param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$LogPath,

    [string]$Root,

    [switch]$IncludeArchivedLogs,

    [string]$ArchivedLogRoot,

    [int]$MaxArchivedAnalysisFiles = 120,

    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

if ($MaxArchivedAnalysisFiles -lt 1) {
    throw "MaxArchivedAnalysisFiles must be positive."
}

function Get-ConfigValueMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $map = @{}
    $section = ""
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            $section = $trimmed.Trim("[", "]")
            continue
        }

        $parts = $trimmed -split "=", 2
        if ($parts.Count -ne 2) {
            continue
        }

        $key = if ([string]::IsNullOrWhiteSpace($section)) {
            $parts[0].Trim()
        } else {
            "$section.$($parts[0].Trim())"
        }

        $map[$key] = $parts[1].Trim()
    }

    return $map
}

function Test-ConfigTrue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    return $Map.ContainsKey($Key) -and $Map[$Key].Equals("true", [StringComparison]::OrdinalIgnoreCase)
}

function Get-ConfiguredStage {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssPersistentEvaluateProbe") { return "dlss-persistent-evaluate" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssEvaluateProbe") { return "dlss-evaluate" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssVisibleWritebackProbe") { return "dlss-visible-writeback" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssSuperResolutionFrameSequenceEvaluateProbe") { return "dlss-super-resolution-frame-sequence" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssSuperResolutionPersistentEvaluateProbe") { return "dlss-super-resolution-persistent-evaluate" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssSuperResolutionEvaluateProbe") { return "dlss-super-resolution-evaluate" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssSuperResolutionInputProbe") { return "dlss-super-resolution-inputs" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssEvaluateInputProbe") { return "dlss-evaluate-inputs" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssPassResourceProbe") { return "dlsspass-resource" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassBoundaryProbe") { return "rendergraph-pass-boundary" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassMapProbe") { return "rendergraph-pass-map" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpDlssScheduleGateProbe") { return "hdrp-dlss-schedule-gate" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassListProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassDataSnapshotProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "hdrp-dlss-contract-bind-render-scale" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassDataSnapshotProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe") -and
        (-not (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeBridgeSmokeTest"))) { return "easu-carrier-only-cost-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassListProbe") { return "rendergraph-pass-list" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassResourceDeclarationProbe") { return "rendergraph-pass-declarations" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassDataSnapshotProbe") { return "rendergraph-pass-data" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe") { return "rendergraph-renderfunc-metadata" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphCompiledPassInfoProbe") { return "rendergraph-compiled-pass-info" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphExecuteDelegateProbe") { return "rendergraph-execute-delegate" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe") { return "native-renderfunc-commandbuffer-frame-descriptor-d3d11" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe") { return "native-renderfunc-commandbuffer-dlss-visible-writeback" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe") { return "native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe") { return "native-renderfunc-commandbuffer-dlss-scratch-evaluate" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-frame-descriptor-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe") { return "native-renderfunc-commandbuffer-frame-descriptor" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "hdrp-easu-input-output-correlation-render-scale" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferEventProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-event-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferEventProbe") { return "native-renderfunc-commandbuffer-event" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferPayloadProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-payload-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferPayloadProbe") { return "native-renderfunc-commandbuffer-payload" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssFeatureCreateProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-commandbuffer-dlss-create-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssFeatureCreateProbe") { return "native-renderfunc-commandbuffer-dlss-create" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncContextProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-context-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncContextProbe") { return "native-renderfunc-context" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceD3D11Probe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-resource-d3d11-render-scale" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-resource-native-pointer-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceD3D11Probe") { return "native-renderfunc-resource-d3d11" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe") { return "native-renderfunc-resource-native-pointer" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceResolveProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-resource-resolve-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceResolveProbe") { return "native-renderfunc-resource-resolve" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceTupleProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "native-renderfunc-resource-tuple-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceTupleProbe") { return "native-renderfunc-resource-tuple" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceIdentityProbe") { return "native-renderfunc-resource-identity" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncArgumentProbe") { return "native-renderfunc-args" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncEntryProbe") { return "native-renderfunc-entry" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "hdrp-postprocess-render-args-global-textures-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe") { return "hdrp-postprocess-render-args-global-textures" }
    if ((Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessRenderArgsProbe") -and
        (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe")) { return "hdrp-postprocess-render-args-render-scale" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessRenderArgsProbe") { return "hdrp-postprocess-render-args" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHdrpPostProcessBoundaryProbe") { return "hdrp-postprocess-boundary" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableCustomPostProcessRenderEntryProbe") { return "custom-postprocess-render-entry" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableCustomPostProcessRegistrationProbe") { return "custom-postprocess-registration" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssFeatureCreateProbe") { return "dlss-feature-create" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssOptimalSettingsProbe") { return "dlss-optimal-settings" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssInitQueryProbe") { return "dlss-init-query" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssRuntimeProbe") { return "dlss-runtime" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableFrameResourceProbe") { return "frame-resource" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderScaleControlProbe") { return "render-scale-control" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableUpscalerStateProbe") { return "upscaler-state" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHarmonyCallProbe") { return "harmony-call" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableD3D11TextureProbe") { return "d3d11" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderThreadSmokeTest") { return "render-thread" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeBridgeSmokeTest") { return "native" }
    return "loader"
}

function Get-FirstStageStatus {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Results,

        [Parameter(Mandatory = $true)]
        [string]$StagePrefix
    )

    $match = $Results | Where-Object { $_.Stage -like "$StagePrefix*" } | Select-Object -First 1
    if ($match) {
        return $match.Status
    }

    return "Missing"
}

function Get-StatusRank {
    param([string]$Status)

    switch ($Status) {
        "Pass" { return 5 }
        "Fail" { return 4 }
        "Blocked" { return 3 }
        "Partial" { return 2 }
        "Missing" { return 1 }
        default { return 0 }
    }
}

function Add-StageEvidenceSource {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    [pscustomobject]@{
        Stage = $Result.Stage
        Status = $Result.Status
        Evidence = "$($Result.Evidence); Source=$Source"
    }
}

function Read-AnalysisStageResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match "^\s*(?<Stage>.+?)\s+(?<Status>Pass|Fail|Blocked|Partial|Missing)\s+(?<Evidence>.*)$") {
            $stage = $Matches.Stage.Trim()
            if ([string]::IsNullOrWhiteSpace($stage) -or $stage -eq "Stage") {
                continue
            }

            $results.Add([pscustomobject]@{
                Stage = $stage
                Status = $Matches.Status.Trim()
                Evidence = "$($Matches.Evidence.Trim()); Source=$Path"
            })
        }
    }

    return $results.ToArray()
}

function Merge-StageResults {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ResultSets
    )

    $merged = [ordered]@{}
    foreach ($result in $ResultSets) {
        if (-not $result -or [string]::IsNullOrWhiteSpace([string]$result.Stage)) {
            continue
        }

        $key = [string]$result.Stage
        if (-not $merged.Contains($key)) {
            $merged[$key] = $result
            continue
        }

        $existing = $merged[$key]
        if ((Get-StatusRank -Status $result.Status) -gt (Get-StatusRank -Status $existing.Status)) {
            $merged[$key] = $result
        }
    }

    return @($merged.Values)
}

