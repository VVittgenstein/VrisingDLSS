param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [ValidateSet("Paired", "BaselineOnly", "CandidateOnly")]
    [string]$Mode = "Paired",

    [string]$Root,
    [string]$ArtifactLabel,
    [int]$DurationSeconds = 220,
    [int]$CaptureAtSeconds = 150,
    [int]$CaptureWaitSeconds = 20,
    [switch]$ManualCapture,
    [string]$ReadyFile,
    [int]$ReadyTimeoutSeconds = 600,
    [switch]$AttachExistingBaseline,
    $CapturePerformance = $true,
    [int]$PerformanceSeconds = 30,
    [int]$PerformanceDelaySeconds = 1,
    [int]$PerformanceMetricsIntervalMs = 1000,
    [string]$PresentMonPath = "C:\Software\PresentMon\PresentMon-2.4.1-x64.exe",
    [string]$NvidiaSmiPath = "nvidia-smi.exe",
    [switch]$SkipSystemMetrics,
    [ValidateSet("dlss-visible-writeback", "dlss-user-rendering", "dlss-user-rendering-cached-driver", "dlss-user-rendering-no-evaluate", "dlss-user-rendering-materialization-no-evaluate", "dlss-user-rendering-cached-driver-no-evaluate", "render-scale-control")]
    [string]$CandidateStage = "dlss-visible-writeback",
    $WaitForStage10A = $true,
    [int]$Stage10ATimeoutSeconds = 600,
    $WaitForUserRendering = $true,
    [int]$UserRenderingTimeoutSeconds = 600,
    $KeepCandidateWritebackRunning = $true,
    [string]$DlssRuntimePath = "",
    [string]$DlssApplicationId = "0",
    [string]$SdkWrapperNativePath,
    [ValidateSet("Unchanged", "Off", "UltraQuality", "Quality", "Balanced", "Performance")]
    [string]$FsrMode = "Unchanged",
    [string]$FsrSettingsPath,
    [switch]$NoFsrBackup,
    [switch]$SkipInstall,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [switch]$SetClientResolution,
    [switch]$SetClientWindowMode,
    [ValidateRange(0, 3)]
    [int]$ClientWindowMode = 3,
    [switch]$ProtectSave,
    [string]$SaveDir,
    $ArchiveChangedSave = $true,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Convert-ToBooleanOption {
    param(
        $Value,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($Value -is [bool]) {
        return $Value
    }

    if ($null -eq $Value) {
        throw "$Name cannot be null."
    }

    if ($Value -is [int] -or $Value -is [long]) {
        return ([long]$Value) -ne 0
    }

    $text = ([string]$Value).Trim()
    switch ($text.ToLowerInvariant()) {
        "true" { return $true }
        "false" { return $false }
        "1" { return $true }
        "0" { return $false }
        "yes" { return $true }
        "no" { return $false }
        default { throw "$Name must be a boolean value. Use true/false or 1/0." }
    }
}

$capturePerformanceEnabled = Convert-ToBooleanOption -Value $CapturePerformance -Name "CapturePerformance"
$waitForStage10AEnabled = Convert-ToBooleanOption -Value $WaitForStage10A -Name "WaitForStage10A"
$waitForUserRenderingEnabled = Convert-ToBooleanOption -Value $WaitForUserRendering -Name "WaitForUserRendering"
$keepCandidateWritebackRunningEnabled = Convert-ToBooleanOption -Value $KeepCandidateWritebackRunning -Name "KeepCandidateWritebackRunning"
$archiveChangedSaveEnabled = Convert-ToBooleanOption -Value $ArchiveChangedSave -Name "ArchiveChangedSave"

if ($DurationSeconds -lt 30) {
    throw "DurationSeconds must be at least 30."
}

if ($CaptureAtSeconds -lt 5) {
    throw "CaptureAtSeconds must be at least 5."
}

if ($CaptureAtSeconds -gt $DurationSeconds) {
    throw "CaptureAtSeconds cannot be greater than DurationSeconds."
}

if ($CaptureWaitSeconds -lt 0) {
    throw "CaptureWaitSeconds cannot be negative."
}

if ($ReadyTimeoutSeconds -lt 30) {
    throw "ReadyTimeoutSeconds must be at least 30."
}

if ($PerformanceSeconds -lt 3) {
    throw "PerformanceSeconds must be at least 3."
}

if ($PerformanceDelaySeconds -lt 0) {
    throw "PerformanceDelaySeconds cannot be negative."
}

if ($PerformanceMetricsIntervalMs -lt 250) {
    throw "PerformanceMetricsIntervalMs must be at least 250."
}

if ($Stage10ATimeoutSeconds -lt 30) {
    throw "Stage10ATimeoutSeconds must be at least 30."
}

if ($UserRenderingTimeoutSeconds -lt 30) {
    throw "UserRenderingTimeoutSeconds must be at least 30."
}

if ($Width -lt 640 -or $Height -lt 480) {
    throw "Width/Height are too small for a useful V Rising visual comparison."
}

if ($ProtectSave -and [string]::IsNullOrWhiteSpace($SaveDir)) {
    throw "ProtectSave requires -SaveDir pointing to the local/private V Rising save directory to back up and restore."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
$exePath = Join-Path $resolvedGamePath "VRising.exe"
$pluginPath = Join-Path $resolvedGamePath "BepInEx\plugins\VrisingDLSS"
$nativeTargetPath = Join-Path $pluginPath "VrisingDLSS.Native.dll"
$logPath = Join-Path $resolvedGamePath "BepInEx\LogOutput.log"
$runtimeLogRoot = Join-Path $resolvedRoot "artifacts\runtime-logs"
$visualRoot = Join-Path $resolvedRoot "artifacts\visual-validation"
$fpsRoot = Join-Path $resolvedRoot "artifacts\fps-validation"
$clientSettingsPath = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Settings\v4\ClientSettings.json"
$bepInExConfigPath = Join-Path $resolvedGamePath "BepInEx\config\BepInEx.cfg"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "gameplay-visual-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if ([string]::IsNullOrWhiteSpace($ReadyFile)) {
    $ReadyFile = Join-Path $visualRoot "$ArtifactLabel.ready"
} elseif (-not [System.IO.Path]::IsPathRooted($ReadyFile)) {
    $ReadyFile = Join-Path $resolvedRoot $ReadyFile
}

$readyFileResolved = [System.IO.Path]::GetFullPath($ReadyFile)
$clientSettingsChanged = [bool]($SetClientResolution -or $SetClientWindowMode)
$clientSettingsBackupArtifact = Join-Path $visualRoot "ClientSettings-$ArtifactLabel.before.json"
$bepInExConfigBackupArtifact = Join-Path $visualRoot "BepInEx-$ArtifactLabel.before.cfg"
$saveDirResolved = ""
if ($ProtectSave) {
    $saveDirResolved = [System.IO.Path]::GetFullPath($SaveDir)
}
$saveProtectionLabel = "$ArtifactLabel-protected-save"
$launchArgs = @()
if ($clientSettingsChanged) {
    $launchArgs = @(
        "-windowed",
        "-screen-width", "$Width",
        "-screen-height", "$Height",
        "-screen-fullscreen", "0",
        "-force-d3d11",
        "-single-instance"
    )
}

if ([string]::IsNullOrWhiteSpace($SdkWrapperNativePath)) {
    $SdkWrapperNativePath = Join-Path $resolvedRoot "artifacts\native-build-msvc-wrapper\Release\VrisingDLSS.Native.dll"
} elseif (-not [System.IO.Path]::IsPathRooted($SdkWrapperNativePath)) {
    $SdkWrapperNativePath = Join-Path $resolvedRoot $SdkWrapperNativePath
}

$sdkWrapperNativeResolved = [System.IO.Path]::GetFullPath($SdkWrapperNativePath)

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "VRising.exe was not found: $exePath"
}

