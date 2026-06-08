# Source-Guided DLSS Parameter Alignment - 2026-06-08

Status: implemented, build-validated, and candidate-only runtime validated;
paired visual/performance validation still required.

## Question

After the candidate-only FPS rerun, the next useful source/decompilation question
was whether the current EASU `ctx.cmd` DLSS candidate was submitting the same
per-frame DLSS values that Unity HDRP's official `DLSSPass` submits.

## Source Evidence

Local Unity HDRP 2022.3 source and the V Rising IL2CPP interop dump agree on the
important shape:

- `HDRenderPipeline.DoDLSSPass` fills `DLSSPass.Parameters` with
  `resetHistory`, `hdCamera`, dynamic-resolution settings, and clamped GPU
  exposure.
- `DLSSPass.InternalNVIDIARender` derives render/output sizes from
  `HDCamera.actualWidth/actualHeight` and the final viewport.
- Official HDRP passes jitter as the negative `HDCamera.taaJitter` components.
- Official HDRP passes motion-vector scale as negative render input dimensions.
- Official HDRP passes `preExposure` into the DLSS execute data.
- Official HDRP resets DLSS history when the feature is new or the camera
  requested post-processing history reset.

The current source-guided command-buffer candidate already used the same
low-resolution color/depth/motion and full-size visible output shape, but native
frame-sequence evaluate still used debug-era defaults:

- `jitter=(0,0)`
- `mvScale=(1,1)`
- `preExposure=1.0`
- reset came from config rather than the current `HDCamera` reset flag

## Implementation

The source-guided command-buffer payload now carries a small official-HDRP-like
per-frame parameter set:

- `HdrpPostProcessRenderArgsProbe` reads `HDCamera.taaJitter`,
  `HDCamera.GpuExposureValue()`, and `HDCamera.resetPostProcessingHistory` while
  taking the existing HDRP postprocess/global texture snapshot.
- `HdrpEasuInputOutputCorrelationProbeState` attaches those values to the
  already-proven HDRP/EASU frame descriptor, deriving `mvScale` as
  `(-inputWidth, -inputHeight)`.
- `FrameResourceProbe` passes these values into the native command-buffer DLSS
  scratch/persistent/visible/user-rendering payloads.
- The native bridge API is now `21`.
- The native SDK-wrapper frame-sequence evaluate sets NGX `InPreExposure` from
  the payload and logs `jitter`, `mvScale`, and `preExposure` in the evaluate
  status.

This patch deliberately did not change feature-create flags or the MVP
`AutoExposure` setting. Official Unity sets `IsHDR`, `MVLowRes`,
`DepthInverted`, and a sharpening flag, while the current config path still
mostly exposes `AutoExposure`. That should be a separate source-backed change
because it changes DLSS feature creation semantics, not just per-frame evaluate
values.

## Verification

Non-runtime verification passed:

