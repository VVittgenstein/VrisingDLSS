# V Rising IL2CPP HDRP/PostProcess Boundary Decompilation Notes - 2026-06-07

Status: local narrow decompilation/static-xref pass completed. This is research
evidence only; no decompiled game code or game files are included in the public
mod/package.

## Scope And Compliance Boundary

This pass was started because the injected `VolumeProfile.Add(...)` custom
postprocess route failed before it could reach `Render(...)`, while prior
RenderGraph-wide resource discovery was proven too hot for performance.

Allowed use in this repository:

- Identify types, methods, signatures, tokens, native RVAs, and xref order.
- Choose BepInEx/Harmony-accessible hook boundaries.
- Record distilled conclusions and rejected routes.

Not allowed in release artifacts:

- Decompiled game method bodies.
- V Rising binaries or metadata files.
- Private third-party mod code, ABI, package layout, binaries, or wording.

## Local Inputs

Game install inspected locally:

- `C:\Software\VRising\GameAssembly.dll`
- `C:\Software\VRising\VRising_Data\il2cpp_data\Metadata\global-metadata.dat`
- `C:\Software\VRising\BepInEx\interop\*.dll`
- `C:\Software\VRising\BepInEx\interop\MethodAddressToToken.db`
- `C:\Software\VRising\BepInEx\interop\MethodXrefScanCache.db`
- `C:\Software\VRising\BepInEx\core\Cpp2IL.Core.dll`
- `C:\Software\VRising\BepInEx\core\LibCpp2IL.dll`
- `C:\Software\VRising\BepInEx\core\Il2CppInterop.Common.dll`

Local ignored artifact:

- `artifacts/research/vrising-il2cpp-custom-postprocess-xrefs-20260607.txt`

The interop assemblies are bridge wrappers, not original game source bodies.
They still expose enough metadata for this phase: concrete type names, method
signatures, method tokens, caller counts, cached xref/ref ranges, and method
RVA mapping through the BepInEx-generated databases.

## Method

`ilspycmd` was used against local interop/core assemblies to inspect wrapper
types and BepInEx cache formats. A temporary ignored helper under
`artifacts/tools/InteropXrefProbe` decoded:

- `CachedScanResultsAttribute` ranges on target wrapper methods.
- `MethodXrefScanCache.db` rows.
- `MethodAddressToToken.db` RVA-to-wrapper-method mapping.

This produced method/xref summaries only; it did not copy method bodies.

## V Rising Custom Postprocess Types

The local metadata/interops identify these ProjectM concrete custom postprocess
types:

- `CustomVignette`
- `LineOfSightVision`
- `LineOfSight`
- `BatFormFog`
- `DarkForeground`
- `ProjectM.ContestAreaEffect`

They derive from HDRP `CustomPostProcessVolumeComponent` and expose the official
custom postprocess render signature:

```text
Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
```

Their `Render(...)` xrefs show real HDRP postprocess work, not inert wrappers:

- `CustomVignette.Render`: calls `Material.SetColor`, `Material.SetFloat`,
  `Material.SetTexture`, `RTHandle.op_Implicit`, and
  `HDUtils.DrawFullScreen`.
- `LineOfSightVision.Render`: calls `Material.SetFloat`,
  `RTHandle.op_Implicit`, `Material.SetTexture`, and
  `HDUtils.DrawFullScreen`.
- `LineOfSight.Render`: calls `Material.SetTexture`, `RTHandle.op_Implicit`,
  and `HDUtils.DrawFullScreen`.
- `BatFormFog.Render`: calls `VolumeStack.GetComponent`,
  `VisionManager.get_Instance`, `Material.SetFloat`, `Material.SetTexture`,
  `RTHandle.op_Implicit`, and `HDUtils.DrawFullScreen`.
- `DarkForeground.Render`: calls `Material.SetFloat`, `Material.SetColor`,
  `RTHandle.op_Implicit`, `Material.SetTexture`, and
  `HDUtils.DrawFullScreen`.
- `ProjectM.ContestAreaEffect.Render`: calls `Material.SetFloat`,
  `Material.SetTexture`, `RTHandle.op_Implicit`, and
  `HDUtils.DrawFullScreen`.

Each concrete `Render(...)` wrapper showed `CallerCount=0` and empty direct
`refs/users` in the cached xref database. This is consistent with HDRP invoking
custom postprocess components through virtual/interface dispatch from its custom
postprocess pass rather than through direct calls to each concrete override.

## HDRP RenderPostProcess Order Evidence

The local HDRP interop/xref cache shows
`HDRenderPipeline.RenderPostProcess` is called from
`HDRenderPipeline.RecordRenderGraph`.

Its native xref order, sorted by `foundAt`, strongly suggests this branch-shaped
postprocess sequence:

