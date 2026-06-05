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
        "dlss-feature-create",
        "dlss-evaluate-inputs",
        "dlss-super-resolution-inputs",
        "dlss-super-resolution-evaluate",
        "dlss-super-resolution-persistent-evaluate",
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
    [switch]$SkipInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($DurationSeconds -lt 5) {
    throw "DurationSeconds must be at least 5."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
$exePath = Join-Path $resolvedGamePath "VRising.exe"
$logPath = Join-Path $resolvedGamePath "BepInEx\LogOutput.log"
$artifactRoot = Join-Path $resolvedRoot "artifacts\runtime-logs"
$safeStage = $Stage -replace "[^A-Za-z0-9_.-]", "-"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

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

$existingProcess = Get-VRisingProcess | Select-Object -First 1
if ($existingProcess) {
    throw "VRising is already running (pid=$($existingProcess.Id)). Close it before running a scripted diagnostic."
}

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "Run" })
    GamePath = $resolvedGamePath
    Stage = $Stage
    DurationSeconds = $DurationSeconds
    ArtifactLabel = $ArtifactLabel
    SkipInstall = [bool]$SkipInstall
    LogArtifact = (Join-Path $artifactRoot "LogOutput-$ArtifactLabel.log")
    AnalysisArtifact = (Join-Path $artifactRoot "Analysis-$ArtifactLabel.txt")
    WerArtifact = (Join-Path $artifactRoot "WER-$ArtifactLabel.txt")
    RestoresLoaderConfig = $true
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

try {
    if (-not $SkipInstall) {
        & (Join-Path $resolvedRoot "scripts\install-local-package.ps1") -GamePath $resolvedGamePath | Out-Host
    }

    & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") `
        -GamePath $resolvedGamePath `
        -Stage $Stage `
        -DlssRuntimePath $DlssRuntimePath `
        -DlssApplicationId $DlssApplicationId |
        Out-Host

    Write-Host "DiagnosticRunStart=$($runStart.ToString('o'))"
    Write-Host "DiagnosticStage=$Stage"
    Write-Host "ArtifactLabel=$ArtifactLabel"

    $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -PassThru
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
        & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") -GamePath $resolvedGamePath -Stage loader | Out-Host
    } catch {
        Write-Warning "Restoring loader config failed: $($_.Exception.Message)"
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
    CrashEventCount = $crashEvents.Count
    ExitedBeforeWindow = $exitBeforeWindow
    ClosedByScript = $closedByScript
    RestoredLoaderConfig = $true
    LaunchesGame = $true
}
