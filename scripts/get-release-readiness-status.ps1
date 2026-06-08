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
$resizeResetValidationPath = Join-Path $resolvedRoot "docs\release\dlss-resize-reset-validation.md"
$fallbackValidationPath = Join-Path $resolvedRoot "docs\release\dlss-fallback-validation.md"
$workflowPath = Join-Path $resolvedRoot ".github\workflows\build-package.yml"
$configTemplatePath = Join-Path $resolvedRoot "package\thunderstore\VrisingDLSS.cfg"
$hdrpAssetRequirement = "Local HDRP asset unpack identifies the active render pipeline asset and DLSS/upscaler gates without launching or modifying the game."
$dlssNativeStubRequirement = "Local HDRP DLSS native-stub audit confirms the official DLSS activation/execution body is inert while the RenderGraph shell remains non-stub without launching or modifying the game."
$officialDlssContractRequirement = "Local HDRP DLSS official-contract guard confirms DoDLSSPass needs color/depth/motion/bias resources while V Rising's active EASU path remains color-only, without launching or modifying the game."
$phase0ChatlogRequirement = "Phase 0 chatlog reconstruction covers the 2026-06-04 source log in contiguous chronological chunks without launching or modifying the game."
$phase1GameplayAutomationRequirement = "Phase 1 gameplay automation coverage preserves the proven automatic 11111 Continue route, protected 1920x1080 Windowed protocol, and Computer Use-only UI boundary without launching or modifying the game."
$runtimeDistributionContractRequirement = "DLSS runtime distribution approval gate rejects semantic false positives such as third-party mirrors, missing source URLs, and bundled runtimes without SHA256 checksums."
$contractBindStageRequirement = "Contract-bind render-scale stage dry-run remains no-native/no-evaluate and launch-safe before gameplay automation."
$contractAnalyzerRequirement = "HDRP DLSS schedule analyzer recognizes the contract-bind success shape and rejects evaluate-polluted logs without launching or modifying the game."
$contractBindGameplayProofRequirement = "Protected contract-bind gameplay proof advances the route to bounded no-write B/C/D cost isolation without evaluate/GetTexture pollution."
$boundedNoWriteCostMatrixRequirement = "Bounded no-write B/C/D cost matrix guard maps carrier/native/plugin-event layers to launch-safe stages and near-baseline performance thresholds without launching or modifying the game."
$runtimeNextRecommendationContractRequirement = "Runtime status recommendations defer the known-regressed EASU ctx.cmd user-rendering candidate, run contract-bind only until it passes, then advance to bounded no-write B/C/D cost isolation."
$docNextRecommendationContractRequirement = "Current docs keep the known-regressed dlss-user-rendering route framed as reproduction/investigation, record the contract-bind proof, and name bounded no-write B/C/D cost isolation as the next runtime proof."
$experimentEvidenceLockRequirement = "Experiment evidence locks preserve rejected routes and require the staged carrier/native/plugin-event/NGX/scratch/copy/visible-write matrix before 4K value proof."
$runtimeEnvironmentSnapshotRequirement = "Runtime performance captures preserve before/after system snapshots with CPU, GPU utilization, power, temperature, memory, and top-process context without launching or modifying the game."
$localDecompilationInvestigationRequirement = "Systematic local decompilation investigation keeps clean-room evidence/inference boundaries and, when GamePath is available, rechecks HDRP route anchors, inert DLSSPass bodies, asset gates, and the official DLSS vs EASU contract split without launching or modifying the game."
$localSaveFixtureRequirement = "Local V Rising save fixture resolver finds exactly one usable Continue target named 11111 without launching or modifying the game."
$renderGraphBoundaryRouteRequirement = "RenderGraph boundary route guard keeps mod-owned RenderGraph pass injection rejected as the normal route without launching or modifying the game."
$runtimeDistributionRequirement = "Normal-user DLSS runtime distribution path is approved and does not require ad hoc manual DLL downloads."
$mvpSafetyContractRequirement = "DLSS resize/reset and fallback validation gates reject semantic false positives such as startup-only resize records, missing artifacts, and untested fallback cases."
$resizeResetRequirement = "Normal-user DLSS resize/reset behavior is validated with gameplay artifacts."
$fallbackRequirement = "Normal-user DLSS fallback behavior is validated for missing runtime, unsupported GPU, and resource failures."

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

