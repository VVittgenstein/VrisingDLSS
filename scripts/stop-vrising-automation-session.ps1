param(
    [Parameter(Mandatory = $true)]
    [string]$SessionPath,

    [string]$Root,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedSessionPath = (Resolve-Path -LiteralPath $SessionPath).Path
$session = Get-Content -LiteralPath $resolvedSessionPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($session.GamePath)) {
    throw "Session JSON does not contain GamePath: $resolvedSessionPath"
}

$resolvedGamePath = (Resolve-Path -LiteralPath ([string]$session.GamePath)).Path
$artifactRoot = Split-Path -Parent $resolvedSessionPath
$artifactLabel = [string]$session.ArtifactLabel
if ([string]::IsNullOrWhiteSpace($artifactLabel)) {
    $artifactLabel = [System.IO.Path]::GetFileNameWithoutExtension($resolvedSessionPath) -replace "^Session-", ""
}

$bepInExLogPath = Join-Path $resolvedGamePath "BepInEx\LogOutput.log"
$defaultPlayerLog = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Player.log"
$bepInExLogArtifact = [string]$session.BepInExLogArtifact
if ([string]::IsNullOrWhiteSpace($bepInExLogArtifact)) {
    $bepInExLogArtifact = Join-Path $artifactRoot "LogOutput-$artifactLabel.log"
}

$analysisArtifact = [string]$session.AnalysisArtifact
if ([string]::IsNullOrWhiteSpace($analysisArtifact)) {
    $analysisArtifact = Join-Path $artifactRoot "Analysis-$artifactLabel.txt"
}

$playerLogArtifact = [string]$session.PlayerLogArtifact
if ([string]::IsNullOrWhiteSpace($playerLogArtifact)) {
    $playerLogArtifact = Join-Path $artifactRoot "Player-$artifactLabel.log"
}

$werArtifact = Join-Path $artifactRoot "WER-$artifactLabel.txt"
$cleanupArtifact = Join-Path $artifactRoot "Cleanup-$artifactLabel.json"

function Get-ScopedVRisingProcess {
    $names = @("VRising.exe", "VRisingServer.exe")
    $processes = @()
    $seen = New-Object System.Collections.Generic.HashSet[int]

    foreach ($name in $names) {
        $escapedName = $name.Replace("'", "''")
        foreach ($cim in @(Get-CimInstance Win32_Process -Filter "Name = '$escapedName'" -ErrorAction SilentlyContinue | Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and
                    $_.ExecutablePath.StartsWith($resolvedGamePath, [StringComparison]::OrdinalIgnoreCase)
                })) {
            if ($seen.Add([int]$cim.ProcessId)) {
                $process = Get-Process -Id $cim.ProcessId -ErrorAction SilentlyContinue
                if ($process) {
                    $processes += $process
                }
            }
        }
    }

    $processes | Sort-Object Id
}

function Close-ProcessWithFallback {
    param([System.Diagnostics.Process]$Process)

    $result = [ordered]@{
        ProcessId = $(if ($Process) { [int]$Process.Id } else { $null })
        ProcessName = $(if ($Process) { [string]$Process.ProcessName } else { "" })
        CloseMainWindowAttempted = $false
        ForceStopped = $false
        WasRunning = $false
    }

    if (-not $Process) {
        return [pscustomobject]$result
    }

    $live = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
    if (-not $live) {
        return [pscustomobject]$result
    }

    $result.WasRunning = $true
    try {
        $result.CloseMainWindowAttempted = $true
        [void]$live.CloseMainWindow()
    } catch {
        Write-Warning "CloseMainWindow failed for pid=$($Process.Id): $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 8
    $live = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
    if ($live) {
        Stop-Process -Id $live.Id -Force
        $result.ForceStopped = $true
        Start-Sleep -Seconds 2
    }

    [pscustomobject]$result
}

$runStart = Get-Date
$sessionStart = $null
if (-not [string]::IsNullOrWhiteSpace([string]$session.StartedAt)) {
    try {
        $sessionStart = [datetime]::Parse([string]$session.StartedAt)
    } catch {
        Write-Warning "Could not parse session StartedAt: $($session.StartedAt)"
    }
}

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "StopSession" })
    Question = "Can Codex cleanly end a bounded V Rising automation session and restore release-safe diagnostic state?"
    Hypothesis = "A session artifact with pid, paths, and backups is enough to close the game, archive logs/WER, restore ClientSettings, and rewrite the loader config."
    ExpectedEvidence = @(
        "Cleanup JSON under artifacts/gameplay-automation",
        "VRising process count scoped to the game path is zero",
        "ClientSettings restored when the session changed it",
        "Loader diagnostic config restored",
        "BepInEx, Player, and WER artifacts captured when available"
    )
    PassSignal = "Status=Pass with RemainingVRisingProcessCount=0, RestoredLoaderConfig=true, and RestoredClientSettings=true when required."
    FailSignal = "Any remaining scoped game process, restore failure, or crash event."
    CleanupPath = "This script is the cleanup path; rerun it with the same session artifact if the first attempt fails."
    SessionPath = $resolvedSessionPath
    GamePath = $resolvedGamePath
    Stage = [string]$session.Stage
    ProcessId = $session.ProcessId
    UseSdkWrapperNative = [bool]$session.UseSdkWrapperNative
    SetClientResolution = [bool]$session.SetClientResolution
    SetClientWindowMode = [bool]$session.SetClientWindowMode
    ClientWindowMode = $session.ClientWindowMode
    ClientSettingsPath = [string]$session.ClientSettingsPath
    ClientSettingsBackupArtifact = [string]$session.ClientSettingsBackupArtifact
    BepInExConfigPath = [string]$session.BepInExConfigPath
    BepInExConfigBackupArtifact = [string]$session.BepInExConfigBackupArtifact
    CleanupArtifact = $cleanupArtifact
}

