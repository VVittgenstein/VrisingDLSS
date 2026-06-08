# V Rising Local Decompilation Boundary Refresh - 2026-06-08

Status: completed local/static pass. No V Rising runtime launch was performed,
and no game files were modified.

## Scope

This pass narrows one question: in the actual local V Rising IL2CPP build, where
is the closest official-equivalent HDRP/RenderGraph/DLSS boundary that a
BepInEx/Harmony mod could safely approach?

Clean-room boundary:

- allowed here: method/type names, RVAs, field offsets, first-byte native entry
  shape, xref summaries, serialized asset values, local artifact paths, and
  distilled resource-contract summaries;
- not allowed in release artifacts: copied decompiled V Rising method bodies,
  modified game files, game assets, or redistributed Unity/NVIDIA/game binaries
  outside separately reviewed terms.

## Inputs And Commands

Local game inputs:

- `C:\Software\VRising\GameAssembly.dll`
- `C:\Software\VRising\VRising_Data\il2cpp_data\Metadata\global-metadata.dat`
- `C:\Software\VRising\BepInEx\interop\MethodAddressToToken.db`
- `C:\Software\VRising\BepInEx\interop\MethodXrefScanCache.db`

Local generated/reference inputs:

- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/dump.cs`
- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/script.json`
- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/stringliteral.json`
- `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/DummyDll/`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/`

