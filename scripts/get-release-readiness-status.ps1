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

$manifestPath = Join-Path $resolvedRoot "package\thunderstore\manifest.json"
$packageReadmePath = Join-Path $resolvedRoot "package\thunderstore\README.md"
$thirdPartyNoticesPath = Join-Path $resolvedRoot "package\thunderstore\ThirdPartyNotices.md"
$installDocPath = Join-Path $resolvedRoot "docs\install.md"
$troubleshootingDocPath = Join-Path $resolvedRoot "docs\troubleshooting.md"
$mvpDocPath = Join-Path $resolvedRoot "docs\mvp.md"
$measurementPlanPath = Join-Path $resolvedRoot "docs\development\measurement-plan.md"
$workflowPath = Join-Path $resolvedRoot ".github\workflows\build-package.yml"
$configTemplatePath = Join-Path $resolvedRoot "package\thunderstore\VrisingDLSS.cfg"

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
        -and $workflowText -match "actions/upload-artifact@v4"
    $items.Add((New-ReadinessItem `
        -Area "Automation" `
        -Requirement "GitHub Actions builds and validates the package artifact on a pinned Windows runner." `
        -Status $(if ($workflowOk) { "Pass" } else { "Fail" }) `
        -Evidence $workflowPath))
} else {
    $items.Add((New-ReadinessItem `
        -Area "Automation" `
        -Requirement "GitHub Actions package workflow exists." `
        -Status "Missing" `
        -Evidence "Missing $workflowPath"))
}

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
    -Evidence "EnableDLSS is exposed and wired to an experimental one-evaluate-per-Unity-frame candidate. Stage 8A/8B/8C/8D/8E/8F/8G/9A/10A frame-input/evaluate/output-follow-up/persistent-lifecycle/SR-sizing/SR-evaluate/SR-persistent-lifecycle/frame-sequence/visible-path evidence and the user-rendering candidate evidence are tracked by readiness when present, but image-correctness, performance, resize/reset, and fallback validation are not complete yet."))

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
    NextRecommendation = if ($mvpReady) {
        "MVP evidence is complete. Prepare a final release review."
    } elseif ([string]::IsNullOrWhiteSpace($GamePath)) {
        "Pass -GamePath to include local runtime evidence. Current MVP next step is not another broad DLSS search or unchanged RenderGraph map run: the native-renderfunc-entry preflight plus menu/gameplay proofs passed, native-renderfunc-args menu/gameplay proofs passed, native-renderfunc-resource-identity menu/gameplay proofs passed, native-renderfunc-resource-tuple menu/gameplay proofs passed, and native-renderfunc-resource-resolve menu/gameplay proofs passed. Next narrow step is deciding/designing a separately guarded actual native texture-pointer preflight, or proving no safe equivalent boundary exists; still no command-buffer access or DLSS evaluate."
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
        "Do not rerun rejected RenderGraph wrapper stages unchanged. The official HDRP DLSS boundary is the Deep Learning Super Sampling render func, but V Rising has no proven safe Harmony-equivalent boundary. The rendergraph-compiled-pass-info proof plus native-renderfunc-entry preflight/menu/gameplay proofs passed, native-renderfunc-args menu/gameplay proofs passed, native-renderfunc-resource-identity menu/gameplay proofs passed, native-renderfunc-resource-tuple menu/gameplay proofs passed, and native-renderfunc-resource-resolve menu/gameplay proofs passed. Next narrow step is deciding/designing a separately guarded actual native texture-pointer preflight, or proving no safe equivalent boundary exists; still no command-buffer access or DLSS evaluate."
    } elseif (@($items | Where-Object { $_.Requirement -like "Normal-user dlss-user-rendering gameplay visual/performance comparison*" -and $_.Status -ne "Pass" }).Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($visualNextRecommendation)) {
            $visualNextRecommendation
        } else {
            "After a safe targeted placement route replaces the hot global GetTexture steady-state path, rerun paired dlss-user-rendering gameplay visual/performance comparison and add a matching human review file."
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