```text
RenderPostProcess
  CreateTexture
  BeginProfilingSampler
  DoCopyAlpha
  StopNaNsPass
  DynamicExposurePass
  DoDLSSPasses
  get_beforeTAACustomPostProcessesTypes
  CustomPostProcessPass
  SMAAPass
  DoTemporalAntialiasing
  IsTAAUEnabled
  SetCurrentResolutionGroup
  RestoreNonjitteredMatrices
  get_beforePostProcessCustomPostProcessesTypes
  CustomPostProcessPass
  DepthOfFieldPass
  DoDLSSPasses
  MotionBlurPass
  get_afterPostProcessBlursCustomPostProcessesTypes
  CustomPostProcessPass
  PaniniProjectionPass
  BloomPass
  ColorGradingPass
  LensFlareDataDrivenPass
  UberPass
  PushFullScreenDebugTexture
  get_afterPostProcessCustomPostProcessesTypes
  CustomPostProcessPass
  FXAAPass
  DoDLSSPasses
  DoDLSSPasses
  IsDLSSEnabled
  ContrastAdaptiveSharpeningPass
  EdgeAdaptiveSpatialUpsampling
  DoDLSSPasses
  FinalPass
  IsTAAUEnabled
  EndProfilingSampler
```

Branch conditions matter, so this is not a single guaranteed linear execution
path. It is still strong local evidence for relative stage placement.

## Official DLSS Boundary Evidence

`HDRenderPipeline.DoDLSSPasses` has five `RenderPostProcess` users at local
RVA sites:

- `0x966F389`
- `0x966F5B6`
- `0x966F9C3`
- `0x966F9EF`
- `0x966FAAF`

`DoDLSSPasses` calls:

- `HDRenderPipeline.DoDLSSColorMaskPass`
- `HDRenderPipeline.DoDLSSPass`
- `HDRenderPipeline.SetCurrentResolutionGroup`

`HDRenderPipeline.DoDLSSPass` is the closest local official boundary. Its xrefs
include:

- `RenderGraph.AddRenderPass`
- `HDCamera.RequestGpuTexelValue`
- `HDCamera.PumpReadbackQueue`
- `RenderGraphBuilder.ReadTexture`
- `HDRenderPipeline.GetPostprocessOutputHandle`
- `RenderGraphResourceRegistry.IncrementWriteCount`
- `RenderGraphPass.AddResourceWrite`
- `ResourceHandle.IsValid`
- `DLSSPass.CreateCameraResources`
- `RenderFunc<T>..ctor`
- `RenderGraphBuilder.SetRenderFunc`
- `RenderGraphBuilder.Dispose`

This reinforces the source-search conclusion: official HDRP DLSS declares and
uses specific RenderGraph resources inside a targeted pass construction/render
func path. It does not discover all resources from a broad
`RenderGraphResourceRegistry.GetTexture(TextureHandle&)` callback.

## Decisions

- Keep the `custom-postprocess-render-entry` r2 crash fix, but reject
  unchanged `VolumeProfile.Add(...)` injected component mounting. It still fails
  in `VolumeComponent.OnEnable()` before `Render(...)`.
- Do not return to broad `GetTexture(TextureHandle&)` resource discovery as a
  production/evaluate path. Runtime evidence already showed severe FPS collapse,
  and the local HDRP xrefs show official DLSS is much narrower.
- Treat ProjectM's existing concrete custom postprocess `Render(...)` methods as
  a real, already-mounted HDRP postprocess boundary. They receive
  `cmd/source/destination` and issue `HDUtils.DrawFullScreen`.
- Treat `HDRenderPipeline.DoDLSSPass` / `DoDLSSPasses` / `RenderPostProcess` as
  the most relevant official-boundary symbols for the next static/runtime probe.
- Do not assume patching `CustomPostProcessVolumeComponent.Render` catches the
  concrete overrides; the cached refs suggest virtual dispatch. A probe should
  patch concrete ProjectM render overrides or the HDRP
  `CustomPostProcessPass` method directly.

## Next Minimal Route

Implement a default-off, no-native, no-DLSS `hdrp-postprocess-boundary-probe`
that only logs whether these boundaries are actually reached in menu/gameplay:

- `HDRenderPipeline.RenderPostProcess`
- `HDRenderPipeline.DoDLSSPasses`
- `HDRenderPipeline.DoDLSSPass`
- `HDRenderPipeline.CustomPostProcessPass`
- The concrete ProjectM custom postprocess `Render(...)` methods listed above

The probe must be throttled, must not call `GetTexture(TextureHandle&)`, must
not issue command-buffer work, and must not evaluate DLSS. Its purpose is to
choose one safe execution boundary for the next resource/evaluate preflight.
