# Native RenderFunc CommandBuffer DLSS Persistent Scratch Evaluate Preflight - 2026-06-07

Status: implemented, statically validated, and protected-gameplay validated.

## Question

Can the source-guided EASU `ctx.cmd` boundary keep one SDK-wrapper DLSS frame
sequence alive across multiple callbacks, evaluate into native scratch output
textures three times, and shut down without touching the visible EASU output?

## Source Basis

Local IL2CPP metadata and Unity HDRP 2022.3 source keep pointing at the same
official DLSS shape:

- `HDRenderPipeline.DoDLSSPass(...)` records the `Deep Learning Super Sampling`
  RenderGraph pass.
- The pass reads source, depth, and motion vectors, writes the postprocess
  upsampled output, and resolves camera resources immediately before
  `DLSSPass.Render(..., ctx.cmd)`.
- V Rising's current FSR-Off/render-scale route does not enter that official
  Unity NVIDIA path, but the neighboring EASU render func has the same
  command-buffer timing and now has protected gameplay proof for source/output,
  depth/motion, D3D11 shape, and one scratch DLSS evaluate.

This stage is therefore a bounded lifecycle proof at the official-boundary-
adjacent EASU command-buffer callback, not another broad texture search.

## Design

New config key:

```text
Diagnostics.EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe=false
```

New helper stage:

```text
native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale
```

The stage enables the focused pieces only:

- `EnableNativeBridgeSmokeTest=true`
- `EnableDlssRuntimeProbe=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe=true`
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

It deliberately does not enable normal user rendering or visible write-back.

## Implementation

- Native bridge API version is now `19`.
- New event id: `260613`.
- Target scratch evaluate successes: `3`.
- New export:
  `VrisingDlss_SetRenderEventFrameDescriptorDlssPersistentScratchEvaluatePayload(...)`.
- The native callback validates the four-resource descriptor, creates scratch
  output from the visible destination descriptor, evaluates DLSS into scratch,
  keeps the SDK-wrapper frame sequence alive until the target count is reached,
  then calls release/destroy/shutdown.
- Status capacity was increased so the final consumed status can carry the full
  persistent evaluate and shutdown details.
- Managed target refresh now keeps re-arming the EASU resource target while the
  persistent scratch stage has not reached its target successes. This matters
  because RenderGraph resource handle indexes are reused across compiles.
- Descriptor-not-ready attempts no longer reset the persistent attempt counter;
  the counter now remains meaningful across multiple callbacks.

Release-safe native builds without `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER` compile
and report blocked if this local/private SDK-wrapper stage is used. The
Thunderstore template keeps the switch `false`.

## Validation

Static validation passed:

- C# Release build passed with `0` warnings and `0` errors.
- Native release-safe MSVC build passed.
- Native SDK-wrapper MSVC build passed.
- Dry-run config for the stage showed `EnableDLSS=false`,
  `EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe=true`,
  `EnableRenderGraphGetTextureProbe=false`, and visible write-back disabled.
- `scripts\check-release-boundary.ps1` passed.
- `scripts\package-thunderstore.ps1` rebuilt
  `dist\VrisingDLSS-0.1.0-thunderstore.zip` and package validation passed with
  the persistent scratch switch defaulting to `false`.

Protected gameplay validation passed; see
`docs/development/native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-result-2026-06-07.md`.

## Runtime Lesson

The first gameplay iteration reached `sequenceCreates=1`, `sequenceEvaluates=2`,
and `evaluateSuccesses=2`, but did not reach the target `3`. Review showed the
managed EASU target had stopped refreshing after the first successful set, while
RenderGraph handle indexes were later reused by unrelated resources. The fix was
source/lifecycle-guided: keep refreshing the target until persistent scratch
set/issue successes reach the target count. The second gameplay run then passed.

This is a concrete example of why the source/decompilation map reduces blind
trial: the useful question was not "does DLSS work?", but "does our target stay
aligned with the current RenderGraph compile while the persistent sequence is
pending?"

## Next Step

This proves NGX feature reuse and scratch-output lifecycle at the EASU
command-buffer callback. The next source-guided guard should either move to a
separately gated visible write-back timing/quality proof at the same boundary or
continue decompiling the official HDRP DLSS pass to find a cleaner BepInEx-
reachable equivalent boundary.
