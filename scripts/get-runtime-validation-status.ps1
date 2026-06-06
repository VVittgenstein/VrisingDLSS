param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$LogPath,

    [string]$Root,

    [switch]$IncludeArchivedLogs,

    [string]$ArchivedLogRoot,

    [int]$MaxArchivedAnalysisFiles = 120
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
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassListProbe") { return "rendergraph-pass-list" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassResourceDeclarationProbe") { return "rendergraph-pass-declarations" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassDataSnapshotProbe") { return "rendergraph-pass-data" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe") { return "rendergraph-renderfunc-metadata" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphCompiledPassInfoProbe") { return "rendergraph-compiled-pass-info" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderGraphExecuteDelegateProbe") { return "rendergraph-execute-delegate" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncResourceIdentityProbe") { return "native-renderfunc-resource-identity" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncArgumentProbe") { return "native-renderfunc-args" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeRenderFuncEntryProbe") { return "native-renderfunc-entry" }
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

        [string]$CurrentLogText = ""
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
    $nativeRenderFuncResourceIdentity = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Resource Identity"
    $nativeRenderFuncArgs = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Args"
    $nativeRenderFuncEntry = Get-FirstStageStatus -Results $LogResults -StagePrefix "Native RenderFunc Entry"
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

    if ($nativeRenderFuncResourceIdentity -eq "Pass") {
        $developmentDocRoot = Join-Path $Root "docs\development"
        $nativeRenderFuncResourceIdentityGameplayDoc = Get-ChildItem -LiteralPath $developmentDocRoot -Filter "native-renderfunc-resource-identity-gameplay-result-*.md" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($nativeRenderFuncResourceIdentityGameplayDoc) {
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
        return "DLSS user-rendering candidate passed. Next engineering step is a paired dlss-user-rendering gameplay visual/performance comparison, human image-quality review, resize/reset handling, and fallback validation."
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
$recommendation = Get-NextRecommendation `
    -Inspect $inspect `
    -PluginInstalled $pluginInstalled `
    -ConfigExists $configExists `
    -LogResults $logResults `
    -CurrentLogResults $currentLogResults `
    -CurrentLogText $currentLogText

[pscustomobject]@{
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
    NextRecommendation = $recommendation
    LaunchesGame = $false
}
