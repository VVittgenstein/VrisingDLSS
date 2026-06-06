# HDRP RenderGraph Harmony Boundary Audit - 2026-06-06

Status: narrow post-renderfunc-metadata audit. No game launch in this pass.

## Question

Where does Unity HDRP's official DLSS path obtain resources and submit evaluate,
and is there an equally safe BepInEx/Harmony-accessible boundary in V Rising?

This audit intentionally avoids broad DLSS performance theory. Local Unity
source and V Rising interop/decompile evidence are primary. Network checks only
fill exact documentation and implementation-model gaps.

## Official HDRP Boundary

The official Unity HDRP DLSS boundary is a RenderGraph pass render function:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> "Deep Learning Super Sampling" render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

Local source anchors:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
  records the `Deep Learning Super Sampling` pass in `DoDLSSPass(...)`.
- That pass declares `source`, `output`, `depth`, `motionVectors`, and optional
  `biasColorMask` through `ReadTexture` / `WriteTexture`.
- The pass render function calls
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(data.resourceHandles), ctx.cmd)`.
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
  converts the `TextureHandle` group into real `Texture` resources and submits
  NVIDIA DLSS commands.
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
  executes compiled passes as
  `PreRenderPassExecute -> pass.Execute(ctx) -> PostRenderPassExecute`.

So the official resource/evaluate point is not global texture discovery. It is
inside the specific upscaler pass execution window, with current-frame resources
and the current `RenderGraphContext.cmd`.

## V Rising Local Evidence

V Rising exposes the HDRP symbols as interop landmarks:

- `HDRenderPipeline.RenderPostProcess`
- `HDRenderPipeline.GetPostprocessUpsampledOutputHandle`
- `HDRenderPipeline.DoDLSSPasses`
- `HDRenderPipeline.DoDLSSPass`
- `HDRenderPipeline.FinalPass`
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`
- `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)`
- `RenderGraph.CompileRenderGraph(int)`
- `RenderGraph.ExecuteCompiledPass(ref CompiledPassInfo)`
- `RenderGraph.PreRenderPassExecute(ref CompiledPassInfo, RenderGraphPass, RenderGraphContext)`
- `RenderGraph.PostRenderPassExecute(ref CompiledPassInfo, RenderGraphContext)`

However, the local metadata/runtime scan still does not expose the complete Unity
NVIDIA runtime stack (`DLSSContext`, `DLSSTextureTable`, `DLSSQuality`,
`NVUnityPlugin`, NGX runtime symbols). The built-in HDRP DLSS path remains a map,
not a turnkey route.

The proven V Rising gameplay pass chain is currently:

`Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass`.

The accepted `rendergraph-pass-list`, `rendergraph-pass-declarations`,
`rendergraph-pass-data`, and `rendergraph-renderfunc-metadata` proofs all reused
the safe `RenderGraph.CompileRenderGraph(int)` postfix and kept `GetTexture=0`.
They prove pass order, handle declarations, pass-data fields, and render-func
metadata. They do not prove an execution/evaluate boundary.

## Interop Wrapper Audit

Fresh `ilspycmd` inspection was run against:

- `C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.Core.Runtime.dll`
- `C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.HighDefinition.Runtime.dll`

Key findings:

| Wrapper | Local decompile evidence | Interpretation |
| --- | --- | --- |
| `RenderGraphPass<T>.Execute(RenderGraphContext)` | `CallerCount(0)` and a generated `IL2CPP.il2cpp_runtime_invoke(...)` wrapper | Harmony patching the managed wrapper is unlikely to see actual native pass execution. Open-generic patching was already rejected. |
| `RenderFunc<T>.Invoke(PassData, RenderGraphContext)` | `CallerCount(0)` and a generated `IL2CPP.il2cpp_runtime_invoke(...)` wrapper | Patching delegate `Invoke` is unlikely to observe native execution. |
| `RenderFunc<T>` constructor | `CallerCount(195)` | Observable setup-time delegate construction, but no live resources, no command buffer, and no evaluate authority. |
| `DLSSPass.GetCameraResources(...)` | `CallerCount(0)` despite official source calling it inside the render func | It likely only fires through native/generated code if the official DLSS pass executes. The helper probe already produced no callbacks. |
| `DLSSPass.Render(...)` | `CallerCount(5)` | Exact official submission wrapper, but targeted Harmony patch crashed in `UnityPlayer.dll` before prefix logging. Rejected. |
| `RenderGraph.CompileRenderGraph(int)` | `CallerCount(1)` | Proven safe read-only observation point in menu and protected gameplay. Too early for evaluate. |
| `ExecuteCompiledPass` / `PreRenderPassExecute` / `PostRenderPassExecute` | Ref-`CompiledPassInfo` executor wrapper family | Conceptually close, but `PreRenderPassExecute` already patched then crashed in `coreclr.dll`; do not use adjacent ref-executor wrappers as the next normal route. |