- C# Release build:
  `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
- release-safe native build:
  `cmake --build artifacts\native-build-msvc --config Release`
- SDK-wrapper native build:
  `cmake --build artifacts\native-build-msvc-wrapper --config Release`
- Visual readiness stayed `Blocked`, as expected, because the latest paired
  visual/performance gate still lacks a same-run candidate FPS summary and human
  review.

## Runtime Validation

Candidate-only protected gameplay run
`api21-user-rendering-1080p-20260608-r4` passed the narrow API 21 guard.

Runtime shape:

- `1920x1080` Windowed.
- V Rising `FsrQualityMode=Off`.
- SDK-wrapper native and local research `nvngx_dlss.dll` from
  `ref/NVIDIA-DLSS-310.6.0/nvngx_dlss.dll`.
- Protected local/private `11111` save.
- Computer Use selected the real `process:C:\Software\VRising\VRising.exe`
  Unity window, clicked Continue once, and sent no movement/gameplay keys.

Positive evidence:

- Analysis reported `Native bridge API version: 21`.
- `HDRP PostProcess Render Args=Pass`,
  `HDRP PostProcess Render Args Global Textures=Pass`,
  `HDRP/EASU Input Output Correlation=Pass`,
  `Native RenderFunc CommandBuffer DLSS User Rendering=Pass`, and
  `DLSS User Rendering Candidate=Pass`.
- Logs contained `dlssFrameParams=` 11 times,
  `dlssEvaluateParams=` once, and native
  `jitter/mvScale/preExposure` payload/evaluate status 59 times.
- First accepted descriptor logged
  `dlssEvaluateParams=jitter=(0.0375,0.0833),mvScale=(-960,-540),preExposure=1,resetHistory=False`.
- Native pending/consumed statuses carried matching values such as
  `jitter=(0.0375,0.0833); mvScale=(-960.0000,-540.0000); preExposure=1.0000`.
- User-rendering evidence reached `setSuccesses=109`, `consumed=109`,
  `sequenceCreates=1`, `sequenceEvaluates=109`, and
  `evaluateSuccesses=109` in the analyzer, with later status lines reaching
  thousands of sustained evaluates before cleanup.
- FPS capture passed:
  `AverageFps=131.241`, `OnePercentLowFps=99.398`,
  `P95FrameMs=9.037`, `P99FrameMs=10.061`,
  `AverageGpuUtilPercent=52`, and `AverageGpuPowerW=85.836`.
- Screenshot artifact is nonblank gameplay:
  `artifacts/visual-validation/api21-user-rendering-1080p-20260608-r4-user-rendering.png`,
  SHA-256 `18FC7DEF8DF0B3BBC58CFEAD98ED1F0CD1BC9742BBAACE0A9B30639C7C2141AB`.

Negative and cleanup evidence:

- `RenderGraph GetTexture call #` count was `0`.
- Explicit user-rendering failed/blocked/skipped lines were `0`.
- Access violation / `0xc0000005` / `nvwgf2umx` evidence was `0`.
- Crash event count was `0`.
- The helper restored release-safe state, BepInEx config, client settings, and
  FSR Off state, left no V Rising process, archived the changed post-run save,
  and restored the protected save to `ChangeCount=0`.

This proves the API 21 parameter path reaches real gameplay NGX evaluate. It
does not prove MVP performance because it is candidate-only and short. The next
visual/performance gate still needs same-run baseline versus candidate evidence
and human visual review.

## Runner Notes From This Validation

Three pre-launch attempts were rejected before gameplay and safely restored:

- `r1` used `Start-Process -ArgumentList` with a save path containing spaces;
  PowerShell argument joining mis-bound script parameters.
- `r2` used an encoded command but invoked the visual-comparison script with a
  literal hashtable instead of splatting it.
- `r3` reached the visual helper's safe preflight and then rejected the run
  because SDK-wrapper candidate visual runs require `-DlssRuntimePath`.

For future hidden visual-comparison runners, create a `$params` hashtable inside
the encoded command, invoke the script as `& script.ps1 @params`, and pass
`DlssRuntimePath` explicitly for SDK-wrapper candidate stages.

## Next Runtime Guard

Before the next game run, state the usual runtime preflight. The next narrow
question should be whether API 21 improves a same-run baseline versus candidate
visual/performance comparison, not whether the ABI/log path works.

Use the protected `1920x1080` Windowed fixture for quick iteration, then move to
the required GPU-bound 4K/high-load matrix only after image correctness and
same-scene 1080p behavior are understood.

## Remaining Source Questions

- Decide whether the command-buffer DLSS route should match Unity's feature
  flags: `IsHDR`, `MVLowRes`, `DepthInverted`, and sharpening, and whether that
  means disabling the current `AutoExposure` flag when `preExposure` is supplied.
- Decide whether a bias color mask is needed or whether omitting it is acceptable
  for V Rising's use case.
- Validate resize/reset behavior after a real resolution or camera history
  change, not only the first steady gameplay scene.
