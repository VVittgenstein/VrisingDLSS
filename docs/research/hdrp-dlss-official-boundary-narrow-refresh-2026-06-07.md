# HDRP DLSS Official Boundary Narrow Refresh - 2026-06-07

Status: source/interoperability refresh. No game launch.

## Question

In Unity HDRP/RenderGraph, where does the official DLSS path obtain live
resources and submit evaluate, and is there an equivalent boundary that a
BepInEx/Harmony mod can safely approach?

This refresh intentionally avoids broad DLSS performance theory. Local/upstream
source and V Rising IL2CPP interop are primary. Web references only fill narrow
source/API gaps.

## Local Source Answer

Primary source files:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`

The official HDRP DLSS boundary is:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`

Pinned details:

- `RenderPostProcess(...)` schedules `DoDLSSPasses(...)` at HDRP dynamic
  resolution upsampler injection points.
- `DoDLSSPasses(...)` returns the source unchanged unless `m_DLSSPassEnabled`
  is true and the current schedule matches the HDRP asset `DLSSInjectionPoint`.
- `DoDLSSPass(...)` adds a RenderGraph pass named
  `Deep Learning Super Sampling`.
- That pass declares `source`, `output`, `depth`, `motionVectors`, and optional
  `biasColorMask`; output is
  `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`.
- The actual evaluate-adjacent line is in the pass render function:
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(data.resourceHandles), ctx.cmd)`.
- `DLSSPass.GetCameraResources(...)` converts the handle group to actual
  `Texture` objects via `GetViewResources(...)`.
- `DLSSPass.Render(...)` enters the NVIDIA path when compiled with the NVIDIA
  module; `SubmitDlssCommands(...)` builds the texture table and calls
  `ExecuteDLSS(...)`.
- `RenderGraph.ExecuteCompiledPass(...)` executes
  `PreRenderPassExecute(...) -> pass.Execute(...) -> PostRenderPassExecute(...)`.
  This makes pass execution the live resource/command-buffer boundary.
- `RenderGraphResourceRegistry.GetTexture(TextureHandle)` reads
  `TextureResource.graphicsResource` and throws when a non-imported texture is
  not created or is already released.
- `CreateTextureCallback(...)` is resource creation/clear support, not the DLSS
  evaluate boundary.

## V Rising Interop Evidence

Direct `ilspycmd` inspection of
`C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.HighDefinition.Runtime.dll`
and `Unity.RenderPipelines.Core.Runtime.dll` confirmed:

- `HDRenderPipeline.RenderPostProcess` token `100663789`.
- `HDRenderPipeline.GetPostprocessUpsampledOutputHandle` token `100663787`.
- `HDRenderPipeline.DoDLSSPasses` token `100663792`.
- `HDRenderPipeline.DoDLSSPass` token `100663793`.
- Generated official DLSS render func
  `HDRenderPipeline.__c._DoDLSSPass_b__969_0(DLSSData, RenderGraphContext)`
  token `100664365`.
- Current FSR/EASU analogs
  `_EdgeAdaptiveSpatialUpsampling_b__1066_0` token `100664389` and
  `_FinalPass_b__1069_0` token `100664390`.
- `DLSSPass.GetViewResources`, `DLSSPass.CreateCameraResources`,
  `DLSSPass.GetCameraResources`, and
  `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)`.
- `DLSSPass.GetCameraResources(...)` interop wrapper reports `CallerCount(0)`,
  consistent with no observed official DLSS pass execution in current runs.
- `RenderGraphResourceRegistry.current`, `BeginExecute(int)`, `EndExecute()`,
  `GetTexture(ref TextureHandle)`, `GetTextureResource(ref ResourceHandle)`,
  and `CreateTextureCallback(...)`.
- `RenderGraph.CompileRenderGraph(int)`, `ExecuteCompiledPass(ref CompiledPassInfo)`,
  `PreRenderPassExecute(...)`, `PostRenderPassExecute(...)`, and
  `RenderGraphPass<TPassData>` wrapper shapes.

Negative runtime/interoperability facts remain binding:

- Direct `DLSSPass.Render(...)` Harmony patch crashed in `UnityPlayer.dll`.
- Generated render-func Harmony patching is rejected as a normal route because
  the family previously crashed in `coreclr.dll`.
- `PreRenderPassExecute(...)` patched but then crashed in `coreclr.dll`.
- Closed `RenderGraphPass.GetExecuteDelegate<TPassData>()` patched safely but
  produced zero focused callback lines; the IL2CPP runtime does not have to
  traverse the managed wrapper.
- `RenderGraphPass<T>.Execute(...)`, `RenderFunc<T>.Invoke(...)`, and open
  generic patch routes are rejected/no-signal with the current interop path.
- `CreateTextureCallback(...)` is patch-stable but not an equivalent
  consumption/evaluate boundary.
- Passive engine-owned `GetTexture(ref TextureHandle)` is proven as a diagnostic
  oracle and now has focused native-pointer menu plus protected gameplay proof,
  but broad steady-state use is too hot and it still does not provide `ctx.cmd`.

## Narrow Web Checks

Checked sources:

- Unity Graphics 2022.3 `HDRenderPipeline.PostProcess.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- Unity Graphics 2022.3 `DLSSPass.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- Unity Graphics 2022.3 `RenderGraph.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
- Unity Graphics 2022.3 `RenderGraphResourceRegistry.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`
- Unity RenderGraph fundamentals:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/manual/render-graph-fundamentals.html`
- BepInEx runtime patching:
  `https://docs.bepinex.dev/master/articles/dev_guide/runtime_patching.html`