function Get-VRisingProcess {
    Get-Process VRising -ErrorAction SilentlyContinue
}

function Invoke-ProjectScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [hashtable]$Parameters = @{}
    )

    $scriptPath = Join-Path $resolvedRoot $RelativePath
    & $scriptPath @Parameters
}

function Close-VisualRunProcess {
    param([System.Diagnostics.Process]$Process)

    $closedByScript = $false
    if (-not $Process) {
        return $closedByScript
    }

    $live = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
    if ($live) {
        try {
            [void]$live.CloseMainWindow()
        } catch {
            Write-Warning "CloseMainWindow failed: $($_.Exception.Message)"
        }

        Start-Sleep -Seconds 8
        $live = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
        if ($live) {
            Stop-Process -Id $live.Id -Force
            Start-Sleep -Seconds 2
        }

        $closedByScript = $true
    }

    return $closedByScript
}

function Set-IniValue {
    param(
        [string[]]$Lines,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )

    $result = New-Object System.Collections.Generic.List[string]
    $currentSection = ""
    $sectionFound = $false
    $keySet = $false
    $keyPattern = "^\s*$([regex]::Escape($Key))\s*="

    foreach ($line in $Lines) {
        if ($line -match "^\s*\[(.+?)\]\s*$") {
            if ($currentSection -eq $Section -and -not $keySet) {
                $result.Add("$Key = $Value")
                $keySet = $true
            }

            $currentSection = $matches[1]
            if ($currentSection -eq $Section) {
                $sectionFound = $true
            }

            $result.Add($line)
            continue
        }

        if ($currentSection -eq $Section -and $line -match $keyPattern) {
            $result.Add("$Key = $Value")
            $keySet = $true
            continue
        }

        $result.Add($line)
    }

    if ($sectionFound) {
        if ($currentSection -eq $Section -and -not $keySet) {
            $result.Add("$Key = $Value")
        }
    } else {
        if ($result.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($result[$result.Count - 1])) {
            $result.Add("")
        }

        $result.Add("[$Section]")
        $result.Add("$Key = $Value")
    }

    return $result.ToArray()
}

function Set-BepInExVisualRunConfig {
    if (-not (Test-Path -LiteralPath $bepInExConfigPath)) {
        Write-Warning "BepInEx config was not found; console mitigation skipped: $bepInExConfigPath"
        return $false
    }

    Copy-Item -LiteralPath $bepInExConfigPath -Destination $bepInExConfigBackupArtifact -Force
    $lines = Get-Content -LiteralPath $bepInExConfigPath
    $lines = Set-IniValue -Lines $lines -Section "Logging.Console" -Key "Enabled" -Value "false"
    $lines = Set-IniValue -Lines $lines -Section "Logging.Disk" -Key "Enabled" -Value "true"
    $lines = Set-IniValue -Lines $lines -Section "Logging.Disk" -Key "InstantFlushing" -Value "true"
    $lines | Set-Content -LiteralPath $bepInExConfigPath -Encoding UTF8
    Write-Host "Temporarily disabled BepInEx console and enabled instant disk log flushing for visual comparison."
    return $true
}

function Restore-BepInExVisualRunConfig {
    if (-not (Test-Path -LiteralPath $bepInExConfigBackupArtifact)) {
        return $true
    }

    Copy-Item -LiteralPath $bepInExConfigBackupArtifact -Destination $bepInExConfigPath -Force
    return $true
}

function Archive-VisualRunLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [datetime]$RunStart,

        [Parameter(Mandatory = $true)]
        [datetime]$RunEnd
    )

    $logArtifact = Join-Path $runtimeLogRoot "LogOutput-$Label.log"
    $analysisArtifact = Join-Path $runtimeLogRoot "Analysis-$Label.txt"
    $werArtifact = Join-Path $runtimeLogRoot "WER-$Label.txt"
    $crashEvents = @()

    try {
        if (Test-Path -LiteralPath $logPath) {
            Copy-Item -LiteralPath $logPath -Destination $logArtifact -Force
            Invoke-ProjectScript -RelativePath "scripts\analyze-bepinex-log.ps1" -Parameters @{ LogPath = $logArtifact } |
                Out-String -Width 220 |
                Set-Content -LiteralPath $analysisArtifact -Encoding UTF8
        }
    } catch {
        Write-Warning "Log archive/analyze failed for ${Label}: $($_.Exception.Message)"
    }

    try {
        $crashEvents = @(Get-WinEvent -FilterHashtable @{
                ProviderName = "Application Error"
                StartTime = $RunStart.AddSeconds(-5)
                EndTime = $RunEnd.AddSeconds(10)
            } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match "VRising|UnityPlayer|coreclr|VrisingDLSS" } |
            Select-Object TimeCreated, Id, ProviderName, Message)

        if ($crashEvents.Count -gt 0) {
            $crashEvents | Format-List | Out-String -Width 220 | Set-Content -LiteralPath $werArtifact -Encoding UTF8
        }
    } catch {
        Write-Warning "WER archive failed for ${Label}: $($_.Exception.Message)"
    }

    [pscustomobject]@{
        LogArtifact = $(if (Test-Path -LiteralPath $logArtifact) { $logArtifact } else { "" })
        AnalysisArtifact = $(if (Test-Path -LiteralPath $analysisArtifact) { $analysisArtifact } else { "" })
        WerArtifact = $(if (Test-Path -LiteralPath $werArtifact) { $werArtifact } else { "" })
        CrashEventCount = $crashEvents.Count
    }
}