Commands used:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-vrising-hdrp-dlss-static-route.ps1 -GamePath C:\Software\VRising -Json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-vrising-hdrp-assets.ps1 -GamePath C:\Software\VRising -Json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-vrising-hdrp-dlss-native-stubs.ps1 -GamePath C:\Software\VRising -Json
C:\Software\dotnet\dotnet.exe artifacts\tools\InteropXrefProbe\bin\Release\net6.0\InteropXrefProbe.dll C:\Software\VRising
```

Local ignored artifact copies from this rerun:

- `artifacts/research/vrising-hdrp-dlss-static-route-audit-20260608-rerun.json`
- `artifacts/research/vrising-hdrp-assets-20260608-rerun.json`
- `artifacts/research/interop-xref-probe-20260608-rerun.txt`

## Evidence

### 1. The Official HDRP Shell Exists

The local IL2CPP metadata contains all targeted HDRP route anchors:

| Symbol | RVA |
| --- | ---: |
| `HDRenderPipeline.SetupDLSSFeature` | `0x963D340` |
| `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler` | `0x9640FE0` |
| `HDRenderPipeline.InitializePostProcess` | `0x966B1E0` |
| `HDRenderPipeline.GetPostprocessUpsampledOutputHandle` | `0x966EA00` |
| `HDRenderPipeline.RenderPostProcess` | `0x966EF40` |
| `HDRenderPipeline.DoDLSSPasses` | `0x9670580` |
| `HDRenderPipeline.DoDLSSPass` | `0x9670740` |
| `HDRenderPipeline.EdgeAdaptiveSpatialUpsampling` | `0x9696960` |
| `HDRenderPipeline.FinalPass` | `0x9697090` |

Interop xref evidence:

- `RenderPostProcess` calls `DoDLSSPasses` at the official schedule points.
- `DoDLSSPasses` calls `DoDLSSPass` and then moves the resolution group after
  dynamic-resolution upscale.
- `DoDLSSPass` has outgoing xrefs consistent with a RenderGraph pass contract:
  add pass, read/write textures, create DLSS camera resources, and set a render
  function.
- `FinalPass` is called from `RenderPostProcess`.

Native entry-byte audit evidence:

- `RenderPostProcess`, `DoDLSSPass`, and `DLSSPass.CreateCameraResources` are
  `NonStubLike`, not immediate-return stubs.

### 2. The Built-In NVIDIA DLSS Body Is Inert

`scripts\inspect-vrising-hdrp-dlss-native-stubs.ps1` maps method RVAs to PE file
offsets and checks the first bytes of key methods. It reports:

| Symbol | RVA | Native entry shape |
| --- | ---: | --- |
| `DLSSPass.SetupFeature` | `0x17312A0` | returns `false` |
| `DLSSPass.Create` | `0x173F700` | returns `null` |
| `DLSSPass.BeginFrame` | `0x171E170` | returns immediately |
| `DLSSPass.SetupDRSScaling` | `0x171E170` | returns immediately |
| `DLSSPass.Render` | `0x171E170` | returns immediately |
| `DLSSPass..ctor` | `0x171E170` | returns immediately |

This matches the upstream HDRP source conditionals: when Unity's NVIDIA module
symbols are not compiled in, `SetupFeature` returns false, `Create` returns
null, and `BeginFrame`/`SetupDRSScaling`/`Render` contain no NVIDIA work.

Additional xref evidence:

- `HDDynamicResolutionPlatformCapabilities.ActivateDLSS` has caller count `0`.
- `SetupDLSSFeature` does not resolve to `DLSSPass.SetupFeature` or
  `ActivateDLSS` in the local xref audit.
- `InitializePostProcess` does not resolve to `DLSSPass.Create`.

Inference: `m_DLSSPass` is not a useful callable implementation in this V Rising
build. The official DLSS path exists as a shell/resource contract, but the
NVIDIA execution body is compiled out or otherwise inert.

### 3. The Active Serialized Asset Selects EASU/FSR, Not DLSS

Read-only Unity asset unpack reports:

| Field | Value |
| --- | --- |
| Game version | `VRising: v1.1.13.0-r99712-b17 (202605251526)` |
| Unity version | `2022.3.58f1` |
| Active SRP asset | `HDRP DefaultSettings` / path id `9008` |
| `m_UseRenderGraph` | `1` |
| `dynamicResolutionSettings.enabled` | `1` |
| `dynamicResolutionSettings.enableDLSS` | `0` |
| `DLSSInjectionPoint` | `BeforePost` |
| `dynResType` | `Hardware` |
| `upsampleFilter` | `EdgeAdaptiveScalingUpres` |

`HDRP_Low` and `HDRP_Medium` also have `enableDLSS=0` and
`upsampleFilter=EdgeAdaptiveScalingUpres`.

Inference: the observed `Uber -> EASU -> FinalPass` route is not accidental. It
is the active HDRP asset's configured dynamic-resolution upscaler route.

### 4. Gate Fields And V Rising's FSR Layer Are Present

Local metadata exposes these relevant fields:

| Field | Offset |
| --- | ---: |
| `HDRenderPipeline.m_DLSSPassEnabled` | `0x3720` |
| `HDRenderPipeline.m_DLSSPass` | `0x3730` |
| `HDAdditionalCameraData.allowDeepLearningSuperSampling` | `0xD4` |
| `HDAdditionalCameraData.cameraCanRenderDLSS` | `0xE4` |
| `HDDynamicResolutionPlatformCapabilities.m_DLSSDetected` | `0x0` |
| `GlobalDynamicResolutionSettings.enableDLSS` | `0x2` |
| `GlobalDynamicResolutionSettings.DLSSInjectionPoint` | `0x8` |
| `GlobalDynamicResolutionSettings.upsampleFilter` | `0x25` |

V Rising-specific ProjectM metadata contains the FSR/dynamic-resolution layer:

- `ProjectM.GraphicsSettingsManager.TryApplyGraphicsSettingsToCamera`
- `ProjectM.GraphicsSettingsManager.GetDynResForQualityMode`
- `ProjectM.GraphicsSettingsManager.TurnOffFSR`
- `ProjectM.GraphicsSettingsManager.TurnOnFSR`
- `ProjectM.GraphicsSettingsManager.SetFSRQuality`
- `ProjectM.ClientConsoleCommandSystem.DetermineFSRQualityMode`

Focused ProjectM search for `DLSS`, `NGX`, `NVIDIA`, `Streamline`, `nvngx`,
`nvsdk_ngx`, and `XeSS` found no ProjectM-specific DLSS control layer. Focused
filesystem search found no DLSS/NGX/Streamline runtime files outside our local
mod/config area.

Inference: V Rising wraps FSR/dynamic-resolution behavior, not a hidden
game-owned DLSS/NGX implementation.

### 5. Official DLSS Contract Shape

Local UnityGraphics 2022.3 source and matching V Rising metadata/xrefs show the
official DLSS pass contract:

- stage: `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass`;
- schedules: `BeforePost`, `AfterDepthOfField`, or `AfterPost`, gated by
  `dynamicResolutionSettings.DLSSInjectionPoint`;
- declared resources: source color, output, depth, motion vectors, and optional
  bias color mask;
- parameters: reset history, pre-exposure, camera, and dynamic-resolution
  settings;
- command submission: the render function receives `RenderGraphContext.ctx.cmd`
  and calls `DLSSPass.Render(...)`;
- NVIDIA-side data in upstream source includes motion-vector scale from input
  resolution, jitter offsets, pre-exposure, inverted depth/Y flags, reset flag,
  feature recreate/reuse on resolution or quality changes, and cleanup on
  camera/view lifecycle changes.

Inference: our current EASU `ctx.cmd` candidate is close in command-buffer
timing and visible-output placement, but it is not official-equivalent by
itself because EASU declares only source/destination and not the DLSS
source/output/depth/motion/bias resource contract.

## Patch Boundary Assessment

Rejected as mainline:

- forcing or calling `m_DLSSPass`;
- patching `DLSSPass.Render` directly;
- broad steady-state `RenderGraphResourceRegistry.GetTexture(TextureHandle&)`;
- real DLSS evaluate from `DynamicResolutionHandler.Update`;
- new mod-owned RenderGraph pass injection as the normal route;
- rerunning the same EASU visible-writeback candidate unchanged.

Useful but read-only/diagnostic:

- `RenderGraph.CompileRenderGraph` pass list, pass data, declarations, and
  render-func metadata;
- local asset unpack of `HDRenderPipelineAsset` and `GraphicsSettings`;
- PE entry-byte audit of key IL2CPP RVAs.

Closest plausible runtime boundary:

- an engine-owned postprocess/upscale render-function boundary that can bind
  source/output placement from the observed `Uber -> EASU -> FinalPass` chain
  with HDRP depth and motion-vector resources, and submit through an HDRP-owned
  `ctx.cmd` at a stage comparable to `DoDLSSPass`.

The currently prepared no-native/no-evaluate proof for that is still
`hdrp-dlss-contract-bind-render-scale`. It should remain a protected gameplay
proof, not a blind native/DLSS runtime test.

## Open Questions

- The exact BepInEx/Harmony-accessible hook that is both official-equivalent and
  cheap is not proven yet.
- `CustomPostProcessVolumeComponent.Render` remains a possible command-buffer
  boundary because HDRP binds postprocess resources around custom passes, but it
  is not proven registered or suitable for DLSS output in this game.
- Full native body reverse engineering with Ghidra/IDA could refine branch and
  resource-flow summaries, but those tools are not currently installed under
  `C:\Software` or available on PATH. If installed later, record only summaries,
  RVAs, and patch-boundary conclusions, not decompiled game code.

## Decision

Use `DoDLSSPass` as the official resource-order and lifecycle contract. Do not
try to resurrect Unity's built-in `DLSSPass` implementation in this build.
Continue toward a mod-owned DLSS evaluator only at an engine-owned
official-equivalent boundary that binds color output, depth, motion vectors,
history/reset, pre-exposure, resize/recreate lifecycle, and fallback behavior
without broad per-frame resource discovery.
