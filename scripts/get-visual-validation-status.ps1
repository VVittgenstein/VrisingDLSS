param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$ArtifactLabel,
    [string]$ComparisonPath,
    [string]$ReviewPath,
    [int]$MinimumWidth = 1280,
    [int]$MinimumHeight = 720,
    [double]$MaxNearBlackRatio = 0.95,
    [double]$MaxNearWhiteRatio = 0.95,
    [double]$MinimumAverageFpsDeltaPercent = -10.0,
    [double]$MinimumOnePercentLowFpsDeltaPercent = -15.0,
    [double]$MaximumP95FrameMsDeltaPercent = 15.0,
    [ValidateSet("Any", "dlss-visible-writeback", "dlss-user-rendering")]
    [string]$RequiredCandidateStage = "Any",
    [switch]$Json,
    [switch]$RequirePass
)

$ErrorActionPreference = "Stop"

function Resolve-OptionalPath {
    param(
        [string]$Path,
        [string]$Base
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Read-FormatListFile {
    param([string]$Path)

    $map = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match "^\s*([^:]+?)\s*:\s*(.*)$") {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $map[$key] = $value
        }
    }

    return $map
}

function Get-MapString {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    if ($Map.ContainsKey($Key)) {
        return [string]$Map[$Key]
    }

    return ""
}

function Get-MapBool {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    $value = Get-MapString -Map $Map -Key $Key
    return $value -match "^(?i:true)$"
}

function Get-MapInt {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    $value = Get-MapString -Map $Map -Key $Key
    if ([string]::IsNullOrWhiteSpace($value)) {
        return 0
    }

    return [int]$value
}

function Get-MapDouble {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    $value = Get-MapString -Map $Map -Key $Key
    if ([string]::IsNullOrWhiteSpace($value)) {
        return 0.0
    }

    return [double]::Parse($value, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-MapNullableDouble {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    $value = Get-MapString -Map $Map -Key $Key
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return [double]::Parse($value, [Globalization.CultureInfo]::InvariantCulture)
}

function Get-Delta {
    param(
        $Baseline,
        $Candidate
    )

    if ($null -eq $Baseline -or $null -eq $Candidate) {
        return $null
    }

    return [Math]::Round(([double]$Candidate - [double]$Baseline), 3)
}

function Get-DeltaPercent {
    param(
        $Baseline,
        $Candidate
    )

    if ($null -eq $Baseline -or $null -eq $Candidate -or [double]$Baseline -eq 0.0) {
        return $null
    }

    return [Math]::Round((([double]$Candidate - [double]$Baseline) / [double]$Baseline * 100.0), 3)
}

function Get-VisualComparisonPattern {
    param(
        [string]$Label,
        [string]$Stage
    )

    $stageSuffix = switch ($Stage) {
        "dlss-visible-writeback" { "stage10a" }
        "dlss-user-rendering" { "user-rendering" }
        default { "*" }
    }

    if ([string]::IsNullOrWhiteSpace($Label)) {
        return "*baseline-vs-$stageSuffix.txt"
    }

    $labelPrefix = $Label -replace "[^A-Za-z0-9_.-]", "-"
    return "$labelPrefix-baseline-vs-$stageSuffix.txt"
}

function Get-VisualNextRecommendation {
    param(
        [string]$Stage,
        [string]$ReviewPath
    )

    if ($Stage -eq "dlss-user-rendering") {
        if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
            return "After the candidate owns render-scale control with V Rising FSR Off, run scripts\run-vrising-visual-comparison.ps1 -CandidateStage dlss-user-rendering -FsrMode Off in a stable gameplay scene, capture performance, then add a matching human review file."
        }

        return "After the candidate owns render-scale control with V Rising FSR Off, run scripts\run-vrising-visual-comparison.ps1 -CandidateStage dlss-user-rendering -FsrMode Off in a stable gameplay scene, capture performance, then create $ReviewPath after human review with matching image SHA256 values."
    }

    if ($Stage -eq "dlss-visible-writeback") {
        if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
            return "Run scripts\run-vrising-visual-comparison.ps1 -CandidateStage dlss-visible-writeback in a stable gameplay scene, capture performance, then add a matching human review file."
        }

        return "Run scripts\run-vrising-visual-comparison.ps1 -CandidateStage dlss-visible-writeback in a stable gameplay scene, capture performance, then create $ReviewPath after human review with matching image SHA256 values."
    }

    if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
        return "Run scripts\run-vrising-visual-comparison.ps1 in Paired mode for a stable gameplay scene, capture performance, then add a matching human review file."
    }

    return "Run a paired gameplay visual comparison at gameplay resolution, capture baseline and candidate performance, then create $ReviewPath after human review with matching image SHA256 values."
}

