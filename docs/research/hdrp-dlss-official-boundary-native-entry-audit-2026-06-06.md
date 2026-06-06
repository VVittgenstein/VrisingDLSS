# HDRP DLSS Official Boundary Native-Entry Audit - 2026-06-06

Status: narrow source/search audit after the `native-renderfunc-entry` menu and
protected gameplay proofs. No game launch in this pass.

## Question

In Unity HDRP/RenderGraph, where does the official DLSS path obtain actual
resources and submit evaluate, and is there a BepInEx/Harmony-accessible
boundary with the same lifetime/order guarantees?

This pass intentionally avoids broad DLSS theory or generic performance
searches. Local/upstream source and local V Rising evidence are primary; network
sources only fill exact RenderGraph, DLSS, and patching-model gaps.

## Version Anchors

- V Rising test install: `C:\Software\VRising`
- V Rising Unity player: `2022.3.58f1 (ed7f6eacb62e)`
- Local upstream source: `ref/UnityGraphics-2022.3`, branch `2022.3/staging`,
  commit `03ca85dffdde4b7bc1d6870074e6f5ff9f0352a3`
- Local source snapshot is close enough for HDRP/CoreRP structure, but V Rising
  interop/runtime evidence remains authoritative for patchability.

## Official HDRP Boundary

The official HDRP DLSS path is:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> "Deep Learning Super Sampling" RenderGraph render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`

Local source anchors:

- `HDRenderPipeline.PostProcess.cs` line `455` creates the upsampled
  post-process output handle through `GetPostprocessUpsampledOutputHandle(...)`.
- `RenderPostProcess(...)` calls `DoDLSSPasses(...)` at the HDRP upsampler
  schedule points: lines `526`, `552`, and `604`.
- `DoDLSSPasses(...)` gates on the configured DLSS injection point and calls
  `DoDLSSPass(...)`: lines `708-717`.
- `DoDLSSPass(...)` records the RenderGraph pass named
  `Deep Learning Super Sampling`, declares `source`, `output`, `depth`,
  `motionVectors`, and optional `biasColorMask`, and writes the output to
  `"DLSS destination"`: lines `720-748`.
- The DLSS render function submits through
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(...), ctx.cmd)`:
  lines `751-754`.
- `DLSSPass.cs` converts `TextureHandle` values to real `Texture` resources in
  `GetViewResources(...)` and `GetCameraResources(...)`: lines `40-105`.
- `DLSSPass.Render(...)` forwards to `InternalNVIDIARender(...)`: lines
  `197-204`.
- `InternalNVIDIARender(...)` builds current-frame quality, input/output
  resolution, jitter, reset, and calls `cameraState.SubmitCommands(...)`: lines
  `687-713`.

The nearest active V Rising path is still the built-in EASU upscaler pass:
`Edge Adaptive Spatial Upsampling` declares `source` and upsampled
`destination`, then runs a `SetRenderFunc(...)` with `RenderGraphContext ctx`
and command-buffer compute dispatch. Local source: `HDRenderPipeline.PostProcess.cs`
lines `5028-5067`.

## RenderGraph Lifetime Constraint

Core RenderGraph source explains why the official boundary matters:

- `ExecuteCompiledPass(...)` runs
  `PreRenderPassExecute(...) -> pass.Execute(ctx) -> PostRenderPassExecute(...)`:
  `RenderGraph.cs` lines `1465-1484`.
- `PreRenderPassExecute(...)` creates resources and sets render targets before
  the pass body: `RenderGraph.cs` lines `1552-1597`.
- `RenderGraphPass<T>.Execute(...)` invokes the stored render delegate with pass
  data and `RenderGraphContext`: `RenderGraphPass.cs` lines `141-143`.
- `RenderGraphResourceRegistry.GetTexture(...)` throws if a non-imported
  texture has not been created or was already released:
  `RenderGraphResourceRegistry.cs` lines `103-113`.
- `CreateTextureCallback(...)` is called during pooled resource creation and
  performs allocation/clear/fast-memory work; it is not a targeted upscaler
  submission boundary: `RenderGraphResourceRegistry.cs` lines `445-490`.

Therefore the production evaluate boundary cannot be `GetTexture` discovery or
`CreateTextureCallback` materialization alone. It must be aligned with the
specific upscaler pass execution window, after current resources exist and while
the pass command buffer is valid.

## Network Blind-Spot Checks

The refreshed network checks reinforce the local answer:

- Unity RenderGraph documentation separates pass setup from rendering and says
  resource handles are converted to actual resources inside the render function;
  outside that function, resources may not be allocated yet.
