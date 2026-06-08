param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$GatePath = "docs\development\dlss-runtime-distribution-gate-2026-06-08.md",
    [string]$ApprovalPath = "docs\release\dlss-runtime-distribution-approval.md",
    [switch]$RequireApproved,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$issues = New-Object System.Collections.Generic.List[string]

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path $resolvedRoot $Path)
}

$resolvedGatePath = Resolve-RepoPath -Path $GatePath
$resolvedApprovalPath = Resolve-RepoPath -Path $ApprovalPath
$gateExists = Test-Path -LiteralPath $resolvedGatePath -PathType Leaf
$approvalExists = Test-Path -LiteralPath $resolvedApprovalPath -PathType Leaf

if (-not $gateExists) {
    [void]$issues.Add("Missing runtime distribution gate document: $resolvedGatePath")
}

$requiredApprovalMarkers = @(
    "# DLSS Runtime Distribution Approval",
    "Runtime Route:",
    "Runtime Source:",
    "Source Evidence URLs:",
    "Runtime Version:",
    "Runtime Files:",
    "Checksums:",
    "License Notices:",
    "Trademark Wording:",
    "User Installation Behavior:",
    "NVIDIA Notification Handling:",
    "Package Validation Updates:",
    "Release Boundary Decision:",
    "Reviewer:",
    "Approval Date:"
)

$missingApprovalMarkers = @()
$emptyApprovalMarkers = @()
$placeholderMatches = @()
$approvalText = ""
if ($approvalExists) {
    $approvalText = Get-Content -LiteralPath $resolvedApprovalPath -Raw
    foreach ($marker in $requiredApprovalMarkers) {
        if ($approvalText.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $missingApprovalMarkers += $marker
            continue
        }

        if ($marker.EndsWith(":", [System.StringComparison]::Ordinal)) {
            $escapedMarker = [regex]::Escape($marker)
            $markerMatch = [regex]::Match($approvalText, "(?im)^\s*$escapedMarker\s*(?<value>\S.*)?$")
            if (-not $markerMatch.Success -or [string]::IsNullOrWhiteSpace($markerMatch.Groups["value"].Value)) {
                $emptyApprovalMarkers += $marker
            }
        }
    }

    $placeholderPattern = '(?i)\b(TBD|TODO|PLACEHOLDER|UNKNOWN|UNRESOLVED|FILL ME|NOT DECIDED)\b|<[^>\r\n]+>'
    $placeholderMatches = @([regex]::Matches($approvalText, $placeholderPattern) | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($missingApprovalMarkers.Count -gt 0) {
        [void]$issues.Add("Approval record is missing required markers: $($missingApprovalMarkers -join ', ')")
    }
    if ($emptyApprovalMarkers.Count -gt 0) {
        [void]$issues.Add("Approval record has empty required marker values: $($emptyApprovalMarkers -join ', ')")
    }
    if ($placeholderMatches.Count -gt 0) {
        [void]$issues.Add("Approval record still contains placeholders: $($placeholderMatches -join ', ')")
    }
}

$status = if (-not $gateExists) {
    "Fail"
} elseif (-not $approvalExists) {
    "Blocked"
} elseif ($issues.Count -gt 0) {
    "Fail"
} else {
    "Pass"
}

$result = [pscustomobject]@{
    Status = $status
    LaunchesGame = $false
    ModifiesGameFiles = $false
    RuntimeDistributionApproved = ($status -eq "Pass")
    GatePath = $resolvedGatePath
    ApprovalPath = $resolvedApprovalPath
    GateExists = $gateExists
    ApprovalExists = $approvalExists
    RequiredApprovalMarkerCount = $requiredApprovalMarkers.Count
    MissingApprovalMarkers = @($missingApprovalMarkers)
    EmptyApprovalMarkers = @($emptyApprovalMarkers)
    PlaceholderCount = $placeholderMatches.Count
    Placeholders = @($placeholderMatches)
    Issues = @($issues)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}

if ($RequireApproved -and $status -ne "Pass") {
    exit 1
}
