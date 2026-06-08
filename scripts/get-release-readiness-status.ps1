param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$PackagePath,
    [string]$GamePath,
    [string]$LogPath,
    [switch]$RequireMvpReady,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function New-ReadinessItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Area,

        [Parameter(Mandatory = $true)]
        [string]$Requirement,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Pass", "Fail", "Blocked", "Missing", "NotApplicable")]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Evidence
    )

    [pscustomobject]@{
        Area = $Area
        Requirement = $Requirement
        Status = $Status
        Evidence = $Evidence
    }
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    $output = New-Object System.Collections.Generic.List[string]
    try {
        & $Command *>&1 | ForEach-Object {
            $output.Add($_.ToString())
        }

        return [pscustomobject]@{
            Succeeded = $true
            Output = ($output -join [Environment]::NewLine)
        }
    } catch {
        if ($_.Exception.Message) {
            $output.Add($_.Exception.Message)
        }

        return [pscustomobject]@{
            Succeeded = $false
            Output = ($output -join [Environment]::NewLine)
        }
    }
}

function Get-FirstStageStatus {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$StageResults,

        [Parameter(Mandatory = $true)]
        [string]$StagePrefix
    )

    $match = $StageResults | Where-Object { $_.Stage -like "$StagePrefix*" } | Select-Object -First 1
    if ($match) {
        return $match.Status
    }

    return "Missing"
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$items = New-Object System.Collections.Generic.List[object]
$runtimeNextRecommendation = $null
$visualNextRecommendation = $null
$nextRuntimeProofPlan = $null

$manifestPath = Join-Path $resolvedRoot "package\thunderstore\manifest.json"
$packageReadmePath = Join-Path $resolvedRoot "package\thunderstore\README.md"
$thirdPartyNoticesPath = Join-Path $resolvedRoot "package\thunderstore\ThirdPartyNotices.md"
$installDocPath = Join-Path $resolvedRoot "docs\install.md"
$troubleshootingDocPath = Join-Path $resolvedRoot "docs\troubleshooting.md"
$mvpDocPath = Join-Path $resolvedRoot "docs\mvp.md"
$measurementPlanPath = Join-Path $resolvedRoot "docs\development\measurement-plan.md"
$runtimeDistributionGatePath = Join-Path $resolvedRoot "docs\development\dlss-runtime-distribution-gate-2026-06-08.md"
$runtimeDistributionApprovalPath = Join-Path $resolvedRoot "docs\release\dlss-runtime-distribution-approval.md"
$workflowPath = Join-Path $resolvedRoot ".github\workflows\build-package.yml"
$configTemplatePath = Join-Path $resolvedRoot "package\thunderstore\VrisingDLSS.cfg"
$hdrpAssetRequirement = "Local HDRP asset unpack identifies the active render pipeline asset and DLSS/upscaler gates without launching or modifying the game."
$contractBindStageRequirement = "Contract-bind render-scale stage dry-run remains no-native/no-evaluate and launch-safe before gameplay automation."
$localSaveFixtureRequirement = "Local V Rising save fixture resolver finds exactly one usable Continue target named 11111 without launching or modifying the game."
$renderGraphBoundaryRouteRequirement = "RenderGraph boundary route guard keeps mod-owned RenderGraph pass injection rejected as the normal route without launching or modifying the game."
$runtimeDistributionRequirement = "Normal-user DLSS runtime distribution path is approved and does not require ad hoc manual DLL downloads."

if ([string]::IsNullOrWhiteSpace($PackagePath) -and (Test-Path -LiteralPath $manifestPath)) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $PackagePath = Join-Path $resolvedRoot "dist\VrisingDLSS-$($manifest.version_number)-thunderstore.zip"
}