- Unity HDRP DLSS documentation confirms the official path depends on HDRP
  Dynamic Resolution, HDRP Asset DLSS enablement, camera Allow Dynamic
  Resolution / Allow DLSS, and the NVIDIA package.
- NVIDIA Streamline's DLSS guide requires render-resolution color,
  final-resolution output, depth, and motion vectors, tags them for the current
  frame/viewport, and calls evaluate at the point where upscaling happens on the
  rendering thread.
- BepInEx documentation confirms generic HarmonyX and RuntimeDetour support, but
  generic patching capability does not override V Rising-specific crash/silent
  wrapper evidence.
- MonoMod's `NativeDetour` documentation matches the risk model: native detours
  are a different tool from normal managed Harmony patches and cannot be treated
  as routine wrapper patching.
- OptiScaler's public model is also boundary-driven: it intercepts existing
  upscaler inputs in games that already expose DLSS/FSR2/XeSS-style temporal
  upscaling, rather than discovering arbitrary textures in a hot global loop.

No new third-party source files were needed because the already cached reference
set under `ref/hdrp-rendergraph-boundary-2026-06-06`, `ref/UnityGraphics-2022.3`,
`ref/NVIDIA-Streamline`, and `ref/OptiScaler` covers the narrow evidence.

## Boundary Classification

| Candidate | Decision |
| --- | --- |
| `RenderGraph.CompileRenderGraph(int)` | Accepted as read-only map evidence only; too early for evaluate. |
| pass list/declarations/pass data/render-func metadata | Accepted as compile-time evidence only. |
| global `RenderGraphResourceRegistry.GetTexture(...)` postfix | Diagnostic tuple oracle only; too hot for steady-state production. |
| `CreateTextureCallback(...)` | Rejected as replacement boundary; prior materialization-only gameplay produced no useful candidate signal. |
| `DynamicResolutionHandler.Update(...)` cached driver | Rejected as real evaluate boundary; real evaluate crashed in `nvwgf2umx.dll`. |
| `DLSSPass.GetCameraResources(...)` | Research-only; no callbacks observed and likely only fires through native/generated execution if the official DLSS pass exists. |
| `DLSSPass.Render(...)` | Rejected; targeted Harmony patch crashed before prefix signal. |
| `RenderGraph.PreRenderPassExecute(...)` / executor wrappers | Rejected as next normal route; prior patch crashed in `coreclr.dll`. |
| `RenderGraphPass<T>.Execute` / `RenderFunc<T>.Invoke` managed wrappers | Rejected as normal Harmony route; interop wrapper evidence and runtime probes were silent. |
| compiler-generated HDRP render funcs by Harmony | Rejected as normal route; prior broad generated-renderfunc patching crashed. |
| exact pass `method_ptr` native entry detour | Currently most plausible execution-boundary approach, but only as a separate default-off native risk class. Entry counting is proven menu/gameplay-safe; resource/argument use is not yet proven. |

## Current Decision

The official answer is stable: HDRP obtains resources and submits DLSS inside the
`Deep Learning Super Sampling` RenderGraph render function, specifically at
`DoDLSSPass -> DLSSPass.GetCameraResources -> DLSSPass.Render(ctx.cmd)`.

There is still no proven safe BepInEx/Harmony-equivalent boundary in V Rising.
After the `native-renderfunc-entry` proofs, the best current direction is no
longer another managed Harmony wrapper or hot `GetTexture` loop. It is a
separate default-off native-entry argument preflight:

- target one already-mapped exact upscaler pass `method_ptr`;
- sample raw callback arguments only;
- do not dereference pointers in the callback;
- do not touch resources or command buffers;
- do not call DLSS;
- run menu-first, then protected `11111` gameplay only after menu proof;
- restore release-safe config and save state after every runtime attempt.

Only if that argument preflight proves stable should a later design consider how
to identify `passData` / `RenderGraphContext` / `CommandBuffer` safely enough to
approach the official pass-owned evaluate boundary.

## Sources

- Unity Graphics source snapshot:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- Unity Graphics source snapshot:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- Unity Graphics source snapshot:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
- Unity Graphics source snapshot:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphPass.cs`
- Unity Graphics source snapshot:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`
- Unity RenderGraph writing guide:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/manual/render-graph-writing-a-render-pipeline.html
- Unity HDRP DLSS guide:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/deep-learning-super-sampling-in-hdrp.html
- NVIDIA Streamline DLSS programming guide:
  https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md
- BepInEx runtime patching docs:
  https://docs.bepinex.dev/master/articles/dev_guide/runtime_patching.html
- MonoMod RuntimeDetour docs:
  https://monomod.github.io/api/MonoMod.RuntimeDetour.html
- OptiScaler README:
  https://github.com/optiscaler/OptiScaler
