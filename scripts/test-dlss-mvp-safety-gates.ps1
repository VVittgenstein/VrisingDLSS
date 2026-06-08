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
        [Parameter(Mandatory = $true)][string[]]$RequiredMarkers,
        [Parameter(Mandatory = $true)][ValidateSet("ResizeReset", "Fallback")][string]$Kind
    )

    $resolvedPath = Resolve-RepoPath -Path $Path
    $exists = Test-Path -LiteralPath $resolvedPath -PathType Leaf
    $issues = New-Object System.Collections.Generic.List[string]
    $missingMarkers = @()
    $emptyMarkers = @()
    $placeholderMatches = @()
    $markerValues = @{}

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
            } else {
                $markerValues[$marker] = $markerMatch.Groups["value"].Value.Trim()
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

    $validationRoute = [string]$markerValues["Validation Route:"]
    if ($validationRoute -match '(?i)(synthetic|dry[- ]?run|template|paper[- ]?only|startup[- ]?only|menu[- ]?only)') {
        [void]$issues.Add("Validation Route must describe real gameplay validation, not synthetic/dry-run/startup-only evidence.")
    }

    $artifacts = [string]$markerValues["Artifacts:"]
    if (-not [string]::IsNullOrWhiteSpace($artifacts) -and $artifacts -notmatch '(?i)\bartifacts[\\/]') {
        [void]$issues.Add("Artifacts must reference local artifact paths under artifacts/.")
    }

    $cleanupEvidence = [string]$markerValues["Cleanup Evidence:"]
    if (-not [string]::IsNullOrWhiteSpace($cleanupEvidence) -and $cleanupEvidence -notmatch '(?i)(no .*process|process.*none|restor|cleanup.*pass|ChangeCount=0|release-safe)') {
        [void]$issues.Add("Cleanup Evidence must prove process cleanup and restored/release-safe state.")
    }

    if ($Kind -eq "ResizeReset") {
        $matrixAndResize = @(
            [string]$markerValues["Test Matrix:"],
            [string]$markerValues["Resolution Change Evidence:"]
        ) -join "`n"
        $resolutionTokens = @([regex]::Matches($matrixAndResize, '\b[0-9]{3,5}x[0-9]{3,5}\b') | ForEach-Object { $_.Value.ToLowerInvariant() } | Select-Object -Unique)
        if ($resolutionTokens.Count -lt 2 -and $matrixAndResize -notmatch '(?i)(resize|resolution).*(change|switch|->|to)') {
            [void]$issues.Add("Resize/reset validation must show an actual resolution or resize transition.")
        }

        $historyEvidence = [string]$markerValues["Camera/History Reset Evidence:"]
        if (-not [string]::IsNullOrWhiteSpace($historyEvidence) -and $historyEvidence -notmatch '(?i)(resetHistory|reset history|history reset|camera cut|reset=1)') {
            [void]$issues.Add("Camera/History Reset Evidence must mention resetHistory/history reset/camera cut evidence.")
        }

        $featureEvidence = [string]$markerValues["Feature Recreate/Reuse Evidence:"]
        if (-not [string]::IsNullOrWhiteSpace($featureEvidence) -and $featureEvidence -notmatch '(?i)((feature|ngx|dlss).*(recreate|reuse|destroy|release|resize|reset)|(recreate|reuse).*(feature|ngx|dlss))') {
            [void]$issues.Add("Feature Recreate/Reuse Evidence must cover DLSS/NGX feature lifecycle across resize/reset.")
        }
    } elseif ($Kind -eq "Fallback") {
        $fallbackCases = [string]$markerValues["Fallback Cases:"]
        foreach ($requiredCase in @("missing runtime", "unsupported gpu", "resource")) {
            if ($fallbackCases -notmatch [regex]::Escape($requiredCase)) {
                [void]$issues.Add("Fallback Cases must include $requiredCase.")
            }
        }

        foreach ($marker in @("Runtime Missing Behavior:", "Unsupported GPU Behavior:", "Resource Missing Behavior:", "Disable/Restore Behavior:")) {
            $value = [string]$markerValues[$marker]
            if ($value -match '(?i)(not tested|skipped|not run|unverified)') {
                [void]$issues.Add("$marker must not be untested/skipped/unverified.")
            }
            if (-not [string]::IsNullOrWhiteSpace($value) -and $value -notmatch '(?i)(fallback|disable|disabled|restor|unchanged|safe|substitute proof|clear status)') {
                [void]$issues.Add("$marker must prove safe fallback/disable/restore behavior or a documented substitute proof.")
            }
        }

        $userStatus = [string]$markerValues["User-Facing Status:"]
        if (-not [string]::IsNullOrWhiteSpace($userStatus) -and $userStatus -notmatch '(?i)(log|status|message|overlay|config|warning|reason)') {
            [void]$issues.Add("User-Facing Status must identify logs/status/messages that explain the fallback reason.")
        }
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
        MarkerValues = [pscustomobject]$markerValues
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

$resizeReset = Test-ValidationRecord -Path $ResizeResetPath -RequiredMarkers $resizeResetMarkers -Kind ResizeReset
$fallback = Test-ValidationRecord -Path $FallbackPath -RequiredMarkers $fallbackMarkers -Kind Fallback
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