function Get-BlockedUserRenderingVisualRecommendation {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $visualStatusScript = Join-Path $RootPath "scripts\get-visual-validation-status.ps1"
    if (-not (Test-Path -LiteralPath $visualStatusScript -PathType Leaf)) {
        return ""
    }

    try {
        $visualJson = & $visualStatusScript -Root $RootPath -RequiredCandidateStage dlss-user-rendering -Json
        if ([string]::IsNullOrWhiteSpace([string]$visualJson)) {
            return ""
        }

        $visualStatus = $visualJson | ConvertFrom-Json
        $issuesText = @($visualStatus.Issues) -join " | "
        $hasPerformanceRegression = $visualStatus.NextRecommendation -match "Do not rerun the same EASU ctx\.cmd" `
            -or $issuesText -match "Candidate average FPS regressed|Candidate 1% low FPS regressed|Candidate P95 frame time worsened"

        if ($visualStatus.Status -ne "Pass" -and $hasPerformanceRegression -and
            -not [string]::IsNullOrWhiteSpace([string]$visualStatus.NextRecommendation)) {
            return [string]$visualStatus.NextRecommendation
        }
    } catch {
        return ""
    }

    return ""
}

function Get-NextRecommendation {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Inspect,

        [Parameter(Mandatory = $true)]
        [bool]$PluginInstalled,

        [Parameter(Mandatory = $true)]
        [bool]$ConfigExists,

        [Parameter(Mandatory = $true)]
        [object[]]$LogResults,

        [object[]]$CurrentLogResults = @(),

        [string]$CurrentLogText = "",

        [object]$ContractBindGameplayProof = $null
    )

    if (-not $Inspect.GameInstalled) {
        return "Provide a valid -GamePath that contains VRising.exe."
    }

    if (-not $Inspect.BepInExInstalled) {
        return "powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath `"$($Inspect.GamePath)`" -DryRun"
    }

    if (-not $PluginInstalled) {
        return "powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath `"$($Inspect.GamePath)`" -DryRun"
    }

    if (-not $ConfigExists) {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage loader"
    }

    if (-not $Inspect.LogExists) {
        return "Launch the staged local/offline test once, exit after BepInEx starts, then run scripts\analyze-bepinex-log.ps1."
    }

    $loader = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 1"
    if ($loader -ne "Pass") {
        return "Keep Stage loader config, rerun the local/offline test, then inspect BepInEx\LogOutput.log."
    }

    $evaluateInputs = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8A"
    $evaluate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8B"
    $outputFollowup = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8C"
    $persistentEvaluate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8D"
    $superResolutionInputs = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8E"
    $superResolutionEvaluate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8F"
    $superResolutionPersistentEvaluate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8G"
    $superResolutionFrameSequence = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 9A"
    $visibleWriteback = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 10A"
    $userRendering = Get-FirstStageStatus -Results $LogResults -StagePrefix "DLSS User Rendering Candidate"
    $nativeRenderFuncCommandBufferDlssFeatureCreate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer DLSS Feature Create"
    $nativeRenderFuncCommandBufferDlssVisibleWriteback = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer DLSS Visible Write-back"
    $nativeRenderFuncCommandBufferDlssPersistentScratchEvaluate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer DLSS Persistent Scratch Evaluate"
    $nativeRenderFuncCommandBufferDlssScratchEvaluate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer DLSS Scratch Evaluate"
    $nativeRenderFuncCommandBufferFrameDescriptorD3D11 = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer Frame Descriptor D3D11"
    $nativeRenderFuncCommandBufferFrameDescriptor = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer Frame Descriptor"
    $nativeRenderFuncCommandBufferPayload = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer Payload"
    $nativeRenderFuncCommandBufferEvent = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc CommandBuffer Event"
    $nativeRenderFuncContext = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Context"
    $nativeRenderFuncResourceD3D11 = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Resource D3D11"
    $nativeRenderFuncResourceNativePointer = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Resource Native Pointer"
    $hdrpEasuInputOutputCorrelation = Get-FirstStageStatus -Results $LogResults -StagePrefix "HDRP/EASU Input Output Correlation"
    $nativeRenderFuncResourceResolve = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Resource Resolve"
    $nativeRenderFuncResourceTuple = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Resource Tuple"
    $nativeRenderFuncResourceIdentity = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Resource Identity"
    $nativeRenderFuncArgs = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Args"
    $nativeRenderFuncEntry = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Entry"
    $renderScaleControl = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 2C"
    $hdrpPostProcessRenderArgsGlobalTextures = Get-FirstStageStatus -Results $LogResults -StagePrefix "HDRP PostProcess Render Args Global Textures"
    $hdrpPostProcessRenderArgs = Get-FirstStageStatus -Results $LogResults -StagePrefix "HDRP PostProcess Render Args"
    $hdrpPostProcessBoundary = Get-FirstStageStatus -Results $LogResults -StagePrefix "HDRP PostProcess Boundary"
    $hdrpDlssContractBind = Get-FirstStageStatus -Results $LogResults -StagePrefix "HDRP DLSS Contract Bind"
    $currentUserRendering = Get-FirstStageStatus -Results $CurrentLogResults -StagePrefix "DLSS User Rendering Candidate"
    if ($currentUserRendering -eq "Partial" -and
        $CurrentLogText.IndexOf("DLSS super-resolution input probe not accepted", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
        $CurrentLogText.IndexOf("color=1920x1080 output=1920x1080", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        if ($CurrentLogText.IndexOf("Render-scale control member write did not stick", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $CurrentLogText.IndexOf("RTHandles.SetHardwareDynamicResolutionState=true", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            if ($CurrentLogText.IndexOf("_960x540", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                $CurrentLogText.IndexOf("Render-scale control handler request diagnostic", [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                return "The latest gameplay run reached 1920x1080 Windowed gameplay and produced some auxiliary 960x540 dynamic resources, but the DLSS color/depth/motion/output candidate stayed color=1920x1080 output=1920x1080 and no handler/software-fallback readback was logged. Use the current plugin build with the explicit ForceSoftwareFallback/ScalableBufferManager diagnostic; if it is not staged yet, rebuild/stage it, then rerun the same FSR Off proof once."
            }

            if ($CurrentLogText.IndexOf("Render-scale control handler request diagnostic", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                if ($CurrentLogText.IndexOf("Render-scale control software fallback diagnostic", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    if ($CurrentLogText.IndexOf("SoftwareDynamicResIsEnabled=True", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                        $CurrentLogText.IndexOf("GetResolvedScale=", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        return "The latest dlss-user-rendering gameplay log includes the explicit software-fallback diagnostic and proves SoftwareDynamicResIsEnabled=True, but the Super Resolution tuple still was not accepted. Inspect GetResolvedScale and the HDCamera actualWidth/actualHeight lines next; if the scale is 0.5 while CameraColor remains 1920x1080, the next patch should move closer to HDCamera.GetScaledSize/actual-size assignment instead of repeating handler or fallback toggles."
                    }

                    return "The latest dlss-user-rendering gameplay log includes the explicit software-fallback diagnostic but still did not accept an FSR Off Super Resolution tuple. Inspect invokedForceSoftwareFallback, fallbackAfter, SoftwareDynamicResIsEnabled, GetResolvedScale, and ScalableBufferManager fields before choosing the next hook."
                }

                if ($CurrentLogText.IndexOf("invokedSetCurrentCameraRequest=True", [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                    $CurrentLogText.IndexOf("after=True", [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    return "The latest dlss-user-rendering gameplay log proves DynamicResolutionHandler.SetCurrentCameraRequest(true) succeeds and the handler request is true, but CameraColor/output stayed 1920x1080. Use the current plugin build with the explicit ForceSoftwareFallback/ScalableBufferManager diagnostic; if it is not staged yet, rebuild/stage it, then rerun the same 1920x1080 Windowed FSR Off proof once."
                }

                return "The latest dlss-user-rendering gameplay log includes handler-request diagnostics but still did not accept an FSR Off Super Resolution tuple. Inspect the handler before/after/invocation fields; if SetCurrentCameraRequest(true) or m_CurrentCameraRequest=True is proven while CameraColor remains 1920x1080, move to an explicit software-fallback/ScalableBufferManager diagnostic instead of another hardware-DRS rerun."
            }

            return "The latest targeted dlss-user-rendering gameplay log still did not accept an FSR Off Super Resolution tuple after RTHandles.SetHardwareDynamicResolutionState=true. Static/runtime follow-up has already ruled out the direct handler-request gate, so use the current plugin build and rerun the 1920x1080 Windowed FSR Off proof only with the explicit ForceSoftwareFallback/ScalableBufferManager diagnostic."
        }

        return "The latest dlss-user-rendering gameplay log did not accept an FSR Off Super Resolution tuple: the main candidate stayed color=1920x1080 output=1920x1080. Before rerunning the same runtime proof, use the targeted render-scale diagnostic to check for `Render-scale control member write did not stick`, `RTHandles.SetHardwareDynamicResolutionState=true`, and whether the gameplay camera/main targets remain full-size."
    }

    if ($ContractBindGameplayProof -and [string]$ContractBindGameplayProof.Status -eq "Pass") {
        return [string]$ContractBindGameplayProof.NextRecommendation
    }

    if ($hdrpDlssContractBind -eq "Pass") {
        return "Contract-bind gameplay proof is present in current or archived analysis. Next work is evidence-lock matrix B/C/D bounded no-write cost proof: B EASU carrier-only cost, C native D3D11 resource-desc validate-only, and D empty existing command-buffer plugin-event callback under the same 1920x1080 Windowed protected 11111 fixture with environment snapshots. Do not rerun hdrp-dlss-contract-bind-render-scale unchanged and do not attempt visible DLSS write-back until B-G pass."
    }

    if ($userRendering -eq "Pass") {
        $blockedVisualRecommendation = Get-BlockedUserRenderingVisualRecommendation -RootPath $Root
        if (-not [string]::IsNullOrWhiteSpace($blockedVisualRecommendation)) {
            return $blockedVisualRecommendation
        }

        return "DLSS user-rendering candidate passed on the source-guided EASU ctx.cmd command-buffer route. Next engineering step is paired dlss-user-rendering gameplay visual/performance comparison with V Rising FSR Off and -ProtectSave -SaveName 11111, human image-quality review, resize/reset handling, and fallback validation."
    }

    if ($nativeRenderFuncCommandBufferDlssVisibleWriteback -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferDlssVisibleWritebackGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferDlssVisibleWritebackGameplayDoc) {
            return "Native EASU ctx.cmd DLSS visible write-back and render-scale control have a protected gameplay proof: the same source-guided frame sequence reaches the target visible-output successes and then shuts down. Next step is the normal-user dlss-user-rendering visual/performance comparison with -ProtectSave -SaveName 11111 before MVP promotion. Latest proof: $($nativeRenderFuncCommandBufferDlssVisibleWritebackGameplayDoc.FullName)"
        }

        return "Native EASU ctx.cmd DLSS visible write-back passed with render-scale evidence. Next step is normal-user dlss-user-rendering visual/performance comparison with -ProtectSave -SaveName 11111 before MVP promotion."
    }

    if ($nativeRenderFuncCommandBufferFrameDescriptorD3D11 -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferFrameDescriptorD3D11GameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferFrameDescriptorD3D11GameplayDoc) {
            return "Native EASU ctx.cmd frame-descriptor D3D11 validation now proves source/output/depth/motion are same-device D3D11 textures with source/depth/motion at render input size and output at final size, without NGX, evaluate, or visible write-back. Next source-guided guard can be a bounded SDK-wrapper-only no-write DLSS frame-sequence evaluate at this same callback. Latest proof: $($nativeRenderFuncCommandBufferFrameDescriptorD3D11GameplayDoc.FullName)"
        }

        return "Native frame-descriptor D3D11 validation passed with render-scale evidence. Next step should be a protected gameplay proof document, then a separate bounded no-write evaluate preflight at the same callback; do not add visible write-back yet."
    }

    if ($nativeRenderFuncCommandBufferDlssVisibleWriteback -eq "Blocked" -or $nativeRenderFuncCommandBufferDlssVisibleWriteback -eq "Fail" -or $nativeRenderFuncCommandBufferDlssVisibleWriteback -eq "Partial") {
        return "Native visible DLSS write-back at the focused EASU ctx.cmd boundary has not passed. Inspect visible write-back set/issue/consume counts, sequenceCreates, sequenceEvaluates, evaluateSuccesses, shutdown pending/completed, image artifacts, SDK-wrapper/runtime path, and stale target refresh before changing normal-user rendering."
    }

    if ($nativeRenderFuncCommandBufferDlssPersistentScratchEvaluate -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferDlssPersistentScratchEvaluateGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferDlssPersistentScratchEvaluateGameplayDoc) {
            return "Native EASU ctx.cmd DLSS persistent scratch evaluate and render-scale control have a protected gameplay proof: the same frame-sequence feature reaches the target scratch successes across callbacks without touching the visible EASU output. Next source-guided guard can move from scratch-output lifecycle proof to a separately gated visible write-back timing/quality proof, still default-off. Latest proof: $($nativeRenderFuncCommandBufferDlssPersistentScratchEvaluateGameplayDoc.FullName)"
        }

        return "Native EASU ctx.cmd DLSS persistent scratch evaluate passed with render-scale evidence. Next step should be a protected gameplay proof document before any visible write-back or normal-user rendering change."
    }

    if ($nativeRenderFuncCommandBufferDlssPersistentScratchEvaluate -eq "Blocked" -or $nativeRenderFuncCommandBufferDlssPersistentScratchEvaluate -eq "Fail" -or $nativeRenderFuncCommandBufferDlssPersistentScratchEvaluate -eq "Partial") {
        return "Native persistent DLSS scratch evaluate at the focused EASU ctx.cmd boundary has not passed. Inspect set/issue/consume counts, sequenceCreates, recreated yes/no, shutdown pending/completed, SDK-wrapper/runtime path, and frame descriptor dimensions before trying visible write-back."
    }

    if ($nativeRenderFuncCommandBufferDlssScratchEvaluate -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferDlssScratchEvaluateGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferDlssScratchEvaluateGameplayDoc) {
            return "Native EASU ctx.cmd DLSS scratch evaluate and render-scale control have a protected gameplay proof: the four-resource descriptor can evaluate into a native scratch output without touching the visible EASU output. Next source-guided guard should prove persistent feature reuse at the same boundary before any visible write-back or normal-user rendering change. Latest proof: $($nativeRenderFuncCommandBufferDlssScratchEvaluateGameplayDoc.FullName)"
        }

        return "Native EASU ctx.cmd DLSS scratch evaluate passed with render-scale evidence. Next step should be a protected gameplay proof document, then a separate persistent scratch feature-reuse guard before any visible write-back."
    }

    if ($nativeRenderFuncCommandBufferDlssScratchEvaluate -eq "Blocked" -or $nativeRenderFuncCommandBufferDlssScratchEvaluate -eq "Fail" -or $nativeRenderFuncCommandBufferDlssScratchEvaluate -eq "Partial") {
        return "Native DLSS scratch evaluate at the focused EASU ctx.cmd boundary has not passed. Inspect scratch-output creation, SDK-wrapper/runtime path, evaluate/shutdown status, and the frame descriptor dimensions before trying visible write-back or normal-user rendering again."
    }

    if ($nativeRenderFuncCommandBufferFrameDescriptorD3D11 -eq "Partial") {
        return "Native frame-descriptor D3D11 validation started but did not prove set/issue/consume. Inspect D3D11 status lines, validation failure text, frame deltas, and whether source/depth/motion/output dimensions match before adding any NGX or evaluate work."
    }

    if ($nativeRenderFuncCommandBufferFrameDescriptor -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferFrameDescriptorGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferFrameDescriptorGameplayDoc) {
            return "Native EASU ctx.cmd frame-descriptor payload now carries EASU source/output plus HDRP depth/motion pointers in a combined protected gameplay proof without D3D11 validation, NGX, evaluate, or visible write-back. Next source-guided guard can decide between validating this four-texture tuple with a separately gated D3D11/SR input check or wiring it into a bounded no-write DLSS frame-sequence evaluate preflight. Latest proof: $($nativeRenderFuncCommandBufferFrameDescriptorGameplayDoc.FullName)"
        }

        return "Native EASU ctx.cmd frame-descriptor payload carries EASU source/output plus HDRP depth/motion pointers with render-scale evidence. Next step should be a protected 1920x1080 gameplay proof document, then a separate guard for either D3D11/SR input validation or bounded no-write evaluate."
    }

    if ($nativeRenderFuncCommandBufferFrameDescriptor -eq "Partial") {
        return "Native frame-descriptor payload started but did not prove set/issue/consume. Inspect frame descriptor status lines, HDRP/EASU frame deltas, and whether descriptor status reports D3D11-not-queried/ngx=not-loaded/evaluate=not-run before moving to any validation/evaluate step."
    }

    if ($hdrpEasuInputOutputCorrelation -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $hdrpEasuCorrelationGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "hdrp-easu-input-output-correlation-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($hdrpEasuCorrelationGameplayDoc) {
            return "HDRP DarkForeground low-resolution color/depth/motion input and focused EASU low-resolution source/full-size output native-pointer observations now have a combined protected gameplay correlation proof. Next separate guard can build a no-evaluate native payload descriptor that carries EASU color/output plus HDRP depth/motion pointers toward the proven ctx.cmd boundary; still do not combine D3D11 validation, NGX feature lifecycle, or DLSS evaluate in the same step. Latest proof: $($hdrpEasuCorrelationGameplayDoc.FullName)"
        }

        return "HDRP/EASU input-output correlation has runtime evidence. Next separate guard can build a no-evaluate native payload descriptor that carries EASU color/output plus HDRP depth/motion pointers toward the proven ctx.cmd boundary; still do not combine D3D11 validation, NGX feature lifecycle, or DLSS evaluate in the same step."
    }

    if ($hdrpEasuInputOutputCorrelation -eq "Partial") {
        return "HDRP/EASU input-output correlation started but did not prove aligned low-resolution HDRP color/depth/motion plus full-size EASU output in the same run. Inspect `HDRP/EASU input-output correlation status #` lines, frame deltas, and whether DarkForeground depth/motion reached the EASU input dimensions before moving to a native payload descriptor."
    }

    if ($hdrpPostProcessRenderArgsGlobalTextures -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $hdrpPostProcessRenderArgsGlobalTexturesRenderScaleGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "hdrp-postprocess-render-args-global-textures-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($hdrpPostProcessRenderArgsGlobalTexturesRenderScaleGameplayDoc) {
            return "HDRP DarkForeground.Render managed source/destination snapshots, global depth/motion texture native pointers, and render-scale control now have a combined protected gameplay proof. Next separate guard should correlate this low-resolution color/depth/motion boundary with the proven full-size EASU output/native command-buffer boundary, without broad GetTexture discovery, D3D11 validation, command-buffer work, or DLSS evaluate in the same step. Latest proof: $($hdrpPostProcessRenderArgsGlobalTexturesRenderScaleGameplayDoc.FullName)"
        }

        return "HDRP DarkForeground.Render managed source/destination snapshots, global depth/motion texture native pointers, and render-scale control now have runtime evidence. Next separate guard should correlate this low-resolution color/depth/motion boundary with the proven full-size EASU output/native command-buffer boundary, without broad GetTexture discovery, D3D11 validation, command-buffer work, or DLSS evaluate in the same step."
    }

    if ($hdrpPostProcessRenderArgsGlobalTextures -eq "Pass") {
        return "HDRP DarkForeground.Render global depth/motion texture native pointers have runtime evidence. Next narrow run should combine this stage with render-scale control, then compare source/depth/motion sizes against the proven EASU full-size output boundary; still no broad GetTexture discovery, command-buffer work, D3D11 validation, NGX, or DLSS evaluate."
    }

    if ($hdrpPostProcessRenderArgsGlobalTextures -eq "Partial") {
        return "HDRP postprocess global-texture probe started but did not prove both _CameraDepthTexture and _CameraMotionVectorsTexture native pointers. If this was menu-only, run a protected 11111 gameplay proof at 1920x1080 Windowed; if gameplay was reached, inspect whether motion vectors are disabled or not yet bound at DarkForeground.Render."
    }

    if ($nativeRenderFuncCommandBufferDlssFeatureCreate -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferDlssFeatureCreateGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-dlss-create-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferDlssFeatureCreateGameplayDoc) {
            return "Native EASU ctx.cmd DLSS feature-create lifecycle and render-scale control have a combined protected gameplay proof. Next source-guided guard should add the missing depth/motion-vector payloads or design a bounded no-write evaluate preflight at this callback boundary; still avoid broad GetTexture discovery and direct DLSSPass.Render patching. Latest proof: $($nativeRenderFuncCommandBufferDlssFeatureCreateGameplayDoc.FullName)"
        }

        return "Native EASU ctx.cmd DLSS feature-create lifecycle and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-commandbuffer-dlss-create-render-scale with -UseSdkWrapperNative and -DlssRuntimePath; expected evidence is create=0x00000001, feature=yes, release/destroy/shutdown success, no ExecuteDLSS, no visible write-back, and save restore."
    }

    if ($nativeRenderFuncCommandBufferPayload -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferPayloadGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-payload-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferPayloadGameplayDoc) {
            return "Native EASU ctx.cmd texture-payload consume and render-scale control have a combined protected gameplay proof. Next source-guided guard can evaluate whether this exact callback lifecycle can carry the DLSS frame-sequence create/evaluate state, still behind SDK-wrapper/local gates and without broad GetTexture discovery. Latest proof: $($nativeRenderFuncCommandBufferPayloadGameplayDoc.FullName)"
        }

        return "Native EASU ctx.cmd texture-payload consume and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-commandbuffer-payload-render-scale; expected evidence is payload set, event issue, native consumed count advancing, same-device 960x540 -> 1920x1080 status, and no NGX/DLSS/evaluate/visible write-back."
    }

    if ($nativeRenderFuncCommandBufferEvent -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncCommandBufferEventGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-commandbuffer-event-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncCommandBufferEventGameplayDoc) {
            return "Native EASU ctx.cmd no-op plugin event and render-scale control have a combined protected gameplay proof. Next source-guided guard can design a separately gated native callback payload/lifecycle proof at this same boundary, still without DLSS evaluate or visible write-back in the same step. Latest proof: $($nativeRenderFuncCommandBufferEventGameplayDoc.FullName)"
        }

        return "Native EASU ctx.cmd no-op plugin event and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-commandbuffer-event-render-scale; expected evidence is the native render event callback count advancing while GetTexture/native pointer/D3D11/DLSS/evaluate stay zero."
    }

    if ($nativeRenderFuncContext -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncContextRenderScaleGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-context-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncContextRenderScaleGameplayDoc) {
            return "Native EASU RenderGraphContext/CommandBuffer identity and render-scale control have a combined protected gameplay proof. Next source-guided guard can investigate a no-op command-buffer/plugin-event timing proof at this exact EASU render-func boundary, but still do not combine DLSS evaluate in the same step. Latest proof: $($nativeRenderFuncContextRenderScaleGameplayDoc.FullName)"
        }

        return "Native EASU RenderGraphContext/CommandBuffer identity and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-context-render-scale; expected evidence is cmdPointerNonZero>0 while GetTexture/native pointer/D3D11/DLSS/evaluate stay zero."
    }

    if ($nativeRenderFuncResourceD3D11 -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncResourceD3D11RenderScaleGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-resource-d3d11-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceD3D11RenderScaleGameplayDoc) {
            return "Native EASU source/destination D3D11 pair validation and render-scale control have a combined protected gameplay proof. Next source-guided guard can investigate command-buffer/RenderGraphContext timing at the EASU render func boundary, but still do not combine DLSS evaluate in the same step. Latest proof: $($nativeRenderFuncResourceD3D11RenderScaleGameplayDoc.FullName)"
        }

        return "Native EASU D3D11 pair validation and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-d3d11-render-scale; expected evidence is a sameDevice=yes D3D11 texture pair with source=960x540 and destination=1920x1080 while command-buffer/DLSS/evaluate stay zero."
    }

    if ($nativeRenderFuncResourceNativePointer -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncResourceNativePointerRenderScaleGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-resource-native-pointer-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceNativePointerRenderScaleGameplayDoc) {
            return "Native EASU source/destination native pointers and render-scale control have a combined protected gameplay proof, and source/decompilation kickoff is recorded. Next separate guard is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-d3d11-render-scale to validate same-device D3D11 pair properties and dimensions; still do not combine command-buffer access or DLSS evaluate in the same step. Latest proof: $($nativeRenderFuncResourceNativePointerRenderScaleGameplayDoc.FullName)"
        }

        return "Native EASU native-pointer observation and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-native-pointer-render-scale; expected evidence is EASU tuple=input=960x540 output=1920x1080 plus non-zero source/destination nativePtr values while D3D11/DLSS/evaluate stay zero."
    }

    if ($nativeRenderFuncResourceResolve -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncResourceResolveRenderScaleGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-resource-resolve-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceResolveRenderScaleGameplayDoc) {
            return "Native EASU TextureResource metadata resolve and render-scale control have a combined protected gameplay proof. Next separate guard can move to focused EASU source/destination native-pointer observation under render scale, still without command-buffer access, D3D11 validation, or DLSS evaluate in the same step. Latest proof: $($nativeRenderFuncResourceResolveRenderScaleGameplayDoc.FullName)"
        }

        return "Native EASU resource resolve and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-resolve-render-scale; expected evidence is EASU tuple=input=960x540 output=1920x1080 plus TextureResource metadata for source/destination while GetTexture/native pointer/D3D11/DLSS/evaluate stay zero."
    }

    if ($nativeRenderFuncResourceTuple -eq "Pass" -and $renderScaleControl -eq "Pass") {
        $nativeRenderFuncResourceTupleRenderScaleGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-resource-tuple-render-scale-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceTupleRenderScaleGameplayDoc) {
            return "Native EASU tuple metadata and render-scale control have a combined protected gameplay proof. Inspect the latest EASU tuple: if it is input=960x540 output=1920x1080, the next separate guard can target focused EASU source/destination resource resolution or native-pointer observation; if it remains same-sized, compare EASU timing against the DarkForeground scaled postprocess boundary. Still no broad GetTexture loop, command-buffer access, native texture dereference, or DLSS evaluate without another explicit preflight. Latest proof: $($nativeRenderFuncResourceTupleRenderScaleGameplayDoc.FullName)"
        }

        return "Native render-func tuple and render-scale control both have runtime evidence, but not yet in the same protected gameplay proof. Next step is a 1920x1080 Windowed protected 11111 run using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-tuple-render-scale; expected evidence is whether EASU reports input=960x540 output=1920x1080 while GetTexture/DLSS/evaluate stay zero."
    }

    if ($hdrpPostProcessRenderArgs -eq "Pass" -and $renderScaleControl -eq "Pass") {
        return "HDRP postprocess render-argument snapshots and render-scale control both have runtime evidence. Inspect the latest DarkForeground source/destination summaries next: if both are scaled, this boundary is useful for low-resolution color input but still needs a separate full-size output boundary; if source is scaled and destination is full-size, the next separate guard can move toward native pointer preflight at this boundary; if both stay full-size, compare snapshot timing against DynamicResolutionHandler.Update and Stage 8E's accepted tuple timing. Still no GetTexture loop, D3D11 validation, native texture dereference, or DLSS evaluate without another explicit preflight."
    }

    if ($hdrpPostProcessRenderArgs -eq "Pass") {
        return "HDRP postprocess render-argument snapshot has runtime evidence. Inspect the latest source/destination RTHandle and texture summaries to decide whether this ProjectM custom postprocess boundary is close enough to the official HDRP DLSS evaluate boundary for the next separate guard. Still no command-buffer work, GetTexture loop, D3D11 validation, native texture dereference, or DLSS evaluate without another explicit preflight."
    }

    if ($hdrpPostProcessRenderArgs -eq "Partial") {
        return "HDRP postprocess render-argument probe patched DarkForeground.Render but did not observe a snapshot in available logs. If this was menu-only, run a protected 11111 gameplay proof at 1920x1080 Windowed before rejecting the boundary; keep it no-native/no-DLSS and do not send movement keys."
    }

    if ($hdrpPostProcessBoundary -eq "Pass") {
        return "HDRP postprocess boundary probe has protected gameplay runtime evidence. Next separate guard is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage hdrp-postprocess-render-args -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a no-native source/destination RTHandle snapshot; still no command-buffer work, GetTexture loop, D3D11 validation, native texture dereference, or DLSS evaluate."
    }

    if ($hdrpPostProcessBoundary -eq "Partial") {
        return "HDRP postprocess boundary probe patched methods but did not observe a boundary call in available logs. If this was menu-only, run a protected 11111 gameplay proof at 1920x1080 Windowed before rejecting the boundary; keep it no-native/no-DLSS and do not send movement keys."
    }

    if ($nativeRenderFuncResourceNativePointer -eq "Pass") {
        $nativeRenderFuncResourceNativePointerGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-resource-native-pointer-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceNativePointerGameplayDoc) {
            $hdrpPostProcessBoundaryImplementationDoc = Join-Path $Root "docs\development\hdrp-postprocess-boundary-preflight-implementation-2026-06-07.md"
            if (Test-Path -LiteralPath $hdrpPostProcessBoundaryImplementationDoc) {
                return "Native render-func resource native-pointer menu and protected 11111 gameplay proofs passed, and the default-off HDRP postprocess boundary probe is implemented. Next step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage hdrp-postprocess-boundary -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a 1920x1080 Windowed menu-only proof; no native bridge, no GetTexture, no command-buffer work, and no DLSS evaluate."
            }

            return "Native render-func resource native-pointer menu and protected 11111 gameplay proofs passed. Next engineering step is implementing a default-off no-native HDRP postprocess boundary probe over RenderPostProcess/DoDLSSPass/CustomPostProcessPass and concrete ProjectM custom postprocess Render methods; do not combine command-buffer access or DLSS evaluate without another explicit guard. Latest proof: $($nativeRenderFuncResourceNativePointerGameplayDoc.FullName)"
        }

        return "Native render-func resource native-pointer menu preflight passed in available logs. Next step is a protected 11111 gameplay proof at 1920x1080 Windowed using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-native-pointer; no movement keys, no command-buffer access, no D3D11 validation, and no DLSS evaluate."
    }

    if ($nativeRenderFuncResourceResolve -eq "Pass") {
        $nativeRenderFuncResourceResolveGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-resource-resolve-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceResolveGameplayDoc) {
            $nativeRenderFuncResourceNativePointerImplementationDoc = Join-Path $Root "docs\development\native-renderfunc-resource-native-pointer-preflight-implementation-2026-06-07.md"
            if (Test-Path -LiteralPath $nativeRenderFuncResourceNativePointerImplementationDoc) {
                return "Native render-func resource resolve menu and protected 11111 gameplay proofs passed, and the default-off native-pointer preflight is implemented. Next step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native-renderfunc-resource-native-pointer -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a 1920x1080 Windowed menu-only proof; no command-buffer access, no D3D11 validation, and no DLSS evaluate."
            }

            return "Native render-func resource resolve menu and protected 11111 gameplay proofs passed. Next engineering step is deciding whether to move from TextureResource/graphicsResource metadata to a separately guarded actual native texture-pointer preflight; still no command-buffer access or DLSS evaluate without another explicit preflight. Latest proof: $($nativeRenderFuncResourceResolveGameplayDoc.FullName)"
        }

        return "Native render-func resource resolve menu preflight passed in available logs. Next step is a protected 11111 gameplay proof at 1920x1080 Windowed using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-resolve; no GetTexture, native texture pointer reads, command-buffer access, or DLSS evaluate."
    }

    if ($nativeRenderFuncResourceTuple -eq "Pass") {
        $nativeRenderFuncResourceTupleGameplayDoc = Get-ChildItem -LiteralPath (Join-Path $Root "docs\development") -Filter "native-renderfunc-resource-tuple-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceTupleGameplayDoc) {
            $nativeRenderFuncResourceResolveImplementationDoc = Join-Path $Root "docs\development\native-renderfunc-resource-resolve-preflight-implementation-2026-06-07.md"
            if (Test-Path -LiteralPath $nativeRenderFuncResourceResolveImplementationDoc) {
                return "Native render-func resource tuple menu and protected 11111 gameplay proofs passed, and the default-off resource-resolve preflight is implemented. Next step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native-renderfunc-resource-resolve -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a 1920x1080 Windowed menu-only proof; no GetTexture, native texture pointer reads, command-buffer access, or DLSS evaluate."
            }

            return "Native render-func resource tuple menu and protected 11111 gameplay proofs passed. Next engineering step is deciding the first separately guarded resource-resolution preflight; still no command-buffer access or DLSS evaluate without another explicit preflight. Latest proof: $($nativeRenderFuncResourceTupleGameplayDoc.FullName)"
        }

        return "Native render-func resource tuple menu preflight passed in available logs, but no protected gameplay result document was found. Next step is a protected 11111 gameplay proof at 1920x1080 Windowed using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-tuple; no GetTexture, command-buffer access, texture resolution, or DLSS evaluate."
    }

    if ($nativeRenderFuncResourceIdentity -eq "Pass") {
        $developmentDocRoot = Join-Path $Root "docs\development"
        $nativeRenderFuncResourceIdentityGameplayDoc = Get-ChildItem -LiteralPath $developmentDocRoot -Filter "native-renderfunc-resource-identity-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceIdentityGameplayDoc) {
            $nativeRenderFuncResourceTupleImplementationDoc = Join-Path $Root "docs\development\native-renderfunc-resource-tuple-preflight-implementation-2026-06-07.md"
            $nativeRenderFuncResourceTupleRuntimeDoc = Join-Path $Root "docs\development\native-renderfunc-resource-tuple-runtime-result-2026-06-07.md"
            $nativeRenderFuncResourceTupleGameplayDoc = Join-Path $Root "docs\development\native-renderfunc-resource-tuple-gameplay-result-2026-06-07.md"
            if (Test-Path -LiteralPath $nativeRenderFuncResourceTupleGameplayDoc) {
                $nativeRenderFuncResourceResolveImplementationDoc = Join-Path $Root "docs\development\native-renderfunc-resource-resolve-preflight-implementation-2026-06-07.md"
                if (Test-Path -LiteralPath $nativeRenderFuncResourceResolveImplementationDoc) {
                    return "Native render-func resource identity and tuple menu/protected gameplay proofs passed, and the default-off resource-resolve preflight is implemented. Next step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native-renderfunc-resource-resolve -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a 1920x1080 Windowed menu-only proof; no GetTexture, native texture pointer reads, command-buffer access, or DLSS evaluate."
                }

                return "Native render-func resource identity menu/protected gameplay proofs passed, and native-renderfunc-resource-tuple menu/protected gameplay proofs passed. Next engineering step is deciding the first separately guarded resource-resolution preflight; still no command-buffer access or DLSS evaluate without another explicit preflight. Latest proof: $nativeRenderFuncResourceTupleGameplayDoc"
            }

            if (Test-Path -LiteralPath $nativeRenderFuncResourceTupleRuntimeDoc) {
                return "Native render-func resource identity menu/protected gameplay proofs passed, and native-renderfunc-resource-tuple menu proof passed, but no protected gameplay result document was found. Next step is protected 11111 gameplay proof at 1920x1080 Windowed using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-tuple, with save backup/restore, no movement keys, and still no GetTexture, command-buffer access, texture resolution, or DLSS evaluate."
            }

            if (Test-Path -LiteralPath $nativeRenderFuncResourceTupleImplementationDoc) {
                return "Native render-func resource identity menu and protected 11111 gameplay proofs passed, and the default-off resource-tuple preflight is implemented. Next step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native-renderfunc-resource-tuple -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a 1920x1080 Windowed menu-only tuple proof; no GetTexture, command-buffer access, texture resolution, or DLSS evaluate."
            }

            return "Native render-func resource identity menu and protected 11111 gameplay proofs passed. Next engineering step is deciding whether the proven managed EASU pass-data/TextureHandle identity can support a safe official-boundary-adjacent resource path; still do not add command-buffer access or DLSS evaluate without a separate preflight. Latest proof: $($nativeRenderFuncResourceIdentityGameplayDoc.FullName)"
        }

        return "Native render-func resource identity menu preflight passed in available logs. Next step is a protected 11111 gameplay proof at 1920x1080 Windowed using scripts\start-vrising-automation-session.ps1 -Stage native-renderfunc-resource-identity; no native-callback pointer dereference, command-buffer access, or DLSS evaluate."
    }

    if ($nativeRenderFuncArgs -eq "Pass") {
        $nativeRenderFuncResourceIdentityImplementationDoc = Join-Path $Root "docs\development\native-renderfunc-resource-identity-preflight-implementation-2026-06-06.md"
        $nativeRenderFuncArgsGameplayDoc = Join-Path $Root "docs\development\native-renderfunc-args-gameplay-result-2026-06-06.md"
        if (Test-Path -LiteralPath $nativeRenderFuncArgsGameplayDoc) {
            if (Test-Path -LiteralPath $nativeRenderFuncResourceIdentityImplementationDoc) {
                return "Native render-func argument menu and protected 11111 gameplay proofs passed, and the default-off resource-identity preflight is implemented. Next step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native-renderfunc-resource-identity -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a 1920x1080 Windowed menu-only proof; no native-callback pointer dereference, command-buffer access, or DLSS evaluate."
            }

            return "Native render-func argument menu and protected 11111 gameplay proofs passed. Next engineering step is a separately designed, default-off resource-identity preflight from the raw argument evidence; no native-callback pointer dereference, command-buffer access, or DLSS evaluate yet."
        }

        return "Native render-func argument menu preflight passed in available logs. If the protected 11111 gameplay proof is not documented yet, run native-renderfunc-args through the save-protected gameplay protocol next; only after menu and protected gameplay safety are both documented should a separate resource-identity preflight be designed. No pointer dereference, command-buffer access, or DLSS evaluate yet."
    }

    if ($nativeRenderFuncEntry -eq "Pass") {
        return "Native render-func entry menu and protected 11111 gameplay proofs passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native-renderfunc-args -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 for a 1920x1080 Windowed menu-only argument preflight; no pointer dereference, command-buffer access, or DLSS evaluate."
    }

    if ($userRendering -eq "Pass") {
        $blockedVisualRecommendation = Get-BlockedUserRenderingVisualRecommendation -RootPath $Root
        if (-not [string]::IsNullOrWhiteSpace($blockedVisualRecommendation)) {
            return $blockedVisualRecommendation
        }

        return "DLSS user-rendering candidate passed. Next engineering step is a paired dlss-user-rendering gameplay visual/performance comparison with -ProtectSave -SaveName 11111, human image-quality review, resize/reset handling, and fallback validation."
    }

    if ($visibleWriteback -eq "Pass") {
        return "Stage 10A visible write-back candidate passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-user-rendering with the local SDK-wrapper native build, then paired gameplay visual/performance validation."
    }

    if ($persistentEvaluate -eq "Pass") {
        if ($superResolutionInputs -eq "Pass" -and $superResolutionEvaluate -eq "Pass" -and $superResolutionPersistentEvaluate -eq "Pass" -and $superResolutionFrameSequence -eq "Pass" -and $visibleWriteback -eq "Pass") {
            return "Stage 10A visible write-back candidate passed after Stage 8D/8E/8F/8G/9A evidence. Next engineering step is image-correctness validation, screenshot/visual comparison, resize/reset handling, and fallback behavior in local/private gameplay."
        }

        if ($superResolutionInputs -eq "Pass" -and $superResolutionEvaluate -eq "Pass" -and $superResolutionPersistentEvaluate -eq "Pass" -and $superResolutionFrameSequence -eq "Pass") {
            return "Stage 8D persistent DLSS evaluate, Stage 8E Super Resolution input sizing, Stage 8F Super Resolution evaluate, Stage 8G Super Resolution persistent evaluate, and Stage 9A frame-sequence evaluate passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-visible-writeback with the local SDK-wrapper native build, then image-correctness validation."
        }

        if ($superResolutionInputs -eq "Pass" -and $superResolutionEvaluate -eq "Pass" -and $superResolutionPersistentEvaluate -eq "Pass") {
            return "Stage 8D persistent DLSS evaluate, Stage 8E Super Resolution input sizing, Stage 8F Super Resolution evaluate, and Stage 8G Super Resolution persistent evaluate passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-super-resolution-frame-sequence with the local SDK-wrapper native build, then guarded visible write-back."
        }

        if ($superResolutionInputs -eq "Pass" -and $superResolutionEvaluate -eq "Pass") {
            return "Stage 8D persistent DLSS evaluate, Stage 8E Super Resolution input sizing, and Stage 8F Super Resolution evaluate passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-super-resolution-persistent-evaluate with the local SDK-wrapper native build, then guarded visible write-back."
        }

        if ($superResolutionInputs -eq "Pass") {
            return "Stage 8D persistent DLSS evaluate and Stage 8E Super Resolution input sizing passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-super-resolution-evaluate with the local SDK-wrapper native build, then Stage 8G Super Resolution persistent evaluate."
        }

        return "Stage 8D persistent DLSS evaluate passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-super-resolution-inputs to prove a render-input-smaller-than-output tuple, then guarded visible write-back."
    }

    if ($persistentEvaluate -eq "Blocked") {
        return "Stage 8D is blocked until the native bridge is built with the optional NVIDIA SDK wrapper path and DLSS.DlssRuntimePath points to a local research runtime."
    }

    if ($persistentEvaluate -eq "Fail") {
        return "Stage 8D persistent evaluate reached the native path but failed. Preserve the persistent evaluate status line and inspect repeated evaluate/create lifecycle behavior."
    }

    if ($evaluate -eq "Pass") {
        if ($outputFollowup -eq "Pass") {
            if ($persistentEvaluate -eq "Pass") {
                return "Stage 8B/8C/8D passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-inputs to prove Super Resolution sizing, then scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-evaluate."
            }

            if ($persistentEvaluate -eq "Fail") {
                return "Stage 8B/8C passed, but Stage 8D persistent evaluate failed. Preserve the persistent status line and inspect repeated evaluate/create lifecycle behavior."
            }

            return "Stage 8B DLSS evaluate and Stage 8C output follow-up passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -Stage dlss-persistent-evaluate with the local SDK-wrapper native build."
        }

        if ($outputFollowup -eq "Fail") {
            return "Stage 8B DLSS evaluate passed, but Stage 8C output follow-up failed. Preserve the follow-up status line and inspect whether the selected output texture remains D3D11-accessible after evaluate."
        }

        return "Stage 8B DLSS evaluate passed. Next engineering step is rerunning scripts\run-vrising-diagnostic.ps1 -Stage dlss-evaluate with the output follow-up probe, then image-correctness validation."
    }

    if ($evaluate -eq "Blocked") {
        return "Stage 8B is blocked until the native bridge is built with the optional NVIDIA SDK wrapper path and DLSS.DlssRuntimePath points to a local research runtime."
    }

    if ($evaluate -eq "Fail") {
        return "Stage 8B reached the native evaluate path but failed. Preserve the DLSS evaluate status line and inspect create/evaluate/result codes, output selection, jitter, and motion-vector assumptions."
    }

    if ($evaluateInputs -eq "Pass") {
        return "Stage 8A evaluate-input probing passed. Next engineering step is scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-evaluate with a local SDK-wrapper native build, DLSS runtime path, and DLSS disabled by default."
    }

    if ($evaluateInputs -eq "Blocked") {
        return "Stage 8A is blocked until color/output/depth/motion native textures are present in the same frame; try scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-evaluate-inputs -DurationSeconds 240 and enter a local/private gameplay scene."
    }

    if ($evaluateInputs -eq "Fail") {
        return "Stage 8A evaluate-input probing reached native validation but failed. Preserve the status line and inspect D3D11 resource/device/dimension mismatch."
    }

    if ($evaluateInputs -eq "Partial") {
        return "Stage 8A started but did not produce pass/blocked/fail evidence. If this was the main menu, run scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-evaluate-inputs -DurationSeconds 240 and enter a local/private gameplay scene, then preserve the archived log."
    }

    $contractBindPreflightDoc = Join-Path $Root "docs\development\hdrp-dlss-contract-bind-render-scale-preflight-2026-06-08.md"
    $contractAnalysisDoc = Join-Path $Root "docs\development\official-dlss-contract-vs-easu-chain-analysis-2026-06-08.md"
    $systematicDecompilationDoc = Join-Path $Root "docs\development\vrising-systematic-local-decompilation-investigation-2026-06-08.md"
    if ((Test-Path -LiteralPath $contractBindPreflightDoc) -and
        (Test-Path -LiteralPath $contractAnalysisDoc) -and
        (Test-Path -LiteralPath $systematicDecompilationDoc)) {
        return "Current repository evidence has moved beyond the early hook-probe ladder. Next normal proof is the protected hdrp-dlss-contract-bind-render-scale gameplay run at true 1920x1080 Windowed: use scripts\start-vrising-automation-session.ps1 -Stage hdrp-dlss-contract-bind-render-scale -ProtectSave -SaveName 11111, click Continue/11111 once through Computer Use, send no movement keys, stop with scripts\stop-vrising-automation-session.ps1, require SaveAfterRestoreChangeCount=0, then analyze with scripts\analyze-hdrp-dlss-schedule-audit.ps1. If Computer Use is unavailable, keep this run deferred rather than falling back to foreground key scripts."
    }

    $hook = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 2"
    if ($hook -ne "Pass") {
        return "Keep Stage loader config until the hook probe finds CustomVignette; review Hook target log lines."
    }

    $upscaler = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 2B"
    if ($upscaler -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage upscaler-state"
    }

    $renderScaleControl = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 2C"
    if ($renderScaleControl -eq "Fail") {
        return "Render-scale control probe failed. Preserve BepInEx\LogOutput.log and inspect the first Render-scale control failure before running DLSS user-rendering with FSR Off."
    }

    if ($renderScaleControl -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage render-scale-control"
    }

    $native = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 4"
    if ($native -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native"
    }

    $renderThread = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5A"
    if ($renderThread -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage render-thread"
    }

    $d3d11 = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5B"
    if ($d3d11 -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage d3d11"
    }

    $frame = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5C"
    if ($frame -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage frame-resource"
    }

    $runtime = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5D"
    if ($runtime -ne "Pass") {
        return "Set DLSS.DlssRuntimePath, then run write-diagnostic-config.ps1 -Stage dlss-runtime."
    }

    $initQuery = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 6"
    if ($initQuery -eq "Blocked") {
        return "Stage 6 is blocked until the native bridge has an explicit NVIDIA SDK wrapper integration path; repeating the same dlss-init-query diagnostic with only nvngx_dlss.dll will not advance it."
    }

    if ($initQuery -ne "Pass") {
        return "Set DLSS.DlssRuntimePath/DlssApplicationId, then run write-diagnostic-config.ps1 -Stage dlss-init-query."
    }

    $optimalSettings = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 6B"
    if ($optimalSettings -eq "Blocked") {
        return "Stage 6B optimal-settings query is blocked until the native bridge is built with the optional NVIDIA SDK wrapper path."
    }

    if ($optimalSettings -ne "Pass") {
        return "Use the optional SDK-wrapper native build, then run write-diagnostic-config.ps1 -Stage dlss-optimal-settings."
    }

    $featureCreate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 7"
    if ($featureCreate -eq "Blocked") {
        return "Stage 7 feature create is blocked until the native bridge is built with the optional NVIDIA SDK wrapper path."
    }

    if ($featureCreate -ne "Pass") {
        return "Use the optional SDK-wrapper native build, then run write-diagnostic-config.ps1 -Stage dlss-feature-create."
    }

    return "Run scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-evaluate-inputs -DurationSeconds 240 in a local/private gameplay scene to prove the real frame resources can enter the native evaluate ABI."
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedArchivedLogRoot = if ([string]::IsNullOrWhiteSpace($ArchivedLogRoot)) {
    Join-Path $resolvedRoot "artifacts\runtime-logs"
} elseif ([System.IO.Path]::IsPathRooted($ArchivedLogRoot)) {
    [System.IO.Path]::GetFullPath($ArchivedLogRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $ArchivedLogRoot))
}
$inspectScript = Join-Path $resolvedRoot "scripts\inspect-vrising-install.ps1"
$analyzeScript = Join-Path $resolvedRoot "scripts\analyze-bepinex-log.ps1"
$contractBindProofScript = Join-Path $resolvedRoot "scripts\get-contract-bind-gameplay-proof.ps1"

