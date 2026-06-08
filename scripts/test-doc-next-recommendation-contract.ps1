param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]
$visualStatus = $null

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

function Get-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $resolvedRoot $RelativePath
}

function Test-ContainsText {
    param(
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Needle
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return $false
    }

    return $Text.IndexOf($Needle, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-FileText {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ""
    }

    return Get-Content -LiteralPath $Path -Raw
}

$visualScript = Get-RepoPath -RelativePath "scripts\get-visual-validation-status.ps1"
$contractBindProofScript = Get-RepoPath -RelativePath "scripts\get-contract-bind-gameplay-proof.ps1"
$mvpPath = Get-RepoPath -RelativePath "docs\mvp.md"
$installPath = Get-RepoPath -RelativePath "docs\install.md"
$contextPath = Get-RepoPath -RelativePath "docs\context\current-context.md"
$proofDocPath = Get-RepoPath -RelativePath "docs\development\hdrp-dlss-contract-bind-render-scale-gameplay-result-2026-06-08.md"

foreach ($path in @($visualScript, $contractBindProofScript, $mvpPath, $installPath, $contextPath, $proofDocPath)) {
    Add-Check `
        -Name "FileExists:$([System.IO.Path]::GetFileName($path))" `
        -Passed (Test-Path -LiteralPath $path -PathType Leaf) `
        -Evidence $path `
        -Failure "missing $path"
}

$contractBindProof = $null
$contractBindProofPassed = $false
if (Test-Path -LiteralPath $contractBindProofScript -PathType Leaf) {
    try {
        $contractBindProofJson = & $contractBindProofScript -Root $resolvedRoot -Json
        if (-not [string]::IsNullOrWhiteSpace([string]$contractBindProofJson)) {
            $contractBindProof = $contractBindProofJson | ConvertFrom-Json
            $contractBindProofPassed = [string]$contractBindProof.Status -eq "Pass"
        }
    } catch {
        Add-Check `
            -Name "ContractBindProofDetectorReadable" `
            -Passed $false `
            -Evidence $_.Exception.Message `
            -Failure $_.Exception.Message
    }
}

if (Test-Path -LiteralPath $visualScript -PathType Leaf) {
    try {
        $visualJson = & $visualScript -Root $resolvedRoot -RequiredCandidateStage dlss-user-rendering -Json
        if ([string]::IsNullOrWhiteSpace([string]$visualJson)) {
            throw "visual status produced no JSON"
        }

        $visualStatus = $visualJson | ConvertFrom-Json
        $visualIssues = @($visualStatus.Issues) -join " | "
        $hasRegressionEvidence = $visualStatus.Status -ne "Pass" -and (
            [double]$visualStatus.AverageFpsDeltaPercent -lt -10.0 -or
            [double]$visualStatus.OnePercentLowFpsDeltaPercent -lt -15.0 -or
            [double]$visualStatus.P95FrameMsDeltaPercent -gt 15.0 -or
            $visualIssues -match "regressed|worsened"
        )

        Add-Check `
            -Name "VisualGateHasKnownUserRenderingRegressionEvidence" `
            -Passed $hasRegressionEvidence `
            -Evidence "Status=$($visualStatus.Status); AverageFpsDeltaPercent=$($visualStatus.AverageFpsDeltaPercent); OnePercentLowFpsDeltaPercent=$($visualStatus.OnePercentLowFpsDeltaPercent); P95FrameMsDeltaPercent=$($visualStatus.P95FrameMsDeltaPercent)" `
            -Failure "visual gate no longer exposes the known dlss-user-rendering performance regression that this doc contract is meant to track"

        Add-Check `
            -Name "VisualGateNextRecommendationAdvancesWithContractBindProofState" `
            -Passed ($(if ($contractBindProofPassed) {
                    (Test-ContainsText -Text $visualStatus.NextRecommendation -Needle "bounded no-write") `
                        -and (Test-ContainsText -Text $visualStatus.NextRecommendation -Needle "EASU carrier-only") `
                        -and (Test-ContainsText -Text $visualStatus.NextRecommendation -Needle "empty existing command-buffer plugin-event") `
                        -and (-not (Test-ContainsText -Text $visualStatus.NextRecommendation -Needle "Next work should run the protected hdrp-dlss-contract-bind-render-scale proof"))
                } else {
                    (Test-ContainsText -Text $visualStatus.NextRecommendation -Needle "Do not rerun the same EASU ctx.cmd") `
                        -and (Test-ContainsText -Text $visualStatus.NextRecommendation -Needle "hdrp-dlss-contract-bind-render-scale")
                })) `
            -Evidence $visualStatus.NextRecommendation `
            -Failure "visual gate next recommendation no longer points away from unchanged user-rendering and toward the correct post-contract-bind step"
    } catch {
        Add-Check `
            -Name "VisualGateStatusReadableForDocContract" `
            -Passed $false `
            -Evidence $_.Exception.Message `
            -Failure $_.Exception.Message
    }
}

$mvpText = Get-FileText -Path $mvpPath
$installText = Get-FileText -Path $installPath
$contextText = Get-FileText -Path $contextPath
$proofDocText = Get-FileText -Path $proofDocPath

Add-Check `
    -Name "MvpDocMarksUserRenderingAsKnownRegressedAndContractBindPassed" `
    -Passed ((Test-ContainsText -Text $mvpText -Needle "known-regressed route") `
        -and (Test-ContainsText -Text $mvpText -Needle 'Do not rerun the same EASU `ctx.cmd` `dlss-user-rendering` candidate unchanged') `
        -and (Test-ContainsText -Text $mvpText -Needle "contract-bind proof has now passed") `
        -and (Test-ContainsText -Text $mvpText -Needle "bounded no-write B/C/D cost isolation") `
        -and (Test-ContainsText -Text $mvpText -Needle "ChangeCount=0")) `
    -Evidence $mvpPath `
    -Failure "docs/mvp.md must keep the current visual gate as blocked on a known-regressed user-rendering route and name bounded no-write B/C/D as next runtime proof after contract-bind passed"

Add-Check `
    -Name "InstallDocTopStatusDoesNotPromoteUnchangedUserRenderingOrContractBindRerun" `
    -Passed ((Test-ContainsText -Text $installText -Needle "performance-regressed") `
        -and (Test-ContainsText -Text $installText -Needle 'Do not treat `dlss-user-rendering` as the next runtime proof to rerun unchanged') `
        -and (Test-ContainsText -Text $installText -Needle "contract-bind proof has passed") `
        -and (Test-ContainsText -Text $installText -Needle "bounded no-write B/C/D cost isolation")) `
    -Evidence $installPath `
    -Failure "docs/install.md top status must name the user-rendering regression and current bounded no-write B/C/D next proof"

Add-Check `
    -Name "InstallDocVisualHelperAllowsOnlyIntentionalReproduction" `
    -Passed ((Test-ContainsText -Text $installText -Needle 'The visual helper can still capture `dlss-user-rendering` when intentionally reproducing or investigating that candidate') `
        -and (Test-ContainsText -Text $installText -Needle 'not another unchanged `dlss-user-rendering` visual comparison') `
        -and (Test-ContainsText -Text $installText -Needle 'next runtime proof is bounded no-write B/C/D cost isolation')) `
    -Evidence $installPath `
    -Failure "docs/install.md must keep dlss-user-rendering visual captures framed as reproduction/investigation, not the main next proof"

Add-Check `
    -Name "InstallDocDlssEnableDescriptionWarnsAboutCurrentRegression" `
    -Passed ((Test-ContainsText -Text $installText -Needle '`DLSS.EnableDLSS=true`, or helper stage `dlss-user-rendering`, remains an experimental normal-user-path candidate') `
        -and (Test-ContainsText -Text $installText -Needle "is not the next runtime proof to rerun unchanged") `
        -and (Test-ContainsText -Text $installText -Needle "bounded no-write B/C/D cost isolation")) `
    -Evidence $installPath `
    -Failure "docs/install.md DLSS.EnableDLSS section must not describe dlss-user-rendering as the current next route without the regression warning"

Add-Check `
    -Name "DocsDoNotContainStaleNextValidationMustRunUserRenderingPhrase" `
    -Passed ((-not (Test-ContainsText -Text $mvpText -Needle 'The next validation must run `scripts\run-vrising-visual-comparison.ps1 -CandidateStage dlss-user-rendering')) `
        -and (-not (Test-ContainsText -Text $installText -Needle 'The next validation must run `scripts\run-vrising-visual-comparison.ps1 -CandidateStage dlss-user-rendering'))) `
    -Evidence "docs/mvp.md; docs/install.md" `
    -Failure "stale next-validation guidance points directly back to the known-regressed user-rendering route"

Add-Check `
    -Name "DurableContextRecordsDocRecommendationGuard" `
    -Passed ((Test-ContainsText -Text $contextText -Needle "scripts\test-doc-next-recommendation-contract.ps1") `
        -and (Test-ContainsText -Text $contextText -Needle 'cannot drift') `
        -and (Test-ContainsText -Text $contextText -Needle 'rerunning the unchanged `dlss-user-rendering` candidate') `
        -and (Test-ContainsText -Text $contextText -Needle "contract-bind proof has passed") `
        -and (Test-ContainsText -Text $contextText -Needle "bounded no-write B/C/D cost isolation")) `
    -Evidence $contextPath `
    -Failure "durable context must record the doc recommendation guard"

Add-Check `
    -Name "ContractBindProofDocHasMachineReadableMarkers" `
    -Passed ((Test-ContainsText -Text $proofDocText -Needle "Status: Pass") `
        -and (Test-ContainsText -Text $proofDocText -Needle "EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved=true") `
        -and (Test-ContainsText -Text $proofDocText -Needle "RenderGraphGetTextureCalls=0") `
        -and (Test-ContainsText -Text $proofDocText -Needle "UserRenderingCandidateStarted=0") `
        -and (Test-ContainsText -Text $proofDocText -Needle "DlssEvaluateSucceeded=0") `
        -and (Test-ContainsText -Text $proofDocText -Needle "SaveAfterRestoreChangeCount=0") `
        -and (Test-ContainsText -Text $proofDocText -Needle "bounded no-write cost proof")) `
    -Evidence $proofDocPath `
    -Failure "contract-bind proof doc must preserve machine-readable markers for CI/no-artifact status"

$failedChecks = @($checks.ToArray() | Where-Object { $_.Status -ne "Pass" })
$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    VisualStatus = if ($visualStatus) { [string]$visualStatus.Status } else { "" }
    VisualNextRecommendation = if ($visualStatus) { [string]$visualStatus.NextRecommendation } else { "" }
    ContractBindGameplayProofStatus = if ($contractBindProof) { [string]$contractBindProof.Status } else { "" }
    ContractBindGameplayProofSource = if ($contractBindProof) { [string]$contractBindProof.Source } else { "" }
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Issues = @($issues.ToArray())
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