function New-Status {
    param(
        [string]$Status,
        [string]$Evidence,
        [string]$NextRecommendation,
        [string[]]$Issues = @(),
        [hashtable]$Details = @{}
    )

    [pscustomobject]@{
        Status = $Status
        Evidence = $Evidence
        NextRecommendation = $NextRecommendation
        Issues = $Issues
        ComparisonPath = $(if ($Details.ContainsKey("ComparisonPath")) { $Details.ComparisonPath } else { "" })
        ReviewPath = $(if ($Details.ContainsKey("ReviewPath")) { $Details.ReviewPath } else { "" })
        BaselinePath = $(if ($Details.ContainsKey("BaselinePath")) { $Details.BaselinePath } else { "" })
        CandidatePath = $(if ($Details.ContainsKey("CandidatePath")) { $Details.CandidatePath } else { "" })
        BaselineSha256 = $(if ($Details.ContainsKey("BaselineSha256")) { $Details.BaselineSha256 } else { "" })
        CandidateSha256 = $(if ($Details.ContainsKey("CandidateSha256")) { $Details.CandidateSha256 } else { "" })
        RequiredCandidateStage = $(if ($Details.ContainsKey("RequiredCandidateStage")) { $Details.RequiredCandidateStage } else { $RequiredCandidateStage })
        Width = $(if ($Details.ContainsKey("Width")) { $Details.Width } else { 0 })
        Height = $(if ($Details.ContainsKey("Height")) { $Details.Height } else { 0 })
        MeanAbsRgbDelta = $(if ($Details.ContainsKey("MeanAbsRgbDelta")) { $Details.MeanAbsRgbDelta } else { $null })
        ChangedRatioGt10 = $(if ($Details.ContainsKey("ChangedRatioGt10")) { $Details.ChangedRatioGt10 } else { $null })
        CandidateStage = $(if ($Details.ContainsKey("CandidateStage")) { $Details.CandidateStage } else { "" })
        CandidateEvidenceLogPath = $(if ($Details.ContainsKey("CandidateEvidenceLogPath")) { $Details.CandidateEvidenceLogPath } else { "" })
        CandidateEvidenceProved = $(if ($Details.ContainsKey("CandidateEvidenceProved")) { $Details.CandidateEvidenceProved } else { $false })
        Stage10ALogPath = $(if ($Details.ContainsKey("Stage10ALogPath")) { $Details.Stage10ALogPath } else { "" })
        Stage10AProved = $(if ($Details.ContainsKey("Stage10AProved")) { $Details.Stage10AProved } else { $false })
        UserRenderingLogPath = $(if ($Details.ContainsKey("UserRenderingLogPath")) { $Details.UserRenderingLogPath } else { "" })
        UserRenderingProved = $(if ($Details.ContainsKey("UserRenderingProved")) { $Details.UserRenderingProved } else { $false })
        PerformanceSummaryPath = $(if ($Details.ContainsKey("CandidatePerformanceSummaryPath")) { $Details.CandidatePerformanceSummaryPath } elseif ($Details.ContainsKey("PerformanceSummaryPath")) { $Details.PerformanceSummaryPath } else { "" })
        PerformanceSummaryPresent = $(if ($Details.ContainsKey("CandidatePerformanceSummaryPresent")) { $Details.CandidatePerformanceSummaryPresent } elseif ($Details.ContainsKey("PerformanceSummaryPresent")) { $Details.PerformanceSummaryPresent } else { $false })
        BaselinePerformanceSummaryPath = $(if ($Details.ContainsKey("BaselinePerformanceSummaryPath")) { $Details.BaselinePerformanceSummaryPath } else { "" })
        CandidatePerformanceSummaryPath = $(if ($Details.ContainsKey("CandidatePerformanceSummaryPath")) { $Details.CandidatePerformanceSummaryPath } else { "" })
        BaselinePerformanceSummaryPresent = $(if ($Details.ContainsKey("BaselinePerformanceSummaryPresent")) { $Details.BaselinePerformanceSummaryPresent } else { $false })
        CandidatePerformanceSummaryPresent = $(if ($Details.ContainsKey("CandidatePerformanceSummaryPresent")) { $Details.CandidatePerformanceSummaryPresent } else { $false })
        BaselineAverageFps = $(if ($Details.ContainsKey("BaselineAverageFps")) { $Details.BaselineAverageFps } else { $null })
        CandidateAverageFps = $(if ($Details.ContainsKey("CandidateAverageFps")) { $Details.CandidateAverageFps } else { $null })
        AverageFpsDelta = $(if ($Details.ContainsKey("AverageFpsDelta")) { $Details.AverageFpsDelta } else { $null })
        AverageFpsDeltaPercent = $(if ($Details.ContainsKey("AverageFpsDeltaPercent")) { $Details.AverageFpsDeltaPercent } else { $null })
        BaselineOnePercentLowFps = $(if ($Details.ContainsKey("BaselineOnePercentLowFps")) { $Details.BaselineOnePercentLowFps } else { $null })
        CandidateOnePercentLowFps = $(if ($Details.ContainsKey("CandidateOnePercentLowFps")) { $Details.CandidateOnePercentLowFps } else { $null })
        OnePercentLowFpsDelta = $(if ($Details.ContainsKey("OnePercentLowFpsDelta")) { $Details.OnePercentLowFpsDelta } else { $null })
        OnePercentLowFpsDeltaPercent = $(if ($Details.ContainsKey("OnePercentLowFpsDeltaPercent")) { $Details.OnePercentLowFpsDeltaPercent } else { $null })
        BaselineP95FrameMs = $(if ($Details.ContainsKey("BaselineP95FrameMs")) { $Details.BaselineP95FrameMs } else { $null })
        CandidateP95FrameMs = $(if ($Details.ContainsKey("CandidateP95FrameMs")) { $Details.CandidateP95FrameMs } else { $null })
        P95FrameMsDelta = $(if ($Details.ContainsKey("P95FrameMsDelta")) { $Details.P95FrameMsDelta } else { $null })
        P95FrameMsDeltaPercent = $(if ($Details.ContainsKey("P95FrameMsDeltaPercent")) { $Details.P95FrameMsDeltaPercent } else { $null })
        HumanReviewStatus = $(if ($Details.ContainsKey("HumanReviewStatus")) { $Details.HumanReviewStatus } else { "" })
        LaunchesGame = $false
    }
}