$inspectJson = & $inspectScript -GamePath $GamePath -Json
$inspect = $inspectJson | ConvertFrom-Json

$pluginDir = Join-Path $inspect.GamePath "BepInEx\plugins\VrisingDLSS"
$pluginDll = Join-Path $pluginDir "VrisingDLSS.Plugin.dll"
$nativeDll = Join-Path $pluginDir "VrisingDLSS.Native.dll"
$pluginInstalled = (Test-Path -LiteralPath $pluginDll) -and (Test-Path -LiteralPath $nativeDll)

$configPath = Join-Path $inspect.GamePath "BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg"
$configExists = Test-Path -LiteralPath $configPath
$config = Get-ConfigValueMap -Path $configPath
$configuredStage = if ($configExists) { Get-ConfiguredStage -Config $config } else { "missing" }

$effectiveLogPath = if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $inspect.LogPath
} else {
    $LogPath
}
$effectiveLogExists = -not [string]::IsNullOrWhiteSpace($effectiveLogPath) -and (Test-Path -LiteralPath $effectiveLogPath)
$inspect.LogPath = $effectiveLogPath
$inspect.LogExists = $effectiveLogExists

$currentLogResults = @(& $analyzeScript -GamePath $inspect.GamePath -LogPath $effectiveLogPath | ForEach-Object {
        Add-StageEvidenceSource -Result $_ -Source $effectiveLogPath
    })