if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $expectedDependency = "BepInEx-BepInExPack_V_Rising-1.733.2"
    $manifestOk = $manifest.name -eq "VrisingDLSS" `
        -and $manifest.version_number -match "^\d+\.\d+\.\d+$" `
        -and @($manifest.dependencies) -contains $expectedDependency `
        -and $manifest.website_url -match "github\.com/VVittgenstein/VrisingDLSS"
    $items.Add((New-ReadinessItem `
        -Area "Package" `
        -Requirement "Thunderstore manifest is present and points at the expected package identity/dependency." `
        -Status $(if ($manifestOk) { "Pass" } else { "Fail" }) `
        -Evidence "manifest.json name=$($manifest.name); version=$($manifest.version_number); dependencies=$(@($manifest.dependencies) -join ', '); website_url=$($manifest.website_url)"))
} else {
    $items.Add((New-ReadinessItem `
        -Area "Package" `
        -Requirement "Thunderstore manifest is present." `
        -Status "Missing" `
        -Evidence "Missing $manifestPath"))
}

foreach ($doc in @(
        [pscustomobject]@{ Area = "Docs"; Requirement = "Install guide exists."; Path = $installDocPath },
        [pscustomobject]@{ Area = "Docs"; Requirement = "Troubleshooting guide exists."; Path = $troubleshootingDocPath },
        [pscustomobject]@{ Area = "Docs"; Requirement = "Third-party notices exist."; Path = $thirdPartyNoticesPath },
        [pscustomobject]@{ Area = "Docs"; Requirement = "MVP definition exists."; Path = $mvpDocPath },
        [pscustomobject]@{ Area = "Docs"; Requirement = "DLSS visual/performance measurement plan exists."; Path = $measurementPlanPath },
        [pscustomobject]@{ Area = "Docs"; Requirement = "Package README exists."; Path = $packageReadmePath }
    )) {
    $exists = Test-Path -LiteralPath $doc.Path
    $items.Add((New-ReadinessItem `
        -Area $doc.Area `
        -Requirement $doc.Requirement `
        -Status $(if ($exists) { "Pass" } else { "Missing" }) `
        -Evidence $(if ($exists) { $doc.Path } else { "Missing $($doc.Path)" })))
}

if (Test-Path -LiteralPath $configTemplatePath) {
    $configText = Get-Content -LiteralPath $configTemplatePath -Raw
    $hasModFolderConfig = $configText -match "\[General\]" -and $configText -match "\[Diagnostics\]" -and $configText -match "\[DLSS\]"
    $items.Add((New-ReadinessItem `
        -Area "Package" `
        -Requirement "Mod-folder config template exists with General/Diagnostics/DLSS sections." `
        -Status $(if ($hasModFolderConfig) { "Pass" } else { "Fail" }) `
        -Evidence $configTemplatePath))
} else {
    $items.Add((New-ReadinessItem `
        -Area "Package" `
        -Requirement "Mod-folder config template exists." `
        -Status "Missing" `
        -Evidence "Missing $configTemplatePath"))
}

$boundaryCheck = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\check-release-boundary.ps1") -Root $resolvedRoot
}
$items.Add((New-ReadinessItem `
    -Area "Compliance" `
    -Requirement "Release boundary check passes with no forbidden PureDark/NVIDIA/runtime binaries." `
    -Status $(if ($boundaryCheck.Succeeded) { "Pass" } else { "Fail" }) `
    -Evidence $(if ([string]::IsNullOrWhiteSpace($boundaryCheck.Output)) { "No output." } else { $boundaryCheck.Output })))

if (Test-Path -LiteralPath $PackagePath) {
    $packageCheck = Invoke-CapturedCommand -Command {
        & (Join-Path $resolvedRoot "scripts\validate-thunderstore-package.ps1") -Root $resolvedRoot -PackagePath $PackagePath
    }
    $items.Add((New-ReadinessItem `
        -Area "Package" `
        -Requirement "Thunderstore zip has upload-shaped metadata, BepInEx plugin route, and release-safe contents." `
        -Status $(if ($packageCheck.Succeeded) { "Pass" } else { "Fail" }) `
        -Evidence $(if ([string]::IsNullOrWhiteSpace($packageCheck.Output)) { $PackagePath } else { $packageCheck.Output })))
} else {
    $items.Add((New-ReadinessItem `
        -Area "Package" `
        -Requirement "Thunderstore zip exists." `
        -Status "Missing" `
        -Evidence "Missing $PackagePath"))
}

if (Test-Path -LiteralPath $workflowPath) {
    $workflowText = Get-Content -LiteralPath $workflowPath -Raw
    $workflowOk = $workflowText -match "windows-2022" `
        -and $workflowText -match "validate-thunderstore-package\.ps1" `
        -and $workflowText -match "package-thunderstore\.ps1" `
        -and $workflowText -match "test-hdrp-dlss-contract-bind-stage\.ps1\s+-RequirePass" `
        -and $workflowText -match "test-rendergraph-boundary-route-status\.ps1\s+-RequirePass" `
        -and $workflowText -match "actions/upload-artifact@v4"
    $items.Add((New-ReadinessItem `
        -Area "Automation" `
        -Requirement "GitHub Actions builds, guards, and validates the package artifact on a pinned Windows runner." `
        -Status $(if ($workflowOk) { "Pass" } else { "Fail" }) `
        -Evidence $workflowPath))
} else {
    $items.Add((New-ReadinessItem `
        -Area "Automation" `
        -Requirement "GitHub Actions package workflow exists." `
        -Status "Missing" `
        -Evidence "Missing $workflowPath"))
}

