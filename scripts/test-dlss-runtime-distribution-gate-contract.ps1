param(
    [string]$Root,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path "$PSScriptRoot\..").Path
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$gateScript = Join-Path $resolvedRoot "scripts\test-dlss-runtime-distribution-gate.ps1"
$gatePath = Join-Path $resolvedRoot "docs\development\dlss-runtime-distribution-gate-2026-06-08.md"
$dryRunDir = Join-Path $resolvedRoot "artifacts\dryrun"
New-Item -ItemType Directory -Path $dryRunDir -Force | Out-Null

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [string]$Evidence = ""
    )

    [void]$Checks.Add([pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Evidence = $Evidence
    })
}

function Write-Approval {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    $path = Join-Path $dryRunDir $Name
    Set-Content -LiteralPath $path -Value ($Lines -join [Environment]::NewLine) -Encoding UTF8
    return $path
}

function Invoke-Gate {
    param([Parameter(Mandatory = $true)][string]$ApprovalPath)

    $jsonText = & $gateScript -Root $resolvedRoot -GatePath $gatePath -ApprovalPath $ApprovalPath -Json
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw "Runtime distribution gate produced no JSON for $ApprovalPath"
    }

    return $jsonText | ConvertFrom-Json
}

$checks = New-Object System.Collections.Generic.List[object]

$approvedBundled = Write-Approval -Name "DlssRuntimeDistributionApprovalSyntheticBundled.md" -Lines @(
    "# DLSS Runtime Distribution Approval",
    "Runtime Route: Bundled NVIDIA DLSS SDK runtime",
    "Runtime Source: NVIDIA/DLSS GitHub release v310.6.0",
    "Source Evidence URLs: https://github.com/NVIDIA/DLSS https://github.com/NVIDIA/DLSS/releases/tag/v310.6.0 https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt",
    "Runtime Version: 310.6.0.0",
    "Runtime Files: nvngx_dlss.dll",
    "Checksums: SHA256=099B3E1E3AD3F226DE621FE570B26CC554CC775E2606BE23EB222D6245674070",
    "License Notices: NVIDIA RTX SDKs license terms reviewed for this route.",
    "Trademark Wording: NVIDIA and DLSS are trademarks or registered trademarks of NVIDIA Corporation.",
    "User Installation Behavior: Runtime ships with the mod package after release-boundary approval.",
    "NVIDIA Notification Handling: DLSS SDK notification requirement reviewed before public release.",
    "Package Validation Updates: Release boundary and package validation updated for the exact runtime file.",
    "Release Boundary Decision: Approved only for this exact bundled NVIDIA runtime route.",
    "Reviewer: VrisingDLSS release reviewer",
    "Approval Date: 2026-06-08"
)

$approvedResult = Invoke-Gate -ApprovalPath $approvedBundled
Add-Check -Checks $checks `
    -Name "synthetic bundled approval passes semantic gate" `
    -Passed ($approvedResult.Status -eq "Pass" -and $approvedResult.RuntimeDistributionApproved -eq $true) `
    -Evidence "Status=$($approvedResult.Status); Issues=$(@($approvedResult.Issues) -join ' | ')"

$badRoute = Write-Approval -Name "DlssRuntimeDistributionApprovalSyntheticThirdParty.md" -Lines @(
    "# DLSS Runtime Distribution Approval",
    "Runtime Route: Bundled NVIDIA DLSS SDK runtime",
    "Runtime Source: TechPowerUp DLSS DLL mirror",
    "Source Evidence URLs: https://www.techpowerup.com/download/nvidia-dlss-dll/",
    "Runtime Version: 310.6.0.0",
    "Runtime Files: nvngx_dlss.dll",
    "Checksums: SHA256=099B3E1E3AD3F226DE621FE570B26CC554CC775E2606BE23EB222D6245674070",
    "License Notices: Mirror download terms reviewed.",
    "Trademark Wording: NVIDIA and DLSS are trademarks or registered trademarks of NVIDIA Corporation.",
    "User Installation Behavior: User manually downloads a DLL from a third-party mirror.",
    "NVIDIA Notification Handling: Not applicable for mirror route.",
    "Package Validation Updates: None.",
    "Release Boundary Decision: Approved third-party mirror route.",
    "Reviewer: VrisingDLSS release reviewer",
    "Approval Date: 2026-06-08"
)

$badRouteResult = Invoke-Gate -ApprovalPath $badRoute
Add-Check -Checks $checks `
    -Name "synthetic third-party/manual route is rejected" `
    -Passed ($badRouteResult.Status -eq "Fail" -and @($badRouteResult.Issues | Where-Object { $_ -like "*rejected runtime route*" }).Count -gt 0) `
    -Evidence "Status=$($badRouteResult.Status); Issues=$(@($badRouteResult.Issues) -join ' | ')"