if ($MinimumWidth -lt 1 -or $MinimumHeight -lt 1) {
    throw "MinimumWidth and MinimumHeight must be positive."
}

if ($MaxNearBlackRatio -le 0 -or $MaxNearBlackRatio -gt 1 -or $MaxNearWhiteRatio -le 0 -or $MaxNearWhiteRatio -gt 1) {
    throw "MaxNearBlackRatio and MaxNearWhiteRatio must be in (0, 1]."
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$visualRoot = Join-Path $resolvedRoot "artifacts\visual-validation"
$runtimeLogRoot = Join-Path $resolvedRoot "artifacts\runtime-logs"
$fpsRoot = Join-Path $resolvedRoot "artifacts\fps-validation"

$comparisonResolved = Resolve-OptionalPath -Path $ComparisonPath -Base $resolvedRoot
if ([string]::IsNullOrWhiteSpace($comparisonResolved)) {
    if (-not (Test-Path -LiteralPath $visualRoot)) {
        $result = New-Status `
            -Status "Missing" `
            -Evidence "No visual-validation artifact directory exists: $visualRoot" `
            -NextRecommendation (Get-VisualNextRecommendation -Stage $RequiredCandidateStage -ReviewPath "")
        if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result }
        if ($RequirePass) { exit 1 }
        return
    }

    $pattern = Get-VisualComparisonPattern -Label $ArtifactLabel -Stage $RequiredCandidateStage

    $latest = Get-ChildItem -LiteralPath $visualRoot -Filter $pattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        $result = New-Status `
            -Status "Missing" `
            -Evidence "No baseline-vs comparison artifact matched '$pattern' in $visualRoot" `
            -NextRecommendation (Get-VisualNextRecommendation -Stage $RequiredCandidateStage -ReviewPath "")
        if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result }
        if ($RequirePass) { exit 1 }
        return
    }

    $comparisonResolved = $latest.FullName
}

