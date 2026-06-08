param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]
$dryRunDir = Join-Path $resolvedRoot "artifacts\dryrun"
New-Item -ItemType Directory -Force -Path $dryRunDir | Out-Null

function Add-Check {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [AllowEmptyString()]
        [string]$Evidence = "",

        [AllowEmptyString()]
        [string]$Failure = ""
    )

    if (-not $Passed) {
        if ([string]::IsNullOrWhiteSpace($Failure)) {
            [void]$issues.Add($Name)
        } else {
            [void]$issues.Add("${Name}: $Failure")
        }
    }

    [void]$checks.Add([pscustomobject]@{
            Name = $Name
            Status = $(if ($Passed) { "Pass" } else { "Fail" })
            Evidence = $Evidence
        })
}

function Test-HasProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return $null -ne $Object -and $null -ne ($Object.PSObject.Properties[$Name])
}

$snapshotScript = Join-Path $resolvedRoot "scripts\capture-system-snapshot.ps1"
$fpsScript = Join-Path $resolvedRoot "scripts\capture-vrising-fps.ps1"
$visualComparisonScript = Join-Path $resolvedRoot "scripts\run-vrising-visual-comparison.ps1"
$snapshotPath = Join-Path $dryRunDir "runtime-environment-snapshot-contract.json"

foreach ($path in @($snapshotScript, $fpsScript, $visualComparisonScript)) {
    Add-Check `
        -Name "FileExists:$([System.IO.Path]::GetFileName($path))" `
        -Passed (Test-Path -LiteralPath $path -PathType Leaf) `
        -Evidence $path `
        -Failure "missing $path"
}

$snapshotPlan = & $snapshotScript `
    -Root $resolvedRoot `
    -OutputPath $snapshotPath `
    -ArtifactLabel "runtime-environment-snapshot-contract" `
    -Reason "contract-dry-run" `
    -TopProcessCount 5 `
    -SampleMilliseconds 250 `
    -DryRun

Add-Check `
    -Name "SystemSnapshotDryRunIsNoLaunch" `
    -Passed (($snapshotPlan.Mode -eq "DryRun") -and (-not [bool]$snapshotPlan.LaunchesGame) -and ($snapshotPlan.OutputPath -eq [System.IO.Path]::GetFullPath($snapshotPath))) `
    -Evidence "Mode=$($snapshotPlan.Mode); LaunchesGame=$($snapshotPlan.LaunchesGame); OutputPath=$($snapshotPlan.OutputPath)" `
    -Failure "capture-system-snapshot dry-run no longer reports a no-launch plan"

$snapshot = & $snapshotScript `
    -Root $resolvedRoot `
    -OutputPath $snapshotPath `
    -ArtifactLabel "runtime-environment-snapshot-contract" `
    -Reason "contract-smoke" `
    -TopProcessCount 5 `
    -SampleMilliseconds 250

Add-Check `
    -Name "SystemSnapshotSmokeWritesJsonWithoutLaunchingGame" `
    -Passed (($snapshot.Mode -eq "SystemSnapshot") -and (-not [bool]$snapshot.LaunchesGame) -and (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) `
    -Evidence "Mode=$($snapshot.Mode); LaunchesGame=$($snapshot.LaunchesGame); OutputPath=$($snapshot.OutputPath)" `
    -Failure "capture-system-snapshot smoke did not write a no-launch JSON snapshot"

$snapshotJson = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
Add-Check `
    -Name "SystemSnapshotSchemaIncludesCpuMemoryGpuAndProcesses" `
    -Passed ((Test-HasProperty -Object $snapshotJson -Name "Cpu") `
        -and (Test-HasProperty -Object $snapshotJson -Name "Memory") `
        -and (Test-HasProperty -Object $snapshotJson -Name "Gpu") `
        -and (Test-HasProperty -Object $snapshotJson -Name "TopCpuProcesses") `
        -and (Test-HasProperty -Object $snapshotJson -Name "TopMemoryProcesses") `
        -and (Test-HasProperty -Object $snapshotJson.Gpu -Name "Available") `
        -and (Test-HasProperty -Object $snapshotJson.Gpu -Name "GpuUtilPercent") `
        -and (Test-HasProperty -Object $snapshotJson.Gpu -Name "GpuPowerW") `
        -and (Test-HasProperty -Object $snapshotJson.Gpu -Name "GpuTemperatureC")) `
    -Evidence "Cpu=$($snapshotJson.Cpu.Name); GPUAvailable=$($snapshotJson.Gpu.Available); TopCpu=$(@($snapshotJson.TopCpuProcesses).Count); TopMemory=$(@($snapshotJson.TopMemoryProcesses).Count)" `
    -Failure "system snapshot JSON no longer carries the CPU/memory/GPU/process fields needed for performance comparisons"

Add-Check `
    -Name "SystemSnapshotCapturesBoundedTopProcessLists" `
    -Passed ((@($snapshotJson.TopCpuProcesses).Count -le 5) -and (@($snapshotJson.TopMemoryProcesses).Count -le 5) -and ($snapshotJson.SampleMilliseconds -ge 250)) `
    -Evidence "TopCpu=$(@($snapshotJson.TopCpuProcesses).Count); TopMemory=$(@($snapshotJson.TopMemoryProcesses).Count); SampleMilliseconds=$($snapshotJson.SampleMilliseconds)" `
    -Failure "system snapshot process lists are not bounded by TopProcessCount or sample duration is invalid"

$fpsPlan = & $fpsScript `
    -Root $resolvedRoot `
    -ArtifactLabel "runtime-environment-fps-contract" `
    -Seconds 5 `
    -MetricsIntervalMs 500 `
    -DryRun

