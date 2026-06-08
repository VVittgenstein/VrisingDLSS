param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$stage = "hdrp-dlss-contract-bind-render-scale"
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$artifactRoot = Join-Path $resolvedRoot "artifacts\gameplay-automation"
$docsRoot = Join-Path $resolvedRoot "docs\development"
$analyzerPath = Join-Path $resolvedRoot "scripts\analyze-hdrp-dlss-schedule-audit.ps1"
$checkedArtifacts = 0
$issues = New-Object System.Collections.Generic.List[string]
$result = $null

function Get-BoundedNoWriteRecommendation {
    param([string]$Evidence)

    $prefix = "Contract-bind gameplay proof passed"
    if (-not [string]::IsNullOrWhiteSpace($Evidence)) {
        $prefix = "${prefix}: $Evidence"
    }

    return "Do not rerun the same EASU ctx.cmd dlss-user-rendering candidate unchanged. $prefix. Next work is evidence-lock matrix B/C/D bounded no-write cost proof: B EASU carrier-only cost, C native D3D11 resource-desc validate-only, and D empty existing command-buffer plugin-event callback under the same 1920x1080 Windowed protected 11111 fixture with environment snapshots. Do not rerun hdrp-dlss-contract-bind-render-scale unchanged and do not attempt visible DLSS write-back until B-G pass."
}

function New-ProofResult {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Pass", "Missing", "Blocked")]
        [string]$Status,

        [string]$Evidence = "",
        [string]$Source = "",
        [string]$ArtifactLabel = "",
        [string]$CleanupPath = "",
        [string]$LogPath = "",
        [string]$AnalysisPath = "",
        [string]$DocPath = "",
        [object]$Analysis = $null,
        [string[]]$Issues = @()
    )

    $counts = if ($Analysis -and $Analysis.Counts) { $Analysis.Counts } else { $null }
    $contract = if ($Analysis -and $Analysis.Contract) { $Analysis.Contract } else { $null }

    [pscustomobject]@{
        Status = $Status
        Stage = $stage
        Source = $Source
        ArtifactLabel = $ArtifactLabel
        CleanupPath = $CleanupPath
        LogPath = $LogPath
        AnalysisPath = $AnalysisPath
        DocPath = $DocPath
        AnalysisStatus = $(if ($Analysis) { [string]$Analysis.Status } else { "" })
        ContractStatus = $(if ($contract) { [string]$contract.Status } else { "" })
        EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved = $(if ($contract) { [bool]$contract.EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved } else { $false })
        RenderGraphGetTextureCalls = $(if ($counts) { [int]$counts.RenderGraphGetTextureCalls } else { $null })
        UserRenderingCandidateStarted = $(if ($counts) { [int]$counts.UserRenderingCandidateStarted } else { $null })
        DlssEvaluateSucceeded = $(if ($counts) { [int]$counts.DlssEvaluateSucceeded } else { $null })
        AccessViolationIndicators = $(if ($counts) { [int]$counts.AccessViolationIndicators } else { $null })
        CompleteSuperResolutionChains = $(if ($counts) { [int]$counts.CompleteSuperResolutionChains } else { $null })
        SuperResolutionChainsWithHdrpDepthMotion = $(if ($counts) { [int]$counts.SuperResolutionChainsWithHdrpDepthMotion } else { $null })
        Evidence = $Evidence
        NextRecommendation = $(if ($Status -eq "Pass") { Get-BoundedNoWriteRecommendation -Evidence $Evidence } else { "" })
        CheckedArtifactCount = $checkedArtifacts
        Issues = @($Issues)
        LaunchesGame = $false
        ModifiesGameFiles = $false
    }
}