$contractBindSaveDir = ""
$contractBindSaveName = ""
if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $saveFixtureProbe = Invoke-CapturedCommand -Command {
        & (Join-Path $resolvedRoot "scripts\find-vrising-save-fixture.ps1") -SaveName "11111" -Json
    }
    $saveFixtureStatus = "Blocked"
    $saveFixtureEvidence = "Save fixture resolver did not produce evidence."
    if ($saveFixtureProbe.Succeeded) {
        try {
            $saveFixture = $saveFixtureProbe.Output | ConvertFrom-Json
            $saveFixtureStatus = if ($saveFixture.Status -eq "Pass") { "Pass" } else { "Blocked" }
            $selectedMatch = @($saveFixture.Matches | Where-Object { $_.SaveDir -eq $saveFixture.SelectedSaveDir } | Select-Object -First 1)
            $saveFixtureEvidence = "Status=$($saveFixture.Status); SaveName=$($saveFixture.SaveName); MatchCount=$($saveFixture.MatchCount); LaunchesGame=$($saveFixture.LaunchesGame); ModifiesGameFiles=$($saveFixture.ModifiesGameFiles)"
            if ($selectedMatch.Count -gt 0) {
                $saveFixtureEvidence = "$saveFixtureEvidence; SelectedSaveId=$($selectedMatch[0].SaveId); AutoSaveCount=$($selectedMatch[0].AutoSaveCount); HasServerGameSettings=$($selectedMatch[0].HasServerGameSettings); Usable=$($selectedMatch[0].Usable)"
            }
            if ($saveFixture.Status -eq "Pass" -and -not [string]::IsNullOrWhiteSpace([string]$saveFixture.SelectedSaveDir)) {
                $contractBindSaveDir = [string]$saveFixture.SelectedSaveDir
                $contractBindSaveName = [string]$saveFixture.SaveName
            }
            if (@($saveFixture.Issues).Count -gt 0) {
                $saveFixtureEvidence = "$saveFixtureEvidence; Issues=$(@($saveFixture.Issues) -join ' | ')"
            }
        } catch {
            $saveFixtureStatus = "Blocked"
            $saveFixtureEvidence = "Failed to parse save fixture resolver JSON: $($_.Exception.Message); Output=$($saveFixtureProbe.Output)"
        }
    } else {
        $saveFixtureEvidence = "Save fixture resolver failed: $($saveFixtureProbe.Output)"
    }

    $items.Add((New-ReadinessItem `
        -Area "Evidence" `
        -Requirement $localSaveFixtureRequirement `
        -Status $saveFixtureStatus `
        -Evidence $saveFixtureEvidence))
} else {
    $items.Add((New-ReadinessItem `
        -Area "Evidence" `
        -Requirement $localSaveFixtureRequirement `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include local save fixture resolver evidence."))
}

$contractBindArgs = @{
    Root = $resolvedRoot
    Json = $true
}
if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $contractBindArgs["GamePath"] = $GamePath
}
if (-not [string]::IsNullOrWhiteSpace($contractBindSaveName)) {
    $contractBindArgs["SaveName"] = $contractBindSaveName
} elseif (-not [string]::IsNullOrWhiteSpace($contractBindSaveDir)) {
    $contractBindArgs["SaveDir"] = $contractBindSaveDir
}
$contractBindGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-hdrp-dlss-contract-bind-stage.ps1") @contractBindArgs
}
$contractBindGuardStatus = "Blocked"
$contractBindGuardEvidence = "Contract-bind stage guard did not produce evidence."
if ($contractBindGuard.Succeeded) {
    try {
        $contractBindReport = $contractBindGuard.Output | ConvertFrom-Json
        $contractBindGuardStatus = if ($contractBindReport.Status -eq "Pass") {
            "Pass"
        } elseif ($contractBindReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $diagnosticDryRun = $contractBindReport.DiagnosticDryRun
        $sessionDryRun = $contractBindReport.SessionDryRun
        $contractBindGuardEvidence = "Status=$($contractBindReport.Status); Stage=$($contractBindReport.Stage); RequiredTrue=$($contractBindReport.RequiredTrueCount); RequiredFalse=$($contractBindReport.RequiredFalseCount); Checks=$($contractBindReport.CheckCount); FailedChecks=$(@($contractBindReport.FailedChecks).Count); LaunchesGame=$($contractBindReport.LaunchesGame); ModifiesGameFiles=$($contractBindReport.ModifiesGameFiles)"
        if ($diagnosticDryRun) {
            $contractBindGuardEvidence = "$contractBindGuardEvidence; DiagnosticDryRunLaunchesGame=$($diagnosticDryRun.LaunchesGame); UseSdkWrapperNative=$($diagnosticDryRun.UseSdkWrapperNative); RestoresReleaseSafeNative=$($diagnosticDryRun.RestoresReleaseSafeNative); SetClientResolution=$($diagnosticDryRun.SetClientResolution); ClientWindowMode=$($diagnosticDryRun.ClientWindowMode)"
        } else {
            $contractBindGuardEvidence = "$contractBindGuardEvidence; DiagnosticDryRun=not requested"
        }
        if ($sessionDryRun) {
            $contractBindGuardEvidence = "$contractBindGuardEvidence; SessionDryRunLaunchesGame=$($sessionDryRun.LaunchesGame); LeavesGameRunning=$($sessionDryRun.LeavesGameRunning); ProtectSave=$($sessionDryRun.ProtectSave); RestoresProtectedSave=$($sessionDryRun.RestoresProtectedSave); SessionUseSdkWrapperNative=$($sessionDryRun.UseSdkWrapperNative); SessionSaveName=$($sessionDryRun.SaveName); SessionSaveFixtureResolved=$($sessionDryRun.SaveFixtureResolved); SessionSaveFixtureStatus=$($sessionDryRun.SaveFixtureStatus); SessionSaveFixtureMatchCount=$($sessionDryRun.SaveFixtureMatchCount); SessionSaveFixtureSaveId=$($sessionDryRun.SaveFixtureSaveId)"
        } else {
            $contractBindGuardEvidence = "$contractBindGuardEvidence; SessionDryRun=not requested"
        }
        if (@($contractBindReport.Issues).Count -gt 0) {
            $contractBindGuardEvidence = "$contractBindGuardEvidence; Issues=$(@($contractBindReport.Issues) -join ' | ')"
        }
        if ($contractBindReport.RuntimeProofPlan) {
            $nextRuntimeProofPlan = $contractBindReport.RuntimeProofPlan
        }
    } catch {
        $contractBindGuardStatus = "Blocked"
        $contractBindGuardEvidence = "Failed to parse contract-bind stage guard JSON: $($_.Exception.Message); Output=$($contractBindGuard.Output)"
    }
} else {
    $contractBindGuardEvidence = "Contract-bind stage guard failed: $($contractBindGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $contractBindStageRequirement `
    -Status $contractBindGuardStatus `
    -Evidence $contractBindGuardEvidence))

$renderGraphBoundaryRouteGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-rendergraph-boundary-route-status.ps1") -Root $resolvedRoot -RequirePass -Json
}
$renderGraphBoundaryRouteStatus = "Blocked"
$renderGraphBoundaryRouteEvidence = "RenderGraph boundary route guard did not produce evidence."
if ($renderGraphBoundaryRouteGuard.Succeeded) {
    try {
        $renderGraphBoundaryRouteReport = $renderGraphBoundaryRouteGuard.Output | ConvertFrom-Json
        $renderGraphBoundaryRouteLaunchesGame = [bool]$renderGraphBoundaryRouteReport.LaunchesGame
        $renderGraphBoundaryRouteModifiesGameFiles = [bool]$renderGraphBoundaryRouteReport.ModifiesGameFiles
        $renderGraphBoundaryRouteEvidenceDetails = $renderGraphBoundaryRouteReport.Evidence
        $renderGraphBoundaryRouteStatus = if ($renderGraphBoundaryRouteReport.Status -eq "Pass" `
                -and $renderGraphBoundaryRouteReport.RouteDecision -eq "RejectedAsNormalRoute" `
                -and -not $renderGraphBoundaryRouteLaunchesGame `
                -and -not $renderGraphBoundaryRouteModifiesGameFiles) {
            "Pass"
        } elseif ($renderGraphBoundaryRouteReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $renderGraphBoundaryRouteEvidence = "Status=$($renderGraphBoundaryRouteReport.Status); RouteDecision=$($renderGraphBoundaryRouteReport.RouteDecision); Checks=$($renderGraphBoundaryRouteReport.CheckCount); FailedChecks=$(@($renderGraphBoundaryRouteReport.FailedChecks).Count); LaunchesGame=$($renderGraphBoundaryRouteReport.LaunchesGame); ModifiesGameFiles=$($renderGraphBoundaryRouteReport.ModifiesGameFiles); AnalyzerStatus=$($renderGraphBoundaryRouteEvidenceDetails.AnalyzerStatus); AnalyzerContractStatus=$($renderGraphBoundaryRouteEvidenceDetails.AnalyzerContractStatus); CompleteUberEasuFinalChains=$($renderGraphBoundaryRouteEvidenceDetails.CompleteUberEasuFinalChains)"
        if (@($renderGraphBoundaryRouteReport.Issues).Count -gt 0) {
            $renderGraphBoundaryRouteEvidence = "$renderGraphBoundaryRouteEvidence; Issues=$(@($renderGraphBoundaryRouteReport.Issues) -join ' | ')"
        }
    } catch {
        $renderGraphBoundaryRouteStatus = "Blocked"
        $renderGraphBoundaryRouteEvidence = "Failed to parse RenderGraph boundary route guard JSON: $($_.Exception.Message); Output=$($renderGraphBoundaryRouteGuard.Output)"
    }
} else {
    $renderGraphBoundaryRouteEvidence = "RenderGraph boundary route guard failed: $($renderGraphBoundaryRouteGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $renderGraphBoundaryRouteRequirement `
    -Status $renderGraphBoundaryRouteStatus `
    -Evidence $renderGraphBoundaryRouteEvidence))

if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $runtimeArgs = @{
        Root = $resolvedRoot
        GamePath = $GamePath
        IncludeArchivedLogs = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $runtimeArgs["LogPath"] = $LogPath
    }

    $runtimeStatus = & (Join-Path $resolvedRoot "scripts\get-runtime-validation-status.ps1") @runtimeArgs
    $runtimeNextRecommendation = $runtimeStatus.NextRecommendation
    $runtimeEvidenceSource = if ($runtimeStatus.IncludeArchivedLogs) {
        "Log=$($runtimeStatus.LogPath); ArchivedAnalysisCount=$($runtimeStatus.ArchivedAnalysisCount)"
    } else {
        "Log=$($runtimeStatus.LogPath)"
    }
    $stageResults = @($runtimeStatus.StageResults)
    $stage8A = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 8A"
    $stage8B = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 8B"
    $stage8C = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 8C"
    $stage8D = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 8D"
    $stage8E = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 8E"
    $stage8F = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 8F"
    $stage8G = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 8G"
    $stage9A = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 9A"
    $stage10A = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 10A"
    $userRendering = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "DLSS User Rendering Candidate"
    $stage7 = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 7"
    $stage6 = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 6"
    $loader = Get-FirstStageStatus -StageResults $stageResults -StagePrefix "Stage 1"
    $sdkWrapperProofStatus = if (($stage6 -eq "Pass" -and $stage7 -eq "Pass") -or $stage8B -eq "Pass") { "Pass" } else { "Blocked" }

    $assetInspector = Invoke-CapturedCommand -Command {
        & (Join-Path $resolvedRoot "scripts\inspect-vrising-hdrp-assets.ps1") -Root $resolvedRoot -GamePath $GamePath -Json
    }
    $assetInspectorStatus = "Blocked"
    $assetInspectorEvidence = "Inspector command did not produce evidence."
    if ($assetInspector.Succeeded) {
        try {
            $assetReport = $assetInspector.Output | ConvertFrom-Json
            $assetSummary = $assetReport.Summary
            $assetLaunchesGame = [bool]$assetReport.LaunchesGame
            $assetModifiesGameFiles = [bool]$assetReport.ModifiesGameFiles
            $assetActiveName = [string]$assetSummary.ActiveAssetName
            $assetInspectorEvidence = "Status=$($assetReport.Status); Unity=$($assetReport.UnityVersion); Active=$assetActiveName; UseRenderGraph=$($assetSummary.UseRenderGraph); DRS=$($assetSummary.DynamicResolutionEnabled); EnableDLSS=$($assetSummary.EnableDLSS); DLSSInjectionPoint=$($assetSummary.DLSSInjectionPointName); DynResType=$($assetSummary.DynamicResolutionTypeName); UpsampleFilter=$($assetSummary.UpsampleFilterName); LaunchesGame=$($assetReport.LaunchesGame); ModifiesGameFiles=$($assetReport.ModifiesGameFiles)"
            if ($assetLaunchesGame -or $assetModifiesGameFiles) {
                $assetInspectorStatus = "Fail"
            } elseif ($assetReport.Status -eq "Pass" -and -not [string]::IsNullOrWhiteSpace($assetActiveName)) {
                $assetInspectorStatus = "Pass"
            } elseif ($assetReport.Status -eq "Pass") {
                $assetInspectorStatus = "Fail"
            } else {
                $assetInspectorStatus = "Blocked"
                if ($assetReport.Error) {
                    $assetInspectorEvidence = "$assetInspectorEvidence; Error=$($assetReport.Error)"
                }
            }
        } catch {
            $assetInspectorStatus = "Blocked"
            $assetInspectorEvidence = "Failed to parse inspector JSON: $($_.Exception.Message); Output=$($assetInspector.Output)"
        }
    } else {
        $assetInspectorEvidence = "Inspector command failed or dependencies are missing: $($assetInspector.Output)"
    }

    $items.Add((New-ReadinessItem `
        -Area "Evidence" `
        -Requirement $hdrpAssetRequirement `
        -Status $assetInspectorStatus `
        -Evidence $assetInspectorEvidence))

    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Local staged install has loaded the plugin at least once." `
        -Status $(if ($loader -eq "Pass") { "Pass" } elseif ($loader -eq "Missing") { "Missing" } else { "Fail" }) `
        -Evidence "Stage 1 Loader=$loader; $runtimeEvidenceSource"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "SDK-wrapper DLSS path has local proof through init/query, feature-create, or guarded evaluate evidence." `
        -Status $sdkWrapperProofStatus `
        -Evidence "Stage 6=$stage6; Stage 7=$stage7; Stage 8B=$stage8B"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8A proves same-frame color/output/depth/motion D3D11 inputs for DLSS evaluate." `
        -Status $(if ($stage8A -eq "Pass") { "Pass" } elseif ($stage8A -eq "Fail") { "Fail" } elseif ($stage8A -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 8A=$stage8A; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8B proves a guarded SDK-wrapper DLSS evaluate call can run against the accepted frame resources." `
        -Status $(if ($stage8B -eq "Pass") { "Pass" } elseif ($stage8B -eq "Fail") { "Fail" } elseif ($stage8B -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 8B=$stage8B; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8C proves the selected DLSS output resource remains D3D11-accessible after the evaluate callback." `
        -Status $(if ($stage8C -eq "Pass") { "Pass" } elseif ($stage8C -eq "Fail") { "Fail" } elseif ($stage8C -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 8C=$stage8C; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8D proves one DLSS feature can persist across multiple evaluate calls before release/shutdown." `
        -Status $(if ($stage8D -eq "Pass") { "Pass" } elseif ($stage8D -eq "Fail") { "Fail" } elseif ($stage8D -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 8D=$stage8D; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8E proves a real-frame DLSS Super Resolution tuple with render inputs smaller than the output target." `
        -Status $(if ($stage8E -eq "Pass") { "Pass" } elseif ($stage8E -eq "Fail") { "Fail" } elseif ($stage8E -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 8E=$stage8E; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8F proves a guarded SDK-wrapper DLSS evaluate call can run against a Super Resolution-sized tuple." `
        -Status $(if ($stage8F -eq "Pass") { "Pass" } elseif ($stage8F -eq "Fail") { "Fail" } elseif ($stage8F -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 8F=$stage8F; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8G proves one DLSS feature can persist across multiple evaluate calls against a Super Resolution-sized tuple." `
        -Status $(if ($stage8G -eq "Pass") { "Pass" } elseif ($stage8G -eq "Fail") { "Fail" } elseif ($stage8G -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 8G=$stage8G; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 9A proves one DLSS feature can persist across multiple RenderGraph callbacks against a Super Resolution-sized tuple." `
        -Status $(if ($stage9A -eq "Pass") { "Pass" } elseif ($stage9A -eq "Fail") { "Fail" } elseif ($stage9A -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 9A=$stage9A; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 10A proves a guarded visible-path candidate can repeatedly evaluate DLSS into the selected Super Resolution output target." `
        -Status $(if ($stage10A -eq "Pass") { "Pass" } elseif ($stage10A -eq "Fail") { "Fail" } elseif ($stage10A -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "Stage 10A=$stage10A; Next=$($runtimeStatus.NextRecommendation)"))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Experimental EnableDLSS user-rendering candidate can evaluate through the SDK-wrapper frame-sequence path." `
        -Status $(if ($userRendering -eq "Pass") { "Pass" } elseif ($userRendering -eq "Fail") { "Fail" } elseif ($userRendering -eq "Missing") { "Missing" } else { "Blocked" }) `
        -Evidence "DLSS User Rendering Candidate=$userRendering; Next=$($runtimeStatus.NextRecommendation)"))
} else {
    $items.Add((New-ReadinessItem `
        -Area "Evidence" `
        -Requirement $hdrpAssetRequirement `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include local HDRP asset unpack evidence."))

    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8A proves same-frame color/output/depth/motion D3D11 inputs for DLSS evaluate." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8B proves a guarded SDK-wrapper DLSS evaluate call can run against the accepted frame resources." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8C proves the selected DLSS output resource remains D3D11-accessible after the evaluate callback." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8D proves one DLSS feature can persist across multiple evaluate calls before release/shutdown." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8E proves a real-frame DLSS Super Resolution tuple with render inputs smaller than the output target." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8F proves a guarded SDK-wrapper DLSS evaluate call can run against a Super Resolution-sized tuple." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 8G proves one DLSS feature can persist across multiple evaluate calls against a Super Resolution-sized tuple." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 9A proves one DLSS feature can persist across multiple RenderGraph callbacks against a Super Resolution-sized tuple." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Stage 10A proves a guarded visible-path candidate can repeatedly evaluate DLSS into the selected Super Resolution output target." `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include runtime validation evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Runtime" `
        -Requirement "Experimental EnableDLSS user-rendering candidate can evaluate through the SDK-wrapper frame-sequence path." `
        -Status "Missing" `
        -Evidence "Pass -GamePath or -LogPath to include runtime validation evidence."))
}

$configTemplateText = if (Test-Path -LiteralPath $configTemplatePath) {
    Get-Content -LiteralPath $configTemplatePath -Raw
} else {
    ""
}
$releaseConfigSurfaceReady = $configTemplateText -match "EnableDLSS" `
    -and $configTemplateText -match "QualityMode" `
    -and $configTemplateText -match "PresetMode" `
    -and $configTemplateText -match "UseOfficialHdrpFeatureFlags" `
    -and $configTemplateText -match "AutoExposure" `
    -and $configTemplateText -match "RenderScaleOverride" `
    -and $configTemplateText -match "MipBiasOverride" `
    -and $configTemplateText -match "ResetOnCameraCut" `
    -and $configTemplateText -match "LogLevel" `
    -and $configTemplateText -match "ShowOverlay"
$items.Add((New-ReadinessItem `
    -Area "MVP" `
    -Requirement "Normal-user DLSS/Advanced configuration surface is present in the mod-folder config." `
    -Status $(if ($releaseConfigSurfaceReady) { "Pass" } else { "Blocked" }) `
    -Evidence $(if ($releaseConfigSurfaceReady) { $configTemplatePath } else { "Release DLSS defaults are documented in docs/mvp.md but the package config does not expose every key yet." })))

$runtimeDistributionGateExists = Test-Path -LiteralPath $runtimeDistributionGatePath
$runtimeDistributionApprovalExists = Test-Path -LiteralPath $runtimeDistributionApprovalPath
$runtimeDistributionStatus = if ($runtimeDistributionApprovalExists) { "Pass" } else { "Blocked" }
$runtimeDistributionEvidence = if ($runtimeDistributionApprovalExists) {
    "Approved runtime distribution record exists: $runtimeDistributionApprovalPath"
} elseif ($runtimeDistributionGateExists) {
    "No approved runtime distribution record exists. Current gate: $runtimeDistributionGatePath"
} else {
    "Missing runtime distribution gate document: $runtimeDistributionGatePath"
}
$items.Add((New-ReadinessItem `
    -Area "MVP" `
    -Requirement $runtimeDistributionRequirement `
    -Status $runtimeDistributionStatus `
    -Evidence $runtimeDistributionEvidence))

$visualStatus = & (Join-Path $resolvedRoot "scripts\get-visual-validation-status.ps1") -Root $resolvedRoot -RequiredCandidateStage dlss-user-rendering
$visualNextRecommendation = $visualStatus.NextRecommendation
$visualEvidence = "$($visualStatus.Evidence)"
if (@($visualStatus.Issues).Count -gt 0) {
    $visualEvidence = "$visualEvidence; Issues=$(@($visualStatus.Issues) -join ' | ')"
}
$items.Add((New-ReadinessItem `
    -Area "MVP" `
    -Requirement "Normal-user dlss-user-rendering gameplay visual/performance comparison proves the DLSS candidate is image-correct enough for MVP integration." `
    -Status $visualStatus.Status `
    -Evidence $visualEvidence))

$items.Add((New-ReadinessItem `
    -Area "MVP" `
    -Requirement "Normal-user DLSS enable/disable changes rendering correctly and safely." `
    -Status "Blocked" `
    -Evidence "EnableDLSS is exposed and wired to the experimental source-guided EASU ctx.cmd command-buffer candidate. Runtime evidence and the user-rendering candidate proof are tracked by readiness when present, but image-correctness, performance, resize/reset, and fallback validation are not complete yet."))

$mvpBlockingStatuses = @("Fail", "Blocked", "Missing")
$hardFailures = @($items | Where-Object { $_.Status -eq "Fail" })
$diagnosticPackageReady = -not @($items | Where-Object {
        ($_.Area -in @("Package", "Compliance", "Automation", "Docs")) -and $_.Status -in @("Fail", "Missing")
    })
$mvpReady = -not @($items | Where-Object { $mvpBlockingStatuses -contains $_.Status })
$overallStatus = if ($mvpReady) {
    "MvpReady"
} elseif ($hardFailures.Count -gt 0) {
    "Fail"
} elseif ($diagnosticPackageReady) {
    "DiagnosticPackageReady_MvpBlocked"
} else {
    "NotReady"
}

$summary = [pscustomobject]@{
    OverallStatus = $overallStatus
    DiagnosticPackageReady = $diagnosticPackageReady
    MvpReady = $mvpReady
    PackagePath = $PackagePath
    GamePath = $GamePath
    Items = $items
    NextRuntimeProofPlan = $nextRuntimeProofPlan
    NextRecommendation = if ($mvpReady) {
        "MVP evidence is complete. Prepare a final release review."
    } elseif ([string]::IsNullOrWhiteSpace($GamePath)) {
        "Pass -GamePath to include local runtime evidence. Current MVP route is paused on direct runtime probing: use the static HDRP/DLSS route, m_DLSSPass xref, and official-equivalent RenderGraph boundary audits. The contract analyzer now proves the observed EASU chain alone is incomplete; next run or inspect the default-off hdrp-dlss-contract-bind-render-scale stage to bind HDRP depth/motion correlation to the Uber->EASU->Final chain before any bounded no-write cost proof. Avoid camera-gate probing and new mod-owned pass injection."
    } elseif ($visualStatus.Status -ne "Pass" -and $visualStatus.HumanReviewStatus -eq "Pending") {
        if (-not [string]::IsNullOrWhiteSpace($visualNextRecommendation)) {
            $visualNextRecommendation
        } else {
            "Complete the pending human visual review only after confirming the candidate uses V Rising FSR Off with mod-owned render-scale control."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 8A*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Pass -GamePath to include runtime validation evidence, then run scripts\run-vrising-diagnostic.ps1 -Stage dlss-evaluate-inputs in a local/private gameplay scene."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 8B*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Run scripts\run-vrising-diagnostic.ps1 -Stage dlss-evaluate with a local SDK-wrapper native build, DLSS runtime path, and DLSS disabled by default."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 8C*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Rerun scripts\run-vrising-diagnostic.ps1 -Stage dlss-evaluate with the output follow-up probe, then preserve the archived log."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 8D*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Run scripts\run-vrising-diagnostic.ps1 -Stage dlss-persistent-evaluate with a local SDK-wrapper native build, DLSS runtime path, and DLSS disabled by default."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 8E*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Run scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-inputs to prove a render-input-smaller-than-output tuple."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 8F*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Run scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-evaluate with a local SDK-wrapper native build, DLSS runtime path, and DLSS disabled by default."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 8G*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Run scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-persistent-evaluate with a local SDK-wrapper native build, DLSS runtime path, and DLSS disabled by default."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 9A*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Run scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-frame-sequence with a local SDK-wrapper native build, DLSS runtime path, and DLSS disabled by default."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Stage 10A*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Run scripts\run-vrising-diagnostic.ps1 -Stage dlss-visible-writeback with a local SDK-wrapper native build, DLSS runtime path, and DLSS disabled by default."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Experimental EnableDLSS user-rendering*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($runtimeNextRecommendation)) {
            $runtimeNextRecommendation
        } else {
            "Do not rerun rejected RenderGraph wrapper stages unchanged. Re-run or inspect the source-guided EASU ctx.cmd dlss-user-rendering protected gameplay proof, then move to paired visual/performance validation with V Rising FSR Off and -ProtectSave -SaveName 11111."
        }
    } elseif (@($items | Where-Object { $_.Requirement -like "Normal-user dlss-user-rendering gameplay visual/performance comparison*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($visualNextRecommendation)) {
            $visualNextRecommendation
        } else {
            "Do not rerun the same EASU ctx.cmd candidate unchanged. Use the static HDRP/DLSS route, m_DLSSPass xref, and official-equivalent RenderGraph boundary audits. The contract analyzer now proves the observed EASU chain alone is incomplete; next run or inspect the default-off hdrp-dlss-contract-bind-render-scale stage to bind HDRP depth/motion correlation to the Uber->EASU->Final chain before any bounded no-write cost proof. Reserve hdrp-dlss-schedule-gate only as a later menu classifier and do not inject a new mod-owned RenderGraph pass."
        }
    } else {
        "Validate image correctness, output selection, resize/reset handling, and fallback behavior before public release."
    }
    LaunchesGame = $false
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 6
} else {
    $summary
}

if ($RequireMvpReady -and -not $mvpReady) {
    exit 1
}
