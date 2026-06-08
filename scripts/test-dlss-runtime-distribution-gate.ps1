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
$markerValues = @{}
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
            } else {
                $markerValues[$marker] = $markerMatch.Groups["value"].Value.Trim()
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

    $approvedRouteTypes = @(
        "Bundled NVIDIA DLSS SDK runtime",
        "Authoritative NVIDIA installer or dependency",
        "Documented non-NVIDIA-runtime route"
    )
    $runtimeRoute = [string]$markerValues["Runtime Route:"]
    if (-not [string]::IsNullOrWhiteSpace($runtimeRoute) -and -not ($approvedRouteTypes -contains $runtimeRoute)) {
        [void]$issues.Add("Runtime Route must be one of: $($approvedRouteTypes -join '; ')")
    }

    $sourceEvidenceUrls = [string]$markerValues["Source Evidence URLs:"]
    if (-not [string]::IsNullOrWhiteSpace($sourceEvidenceUrls) -and $sourceEvidenceUrls -notmatch 'https?://') {
        [void]$issues.Add("Source Evidence URLs must include at least one http(s) URL.")
    }

    $forbiddenRoutePattern = '(?i)(techpowerup|techspot|dll[- ]?files|dlss\s*swapper|third[- ]party\s+mirror|mirror\s+site|user[- ]?supplied|manual\s+dll\s+download|manually\s+download|arbitrary\s+dll|copy\s+your\s+own\s+dll)'
    $routeFieldsText = @(
        [string]$markerValues["Runtime Route:"],
        [string]$markerValues["Runtime Source:"],
        [string]$markerValues["User Installation Behavior:"],
        [string]$markerValues["Release Boundary Decision:"]
    ) -join "`n"
    if ($routeFieldsText -match $forbiddenRoutePattern) {
        [void]$issues.Add("Approval record describes a rejected runtime route such as third-party mirrors, manual DLL downloads, or user-supplied arbitrary DLLs.")
    }

    if ($runtimeRoute -eq "Bundled NVIDIA DLSS SDK runtime") {
        $runtimeSource = [string]$markerValues["Runtime Source:"]
        $runtimeFiles = [string]$markerValues["Runtime Files:"]
        $checksums = [string]$markerValues["Checksums:"]
        $licenseNotices = [string]$markerValues["License Notices:"]
        $trademarkWording = [string]$markerValues["Trademark Wording:"]
        $userInstallationBehavior = [string]$markerValues["User Installation Behavior:"]
        $notificationHandling = [string]$markerValues["NVIDIA Notification Handling:"]
        $packageValidationUpdates = [string]$markerValues["Package Validation Updates:"]
        $releaseBoundaryDecision = [string]$markerValues["Release Boundary Decision:"]
        $bundledFieldsText = @(
            $runtimeSource,
            $sourceEvidenceUrls,
            $runtimeFiles,
            $checksums,
            $licenseNotices,
            $trademarkWording,
            $userInstallationBehavior,
            $notificationHandling,
            $packageValidationUpdates,
            $releaseBoundaryDecision
        ) -join "`n"

        if ($runtimeSource -notmatch '(?i)(github\.com/NVIDIA/DLSS|developer\.nvidia\.com)') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must identify an authoritative NVIDIA/DLSS source.")
        }
        if ($sourceEvidenceUrls -notmatch '(?i)(github\.com/NVIDIA/DLSS|developer\.nvidia\.com)') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must include an official NVIDIA/DLSS source URL.")
        }
        if ($runtimeFiles -notmatch '(?i)\bnvngx_dlss\.dll\b') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must name nvngx_dlss.dll in Runtime Files.")
        }
        if ($checksums -notmatch '(?i)\bSHA256\b.*\b[0-9A-F]{64}\b') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must include a SHA256 checksum.")
        }
        if ($bundledFieldsText -notmatch '(?i)\b(production|release)\b' -or $bundledFieldsText -notmatch '(?i)non[- ]?watermarked|no\s+watermark') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must state that the runtime is production/release and non-watermarked.")
        }
        if ($bundledFieldsText -notmatch '(?i)(signed\s+by\s+NVIDIA|SignatureStatus\s*=\s*Valid|valid\s+NVIDIA\s+signature)') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must record a valid NVIDIA signature check.")
        }
        if ($licenseNotices -notmatch '(?i)(NVIDIA RTX SDKs license|LICENSE\.txt|RTX SDKs)') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must name the NVIDIA RTX SDKs license notice source.")
        }
        if ($trademarkWording -notmatch '(?i)\bNVIDIA\b' -or $trademarkWording -notmatch '(?i)\bDLSS\b') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must include NVIDIA and DLSS trademark wording.")
        }
        if ($notificationHandling -notmatch '(?i)developer\.nvidia\.com/sw-notification') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must explicitly address the NVIDIA SDK notification URL.")
        }
        if ($packageValidationUpdates -notmatch '(?i)check-release-boundary\.ps1' -or $packageValidationUpdates -notmatch '(?i)validate-thunderstore-package\.ps1' -or $packageValidationUpdates -notmatch '(?i)ThirdPartyNotices') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must name the package/release-boundary validation updates, including check-release-boundary.ps1, validate-thunderstore-package.ps1, and ThirdPartyNotices.")
        }
        if ($userInstallationBehavior -notmatch '(?i)(ships\s+with|bundled\s+with|included\s+in).*(mod|package|Thunderstore)') {
            [void]$issues.Add("Bundled NVIDIA DLSS SDK runtime approval must describe a drag-in/package install path that does not require manual DLL sourcing.")
        }
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
    MarkerValues = [pscustomobject]$markerValues
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