if ($DryRun) {
    $plan
    return
}

$status = "Pass"
$failureReasons = New-Object System.Collections.Generic.List[string]
$closedProcesses = @()
$clientSettingsChanged = [bool]($session.SetClientResolution -or $session.SetClientWindowMode)
$restoredClientSettings = -not $clientSettingsChanged
$restoredLoaderConfig = $false
$bepInExConfigBackupArtifact = [string]$session.BepInExConfigBackupArtifact
$restoredBepInExConfig = [string]::IsNullOrWhiteSpace($bepInExConfigBackupArtifact)
$restoredReleaseSafeNative = -not [bool]$session.UseSdkWrapperNative
$bepInExLogArchived = $false
$analysisArchived = $false
$playerLogArchived = $false
$crashEvents = @()

try {
    $processId = 0
    if ($session.ProcessId -and [int]::TryParse([string]$session.ProcessId, [ref]$processId)) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($process) {
            $closedProcesses += Close-ProcessWithFallback -Process $process
        }
    }

    foreach ($process in @(Get-ScopedVRisingProcess)) {
        if (@($closedProcesses | Where-Object { $_.ProcessId -eq $process.Id }).Count -eq 0) {
            $closedProcesses += Close-ProcessWithFallback -Process $process
        }
    }

    try {
        if (Test-Path -LiteralPath $bepInExLogPath) {
            Copy-Item -LiteralPath $bepInExLogPath -Destination $bepInExLogArtifact -Force
            $bepInExLogArchived = $true
            & (Join-Path $resolvedRoot "scripts\analyze-bepinex-log.ps1") -LogPath $bepInExLogArtifact |
                Out-String -Width 220 |
                Set-Content -LiteralPath $analysisArtifact -Encoding UTF8
            $analysisArchived = Test-Path -LiteralPath $analysisArtifact
        }
    } catch {
        $failureReasons.Add("BepInEx log archive failed: $($_.Exception.Message)")
    }

    try {
        if (-not (Test-Path -LiteralPath $playerLogArtifact) -and (Test-Path -LiteralPath $defaultPlayerLog)) {
            Copy-Item -LiteralPath $defaultPlayerLog -Destination $playerLogArtifact -Force
        }
        $playerLogArchived = Test-Path -LiteralPath $playerLogArtifact
    } catch {
        $failureReasons.Add("Player log archive failed: $($_.Exception.Message)")
    }

    try {
        $werStart = $(if ($sessionStart) { $sessionStart.AddSeconds(-5) } else { $runStart.AddMinutes(-10) })
        $werEnd = (Get-Date).AddSeconds(10)
        $crashEvents = @(Get-WinEvent -FilterHashtable @{
                ProviderName = "Application Error"
                StartTime = $werStart
                EndTime = $werEnd
            } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match "VRising|UnityPlayer|coreclr|VrisingDLSS" } |
            Select-Object TimeCreated, Id, ProviderName, Message)

        if ($crashEvents.Count -gt 0) {
            $crashEvents | Format-List | Out-String -Width 220 | Set-Content -LiteralPath $werArtifact -Encoding UTF8
            $failureReasons.Add("Windows Application Error event was recorded.")
        }
    } catch {
        $failureReasons.Add("WER archive failed: $($_.Exception.Message)")
    }

    try {
        if ([bool]$session.UseSdkWrapperNative) {
            & (Join-Path $resolvedRoot "scripts\install-local-package.ps1") -GamePath $resolvedGamePath | Out-Host
            $restoredReleaseSafeNative = $true
        }

        if ($clientSettingsChanged) {
            $clientSettingsPath = [string]$session.ClientSettingsPath
            $clientSettingsBackupArtifact = [string]$session.ClientSettingsBackupArtifact
            if ([string]::IsNullOrWhiteSpace($clientSettingsPath) -or [string]::IsNullOrWhiteSpace($clientSettingsBackupArtifact)) {
                throw "Session did not contain ClientSettings restore paths."
            }

            if (-not (Test-Path -LiteralPath $clientSettingsBackupArtifact)) {
                throw "ClientSettings backup artifact was not found: $clientSettingsBackupArtifact"
            }

            Copy-Item -LiteralPath $clientSettingsBackupArtifact -Destination $clientSettingsPath -Force
            $restoredClientSettings = $true
        }

        $bepInExConfigPath = [string]$session.BepInExConfigPath
        if (-not [string]::IsNullOrWhiteSpace($bepInExConfigBackupArtifact)) {
            if ([string]::IsNullOrWhiteSpace($bepInExConfigPath)) {
                throw "Session did not contain BepInEx config restore path."
            }

            if (-not (Test-Path -LiteralPath $bepInExConfigBackupArtifact)) {
                throw "BepInEx config backup artifact was not found: $bepInExConfigBackupArtifact"
            }

            Copy-Item -LiteralPath $bepInExConfigBackupArtifact -Destination $bepInExConfigPath -Force
            $restoredBepInExConfig = $true
        }
    } catch {
        $failureReasons.Add("ClientSettings/BepInEx config restore failed: $($_.Exception.Message)")
    }

    try {
        & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") -GamePath $resolvedGamePath -Stage loader | Out-Host
        $restoredLoaderConfig = $true
    } catch {
        $failureReasons.Add("Loader config restore failed: $($_.Exception.Message)")
    }
} catch {
    $failureReasons.Add("Unexpected cleanup failure: $($_.Exception.Message)")
}