$currentLogText = if ($effectiveLogExists) {
    Get-Content -LiteralPath $effectiveLogPath -Raw
} else {
    ""
}
$archivedAnalysisCount = 0
$archivedLogResults = @()
if ($IncludeArchivedLogs -and (Test-Path -LiteralPath $resolvedArchivedLogRoot)) {
    $analysisFiles = @(Get-ChildItem -LiteralPath $resolvedArchivedLogRoot -Filter "Analysis-*.txt" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $MaxArchivedAnalysisFiles)

    $archivedAnalysisCount = $analysisFiles.Count
    $archivedLogResultList = New-Object System.Collections.Generic.List[object]
    foreach ($analysisFile in $analysisFiles) {
        foreach ($result in @(Read-AnalysisStageResults -Path $analysisFile.FullName)) {
            if ($result -and -not [string]::IsNullOrWhiteSpace([string]$result.Stage)) {
                $archivedLogResultList.Add($result)
            }
        }
    }

    $archivedLogResults = @($archivedLogResultList.ToArray())
}

$logResults = if ($IncludeArchivedLogs) {
    Merge-StageResults -ResultSets @($currentLogResults + $archivedLogResults)
} else {
    $currentLogResults
}

$contractBindGameplayProof = $null
if (Test-Path -LiteralPath $contractBindProofScript -PathType Leaf) {
    try {
        $contractBindProofJson = & $contractBindProofScript -Root $resolvedRoot -Json
        if (-not [string]::IsNullOrWhiteSpace([string]$contractBindProofJson)) {
            $contractBindGameplayProof = $contractBindProofJson | ConvertFrom-Json
        }
    } catch {
        $contractBindGameplayProof = [pscustomobject]@{
            Status = "Blocked"
            Evidence = "Failed to read contract-bind gameplay proof: $($_.Exception.Message)"
            NextRecommendation = ""
            LaunchesGame = $false
            ModifiesGameFiles = $false
        }
    }
}

