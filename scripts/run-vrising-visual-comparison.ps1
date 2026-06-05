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
    [string]$DlssRuntimePath = "",
    [string]$DlssApplicationId = "0",
    [string]$SdkWrapperNativePath,
    [switch]$SkipInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

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
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "gameplay-visual-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
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

function Invoke-VisualRun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [bool]$UseSdkWrapperNative
    )

    $runStart = Get-Date
    $process = $null
    $capture = $null
    $closedByScript = $false
    $exitedBeforeCapture = $false

    try {
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
        } | Out-Host

        Write-Host "VisualRunStart=$($runStart.ToString('o'))"
        Write-Host "VisualRunStage=$Stage"
        Write-Host "VisualRunLabel=$Label"
        Write-Host "Enter the same local/private gameplay scene before capture at +$CaptureAtSeconds seconds."

        $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -PassThru
        Write-Host "Started VRising pid=$($process.Id)"

        if (-not (Wait-UntilRunSecond -Process $process -RunStart $runStart -Second $CaptureAtSeconds)) {
            $exitedBeforeCapture = $true
        } else {
            $capture = Invoke-ProjectScript -RelativePath "scripts\capture-vrising-window.ps1" -Parameters @{
                ArtifactLabel = $Label
                WaitSeconds = $CaptureWaitSeconds
            }
            $capture | Format-List | Out-String -Width 220 | Write-Host
        }

        if (-not $exitedBeforeCapture) {
            [void](Wait-UntilRunSecond -Process $process -RunStart $runStart -Second $DurationSeconds)
        }
    } finally {
        $closedByScript = Close-VisualRunProcess -Process $process
        $runEnd = Get-Date
        $archived = Archive-VisualRunLog -Label $Label -RunStart $runStart -RunEnd $runEnd
        Restore-ReleaseSafeState
    }

    [pscustomobject]@{
        Mode = "VisualRunCompleted"
        Stage = $Stage
        Label = $Label
        CapturePath = $(if ($capture) { $capture.Path } else { "" })
        CaptureMethod = $(if ($capture) { $capture.Method } else { "" })
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
        LaunchesGame = $true
    }
}

$existingProcess = Get-VRisingProcess | Select-Object -First 1
if ($existingProcess) {
    throw "VRising is already running (pid=$($existingProcess.Id)). Close it before running visual comparison."
}

$baselineLabel = "$ArtifactLabel-baseline-loader"
$candidateLabel = "$ArtifactLabel-stage10a-visible-writeback"
$comparisonLabel = "$ArtifactLabel-baseline-vs-stage10a"
$baselinePath = Join-Path $visualRoot "$baselineLabel.png"
$candidatePath = Join-Path $visualRoot "$candidateLabel.png"
$comparisonPath = Join-Path $visualRoot "$comparisonLabel.txt"

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { $Mode })
    GamePath = $resolvedGamePath
    DurationSeconds = $DurationSeconds
    CaptureAtSeconds = $CaptureAtSeconds
    CaptureWaitSeconds = $CaptureWaitSeconds
    ArtifactLabel = $ArtifactLabel
    BaselineCapture = $(if ($Mode -ne "CandidateOnly") { $baselinePath } else { "" })
    CandidateCapture = $(if ($Mode -ne "BaselineOnly") { $candidatePath } else { "" })
    ComparisonArtifact = $(if ($Mode -eq "Paired") { $comparisonPath } else { "" })
    DlssRuntimePath = $DlssRuntimePath
    SdkWrapperNativePath = $(if ($Mode -ne "BaselineOnly") { $sdkWrapperNativeResolved } else { "" })
    RestoresReleaseSafeState = $true
    LaunchesGame = -not [bool]$DryRun
}

if ($DryRun) {
    $plan
    return
}

New-Item -ItemType Directory -Force -Path $runtimeLogRoot, $visualRoot | Out-Null

$results = New-Object System.Collections.Generic.List[object]

if ($Mode -ne "CandidateOnly") {
    $results.Add((Invoke-VisualRun -Stage "loader" -Label $baselineLabel -UseSdkWrapperNative $false))
}

if ($Mode -ne "BaselineOnly") {
    $results.Add((Invoke-VisualRun -Stage "dlss-visible-writeback" -Label $candidateLabel -UseSdkWrapperNative $true))
}

$comparison = $null
if ($Mode -eq "Paired") {
    $baseline = $results | Where-Object { $_.Stage -eq "loader" } | Select-Object -First 1
    $candidate = $results | Where-Object { $_.Stage -eq "dlss-visible-writeback" } | Select-Object -First 1
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

[pscustomobject]@{
    Mode = "Completed"
    GamePath = $resolvedGamePath
    ArtifactLabel = $ArtifactLabel
    Results = $results
    ComparisonArtifact = $(if ($comparison) { $comparison.OutputPath } else { "" })
    MeanAbsRgbDelta = $(if ($comparison) { $comparison.MeanAbsRgbDelta } else { $null })
    MaxAbsRgbDelta = $(if ($comparison) { $comparison.MaxAbsRgbDelta } else { $null })
    ChangedRatioGt10 = $(if ($comparison) { $comparison.ChangedRatioGt10 } else { $null })
    BaselineSha256 = $(if ($comparison) { $comparison.BaselineSha256 } else { "" })
    CandidateSha256 = $(if ($comparison) { $comparison.CandidateSha256 } else { "" })
    ProcessStillRunning = [bool](Get-VRisingProcess)
    RestoredReleaseSafeState = $true
    LaunchesGame = $true
}