function Restore-ReleaseSafeState {
    try {
        Invoke-ProjectScript -RelativePath "scripts\install-local-package.ps1" -Parameters @{ GamePath = $resolvedGamePath } | Out-Host
    } catch {
        Write-Warning "Release-safe native restore failed: $($_.Exception.Message)"
    }

    try {
        Invoke-ProjectScript -RelativePath "scripts\write-diagnostic-config.ps1" -Parameters @{ GamePath = $resolvedGamePath; Stage = "loader" } | Out-Host
    } catch {
        Write-Warning "Loader config restore failed: $($_.Exception.Message)"
    }
}

function Wait-UntilRunSecond {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [datetime]$RunStart,

        [Parameter(Mandatory = $true)]
        [int]$Second
    )

    $deadline = $RunStart.AddSeconds($Second)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)) {
            return $false
        }

        Start-Sleep -Seconds 3
    }

    return $true
}

function Wait-ForManualCaptureReady {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [datetime]$RunStart,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $readyFileResolved) | Out-Null
    Remove-Item -LiteralPath $readyFileResolved -Force -ErrorAction SilentlyContinue

    Write-Host "ManualCaptureReadyFile=$readyFileResolved"
    Write-Host "Create the ready file after entering the target scene. Capture will not happen before +$CaptureAtSeconds seconds."

    $deadline = (Get-Date).AddSeconds($ReadyTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{
                Ready = $false
                TimedOut = $false
                ProcessExited = $true
                ReadyDetectedAt = $null
            }
        }

        if (Test-Path -LiteralPath $readyFileResolved) {
            $readyDetectedAt = Get-Date
            Remove-Item -LiteralPath $readyFileResolved -Force -ErrorAction SilentlyContinue
            if (-not (Wait-UntilRunSecond -Process $Process -RunStart $RunStart -Second $CaptureAtSeconds)) {
                return [pscustomobject]@{
                    Ready = $false
                    TimedOut = $false
                    ProcessExited = $true
                    ReadyDetectedAt = $readyDetectedAt
                }
            }

            return [pscustomobject]@{
                Ready = $true
                TimedOut = $false
                ProcessExited = $false
                ReadyDetectedAt = $readyDetectedAt
            }
        }

        Start-Sleep -Seconds 2
    }

    return [pscustomobject]@{
        Ready = $false
        TimedOut = $true
        ProcessExited = $false
        ReadyDetectedAt = $null
    }
}

function Read-LogSinceOffset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [long]$Offset
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    $stream = $null
    $reader = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        if ($stream.Length -ge $Offset) {
            [void]$stream.Seek($Offset, [System.IO.SeekOrigin]::Begin)
        } else {
            [void]$stream.Seek(0, [System.IO.SeekOrigin]::Begin)
        }

        $reader = New-Object System.IO.StreamReader($stream)
        return $reader.ReadToEnd()
    } finally {
        if ($reader) {
            $reader.Dispose()
        } elseif ($stream) {
            $stream.Dispose()
        }
    }
}

function Wait-ForStage10AVisibleWriteback {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [long]$LogStartOffset
    )

    Write-Host "Waiting for Stage 10A visible write-back success in BepInEx log."

    $deadline = (Get-Date).AddSeconds($Stage10ATimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{
                Ready = $false
                TimedOut = $false
                ProcessExited = $true
                DetectedAt = $null
            }
        }

        $text = Read-LogSinceOffset -Path $logPath -Offset $LogStartOffset
        if ($text -match "DLSS visible write-back probe succeeded" -and $text -match "sequenceSuccesses=30/30") {
            return [pscustomobject]@{
                Ready = $true
                TimedOut = $false
                ProcessExited = $false
                DetectedAt = Get-Date
            }
        }

        Start-Sleep -Seconds 2
    }

    return [pscustomobject]@{
        Ready = $false
        TimedOut = $true
        ProcessExited = $false
        DetectedAt = $null
    }
}

function Wait-ForDlssUserRenderingReady {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [long]$LogStartOffset,

        [Parameter(Mandatory = $true)]
        [string]$Stage
    )

    if ($Stage -eq "dlss-user-rendering-no-evaluate" -or $Stage -eq "dlss-user-rendering-materialization-no-evaluate" -or $Stage -eq "dlss-user-rendering-cached-driver-no-evaluate") {
        Write-Host "Waiting for DLSS user-rendering no-evaluate acceptance in BepInEx log."
        $readyPattern = "DLSS user rendering no-evaluate accepted from"
        $readyCountPattern = "acceptedFrames=\d+"
    } else {
        Write-Host "Waiting for DLSS user-rendering evaluate success in BepInEx log."
        $readyPattern = "DLSS user rendering evaluate succeeded from"
        $readyCountPattern = "sequenceSuccesses=\d+"
    }

    $deadline = (Get-Date).AddSeconds($UserRenderingTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{
                Ready = $false
                TimedOut = $false
                ProcessExited = $true
                DetectedAt = $null
            }
        }

        $text = Read-LogSinceOffset -Path $logPath -Offset $LogStartOffset
        if ($text -match $readyPattern -and $text -match $readyCountPattern) {
            return [pscustomobject]@{
                Ready = $true
                TimedOut = $false
                ProcessExited = $false
                DetectedAt = Get-Date
            }
        }

        if ($text -match "DLSS user rendering evaluate (blocked|failed|skipped) from" -or $text -match "DLSS user rendering shutdown failed:" -or (($Stage -eq "dlss-user-rendering-no-evaluate" -or $Stage -eq "dlss-user-rendering-materialization-no-evaluate" -or $Stage -eq "dlss-user-rendering-cached-driver-no-evaluate") -and $text -match "DLSS user rendering evaluate succeeded from")) {
            return [pscustomobject]@{
                Ready = $false
                TimedOut = $false
                ProcessExited = $false
                DetectedAt = $null
            }
        }

        Start-Sleep -Seconds 2
    }

    [pscustomobject]@{
        Ready = $false
        TimedOut = $true
        ProcessExited = $false
        DetectedAt = $null
    }
}

function Invoke-PerformanceCapture {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not $capturePerformanceEnabled) {
        return $null
    }

    if (-not (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue)) {
        Write-Warning "Performance capture skipped for ${Label}: VRising process is no longer running."
        return $null
    }

    $parameters = @{
        ArtifactLabel = $Label
        ProcessId = $Process.Id
        Seconds = $PerformanceSeconds
        DelaySeconds = $PerformanceDelaySeconds
        MetricsIntervalMs = $PerformanceMetricsIntervalMs
        PresentMonPath = $PresentMonPath
        NvidiaSmiPath = $NvidiaSmiPath
    }

    if ($SkipSystemMetrics) {
        $parameters.SkipSystemMetrics = $true
    }

    $performance = Invoke-ProjectScript -RelativePath "scripts\capture-vrising-fps.ps1" -Parameters $parameters
    $performance | Format-List | Out-String -Width 220 | Write-Host
    return $performance
}