$runEnd = Get-Date
$remainingProcessCount = @(Get-ScopedVRisingProcess).Count
if ($remainingProcessCount -gt 0) {
    $failureReasons.Add("Scoped V Rising process remained after cleanup.")
}

if ($failureReasons.Count -gt 0 -or -not $restoredLoaderConfig -or -not $restoredClientSettings -or -not $restoredBepInExConfig -or $remainingProcessCount -gt 0) {
    $status = "Failed"
}

if ([bool]$session.UseSdkWrapperNative -and -not $restoredReleaseSafeNative) {
    $failureReasons.Add("Release-safe native restore failed.")
    $status = "Failed"
}

$result = [pscustomobject]@{
    Mode = "StopSession"
    Status = $status
    FailureReason = ($failureReasons.ToArray() -join " ")
    SessionPath = $resolvedSessionPath
    GamePath = $resolvedGamePath
    Stage = [string]$session.Stage
    ArtifactLabel = $artifactLabel
    StartedAt = $runStart.ToString("o")
    EndedAt = $runEnd.ToString("o")
    SessionStartedAt = $(if ($sessionStart) { $sessionStart.ToString("o") } else { "" })
    ProcessId = $session.ProcessId
    ClosedProcesses = @($closedProcesses)
    BepInExLogArtifact = $(if (Test-Path -LiteralPath $bepInExLogArtifact) { $bepInExLogArtifact } else { "" })
    BepInExLogArchived = $bepInExLogArchived
    AnalysisArtifact = $(if (Test-Path -LiteralPath $analysisArtifact) { $analysisArtifact } else { "" })
    AnalysisArchived = $analysisArchived
    PlayerLogArtifact = $(if (Test-Path -LiteralPath $playerLogArtifact) { $playerLogArtifact } else { "" })
    PlayerLogArchived = $playerLogArchived
    WerArtifact = $(if (Test-Path -LiteralPath $werArtifact) { $werArtifact } else { "" })
    CrashEventCount = $crashEvents.Count
    UseSdkWrapperNative = [bool]$session.UseSdkWrapperNative
    SetClientResolution = [bool]$session.SetClientResolution
    SetClientWindowMode = [bool]$session.SetClientWindowMode
    ClientWindowMode = $session.ClientWindowMode
    RestoredClientSettings = $restoredClientSettings
    RestoredLoaderConfig = $restoredLoaderConfig
    RestoredBepInExConfig = $restoredBepInExConfig
    BepInExConfigBackupArtifact = $(if (-not [string]::IsNullOrWhiteSpace($bepInExConfigBackupArtifact) -and (Test-Path -LiteralPath $bepInExConfigBackupArtifact)) { $bepInExConfigBackupArtifact } else { "" })
    RestoredReleaseSafeNative = $restoredReleaseSafeNative
    CleanupRequired = $false
    RemainingVRisingProcessCount = $remainingProcessCount
    LaunchesGame = $false
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cleanupArtifact -Encoding UTF8
$result

if ($status -ne "Pass") {
    exit 1
}