Add-Check `
    -Name "FpsDryRunDefaultsToSystemMetricsAndSnapshots" `
    -Passed (($fpsPlan.Mode -eq "DryRun") `
        -and (-not [bool]$fpsPlan.LaunchesGame) `
        -and [bool]$fpsPlan.CapturesSystemMetrics `
        -and [bool]$fpsPlan.CapturesSystemSnapshots `
        -and $fpsPlan.MetricsPath -match [regex]::Escape("artifacts\fps-validation") `
        -and $fpsPlan.SystemSnapshotBeforePath -match [regex]::Escape("artifacts\system-snapshots") `
        -and $fpsPlan.SystemSnapshotAfterPath -match [regex]::Escape("artifacts\system-snapshots")) `
    -Evidence "CapturesSystemMetrics=$($fpsPlan.CapturesSystemMetrics); CapturesSystemSnapshots=$($fpsPlan.CapturesSystemSnapshots); MetricsPath=$($fpsPlan.MetricsPath); Before=$($fpsPlan.SystemSnapshotBeforePath); After=$($fpsPlan.SystemSnapshotAfterPath)" `
    -Failure "capture-vrising-fps dry-run no longer guarantees metrics plus before/after system snapshots by default"

$visualText = Get-Content -LiteralPath $visualComparisonScript -Raw
Add-Check `
    -Name "VisualComparisonRoutesPerformanceThroughFpsCapture" `
    -Passed (($visualText -match 'Invoke-ProjectScript\s+-RelativePath\s+"scripts\\capture-vrising-fps\.ps1"') -and ($visualText -notmatch 'SkipSystemSnapshots')) `
    -Evidence "run-vrising-visual-comparison invokes capture-vrising-fps and does not disable snapshots." `
    -Failure "visual comparison performance capture no longer clearly routes through capture-vrising-fps with default snapshots"

$failedChecks = @($checks.ToArray() | Where-Object { $_.Status -ne "Pass" })
$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Issues = @($issues.ToArray())
    SnapshotPath = $snapshotPath
    GpuAvailable = if ($snapshotJson) { [bool]$snapshotJson.Gpu.Available } else { $false }
    Checks = @($checks.ToArray())
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}

if ($failedChecks.Count -gt 0) {
    exit 1
}
