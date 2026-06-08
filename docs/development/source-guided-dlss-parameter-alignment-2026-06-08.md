# Source-Guided DLSS Parameter Alignment - 2026-06-08

Status: implemented and build-validated; runtime validation still required.

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

## Next Runtime Guard

Before the next game run, state the usual runtime preflight. The narrow runtime
question should be:

Does `dlss-user-rendering` still reach the source-guided EASU `ctx.cmd`
candidate after API 21, and do logs show non-default official-like
`jitter/mvScale/preExposure/reset` values without crash or save/config residue?

Use the protected `1920x1080` Windowed fixture. A short candidate-only run is
enough to validate the ABI/log path before a full paired visual/performance run.

## Remaining Source Questions

- Decide whether the command-buffer DLSS route should match Unity's feature
  flags: `IsHDR`, `MVLowRes`, `DepthInverted`, and sharpening, and whether that
  means disabling the current `AutoExposure` flag when `preExposure` is supplied.
- Decide whether a bias color mask is needed or whether omitting it is acceptable
  for V Rising's use case.
- Validate resize/reset behavior after a real resolution or camera history
  change, not only the first steady gameplay scene.
