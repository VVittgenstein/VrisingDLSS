# HDRP/EASU Input Output Correlation Preflight Implementation - 2026-06-07

## Question

Can one guarded diagnostic run correlate the low-resolution HDRP/ProjectM
`DarkForeground.Render(...)` input side with the focused EASU RenderGraph
source/output native-pointer side, before adding any command-buffer work, D3D11
validation, NGX feature lifecycle, or DLSS evaluate?

## Design

New helper stage:

```text
hdrp-easu-input-output-correlation-render-scale
```

The stage combines only already-proven components:

- `EnableHdrpPostProcessRenderArgsProbe=true`
- `EnableHdrpPostProcessRenderArgsGlobalTextureProbe=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableUpscalerStateProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`

It does not enable native D3D11 validation, command-buffer plugin events, NGX
feature create/release, DLSS evaluate, user rendering, or visible write-back.

## Implementation

- Added `HdrpEasuInputOutputCorrelationProbeState`.
- `HdrpPostProcessRenderArgsProbe` now records a latest HDRP input snapshot
  when global depth and motion native pointers are both non-zero.
- The HDRP snapshot includes `UnityEngine.Time.frameCount`, HDCamera summary,
  source/destination RTHandle summaries, and global depth/motion texture
  summaries.
- `FrameResourceProbe` now records the latest focused EASU source/destination
  native-pointer observation when both pointers are available.
- The shared state logs one pass line only when the current snapshots align:
  HDRP camera/source match the EASU input dimensions, HDRP depth/motion contain
  the same input dimensions, the EASU tuple upscales to a larger output, and
  the HDRP/EASU `Time.frameCount` delta is within five frames.

Expected pass line:

```text
HDRP/EASU input-output correlation advanced:
```

The line includes HDRP frame, EASU source/destination frames, frame deltas,
dimension-match booleans, the HDRP color/depth/motion summaries, and the EASU
source/output native-pointer summaries.

## Validation So Far

- PowerShell parser: pass for all scripts.
- C# Release build: pass, 0 warnings, 0 errors.
- Dry-run config for `hdrp-easu-input-output-correlation-render-scale`: pass.
- Protected gameplay validation passed in `r3`; see
  `docs/development/hdrp-easu-input-output-correlation-render-scale-gameplay-result-2026-06-07.md`.
- `r1` rejected stale frame pairing correctly. `r2` exposed stale
  `ResourceHandle` reuse, so pass now requires actual EASU source/destination
  observation dimensions in addition to the EASU tuple dimensions.

## Runtime Proof Standard

Any future repeat should use a protected `11111` gameplay test at true
`1920x1080` Windowed, V Rising `FsrQualityMode=Off`, with no movement keys.
Expected evidence:

- Analyzer `HDRP/EASU Input Output Correlation=Pass`.
- Analyzer `HDRP PostProcess Render Args Global Textures=Pass`.
- Analyzer `Native RenderFunc Resource Native Pointer=Pass`.
- Analyzer `Stage 2C Render-Scale Control Probe=Pass`.
- Pass line shows HDRP color/depth/motion at the EASU input size and EASU
  `input=960x540; output=1920x1080`.
- No D3D11 validation, command-buffer event/payload, NGX, DLSS evaluate,
  visible write-back, crash, or save drift.
