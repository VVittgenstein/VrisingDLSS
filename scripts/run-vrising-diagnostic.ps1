param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [ValidateSet(
        "loader",
        "native",
        "harmony-call",
        "render-thread",
        "d3d11",
        "frame-resource",
        "upscaler-state",
        "dlss-runtime",
        "dlss-init-query",
        "dlss-optimal-settings",
        "dlss-feature-create",
        "dlss-evaluate-inputs",
        "dlss-super-resolution-inputs",
        "dlss-super-resolution-evaluate",
        "dlss-super-resolution-persistent-evaluate",
        "dlss-super-resolution-frame-sequence",
        "dlss-visible-writeback",
        "rendergraph-pass-boundary",
        "rendergraph-pass-map",
        "rendergraph-pass-list",
        "rendergraph-pass-declarations",
        "rendergraph-pass-data",
        "rendergraph-renderfunc-metadata",
        "rendergraph-compiled-pass-info",
        "rendergraph-execute-delegate",
        "render-scale-control",
        "dlss-user-rendering",
        "dlss-user-rendering-cached-driver",
        "dlss-user-rendering-no-evaluate",
        "dlss-user-rendering-materialization-no-evaluate",
        "dlss-user-rendering-cached-driver-no-evaluate",
        "dlss-evaluate",
        "dlss-persistent-evaluate",
        "dlsspass-resource"
    )]
    [string]$Stage = "loader",

    [string]$Root,
    [int]$DurationSeconds = 75,
    [string]$ArtifactLabel,
    [string]$DlssRuntimePath = "",
    [string]$DlssApplicationId = "0",
    [switch]$UseSdkWrapperNative,
    [string]$SdkWrapperNativePath,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [switch]$SetClientResolution,
    [switch]$SetClientWindowMode,
    [ValidateRange(0, 3)]
    [int]$ClientWindowMode = 3,
    [switch]$SkipInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($DurationSeconds -lt 5) {
    throw "DurationSeconds must be at least 5."
}

if ($Width -lt 640 -or $Height -lt 480) {
    throw "Width/Height are too small for a useful diagnostic run."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
$exePath = Join-Path $resolvedGamePath "VRising.exe"
$logPath = Join-Path $resolvedGamePath "BepInEx\LogOutput.log"
$pluginPath = Join-Path $resolvedGamePath "BepInEx\plugins\VrisingDLSS"
$nativeTargetPath = Join-Path $pluginPath "VrisingDLSS.Native.dll"
$artifactRoot = Join-Path $resolvedRoot "artifacts\runtime-logs"
$clientSettingsPath = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Settings\v4\ClientSettings.json"
$safeStage = $Stage -replace "[^A-Za-z0-9_.-]", "-"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($SdkWrapperNativePath)) {
    $SdkWrapperNativePath = Join-Path $resolvedRoot "artifacts\native-build-msvc-wrapper\Release\VrisingDLSS.Native.dll"
}

$sdkWrapperNativeResolved = $null
if ($UseSdkWrapperNative) {
    if (-not (Test-Path -LiteralPath $SdkWrapperNativePath)) {
        throw "SDK-wrapper native DLL was not found: $SdkWrapperNativePath"
    }

    $sdkWrapperNativeResolved = (Resolve-Path -LiteralPath $SdkWrapperNativePath).Path
    if ([string]::IsNullOrWhiteSpace($DlssRuntimePath) -or -not (Test-Path -LiteralPath $DlssRuntimePath)) {
        throw "SDK-wrapper diagnostic run requires -DlssRuntimePath pointing to a local nvngx_dlss.dll."
    }
}

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "$safeStage-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "VRising.exe was not found: $exePath"
}

function Get-VRisingProcess {
    Get-Process VRising -ErrorAction SilentlyContinue
}

function Get-PlayerLogResolutionInfo {
    param([string]$Path)

    $info = [ordered]@{
        Width = $null
        Height = $null
        FullScreenMode = ""
        SetResolutionLine = ""
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]$info
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match "SetResolution\s+(\d+),\s*(\d+),\s*fullScreenMode\s+(\S+)") {
            $info.Width = [int]$Matches[1]
            $info.Height = [int]$Matches[2]
            $info.FullScreenMode = [string]$Matches[3]
            $info.SetResolutionLine = [string]$line
        }
    }

    [pscustomobject]$info
}

$existingProcess = Get-VRisingProcess | Select-Object -First 1
if ($existingProcess) {
    throw "VRising is already running (pid=$($existingProcess.Id)). Close it before running a scripted diagnostic."
}

