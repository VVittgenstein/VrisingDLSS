# Native RenderFunc CommandBuffer DLSS Visible Write-back Preflight - 2026-06-07

Status: implemented, statically validated, and protected-gameplay validated.

## Question

Can the source-guided EASU `ctx.cmd` boundary reuse the same DLSS frame-sequence
path that passed the persistent scratch proof, but write the evaluated DLSS
output into the visible EASU destination for a bounded three-callback local test?

## Source Basis

Local IL2CPP metadata and Unity HDRP source still point at the same official
shape: the DLSS pass consumes source, depth, and motion vectors, writes the
postprocess upsampled output, and evaluates from a command-buffer render pass.
V Rising's FSR-Off path does not enter the built-in NVIDIA HDRP pass, but the
neighboring EASU render func has already proved:

- source/output correlation at `960x540 -> 1920x1080`
- HDRP depth/motion globals at render input size
- same-device D3D11 texture shape
- scratch DLSS evaluate
- persistent frame-sequence reuse and shutdown

This stage is therefore a narrow visible-output timing/quality guard at the
already-proven EASU command-buffer callback. It is not the older global
`RenderGraph.GetTexture` Stage 10A path.

## Design

New config key:

```text
Diagnostics.EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe=false
```

New helper stage:

```text
native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale
```

The helper enables only the focused route:

- `EnableNativeBridgeSmokeTest=true`
- `EnableDlssRuntimeProbe=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe=true`
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

The old `Diagnostics.EnableDlssVisibleWritebackProbe` remains `false`, and
normal-user rendering remains disabled.

## Implementation

- Native bridge API version is now `20`.
- New event id: `260614`.
- Target visible evaluate successes: `3`.
- New native export:
  `VrisingDlss_SetRenderEventFrameDescriptorDlssVisibleWritebackPayload(...)`.
- The native callback validates the four-resource descriptor and evaluates DLSS
  directly into the visible EASU destination instead of a scratch output.
- The callback keeps one SDK-wrapper DLSS frame sequence alive until the target
  count is reached, then calls release/destroy/shutdown.
- Managed target refresh uses the same persistent-evaluate anti-stale logic as
  the scratch proof so RenderGraph handle reuse does not strand the target.
- Uninstall cleanup now clears both persistent scratch and visible write-back
  enable flags.

Release-safe native builds without `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER` compile
and report blocked if this local/private SDK-wrapper stage is used. The
Thunderstore template keeps the switch `false`.

## Validation

Static validation passed:

- C# Release build passed with `0` warnings and `0` errors.
- Native release-safe MSVC build passed.
- Native SDK-wrapper MSVC build passed.
- Dry-run config showed `EnableDLSS=false`,
  `EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe=true`,
  `EnableDlssVisibleWritebackProbe=false`,
  `EnableRenderGraphGetTextureProbe=false`, and `EnableHookProbe=false`.
- `scripts\check-release-boundary.ps1` passed.
- `scripts\package-thunderstore.ps1` rebuilt
  `dist\VrisingDLSS-0.1.0-thunderstore.zip`.
- `scripts\validate-thunderstore-package.ps1` passed and verified the visible
  write-back switch defaults to `false`.

Protected gameplay validation passed; see
`docs/development/native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-result-2026-06-07.md`.

## Next Step

This proves bounded visible-output write-back can execute and shut down at the
source-guided EASU command-buffer boundary. It still does not prove MVP image
quality, sustained performance, resize/reset handling, fallback behavior, legal
runtime distribution, or normal-user `DLSS.EnableDLSS=true` UX.

Next work should preserve this boundary and add a visual/performance proof or a
normal-user-path candidate that reuses this placement without returning to the
hot global `RenderGraph.GetTexture` steady-state path.