- NVIDIA NGX programming guide:
  `https://docs.nvidia.com/ngx/programming-guide/index.html`
- NVIDIA Streamline programming guide:
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
- OptiScaler README:
  `https://github.com/optiscaler/OptiScaler`

Useful confirmations:

- Unity RenderGraph docs confirm actual resources are accessible only inside a
  render pass execution function, and graph resources are created immediately
  before first needed pass and released after last use.
- BepInEx confirms HarmonyX/RuntimeDetour are supported runtime patching tools,
  but this does not override method-specific IL2CPP crash/no-signal evidence.
- NGX evaluate needs concrete graphics resources and DirectX command-list/context
  ownership; the host must manage state around evaluate.
- Streamline uses current-frame resource tagging/evaluate and explicit resource
  lifetimes. This reinforces that DLSS belongs at a real upscaling/evaluate
  point, not a broad texture-discovery callback.
- OptiScaler intercepts existing upscaler API calls and redirects inputs to an
  output backend. That assumes the game already reaches an upscaler API boundary;
  it does not solve Unity RenderGraph resource discovery when V Rising's built-in
  DLSS pass is absent/inactive.

## Custom Post Process Blind Spot

One local source-backed candidate is worth separating from Harmony patching:
HDRP Custom Post Process.

`DoCustomPostProcess(...)` looks up component type strings from HDRP global
settings, finds the component in the camera volume stack, records a RenderGraph
pass, reads/binds depth, normal, motion-vector, source, and destination handles,
sets global textures, then calls:

`customPostProcess.Render(ctx.cmd, hdCamera, source, destination)`.

This is a real HDRP-owned render-function boundary with a current
`CommandBuffer`, source/destination RTHandles, and globally bound depth/motion
textures. It is not a Harmony patch and could be a BepInEx-driven route if a mod
can safely register an IL2CPP `CustomPostProcessVolumeComponent` and insert it
into HDRP global settings plus the active volume stack.

Important limits:

- It is not the official DLSS pass and does not automatically provide
  `DLSSPass.CameraResources`.
- It likely requires proving managed/BepInEx component registration in V Rising
  IL2CPP before any native/DLSS work.
- It still needs a separate guard and probably a no-DLSS smoke proof:
  can the custom post-process `Render(...)` run in menu/gameplay at `1920x1080`
  Windowed with no resource resolution beyond its arguments and no native calls?

## Boundary Classification

| Boundary | Resource/cmd availability | V Rising status | Decision |
| --- | --- | --- | --- |
| Official `DoDLSSPass -> DLSS render func -> GetCameraResources -> Render(ctx.cmd)` | Exact official DLSS resources plus current command buffer | Source/interop confirmed; built-in NVIDIA stack absent/inactive | Design map only |
| `DLSSPass.Render(...)` Harmony patch | Exact wrapper | Crashed in `UnityPlayer.dll` | Rejected |
| Generated render funcs, including `_DoDLSSPass_b__969_0` and EASU/Final closures | Current pass execution | Prior generated family crash; do not rerun unchanged | Rejected as normal route |
| `PreRenderPassExecute` / `ExecuteCompiledPass` / `PostRenderPassExecute` | Executor window | Ref-wrapper family crashed/no-signal | Rejected |
| `GetExecuteDelegate<T>` / `RenderGraphPass<T>.Execute` / `RenderFunc<T>.Invoke` | Conceptual execution layer | Patch-stable/no-signal or not patchable in current IL2CPP route | Rejected as next normal route |
| `CompileRenderGraph(int)` pass-list/declaration/pass-data/renderfunc metadata | Safe metadata before execution | Menu + protected gameplay proofs passed | Observation only |
| Focused native render-func tuple/native-pointer preflight | EASU source/destination pointer proof through Unity-owned `GetTexture` | Menu + protected gameplay proofs passed | Diagnostic pointer oracle only |
| `CreateTextureCallback(...)` | Creation/clear callback | Patch-stable but no useful tuple boundary | Not equivalent |
| `DynamicResolutionHandler.Update(...)` | Stable per-frame scale driver | Useful for render-scale diagnostics; not ordered like official evaluate | Not evaluate boundary |
| HDRP Custom Post Process component | Current `cmd`, source/destination, global depth/motion bindings | Source-backed only; V Rising component registration unproven | New BepInEx route candidate |

## Answer

The official HDRP DLSS resource/evaluate boundary is the `Deep Learning Super
Sampling` RenderGraph pass render function:

`DLSSPass.GetCameraResources(data.resourceHandles)` immediately followed by
`data.pass.Render(..., ctx.cmd)`.

There is still no proven safe Harmony patch boundary in V Rising that is
equivalent to that execution window. The currently proven safe surfaces are
metadata observation (`CompileRenderGraph`) and focused passive native-pointer
observation through Unity-owned `GetTexture(...)`; neither provides a production
evaluate point.

The next useful search/design branch should not be another broad DLSS search and
should not rerun rejected Harmony wrappers unchanged. The only newly interesting
source-backed direction from this refresh is a separate HDRP Custom Post Process
registration proof. It could provide a BepInEx-accessible HDRP-owned
`CommandBuffer` boundary without patching generated render funcs, but it first
needs its own no-native/no-DLSS menu proof.
