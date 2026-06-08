param(
    [string]$Root,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path "$PSScriptRoot\..").Path
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$gateScript = Join-Path $resolvedRoot "scripts\test-dlss-mvp-safety-gates.ps1"
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

function Write-Record {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    $path = Join-Path $dryRunDir $Name
    Set-Content -LiteralPath $path -Value ($Lines -join [Environment]::NewLine) -Encoding UTF8
    return $path
}

function Invoke-SafetyGate {
    param(
        [Parameter(Mandatory = $true)][string]$ResizePath,
        [Parameter(Mandatory = $true)][string]$FallbackPath
    )

    $jsonText = & $gateScript -Root $resolvedRoot -ResizeResetPath $ResizePath -FallbackPath $FallbackPath -Json
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw "DLSS MVP safety gate produced no JSON."
    }

    return $jsonText | ConvertFrom-Json
}

$checks = New-Object System.Collections.Generic.List[object]

$goodResize = Write-Record -Name "DlssResizeResetValidationSyntheticGood.md" -Lines @(
    "# DLSS Resize Reset Validation",
    "Validation Route: Protected 11111 gameplay validation with real resolution changes",
    "Game Version: V Rising local C:\\Software\\VRising",
    "Mod Build: VrisingDLSS local release build",
    "Runtime Route: Approved NVIDIA DLSS runtime route under review",
    "Test Matrix: 1920x1080 -> 2560x1440 -> 1920x1080, Windowed, FSR Off baseline/candidate",
    "Resolution Change Evidence: artifacts\\resize-reset\\resize-good\\BepInEx.log shows resolution change 1920x1080 -> 2560x1440 and back",
    "Camera/History Reset Evidence: artifacts\\resize-reset\\resize-good\\BepInEx.log includes resetHistory=True and camera cut/history reset after resize",
    "Feature Recreate/Reuse Evidence: artifacts\\resize-reset\\resize-good\\BepInEx.log shows DLSS feature release/recreate or reuse after resize",
    "Cleanup Evidence: cleanup passed; no V Rising process remains; protected save restored with ChangeCount=0; release-safe config restored",
    "Artifacts: artifacts\\resize-reset\\resize-good\\BepInEx.log; artifacts\\resize-reset\\resize-good\\SaveCompareAfterRestore.json",
    "Reviewer: VrisingDLSS release reviewer",
    "Validation Date: 2026-06-08"
)

$goodFallback = Write-Record -Name "DlssFallbackValidationSyntheticGood.md" -Lines @(
    "# DLSS Fallback Validation",
    "Validation Route: Protected 11111 gameplay fallback validation",
    "Game Version: V Rising local C:\\Software\\VRising",
    "Mod Build: VrisingDLSS local release build",
    "Fallback Cases: missing runtime; unsupported GPU; resource missing/resource acquisition failure",
    "Runtime Missing Behavior: missing runtime disables DLSS and falls back to unchanged native rendering with clear status log",
    "Unsupported GPU Behavior: unsupported GPU path uses substitute proof and disables DLSS safely with fallback status log",
    "Resource Missing Behavior: resource missing failure disables DLSS, restores native rendering, and logs a clear reason",
    "Disable/Restore Behavior: disabling DLSS restores release-safe config and unchanged native rendering",
    "User-Facing Status: BepInEx log warning/status messages explain each fallback reason",
    "Cleanup Evidence: cleanup passed; no V Rising process remains; protected save restored with ChangeCount=0; release-safe config restored",
    "Artifacts: artifacts\\fallback\\fallback-good\\BepInEx.log; artifacts\\fallback\\fallback-good\\SaveCompareAfterRestore.json",
    "Reviewer: VrisingDLSS release reviewer",
    "Validation Date: 2026-06-08"
)

$goodResult = Invoke-SafetyGate -ResizePath $goodResize -FallbackPath $goodFallback
Add-Check -Checks $checks `
    -Name "synthetic good resize/fallback validation passes" `
    -Passed ($goodResult.Status -eq "Pass" -and $goodResult.ResizeReset.Status -eq "Pass" -and $goodResult.Fallback.Status -eq "Pass") `
    -Evidence "Status=$($goodResult.Status); Resize=$($goodResult.ResizeReset.Status); Fallback=$($goodResult.Fallback.Status); Issues=$(@($goodResult.ResizeReset.Issues + $goodResult.Fallback.Issues) -join ' | ')"

$badResize = Write-Record -Name "DlssResizeResetValidationSyntheticBad.md" -Lines @(
    "# DLSS Resize Reset Validation",
    "Validation Route: startup only menu dry-run",
    "Game Version: V Rising local C:\\Software\\VRising",
    "Mod Build: VrisingDLSS local release build",
    "Runtime Route: no runtime route",
    "Test Matrix: 1920x1080 only",
    "Resolution Change Evidence: no resize was performed",
    "Camera/History Reset Evidence: camera was stable",
    "Feature Recreate/Reuse Evidence: feature was not inspected",
    "Cleanup Evidence: finished",
    "Artifacts: docs\\notes\\not-an-artifact.md",
    "Reviewer: VrisingDLSS release reviewer",
    "Validation Date: 2026-06-08"
)

$badResizeResult = Invoke-SafetyGate -ResizePath $badResize -FallbackPath $goodFallback
Add-Check -Checks $checks `
    -Name "synthetic startup-only resize validation is rejected" `
    -Passed ($badResizeResult.Status -eq "Fail" -and $badResizeResult.ResizeReset.Status -eq "Fail" -and @($badResizeResult.ResizeReset.Issues).Count -gt 0) `
    -Evidence "Status=$($badResizeResult.Status); Issues=$(@($badResizeResult.ResizeReset.Issues) -join ' | ')"

$badFallback = Write-Record -Name "DlssFallbackValidationSyntheticBad.md" -Lines @(
    "# DLSS Fallback Validation",
    "Validation Route: Protected 11111 gameplay fallback validation",
    "Game Version: V Rising local C:\\Software\\VRising",
    "Mod Build: VrisingDLSS local release build",
    "Fallback Cases: missing runtime only",
    "Runtime Missing Behavior: not tested",
    "Unsupported GPU Behavior: skipped",
    "Resource Missing Behavior: not run",
    "Disable/Restore Behavior: unverified",
    "User-Facing Status: no user-facing output",
    "Cleanup Evidence: finished",
    "Artifacts: docs\\notes\\not-an-artifact.md",
    "Reviewer: VrisingDLSS release reviewer",
    "Validation Date: 2026-06-08"
)

$badFallbackResult = Invoke-SafetyGate -ResizePath $goodResize -FallbackPath $badFallback
Add-Check -Checks $checks `
    -Name "synthetic incomplete fallback validation is rejected" `
    -Passed ($badFallbackResult.Status -eq "Fail" -and $badFallbackResult.Fallback.Status -eq "Fail" -and @($badFallbackResult.Fallback.Issues).Count -gt 0) `
    -Evidence "Status=$($badFallbackResult.Status); Issues=$(@($badFallbackResult.Fallback.Issues) -join ' | ')"

$failedChecks = @($checks.ToArray() | Where-Object { -not $_.Passed })
$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Checks = @($checks.ToArray())
    SyntheticRecordPaths = @($goodResize, $goodFallback, $badResize, $badFallback)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}

if ($failedChecks.Count -gt 0) {
    exit 1
}