function Test-RequiredDocMarker {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Marker
    )

    return $Text.IndexOf($Marker, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Test-CleanupPass {
    param([Parameter(Mandatory = $true)][object]$Cleanup)

    $cleanupIssues = New-Object System.Collections.Generic.List[string]
    if ([string]$Cleanup.Stage -ne $stage) { $cleanupIssues.Add("Stage=$($Cleanup.Stage)") }
    if ([string]$Cleanup.Status -ne "Pass") { $cleanupIssues.Add("Cleanup status=$($Cleanup.Status)") }
    if ([bool]$Cleanup.UseSdkWrapperNative) { $cleanupIssues.Add("UseSdkWrapperNative=True") }
    if ([int]$Cleanup.CrashEventCount -ne 0) { $cleanupIssues.Add("CrashEventCount=$($Cleanup.CrashEventCount)") }
    if (-not [bool]$Cleanup.ProtectSave) { $cleanupIssues.Add("ProtectSave=False") }
    if (-not [bool]$Cleanup.SaveRestored) { $cleanupIssues.Add("SaveRestored=False") }
    if ([int]$Cleanup.SaveAfterRestoreChangeCount -ne 0) { $cleanupIssues.Add("SaveAfterRestoreChangeCount=$($Cleanup.SaveAfterRestoreChangeCount)") }
    if ([string]$Cleanup.SaveCompareStatus -ne "Restored") { $cleanupIssues.Add("SaveCompareStatus=$($Cleanup.SaveCompareStatus)") }
    if ([int]$Cleanup.RemainingVRisingProcessCount -ne 0) { $cleanupIssues.Add("RemainingVRisingProcessCount=$($Cleanup.RemainingVRisingProcessCount)") }
    if ([bool]$Cleanup.CleanupRequired) { $cleanupIssues.Add("CleanupRequired=True") }

    return @($cleanupIssues.ToArray())
}

function Test-AnalyzerPass {
    param([Parameter(Mandatory = $true)][object]$Analysis)

    $analysisIssues = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Analysis.Contract -or -not [bool]$Analysis.Contract.EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved) {
        $analysisIssues.Add("EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved=False")
    }
    if ($null -eq $Analysis.Counts -or [int]$Analysis.Counts.SuperResolutionChainsWithHdrpDepthMotion -le 0) {
        $analysisIssues.Add("SuperResolutionChainsWithHdrpDepthMotion=$($Analysis.Counts.SuperResolutionChainsWithHdrpDepthMotion)")
    }
    if ($null -eq $Analysis.Counts -or [int]$Analysis.Counts.RenderGraphGetTextureCalls -ne 0) {
        $analysisIssues.Add("RenderGraphGetTextureCalls=$($Analysis.Counts.RenderGraphGetTextureCalls)")
    }
    if ($null -eq $Analysis.Counts -or [int]$Analysis.Counts.UserRenderingCandidateStarted -ne 0) {
        $analysisIssues.Add("UserRenderingCandidateStarted=$($Analysis.Counts.UserRenderingCandidateStarted)")
    }
    if ($null -eq $Analysis.Counts -or [int]$Analysis.Counts.DlssEvaluateSucceeded -ne 0) {
        $analysisIssues.Add("DlssEvaluateSucceeded=$($Analysis.Counts.DlssEvaluateSucceeded)")
    }
    if ($null -eq $Analysis.Counts -or [int]$Analysis.Counts.AccessViolationIndicators -ne 0) {
        $analysisIssues.Add("AccessViolationIndicators=$($Analysis.Counts.AccessViolationIndicators)")
    }
    if (@($Analysis.Issues).Count -ne 0) {
        $analysisIssues.Add("AnalyzerIssues=$(@($Analysis.Issues) -join ' | ')")
    }

    return @($analysisIssues.ToArray())
}