function Invoke-VisibilityPreflight {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $preflight = Invoke-ProjectScript -RelativePath "scripts\inspect-vrising-visibility.ps1" -Parameters @{
        GamePath = $resolvedGamePath
    }

    Write-Host "VisibilityPreflightLabel=$Label"
    Write-Host "VisibilityPreflightStatus=$($preflight.Status)"
    Write-Host "VisibilityPreflightProcessCount=$($preflight.ProcessCount)"
    if ($preflight.SelectedProcess) {
        Write-Host "VisibilityPreflightSelectedProcessId=$($preflight.SelectedProcess.Id)"
        Write-Host "VisibilityPreflightSelectedWindowTitle=$($preflight.SelectedProcess.MainWindowTitle)"
    }

    if ($preflight.Status -ne "VisibleGameWindow") {
        Write-Warning "Visibility preflight did not find a visible V Rising game window for ${Label}: $(@($preflight.Issues) -join ' ')"
    }

    return $preflight
}

function Invoke-VisualRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [bool]$UseSdkWrapperNative,

        [bool]$AttachExistingProcess = $false
    )

    $runStart = Get-Date
    $process = $null
    $capture = $null
    $performance = $null
    $visibilityPreflight = $null
    $closedByScript = $false
    $exitedBeforeCapture = $false
    $captureReadyTimedOut = $false
    $manualReadyDetectedAt = $null
    $stage10AReadyTimedOut = $false
    $stage10ADetectedAt = $null
    $userRenderingReadyTimedOut = $false
    $userRenderingDetectedAt = $null
    $waitedForStage10A = $waitForStage10AEnabled -and $UseSdkWrapperNative -and $Stage -eq "dlss-visible-writeback"
    $waitedForUserRendering = $waitForUserRenderingEnabled -and (($UseSdkWrapperNative -and ($Stage -eq "dlss-user-rendering" -or $Stage -eq "dlss-user-rendering-cached-driver")) -or $Stage -eq "dlss-user-rendering-no-evaluate" -or $Stage -eq "dlss-user-rendering-materialization-no-evaluate" -or $Stage -eq "dlss-user-rendering-cached-driver-no-evaluate")

    try {
        if ($AttachExistingProcess) {
            if ($UseSdkWrapperNative) {
                throw "AttachExistingProcess is only supported for baseline loader runs."
            }

            $process = Get-VRisingProcess |
                Sort-Object StartTime -Descending |
                Select-Object -First 1
            if (-not $process) {
                throw "No running VRising process was found for the attached baseline run."
            }

            Write-Host "Attached to existing VRising pid=$($process.Id) for baseline capture."
            Write-Host "Attached baseline setup is read-only before capture; no config or DLL files are rewritten until cleanup."
        } else {
            if (-not $SkipInstall) {
                Invoke-ProjectScript -RelativePath "scripts\install-local-package.ps1" -Parameters @{ GamePath = $resolvedGamePath } | Out-Host
            }

            if ($UseSdkWrapperNative) {
                if (-not (Test-Path -LiteralPath $sdkWrapperNativeResolved)) {
                    throw "SDK-wrapper native DLL was not found: $sdkWrapperNativeResolved"
                }
                if ([string]::IsNullOrWhiteSpace($DlssRuntimePath) -or -not (Test-Path -LiteralPath $DlssRuntimePath)) {
                    throw "Candidate visual run requires -DlssRuntimePath pointing to a local nvngx_dlss.dll."
                }

                New-Item -ItemType Directory -Force -Path $pluginPath | Out-Null
                Copy-Item -LiteralPath $sdkWrapperNativeResolved -Destination $nativeTargetPath -Force
            }

            Invoke-ProjectScript -RelativePath "scripts\write-diagnostic-config.ps1" -Parameters @{
                GamePath = $resolvedGamePath
                Stage = $Stage
                DlssRuntimePath = $DlssRuntimePath
                DlssApplicationId = $DlssApplicationId
                KeepVisibleWritebackRunning = ($UseSdkWrapperNative -and $Stage -eq "dlss-visible-writeback" -and $keepCandidateWritebackRunningEnabled)
            } | Out-Host
        }

        Write-Host "VisualRunStart=$($runStart.ToString('o'))"
        Write-Host "VisualRunStage=$Stage"
        Write-Host "VisualRunLabel=$Label"
        if ($ManualCapture) {
            Write-Host "Enter the same local/private gameplay scene, then create the ready file when the scene is stable."
        } else {
            Write-Host "Enter the same local/private gameplay scene before capture at +$CaptureAtSeconds seconds."
        }

        $logStartOffset = if (Test-Path -LiteralPath $logPath) { (Get-Item -LiteralPath $logPath).Length } else { 0L }
        if (-not $AttachExistingProcess) {
            if ($launchArgs.Count -gt 0) {
                $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -ArgumentList $launchArgs -PassThru
            } else {
                $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -PassThru
            }
            Write-Host "Started VRising pid=$($process.Id)"
        }

        if ($ManualCapture) {
            $ready = Wait-ForManualCaptureReady -Process $process -RunStart $runStart -Label $Label
            $manualReadyDetectedAt = $ready.ReadyDetectedAt
            $captureReadyTimedOut = $ready.TimedOut
            $exitedBeforeCapture = $ready.ProcessExited
            if (-not $ready.Ready) {
                Write-Warning "Manual capture was not ready for ${Label}; TimedOut=$($ready.TimedOut); ProcessExited=$($ready.ProcessExited)"
            }
        } else {
            if (-not (Wait-UntilRunSecond -Process $process -RunStart $runStart -Second $CaptureAtSeconds)) {
                $exitedBeforeCapture = $true
            }
        }

        if (-not $exitedBeforeCapture -and -not $captureReadyTimedOut -and $waitedForStage10A) {
            $stage10A = Wait-ForStage10AVisibleWriteback -Process $process -LogStartOffset $logStartOffset
            $stage10ADetectedAt = $stage10A.DetectedAt
            $stage10AReadyTimedOut = $stage10A.TimedOut
            $exitedBeforeCapture = $stage10A.ProcessExited
            if (-not $stage10A.Ready) {
                Write-Warning "Stage 10A visible write-back success was not observed before capture for ${Label}; TimedOut=$($stage10A.TimedOut); ProcessExited=$($stage10A.ProcessExited)"
            }
        }

        if (-not $exitedBeforeCapture -and -not $captureReadyTimedOut -and $waitedForUserRendering) {
            $userRendering = Wait-ForDlssUserRenderingReady -Process $process -LogStartOffset $logStartOffset -Stage $Stage
            $userRenderingDetectedAt = $userRendering.DetectedAt
            $userRenderingReadyTimedOut = $userRendering.TimedOut -or (-not $userRendering.Ready -and -not $userRendering.ProcessExited)
            $exitedBeforeCapture = $userRendering.ProcessExited
            if (-not $userRendering.Ready) {
                Write-Warning "DLSS user-rendering readiness was not observed before capture for ${Label}; TimedOut=$($userRendering.TimedOut); ProcessExited=$($userRendering.ProcessExited)"
            }
        }

        if (-not $exitedBeforeCapture -and -not $captureReadyTimedOut -and -not $stage10AReadyTimedOut -and -not $userRenderingReadyTimedOut) {
            $visibilityPreflight = Invoke-VisibilityPreflight -Label $Label
            $capture = Invoke-ProjectScript -RelativePath "scripts\capture-vrising-window.ps1" -Parameters @{
                ArtifactLabel = $Label
                WaitSeconds = $CaptureWaitSeconds
            }
            $capture | Format-List | Out-String -Width 220 | Write-Host
        }

        if (-not $exitedBeforeCapture -and -not $captureReadyTimedOut -and -not $stage10AReadyTimedOut -and -not $userRenderingReadyTimedOut) {
            $performance = Invoke-PerformanceCapture -Process $process -Label $Label
        }

        if (-not $exitedBeforeCapture) {
            [void](Wait-UntilRunSecond -Process $process -RunStart $runStart -Second $DurationSeconds)
        }
    } finally {
        $closedByScript = Close-VisualRunProcess -Process $process
        $runEnd = Get-Date
        $archived = if ($process) {
            Archive-VisualRunLog -Label $Label -RunStart $runStart -RunEnd $runEnd
        } else {
            Write-Warning "Log archive skipped for ${Label}: VRising was not launched or attached."
            [pscustomobject]@{
                LogArtifact = ""
                AnalysisArtifact = ""
                WerArtifact = ""
                CrashEventCount = 0
            }
        }
        Restore-ReleaseSafeState
    }

    [pscustomobject]@{
        Mode = "VisualRunCompleted"
        Stage = $Stage
        Label = $Label
        CapturePath = $(if ($capture) { $capture.Path } else { "" })
        CaptureMethod = $(if ($capture) { $capture.Method } else { "" })
        PerformanceCsvPath = $(if ($performance) { $performance.CsvPath } else { "" })
        PerformanceMetricsPath = $(if ($performance) { $performance.MetricsPath } else { "" })
        PerformanceSummaryPath = $(if ($performance) { $performance.SummaryPath } else { "" })
        AverageFps = $(if ($performance) { $performance.AverageFps } else { $null })
        OnePercentLowFps = $(if ($performance) { $performance.OnePercentLowFps } else { $null })
        AverageFrameMs = $(if ($performance) { $performance.AverageFrameMs } else { $null })
        P95FrameMs = $(if ($performance) { $performance.P95FrameMs } else { $null })
        P99FrameMs = $(if ($performance) { $performance.P99FrameMs } else { $null })
        AverageProcessCpuPercent = $(if ($performance) { $performance.AverageProcessCpuPercent } else { $null })
        AverageGpuUtilPercent = $(if ($performance) { $performance.AverageGpuUtilPercent } else { $null })
        AverageGpuMemoryUsedMb = $(if ($performance) { $performance.AverageGpuMemoryUsedMb } else { $null })
        AverageGpuPowerW = $(if ($performance) { $performance.AverageGpuPowerW } else { $null })
        VisibilityPreflightStatus = $(if ($visibilityPreflight) { $visibilityPreflight.Status } else { "" })
        VisibilityPreflightProcessCount = $(if ($visibilityPreflight) { $visibilityPreflight.ProcessCount } else { 0 })
        VisibilityPreflightSelectedProcessId = $(if ($visibilityPreflight -and $visibilityPreflight.SelectedProcess) { $visibilityPreflight.SelectedProcess.Id } else { 0 })
        VisibilityPreflightSelectedWindowTitle = $(if ($visibilityPreflight -and $visibilityPreflight.SelectedProcess) { $visibilityPreflight.SelectedProcess.MainWindowTitle } else { "" })
        VisibilityPreflightIssues = $(if ($visibilityPreflight) { @($visibilityPreflight.Issues) -join " | " } else { "" })
        ManualCapture = [bool]$ManualCapture
        ManualReadyFile = $(if ($ManualCapture) { $readyFileResolved } else { "" })
        ManualReadyDetectedAt = $(if ($manualReadyDetectedAt) { $manualReadyDetectedAt.ToString("o") } else { "" })
        CaptureReadyTimedOut = $captureReadyTimedOut
        WaitedForStage10A = $waitedForStage10A
        Stage10ADetectedAt = $(if ($stage10ADetectedAt) { $stage10ADetectedAt.ToString("o") } else { "" })
        Stage10AReadyTimedOut = $stage10AReadyTimedOut
        WaitedForUserRendering = $waitedForUserRendering
        UserRenderingDetectedAt = $(if ($userRenderingDetectedAt) { $userRenderingDetectedAt.ToString("o") } else { "" })
        UserRenderingReadyTimedOut = $userRenderingReadyTimedOut
        KeepCandidateWritebackRunning = $(if ($UseSdkWrapperNative -and $Stage -eq "dlss-visible-writeback") { $keepCandidateWritebackRunningEnabled } else { $false })
        Width = $(if ($capture) { $capture.Width } else { 0 })
        Height = $(if ($capture) { $capture.Height } else { 0 })
        AverageLuma = $(if ($capture) { $capture.AverageLuma } else { 0 })
        NearBlackRatio = $(if ($capture) { $capture.NearBlackRatio } else { 0 })
        NearWhiteRatio = $(if ($capture) { $capture.NearWhiteRatio } else { 0 })
        Sha256 = $(if ($capture) { $capture.Sha256 } else { "" })
        LogArtifact = $archived.LogArtifact
        AnalysisArtifact = $archived.AnalysisArtifact
        WerArtifact = $archived.WerArtifact
        CrashEventCount = $archived.CrashEventCount
        ExitedBeforeCapture = $exitedBeforeCapture
        ClosedByScript = $closedByScript
        RestoredReleaseSafeState = $true
        AttachedExistingProcess = $AttachExistingProcess
        LaunchesGame = -not $AttachExistingProcess
    }
}

