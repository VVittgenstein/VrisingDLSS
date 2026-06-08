param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]

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

function Get-PropertyValue {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) {
        return $null
    }

    return $Object.PSObject.Properties[$Name].Value
}

$factsPath = Get-RepoPath -RelativePath "docs\development\experiment-facts.json"
$synthesisPath = Get-RepoPath -RelativePath "docs\research\user-provided-easu-dlss-plan-synthesis-2026-06-08.md"

foreach ($path in @($factsPath, $synthesisPath)) {
    Add-Check `
        -Name "FileExists:$([System.IO.Path]::GetFileName($path))" `
        -Passed (Test-Path -LiteralPath $path -PathType Leaf) `
        -Evidence $path `
        -Failure "missing $path"
}

$facts = $null
if (Test-Path -LiteralPath $factsPath -PathType Leaf) {
    try {
        $facts = Get-Content -LiteralPath $factsPath -Raw | ConvertFrom-Json
    } catch {
        Add-Check `
            -Name "ExperimentFactsJsonParse" `
            -Passed $false `
            -Evidence $_.Exception.Message `
            -Failure $_.Exception.Message
    }
}

if ($facts) {
    Add-Check `
        -Name "ExperimentFactsIsNoRuntimeNoModify" `
        -Passed (($facts.schemaVersion -eq 1) -and (-not [bool]$facts.launchesGame) -and (-not [bool]$facts.modifiesGameFiles)) `
        -Evidence "schemaVersion=$($facts.schemaVersion); launchesGame=$($facts.launchesGame); modifiesGameFiles=$($facts.modifiesGameFiles)" `
        -Failure "experiment facts must be a no-runtime/no-game-file contract"

    $locks = @($facts.evidenceLocks)
    $locksById = @{}
    foreach ($lock in $locks) {
        $locksById[[string]$lock.id] = $lock
    }

    $requiredLocks = @(
        "steady-state-broad-rendergraph-gettexture-discovery",
        "cached-tuple-dynamicresolutionhandler-evaluate",
        "force-or-patch-inert-dlsspass-render",
        "new-mod-owned-rendergraph-pass-production",
        "unchanged-dlss-user-rendering-rerun",
        "visible-evaluate-without-scratch-or-no-write-layers"
    )

    $missingLocks = @($requiredLocks | Where-Object { -not $locksById.ContainsKey($_) })
    Add-Check `
        -Name "RequiredEvidenceLocksPresent" `
        -Passed ($missingLocks.Count -eq 0) `
        -Evidence "Required=$($requiredLocks.Count); Present=$($locksById.Count)" `
        -Failure "missing locks: $($missingLocks -join ', ')"

    foreach ($lockId in $requiredLocks | Where-Object { $locksById.ContainsKey($_) }) {
        $lock = $locksById[$lockId]
        $status = [string]$lock.status
        $allowed = [string]$lock.allowedChallenge
        $evidenceCount = @($lock.evidence).Count
        Add-Check `
            -Name "EvidenceLockHasEnforcement:$lockId" `
            -Passed ((@("rejected", "unsafe_crash", "known_regressed", "blocked_until_matrix_passes") -contains $status) -and $evidenceCount -gt 0 -and -not [string]::IsNullOrWhiteSpace($allowed)) `
            -Evidence "status=$status; enforcement=$($lock.enforcement); evidenceCount=$evidenceCount" `
            -Failure "lock must have a final status, evidence, and allowedChallenge"
    }

    $matrix = @($facts.boundaryCostMatrix)
    $matrixLayers = @($matrix | ForEach-Object { [string]$_.layer })
    $expectedLayers = @("A", "B", "C", "D", "E", "F", "G", "H", "I")
    Add-Check `
        -Name "BoundaryCostMatrixOrderIsAThroughI" `
        -Passed (($matrixLayers -join ",") -eq ($expectedLayers -join ",")) `
        -Evidence "Layers=$($matrixLayers -join ',')" `
        -Failure "matrix must keep the staged A-I order from baseline through 4K value proof"

    $matrixByLayer = @{}
    foreach ($entry in $matrix) {
        $matrixByLayer[[string]$entry.layer] = $entry
    }

    foreach ($layer in @("B", "C", "D")) {
        $criteria = Get-PropertyValue -Object $matrixByLayer[$layer] -Name "passCriteria"
        Add-Check `
            -Name "NoWriteLayerHasNearBaselineCostGate:$layer" `
            -Passed (($null -ne $criteria) `
                -and [double]$criteria.averageFpsRatioMin -ge 0.98 `
                -and [double]$criteria.p95FrameMsDeltaMax -le 0.5 `
                -and [double]$criteria.p99FrameMsDeltaMax -le 1.0 `
                -and [bool]$criteria.forbidGpuUtilPowerCollapse) `
            -Evidence "Layer=$layer; averageFpsRatioMin=$($criteria.averageFpsRatioMin); p95Max=$($criteria.p95FrameMsDeltaMax); p99Max=$($criteria.p99FrameMsDeltaMax)" `
            -Failure "B/C/D must remain cheap no-write gates before NGX evaluate"
    }

    $visibleRequires = @($matrixByLayer["H"].requiresPriorLayers)
    $visibleRequired = @("B", "C", "D", "E", "F", "G")
    $missingVisibleRequires = @($visibleRequired | Where-Object { $visibleRequires -notcontains $_ })
    Add-Check `
        -Name "VisibleWriteRequiresPriorCostLayers" `
        -Passed ($missingVisibleRequires.Count -eq 0) `
        -Evidence "Requires=$($visibleRequires -join ',')" `
        -Failure "visible write missing prerequisites: $($missingVisibleRequires -join ',')"

    $valueRequires = @($matrixByLayer["I"].requiresPriorLayers)
    Add-Check `
        -Name "ValueProofRequiresVisibleWriteAndGpuBound4K" `
        -Passed (($valueRequires -contains "H") -and ([string]$matrixByLayer["I"].resolution -eq "4K GPU-bound")) `
        -Evidence "Requires=$($valueRequires -join ','); Resolution=$($matrixByLayer["I"].resolution)" `
        -Failure "4K product-value proof must require surviving visible write evidence"
}

if (Test-Path -LiteralPath $synthesisPath -PathType Leaf) {
    $synthesisText = Get-Content -LiteralPath $synthesisPath -Raw
    Add-Check `
        -Name "SynthesisMatchesEvidenceLockRoute" `
        -Passed (($synthesisText -match "hdrp-dlss-contract-bind-render-scale") `
            -and ($synthesisText -match "B-H cost matrix") `
            -and ($synthesisText -match "Visible write requires prior B-G cost layers")) `
        -Evidence $synthesisPath `
        -Failure "user-provided synthesis must keep contract-bind first and staged B-H matrix next"
}

$failedChecks = @($checks.ToArray() | Where-Object { $_.Status -ne "Pass" })
$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    EvidenceLockCount = if ($facts) { @($facts.evidenceLocks).Count } else { 0 }
    MatrixLayerCount = if ($facts) { @($facts.boundaryCostMatrix).Count } else { 0 }
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
