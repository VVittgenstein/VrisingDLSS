# HDRP DLSS Resource Resolve Boundary Narrow Search - 2026-06-07

Question: in Unity HDRP/RenderGraph, where does the official DLSS path obtain
actual resources and submit evaluate, and is there a BepInEx/Harmony-adjacent
equivalent boundary we can safely approach?

## Priority And Scope

This was a narrow refresh, not a broad DLSS/performance search. Local/upstream
source and V Rising metadata/runtime evidence remain primary. Web search only
filled specific source/link gaps around:

- `HDRenderPipeline.DoDLSSPasses`
- `HDRenderPipeline.DoDLSSPass`
- `DLSSPass`
- `GetPostprocessUpsampledOutputHandle`
- RenderGraph resource conversion semantics
- `RenderGraphResourceRegistry.GetTextureResource`
- OptiScaler-style upscaler interception/resource tagging

## Local/Upstream Findings

Primary local files:

- `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.high-definition\Runtime\RenderPipeline\HDRenderPipeline.PostProcess.cs`
- `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.high-definition\Runtime\RenderPipeline\RenderPass\DLSSPass.cs`
- `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.core\Runtime\RenderGraph\RenderGraphResourceRegistry.cs`

Official HDRP DLSS flow:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`

Important source points:

- `DoDLSSPasses(...)` gates on `m_DLSSPassEnabled` and the configured
  `DLSSInjectionPoint`, then calls `DoDLSSPass(...)`.
- `DoDLSSPass(...)` records a RenderGraph pass named
  `Deep Learning Super Sampling`.
- The pass declares source/output/depth/motion-vector handles. Output is
  declared through `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`.
- The actual submission is inside `builder.SetRenderFunc(...)`, where HDRP calls
  `DLSSPass.GetCameraResources(data.resourceHandles)` and then
  `data.pass.Render(data.parameters, ..., ctx.cmd)`.
- `DLSSPass.Render(...)` forwards to the NVIDIA-specific path when the NVIDIA
  module is compiled in; `SubmitDlssCommands(...)` builds a texture table and
  submits `ExecuteDLSS(...)`.
- `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` first calls
  `GetTextureResource(ResourceHandle&)`, then reads `graphicsResource`, and can
  throw when the actual resource is not valid yet.
- `GetTextureResource(ResourceHandle&)` returns the registry `TextureResource`
  metadata object. It is a narrower, earlier diagnostic than `GetTexture(...)`,
  and it does not by itself prove native texture pointer availability.
- `CreateTextureCallback(...)` runs during pooled resource creation/clear. It is
  not the DLSS evaluate boundary; prior local materialization-only gameplay
  already failed to produce a useful replacement tuple boundary.

## Web References Checked

- Unity Graphics 2022.3 `HDRenderPipeline.PostProcess.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- Unity Graphics 2022.3 `DLSSPass.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- Unity Graphics 2022.3 `RenderGraphResourceRegistry.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`
- Unity RenderGraph writing guide:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4011.0/manual/render-graph-writing-a-render-pipeline.html`
- OptiScaler README:
  `https://github.com/optiscaler/OptiScaler`
- OptiScaler config:
  `https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini`

## OptiScaler Takeaway

OptiScaler is useful as a design comparison, but not as a direct boundary answer.
Its README describes a middleware model: it intercepts existing upscaler input
calls from the game and redirects them to another backend. Its config exposes
resource tagging switches such as depth/velocity/HUDless validity, and input
hooks for DLSS/XeSS/FSR families. That assumes the game already reaches a modern
upscaler API call path.

For V Rising, the problem is earlier: finding a safe Unity HDRP/BepInEx boundary
equivalent to the official RenderGraph DLSS render function. OptiScaler therefore
supports the principle "reuse a real upscaler boundary when one exists", but it
does not give a safe Harmony patch point for Unity HDRP RenderGraph/IL2CPP.

## Boundary Decision

Do not jump to:

- Generated HDRP render-func Harmony patches.
- Direct `DLSSPass.Render(...)` patches.
- Calling `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` outside an
  engine-owned valid render-func/resource scope.
- Reusing `CreateTextureCallback(...)` as a steady-state tuple boundary.
- Driving real evaluate from `DynamicResolutionHandler.Update(...)`.

Next safe step implemented:

`Diagnostics.EnableNativeRenderFuncResourceResolveProbe=false`

Helper stage:

`native-renderfunc-resource-resolve`

This stage reuses the already-proven native render-func entry/argument/resource
identity/tuple path for the focused EASU pass, then resolves only the matched
`source` and `destination` `TextureHandle`s through
`RenderGraphResourceRegistry.GetTextureResource(ResourceHandle&)`. It logs
whether `TextureResource` exists and whether `graphicsResource` is non-null. It
does not call `GetTexture(...)`, read native texture pointers, touch command
buffers, patch generated render functions, or evaluate DLSS.

Expected result interpretation:

- `textureResourceReady=True` for both handles would prove metadata resolution at
  the focused boundary.
- `graphicsResourceReady=False` is not failure by itself; it means this point is
  still metadata-only and actual resource availability remains tied to the
  engine-owned render-func scope.