$recommendation = Get-NextRecommendation `
    -Inspect $inspect `
    -PluginInstalled $pluginInstalled `
    -ConfigExists $configExists `
    -LogResults $logResults `
    -CurrentLogResults $currentLogResults `
    -CurrentLogText $currentLogText `
    -ContractBindGameplayProof $contractBindGameplayProof

$summary = [pscustomobject]@{
    GamePath = $inspect.GamePath
    GameVersion = $inspect.GameVersion
    BepInExInstalled = $inspect.BepInExInstalled
    PluginInstalled = $pluginInstalled
    ConfigPath = $configPath
    ConfigExists = $configExists
    ConfiguredStage = $configuredStage
    InteropGenerated = $inspect.InteropGenerated
    LogExists = $effectiveLogExists
    LogPath = $effectiveLogPath
    IncludeArchivedLogs = [bool]$IncludeArchivedLogs
    ArchivedLogRoot = $(if ($IncludeArchivedLogs) { $resolvedArchivedLogRoot } else { "" })
    ArchivedAnalysisCount = $(if ($IncludeArchivedLogs) { $archivedAnalysisCount } else { 0 })
    StageResults = $logResults
    ContractBindGameplayProof = $contractBindGameplayProof
    NextRecommendation = $recommendation
    LaunchesGame = $false
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 6
} else {
    $summary
}
