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
        "native-renderfunc-entry",
        "native-renderfunc-args",
        "native-renderfunc-resource-identity",
        "native-renderfunc-resource-tuple",
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
    [string]$ArtifactLabel,
    [string]$DlssRuntimePath = "",
    [string]$DlssApplicationId = "0",
    [switch]$UseSdkWrapperNative,
    [string]$SdkWrapperNativePath,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$WaitForWindowSeconds = 90,
    [int]$WaitForNonBlankScreenshotSeconds = 90,
    [int]$ScreenshotRetrySeconds = 3,
    [ValidateSet("Auto", "PrintWindow", "ScreenCopy")]
    [string]$ScreenshotMethod = "Auto",
    [switch]$SetClientResolution,
    [switch]$SetClientWindowMode,
    [ValidateRange(0, 3)]
    [int]$ClientWindowMode = 3,
    [switch]$SkipInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($Width -lt 640 -or $Height -lt 480) {
    throw "Width/Height are too small for a useful V Rising automation session."
}

if ($WaitForWindowSeconds -lt 5) {
    throw "WaitForWindowSeconds must be at least 5."
}

if ($WaitForNonBlankScreenshotSeconds -lt 0) {
    throw "WaitForNonBlankScreenshotSeconds cannot be negative."
}

if ($ScreenshotRetrySeconds -lt 1) {
    throw "ScreenshotRetrySeconds must be at least 1."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
$exePath = Join-Path $resolvedGamePath "VRising.exe"
$pluginPath = Join-Path $resolvedGamePath "BepInEx\plugins\VrisingDLSS"
$nativeTargetPath = Join-Path $pluginPath "VrisingDLSS.Native.dll"
$artifactRoot = Join-Path $resolvedRoot "artifacts\gameplay-automation"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "automation-session-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "VRising.exe was not found: $exePath"
}

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
        throw "SDK-wrapper automation session requires -DlssRuntimePath pointing to a local nvngx_dlss.dll."
    }
}

function Get-VRisingProcess {
    Get-Process VRising -ErrorAction SilentlyContinue
}

function Close-VRisingProcess {
    param([System.Diagnostics.Process]$Process)

    $closed = $false
    if (-not $Process) {
        return $closed
    }

    $live = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
    if (-not $live) {
        return $closed
    }

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

    return $true
}

$sessionArtifact = Join-Path $artifactRoot "Session-$ArtifactLabel.json"
$playerLogArtifact = Join-Path $artifactRoot "Player-$ArtifactLabel.log"
$bepInExLogArtifact = Join-Path $artifactRoot "LogOutput-$ArtifactLabel.log"
$analysisArtifact = Join-Path $artifactRoot "Analysis-$ArtifactLabel.txt"
$visibilityArtifact = Join-Path $artifactRoot "Visibility-$ArtifactLabel.json"
$screenshotArtifact = Join-Path $artifactRoot "SessionScreenshot-$ArtifactLabel.png"
$clientSettingsPath = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Settings\v4\ClientSettings.json"
$clientSettingsBackupArtifact = Join-Path $artifactRoot "ClientSettings-$ArtifactLabel.before.json"

$launchArgs = @(
    "-windowed",
    "-screen-width", "$Width",
    "-screen-height", "$Height",
    "-screen-fullscreen", "0",
    "-force-d3d11",
    "-single-instance",
    "-logFile", $playerLogArtifact
)

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "StartSession" })
    Question = "Can Codex start V Rising in a controlled diagnostic state and leave the UnityWndClass window open for a bounded UI automation proof?"
    Hypothesis = "The proven launch/window/screenshot path can prepare a Computer Use UI-navigation session if the session artifact records diagnostic stage, native-DLL state, and cleanup requirements."
    ExpectedEvidence = @(
        "Session JSON with process id and cleanup requirements",
        "VisibleGameWindow from inspect-vrising-visibility.ps1",
        "A nonblank session screenshot",
        "Player log redirected to the artifact path",
        "ClientSettings backup path when -SetClientResolution or -SetClientWindowMode is used",
        "Stage/native-DLL restore requirements when a diagnostic stage is used"
    )
    PassSignal = "Status=Ready and CleanupRequired=true in the session JSON."
    FailSignal = "No visible window, invalid screenshot, early exit, or setup failure; failed starts clean up immediately."
    CleanupPath = "Run scripts\stop-vrising-automation-session.ps1 with the session artifact path."
    GamePath = $resolvedGamePath
    Stage = $Stage
    UseSdkWrapperNative = [bool]$UseSdkWrapperNative
    SdkWrapperNativePath = $(if ($sdkWrapperNativeResolved) { $sdkWrapperNativeResolved } else { "" })
    DlssRuntimePath = $DlssRuntimePath
    DlssApplicationId = $DlssApplicationId
    LaunchArgs = $launchArgs
    SetClientResolution = [bool]$SetClientResolution
    SetClientWindowMode = [bool]$SetClientWindowMode
    ClientWindowMode = $(if ($SetClientWindowMode) { $ClientWindowMode } else { $null })
    ClientSettingsPath = $clientSettingsPath
    ClientSettingsBackupArtifact = $(if ($SetClientResolution -or $SetClientWindowMode) { $clientSettingsBackupArtifact } else { "" })
    ScreenshotMethod = $ScreenshotMethod
    ArtifactLabel = $ArtifactLabel
    SessionArtifact = $sessionArtifact
    ScreenshotArtifact = $screenshotArtifact
    PlayerLogArtifact = $playerLogArtifact
    BepInExLogArtifact = $bepInExLogArtifact
    AnalysisArtifact = $analysisArtifact
    VisibilityArtifact = $visibilityArtifact
    RestoresLoaderConfig = $true
    RestoresReleaseSafeNative = [bool]$UseSdkWrapperNative
    LeavesGameRunning = -not [bool]$DryRun
    LaunchesGame = -not [bool]$DryRun
}