$missingUrl = Write-Approval -Name "DlssRuntimeDistributionApprovalSyntheticMissingUrl.md" -Lines @(
    "# DLSS Runtime Distribution Approval",
    "Runtime Route: Bundled NVIDIA DLSS SDK runtime",
    "Runtime Source: NVIDIA/DLSS GitHub release v310.6.0",
    "Source Evidence URLs: NVIDIA DLSS release page",
    "Runtime Version: 310.6.0.0",
    "Runtime Files: nvngx_dlss.dll",
    "Checksums: SHA256=099B3E1E3AD3F226DE621FE570B26CC554CC775E2606BE23EB222D6245674070",
    "License Notices: NVIDIA RTX SDKs license terms reviewed for this route.",
    "Trademark Wording: NVIDIA and DLSS are trademarks or registered trademarks of NVIDIA Corporation.",
    "User Installation Behavior: Runtime ships with the mod package after release-boundary approval.",
    "NVIDIA Notification Handling: DLSS SDK notification requirement reviewed before public release.",
    "Package Validation Updates: Release boundary and package validation updated for the exact runtime file.",
    "Release Boundary Decision: Approved only for this exact bundled NVIDIA runtime route.",
    "Reviewer: VrisingDLSS release reviewer",
    "Approval Date: 2026-06-08"
)

$missingUrlResult = Invoke-Gate -ApprovalPath $missingUrl
Add-Check -Checks $checks `
    -Name "synthetic approval without source URL is rejected" `
    -Passed ($missingUrlResult.Status -eq "Fail" -and @($missingUrlResult.Issues | Where-Object { $_ -like "*Source Evidence URLs*" }).Count -gt 0) `
    -Evidence "Status=$($missingUrlResult.Status); Issues=$(@($missingUrlResult.Issues) -join ' | ')"

$missingChecksum = Write-Approval -Name "DlssRuntimeDistributionApprovalSyntheticMissingChecksum.md" -Lines @(
    "# DLSS Runtime Distribution Approval",
    "Runtime Route: Bundled NVIDIA DLSS SDK runtime",
    "Runtime Source: NVIDIA/DLSS GitHub release v310.6.0",
    "Source Evidence URLs: https://github.com/NVIDIA/DLSS/releases/tag/v310.6.0",
    "Runtime Version: 310.6.0.0",
    "Runtime Files: nvngx_dlss.dll",
    "Checksums: Signed by NVIDIA",
    "License Notices: NVIDIA RTX SDKs license terms reviewed for this route.",
    "Trademark Wording: NVIDIA and DLSS are trademarks or registered trademarks of NVIDIA Corporation.",
    "User Installation Behavior: Runtime ships with the mod package after release-boundary approval.",
    "NVIDIA Notification Handling: DLSS SDK notification requirement reviewed before public release.",
    "Package Validation Updates: Release boundary and package validation updated for the exact runtime file.",
    "Release Boundary Decision: Approved only for this exact bundled NVIDIA runtime route.",
    "Reviewer: VrisingDLSS release reviewer",
    "Approval Date: 2026-06-08"
)

$missingChecksumResult = Invoke-Gate -ApprovalPath $missingChecksum
Add-Check -Checks $checks `
    -Name "synthetic bundled approval without SHA256 is rejected" `
    -Passed ($missingChecksumResult.Status -eq "Fail" -and @($missingChecksumResult.Issues | Where-Object { $_ -like "*SHA256*" }).Count -gt 0) `
    -Evidence "Status=$($missingChecksumResult.Status); Issues=$(@($missingChecksumResult.Issues) -join ' | ')"

$failedChecks = @($checks.ToArray() | Where-Object { -not $_.Passed })
$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Checks = @($checks.ToArray())
    SyntheticApprovalPaths = @($approvedBundled, $badRoute, $missingUrl, $missingChecksum)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}

if ($failedChecks.Count -gt 0) {
    exit 1
}