$existingProcess = Get-VRisingProcess | Select-Object -First 1
if ($AttachExistingBaseline -and $Mode -eq "CandidateOnly") {
    throw "AttachExistingBaseline cannot be used with CandidateOnly mode."
}

if ($existingProcess -and (-not $AttachExistingBaseline -or $Mode -eq "CandidateOnly")) {
    throw "VRising is already running (pid=$($existingProcess.Id)). Close it before running visual comparison."
}

if ($FsrMode -ne "Unchanged" -and $AttachExistingBaseline) {
    throw "FsrMode cannot be used with AttachExistingBaseline because the helper must change ClientSettings.json before launching both runs."
}

$fsrPlan = $null
if ($FsrMode -ne "Unchanged") {
    $fsrPlanParameters = @{
        Mode = $FsrMode
        Root = $resolvedRoot
        DryRun = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($FsrSettingsPath)) {
        $fsrPlanParameters.SettingsPath = $FsrSettingsPath
    }
    if ($NoFsrBackup) {
        $fsrPlanParameters.NoBackup = $true
    }

    $fsrPlan = Invoke-ProjectScript -RelativePath "scripts\set-vrising-fsr-mode.ps1" -Parameters $fsrPlanParameters
}

$candidateRequiresSdkWrapper = @("render-scale-control", "dlss-user-rendering-no-evaluate", "dlss-user-rendering-materialization-no-evaluate", "dlss-user-rendering-cached-driver-no-evaluate") -notcontains $CandidateStage
$candidateLabelSuffix = switch ($CandidateStage) {
    "dlss-visible-writeback" { "stage10a-visible-writeback" }
    "dlss-user-rendering" { "user-rendering" }
    "dlss-user-rendering-cached-driver" { "user-rendering-cached-driver" }
    "dlss-user-rendering-no-evaluate" { "user-rendering-no-evaluate" }
    "dlss-user-rendering-materialization-no-evaluate" { "user-rendering-materialization-no-evaluate" }
    "dlss-user-rendering-cached-driver-no-evaluate" { "user-rendering-cached-driver-no-evaluate" }
    "render-scale-control" { "render-scale-control" }
}
$comparisonLabelSuffix = switch ($CandidateStage) {
    "dlss-visible-writeback" { "stage10a" }
    "dlss-user-rendering" { "user-rendering" }
    "dlss-user-rendering-cached-driver" { "user-rendering-cached-driver" }
    "dlss-user-rendering-no-evaluate" { "user-rendering-no-evaluate" }
    "dlss-user-rendering-materialization-no-evaluate" { "user-rendering-materialization-no-evaluate" }
    "dlss-user-rendering-cached-driver-no-evaluate" { "user-rendering-cached-driver-no-evaluate" }
    "render-scale-control" { "render-scale-control" }
}
$baselineLabel = "$ArtifactLabel-baseline-loader"
$candidateLabel = "$ArtifactLabel-$candidateLabelSuffix"
$comparisonLabel = "$ArtifactLabel-baseline-vs-$comparisonLabelSuffix"
$baselinePath = Join-Path $visualRoot "$baselineLabel.png"
$candidatePath = Join-Path $visualRoot "$candidateLabel.png"
$comparisonPath = Join-Path $visualRoot "$comparisonLabel.txt"

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { $Mode })
    GamePath = $resolvedGamePath
    DurationSeconds = $DurationSeconds
    CaptureAtSeconds = $CaptureAtSeconds
    CaptureWaitSeconds = $CaptureWaitSeconds
    ManualCapture = [bool]$ManualCapture
    ReadyFile = $(if ($ManualCapture) { $readyFileResolved } else { "" })
    ReadyTimeoutSeconds = $(if ($ManualCapture) { $ReadyTimeoutSeconds } else { 0 })
    AttachExistingBaseline = [bool]$AttachExistingBaseline
    SetClientResolution = [bool]$SetClientResolution
    SetClientWindowMode = [bool]$SetClientWindowMode
    Width = $(if ($SetClientResolution) { $Width } else { 0 })
    Height = $(if ($SetClientResolution) { $Height } else { 0 })
    ClientWindowMode = $(if ($SetClientWindowMode) { $ClientWindowMode } else { $null })
    ClientSettingsPath = $(if ($clientSettingsChanged) { $clientSettingsPath } else { "" })
    ClientSettingsBackupArtifact = $(if ($clientSettingsChanged) { $clientSettingsBackupArtifact } else { "" })
    BepInExConfigPath = $bepInExConfigPath
    BepInExConfigBackupArtifact = $bepInExConfigBackupArtifact
    LaunchArgs = $launchArgs
    CapturePerformance = $capturePerformanceEnabled
    PerformanceSeconds = $(if ($capturePerformanceEnabled) { $PerformanceSeconds } else { 0 })
    PerformanceDelaySeconds = $(if ($capturePerformanceEnabled) { $PerformanceDelaySeconds } else { 0 })
    PerformanceMetricsIntervalMs = $(if ($capturePerformanceEnabled) { $PerformanceMetricsIntervalMs } else { 0 })
    PresentMonPath = $(if ($capturePerformanceEnabled) { $PresentMonPath } else { "" })
    NvidiaSmiPath = $(if ($capturePerformanceEnabled -and -not $SkipSystemMetrics) { $NvidiaSmiPath } else { "" })
    CandidateStage = $CandidateStage
    WaitForStage10A = ($CandidateStage -eq "dlss-visible-writeback" -and $waitForStage10AEnabled)
    Stage10ATimeoutSeconds = $(if ($Mode -ne "BaselineOnly" -and $CandidateStage -eq "dlss-visible-writeback" -and $waitForStage10AEnabled) { $Stage10ATimeoutSeconds } else { 0 })
    WaitForUserRendering = (($CandidateStage -eq "dlss-user-rendering" -or $CandidateStage -eq "dlss-user-rendering-cached-driver" -or $CandidateStage -eq "dlss-user-rendering-no-evaluate" -or $CandidateStage -eq "dlss-user-rendering-materialization-no-evaluate" -or $CandidateStage -eq "dlss-user-rendering-cached-driver-no-evaluate") -and $waitForUserRenderingEnabled)
    UserRenderingTimeoutSeconds = $(if ($Mode -ne "BaselineOnly" -and ($CandidateStage -eq "dlss-user-rendering" -or $CandidateStage -eq "dlss-user-rendering-cached-driver" -or $CandidateStage -eq "dlss-user-rendering-no-evaluate" -or $CandidateStage -eq "dlss-user-rendering-materialization-no-evaluate" -or $CandidateStage -eq "dlss-user-rendering-cached-driver-no-evaluate") -and $waitForUserRenderingEnabled) { $UserRenderingTimeoutSeconds } else { 0 })
    KeepCandidateWritebackRunning = $(if ($Mode -ne "BaselineOnly" -and $CandidateStage -eq "dlss-visible-writeback") { $keepCandidateWritebackRunningEnabled } else { $false })
    ArtifactLabel = $ArtifactLabel
    BaselineCapture = $(if ($Mode -ne "CandidateOnly") { $baselinePath } else { "" })
    CandidateCapture = $(if ($Mode -ne "BaselineOnly") { $candidatePath } else { "" })
    ComparisonArtifact = $(if ($Mode -eq "Paired") { $comparisonPath } else { "" })
    DlssRuntimePath = $DlssRuntimePath
    CandidateRequiresSdkWrapper = $candidateRequiresSdkWrapper
    SdkWrapperNativePath = $(if ($Mode -ne "BaselineOnly" -and $candidateRequiresSdkWrapper) { $sdkWrapperNativeResolved } else { "" })
    FsrMode = $FsrMode
    FsrSettingsPath = $(if ($fsrPlan) { $fsrPlan.SettingsPath } elseif (-not [string]::IsNullOrWhiteSpace($FsrSettingsPath)) { [System.IO.Path]::GetFullPath($FsrSettingsPath) } else { "" })
    PreviousFsrMode = $(if ($fsrPlan) { $fsrPlan.PreviousFsrQualityName } else { "" })
    RestoresFsrMode = ($FsrMode -ne "Unchanged")
    FsrBackupPath = $(if ($fsrPlan) { $fsrPlan.BackupPath } else { "" })
    RestoresClientSettings = $clientSettingsChanged
    RestoresBepInExConfig = $true
    RestoresReleaseSafeState = $true
    ProtectSave = [bool]$ProtectSave
    SaveDir = $(if ($ProtectSave) { $saveDirResolved } else { "" })
    SaveProtectionLabel = $(if ($ProtectSave) { $saveProtectionLabel } else { "" })
    ArchiveChangedSave = $(if ($ProtectSave) { $archiveChangedSaveEnabled } else { $false })
    RestoresProtectedSave = [bool]$ProtectSave
    LaunchesGame = (-not [bool]$DryRun) -and (($Mode -ne "BaselineOnly") -or (-not [bool]$AttachExistingBaseline))
}

