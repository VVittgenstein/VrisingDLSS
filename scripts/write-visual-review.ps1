param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$ArtifactLabel,
    [string]$ComparisonPath,
    [string]$ReviewPath,
    [ValidateSet("Pending", "Pass", "Fail")]
    [string]$ReviewStatus = "Pending",
    [string]$Reviewer = $env:USERNAME,
    [string]$Scene = "",
    [string]$Notes = "",
    [switch]$ConfirmImageCorrectness,
    [switch]$Force,
    [switch]$DryRun
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
            $map[$Matches[1].Trim()] = $Matches[2].Trim()
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

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$visualRoot = Join-Path $resolvedRoot "artifacts\visual-validation"

$comparisonResolved = Resolve-OptionalPath -Path $ComparisonPath -Base $resolvedRoot
if ([string]::IsNullOrWhiteSpace($comparisonResolved)) {
    if (-not (Test-Path -LiteralPath $visualRoot)) {
        throw "No visual-validation artifact directory exists: $visualRoot"
    }

    $pattern = if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
        "*baseline-vs-*.txt"
    } else {
        "$($ArtifactLabel -replace '[^A-Za-z0-9_.-]', '-')-baseline-vs-*.txt"
    }

    $latest = Get-ChildItem -LiteralPath $visualRoot -Filter $pattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw "No baseline-vs comparison artifact matched '$pattern' in $visualRoot"
    }

    $comparisonResolved = $latest.FullName
}

if (-not (Test-Path -LiteralPath $comparisonResolved)) {
    throw "Comparison artifact does not exist: $comparisonResolved"
}

if ($ReviewStatus -eq "Pass" -and -not $ConfirmImageCorrectness) {
    throw "Pass reviews require -ConfirmImageCorrectness after inspecting the baseline and candidate images."
}

$comparison = Read-FormatListFile -Path $comparisonResolved
$baselinePath = Get-MapString -Map $comparison -Key "BaselinePath"
$candidatePath = Get-MapString -Map $comparison -Key "CandidatePath"
$baselineSha = Get-MapString -Map $comparison -Key "BaselineSha256"
$candidateSha = Get-MapString -Map $comparison -Key "CandidateSha256"

if ([string]::IsNullOrWhiteSpace($baselineSha) -or [string]::IsNullOrWhiteSpace($candidateSha)) {
    throw "Comparison artifact does not contain baseline/candidate SHA256 values: $comparisonResolved"
}

if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
    $reviewResolved = [System.IO.Path]::ChangeExtension($comparisonResolved, ".review.json")
} else {
    $reviewResolved = Resolve-OptionalPath -Path $ReviewPath -Base $resolvedRoot
}

if ((Test-Path -LiteralPath $reviewResolved) -and -not $Force -and -not $DryRun) {
    throw "Review file already exists. Pass -Force to overwrite: $reviewResolved"
}

if ([string]::IsNullOrWhiteSpace($Reviewer)) {
    $Reviewer = "local"
}

if ([string]::IsNullOrWhiteSpace($Notes)) {
    $Notes = if ($ReviewStatus -eq "Pending") {
        "Inspect baseline and candidate captures for black/white frames, wrong-window capture, severe blur, ghosting, unstable UI, and obvious temporal artifacts before changing reviewStatus to Pass."
    } elseif ($ReviewStatus -eq "Pass") {
        "No black/white frame, wrong-window capture, severe blur, ghosting, unstable UI, or obvious temporal artifacts observed."
    } else {
        "Candidate visual output failed review. See notes from reviewer."
    }
}

$review = [ordered]@{
    reviewStatus = $ReviewStatus
    reviewer = $Reviewer
    reviewedAt = [DateTime]::UtcNow.ToString("o")
    scene = $Scene
    notes = $Notes
    comparisonPath = $comparisonResolved
    baselinePath = $baselinePath
    candidatePath = $candidatePath
    baselineSha256 = $baselineSha
    candidateSha256 = $candidateSha
    dimensionsMatch = Get-MapString -Map $comparison -Key "DimensionsMatch"
    comparedWidth = Get-MapString -Map $comparison -Key "ComparedWidth"
    comparedHeight = Get-MapString -Map $comparison -Key "ComparedHeight"
    meanAbsRgbDelta = Get-MapString -Map $comparison -Key "MeanAbsRgbDelta"
    changedRatioGt10 = Get-MapString -Map $comparison -Key "ChangedRatioGt10"
    checklist = @(
        "baseline and candidate captures are from the same stable gameplay scene",
        "candidate capture is not black, white, wrong-window, or menu-only unless deliberately testing menu behavior",
        "candidate image has no severe blur, ghosting, unstable UI, or obvious temporal artifacts",
        "candidate DLSS evidence log and baseline/candidate performance summaries are present when get-visual-validation-status.ps1 is run"
    )
    launchesGame = $false
}

$json = $review | ConvertTo-Json -Depth 5

if ($DryRun) {
    [pscustomobject]@{
        Mode = "DryRun"
        ComparisonPath = $comparisonResolved
        ReviewPath = $reviewResolved
        ReviewJson = $json
        LaunchesGame = $false
    }
    return
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reviewResolved) | Out-Null
Set-Content -LiteralPath $reviewResolved -Encoding UTF8 -Value $json

[pscustomobject]@{
    Mode = "ReviewWritten"
    ReviewPath = $reviewResolved
    ReviewStatus = $ReviewStatus
    BaselineSha256 = $baselineSha
    CandidateSha256 = $candidateSha
    LaunchesGame = $false
}
