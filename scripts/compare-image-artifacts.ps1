param(
    [Parameter(Mandatory = $true)]
    [string]$BaselinePath,

    [Parameter(Mandatory = $true)]
    [string]$CandidatePath,

    [string]$OutputPath,
    [string]$ArtifactLabel,
    [string]$Root,
    [int]$MaxSamples = 250000,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($MaxSamples -lt 1000) {
    throw "MaxSamples must be at least 1000."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path

function Resolve-ExistingPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    return (Resolve-Path -LiteralPath (Join-Path $resolvedRoot $Path)).Path
}

$baselineResolved = Resolve-ExistingPath -Path $BaselinePath
$candidateResolved = Resolve-ExistingPath -Path $CandidatePath

$artifactRoot = Join-Path $resolvedRoot "artifacts\visual-validation"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "image-comparison-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot "$ArtifactLabel.txt"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $resolvedRoot $OutputPath
}

$targetPath = [System.IO.Path]::GetFullPath($OutputPath)

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "Compare" })
    BaselinePath = $baselineResolved
    CandidatePath = $candidateResolved
    OutputPath = $targetPath
    MaxSamples = $MaxSamples
    LaunchesGame = $false
}

if ($DryRun) {
    $plan
    return
}

Add-Type -AssemblyName System.Drawing

function Get-BitmapStats {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$MaxSamples
    )

    $pixelCount = [double]($Bitmap.Width * $Bitmap.Height)
    $step = [Math]::Max(1, [int][Math]::Ceiling([Math]::Sqrt($pixelCount / $MaxSamples)))
    $samples = 0
    $nearBlack = 0
    $nearWhite = 0
    $sumLuma = 0.0

    for ($y = 0; $y -lt $Bitmap.Height; $y += $step) {
        for ($x = 0; $x -lt $Bitmap.Width; $x += $step) {
            $color = $Bitmap.GetPixel($x, $y)
            $luma = (0.2126 * $color.R) + (0.7152 * $color.G) + (0.0722 * $color.B)
            $sumLuma += $luma
            if ($color.R -lt 8 -and $color.G -lt 8 -and $color.B -lt 8) {
                $nearBlack++
            }
            if ($color.R -gt 247 -and $color.G -gt 247 -and $color.B -gt 247) {
                $nearWhite++
            }
            $samples++
        }
    }

    [pscustomobject]@{
        Samples = $samples
        AverageLuma = [Math]::Round($sumLuma / $samples, 3)
        NearBlackRatio = [Math]::Round($nearBlack / $samples, 6)
        NearWhiteRatio = [Math]::Round($nearWhite / $samples, 6)
    }
}

$baseline = $null
$candidate = $null

try {
    $baseline = New-Object System.Drawing.Bitmap($baselineResolved)
    $candidate = New-Object System.Drawing.Bitmap($candidateResolved)

    $compareWidth = [Math]::Min($baseline.Width, $candidate.Width)
    $compareHeight = [Math]::Min($baseline.Height, $candidate.Height)
    $pixelCount = [double]($compareWidth * $compareHeight)
    $step = [Math]::Max(1, [int][Math]::Ceiling([Math]::Sqrt($pixelCount / $MaxSamples)))

    $samples = 0
    $changedGt2 = 0
    $changedGt10 = 0
    $sumAbsRgb = 0.0
    $sumAbsLuma = 0.0
    $maxAbsRgb = 0.0
    $maxAbsLuma = 0.0

    for ($y = 0; $y -lt $compareHeight; $y += $step) {
        for ($x = 0; $x -lt $compareWidth; $x += $step) {
            $a = $baseline.GetPixel($x, $y)
            $b = $candidate.GetPixel($x, $y)
            $dr = [Math]::Abs([int]$a.R - [int]$b.R)
            $dg = [Math]::Abs([int]$a.G - [int]$b.G)
            $db = [Math]::Abs([int]$a.B - [int]$b.B)
            $absRgb = ($dr + $dg + $db) / 3.0

            $lumaA = (0.2126 * $a.R) + (0.7152 * $a.G) + (0.0722 * $a.B)
            $lumaB = (0.2126 * $b.R) + (0.7152 * $b.G) + (0.0722 * $b.B)
            $absLuma = [Math]::Abs($lumaA - $lumaB)

            $sumAbsRgb += $absRgb
            $sumAbsLuma += $absLuma
            $maxAbsRgb = [Math]::Max($maxAbsRgb, $absRgb)
            $maxAbsLuma = [Math]::Max($maxAbsLuma, $absLuma)
            if ($absRgb -gt 2) {
                $changedGt2++
            }
            if ($absRgb -gt 10) {
                $changedGt10++
            }
            $samples++
        }
    }

    $baselineStats = Get-BitmapStats -Bitmap $baseline -MaxSamples $MaxSamples
    $candidateStats = Get-BitmapStats -Bitmap $candidate -MaxSamples $MaxSamples

    $result = [pscustomobject]@{
        Mode = "Compared"
        BaselinePath = $baselineResolved
        CandidatePath = $candidateResolved
        OutputPath = $targetPath
        BaselineWidth = $baseline.Width
        BaselineHeight = $baseline.Height
        CandidateWidth = $candidate.Width
        CandidateHeight = $candidate.Height
        DimensionsMatch = ($baseline.Width -eq $candidate.Width -and $baseline.Height -eq $candidate.Height)
        ComparedWidth = $compareWidth
        ComparedHeight = $compareHeight
        Samples = $samples
        MeanAbsRgbDelta = [Math]::Round($sumAbsRgb / $samples, 4)
        MaxAbsRgbDelta = [Math]::Round($maxAbsRgb, 4)
        MeanAbsLumaDelta = [Math]::Round($sumAbsLuma / $samples, 4)
        MaxAbsLumaDelta = [Math]::Round($maxAbsLuma, 4)
        ChangedRatioGt2 = [Math]::Round($changedGt2 / $samples, 6)
        ChangedRatioGt10 = [Math]::Round($changedGt10 / $samples, 6)
        BaselineAverageLuma = $baselineStats.AverageLuma
        BaselineNearBlackRatio = $baselineStats.NearBlackRatio
        BaselineNearWhiteRatio = $baselineStats.NearWhiteRatio
        CandidateAverageLuma = $candidateStats.AverageLuma
        CandidateNearBlackRatio = $candidateStats.NearBlackRatio
        CandidateNearWhiteRatio = $candidateStats.NearWhiteRatio
        BaselineSha256 = (Get-FileHash -LiteralPath $baselineResolved -Algorithm SHA256).Hash
        CandidateSha256 = (Get-FileHash -LiteralPath $candidateResolved -Algorithm SHA256).Hash
        LaunchesGame = $false
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
    $result | Format-List | Out-String -Width 220 | Set-Content -LiteralPath $targetPath -Encoding UTF8
    $result
} finally {
    if ($baseline) {
        $baseline.Dispose()
    }
    if ($candidate) {
        $candidate.Dispose()
    }
}