if (-not (Test-Path -LiteralPath $comparisonResolved)) {
    $result = New-Status `
        -Status "Missing" `
        -Evidence "Comparison artifact does not exist: $comparisonResolved" `
        -NextRecommendation (Get-VisualNextRecommendation -Stage $RequiredCandidateStage -ReviewPath "")
    if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result }
    if ($RequirePass) { exit 1 }
    return
}

$comparison = Read-FormatListFile -Path $comparisonResolved
$baselinePath = Get-MapString -Map $comparison -Key "BaselinePath"
$candidatePath = Get-MapString -Map $comparison -Key "CandidatePath"
$baselineSha = Get-MapString -Map $comparison -Key "BaselineSha256"
$candidateSha = Get-MapString -Map $comparison -Key "CandidateSha256"
$baselineLabel = if ([string]::IsNullOrWhiteSpace($baselinePath)) { "" } else { [System.IO.Path]::GetFileNameWithoutExtension($baselinePath) }
$candidateLabel = if ([string]::IsNullOrWhiteSpace($candidatePath)) { "" } else { [System.IO.Path]::GetFileNameWithoutExtension($candidatePath) }
$candidateStage = if ($candidateLabel -match "user-rendering" -or [System.IO.Path]::GetFileNameWithoutExtension($comparisonResolved) -match "baseline-vs-user-rendering") {
    "dlss-user-rendering"
} else {
    "dlss-visible-writeback"
}
$candidateEvidenceLogPath = if ([string]::IsNullOrWhiteSpace($candidateLabel)) { "" } else { Join-Path $runtimeLogRoot "LogOutput-$candidateLabel.log" }
$stage10ALogPath = if ($candidateStage -eq "dlss-visible-writeback") { $candidateEvidenceLogPath } else { "" }
$userRenderingLogPath = if ($candidateStage -eq "dlss-user-rendering") { $candidateEvidenceLogPath } else { "" }
$baselinePerformanceSummaryPath = if ([string]::IsNullOrWhiteSpace($baselineLabel)) { "" } else { Join-Path $fpsRoot "$baselineLabel.txt" }
$candidatePerformanceSummaryPath = if ([string]::IsNullOrWhiteSpace($candidateLabel)) { "" } else { Join-Path $fpsRoot "$candidateLabel.txt" }
$baselinePerformance = if (-not [string]::IsNullOrWhiteSpace($baselinePerformanceSummaryPath) -and (Test-Path -LiteralPath $baselinePerformanceSummaryPath)) {
    Read-FormatListFile -Path $baselinePerformanceSummaryPath
} else {
    @{}
}
$candidatePerformance = if (-not [string]::IsNullOrWhiteSpace($candidatePerformanceSummaryPath) -and (Test-Path -LiteralPath $candidatePerformanceSummaryPath)) {
    Read-FormatListFile -Path $candidatePerformanceSummaryPath
} else {
    @{}
}
$baselineAverageFps = Get-MapNullableDouble -Map $baselinePerformance -Key "AverageFps"
$candidateAverageFps = Get-MapNullableDouble -Map $candidatePerformance -Key "AverageFps"
$baselineOnePercentLowFps = Get-MapNullableDouble -Map $baselinePerformance -Key "OnePercentLowFps"
$candidateOnePercentLowFps = Get-MapNullableDouble -Map $candidatePerformance -Key "OnePercentLowFps"
$baselineP95FrameMs = Get-MapNullableDouble -Map $baselinePerformance -Key "P95FrameMs"
$candidateP95FrameMs = Get-MapNullableDouble -Map $candidatePerformance -Key "P95FrameMs"

$details = @{
    ComparisonPath = $comparisonResolved
    BaselinePath = $baselinePath
    CandidatePath = $candidatePath
    BaselineSha256 = $baselineSha
    CandidateSha256 = $candidateSha
    RequiredCandidateStage = $RequiredCandidateStage
    Width = Get-MapInt -Map $comparison -Key "ComparedWidth"
    Height = Get-MapInt -Map $comparison -Key "ComparedHeight"
    MeanAbsRgbDelta = Get-MapDouble -Map $comparison -Key "MeanAbsRgbDelta"
    ChangedRatioGt10 = Get-MapDouble -Map $comparison -Key "ChangedRatioGt10"
    CandidateStage = $candidateStage
    CandidateEvidenceLogPath = $candidateEvidenceLogPath
    CandidateEvidenceProved = $false
    Stage10ALogPath = $stage10ALogPath
    Stage10AProved = $false
    UserRenderingLogPath = $userRenderingLogPath
    UserRenderingProved = $false
    BaselinePerformanceSummaryPath = $baselinePerformanceSummaryPath
    CandidatePerformanceSummaryPath = $candidatePerformanceSummaryPath
    BaselinePerformanceSummaryPresent = -not [string]::IsNullOrWhiteSpace($baselinePerformanceSummaryPath) -and (Test-Path -LiteralPath $baselinePerformanceSummaryPath)
    CandidatePerformanceSummaryPresent = -not [string]::IsNullOrWhiteSpace($candidatePerformanceSummaryPath) -and (Test-Path -LiteralPath $candidatePerformanceSummaryPath)
    BaselineAverageFps = $baselineAverageFps
    CandidateAverageFps = $candidateAverageFps
    AverageFpsDelta = Get-Delta -Baseline $baselineAverageFps -Candidate $candidateAverageFps
    AverageFpsDeltaPercent = Get-DeltaPercent -Baseline $baselineAverageFps -Candidate $candidateAverageFps
    BaselineOnePercentLowFps = $baselineOnePercentLowFps
    CandidateOnePercentLowFps = $candidateOnePercentLowFps
    OnePercentLowFpsDelta = Get-Delta -Baseline $baselineOnePercentLowFps -Candidate $candidateOnePercentLowFps
    OnePercentLowFpsDeltaPercent = Get-DeltaPercent -Baseline $baselineOnePercentLowFps -Candidate $candidateOnePercentLowFps
    BaselineP95FrameMs = $baselineP95FrameMs
    CandidateP95FrameMs = $candidateP95FrameMs
    P95FrameMsDelta = Get-Delta -Baseline $baselineP95FrameMs -Candidate $candidateP95FrameMs
    P95FrameMsDeltaPercent = Get-DeltaPercent -Baseline $baselineP95FrameMs -Candidate $candidateP95FrameMs
    HumanReviewStatus = ""
}

if ($RequiredCandidateStage -ne "Any" -and $candidateStage -ne $RequiredCandidateStage) {
    $issue = "Comparison candidate stage is $candidateStage, required $RequiredCandidateStage."
    $result = New-Status `
        -Status "Blocked" `
        -Evidence "Comparison artifact candidate stage does not satisfy the requested visual gate: $comparisonResolved" `
        -NextRecommendation (Get-VisualNextRecommendation -Stage $RequiredCandidateStage -ReviewPath "") `
        -Issues @($issue) `
        -Details $details
    if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result }
    if ($RequirePass) { exit 1 }
    return
}

