# Native RenderFunc CommandBuffer DLSS Scratch Evaluate Preflight - 2026-06-07

Status: implemented, statically validated, and protected-gameplay validated.

## Question

Given V Rising's IL2CPP metadata plus Unity HDRP 2022.3 source alignment, can
the already-proven EASU `RenderGraphContext.cmd` boundary run one SDK-wrapper
DLSS evaluate against the coherent source/output/depth/motion descriptor while
writing only to a native scratch output texture?

## Source Basis

Local IL2CPP interop and upstream HDRP source agree on the official DLSS shape:

- `HDRenderPipeline.DoDLSSPass(...)` records the `Deep Learning Super Sampling`
  RenderGraph pass.
- The pass reads source, depth, and motion vectors, writes a postprocess
  upsampled output, then stores `DLSSPass.CreateCameraResources(...)`.
- The render func calls `DLSSPass.GetCameraResources(...)` immediately before
  `DLSSPass.Render(..., ctx.cmd)`.
- V Rising's active FSR-Off/render-scale path currently reaches the neighboring
  EASU render func, where the mod has already proven `ctx.cmd`, source/output,
  depth/motion correlation, and same-device D3D11 shape.

This stage is therefore not a broad resource search. It is a source-guided
single evaluate at the official-boundary-adjacent EASU command-buffer callback.

## Design

New config key:

```text
Diagnostics.EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe=false
```

New helper stage:

```text
native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale
```

The stage enables the focused pieces only:

- `EnableNativeBridgeSmokeTest=true`
- `EnableDlssRuntimeProbe=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableHdrpPostProcessRenderArgsProbe=true`
- `EnableHdrpPostProcessRenderArgsGlobalTextureProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableUpscalerStateProbe=true`
- `EnableHookProbe=false`
- `EnableDLSS=false`

It deliberately does not enable user rendering or visible write-back.

## Implementation

- Native bridge API version is now `18`.
- New export:
  `VrisingDlss_SetRenderEventFrameDescriptorDlssScratchEvaluatePayload(...)`.
- The managed probe uses event id `260612`.
- The native callback reuses the D3D11 descriptor validation path for source,
  visible destination, depth, and motion.
- For scratch output it clones the visible destination D3D11 texture desc,
  creates a native `ID3D11Texture2D`, evaluates DLSS into that scratch texture,
  then immediately calls `ShutdownDlssFrameSequenceWithSdkWrapper()`.
- Success status includes `scratchOutput=yes`, `visibleOutput=no`,
  `evaluateResult=1`, and `shutdownResult=1`.

Release-safe native builds without `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER` compile
and report blocked if this local/private SDK-wrapper stage is mistakenly used.
Thunderstore/package defaults keep the switch `false`.

## Validation

Static validation passed:

- C# Release build passed with `0` warnings and `0` errors.
- Native release-safe MSVC build passed.
- Native SDK-wrapper MSVC build passed.
- Dry-run config for the new stage showed `EnableDLSS=false`,
  `EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe=true`,
  `EnableRenderGraphGetTextureProbe=false`, and visible write-back disabled.
- `scripts\check-release-boundary.ps1` passed.
- `scripts\package-thunderstore.ps1` rebuilt
  `dist\VrisingDLSS-0.1.0-thunderstore.zip` and package validation passed with
  the new scratch-evaluate switch defaulting to `false`.

Protected gameplay validation passed; see
`docs/development/native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-result-2026-06-07.md`.

## Next Step

This proves one no-visible-output DLSS evaluate can run at the source-guided
EASU command-buffer boundary. The next guard should prove persistent scratch
feature reuse at the same boundary, because the one-shot result spent about one
second in NGX prepare/create and only about half a millisecond in the evaluate
itself.
