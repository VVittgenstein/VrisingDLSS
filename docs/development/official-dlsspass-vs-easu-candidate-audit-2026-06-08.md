# Official HDRP DLSSPass vs EASU Candidate Audit

Status: initial source/decompilation audit after
`api21-paired-user-rendering-1080p-20260608-r1`. Follow-up flag/invert parity
implementation is recorded in
`docs/development/official-hdrp-dlss-flag-invert-parity-2026-06-08.md`.
Fresh V Rising IL2CPP shell evidence is recorded in
`docs/development/vrising-il2cpp-hdrp-dlss-shell-decompilation-2026-06-08.md`.

## Trigger

The API 21 paired run proved that the current command-buffer EASU
user-rendering path reaches sustained NGX DLSS evaluate without the old
`RenderGraph.GetTexture` hot path, but it still fails performance:

| Metric | Baseline | Candidate |
| --- | ---: | ---: |
| Average FPS | 199.704 | 126.358 |
| 1% low FPS | 150.016 | 99.225 |
| P95 frame time | 6.061 ms | 9.088 ms |
| Average GPU utilization | 97.75% | 51.0% |
| Average GPU power | 138.106 W | 86.064 W |

The broader system snapshots did not show another GPU-heavy process stealing the
candidate run. The current signal is therefore not "DLSS failed to run"; it is
"the candidate path runs DLSS but drives the frame in a low-GPU-utilization,
slower shape."

## Inputs

Primary local sources:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- `ref/decompilation-vrising-2026-06-07/ilspy-types/UnityEngine.Rendering.HighDefinition.DLSSPass.cs`
- `ref/decompilation-vrising-2026-06-07/ilspy-types/UnityEngine.Rendering.HighDefinition.HDRenderPipeline_ApplyExposureData.cs`
- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/dump.cs`
- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/il2cpp.h`
- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/script.json`
- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/stringliteral.json`
- `ref/NVIDIA-DLSS-main/include/nvsdk_ngx_defs.h`
- `ref/NVIDIA-DLSS-main/include/nvsdk_ngx_helpers.h`
- `src/VrisingDLSS.Plugin/FrameResourceProbe.cs`
- `src/VrisingDLSS.Plugin/HdrpEasuInputOutputCorrelationProbeState.cs`
- `src/VrisingDLSS.Plugin/HdrpPostProcessRenderArgsProbe.cs`
- `src/VrisingDLSS.Plugin/Plugin.cs`
- `src/VrisingDLSS.Plugin/NativeBridge.cs`
- `src/VrisingDLSS.Native/src/VrisingDlssNative.cpp`

The V Rising IL2CPP files are used as local/private evidence only. Do not copy
proprietary method bodies into the public package.

## Matrix