$issues = New-Object System.Collections.Generic.List[string]
if ([string]::IsNullOrWhiteSpace($baselinePath) -or -not (Test-Path -LiteralPath $baselinePath)) {
    $issues.Add("Baseline capture is missing.")
}

if ([string]::IsNullOrWhiteSpace($candidatePath) -or -not (Test-Path -LiteralPath $candidatePath)) {
    $issues.Add("Candidate capture is missing.")
}

if (-not (Get-MapBool -Map $comparison -Key "DimensionsMatch")) {
    $issues.Add("Baseline and candidate image dimensions do not match.")
}

if ($details.Width -lt $MinimumWidth -or $details.Height -lt $MinimumHeight) {
    $issues.Add("Comparison resolution $($details.Width)x$($details.Height) is below the required $MinimumWidth x $MinimumHeight gameplay validation floor.")
}

foreach ($prefix in @("Baseline", "Candidate")) {
    $nearBlack = Get-MapDouble -Map $comparison -Key "${prefix}NearBlackRatio"
    $nearWhite = Get-MapDouble -Map $comparison -Key "${prefix}NearWhiteRatio"
    if ($nearBlack -gt $MaxNearBlackRatio) {
        $issues.Add("$prefix capture is mostly near-black: ratio=$nearBlack.")
    }
    if ($nearWhite -gt $MaxNearWhiteRatio) {
        $issues.Add("$prefix capture is mostly near-white: ratio=$nearWhite.")
    }
}

