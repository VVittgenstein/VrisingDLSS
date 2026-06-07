# HDRP DLSS Official Boundary Equivalent Point - 2026-06-07

Status: narrow source/metadata refresh. No game launch.

## Question

Where does Unity HDRP/RenderGraph's official DLSS path obtain actual resources
and submit evaluate, and is there a BepInEx/Harmony-accessible boundary with
equivalent safety properties?

This pass intentionally did not repeat broad DLSS performance or generic
integration searches. Local/upstream source and V Rising interop evidence were
checked first; network search only filled exact documentation/source gaps.

## Local Source Evidence

Primary local source:

- `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.high-definition\Runtime\RenderPipeline\HDRenderPipeline.PostProcess.cs`
- `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.high-definition\Runtime\RenderPipeline\RenderPass\DLSSPass.cs`
- `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.core\Runtime\RenderGraph\RenderGraph.cs`
- `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.core\Runtime\RenderGraph\RenderGraphResourceRegistry.cs`

Pinned source facts:

- `RenderPostProcess(...)` schedules `DoDLSSPasses(...)` around the HDRP
  upsampler injection points.
- `DoDLSSPasses(...)` returns the input unchanged unless `m_DLSSPassEnabled` and
  the current HDRP `DLSSInjectionPoint` match.
- `DoDLSSPass(...)` records a RenderGraph pass named
  `Deep Learning Super Sampling`, declares `source`, `output`, `depth`,
  `motionVectors`, and optional `biasColorMask`, and writes the output through
  `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`.
- The actual boundary is the pass render function:
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(data.resourceHandles), ctx.cmd)`.
- `DLSSPass.GetCameraResources(...)` converts the recorded handle group to
  actual `Texture` fields through `GetViewResources(...)`.
- `DLSSPass.Render(...)` enters the NVIDIA path when compiled with the NVIDIA
  module, prepares input/output resolutions from `HDCamera.actualWidth/height`
  and `DynamicResolutionHandler.instance.finalViewport`, then submits
  `SubmitDlssCommands(...)`.
- `SubmitDlssCommands(...)` builds the DLSS texture table
  `colorInput/colorOutput/depth/motionVectors/biasColorMask` and calls
  `ExecuteDLSS(...)`.
- `RenderGraph.ExecuteCompiledPass(...)` executes:
  `PreRenderPassExecute(...) -> pass.Execute(...) -> PostRenderPassExecute(...)`.
  This is why resource availability belongs to the execution window, not pass
  recording.
- `RenderGraphResourceRegistry.GetTexture(TextureHandle)` calls
  `GetTextureResource(handle.handle)`, reads `graphicsResource`, and throws when
  a non-imported texture has not been created or was already released.
- `CreateTextureCallback(...)` runs from pooled resource creation and optional
  clear/fast-memory setup. It is not the DLSS evaluate boundary.

## V Rising Interop Evidence

Fresh local metadata probe:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\probe-vrising-render-metadata.ps1 -GamePath "C:\Software\VRising" -Json
```

Relevant positive evidence:

- `HDRenderPipeline.RenderPostProcess`
- `HDRenderPipeline.GetPostprocessUpsampledOutputHandle`
- `HDRenderPipeline.DoDLSSPasses`
- `HDRenderPipeline.DoDLSSPass`
- `HDRenderPipeline.FinalPass`
- `DLSSPass.ViewResourceHandles` with `source`, `output`, `depth`,
  `motionVectors`, `biasColorMask`
- `DLSSPass.ViewResources` with matching `Texture` fields
- `DLSSPass.GetViewResources`
- `DLSSPass.CreateCameraResources`
- `DLSSPass.GetCameraResources`
- `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)`
- `RenderGraphResourceRegistry.GetTexture(ref TextureHandle)`
- `RenderGraphResourceRegistry.GetTextureResource(ref ResourceHandle)`
- `RenderGraphResourceRegistry.CreateTextureCallback(...)`
- `RenderGraph.CompileRenderGraph(int)`
- `RenderGraph.ExecuteCompiledPass(ref CompiledPassInfo)`
- `RenderGraph.PreRenderPassExecute(ref CompiledPassInfo, RenderGraphPass, RenderGraphContext)`
- `RenderGraph.PostRenderPassExecute(ref CompiledPassInfo, RenderGraphContext)`

Direct `ilspycmd` inspection with `DOTNET_ROOT=C:\Software\dotnet` confirmed:

- `HDRenderPipeline.__c._DoDLSSPass_b__969_0(DLSSData, RenderGraphContext)`
  exists with metadata token `100664365`.
- `DLSSPass.GetCameraResources(...)` and `DLSSPass.Render(..., CommandBuffer)`
  exist as generated interop wrappers.
- `RenderGraphResourceRegistry.current`, `GetTexture(ref TextureHandle)`,
  `GetTextureResource(ref ResourceHandle)`, `BeginExecute(int)`, and
  `EndExecute()` exist.
- `RenderGraph.m_RenderPasses`, `GetCompiledPassInfos()`,
  `CompileRenderGraph(int)`, `ExecuteCompiledPass(ref CompiledPassInfo)`,
  `PreRenderPassExecute(...)`, `PostRenderPassExecute(...)`, and
  `ClearRenderPasses()` exist.

Relevant negative evidence:

- Metadata string scan still reports no complete Unity NVIDIA runtime stack:
  `DLSSContext`, `DLSSCommandInitializationData`, `DLSSTextureTable`,
  `DLSSQuality`, `NVUnityPlugin`, `NGX`, and `nvsdk_ngx` are absent.