| Concern | Official HDRP behavior | V Rising local evidence | Current candidate | Gap/risk | Next action |
| --- | --- | --- | --- | --- | --- |
| DLSS pass boundary | `DoDLSSPasses` checks the configured DLSS injection point, creates a `"DLSS Color Mask"` pass, then a `"Deep Learning Super Sampling"` RenderGraph pass. The render func calls `data.pass.Render(..., ctx.cmd)`. | Fresh Il2CppDumper output confirms `DoDLSSPasses`, `DoDLSSPass`, `DLSSData`, the generated `DoDLSSPass` render func, and pass strings are present. However `DLSSPass.Render`, `BeginFrame`, and `SetupDRSScaling` all map to the same empty/no-op address `24240496` / `RVA 0x171E170`. | We patch the EASU render-func boundary and consume a native command-buffer event there. | The EASU boundary is proven stable and visible, but it is later/different than the official DLSS pass. The official pass shell exists, but the NVIDIA execution body appears not compiled in, so simply enabling/calling `DLSSPass.Render` is not a working path. | Keep EASU as current measuring point. Treat official HDRP as the semantic map, not a callable implementation. Any closer official-equivalent experiment must replace/augment the missing body and start as a no-DLSS/no-native pass-boundary proof. |
| Output target | Official writes `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`, then sets `source = viewHandles.output` and marks `AfterDynamicResUpscale`. | `stringliteral.json` contains `"DLSS destination"` and `"Deep Learning Super Sampling"`, and `il2cpp.h` contains the DLSS resource-handle layout. The final `DLSSPass.Render` body still maps to the no-op address. | Candidate writes into the EASU visible destination named `"Edge Adaptive Spatial Upsampling"`. | Correct visible output is proven, but the output is not the official `"DLSS destination"` handle. EASU/final-pass ordering may still impose extra synchronization or leave the pipeline in a less optimal shape. | Probe resource declaration/order around EASU and final pass; prefer an official-equivalent output handle only if it can be created or reached cleanly without relying on the no-op official renderer. |
| Feature create flags | Official Unity sets `IsHDR`, `MVLowRes`, `DepthInverted`, and `DoSharpening` during DLSS feature creation. With current NGX headers those bits are `0x1 | 0x2 | 0x8 | 0x20 = 0x2B`. | No V Rising-specific override has been found; the HDRP `DLSSPass` symbols match the upstream shape. | `Plugin.CreateDlssEvaluateProbeSettings()` currently uses only `AutoExposure` when enabled, producing `flags=0x00000040` in the paired run. | This is the clearest mismatch. It changes NGX feature creation semantics, not just quality. It could affect depth interpretation, motion-vector interpretation, HDR path, and internal scheduling. | First code patch candidate: add a reversible official-HDRP flag mode for user-rendering feature creation. Test `0x2B` first, and treat `AutoExposure` as a separate experiment. |
| Auto exposure vs supplied pre-exposure | Official requests GPU exposure, supplies clamped `preExposure`, and does not set `AutoExposure` in the HDRP source path. | Runtime correlation reads `GpuExposureValue()` and logs `preExposure=1` in the tested scene. | Current feature flags enable `AutoExposure`, while the user-rendering payload also supplies `InPreExposure`. | Supplying pre-exposure while creating an auto-exposure feature may be redundant or contradictory depending on NGX behavior. Even if not a perf root cause, it is not official-equivalent. | When testing official flags, disable `AutoExposure` unless a separate source-backed reason says otherwise. Keep this isolated from other changes. |
| Per-frame jitter, motion-vector scale, pre-exposure | Official uses jitter `(-taaJitter.x, -taaJitter.y)`, `mvScale=(-inputWidth, -inputHeight)`, clamped `preExposure`, render subrect size=input resolution. | `HdrpPostProcessRenderArgsProbe` and correlation logs prove these values are observable locally. | API 21 user-rendering command-buffer payload passes descriptor jitter, mvScale, preExposure, and render subrect dimensions to native; paired logs showed matching non-default jitter/mvScale and `preExposure=1.0000`. | Current user-rendering path is aligned enough for these values. Older direct/non-command-buffer probes still hard-code some values and should not be used as evidence for current user-rendering. | Keep these values. If direct probes remain useful, update or clearly label their hard-coded preExposure/default behavior. |
| Reset/history | Official sets `viewData.reset = parameters.resetHistory`, then `m_Data.reset = isNew || viewData.reset`; every submit passes `reset = m_Data.reset ? 1 : 0`. | Runtime can read `HDCamera.resetPostProcessingHistory`. Tested scene logged `False`. | Command-buffer payload carries `descriptor.ResetHistory`, but native applies reset only when `g_dlssFrameSequence.evaluateCount == 0`. Later camera reset/history is ignored once the sequence has evaluated. | This is a real lifecycle mismatch and could create bad history after camera cuts, teleports, resize, or major scene transitions. It may not explain the steady low-GPU-utilization run, but it is correctness debt. | Patch native reset to apply on new sequence or when payload reset is true. Add a log field distinguishing `requestedReset`, `newSequence`, and `appliedReset`. |
| Feature recreate criteria | Official recreates if output resolution changes, input exceeds current backbuffer, optimal-settings fit changes, perf quality changes, context is null, or automatic-settings mode changes. It destroys old feature before recreate. | IL2CPP exposes camera/pass lifecycle symbols, but bodies are native wrapper calls. | Current native sequence recreates on active/device/input/output/perfQuality/featureFlags/appId/runtime/appData changes. It is global, not per camera/view. | Good for current single-view steady scene, but less official-equivalent for camera changes, XR/view count, optimal settings, or dynamic-res policy. | Keep current criteria for MVP, but add resize/camera-reset proof later. If a closer DLSSPass boundary is found, compare camera identity/view lifecycle. |
| Bias color mask | Official builds a DLSS color mask from depth and passes it as `biasColorMask` when valid. NGX helper maps it to `DLSS.Input.Bias.Current.Color.Mask`. | V Rising exposes `m_DLSSBiasColorMaskMaterial` and `DLSSColorMaskPassData` in IL2CPP. | Candidate does not pass a bias current color mask. | Likely more visual-quality than performance-critical, but it is an official resource gap. | Defer unless visual artifacts appear; keep in matrix for official parity. |
| Invert axes | Official sets `invertYAxis=1`, `invertXAxis=0`. NGX D3D11 helper exposes `InIndicatorInvertYAxis/XAxis`. | No V Rising override found. | Candidate zero-initializes `NVSDK_NGX_D3D11_DLSS_Eval_Params` and does not set the invert-axis fields, so NGX receives `Y=0`, `X=0`. | Clear evaluate-param mismatch. It may affect motion/depth interpretation and quality; performance impact is unknown. | Small patch candidate: set `InIndicatorInvertYAxis=1`, `InIndicatorInvertXAxis=0` in the frame-sequence evaluate path. |
| Sharpness | Official passes camera/custom or DRS sharpness and creates with `DoSharpening`, though current headers mark that flag deprecated. | No local game override found. | Current config uses `Sharpness=0`, feature flags omit `DoSharpening` unless changed. | Probably not the FPS blocker, but official feature creation includes the flag. | Include `DoSharpening` only in the official-flag experiment; keep sharpness value unchanged first. |
| Output subrects and subrect bases | Official uses subrect offset/base 0 and size=input resolution. Current NGX helper also sends subrect base fields when struct is zeroed. | N/A. | Candidate sets render subrect dimensions and relies on zeroed bases. | This is mostly aligned. | No immediate action. |
| Direct probe parity | Official per-frame params are now available from HDRP. | Runtime logs prove availability. | The direct `VrisingDlss_EvaluateDlssFrameSequence` export still hard-codes `preExposure=1.0f`; user-rendering command-buffer payload does not. | Future direct probe results can be misleading if compared against official behavior. | Either add preExposure to the direct bridge or document that direct probes are legacy controls. |
| External/environment drift | Official comparison does not apply. | Same protected save restored to `ChangeCount=0`; baseline returned to `~200 FPS`. | System snapshots added process/GPU/CPU/temperature/power context. | The earlier `156 FPS` baseline was likely not save-state drift. Candidate performance loss remains real. | Keep wide system snapshots for paired runs. Treat low candidate GPU util/power as a key symptom. |

## Current Conclusion

The fresh 2026-06-08 Il2CppDumper pass changes the practical conclusion:
V Rising contains the HDRP DLSS pass shell and resource layout, but the methods
that should submit NVIDIA work (`DLSSPass.Render`, `BeginFrame`, and
`SetupDRSScaling`) appear compiled as no-op stubs. The official Unity source path
therefore remains the best behavior specification, not a hidden implementation
we can simply turn on.

The API 21 change fixed the biggest per-frame value gap for the active
user-rendering path. The remaining highest-value source-backed differences are:

1. Feature flags: current `0x40` AutoExposure-only vs official-HDRP-like
   `0x2B`.
2. Evaluate invert axes: current `Y=0` vs official `Y=1`.
3. Reset/history: current native sequence ignores later reset requests after the
   first evaluate.
4. Output boundary: current EASU output vs official `"DLSS destination"` pass.
5. Official pass availability: local shell exists, NVIDIA execution body appears
   absent/no-op.

The next runtime test should not be another blind API 21 rerun. The first small
code patch, official feature flags plus invert-axis parity, is now implemented
and build-validated. Rerun the same protected 1080p baseline/candidate shape
with Computer Use kept connected during capture and disconnected after cleanup.
