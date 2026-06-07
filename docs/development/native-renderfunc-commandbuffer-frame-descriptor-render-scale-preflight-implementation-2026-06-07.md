# Native RenderFunc CommandBuffer Frame Descriptor Preflight - 2026-06-07

Status: implemented, statically validated, and protected-gameplay validated.

## Question

After source/decompilation-guided correlation proved that HDRP
`DarkForeground.Render(...)` sees low-resolution color/depth/motion in the same
frame as the focused EASU source/output pair, can the mod carry all four native
texture pointers through one EASU `RenderGraphContext.cmd` plugin event without
touching D3D11 validation, NGX, DLSS evaluate, or visible output?

## Design

New config key:

```text
Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe=false
```

New helper stage:

```text
native-renderfunc-commandbuffer-frame-descriptor-render-scale
```

The stage enables only the source-guided pieces needed for a no-evaluate frame
descriptor:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferFrameDescriptorProbe=true`
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

It deliberately does not enable:

- native D3D11 pair validation;
- NGX runtime load/init/feature lifecycle;
- DLSS evaluate;
- user rendering;
- visible write-back.

## Implementation

- `HdrpPostProcessRenderArgsProbe` now records typed depth and motion native
  pointers from `_CameraDepthTexture` and `_CameraMotionVectorsTexture`.
- `FrameResourceProbe` records typed EASU source and destination native
  pointers from the focused `Edge Adaptive Spatial Upsampling` source/output
  handles.
- `HdrpEasuInputOutputCorrelationProbeState.TryGetFrameDescriptor(...)` returns
  a descriptor only when HDRP color/depth/motion and EASU source/output align
  within the same frame window and the actual EASU source/destination
  observations match the expected input/output dimensions.
- The managed bridge sets one pending native payload with source, destination,
  depth, and motion `IUnknown*` pointers plus dimensions, frame numbers,
  `eventId=260610`, and a monotonic sequence.
- The native bridge AddRefs all four pointers, stores the pending descriptor,
  consumes it from the render-event callback, records metadata, then releases
  the references.

Native bridge API version observed after implementation: `16`.

## Safety Boundary

The native consume path validates only the descriptor shape:

- four pointers are non-null;
- source and destination are not the same pointer;
- input and output dimensions are positive;
- output is larger than input;
- the incoming render event id matches the pending descriptor event id.

It does not call `QueryInterface` for D3D11 resources, does not describe
textures, does not compare devices, does not load NGX, and does not call DLSS
evaluate. Expected native status explicitly includes:

```text
validation=D3D11-not-queried; ngx=not-loaded; evaluate=not-run
```

## Expected Runtime Interpretation

Pass:

- analyzer reports `Native RenderFunc CommandBuffer Frame Descriptor=Pass`;
- analyzer also reports `HDRP/EASU Input Output Correlation=Pass` and
  `Stage 2C Render-Scale Control Probe=Pass`;
- log contains one `Native render-func command-buffer frame descriptor set
  advanced:` line and one `Native render-func command-buffer frame descriptor
  advanced:` line;
- native status shows `render event frame descriptor payload consumed`;
- descriptor dimensions are `input=960x540` and `output=1920x1080` for the
  current 1080p Performance-mode constructive fixture;
- frame deltas are `0` or otherwise within the guarded correlation window;
- broad `RenderGraph GetTexture call #`, D3D11 pair validation, NGX, DLSS
  evaluate, user rendering, visible write-back, crash, and access-violation
  patterns remain absent.

Partial or blocked:

- correlation passes but descriptor set does not run: inspect descriptor
  readiness and target re-arm ordering;
- descriptor set succeeds but consume stays pending: inspect command-buffer
  event issue status and native callback reachability;
- any D3D11/NGX/evaluate/writeback line appears: reject the run as over-scoped.

## Validation

Static validation completed before runtime:

- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
  passed with `0` warnings and `0` errors.
- Native release-safe MSVC build passed.
- Native SDK-wrapper build passed.
- Release-safe native DLL was copied to
  `artifacts\native-build\Release\VrisingDLSS.Native.dll`.
- PowerShell parser validation passed for the changed scripts.
- `git diff --check` passed.
- `scripts\check-release-boundary.ps1` passed.
- `scripts\package-thunderstore.ps1` passed and recreated
  `dist\VrisingDLSS-0.1.0-thunderstore.zip`.

Protected gameplay validation passed; see
`docs/development/native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-result-2026-06-07.md`.

## Next Step

This stage proves four-pointer frame-descriptor transport at the
official-boundary-adjacent EASU `ctx.cmd` event, not DLSS correctness. The next
guard should be either a separate D3D11/SR input validation of the same four
resources, or a bounded SDK-wrapper-only no-write evaluate preflight. Do not
return to broad steady-state `RenderGraph.GetTexture` discovery.
