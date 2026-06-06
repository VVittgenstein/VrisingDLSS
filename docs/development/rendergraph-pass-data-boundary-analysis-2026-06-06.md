# RenderGraph Pass Data Boundary Analysis - 2026-06-06

## Question

For Unity HDRP/RenderGraph, where does the official DLSS path obtain live
resources and submit evaluate, and what BepInEx/Harmony-accessible boundary in
V Rising is closest enough to approach safely?

This note is intentionally narrow. It does not revisit broad DLSS performance
theory or generic integration guidance.

## Local/Upstream Evidence

Downloaded reference source is under:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`

Official HDRP DLSS boundary:

- `RenderPostProcess(...)` schedules `DoDLSSPasses(...)` at the HDRP upsampler
  injection points: before post, after depth of field, or after post.
- `DoDLSSPasses(...)` only records DLSS when `m_DLSSPassEnabled` is true and the
  requested schedule matches the HDRP asset `DLSSInjectionPoint`.
- `DoDLSSPass(...)` records a RenderGraph pass named `Deep Learning Super
  Sampling`.
- That pass declares `source`, `output`, `depth`, `motionVectors`, and optional
  `biasColorMask` handles. Its output comes from
  `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`.
- Its render function calls:

```csharp
data.pass.Render(data.parameters, DLSSPass.GetCameraResources(data.resourceHandles), ctx.cmd);
```

That line is the official evaluate-adjacent boundary: it has pass-local handles
converted into real current-frame textures and the current command buffer.

`DLSSPass.cs` confirms the resource conversion and evaluate path:

- `GetViewResources(...)` casts `TextureHandle` values to real `Texture` objects.
- `GetCameraResources(...)` wraps source/output/depth/motion resources for the
  camera/XR view.
- `InternalNVIDIARender(...)` builds DLSS view data from
  `hdCamera.actualWidth/actualHeight`, `DynamicResolutionHandler.instance.finalViewport`,
  TAA jitter, reset state, quality/sharpness settings, then submits the resource
  table via `ExecuteDLSS(...)`.

Current V Rising analogue:

- With DLSS disabled in-game and the mod driving HDRP dynamic resolution, the
  observed chain is `Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass`.
- `EASUData` contains `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`,
  `source`, and `destination`.
- `EdgeAdaptiveSpatialUpsampling(...)` reads `source`, writes
  `GetPostprocessUpsampledOutputHandle(..., "Edge Adaptive Spatial Upsampling")`,
  and dispatches compute in the pass render function.
- `FinalPassData` reads EASU output as `source`, reads UI/alpha/after-post
  resources, and writes the final target. Its render function performs RCAS when
  `performUpsampling` is true and the filter is `EdgeAdaptiveScalingUpres`.
- `UberPostPassData` reads the post source, bloom, and LUT handles and writes the
  EASU input handle.

This makes EASU/Final the best local stage map, but not a complete DLSS input
boundary because EASU has color source/destination only; depth and motion vectors
are separate earlier resources.

## RenderGraph Lifetime Constraint

Core RP source and Unity docs agree:

- RenderGraph setup declares passes and resource handles.
- Compilation culls passes and determines resource lifetimes.
- Execution creates resources immediately before needed passes and releases them
  after last use.
- `RenderGraphResourceRegistry.GetTexture(...)` throws when a non-imported
  resource is not yet created or was already released.
- `RenderGraphPass<PassData>` owns `data` and `renderFunc`, and execution calls
  the render func with `data` plus `RenderGraphContext`.

Therefore:

- `CompileRenderGraph(int)` is safe for pass/declaration/pass-data observation.
- `CompileRenderGraph(int)` is not a DLSS evaluate boundary: no current pass
  command buffer and no guaranteed live textures.
- The real evaluate-equivalent boundary is pass execution.

## V Rising Interop Evidence

`scripts/probe-vrising-render-metadata.ps1 -GamePath C:\Software\VRising -Json`
confirmed that V Rising exposes HDRP DLSS/upscale symbols:

- `HDRenderPipeline.RenderPostProcess`
- `GetPostprocessUpsampledOutputHandle`
- `DoDLSSPasses`
- `DoDLSSPass`
- `DLSSPass.ViewResourceHandles` / `ViewResources`
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`
- `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)`

The same probe still reports the Unity NVIDIA runtime stack as absent from local
metadata/runtime candidates:

- `DLSSContext`
- `DLSSCommandInitializationData`
- `DLSSTextureTable`
- `DLSSQuality`
- `NVUnityPlugin`
- `NGX` / `nvsdk_ngx`

`ilspycmd` on the local interop also confirmed:

- Generated render functions:
  - `_DoDLSSPass_b__969_0(DLSSData, RenderGraphContext)` token `100664365`
  - `_EdgeAdaptiveSpatialUpsampling_b__1066_0(EASUData, RenderGraphContext)` token `100664389`
  - `_FinalPass_b__1069_0(FinalPassData, RenderGraphContext)` token `100664390`
- Exact HDRP recording methods:
  - `EdgeAdaptiveSpatialUpsampling(RenderGraph, HDCamera, TextureHandle)`
  - `FinalPass(RenderGraph, HDCamera, TextureHandle, TextureHandle, TextureHandle, TextureHandle, TextureHandle, BlueNoise, Boolean, CubemapFace, Boolean)`
- `RenderGraphPass<PassData>` has `data`, `renderFunc`, `Execute(...)`, and
  `Initialize(...)`.