if ($DryRun) {
    $plan
    return
}

$results = New-Object System.Collections.Generic.List[object]
$comparison = $null
$fsrChange = $null
$restoredFsrMode = ($FsrMode -eq "Unchanged")
$restoredClientSettings = -not $clientSettingsChanged
$previousFsrMode = ""
$fsrBackupPath = ""
$bepInExConfigChanged = $false
$restoredBepInExConfig = $true
$saveBackup = $null
$saveRestore = $null
$saveProtectionBackedUp = $false
$saveRestoreAttempted = $false
$saveRestoreSkippedReason = ""
$saveRestored = -not [bool]$ProtectSave

try {
    New-Item -ItemType Directory -Force -Path $runtimeLogRoot, $visualRoot, $fpsRoot | Out-Null

    if (Set-BepInExVisualRunConfig) {
        $bepInExConfigChanged = $true
        $restoredBepInExConfig = $false
    }

    if ($ProtectSave) {
        $saveBackup = Invoke-ProjectScript -RelativePath "scripts\protect-vrising-save.ps1" -Parameters @{
            Mode = "Backup"
            SaveDir = $saveDirResolved
            Label = $saveProtectionLabel
            Root = $resolvedRoot
        }
        $saveBackup | Format-List | Out-String -Width 220 | Write-Host
        $saveProtectionBackedUp = $true
    }

    if ($clientSettingsChanged) {
        if ($AttachExistingBaseline) {
            throw "SetClientResolution/SetClientWindowMode cannot be used with AttachExistingBaseline."
        }

        if (-not (Test-Path -LiteralPath $clientSettingsPath)) {
            throw "ClientSettings.json was not found: $clientSettingsPath"
        }

        Copy-Item -LiteralPath $clientSettingsPath -Destination $clientSettingsBackupArtifact -Force
        $settings = Get-Content -LiteralPath $clientSettingsPath -Raw | ConvertFrom-Json
        if (-not $settings.GraphicSettings) {
            throw "ClientSettings.json does not contain GraphicSettings."
        }

        if ($SetClientResolution) {
            if (-not $settings.GraphicSettings.Resolution) {
                throw "ClientSettings.json does not contain GraphicSettings.Resolution."
            }

            $settings.GraphicSettings.Resolution.x = $Width
            $settings.GraphicSettings.Resolution.y = $Height
            Write-Host "Temporarily set ClientSettings GraphicSettings.Resolution to ${Width}x${Height}."
        }

        if ($SetClientWindowMode) {
            $windowModeProperty = $settings.GraphicSettings.PSObject.Properties["WindowMode"]
            if ($windowModeProperty) {
                $windowModeProperty.Value = $ClientWindowMode
            } else {
                $settings.GraphicSettings | Add-Member -NotePropertyName "WindowMode" -NotePropertyValue $ClientWindowMode
            }

            Write-Host "Temporarily set ClientSettings GraphicSettings.WindowMode to $ClientWindowMode."
        }

        $settings | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $clientSettingsPath -Encoding UTF8
        $restoredClientSettings = $false
    }

    if ($FsrMode -ne "Unchanged") {
        $fsrParameters = @{
            Mode = $FsrMode
            Root = $resolvedRoot
        }
        if (-not [string]::IsNullOrWhiteSpace($FsrSettingsPath)) {
            $fsrParameters.SettingsPath = $FsrSettingsPath
        }
        if ($NoFsrBackup) {
            $fsrParameters.NoBackup = $true
        }

        $fsrChange = Invoke-ProjectScript -RelativePath "scripts\set-vrising-fsr-mode.ps1" -Parameters $fsrParameters
        $fsrChange | Format-List | Out-String -Width 220 | Write-Host
        $previousFsrMode = [string]$fsrChange.PreviousFsrQualityName
        $fsrBackupPath = [string]$fsrChange.BackupPath
    }

    if ($Mode -ne "CandidateOnly") {
        $results.Add((Invoke-VisualRun -Stage "loader" -Label $baselineLabel -UseSdkWrapperNative $false -AttachExistingProcess ([bool]$AttachExistingBaseline)))
    }

    if ($Mode -ne "BaselineOnly") {
        $results.Add((Invoke-VisualRun -Stage $CandidateStage -Label $candidateLabel -UseSdkWrapperNative $candidateRequiresSdkWrapper))
    }

    if ($Mode -eq "Paired") {
        $baseline = $results | Where-Object { $_.Stage -eq "loader" } | Select-Object -First 1
        $candidate = $results | Where-Object { $_.Stage -eq $CandidateStage } | Select-Object -First 1
        if ($baseline -and $candidate -and
            -not [string]::IsNullOrWhiteSpace($baseline.CapturePath) -and
            -not [string]::IsNullOrWhiteSpace($candidate.CapturePath)) {
            $comparison = Invoke-ProjectScript -RelativePath "scripts\compare-image-artifacts.ps1" -Parameters @{
                BaselinePath = $baseline.CapturePath
                CandidatePath = $candidate.CapturePath
                ArtifactLabel = $comparisonLabel
            }
        }
    }
} finally {
    if ($fsrChange) {
        try {
            $restoreMode = [string]$fsrChange.PreviousFsrQualityName
            if ($restoreMode -match "^Unknown") {
                Write-Warning "FSR mode restore skipped because previous mode was not recognized: $restoreMode"
            } else {
                $restoreParameters = @{
                    Mode = $restoreMode
                    Root = $resolvedRoot
                    NoBackup = $true
                }
                if (-not [string]::IsNullOrWhiteSpace($FsrSettingsPath)) {
                    $restoreParameters.SettingsPath = $FsrSettingsPath
                }

                Invoke-ProjectScript -RelativePath "scripts\set-vrising-fsr-mode.ps1" -Parameters $restoreParameters |
                    Format-List |
                    Out-String -Width 220 |
                    Write-Host
                $restoredFsrMode = $true
            }
        } catch {
            Write-Warning "FSR mode restore failed: $($_.Exception.Message)"
        }
    }

    if ($clientSettingsChanged -and (Test-Path -LiteralPath $clientSettingsBackupArtifact)) {
        try {
            Copy-Item -LiteralPath $clientSettingsBackupArtifact -Destination $clientSettingsPath -Force
            $restoredClientSettings = $true
        } catch {
            Write-Warning "ClientSettings restore failed: $($_.Exception.Message)"
        }
    }

    if ($bepInExConfigChanged) {
        try {
            if (Restore-BepInExVisualRunConfig) {
                $restoredBepInExConfig = $true
            }
        } catch {
            Write-Warning "BepInEx config restore failed: $($_.Exception.Message)"
        }
    }

    if ($ProtectSave) {
        if ($saveProtectionBackedUp -and $saveBackup -and -not [string]::IsNullOrWhiteSpace([string]$saveBackup.BackupDir)) {
            $remainingBeforeSaveRestore = @(Get-VRisingProcess)
            if ($remainingBeforeSaveRestore.Count -gt 0) {
                foreach ($runningProcess in $remainingBeforeSaveRestore) {
                    [void](Close-VisualRunProcess -Process $runningProcess)
                }
            }

            if (@(Get-VRisingProcess).Count -gt 0) {
                $saveRestoreSkippedReason = "VRising process remained after cleanup; refusing to restore protected save while the game is running."
                Write-Warning $saveRestoreSkippedReason
            } else {
                try {
                    $restoreParameters = @{
                        Mode = "Restore"
                        SaveDir = $saveDirResolved
                        Label = $saveProtectionLabel
                        ReferenceDir = [string]$saveBackup.BackupDir
                        Root = $resolvedRoot
                    }
                    if ($archiveChangedSaveEnabled) {
                        $restoreParameters.ArchiveCurrent = $true
                    }

                    $saveRestoreAttempted = $true
                    $saveRestore = Invoke-ProjectScript -RelativePath "scripts\protect-vrising-save.ps1" -Parameters $restoreParameters
                    $saveRestore | Format-List | Out-String -Width 220 | Write-Host
                    $saveRestored = ([int]$saveRestore.ChangeCount -eq 0)
                } catch {
                    $saveRestoreSkippedReason = "Protected save restore failed: $($_.Exception.Message)"
                    Write-Warning $saveRestoreSkippedReason
                }
            }
        } else {
            $saveRestoreSkippedReason = "Protected save backup did not complete; restore was not attempted."
            Write-Warning $saveRestoreSkippedReason
        }
    }
}

