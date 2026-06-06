# HDRP DLSS RenderGraph Safe Boundary Follow-up - 2026-06-06

Status: narrow source-backed follow-up after the search scope was reduced to one
question.

## Question

Where does Unity HDRP's official DLSS path obtain resources and submit evaluate,
and is there a BepInEx/Harmony-accessible boundary in V Rising with comparable
resource lifetime and command-buffer ordering?

This note intentionally avoids broad DLSS performance theory. Local/upstream
source and local runtime evidence are primary. Network checks only fill exact
documentation gaps.

## Local Source Answer

Official HDRP DLSS is a RenderGraph pass-execution boundary, not a global texture
lookup boundary.

- `HDRenderPipeline.RenderPostProcess(...)` calls `DoDLSSPasses(...)` at the
  HDRP upsampler schedule points: before post, after depth of field, or after
  post. Local source:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
  lines 479, 526, 552, 604, and 708.
- `DoDLSSPass(...)` records a RenderGraph pass named
  `Deep Learning Super Sampling`, declares `source`, `output`, `depth`,
  `motionVectors`, optional `biasColorMask`, and writes output from
  `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`. Local source:
  `HDRenderPipeline.PostProcess.cs` lines 720-754.
- The DLSS pass render function calls
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(...), ctx.cmd)`.
  That is the moment the pass has current-frame resources and the current
  command buffer. Local source: `HDRenderPipeline.PostProcess.cs` line 754.
- `DLSSPass.GetViewResources(...)` and `GetCameraResources(...)` convert
  `TextureHandle` groups into real `Texture` resources. Local source:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
  lines 40 and 91.
- The NVIDIA path builds the texture table and calls `ExecuteDLSS(...)`. Local
  source: `DLSSPass.cs` line 415.

The closest local analogue in V Rising's current path is HDRP's existing EASU
upscaler pass:

- `EdgeAdaptiveSpatialUpsampling(...)` records a RenderGraph pass named
  `Edge Adaptive Spatial Upsampling`.
- It declares `source = builder.ReadTexture(source)` and
  `destination = builder.WriteTexture(GetPostprocessUpsampledOutputHandle(...))`.
- Its render function uses the same execution pattern: pass data plus
  `RenderGraphContext ctx`, actual texture casts/command-buffer compute dispatch,
  and then `SetCurrentResolutionGroup(... AfterDynamicResUpscale)`.
- Local source: `HDRenderPipeline.PostProcess.cs` around lines 5020-5078.

So the theoretical equivalent boundary is "inside the upscaler pass render
function", not `DynamicResolutionHandler.Update(...)`, not broad
`RenderGraphResourceRegistry.GetTexture(...)`, and not `CreateTextureCallback(...)`
alone.

## RenderGraph Timing Constraint

Unity Core source matches the docs:

- `RenderGraph.AddRenderPass(...)` appends passes to `m_RenderPasses` during
  setup. Local source:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
  line 613.
- `CompileRenderGraph()` compiles/culls/lifetimes resources before execution.
  Local source: `RenderGraph.cs` line 1373.
- `ExecuteCompiledPass(...)` executes:
  `PreRenderPassExecute(...) -> pass.Execute(...) -> PostRenderPassExecute(...)`.
  Local source: `RenderGraph.cs` lines 1465-1483.
- `PreRenderPassExecute(...)` creates needed resources and sets render targets
  before pass execution. Local source: `RenderGraph.cs` line 1552.
- `RenderGraphResourceRegistry.GetTexture(...)` returns an `RTHandle`, but throws
  if the resource has not been created or has already been released. Local source:
  `RenderGraphResourceRegistry.cs` line 103.

This explains why prefix-time handle resolution is unsafe, and why a production
evaluate must be aligned with pass execution or an engine-owned valid-scope access.

## V Rising Metadata And Runtime Evidence

Fresh metadata probe:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\probe-vrising-render-metadata.ps1 -GamePath C:\Software\VRising -Json
```

Confirmed present:

