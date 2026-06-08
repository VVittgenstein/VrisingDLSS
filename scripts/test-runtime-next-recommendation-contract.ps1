param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$GamePath,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]
$visualStatus = $null
$runtimeStatus = $null

function Add-Check {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [string]$Evidence = ""
    )

    [void]$checks.Add([pscustomobject]@{
            Name = $Name
            Passed = $Passed
            Evidence = $Evidence
        })

    if (-not $Passed) {
        [void]$issues.Add($Name)
    }
}

function Get-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $resolvedRoot $RelativePath
}

$runtimeScript = Get-RepoPath -RelativePath "scripts\get-runtime-validation-status.ps1"
$visualScript = Get-RepoPath -RelativePath "scripts\get-visual-validation-status.ps1"

Add-Check `
    -Name "runtime status script exists" `
    -Passed (Test-Path -LiteralPath $runtimeScript -PathType Leaf) `
    -Evidence $runtimeScript

Add-Check `
    -Name "visual status script exists" `
    -Passed (Test-Path -LiteralPath $visualScript -PathType Leaf) `
    -Evidence $visualScript

if (Test-Path -LiteralPath $runtimeScript -PathType Leaf) {
    $runtimeText = Get-Content -LiteralPath $runtimeScript -Raw
    Add-Check `
        -Name "runtime status consults blocked user-rendering visual gate before recommending another visual run" `
        -Passed ($runtimeText -match "Get-BlockedUserRenderingVisualRecommendation" -and $runtimeText -match "get-visual-validation-status\.ps1" -and $runtimeText -match "RequiredCandidateStage dlss-user-rendering") `
        -Evidence "get-runtime-validation-status.ps1"
}

$hasVisualPerformanceRegression = $false
if (Test-Path -LiteralPath $visualScript -PathType Leaf) {
    try {
        $visualJson = & $visualScript -Root $resolvedRoot -RequiredCandidateStage dlss-user-rendering -Json
        if (-not [string]::IsNullOrWhiteSpace([string]$visualJson)) {
            $visualStatus = $visualJson | ConvertFrom-Json
            $visualIssues = @($visualStatus.Issues) -join " | "
            $hasVisualPerformanceRegression = $visualStatus.Status -ne "Pass" -and (
                $visualStatus.NextRecommendation -match "Do not rerun the same EASU ctx\.cmd" -or
                $visualIssues -match "Candidate average FPS regressed|Candidate 1% low FPS regressed|Candidate P95 frame time worsened"
            )

            if ($hasVisualPerformanceRegression) {
                Add-Check `
                    -Name "visual gate recommends official-equivalent contract-bind route after performance regression" `
                    -Passed ($visualStatus.NextRecommendation -match "Do not rerun the same EASU ctx\.cmd" -and $visualStatus.NextRecommendation -match "hdrp-dlss-contract-bind-render-scale") `
                    -Evidence "Status=$($visualStatus.Status); AverageFpsDeltaPercent=$($visualStatus.AverageFpsDeltaPercent); P95FrameMsDeltaPercent=$($visualStatus.P95FrameMsDeltaPercent)"
            }
        }
    } catch {
        Add-Check -Name "visual gate can be read for recommendation contract" -Passed $false -Evidence $_.Exception.Message
    }
}

if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    if (-not (Test-Path -LiteralPath (Join-Path $GamePath "VRising.exe") -PathType Leaf)) {
        Add-Check -Name "local GamePath contains VRising.exe" -Passed $false -Evidence $GamePath
    } else {
        Add-Check -Name "local GamePath contains VRising.exe" -Passed $true -Evidence (Join-Path $GamePath "VRising.exe")
    }

    try {
        $runtimeJson = & $runtimeScript -Root $resolvedRoot -GamePath $GamePath -IncludeArchivedLogs -Json
        if ([string]::IsNullOrWhiteSpace([string]$runtimeJson)) {
            throw "Runtime status produced no JSON."
        }

        $runtimeStatus = $runtimeJson | ConvertFrom-Json
        if ($hasVisualPerformanceRegression) {
            Add-Check `
                -Name "runtime next recommendation does not send user-rendering performance regression back to the same candidate" `
                -Passed ($runtimeStatus.NextRecommendation -match "Do not rerun the same EASU ctx\.cmd" -and $runtimeStatus.NextRecommendation -match "hdrp-dlss-contract-bind-render-scale" -and $runtimeStatus.NextRecommendation -notmatch "Next engineering step is paired dlss-user-rendering gameplay visual/performance comparison") `
                -Evidence $runtimeStatus.NextRecommendation
        } else {
            Add-Check `
                -Name "runtime status is readable when no visual regression contract is active" `
                -Passed (-not [string]::IsNullOrWhiteSpace([string]$runtimeStatus.NextRecommendation)) `
                -Evidence $runtimeStatus.NextRecommendation
        }
    } catch {
        Add-Check -Name "runtime next recommendation can be read for local contract" -Passed $false -Evidence $_.Exception.Message
    }
}

$failedChecks = @($checks | Where-Object { -not $_.Passed })
$status = if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" }
$runtimeNextRecommendation = if ($runtimeStatus) { [string]$runtimeStatus.NextRecommendation } else { "" }
$visualNextRecommendation = if ($visualStatus) { [string]$visualStatus.NextRecommendation } else { "" }
$allChecksArray = [object[]]@($checks.ToArray())
$failedChecksArray = [object[]]@($failedChecks)
$issuesArray = [string[]]@($issues.ToArray())

$result = [pscustomobject]@{
    Status = $status
    LaunchesGame = $false
    ModifiesGameFiles = $false
    GamePath = $GamePath
    VisualPerformanceRegressionEvidence = [bool]$hasVisualPerformanceRegression
    RuntimeNextRecommendation = $runtimeNextRecommendation
    VisualNextRecommendation = $visualNextRecommendation
    CheckCount = $checks.Count
    FailedChecks = $failedChecksArray
    Checks = $allChecksArray
    Issues = $issuesArray
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}

if ($status -ne "Pass") {
    exit 1
}