- `DLSSPass.GetCameraResources(...)` generated interop wrapper shows
  `CallerCount(0)`, consistent with no observed official DLSS pass execution in
  current V Rising runs.

## Network Blind-Spot Checks

Checked references:

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
- Unity RenderGraph writing guide:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4016.0/manual/render-graph-writing-a-render-pipeline.html`
- Unity TextureHandle API:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/api/UnityEngine.Rendering.RenderGraphModule.TextureHandle.html`
- Unity HDRP DLSS manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/deep-learning-super-sampling-in-hdrp.html`
- Unity HDRP Camera manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/HDRP-Camera.html`
- BepInEx runtime patching:
  `https://docs.bepinex.dev/articles/dev_guide/runtime_patching.html`
- NVIDIA Streamline DLSS programming guide:
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md`
- NVIDIA Streamline programming guide:
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
- NVIDIA NGX programming guide:
  `https://docs.nvidia.com/ngx/latest/programming-guide/`
- OptiScaler README/config:
  `https://github.com/optiscaler/OptiScaler`
  `https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini`

Useful confirmations:

- Unity RenderGraph docs say actual resource references are accessible only
  inside render-pass execution code. They also say resources are created before
  the first pass that needs them and released after the last pass that needs
  them.
- Unity TextureHandle docs say handles belong to one record+execute phase and
  may not represent actual textures if the graph culls the pass/resource.
- Unity HDRP DLSS docs tie DLSS to the NVIDIA package, HDRP Dynamic Resolution,
  HDRP asset DLSS enablement, and camera Allow Dynamic Resolution / Allow DLSS.
- Streamline requires render-resolution input color, final-resolution output
  color, depth, and motion-vector resource tags. It emphasizes current-frame
  lifetimes and evaluation on the relevant command list.
- NGX evaluate requires concrete graphics resources and cautions that DirectX
  evaluate can mutate command-list state, so host code must manage state around
  the evaluate boundary.
- OptiScaler intercepts existing upscaler API inputs. Its model assumes the game
  already calls DLSS/XeSS/FSR-style APIs; it does not solve Unity RenderGraph
  resource discovery for a game whose official DLSS pass is not executing.

## Boundary Classification

| Boundary | Provides | Local status | Decision |
| --- | --- | --- | --- |
| `DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render(ctx.cmd)` | Exact official resource conversion and evaluate boundary | Source and interop confirmed; built-in DLSS runtime stack not present/active | Design map only |
| `DLSSPass.Render(...)` Harmony patch | Exact evaluate method | Previously crashed in `UnityPlayer.dll` after patching, before prefix log | Rejected |
| Generated render funcs, including `_DoDLSSPass_b__969_0(...)` | Official execution window | Broad generated render-func patching previously crashed in `coreclr.dll` | Rejected as normal route |
| `RenderGraph.PreRenderPassExecute(...)` / `ExecuteCompiledPass(...)` / `PostRenderPassExecute(...)` | Near-execution resource creation/executor window | Ref-`CompiledPassInfo` family already crashed or is adjacent to rejected wrapper | Rejected for next normal diagnostic |
| `RenderGraph.CompileRenderGraph(int)` postfix | Safe pass list/pass data snapshot before cleanup | Menu and protected gameplay proofs passed | Metadata/pass-shape only |
| `RenderGraphResourceRegistry.GetTextureResource(ref ResourceHandle)` from proven EASU tuple | TextureResource metadata | Menu and gameplay resolve proofs passed; `graphicsResource` stayed null | Metadata-only, not native pointer |
| `RenderGraphResourceRegistry.CreateTextureCallback(...)` | Pooled creation/clear callback | Patch-stable; prior materialization-only gameplay emitted no useful tuple boundary | Rejected as replacement boundary |
| Passive `RenderGraphResourceRegistry.GetTexture(ref TextureHandle)` postfix | Engine-owned valid-scope RTHandle/native pointer oracle | Proved tuples/evaluate earlier; broad steady-state use caused severe performance collapse | Diagnostic oracle only |
| `DLSSPass.GetViewResources` / `GetCameraResources` helper patch | Closest official handle-to-texture conversion helper | Short isolated helper patch did not crash but no calls observed; likely needs official DLSS pass to execute | Research-only |
| `DynamicResolutionHandler.Update(...)` | Stable per-frame driver | Useful for scale/cached-driver diagnostics; real evaluate crashed in NVIDIA D3D11 driver path | Not an evaluate boundary |

## Answer

The official HDRP DLSS boundary is exactly:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

There is still no proven safe BepInEx/Harmony boundary that is equivalent to
that official execution window in V Rising. The closest exact managed wrappers
either already crashed when patched, only run if the built-in DLSS pass is
active, or expose metadata before actual resources exist.

The only narrow next experiment that fits the current evidence is not a
production evaluate boundary. It is a separately guarded actual native
texture-pointer preflight that passively listens to engine-owned
`RenderGraphResourceRegistry.GetTexture(ref TextureHandle)` callbacks, but only
for handles already proven by the native EASU render-func tuple
`source/destination`, and then immediately disables/fast-skips after first
source+destination pointer proof.

That preflight must remain:

- default-off;
- no generated render-func Harmony patch;
- no direct/prefix-time `GetTexture(...)` call;
- no command-buffer access;
- no D3D11 texture validation unless explicitly separated later;
- no NGX/DLSS evaluate;
- no steady-state broad `GetTexture` logging.

If that preflight observes native pointers only when Unity itself calls
`GetTexture(...)`, it gives a safer pointer-availability proof. It still does
not by itself establish a production evaluate point.