- `HDRenderPipeline.RenderPostProcess`
- `GetPostprocessUpsampledOutputHandle`
- `DoDLSSPasses`
- `DoDLSSPass`
- `DLSSPass.ViewResourceHandles` / `ViewResources`
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`
- `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)`

Still absent from local metadata/runtime candidates:

- `DLSSContext`
- `DLSSCommandInitializationData`
- `DLSSTextureTable`
- `DLSSQuality`
- `NVUnityPlugin`
- `NGX` / `nvsdk_ngx`

Interpretation: HDRP's official DLSS source shape exists in generated interop,
but V Rising still does not appear to ship the full Unity NVIDIA runtime stack.
The official path is a map, not a turnkey switch.

Local hook classification:

| Boundary | Status | Decision |
| --- | --- | --- |
| `DLSSPass.Render(...)` | Targeted Harmony patch crashed in `UnityPlayer.dll` before prefix log | Rejected |
| Broad compiler-generated HDRP render funcs | Crashed in `coreclr.dll` before useful scope log | Rejected |
| `RenderGraph.PreRenderPassExecute(...)` | Patched, emitted no pass-boundary lines, then crashed in `coreclr.dll` | Rejected |
| `RenderGraph.OnPassAdded(...)` | Patched safely but emitted zero pass records in menu/gameplay | Safe but useless here |
| `RenderGraph.CompileRenderGraph(int)` pass list | Passed menu and protected `11111` gameplay, `GetTexture=0` | Useful read-only observation |
| `CompileRenderGraph(int)` pass declarations | Menu and protected `11111` gameplay proof passed with `GetTexture=0`; startup/window-only partial also emitted declarations | Useful read-only declaration proof |
| `RenderGraphResourceRegistry.GetTexture(...)` postfix | Proved tuples/evaluate candidates, but no-evaluate perf testing showed severe steady-state cost | Diagnostic oracle only |
| `CreateTextureCallback(...)` | Patch-stable but materialization-only gameplay saw no useful callbacks/candidates | Rejected as replacement boundary |
| `DynamicResolutionHandler.Update(...)` cached driver | No-evaluate performance isolation passed; real evaluate crashed in `nvwgf2umx.dll` | Not a real evaluate boundary |

The latest partial `rendergraph-pass-declarations` startup/window cleanup:

- `CrashEventCount=0`
- `RenderGraph pass declaration #=399`
- `RenderGraph GetTexture call #=0`
- save restore `ChangeCount=0`

This is useful safety/signal evidence, but it did not enter protected gameplay
and should not be counted as the gameplay proof.

The follow-up protected gameplay proof
`rendergraph-pass-declarations-gameplay-1080p-20260606-r2` did enter the `11111`
fixture:

- `CrashEventCount=0`
- analyzer `RenderGraph Pass Declarations=Pass`
- `RenderGraph pass declaration #=529`
- `RenderGraph GetTexture call #=0`
- failures/target-missing `0`
- Computer Use clicked Continue once and sent no movement keys
- stable gameplay screenshot saved at
  `artifacts/gameplay-automation/ComputerUseGameplay-rendergraph-pass-declarations-gameplay-1080p-20260606-r2.png`
- save restore `ChangeCount=0`

This completes the declaration proof. Do not rerun the stage unchanged.

The declaration chain and pass-data follow-up are now analyzed in
`docs/development/rendergraph-pass-data-boundary-analysis-2026-06-06.md`. That
note narrows the next implementation candidate to a default-off
`CompileRenderGraph(int)` pass-data field snapshot for `UberPostPassData`,
`EASUData`, and `FinalPassData`, not a generated render-function patch.

## Network Blind-Spot Checks

Primary sources checked:

- Unity RenderGraph fundamentals:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/manual/render-graph-fundamentals.html
- Unity `TextureHandle` API:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/api/UnityEngine.Rendering.RenderGraphModule.TextureHandle.html
- Unity HDRP Dynamic Resolution:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4013.1/manual/Dynamic-Resolution.html
- Unity HDRP DLSS:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4012.0/manual/deep-learning-super-sampling-in-hdrp.html
- Unity HDRP Asset DLSS injection point docs:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/HDRP-Asset.html
- BepInEx runtime patching:
  https://docs.bepinex.dev/articles/dev_guide/runtime_patching.html
- BepInEx preloader patchers:
  https://docs.bepinex.dev/articles/dev_guide/preloader_patchers.html
- NVIDIA Streamline DLSS guide:
  https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md
- OptiScaler README/INI:
  https://github.com/optiscaler/OptiScaler
  https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini

External evidence did not produce a new safe hook. It reinforced the local answer:

- Unity says actual RenderGraph resources are accessible only in pass execution,
  internal resources do not persist across graph executions, and culled resources
  may never allocate.
- Unity HDRP DLSS is coupled to HDRP Dynamic Resolution, HDRP Asset DLSS enablement,
  camera Allow Dynamic Resolution, camera Allow DLSS, and the NVIDIA package.