$result = [pscustomobject]@{
    Mode = "Completed"
    GamePath = $resolvedGamePath
    ArtifactLabel = $ArtifactLabel
    CandidateStage = $CandidateStage
    Results = $results
    ComparisonArtifact = $(if ($comparison) { $comparison.OutputPath } else { "" })
    MeanAbsRgbDelta = $(if ($comparison) { $comparison.MeanAbsRgbDelta } else { $null })
    MaxAbsRgbDelta = $(if ($comparison) { $comparison.MaxAbsRgbDelta } else { $null })
    ChangedRatioGt10 = $(if ($comparison) { $comparison.ChangedRatioGt10 } else { $null })
    BaselineSha256 = $(if ($comparison) { $comparison.BaselineSha256 } else { "" })
    CandidateSha256 = $(if ($comparison) { $comparison.CandidateSha256 } else { "" })
    FsrMode = $FsrMode
    PreviousFsrMode = $previousFsrMode
    RestoredFsrMode = $restoredFsrMode
    FsrBackupPath = $fsrBackupPath
    SetClientResolution = [bool]$SetClientResolution
    SetClientWindowMode = [bool]$SetClientWindowMode
    Width = $(if ($SetClientResolution) { $Width } else { 0 })
    Height = $(if ($SetClientResolution) { $Height } else { 0 })
    ClientWindowMode = $(if ($SetClientWindowMode) { $ClientWindowMode } else { $null })
    RestoredClientSettings = $restoredClientSettings
    ClientSettingsBackupArtifact = $(if (Test-Path -LiteralPath $clientSettingsBackupArtifact) { $clientSettingsBackupArtifact } else { "" })
    BepInExConfigPath = $bepInExConfigPath
    BepInExConfigBackupArtifact = $(if (Test-Path -LiteralPath $bepInExConfigBackupArtifact) { $bepInExConfigBackupArtifact } else { "" })
    RestoredBepInExConfig = $restoredBepInExConfig
    ProtectSave = [bool]$ProtectSave
    SaveDir = $(if ($ProtectSave) { $saveDirResolved } else { "" })
    SaveProtectionLabel = $(if ($ProtectSave) { $saveProtectionLabel } else { "" })
    SaveBackupDir = $(if ($saveBackup) { [string]$saveBackup.BackupDir } else { "" })
    SaveBackupZipPath = $(if ($saveBackup) { [string]$saveBackup.ZipPath } else { "" })
    SaveBackupManifestPath = $(if ($saveBackup) { [string]$saveBackup.ManifestPath } else { "" })
    SaveRestoreAttempted = $saveRestoreAttempted
    SaveRestored = $saveRestored
    SaveRestoreArchivePath = $(if ($saveRestore) { [string]$saveRestore.ArchivePath } else { "" })
    SaveBeforeRestoreChangeCount = $(if ($saveRestore) { [int]$saveRestore.BeforeChangeCount } else { $null })
    SaveAfterRestoreChangeCount = $(if ($saveRestore) { [int]$saveRestore.ChangeCount } else { $null })
    SaveCompareStatus = $(if ($saveRestore) { [string]$saveRestore.CompareStatus } else { "" })
    SaveRestoreSkippedReason = $saveRestoreSkippedReason
    ArchiveChangedSave = $(if ($ProtectSave) { $archiveChangedSaveEnabled } else { $false })
    ProcessStillRunning = [bool](Get-VRisingProcess)
    RestoredReleaseSafeState = $true
    LaunchesGame = ($Mode -ne "BaselineOnly") -or (-not [bool]$AttachExistingBaseline)
}

$result

if ($ProtectSave -and -not $saveRestored) {
    exit 1
}

if ($bepInExConfigChanged -and -not $restoredBepInExConfig) {
    exit 1
}