$clientSettingsChanged = [bool]($SetClientResolution -or $SetClientWindowMode)
$clientSettingsBackupArtifact = Join-Path $artifactRoot "ClientSettings-$ArtifactLabel.before.json"
$playerLogArtifact = Join-Path $artifactRoot "Player-$ArtifactLabel.log"
$launchArgs = @()
if ($clientSettingsChanged) {
    $launchArgs = @(
        "-windowed",
        "-screen-width", "$Width",
        "-screen-height", "$Height",
        "-screen-fullscreen", "0",
        "-force-d3d11",
        "-single-instance",
        "-logFile", $playerLogArtifact
    )
}

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "Run" })
    GamePath = $resolvedGamePath
    Stage = $Stage
    DurationSeconds = $DurationSeconds
    ArtifactLabel = $ArtifactLabel
    SkipInstall = [bool]$SkipInstall
    UseSdkWrapperNative = [bool]$UseSdkWrapperNative
    SdkWrapperNativePath = $(if ($sdkWrapperNativeResolved) { $sdkWrapperNativeResolved } else { "" })
    LogArtifact = (Join-Path $artifactRoot "LogOutput-$ArtifactLabel.log")
    AnalysisArtifact = (Join-Path $artifactRoot "Analysis-$ArtifactLabel.txt")
    WerArtifact = (Join-Path $artifactRoot "WER-$ArtifactLabel.txt")
    PlayerLogArtifact = $playerLogArtifact
    LaunchArgs = $launchArgs
    SetClientResolution = [bool]$SetClientResolution
    SetClientWindowMode = [bool]$SetClientWindowMode
    ClientWindowMode = $(if ($SetClientWindowMode) { $ClientWindowMode } else { $null })
    ClientSettingsPath = $clientSettingsPath
    ClientSettingsBackupArtifact = $(if ($clientSettingsChanged) { $clientSettingsBackupArtifact } else { "" })
    RestoresLoaderConfig = $true
    RestoresReleaseSafeNative = [bool]$UseSdkWrapperNative
    RestoresClientSettings = $clientSettingsChanged
    LaunchesGame = -not [bool]$DryRun
}

if ($DryRun) {
    $plan
    return
}

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null

$runStart = Get-Date
$process = $null
$closedByScript = $false
$exitBeforeWindow = $false
$crashEvents = @()
$restoredLoaderConfig = $false
$restoredReleaseSafeNative = -not [bool]$UseSdkWrapperNative
$restoredClientSettings = -not $clientSettingsChanged
$playerLogResolutionInfo = $null