$phase0ChatlogGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-chatlog-reconstruction-coverage.ps1") -Root $resolvedRoot -Json
}
$phase0ChatlogStatus = "Blocked"
$phase0ChatlogEvidence = "Phase 0 chatlog reconstruction guard did not produce evidence."
if ($phase0ChatlogGuard.Succeeded) {
    try {
        $phase0ChatlogReport = $phase0ChatlogGuard.Output | ConvertFrom-Json
        $phase0ChatlogStatus = if ($phase0ChatlogReport.Status -eq "Pass" `
                -and -not [bool]$phase0ChatlogReport.LaunchesGame `
                -and -not [bool]$phase0ChatlogReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($phase0ChatlogReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $firstChunk = @($phase0ChatlogReport.ChunkRanges | Select-Object -First 1)
        $lastChunk = @($phase0ChatlogReport.ChunkRanges | Select-Object -Last 1)
        $phase0ChatlogEvidence = "Status=$($phase0ChatlogReport.Status); SourceMessages=$($phase0ChatlogReport.SourceMessageCount); Chunks=$($phase0ChatlogReport.ChunkCount); First=$($firstChunk.MessageStart)-$($firstChunk.MessageEnd); Last=$($lastChunk.MessageStart)-$($lastChunk.MessageEnd); FailedChecks=$(@($phase0ChatlogReport.FailedChecks).Count); LaunchesGame=$($phase0ChatlogReport.LaunchesGame); ModifiesGameFiles=$($phase0ChatlogReport.ModifiesGameFiles)"
        if (@($phase0ChatlogReport.FailedChecks).Count -gt 0) {
            $phase0ChatlogEvidence = "$phase0ChatlogEvidence; Failed=$(@($phase0ChatlogReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
        }
    } catch {
        $phase0ChatlogStatus = "Blocked"
        $phase0ChatlogEvidence = "Failed to parse Phase 0 chatlog guard JSON: $($_.Exception.Message); Output=$($phase0ChatlogGuard.Output)"
    }
} else {
    $phase0ChatlogEvidence = "Phase 0 chatlog guard failed: $($phase0ChatlogGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $phase0ChatlogRequirement `
    -Status $phase0ChatlogStatus `
    -Evidence $phase0ChatlogEvidence))

$phase1GameplayArgs = @{
    Root = $resolvedRoot
    Json = $true
}
if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $phase1GameplayArgs["GamePath"] = $GamePath
}
$phase1GameplayGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-phase1-gameplay-automation-coverage.ps1") @phase1GameplayArgs
}
$phase1GameplayStatus = "Blocked"
$phase1GameplayEvidence = "Phase 1 gameplay automation coverage guard did not produce evidence."
if ($phase1GameplayGuard.Succeeded) {
    try {
        $phase1GameplayReport = $phase1GameplayGuard.Output | ConvertFrom-Json
        $phase1GameplayStatus = if ($phase1GameplayReport.Status -eq "Pass" `
                -and -not [bool]$phase1GameplayReport.LaunchesGame `
                -and -not [bool]$phase1GameplayReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($phase1GameplayReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $phase1GameplayEvidence = "Status=$($phase1GameplayReport.Status); Phase1=$($phase1GameplayReport.Phase1Status); SaveName=$($phase1GameplayReport.SaveName); LocalEvidence=$($phase1GameplayReport.LocalEvidenceStatus); Checks=$($phase1GameplayReport.CheckCount); FailedChecks=$(@($phase1GameplayReport.FailedChecks).Count); LaunchesGame=$($phase1GameplayReport.LaunchesGame); ModifiesGameFiles=$($phase1GameplayReport.ModifiesGameFiles)"
        if ($phase1GameplayReport.SaveFixture) {
            $phase1GameplayEvidence = "$phase1GameplayEvidence; SaveFixtureStatus=$($phase1GameplayReport.SaveFixture.Status); SaveFixtureMatchCount=$($phase1GameplayReport.SaveFixture.MatchCount)"
        }
        if ($phase1GameplayReport.ContractBindStage) {
            $phase1GameplayEvidence = "$phase1GameplayEvidence; ContractBindStatus=$($phase1GameplayReport.ContractBindStage.Status); RequiresComputerUse=$($phase1GameplayReport.ContractBindStage.RequiresComputerUse); MovementKeysAllowed=$($phase1GameplayReport.ContractBindStage.MovementKeysAllowed)"
        }
        if (@($phase1GameplayReport.FailedChecks).Count -gt 0) {
            $phase1GameplayEvidence = "$phase1GameplayEvidence; Failed=$(@($phase1GameplayReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
        }
    } catch {
        $phase1GameplayStatus = "Blocked"
        $phase1GameplayEvidence = "Failed to parse Phase 1 gameplay automation guard JSON: $($_.Exception.Message); Output=$($phase1GameplayGuard.Output)"
    }
} else {
    $phase1GameplayEvidence = "Phase 1 gameplay automation guard failed: $($phase1GameplayGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $phase1GameplayAutomationRequirement `
    -Status $phase1GameplayStatus `
    -Evidence $phase1GameplayEvidence))

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
        -and $workflowText -match "test-chatlog-reconstruction-coverage\.ps1" `
        -and $workflowText -match "test-phase1-gameplay-automation-coverage\.ps1" `
        -and $workflowText -match "test-dlss-runtime-distribution-gate-contract\.ps1" `
        -and $workflowText -match "test-dlss-mvp-safety-gates-contract\.ps1" `
        -and $workflowText -match "test-hdrp-dlss-contract-bind-stage\.ps1\s+-RequirePass" `
        -and $workflowText -match "test-hdrp-dlss-schedule-analyzer-contract\.ps1" `
        -and $workflowText -match "test-bounded-no-write-cost-matrix-contract\.ps1" `
        -and $workflowText -match "test-runtime-next-recommendation-contract\.ps1" `
        -and $workflowText -match "test-doc-next-recommendation-contract\.ps1" `
        -and $workflowText -match "test-experiment-evidence-lock-contract\.ps1" `
        -and $workflowText -match "test-runtime-environment-snapshot-contract\.ps1" `
        -and $workflowText -match "test-vrising-local-decompilation-investigation\.ps1" `
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

$contractAnalyzerGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-hdrp-dlss-schedule-analyzer-contract.ps1") -Root $resolvedRoot -Json
}
$contractAnalyzerStatus = "Blocked"
$contractAnalyzerEvidence = "Contract analyzer guard did not produce evidence."
if ($contractAnalyzerGuard.Succeeded) {
    try {
        $contractAnalyzerReport = $contractAnalyzerGuard.Output | ConvertFrom-Json
        $contractAnalyzerLaunchesGame = [bool]$contractAnalyzerReport.LaunchesGame
        $contractAnalyzerModifiesGameFiles = [bool]$contractAnalyzerReport.ModifiesGameFiles
        $contractAnalyzerStatus = if ($contractAnalyzerReport.Status -eq "Pass" `
                -and -not $contractAnalyzerLaunchesGame `
                -and -not $contractAnalyzerModifiesGameFiles) {
            "Pass"
        } elseif ($contractAnalyzerReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $contractAnalyzerEvidence = "Status=$($contractAnalyzerReport.Status); Checks=$($contractAnalyzerReport.CheckCount); FailedChecks=$(@($contractAnalyzerReport.FailedChecks).Count); LaunchesGame=$($contractAnalyzerReport.LaunchesGame); ModifiesGameFiles=$($contractAnalyzerReport.ModifiesGameFiles); ContractLog=$($contractAnalyzerReport.ContractLogPath); PollutedLog=$($contractAnalyzerReport.PollutedLogPath)"
        if (@($contractAnalyzerReport.FailedChecks).Count -gt 0) {
            $contractAnalyzerEvidence = "$contractAnalyzerEvidence; Failed=$(@($contractAnalyzerReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
        }
    } catch {
        $contractAnalyzerStatus = "Blocked"
        $contractAnalyzerEvidence = "Failed to parse contract analyzer guard JSON: $($_.Exception.Message); Output=$($contractAnalyzerGuard.Output)"
    }
} else {
    $contractAnalyzerEvidence = "Contract analyzer guard failed: $($contractAnalyzerGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $contractAnalyzerRequirement `
    -Status $contractAnalyzerStatus `
    -Evidence $contractAnalyzerEvidence))

$contractBindGameplayProof = $null
$contractBindGameplayProofGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\get-contract-bind-gameplay-proof.ps1") -Root $resolvedRoot -Json
}
$contractBindGameplayProofStatus = "Blocked"
$contractBindGameplayProofEvidence = "Contract-bind gameplay proof guard did not produce evidence."
if ($contractBindGameplayProofGuard.Succeeded) {
    try {
        $contractBindGameplayProof = $contractBindGameplayProofGuard.Output | ConvertFrom-Json
        $contractBindGameplayProofStatus = if ($contractBindGameplayProof.Status -eq "Pass" `
                -and -not [bool]$contractBindGameplayProof.LaunchesGame `
                -and -not [bool]$contractBindGameplayProof.ModifiesGameFiles) {
            "Pass"
        } elseif ($contractBindGameplayProof.Status -eq "Missing") {
            "Blocked"
        } else {
            "Blocked"
        }
        $contractBindGameplayProofEvidence = "Status=$($contractBindGameplayProof.Status); Source=$($contractBindGameplayProof.Source); Artifact=$($contractBindGameplayProof.ArtifactLabel); Contract=$($contractBindGameplayProof.ContractStatus); ChainsWithDepthMotion=$($contractBindGameplayProof.SuperResolutionChainsWithHdrpDepthMotion); RenderGraphGetTextureCalls=$($contractBindGameplayProof.RenderGraphGetTextureCalls); UserRenderingCandidateStarted=$($contractBindGameplayProof.UserRenderingCandidateStarted); DlssEvaluateSucceeded=$($contractBindGameplayProof.DlssEvaluateSucceeded); SaveEvidence=$($contractBindGameplayProof.Evidence); LaunchesGame=$($contractBindGameplayProof.LaunchesGame); ModifiesGameFiles=$($contractBindGameplayProof.ModifiesGameFiles)"
        if (@($contractBindGameplayProof.Issues).Count -gt 0) {
            $contractBindGameplayProofEvidence = "$contractBindGameplayProofEvidence; Issues=$(@($contractBindGameplayProof.Issues) -join ' | ')"
        }

        if ($contractBindGameplayProofStatus -eq "Pass") {
            $nextRuntimeProofPlan = [pscustomobject]@{
                Question = "Which official-equivalent boundary layer is responsible for the current user-rendering performance regression?"
                Hypothesis = "If the engine-owned EASU boundary is cheap, B/C/D no-write layers should stay near baseline at 1920x1080 Windowed before NGX evaluate or visible write-back is retried."
                RequiresComputerUse = $true
                MovementKeysAllowed = $false
                Fixture = "1920x1080 Windowed protected 11111, V Rising FSR Off, Computer Use Continue click once, no movement keys, save restore ChangeCount=0."
                Layers = @(
                    "B: EASU carrier-only cost; no native, no evaluate, no broad GetTexture.",
                    "C: native D3D11 resource-desc validate-only; no NGX init, no evaluate.",
                    "D: empty existing command-buffer plugin-event callback; no DLSS evaluate and no visible write."
                )
                PassSignals = @(
                    "Average FPS ratio >= 0.98 versus same-run baseline.",
                    "P95 frame-time delta <= 0.5 ms and P99 delta <= 1.0 ms for B/C/D.",
                    "No GPU utilization or power collapse relative to baseline.",
                    "SaveAfterRestoreChangeCount=0 and RemainingVRisingProcessCount=0 after each run."
                )
                FailSignals = @(
                    "Any NGX/DLSS evaluate, visible write-back, broad RenderGraph.GetTexture loop, crash, or save restore failure.",
                    "Any B/C/D layer reproduces the low-GPU-utilization performance collapse."
                )
            }
        }
    } catch {
        $contractBindGameplayProofStatus = "Blocked"
        $contractBindGameplayProofEvidence = "Failed to parse contract-bind gameplay proof JSON: $($_.Exception.Message); Output=$($contractBindGameplayProofGuard.Output)"
    }
} else {
    $contractBindGameplayProofEvidence = "Contract-bind gameplay proof guard failed: $($contractBindGameplayProofGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $contractBindGameplayProofRequirement `
    -Status $contractBindGameplayProofStatus `
    -Evidence $contractBindGameplayProofEvidence))

$boundedNoWriteArgs = @{
    Root = $resolvedRoot
    Json = $true
}
if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $boundedNoWriteArgs["GamePath"] = $GamePath
    $boundedNoWriteArgs["SaveName"] = "11111"
}
$boundedNoWriteGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-bounded-no-write-cost-matrix-contract.ps1") @boundedNoWriteArgs
}
$boundedNoWriteStatus = "Blocked"
$boundedNoWriteEvidence = "Bounded no-write B/C/D cost matrix guard did not produce evidence."
if ($boundedNoWriteGuard.Succeeded) {
    try {
        $boundedNoWriteReport = $boundedNoWriteGuard.Output | ConvertFrom-Json
        $boundedNoWriteStatus = if ($boundedNoWriteReport.Status -eq "Pass" `
                -and -not [bool]$boundedNoWriteReport.LaunchesGame `
                -and -not [bool]$boundedNoWriteReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($boundedNoWriteReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $boundedNoWriteEvidence = "Status=$($boundedNoWriteReport.Status); ContractBind=$($boundedNoWriteReport.ContractBindGameplayProofStatus); Stages=$($boundedNoWriteReport.StageCount); Checks=$($boundedNoWriteReport.CheckCount); FailedChecks=$(@($boundedNoWriteReport.FailedChecks).Count); LaunchesGame=$($boundedNoWriteReport.LaunchesGame); ModifiesGameFiles=$($boundedNoWriteReport.ModifiesGameFiles)"
        if ($boundedNoWriteReport.RuntimeProofPlan) {
            $nextRuntimeProofPlan = $boundedNoWriteReport.RuntimeProofPlan
            $boundedNoWriteEvidence = "$boundedNoWriteEvidence; Question=$($boundedNoWriteReport.RuntimeProofPlan.Question)"
        }
        if (@($boundedNoWriteReport.FailedChecks).Count -gt 0) {
            $boundedNoWriteEvidence = "$boundedNoWriteEvidence; Failed=$(@($boundedNoWriteReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
        }
    } catch {
        $boundedNoWriteStatus = "Blocked"
        $boundedNoWriteEvidence = "Failed to parse bounded no-write cost matrix guard JSON: $($_.Exception.Message); Output=$($boundedNoWriteGuard.Output)"
    }
} else {
    $boundedNoWriteEvidence = "Bounded no-write cost matrix guard failed: $($boundedNoWriteGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $boundedNoWriteCostMatrixRequirement `
    -Status $boundedNoWriteStatus `
    -Evidence $boundedNoWriteEvidence))

$runtimeNextRecommendationArgs = @{
    Root = $resolvedRoot
    Json = $true
}
if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $runtimeNextRecommendationArgs["GamePath"] = $GamePath
}
$runtimeNextRecommendationGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-runtime-next-recommendation-contract.ps1") @runtimeNextRecommendationArgs
}
$runtimeNextRecommendationStatus = "Blocked"
$runtimeNextRecommendationEvidence = "Runtime next-recommendation contract guard did not produce evidence."
if ($runtimeNextRecommendationGuard.Succeeded) {
    try {
        $runtimeNextRecommendationReport = $runtimeNextRecommendationGuard.Output | ConvertFrom-Json
        $runtimeNextRecommendationStatus = if ($runtimeNextRecommendationReport.Status -eq "Pass" `
                -and -not [bool]$runtimeNextRecommendationReport.LaunchesGame `
                -and -not [bool]$runtimeNextRecommendationReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($runtimeNextRecommendationReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $runtimeNextRecommendationEvidence = "Status=$($runtimeNextRecommendationReport.Status); VisualRegressionEvidence=$($runtimeNextRecommendationReport.VisualPerformanceRegressionEvidence); Checks=$($runtimeNextRecommendationReport.CheckCount); FailedChecks=$(@($runtimeNextRecommendationReport.FailedChecks).Count); LaunchesGame=$($runtimeNextRecommendationReport.LaunchesGame); ModifiesGameFiles=$($runtimeNextRecommendationReport.ModifiesGameFiles)"
        if (-not [string]::IsNullOrWhiteSpace([string]$runtimeNextRecommendationReport.RuntimeNextRecommendation)) {
            $runtimeNextRecommendationEvidence = "$runtimeNextRecommendationEvidence; RuntimeNext=$($runtimeNextRecommendationReport.RuntimeNextRecommendation)"
        }
        if (@($runtimeNextRecommendationReport.FailedChecks).Count -gt 0) {
            $runtimeNextRecommendationEvidence = "$runtimeNextRecommendationEvidence; Failed=$(@($runtimeNextRecommendationReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
        }
    } catch {
        $runtimeNextRecommendationStatus = "Blocked"
        $runtimeNextRecommendationEvidence = "Failed to parse runtime next-recommendation guard JSON: $($_.Exception.Message); Output=$($runtimeNextRecommendationGuard.Output)"
    }
} else {
    $runtimeNextRecommendationEvidence = "Runtime next-recommendation guard failed: $($runtimeNextRecommendationGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $runtimeNextRecommendationContractRequirement `
    -Status $runtimeNextRecommendationStatus `
    -Evidence $runtimeNextRecommendationEvidence))

$docNextRecommendationGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-doc-next-recommendation-contract.ps1") -Root $resolvedRoot -Json
}
$docNextRecommendationStatus = "Blocked"
$docNextRecommendationEvidence = "Doc next-recommendation contract guard did not produce evidence."
if ($docNextRecommendationGuard.Succeeded) {
    try {
        $docNextRecommendationReport = $docNextRecommendationGuard.Output | ConvertFrom-Json
        $docNextRecommendationStatus = if ($docNextRecommendationReport.Status -eq "Pass" `
                -and -not [bool]$docNextRecommendationReport.LaunchesGame `
                -and -not [bool]$docNextRecommendationReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($docNextRecommendationReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $docNextRecommendationEvidence = "Status=$($docNextRecommendationReport.Status); VisualStatus=$($docNextRecommendationReport.VisualStatus); Checks=$($docNextRecommendationReport.CheckCount); FailedChecks=$(@($docNextRecommendationReport.FailedChecks).Count); LaunchesGame=$($docNextRecommendationReport.LaunchesGame); ModifiesGameFiles=$($docNextRecommendationReport.ModifiesGameFiles)"
        if (@($docNextRecommendationReport.Issues).Count -gt 0) {
            $docNextRecommendationEvidence = "$docNextRecommendationEvidence; Issues=$(@($docNextRecommendationReport.Issues) -join ' | ')"
        }
    } catch {
        $docNextRecommendationStatus = "Blocked"
        $docNextRecommendationEvidence = "Failed to parse doc next-recommendation guard JSON: $($_.Exception.Message); Output=$($docNextRecommendationGuard.Output)"
    }
} else {
    $docNextRecommendationEvidence = "Doc next-recommendation guard failed: $($docNextRecommendationGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $docNextRecommendationContractRequirement `
    -Status $docNextRecommendationStatus `
    -Evidence $docNextRecommendationEvidence))

$experimentEvidenceLockGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-experiment-evidence-lock-contract.ps1") -Root $resolvedRoot -Json
}
$experimentEvidenceLockStatus = "Blocked"
$experimentEvidenceLockEvidence = "Experiment evidence-lock contract guard did not produce evidence."
if ($experimentEvidenceLockGuard.Succeeded) {
    try {
        $experimentEvidenceLockReport = $experimentEvidenceLockGuard.Output | ConvertFrom-Json
        $experimentEvidenceLockStatus = if ($experimentEvidenceLockReport.Status -eq "Pass" `
                -and -not [bool]$experimentEvidenceLockReport.LaunchesGame `
                -and -not [bool]$experimentEvidenceLockReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($experimentEvidenceLockReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $experimentEvidenceLockEvidence = "Status=$($experimentEvidenceLockReport.Status); Locks=$($experimentEvidenceLockReport.EvidenceLockCount); MatrixLayers=$($experimentEvidenceLockReport.MatrixLayerCount); Checks=$($experimentEvidenceLockReport.CheckCount); FailedChecks=$(@($experimentEvidenceLockReport.FailedChecks).Count); LaunchesGame=$($experimentEvidenceLockReport.LaunchesGame); ModifiesGameFiles=$($experimentEvidenceLockReport.ModifiesGameFiles)"
        if (@($experimentEvidenceLockReport.Issues).Count -gt 0) {
            $experimentEvidenceLockEvidence = "$experimentEvidenceLockEvidence; Issues=$(@($experimentEvidenceLockReport.Issues) -join ' | ')"
        }
    } catch {
        $experimentEvidenceLockStatus = "Blocked"
        $experimentEvidenceLockEvidence = "Failed to parse experiment evidence-lock guard JSON: $($_.Exception.Message); Output=$($experimentEvidenceLockGuard.Output)"
    }
} else {
    $experimentEvidenceLockEvidence = "Experiment evidence-lock guard failed: $($experimentEvidenceLockGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $experimentEvidenceLockRequirement `
    -Status $experimentEvidenceLockStatus `
    -Evidence $experimentEvidenceLockEvidence))

$runtimeEnvironmentSnapshotGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-runtime-environment-snapshot-contract.ps1") -Root $resolvedRoot -Json
}
$runtimeEnvironmentSnapshotStatus = "Blocked"
$runtimeEnvironmentSnapshotEvidence = "Runtime environment snapshot contract guard did not produce evidence."
if ($runtimeEnvironmentSnapshotGuard.Succeeded) {
    try {
        $runtimeEnvironmentSnapshotReport = $runtimeEnvironmentSnapshotGuard.Output | ConvertFrom-Json
        $runtimeEnvironmentSnapshotStatus = if ($runtimeEnvironmentSnapshotReport.Status -eq "Pass" `
                -and -not [bool]$runtimeEnvironmentSnapshotReport.LaunchesGame `
                -and -not [bool]$runtimeEnvironmentSnapshotReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($runtimeEnvironmentSnapshotReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $runtimeEnvironmentSnapshotEvidence = "Status=$($runtimeEnvironmentSnapshotReport.Status); Checks=$($runtimeEnvironmentSnapshotReport.CheckCount); FailedChecks=$(@($runtimeEnvironmentSnapshotReport.FailedChecks).Count); GpuAvailable=$($runtimeEnvironmentSnapshotReport.GpuAvailable); LaunchesGame=$($runtimeEnvironmentSnapshotReport.LaunchesGame); ModifiesGameFiles=$($runtimeEnvironmentSnapshotReport.ModifiesGameFiles); Snapshot=$($runtimeEnvironmentSnapshotReport.SnapshotPath)"
        if (@($runtimeEnvironmentSnapshotReport.Issues).Count -gt 0) {
            $runtimeEnvironmentSnapshotEvidence = "$runtimeEnvironmentSnapshotEvidence; Issues=$(@($runtimeEnvironmentSnapshotReport.Issues) -join ' | ')"
        }
    } catch {
        $runtimeEnvironmentSnapshotStatus = "Blocked"
        $runtimeEnvironmentSnapshotEvidence = "Failed to parse runtime environment snapshot guard JSON: $($_.Exception.Message); Output=$($runtimeEnvironmentSnapshotGuard.Output)"
    }
} else {
    $runtimeEnvironmentSnapshotEvidence = "Runtime environment snapshot guard failed: $($runtimeEnvironmentSnapshotGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $runtimeEnvironmentSnapshotRequirement `
    -Status $runtimeEnvironmentSnapshotStatus `
    -Evidence $runtimeEnvironmentSnapshotEvidence))

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

$localDecompilationArgs = @{
    Root = $resolvedRoot
    Json = $true
}
if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $localDecompilationArgs["GamePath"] = $GamePath
    $localDecompilationArgs["RequireLocalEvidence"] = $true
}
$localDecompilationGuard = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-vrising-local-decompilation-investigation.ps1") @localDecompilationArgs
}
$localDecompilationStatus = "Blocked"
$localDecompilationEvidence = "Local decompilation investigation guard did not produce evidence."
if ($localDecompilationGuard.Succeeded) {
    try {
        $localDecompilationReport = $localDecompilationGuard.Output | ConvertFrom-Json
        $localDecompilationLaunchesGame = [bool]$localDecompilationReport.LaunchesGame
        $localDecompilationModifiesGameFiles = [bool]$localDecompilationReport.ModifiesGameFiles
        $localDecompilationStatus = if ($localDecompilationReport.Status -eq "Pass" `
                -and -not $localDecompilationLaunchesGame `
                -and -not $localDecompilationModifiesGameFiles) {
            "Pass"
        } elseif ($localDecompilationReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $localDecompilationEvidence = "Status=$($localDecompilationReport.Status); LocalEvidence=$($localDecompilationReport.LocalEvidenceStatus); Checks=$($localDecompilationReport.CheckCount); FailedChecks=$(@($localDecompilationReport.FailedChecks).Count); LaunchesGame=$($localDecompilationReport.LaunchesGame); ModifiesGameFiles=$($localDecompilationReport.ModifiesGameFiles); StaticRoute=$($localDecompilationReport.Evidence.StaticRouteStatus); NativeStub=$($localDecompilationReport.Evidence.NativeStubStatus); OfficialContract=$($localDecompilationReport.Evidence.OfficialContractStatus); Next=$($localDecompilationReport.Summary.NextBoundary)"
        if (@($localDecompilationReport.Issues).Count -gt 0) {
            $localDecompilationEvidence = "$localDecompilationEvidence; Issues=$(@($localDecompilationReport.Issues) -join ' | ')"
        }
    } catch {
        $localDecompilationStatus = "Blocked"
        $localDecompilationEvidence = "Failed to parse local decompilation investigation guard JSON: $($_.Exception.Message); Output=$($localDecompilationGuard.Output)"
    }
} else {
    $localDecompilationEvidence = "Local decompilation investigation guard failed: $($localDecompilationGuard.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $localDecompilationInvestigationRequirement `
    -Status $localDecompilationStatus `
    -Evidence $localDecompilationEvidence))

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

    $nativeStubAudit = Invoke-CapturedCommand -Command {
        & (Join-Path $resolvedRoot "scripts\inspect-vrising-hdrp-dlss-native-stubs.ps1") -Root $resolvedRoot -GamePath $GamePath -Json
    }
    $nativeStubStatus = "Blocked"
    $nativeStubEvidence = "Native-stub audit did not produce evidence."
    if ($nativeStubAudit.Succeeded) {
        try {
            $nativeStubReport = $nativeStubAudit.Output | ConvertFrom-Json
            $nativeStubLaunchesGame = [bool]$nativeStubReport.LaunchesGame
            $nativeStubModifiesGameFiles = [bool]$nativeStubReport.ModifiesGameFiles
            $methodEvidence = (@($nativeStubReport.Methods) | ForEach-Object {
                    "$($_.Name -replace '^.*\$\$', '')=$($_.Classification)"
                }) -join ", "
            $nativeStubEvidence = "Status=$($nativeStubReport.Status); LaunchesGame=$($nativeStubReport.LaunchesGame); ModifiesGameFiles=$($nativeStubReport.ModifiesGameFiles); Methods=$methodEvidence"
            if ($nativeStubLaunchesGame -or $nativeStubModifiesGameFiles) {
                $nativeStubStatus = "Fail"
            } elseif ($nativeStubReport.Status -eq "Pass") {
                $nativeStubStatus = "Pass"
            } elseif ($nativeStubReport.Status -eq "Fail") {
                $nativeStubStatus = "Fail"
            } else {
                $nativeStubStatus = "Blocked"
            }
            if (@($nativeStubReport.Issues).Count -gt 0) {
                $nativeStubEvidence = "$nativeStubEvidence; Issues=$(@($nativeStubReport.Issues) -join ' | ')"
            }
        } catch {
            $nativeStubStatus = "Blocked"
            $nativeStubEvidence = "Failed to parse native-stub audit JSON: $($_.Exception.Message); Output=$($nativeStubAudit.Output)"
        }
    } else {
        $nativeStubEvidence = "Native-stub audit failed: $($nativeStubAudit.Output)"
    }

    $items.Add((New-ReadinessItem `
        -Area "Evidence" `
        -Requirement $dlssNativeStubRequirement `
        -Status $nativeStubStatus `
        -Evidence $nativeStubEvidence))

    $officialContractGuard = Invoke-CapturedCommand -Command {
        & (Join-Path $resolvedRoot "scripts\test-vrising-hdrp-dlss-official-contract.ps1") -Root $resolvedRoot -GamePath $GamePath -Json
    }
    $officialContractStatus = "Blocked"
    $officialContractEvidence = "Official-contract guard did not produce evidence."
    if ($officialContractGuard.Succeeded) {
        try {
            $officialContractReport = $officialContractGuard.Output | ConvertFrom-Json
            $officialContractLaunchesGame = [bool]$officialContractReport.LaunchesGame
            $officialContractModifiesGameFiles = [bool]$officialContractReport.ModifiesGameFiles
            $officialContractStatus = if ($officialContractReport.Status -eq "Pass" `
                    -and -not $officialContractLaunchesGame `
                    -and -not $officialContractModifiesGameFiles) {
                "Pass"
            } elseif ($officialContractReport.Status -eq "Fail") {
                "Fail"
            } else {
                "Blocked"
            }
            $officialContractEvidence = "Status=$($officialContractReport.Status); Checks=$($officialContractReport.CheckCount); FailedChecks=$(@($officialContractReport.FailedChecks).Count); LaunchesGame=$($officialContractReport.LaunchesGame); ModifiesGameFiles=$($officialContractReport.ModifiesGameFiles); Boundary=$($officialContractReport.Summary.BoundaryImplication)"
            if (@($officialContractReport.FailedChecks).Count -gt 0) {
                $officialContractEvidence = "$officialContractEvidence; Failed=$(@($officialContractReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
            }
        } catch {
            $officialContractStatus = "Blocked"
            $officialContractEvidence = "Failed to parse official-contract guard JSON: $($_.Exception.Message); Output=$($officialContractGuard.Output)"
        }
    } else {
        $officialContractEvidence = "Official-contract guard failed: $($officialContractGuard.Output)"
    }

    $items.Add((New-ReadinessItem `
        -Area "Evidence" `
        -Requirement $officialDlssContractRequirement `
        -Status $officialContractStatus `
        -Evidence $officialContractEvidence))

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
        -Area "Evidence" `
        -Requirement $dlssNativeStubRequirement `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include local HDRP DLSS native-stub audit evidence."))
    $items.Add((New-ReadinessItem `
        -Area "Evidence" `
        -Requirement $officialDlssContractRequirement `
        -Status "Missing" `
        -Evidence "Pass -GamePath to include local HDRP DLSS official-contract guard evidence."))

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

$runtimeDistributionContractGate = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-dlss-runtime-distribution-gate-contract.ps1") -Root $resolvedRoot -Json
}
$runtimeDistributionContractStatus = "Blocked"
$runtimeDistributionContractEvidence = "DLSS runtime distribution contract guard did not produce evidence."
if ($runtimeDistributionContractGate.Succeeded) {
    try {
        $runtimeDistributionContractReport = $runtimeDistributionContractGate.Output | ConvertFrom-Json
        $runtimeDistributionContractStatus = if ($runtimeDistributionContractReport.Status -eq "Pass" `
                -and -not [bool]$runtimeDistributionContractReport.LaunchesGame `
                -and -not [bool]$runtimeDistributionContractReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($runtimeDistributionContractReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $runtimeDistributionContractEvidence = "Status=$($runtimeDistributionContractReport.Status); Checks=$($runtimeDistributionContractReport.CheckCount); FailedChecks=$(@($runtimeDistributionContractReport.FailedChecks).Count); LaunchesGame=$($runtimeDistributionContractReport.LaunchesGame); ModifiesGameFiles=$($runtimeDistributionContractReport.ModifiesGameFiles)"
        if (@($runtimeDistributionContractReport.FailedChecks).Count -gt 0) {
            $runtimeDistributionContractEvidence = "$runtimeDistributionContractEvidence; Failed=$(@($runtimeDistributionContractReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
        }
    } catch {
        $runtimeDistributionContractStatus = "Blocked"
        $runtimeDistributionContractEvidence = "Failed to parse DLSS runtime distribution contract guard JSON: $($_.Exception.Message); Output=$($runtimeDistributionContractGate.Output)"
    }
} else {
    $runtimeDistributionContractEvidence = "DLSS runtime distribution contract guard failed: $($runtimeDistributionContractGate.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $runtimeDistributionContractRequirement `
    -Status $runtimeDistributionContractStatus `
    -Evidence $runtimeDistributionContractEvidence))

$runtimeDistributionGate = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-dlss-runtime-distribution-gate.ps1") `
        -Root $resolvedRoot `
        -GatePath $runtimeDistributionGatePath `
        -ApprovalPath $runtimeDistributionApprovalPath `
        -Json
}
$runtimeDistributionStatus = "Blocked"
$runtimeDistributionEvidence = "DLSS runtime distribution gate did not produce evidence."
if ($runtimeDistributionGate.Succeeded) {
    try {
        $runtimeDistributionReport = $runtimeDistributionGate.Output | ConvertFrom-Json
        $runtimeDistributionStatus = if ($runtimeDistributionReport.Status -eq "Pass") {
            "Pass"
        } elseif ($runtimeDistributionReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $runtimeDistributionEvidence = "Status=$($runtimeDistributionReport.Status); Approved=$($runtimeDistributionReport.RuntimeDistributionApproved); GateExists=$($runtimeDistributionReport.GateExists); ApprovalExists=$($runtimeDistributionReport.ApprovalExists); RequiredMarkers=$($runtimeDistributionReport.RequiredApprovalMarkerCount); MissingMarkers=$(@($runtimeDistributionReport.MissingApprovalMarkers).Count); EmptyMarkers=$(@($runtimeDistributionReport.EmptyApprovalMarkers).Count); PlaceholderCount=$($runtimeDistributionReport.PlaceholderCount); Gate=$($runtimeDistributionReport.GatePath); Approval=$($runtimeDistributionReport.ApprovalPath)"
        if (@($runtimeDistributionReport.Issues).Count -gt 0) {
            $runtimeDistributionEvidence = "$runtimeDistributionEvidence; Issues=$(@($runtimeDistributionReport.Issues) -join ' | ')"
        }
    } catch {
        $runtimeDistributionStatus = "Blocked"
        $runtimeDistributionEvidence = "Failed to parse DLSS runtime distribution gate JSON: $($_.Exception.Message); Output=$($runtimeDistributionGate.Output)"
    }
} else {
    $runtimeDistributionEvidence = "DLSS runtime distribution gate failed: $($runtimeDistributionGate.Output)"
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

$mvpSafetyContractGate = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-dlss-mvp-safety-gates-contract.ps1") -Root $resolvedRoot -Json
}
$mvpSafetyContractStatus = "Blocked"
$mvpSafetyContractEvidence = "DLSS MVP safety gate contract guard did not produce evidence."
if ($mvpSafetyContractGate.Succeeded) {
    try {
        $mvpSafetyContractReport = $mvpSafetyContractGate.Output | ConvertFrom-Json
        $mvpSafetyContractStatus = if ($mvpSafetyContractReport.Status -eq "Pass" `
                -and -not [bool]$mvpSafetyContractReport.LaunchesGame `
                -and -not [bool]$mvpSafetyContractReport.ModifiesGameFiles) {
            "Pass"
        } elseif ($mvpSafetyContractReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $mvpSafetyContractEvidence = "Status=$($mvpSafetyContractReport.Status); Checks=$($mvpSafetyContractReport.CheckCount); FailedChecks=$(@($mvpSafetyContractReport.FailedChecks).Count); LaunchesGame=$($mvpSafetyContractReport.LaunchesGame); ModifiesGameFiles=$($mvpSafetyContractReport.ModifiesGameFiles)"
        if (@($mvpSafetyContractReport.FailedChecks).Count -gt 0) {
            $mvpSafetyContractEvidence = "$mvpSafetyContractEvidence; Failed=$(@($mvpSafetyContractReport.FailedChecks | ForEach-Object { $_.Name }) -join ' | ')"
        }
    } catch {
        $mvpSafetyContractStatus = "Blocked"
        $mvpSafetyContractEvidence = "Failed to parse DLSS MVP safety gate contract guard JSON: $($_.Exception.Message); Output=$($mvpSafetyContractGate.Output)"
    }
} else {
    $mvpSafetyContractEvidence = "DLSS MVP safety gate contract guard failed: $($mvpSafetyContractGate.Output)"
}

$items.Add((New-ReadinessItem `
    -Area "Evidence" `
    -Requirement $mvpSafetyContractRequirement `
    -Status $mvpSafetyContractStatus `
    -Evidence $mvpSafetyContractEvidence))

$mvpSafetyGate = Invoke-CapturedCommand -Command {
    & (Join-Path $resolvedRoot "scripts\test-dlss-mvp-safety-gates.ps1") `
        -Root $resolvedRoot `
        -ResizeResetPath $resizeResetValidationPath `
        -FallbackPath $fallbackValidationPath `
        -Json
}
$resizeResetStatus = "Blocked"
$resizeResetEvidence = "DLSS resize/reset validation gate did not produce evidence."
$fallbackStatus = "Blocked"
$fallbackEvidence = "DLSS fallback validation gate did not produce evidence."
if ($mvpSafetyGate.Succeeded) {
    try {
        $mvpSafetyReport = $mvpSafetyGate.Output | ConvertFrom-Json
        $resizeResetReport = $mvpSafetyReport.ResizeReset
        $fallbackReport = $mvpSafetyReport.Fallback
        $resizeResetStatus = if ($resizeResetReport.Status -eq "Pass") {
            "Pass"
        } elseif ($resizeResetReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $fallbackStatus = if ($fallbackReport.Status -eq "Pass") {
            "Pass"
        } elseif ($fallbackReport.Status -eq "Fail") {
            "Fail"
        } else {
            "Blocked"
        }
        $resizeResetEvidence = "Status=$($resizeResetReport.Status); Exists=$($resizeResetReport.Exists); RequiredMarkers=$($resizeResetReport.RequiredMarkerCount); MissingMarkers=$(@($resizeResetReport.MissingMarkers).Count); EmptyMarkers=$(@($resizeResetReport.EmptyMarkers).Count); PlaceholderCount=$($resizeResetReport.PlaceholderCount); Path=$($resizeResetReport.Path)"
        if (@($resizeResetReport.Issues).Count -gt 0) {
            $resizeResetEvidence = "$resizeResetEvidence; Issues=$(@($resizeResetReport.Issues) -join ' | ')"
        }
        $fallbackEvidence = "Status=$($fallbackReport.Status); Exists=$($fallbackReport.Exists); RequiredMarkers=$($fallbackReport.RequiredMarkerCount); MissingMarkers=$(@($fallbackReport.MissingMarkers).Count); EmptyMarkers=$(@($fallbackReport.EmptyMarkers).Count); PlaceholderCount=$($fallbackReport.PlaceholderCount); Path=$($fallbackReport.Path)"
        if (@($fallbackReport.Issues).Count -gt 0) {
            $fallbackEvidence = "$fallbackEvidence; Issues=$(@($fallbackReport.Issues) -join ' | ')"
        }
    } catch {
        $resizeResetStatus = "Blocked"
        $fallbackStatus = "Blocked"
        $resizeResetEvidence = "Failed to parse DLSS MVP safety gate JSON: $($_.Exception.Message); Output=$($mvpSafetyGate.Output)"
        $fallbackEvidence = $resizeResetEvidence
    }
} else {
    $resizeResetEvidence = "DLSS MVP safety gate failed: $($mvpSafetyGate.Output)"
    $fallbackEvidence = $resizeResetEvidence
}

$items.Add((New-ReadinessItem `
    -Area "MVP" `
    -Requirement $resizeResetRequirement `
    -Status $resizeResetStatus `
    -Evidence $resizeResetEvidence))

$items.Add((New-ReadinessItem `
    -Area "MVP" `
    -Requirement $fallbackRequirement `
    -Status $fallbackStatus `
    -Evidence $fallbackEvidence))

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
    ContractBindGameplayProof = $contractBindGameplayProof
    NextRecommendation = if ($mvpReady) {
        "MVP evidence is complete. Prepare a final release review."
    } elseif ([string]::IsNullOrWhiteSpace($GamePath)) {
        if ($contractBindGameplayProof -and [string]$contractBindGameplayProof.Status -eq "Pass") {
            [string]$contractBindGameplayProof.NextRecommendation
        } else {
            "Pass -GamePath to include local runtime evidence. Current MVP route is paused on direct runtime probing: use the static HDRP/DLSS route, m_DLSSPass xref, and official-equivalent RenderGraph boundary audits. The contract analyzer now proves the observed EASU chain alone is incomplete; next run or inspect the default-off hdrp-dlss-contract-bind-render-scale stage to bind HDRP depth/motion correlation to the Uber->EASU->Final chain before any bounded no-write cost proof. Avoid camera-gate probing and new mod-owned pass injection."
        }
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