- HDRP Asset docs expose a DLSS injection point with `Before Post`,
  `After Depth Of Field`, and `After Post Process`.
- BepInEx supports runtime patching through HarmonyX/RuntimeDetour, and preload
  patchers can rewrite assemblies earlier, but documentation does not override
  local crash evidence for specific IL2CPP wrappers.
- Streamline requires render-resolution input color, final-resolution output color,
  depth, and motion vectors to be tagged for the current frame/pipeline point.
- OptiScaler works by hooking existing DLSS/XeSS/FSR inputs in games that already
  expose temporal upscaler APIs. This supports the "known upscaler boundary" model,
  not arbitrary high-frequency texture discovery.

## Decision

There is still no proven safe BepInEx/Harmony boundary that is equivalent to the
official HDRP DLSS evaluate boundary in V Rising.

The official answer is precise:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

The safest reachable boundary currently proven in V Rising is earlier:

`RenderGraph.CompileRenderGraph(int)` read-only pass list/declaration snapshots.

That boundary can map pass order and declared resource handles, but it cannot
submit DLSS because it has no live command-buffer execution window and no resolved
textures. The next useful step is therefore not another broad search or another
evaluate attempt. The default-off protected gameplay `rendergraph-pass-declarations`
proof is now complete, so the next useful step is to analyze whether declarations
can map V Rising's actual `Uber Post -> Edge Adaptive Spatial Upsampling -> Final
Pass` resource flow closely enough to justify one more narrowly scoped
execution-boundary experiment.

Do not rerun unchanged:

- `DLSSPass.Render` patches
- broad generated render-func patches
- ref-`CompiledPassInfo` executor wrapper patches
- pass injection
- cached-driver real evaluate from `DynamicResolutionHandler.Update(...)`
- pass-list/pass-declarations unchanged
- steady-state production work in global `GetTexture`

## 2026-06-06 Execute-Delegate Follow-up

After the protected `rendergraph-pass-data-gameplay-1080p-20260606-r1` proof,
the next candidate moved one step later than `CompileRenderGraph(int)` without
touching generated render functions or command buffers.

New downloaded refs:

- `ref/hdrp-rendergraph-boundary-2026-06-06/HDRenderPipeline.PostProcess.cs`
- `ref/hdrp-rendergraph-boundary-2026-06-06/DLSSPass.cs`
- `ref/hdrp-rendergraph-boundary-2026-06-06/RenderGraph.cs`
- `ref/hdrp-rendergraph-boundary-2026-06-06/RenderGraphPass.cs`
- `ref/hdrp-rendergraph-boundary-2026-06-06/RenderGraphResourceRegistry.cs`
- `ref/hdrp-rendergraph-boundary-2026-06-06/NVIDIA-Streamline-ProgrammingGuideDLSS.md`
- `ref/hdrp-rendergraph-boundary-2026-06-06/OptiScaler-README.md`

Local reflection helper:

```powershell
C:\Software\dotnet\dotnet.exe run --project artifacts\reflection-check\RenderGraphBoundaryReflection.csproj -- C:\Software\VRising\BepInEx
```

Result: closed generic
`RenderGraphPass.GetExecuteDelegate<TPassData>()` methods can be constructed
with `ContainsGenericParameters=False` for `HDRenderPipeline+DLSSData`,
`UberPostPassData`, `EASUData`, and `FinalPassData`. Local `ilspycmd` also
confirmed `RenderGraphPass<TPassData>.Execute(RenderGraphContext)` exists and
invokes the stored delegate with `data` and `ctx`.

Decision update: the best next read-only/no-evaluate execution-boundary
candidate is a default-off menu-first probe for closed
`GetExecuteDelegate<TPassData>()`, not a generated render-func patch and not
`RenderGraphPass<TPassData>.Execute(ctx)`.

Implementation follow-up: this candidate is now wired as
`Diagnostics.EnableRenderGraphExecuteDelegateProbe=false` and helper stage
`rendergraph-execute-delegate`, with analyzer/package support. It is not
runtime-proven yet; the first proof must be menu-only at `1920x1080 Windowed`.

This candidate only proves that a focused pass reached the execution layer. It
does not provide `RenderGraphContext`, command buffers, native textures, or DLSS
evaluate authority. Full protocol:
`docs/development/rendergraph-execute-delegate-candidate-2026-06-06.md`.