try {
    if (-not $SkipInstall) {
        & (Join-Path $resolvedRoot "scripts\install-local-package.ps1") -GamePath $resolvedGamePath | Out-Host
    }

    if ($UseSdkWrapperNative) {
        New-Item -ItemType Directory -Force -Path $pluginPath | Out-Null
        Copy-Item -LiteralPath $sdkWrapperNativeResolved -Destination $nativeTargetPath -Force
        Write-Host "Copied SDK-wrapper native DLL for diagnostic run: $sdkWrapperNativeResolved"
    }

    & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") `
        -GamePath $resolvedGamePath `
        -Stage $Stage `
        -DlssRuntimePath $DlssRuntimePath `
        -DlssApplicationId $DlssApplicationId |
        Out-Host

    if ($clientSettingsChanged) {
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

    Write-Host "DiagnosticRunStart=$($runStart.ToString('o'))"
    Write-Host "DiagnosticStage=$Stage"
    Write-Host "ArtifactLabel=$ArtifactLabel"

    $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -ArgumentList $launchArgs -PassThru
    Write-Host "Started VRising pid=$($process.Id)"

    $deadline = (Get-Date).AddSeconds($DurationSeconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
            $exitBeforeWindow = $true
            break
        }

        Start-Sleep -Seconds 3
    }

    $liveProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if ($liveProcess) {
        Write-Host "VRising still running after diagnostic window; closing pid=$($liveProcess.Id)"
        try {
            [void]$liveProcess.CloseMainWindow()
        } catch {
            Write-Warning "CloseMainWindow failed: $($_.Exception.Message)"
        }

        Start-Sleep -Seconds 8
        $liveProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        if ($liveProcess) {
            Write-Host "VRising did not close gracefully; stopping pid=$($liveProcess.Id)"
            Stop-Process -Id $liveProcess.Id -Force
            Start-Sleep -Seconds 2
        }

        $closedByScript = $true
    } else {
        Write-Host "VRising exited before diagnostic window ended."
    }
} finally {
    $runEnd = Get-Date

    try {
        if ($process) {
            $liveProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
            if ($liveProcess) {
                Write-Host "VRising is still running during cleanup; closing pid=$($liveProcess.Id)"
                try {
                    [void]$liveProcess.CloseMainWindow()
                } catch {
                    Write-Warning "Cleanup CloseMainWindow failed: $($_.Exception.Message)"
                }

                Start-Sleep -Seconds 8
                $liveProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                if ($liveProcess) {
                    Write-Host "VRising did not close during cleanup; stopping pid=$($liveProcess.Id)"
                    Stop-Process -Id $liveProcess.Id -Force
                    Start-Sleep -Seconds 2
                }

                $closedByScript = $true
            }
        }
    } catch {
        Write-Warning "Cleanup process close failed: $($_.Exception.Message)"
    }

    try {
        if (-not (Test-Path -LiteralPath $playerLogArtifact)) {
            $defaultPlayerLog = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Player.log"
            if (Test-Path -LiteralPath $defaultPlayerLog) {
                Copy-Item -LiteralPath $defaultPlayerLog -Destination $playerLogArtifact -Force
            }
        }

        $playerLogResolutionInfo = Get-PlayerLogResolutionInfo -Path $playerLogArtifact
    } catch {
        Write-Warning "Player log archive/parse failed: $($_.Exception.Message)"
    }

    try {
        if (Test-Path -LiteralPath $logPath) {
            Copy-Item -LiteralPath $logPath -Destination $plan.LogArtifact -Force
            & (Join-Path $resolvedRoot "scripts\analyze-bepinex-log.ps1") -LogPath $plan.LogArtifact |
                Out-String -Width 220 |
                Set-Content -LiteralPath $plan.AnalysisArtifact -Encoding UTF8
        }
    } catch {
        Write-Warning "Log archive/analyze failed: $($_.Exception.Message)"
    }

    try {
        $crashEvents = @(Get-WinEvent -FilterHashtable @{
                ProviderName = "Application Error"
                StartTime = $runStart.AddSeconds(-5)
                EndTime = $runEnd.AddSeconds(10)
            } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match "VRising|UnityPlayer|coreclr|VrisingDLSS" } |
            Select-Object TimeCreated, Id, ProviderName, Message)

        if ($crashEvents.Count -gt 0) {
            $crashEvents | Format-List | Out-String -Width 220 | Set-Content -LiteralPath $plan.WerArtifact -Encoding UTF8
        }
    } catch {
        Write-Warning "WER archive failed: $($_.Exception.Message)"
    }

    try {
        if ($UseSdkWrapperNative) {
            & (Join-Path $resolvedRoot "scripts\install-local-package.ps1") -GamePath $resolvedGamePath | Out-Host
            $restoredReleaseSafeNative = $true
        }

        if ($clientSettingsChanged -and (Test-Path -LiteralPath $clientSettingsBackupArtifact)) {
            Copy-Item -LiteralPath $clientSettingsBackupArtifact -Destination $clientSettingsPath -Force
            $restoredClientSettings = $true
        }

        & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") -GamePath $resolvedGamePath -Stage loader | Out-Host
        $restoredLoaderConfig = $true
    } catch {
        Write-Warning "Restoring release-safe native/loader config failed: $($_.Exception.Message)"
    }
}

[pscustomobject]@{
    Mode = "Completed"
    GamePath = $resolvedGamePath
    Stage = $Stage
    DurationSeconds = $DurationSeconds
    ArtifactLabel = $ArtifactLabel
    LogArtifact = $(if (Test-Path -LiteralPath $plan.LogArtifact) { $plan.LogArtifact } else { "" })
    AnalysisArtifact = $(if (Test-Path -LiteralPath $plan.AnalysisArtifact) { $plan.AnalysisArtifact } else { "" })
    WerArtifact = $(if (Test-Path -LiteralPath $plan.WerArtifact) { $plan.WerArtifact } else { "" })
    PlayerLogArtifact = $(if (Test-Path -LiteralPath $playerLogArtifact) { $playerLogArtifact } else { "" })
    LaunchArgs = $launchArgs
    CrashEventCount = $crashEvents.Count
    ExitedBeforeWindow = $exitBeforeWindow
    ClosedByScript = $closedByScript
    RestoredLoaderConfig = $restoredLoaderConfig
    RestoredReleaseSafeNative = $restoredReleaseSafeNative
    SetClientResolution = [bool]$SetClientResolution
    SetClientWindowMode = [bool]$SetClientWindowMode
    ClientWindowMode = $(if ($SetClientWindowMode) { $ClientWindowMode } else { $null })
    RestoredClientSettings = $restoredClientSettings
    ClientSettingsBackupArtifact = $(if (Test-Path -LiteralPath $clientSettingsBackupArtifact) { $clientSettingsBackupArtifact } else { "" })
    GameReportedWidth = $(if ($playerLogResolutionInfo) { $playerLogResolutionInfo.Width } else { $null })
    GameReportedHeight = $(if ($playerLogResolutionInfo) { $playerLogResolutionInfo.Height } else { $null })
    GameReportedFullScreenMode = $(if ($playerLogResolutionInfo) { $playerLogResolutionInfo.FullScreenMode } else { "" })
    GameReportedSetResolutionLine = $(if ($playerLogResolutionInfo) { $playerLogResolutionInfo.SetResolutionLine } else { "" })
    LaunchesGame = $true
}