if (-not [string]::IsNullOrWhiteSpace($candidateEvidenceLogPath) -and (Test-Path -LiteralPath $candidateEvidenceLogPath)) {
    $logText = Get-Content -LiteralPath $candidateEvidenceLogPath -Raw
    if ($candidateStage -eq "dlss-user-rendering") {
        $details.UserRenderingProved = $logText -match "DLSS user rendering evaluate succeeded from" -and $logText -match "sequenceSuccesses=\d+"
        $details.CandidateEvidenceProved = $details.UserRenderingProved
    } else {
        $details.Stage10AProved = $logText -match "DLSS visible write-back probe succeeded" -and $logText -match "sequenceSuccesses=30/30"
        $details.CandidateEvidenceProved = $details.Stage10AProved
    }
}

if (-not $details.CandidateEvidenceProved) {
    if ($candidateStage -eq "dlss-user-rendering") {
        $issues.Add("Candidate log does not prove DLSS user-rendering evaluate success with sequenceSuccesses.")
    } else {
        $issues.Add("Candidate log does not prove Stage 10A visible write-back success with sequenceSuccesses=30/30.")
    }
}

$details.BaselinePerformanceSummaryPresent = -not [string]::IsNullOrWhiteSpace($baselinePerformanceSummaryPath) -and (Test-Path -LiteralPath $baselinePerformanceSummaryPath)
$details.CandidatePerformanceSummaryPresent = -not [string]::IsNullOrWhiteSpace($candidatePerformanceSummaryPath) -and (Test-Path -LiteralPath $candidatePerformanceSummaryPath)
if (-not $details.BaselinePerformanceSummaryPresent) {
    $issues.Add("Baseline performance summary is missing.")
}

if (-not $details.CandidatePerformanceSummaryPresent) {
    $issues.Add("Candidate performance summary is missing.")
}

if ($candidateStage -eq "dlss-user-rendering" -and $details.BaselinePerformanceSummaryPresent -and $details.CandidatePerformanceSummaryPresent) {
    if ($null -ne $details.AverageFpsDeltaPercent -and [double]$details.AverageFpsDeltaPercent -lt $MinimumAverageFpsDeltaPercent) {
        $issues.Add("Candidate average FPS regressed by $($details.AverageFpsDeltaPercent)% versus baseline; minimum allowed is $MinimumAverageFpsDeltaPercent%.")
    }

    if ($null -ne $details.OnePercentLowFpsDeltaPercent -and [double]$details.OnePercentLowFpsDeltaPercent -lt $MinimumOnePercentLowFpsDeltaPercent) {
        $issues.Add("Candidate 1% low FPS regressed by $($details.OnePercentLowFpsDeltaPercent)% versus baseline; minimum allowed is $MinimumOnePercentLowFpsDeltaPercent%.")
    }

    if ($null -ne $details.P95FrameMsDeltaPercent -and [double]$details.P95FrameMsDeltaPercent -gt $MaximumP95FrameMsDeltaPercent) {
        $issues.Add("Candidate P95 frame time worsened by $($details.P95FrameMsDeltaPercent)% versus baseline; maximum allowed is $MaximumP95FrameMsDeltaPercent%.")
    }
}