if ((Test-Path -LiteralPath $artifactRoot -PathType Container) -and (Test-Path -LiteralPath $analyzerPath -PathType Leaf)) {
    $cleanupFiles = @(Get-ChildItem -LiteralPath $artifactRoot -Filter "Cleanup-$stage-*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)

    foreach ($cleanupFile in $cleanupFiles) {
        $checkedArtifacts += 1
        try {
            $cleanup = Get-Content -LiteralPath $cleanupFile.FullName -Raw | ConvertFrom-Json
            $cleanupIssues = @(Test-CleanupPass -Cleanup $cleanup)
            if ($cleanupIssues.Count -gt 0) {
                $issues.Add("$($cleanupFile.Name): $($cleanupIssues -join '; ')")
                continue
            }

            $artifactLabel = [string]$cleanup.ArtifactLabel
            $logPath = [string]$cleanup.BepInExLogArtifact
            if ([string]::IsNullOrWhiteSpace($logPath)) {
                $logPath = Join-Path $artifactRoot "LogOutput-$artifactLabel.log"
            }
            if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
                $issues.Add("$($cleanupFile.Name): missing log $logPath")
                continue
            }

            $analysisJson = & $analyzerPath -LogPath $logPath -Json
            $analysis = $analysisJson | ConvertFrom-Json
            $analysisIssues = @(Test-AnalyzerPass -Analysis $analysis)
            if ($analysisIssues.Count -gt 0) {
                $issues.Add("$($cleanupFile.Name): $($analysisIssues -join '; ')")
                continue
            }

            $evidence = "Artifact=$artifactLabel; Contract=$($analysis.Contract.Status); SuperResolutionChainsWithHdrpDepthMotion=$($analysis.Counts.SuperResolutionChainsWithHdrpDepthMotion); RenderGraphGetTextureCalls=0; UserRenderingCandidateStarted=0; DlssEvaluateSucceeded=0; SaveAfterRestoreChangeCount=0; RemainingVRisingProcessCount=0"
            $result = New-ProofResult `
                -Status "Pass" `
                -Evidence $evidence `
                -Source "ArtifactAnalyzer" `
                -ArtifactLabel $artifactLabel `
                -CleanupPath $cleanupFile.FullName `
                -LogPath $logPath `
                -AnalysisPath ([string]$cleanup.AnalysisArtifact) `
                -Analysis $analysis `
                -Issues @()
            break
        } catch {
            $issues.Add("$($cleanupFile.Name): $($_.Exception.Message)")
        }
    }
}

if ($null -eq $result -and (Test-Path -LiteralPath $docsRoot -PathType Container)) {
    $doc = Get-ChildItem -LiteralPath $docsRoot -Filter "hdrp-dlss-contract-bind-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($doc) {
        $text = Get-Content -LiteralPath $doc.FullName -Raw
        $requiredMarkers = @(
            "Status: Pass",
            "EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved=true",
            "RenderGraphGetTextureCalls=0",
            "UserRenderingCandidateStarted=0",
            "DlssEvaluateSucceeded=0",
            "AccessViolationIndicators=0",
            "SaveAfterRestoreChangeCount=0",
            "RemainingVRisingProcessCount=0",
            "bounded no-write cost proof"
        )

        $missingMarkers = @($requiredMarkers | Where-Object { -not (Test-RequiredDocMarker -Text $text -Marker $_) })
        if ($missingMarkers.Count -eq 0) {
            $evidence = "Doc=$($doc.FullName); Contract-bind proof markers present; RenderGraphGetTextureCalls=0; UserRenderingCandidateStarted=0; DlssEvaluateSucceeded=0; SaveAfterRestoreChangeCount=0; RemainingVRisingProcessCount=0"
            $result = New-ProofResult `
                -Status "Pass" `
                -Evidence $evidence `
                -Source "DurableDoc" `
                -DocPath $doc.FullName `
                -Issues @()
        } else {
            $issues.Add("$($doc.Name): missing markers: $($missingMarkers -join ', ')")
        }
    }
}

if ($null -eq $result -and $issues.Count -gt 0) {
    $result = New-ProofResult `
        -Status "Blocked" `
        -Evidence "Contract-bind proof artifacts or docs were found but did not satisfy the proof contract." `
        -Issues @($issues.ToArray())
} elseif ($null -eq $result) {
    $result = New-ProofResult `
        -Status "Missing" `
        -Evidence "No contract-bind protected gameplay proof artifact or durable result doc was found."
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}
