param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$ResizeResetPath = "docs\release\dlss-resize-reset-validation.md",
    [string]$FallbackPath = "docs\release\dlss-fallback-validation.md",
    [switch]$RequirePass,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path $resolvedRoot $Path)
}

function Test-ValidationRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$RequiredMarkers
    )

    $resolvedPath = Resolve-RepoPath -Path $Path
    $exists = Test-Path -LiteralPath $resolvedPath -PathType Leaf
    $issues = New-Object System.Collections.Generic.List[string]
    $missingMarkers = @()
    $emptyMarkers = @()
    $placeholderMatches = @()

    if (-not $exists) {
        return [pscustomobject]@{
            Status = "Blocked"
            Path = $resolvedPath
            Exists = $false
            RequiredMarkerCount = $RequiredMarkers.Count
            MissingMarkers = @()
            EmptyMarkers = @()
            PlaceholderCount = 0
            Placeholders = @()
            Issues = @("Missing validation record: $resolvedPath")
        }
    }

    $text = Get-Content -LiteralPath $resolvedPath -Raw
    foreach ($marker in $RequiredMarkers) {
        if ($text.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $missingMarkers += $marker
            continue
        }

        if ($marker.EndsWith(":", [System.StringComparison]::Ordinal)) {
            $escapedMarker = [regex]::Escape($marker)
            $markerMatch = [regex]::Match($text, "(?im)^\s*$escapedMarker\s*(?<value>\S.*)?$")
            if (-not $markerMatch.Success -or [string]::IsNullOrWhiteSpace($markerMatch.Groups["value"].Value)) {
                $emptyMarkers += $marker
            }
        }
    }

    $placeholderPattern = '(?i)\b(TBD|TODO|PLACEHOLDER|UNKNOWN|UNRESOLVED|FILL ME|NOT DECIDED)\b|<[^>\r\n]+>'
    $placeholderMatches = @([regex]::Matches($text, $placeholderPattern) | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($missingMarkers.Count -gt 0) {
        [void]$issues.Add("Validation record is missing required markers: $($missingMarkers -join ', ')")
    }
    if ($emptyMarkers.Count -gt 0) {
        [void]$issues.Add("Validation record has empty required marker values: $($emptyMarkers -join ', ')")
    }
    if ($placeholderMatches.Count -gt 0) {
        [void]$issues.Add("Validation record still contains placeholders: $($placeholderMatches -join ', ')")
    }

    [pscustomobject]@{
        Status = $(if ($issues.Count -eq 0) { "Pass" } else { "Fail" })
        Path = $resolvedPath
        Exists = $true
        RequiredMarkerCount = $RequiredMarkers.Count
        MissingMarkers = @($missingMarkers)
        EmptyMarkers = @($emptyMarkers)
        PlaceholderCount = $placeholderMatches.Count
        Placeholders = @($placeholderMatches)
        Issues = @($issues)
    }
}

$resizeResetMarkers = @(
    "# DLSS Resize Reset Validation",
    "Validation Route:",
    "Game Version:",
    "Mod Build:",
    "Runtime Route:",
    "Test Matrix:",
    "Resolution Change Evidence:",
    "Camera/History Reset Evidence:",
    "Feature Recreate/Reuse Evidence:",
    "Cleanup Evidence:",
    "Artifacts:",
    "Reviewer:",
    "Validation Date:"
)

$fallbackMarkers = @(
    "# DLSS Fallback Validation",
    "Validation Route:",
    "Game Version:",
    "Mod Build:",
    "Fallback Cases:",
    "Runtime Missing Behavior:",
    "Unsupported GPU Behavior:",
    "Resource Missing Behavior:",
    "Disable/Restore Behavior:",
    "User-Facing Status:",
    "Cleanup Evidence:",
    "Artifacts:",
    "Reviewer:",
    "Validation Date:"
)

$resizeReset = Test-ValidationRecord -Path $ResizeResetPath -RequiredMarkers $resizeResetMarkers
$fallback = Test-ValidationRecord -Path $FallbackPath -RequiredMarkers $fallbackMarkers
$overallStatus = if ($resizeReset.Status -eq "Pass" -and $fallback.Status -eq "Pass") {
    "Pass"
} elseif ($resizeReset.Status -eq "Fail" -or $fallback.Status -eq "Fail") {
    "Fail"
} else {
    "Blocked"
}

$result = [pscustomobject]@{
    Status = $overallStatus
    LaunchesGame = $false
    ModifiesGameFiles = $false
    ResizeReset = $resizeReset
    Fallback = $fallback
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}

if ($RequirePass -and $overallStatus -ne "Pass") {
    exit 1
}