$reviewResolved = Resolve-OptionalPath -Path $ReviewPath -Base $resolvedRoot
if ([string]::IsNullOrWhiteSpace($reviewResolved)) {
    $reviewResolved = [System.IO.Path]::ChangeExtension($comparisonResolved, ".review.json")
}

$details.ReviewPath = $reviewResolved
if (-not (Test-Path -LiteralPath $reviewResolved)) {
    $issues.Add("Human visual review file is missing.")
} else {
    try {
        $review = Get-Content -LiteralPath $reviewResolved -Raw | ConvertFrom-Json
        $reviewStatus = ([string]$review.reviewStatus).Trim()
        $details.HumanReviewStatus = $reviewStatus

        if ($reviewStatus -eq "Fail") {
            $result = New-Status `
                -Status "Fail" `
                -Evidence "Human visual review failed: $reviewResolved" `
                -NextRecommendation "Fix the candidate image path, rerun the paired candidate visual comparison, then review a fresh artifact pair." `
                -Issues $issues.ToArray() `
                -Details $details
            if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result }
            if ($RequirePass) { exit 1 }
            return
        }

        if ($reviewStatus -ne "Pass") {
            $issues.Add("Human visual review status is '$reviewStatus', not Pass.")
        }

        if ([string]$review.baselineSha256 -ne $baselineSha -or [string]$review.candidateSha256 -ne $candidateSha) {
            $issues.Add("Human visual review hashes do not match the comparison artifact.")
        }

        if ($reviewStatus -eq "Pass") {
            if ([string]::IsNullOrWhiteSpace([string]$review.scene)) {
                $issues.Add("Human visual review scene description is empty.")
            }

            if ([string]::IsNullOrWhiteSpace([string]$review.notes)) {
                $issues.Add("Human visual review notes are empty.")
            }

            if ([string]::IsNullOrWhiteSpace([string]$review.reviewedAt)) {
                $issues.Add("Human visual review reviewedAt timestamp is empty.")
            }
        }
    } catch {
        $issues.Add("Human visual review file could not be parsed: $($_.Exception.Message)")
    }
}

$nextRecommendation = Get-VisualNextRecommendation -Stage $RequiredCandidateStage -ReviewPath $reviewResolved
if (Test-Path -LiteralPath $reviewResolved) {
    if ($details.HumanReviewStatus -eq "Pending") {
        $nextRecommendation = "Complete human visual review for $reviewResolved, then mark it Pass only if the candidate image is correct enough for MVP evidence."
    } elseif (-not [string]::IsNullOrWhiteSpace([string]$details.HumanReviewStatus)) {
        $nextRecommendation = "Resolve the listed visual review issue in $reviewResolved, rerunning the paired comparison if the existing candidate is not image-correct."
    }
}

if (@($issues | Where-Object { $_ -like "Candidate * regressed*" -or $_ -like "Candidate P95 frame time worsened*" }).Count -gt 0) {
    $nextRecommendation = "Cached-driver real-evaluate crashed in nvwgf2umx.dll even with GetTexture evaluate/output-follow-up at zero, rendergraph-pass-map patched safely but emitted zero pass lines, and rendergraph-pass-list menu smoke safely mapped Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass. Do not rerun those routes unchanged; next run should be protected 11111 gameplay rendergraph-pass-list with save backup/restore before a focused resource-declaration snapshot."
}

if ($issues.Count -gt 0) {
    $result = New-Status `
        -Status "Blocked" `
        -Evidence "Visual validation is not yet strong enough for MVP: $comparisonResolved" `
        -NextRecommendation $nextRecommendation `
        -Issues $issues.ToArray() `
        -Details $details
} else {
    $result = New-Status `
        -Status "Pass" `
        -Evidence "Gameplay visual comparison, candidate DLSS evidence log, baseline/candidate performance summaries, and matching human review passed: $comparisonResolved" `
        -NextRecommendation "Use this visual evidence while validating resize/reset handling and fallback behavior." `
        -Issues @() `
        -Details $details
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}

if ($RequirePass -and $result.Status -ne "Pass") {
    exit 1
}