if ($DryRun) {
    $plan
    return
}

$existing = Get-VRisingProcess | Select-Object -First 1
if ($existing) {
    throw "VRising is already running (pid=$($existing.Id)). Close it before starting an automation session."
}

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null

$runStart = Get-Date
$process = $null
$visibility = $null
$captureResult = $null
$screenshotCreated = $false
$screenshotAccepted = $false
$clientSettingsChanged = [bool]($SetClientResolution -or $SetClientWindowMode)
$restoredClientSettings = -not $clientSettingsChanged
$restoredLoaderConfig = $false
$restoredReleaseSafeNative = -not [bool]$UseSdkWrapperNative
$status = "Failed"
$failureReason = ""
$cleanupRequired = $false

try {
    if (-not $SkipInstall) {
        & (Join-Path $resolvedRoot "scripts\install-local-package.ps1") -GamePath $resolvedGamePath | Out-Host
    }

    if ($UseSdkWrapperNative) {
        New-Item -ItemType Directory -Force -Path $pluginPath | Out-Null
        Copy-Item -LiteralPath $sdkWrapperNativeResolved -Destination $nativeTargetPath -Force
        Write-Host "Copied SDK-wrapper native DLL for automation session: $sdkWrapperNativeResolved"
        $restoredReleaseSafeNative = $false
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

    Write-Host "AutomationSessionStart=$($runStart.ToString('o'))"
    Write-Host "ArtifactLabel=$ArtifactLabel"
    Write-Host "LaunchArgs=$($launchArgs -join ' ')"

    $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -ArgumentList $launchArgs -PassThru
    $cleanupRequired = $true
    Write-Host "Started VRising pid=$($process.Id)"

    $deadline = (Get-Date).AddSeconds($WaitForWindowSeconds)
    do {
        if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
            $failureReason = "VRising exited before a visible game window was detected."
            break
        }

        $visibilityJson = & (Join-Path $resolvedRoot "scripts\inspect-vrising-visibility.ps1") `
            -GamePath $resolvedGamePath `
            -SearchGamePathProcesses `
            -Json
        $visibilityJson | Set-Content -LiteralPath $visibilityArtifact -Encoding UTF8
        $visibility = $visibilityJson | ConvertFrom-Json

        if ($visibility.Status -eq "VisibleGameWindow") {
            break
        }

        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    if (-not $visibility -or $visibility.Status -ne "VisibleGameWindow") {
        if ([string]::IsNullOrWhiteSpace($failureReason)) {
            $failureReason = "VisibleGameWindow was not detected before timeout."
        }
    } else {
        $screenshotDeadline = (Get-Date).AddSeconds($WaitForNonBlankScreenshotSeconds)
        do {
            $captureOutput = & (Join-Path $resolvedRoot "scripts\capture-vrising-window.ps1") `
                -OutputPath $screenshotArtifact `
                -ArtifactLabel "$ArtifactLabel-session" `
                -Method $ScreenshotMethod `
                -WaitSeconds 0
            $captureOutput | Out-Host
            $captureResult = @($captureOutput)[-1]
            $screenshotCreated = Test-Path -LiteralPath $screenshotArtifact

            if ($screenshotCreated -and $captureResult) {
                $nearBlack = [double]$captureResult.NearBlackRatio
                $nearWhite = [double]$captureResult.NearWhiteRatio
                $averageLuma = [double]$captureResult.AverageLuma
                $screenshotAccepted = ($nearBlack -lt 0.98 -and $nearWhite -lt 0.98 -and $averageLuma -gt 1.0)
                if ($screenshotAccepted) {
                    break
                }

                Write-Host "Session screenshot not accepted yet: Width=$($captureResult.Width) Height=$($captureResult.Height) NearBlackRatio=$nearBlack NearWhiteRatio=$nearWhite AverageLuma=$averageLuma"
            }

            if ((Get-Date) -ge $screenshotDeadline) {
                break
            }

            Start-Sleep -Seconds $ScreenshotRetrySeconds
        } while ($true)

        if ($screenshotCreated -and $screenshotAccepted) {
            $status = "Ready"
        } elseif ($screenshotCreated) {
            $failureReason = "Session screenshot was created but remained blank/invalid before timeout."
        } else {
            $failureReason = "Session screenshot was not created."
        }
    }
} catch {
    $failureReason = $_.Exception.Message
} finally {
    if ($status -ne "Ready") {
        if ($process) {
            [void](Close-VRisingProcess -Process $process)
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
            $cleanupRequired = $false
        } catch {
            Write-Warning "Failed-start cleanup failed: $($_.Exception.Message)"
        }
    }

    $runEnd = Get-Date
    $result = [pscustomobject]@{
        Mode = "StartSession"
        Status = $status
        FailureReason = $failureReason
        GamePath = $resolvedGamePath
        Stage = $Stage
        ArtifactLabel = $ArtifactLabel
        StartedAt = $runStart.ToString("o")
        EndedAt = $runEnd.ToString("o")
        ProcessId = $(if ($process) { $process.Id } else { $null })
        UseSdkWrapperNative = [bool]$UseSdkWrapperNative
        SdkWrapperNativePath = $(if ($sdkWrapperNativeResolved) { $sdkWrapperNativeResolved } else { "" })
        DlssRuntimePath = $DlssRuntimePath
        DlssApplicationId = $DlssApplicationId
        LaunchArgs = $launchArgs
        VisibilityStatus = $(if ($visibility) { $visibility.Status } else { "" })
        SelectedWindowHandle = $(if ($visibility -and $visibility.SelectedWindow) { [string]$visibility.SelectedWindow.Handle } else { "" })
        ScreenshotCreated = $screenshotCreated
        ScreenshotAccepted = $screenshotAccepted
        ScreenshotWidth = $(if ($captureResult) { [int]$captureResult.Width } else { $null })
        ScreenshotHeight = $(if ($captureResult) { [int]$captureResult.Height } else { $null })
        ScreenshotNearBlackRatio = $(if ($captureResult) { [double]$captureResult.NearBlackRatio } else { $null })
        ScreenshotNearWhiteRatio = $(if ($captureResult) { [double]$captureResult.NearWhiteRatio } else { $null })
        ScreenshotAverageLuma = $(if ($captureResult) { [double]$captureResult.AverageLuma } else { $null })
        SessionArtifact = $sessionArtifact
        ScreenshotArtifact = $(if (Test-Path -LiteralPath $screenshotArtifact) { $screenshotArtifact } else { "" })
        PlayerLogArtifact = $playerLogArtifact
        BepInExLogArtifact = $bepInExLogArtifact
        AnalysisArtifact = $analysisArtifact
        VisibilityArtifact = $(if (Test-Path -LiteralPath $visibilityArtifact) { $visibilityArtifact } else { "" })
        SetClientResolution = [bool]$SetClientResolution
        SetClientWindowMode = [bool]$SetClientWindowMode
        ClientWindowMode = $(if ($SetClientWindowMode) { $ClientWindowMode } else { $null })
        ClientSettingsPath = $clientSettingsPath
        ClientSettingsBackupArtifact = $(if (Test-Path -LiteralPath $clientSettingsBackupArtifact) { $clientSettingsBackupArtifact } else { "" })
        RestoredClientSettings = $restoredClientSettings
        RestoredLoaderConfig = $restoredLoaderConfig
        RestoredReleaseSafeNative = $restoredReleaseSafeNative
        CleanupRequired = $cleanupRequired
        CleanupCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-vrising-automation-session.ps1 -SessionPath `"$sessionArtifact`""
        RemainingVRisingProcessCount = @(Get-VRisingProcess).Count
        LeavesGameRunning = $status -eq "Ready"
        LaunchesGame = $true
    }

    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sessionArtifact -Encoding UTF8
    $result
}

if ($status -ne "Ready") {
    exit 1
}