This is enough for static field-shape mapping. It is not enough to reclassify
generated render-function Harmony patching as safe.

## Declaration Chain Result

Source log:

`artifacts/gameplay-automation/LogOutput-rendergraph-pass-declarations-gameplay-1080p-20260606-r2.log`

Parsed counts:

| Metric | Count |
| --- | ---: |
| Declaration rows | 529 |
| Distinct compiles | 313 |
| Chain compiles containing Uber/EASU/Final evidence | 286 |
| Complete `Uber -> EASU -> Final` chains | 43 |
| Complete chains where `Uber write == EASU read` | 43 |
| Complete chains where `EASU write == Final first read` | 43 |
| `Uber Post` rows | 279 |
| `Edge Adaptive Spatial Upsampling` rows | 48 |
| `Final Pass` rows | 45 |

Main chain groups:

- `Uber 78 -> EASU 78 -> 79 -> Final 79`: 42 complete chains.
- `Uber 73 -> EASU 73 -> 74 -> Final 74`: 1 complete chain.

Extra EASU/Final-only groups exist (`56 -> 57`, `14 -> final`), and many later
`Uber Post` rows are not followed by EASU/Final in the captured declaration
sample. Do not key a future probe on `Uber Post` alone.

## Narrow Network Checks

Primary checks used only to fill exact blind spots:

- Unity RenderGraph fundamentals: actual resource references are available only
  in pass execution, and graph-created resources do not persist across graph
  executions.
- Unity HDRP DLSS docs: DLSS requires the NVIDIA package, HDRP Dynamic
  Resolution, HDRP Asset DLSS enablement, camera Allow Dynamic Resolution, and
  camera Allow DLSS.
- Unity HDRP Asset docs: DLSS injection points are `Before Post`,
  `After Depth Of Field`, and `After Post Process`.
- NVIDIA Streamline DLSS guide: DLSS needs render-res input color, final-res
  output color, depth, and motion vectors tagged for the current frame; dynamic
  resolution requires explicit extents; evaluate belongs at the upscaling point.
- OptiScaler README/INI: the model is to intercept existing DLSS/FSR2/XeSS
  temporal upscaler calls/resources in games that already expose those inputs.
- BepInEx docs: HarmonyX/RuntimeDetour are supported runtime patching mechanisms,
  but the docs do not override local IL2CPP crash evidence for specific methods.

Downloaded reference snapshots:

- `ref/NVIDIA-Streamline/ProgrammingGuideDLSS.md`
- `ref/OptiScaler/README.md`
- `ref/OptiScaler/OptiScaler.ini`

## Boundary Classification

| Boundary | What it offers | Local status | Decision |
| --- | --- | --- | --- |
| `DLSSPass.Render(...)` | Official DLSS render submission wrapper | Targeted patch crashed in `UnityPlayer.dll` before prefix log | Rejected |
| `_DoDLSSPass_b__969_0(...)` | Official HDRP DLSS render func | Same generated render-func family that broadly crashed in `coreclr.dll`; Unity NVIDIA stack not present | Rejected as next normal route |
| `_EdgeAdaptiveSpatialUpsampling_b__1066_0(...)` | Current command buffer and EASU source/destination | Closest stage sample, but generated render-func family is previously risky and lacks depth/motion | Do not jump here yet |
| `_FinalPass_b__1069_0(...)` | Current command buffer after EASU, final target write | Also generated render-func family; too late for full DLSS inputs by itself | Do not jump here yet |
| Closed `RenderGraphPass<EASUData>.Execute(...)` | The generic pass execution layer for EASU | Static shape exists; open generic patch was rejected and closed-generic runtime stability is unproven | Static-only candidate |
| `RenderGraph.CompileRenderGraph(int)` declarations | Safe pass order and handle declaration map | Passed menu plus protected `11111` gameplay with `GetTexture=0` | Useful observation, not evaluate |
| `RenderGraph.CompileRenderGraph(int)` pass-data snapshot | Same safe point plus pass-data field/handle/dimension mapping | Not implemented yet | Next minimal experiment |

## Decision

The official HDRP DLSS evaluate boundary is:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

There is still no proven safe BepInEx/Harmony-equivalent evaluate boundary in
V Rising.

The next smallest safe step is not another evaluate attempt and not an EASU
render-func patch. It is a default-off `CompileRenderGraph(int)` pass-data
snapshot that reads focused pass `data` fields at the already-proven observation
point:

- `UberPostPassData`: `width`, `height`, `viewCount`, `source`, `destination`,
  `logLut`, `bloomTexture`.
- `EASUData`: `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`,
  `viewCount`, `source`, `destination`.
- `FinalPassData`: `performUpsampling`, `dynamicResIsOn`, `dynamicResFilter`,
  `source`, `destination`, `afterPostProcessTexture`, `alphaTexture`, `uiBuffer`,
  `postProcessIsFinalPass`.

Pass signal:

- EASU `source/destination` match the declaration read/write pair.
- EASU `destination` matches Final `source`.
- EASU dimensions show the expected render-res input and final-res output.
- Final pass shows whether it is doing the EASU/RCAS half of the dynamic-res
  chain.

Fail/stop signal:

- Data field access causes IL2CPP exceptions.
- Pass data is unavailable or not typed as expected.
- Declarations and pass data disagree.
- The probe needs `GetTexture`, native pointers, command-buffer work, or pass
  execution to answer its question.

Only after that pass-data proof should an execution-boundary probe be considered,
and it should start as read-only/no-evaluate/menu-only before any protected
gameplay or DLSS work.
