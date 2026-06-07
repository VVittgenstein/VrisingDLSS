# Native RenderFunc CommandBuffer Frame Descriptor D3D11 Preflight - 2026-06-07

Status: implemented, statically validated, and protected-gameplay validated.

## Question

After the no-evaluate frame descriptor proved that focused EASU source/output
plus HDRP depth/motion pointers can be carried through one EASU
`RenderGraphContext.cmd` plugin event, can the native callback validate those
same four resources as a coherent D3D11 Super Resolution input set without NGX,
DLSS evaluate, user rendering, or visible write-back?

## Design

New config key:

```text
Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe=false
```

New helper stage:

```text
native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale
```

The stage enables only the source-guided pieces needed for a D3D11 validation
of the already-proven descriptor:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe=true`
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

- NGX runtime load/init/feature lifecycle;
- DLSS evaluate;
- user rendering;
- visible write-back.

## Implementation

- Native bridge API version is now `17`.
- The existing metadata-only frame-descriptor payload remains available through
  `VrisingDlss_SetRenderEventFrameDescriptorPayload(...)`.
- A new export,
  `VrisingDlss_SetRenderEventFrameDescriptorD3D11ValidationPayload(...)`,
  stores the same source/destination/depth/motion descriptor with a
  `validateD3D11` flag.
- `FrameResourceProbe` uses a separate event id, `260611`, for the D3D11
  descriptor preflight.
- The managed stage still obtains the descriptor from the source-guided
  HDRP/EASU correlation state and still issues the event through the focused
  EASU `ctx.cmd`.
- The native consume path calls the D3D11 texture-description helper for all
  four pointers, validates device identity and dimensions, then records status.

## Safety Boundary

The native consume path validates only resource shape:

- all four pointers are non-null D3D11 resources;
- source, destination, depth, and motion are on the same D3D11 device;
- source matches the descriptor input size;
- destination matches the descriptor output size;
- depth and motion match the input size;
- output is larger than input.

It does not load NGX, create a DLSS feature, call DLSS evaluate, modify the
resources, or write visible output. Expected native status explicitly includes:

```text
validation=D3D11-succeeded; sameDevice=yes; ngx=not-loaded; evaluate=not-run
```

## Expected Runtime Interpretation

Pass:

- analyzer reports `Native RenderFunc CommandBuffer Frame Descriptor D3D11=Pass`;
- analyzer also reports `HDRP/EASU Input Output Correlation=Pass` and
  `Stage 2C Render-Scale Control Probe=Pass`;
- log contains `Native render-func command-buffer frame descriptor D3D11 set
  advanced:` and `Native render-func command-buffer frame descriptor D3D11
  advanced:`;
- native status shows `render event frame descriptor D3D11 validation consumed`;
- descriptor dimensions are `input=960x540` and `output=1920x1080` for the
  current 1080p Performance-mode constructive fixture;
- D3D11 status shows source/depth/motion at `960x540`, destination at
  `1920x1080`, `sameDevice=yes`, and `scale=(2.000x,2.000x)`;
- NGX, DLSS evaluate, user rendering, visible write-back, crash, and
  access-violation patterns remain absent.

Partial or blocked:

- descriptor set succeeds but D3D11 consume fails: inspect the exact
  `D3D11 validation failed:` reason and resource dimensions;
- device mismatch: do not proceed to evaluate until ownership/lifetime is
  understood;
- missing depth or motion native pointer: return to the HDRP input-side probe;
- any NGX/evaluate/writeback line appears: reject the run as over-scoped.

## Validation

Static validation completed before runtime:

- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
  passed with `0` warnings and `0` errors.
- Native release-safe MSVC build passed.
- Native SDK-wrapper build passed.
- Release-safe native DLL was copied to
  `artifacts\native-build\Release\VrisingDLSS.Native.dll`.
- PowerShell parser validation passed for the changed scripts.
- Dry-run config for
  `native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale` showed
  only the intended toggles.
- `git diff --check` passed.
- `scripts\check-release-boundary.ps1` passed.
- `scripts\package-thunderstore.ps1` passed and package validation confirmed
  both descriptor probes default to `false`.

Protected gameplay validation passed; see
`docs/development/native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-result-2026-06-07.md`.

## Next Step

This stage proves the four-resource descriptor is a coherent same-device D3D11
Super Resolution input/output shape at the official-boundary-adjacent EASU
`ctx.cmd` event. The next guard should be a separate bounded no-write
SDK-wrapper DLSS frame-sequence evaluate at the same callback boundary. Do not
combine evaluate with visible write-back or broad `RenderGraph.GetTexture`
discovery.