BepInEx also ships `MonoMod.RuntimeDetour.NativeDetour`, including
`IntPtr -> IntPtr` native detour constructors. That means a future lower-level
method-pointer experiment is technically possible from the BepInEx process, but
it is not the same risk class as Harmony and is not yet a proven safe route.

## Network Blind-Spot Checks

Primary-source checks:

- Unity RenderGraph fundamentals:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/manual/render-graph-fundamentals.html
- Unity RenderGraph writing guide:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4016.0/manual/render-graph-writing-a-render-pipeline.html
- Unity `TextureHandle` API:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/api/UnityEngine.Rendering.RenderGraphModule.TextureHandle.html
- Unity HDRP DLSS:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/deep-learning-super-sampling-in-hdrp.html
- NVIDIA Streamline:
  https://developer.nvidia.com/rtx/streamline
- NVIDIA Streamline programming guide:
  https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md
- OptiScaler:
  https://github.com/optiscaler/OptiScaler
  https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini

External evidence reinforces the local answer:

- Unity says actual RenderGraph resources are accessible in render pass execution
  code, not arbitrary setup code.
- Unity says `SetRenderFunc` receives `PassData` plus `RenderGraphContext`, whose
  command buffer is where graphics commands are issued.
- Unity says `TextureHandle` is scoped to one record+execute phase and may not
  represent an actual allocation if the pass is culled.
- Unity HDRP DLSS requires the NVIDIA package, HDRP Dynamic Resolution, HDRP
  Asset DLSS enablement, and per-camera Allow Dynamic Resolution / Allow DLSS.
- Streamline asks integrations to identify the required resources and the
  graphics-pipeline point where the plugin should run.
- OptiScaler's public model is to hook existing DLSS/XeSS/FSR inputs in games
  that already expose a temporal upscaler path. Its INI exposes input hooks and
  resource-lifecycle-style options such as depth/velocity valid-now behavior.

Downloaded reference additions:

- `ref/hdrp-rendergraph-boundary-2026-06-06/OptiScaler.ini`
- `ref/hdrp-rendergraph-boundary-2026-06-06/Unity-RenderGraph-Fundamentals.html`
- `ref/hdrp-rendergraph-boundary-2026-06-06/Unity-RenderGraph-Writing-A-Render-Pipeline.html`
- `ref/hdrp-rendergraph-boundary-2026-06-06/Unity-HDRP-DLSS-16.0.html`
- `ref/hdrp-rendergraph-boundary-2026-06-06/Unity-HDRP-Dynamic-Resolution-13.1.html`
- `ref/hdrp-rendergraph-boundary-2026-06-06/BepInEx-Runtime-Patching.html`

## Decision

There is no currently proven safe BepInEx/Harmony boundary in V Rising that is
equivalent to Unity HDRP's official DLSS evaluate boundary.

Use this classification:

| Boundary | Decision |
| --- | --- |
| `RenderGraph.CompileRenderGraph(int)` postfix | Accepted as read-only map only; too early for evaluate. |
| `m_RenderPasses` / pass-data / renderFunc metadata | Accepted as compile-time evidence only; do not call or patch render funcs from this evidence. |
| `RenderGraphPass<T>.Execute` / `RenderFunc<T>.Invoke` managed wrappers | Rejected as next normal route; wrapper metadata and zero-signal run indicate native execution does not traverse them in a useful way. |
| Compiler-generated HDRP render funcs | Rejected as Harmony route; prior broad patch crashed. |
| `DLSSPass.Render(...)` | Rejected; targeted patch crashed. |
| `DLSSPass.GetCameraResources(...)` | Research-only; no callbacks observed and likely requires the official DLSS pass to execute. |
| `ExecuteCompiledPass` / `PreRenderPassExecute` / `PostRenderPassExecute` | Rejected as next normal route; same ref-executor family as the crashing boundary. |
| `DynamicResolutionHandler.Update(...)` cached driver | Rejected as real evaluate boundary; no-evaluate isolation was useful but real evaluate crashed in `nvwgf2umx.dll`. |
| Global `RenderGraphResourceRegistry.GetTexture(...)` postfix | Keep as diagnostic tuple oracle only; too hot for production placement. |

## Next Safe Work

Do not run another gameplay probe from the existing stages unchanged.

Two next-step branches are possible, and they should stay separate:

1. Low-risk map refinement: add a default-off `CompileRenderGraph(int)` compiled
   pass-info snapshot only if culled/resource-lifetime state is still needed.
   It must stay read-only, no `GetTexture`, no command buffer, no evaluate.

2. Actual execution-boundary approach: design a new `native-renderfunc-entry`
   no-op probe before implementing it. It would use the already proven
   compile-time renderFunc metadata to select one exact EASU or Final Pass
   `method_ptr`, then use a native detour only to count entries. No resources,
   no command buffer, no DLSS, menu first, hard caps, and full cleanup. This is a
   new risk class and should not be treated as ordinary Harmony patching.

Current answer to the narrow question: official HDRP gets resources and submits
DLSS inside the `Deep Learning Super Sampling` RenderGraph render function. V
Rising does not yet have a safe Harmony-equivalent boundary for that window.
