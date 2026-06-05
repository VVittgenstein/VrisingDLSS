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
    [bool]$WaitForStage10A = $true,
    [int]$Stage10ATimeoutSeconds = 600,
    [bool]$KeepCandidateWritebackRunning = $true,
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

if ($ReadyTimeoutSeconds -lt 30) {
    throw "ReadyTimeoutSeconds must be at least 30."
}

if ($Stage10ATimeoutSeconds -lt 30) {
    throw "Stage10ATimeoutSeconds must be at least 30."
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

if ([string]::IsNullOrWhiteSpace($ReadyFile)) {
    $ReadyFile = Join-Path $visualRoot "$ArtifactLabel.ready"
} elseif (-not [System.IO.Path]::IsPathRooted($ReadyFile)) {
    $ReadyFile = Join-Path $resolvedRoot $ReadyFile
}

$readyFileResolved = [System.IO.Path]::GetFullPath($ReadyFile)

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
    $captureReadyTimedOut = $false
    $manualReadyDetectedAt = $null
    $stage10AReadyTimedOut = $false
    $stage10ADetectedAt = $null
    $waitedForStage10A = $WaitForStage10A -and $UseSdkWrapperNative -and $Stage -eq "dlss-visible-writeback"

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
            KeepVisibleWritebackRunning = ($UseSdkWrapperNative -and $Stage -eq "dlss-visible-writeback" -and $KeepCandidateWritebackRunning)
        } | Out-Host

        Write-Host "VisualRunStart=$($runStart.ToString('o'))"
        Write-Host "VisualRunStage=$Stage"
        Write-Host "VisualRunLabel=$Label"
        if ($ManualCapture) {
            Write-Host "Enter the same local/private gameplay scene, then create the ready file when the scene is stable."
        } else {
            Write-Host "Enter the same local/private gameplay scene before capture at +$CaptureAtSeconds seconds."
        }

        $logStartOffset = if (Test-Path -LiteralPath $logPath) { (Get-Item -LiteralPath $logPath).Length } else { 0L }
        $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -PassThru
        Write-Host "Started VRising pid=$($process.Id)"

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

        if (-not $exitedBeforeCapture -and -not $captureReadyTimedOut -and -not $stage10AReadyTimedOut) {
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
        ManualCapture = [bool]$ManualCapture
        ManualReadyFile = $(if ($ManualCapture) { $readyFileResolved } else { "" })
        ManualReadyDetectedAt = $(if ($manualReadyDetectedAt) { $manualReadyDetectedAt.ToString("o") } else { "" })
        CaptureReadyTimedOut = $captureReadyTimedOut
        WaitedForStage10A = $waitedForStage10A
        Stage10ADetectedAt = $(if ($stage10ADetectedAt) { $stage10ADetectedAt.ToString("o") } else { "" })
        Stage10AReadyTimedOut = $stage10AReadyTimedOut
        KeepCandidateWritebackRunning = $(if ($UseSdkWrapperNative -and $Stage -eq "dlss-visible-writeback") { $KeepCandidateWritebackRunning } else { $false })
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
    ManualCapture = [bool]$ManualCapture
    ReadyFile = $(if ($ManualCapture) { $readyFileResolved } else { "" })
    ReadyTimeoutSeconds = $(if ($ManualCapture) { $ReadyTimeoutSeconds } else { 0 })
    WaitForStage10A = [bool]$WaitForStage10A
    Stage10ATimeoutSeconds = $(if ($Mode -ne "BaselineOnly" -and $WaitForStage10A) { $Stage10ATimeoutSeconds } else { 0 })
    KeepCandidateWritebackRunning = $(if ($Mode -ne "BaselineOnly") { $KeepCandidateWritebackRunning } else { $false })
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
