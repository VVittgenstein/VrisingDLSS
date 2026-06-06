# HDRP DLSS Execution Boundary - 2026-06-06

Status: narrow source-backed route decision.

## Question

In Unity HDRP/RenderGraph, where does the official DLSS path actually obtain
resources and submit evaluate, and is there an equivalent boundary that a
BepInEx/Harmony mod can approach safely?

This search intentionally excludes broad "why is DLSS slow" and generic DLSS
integration material. Local source and V Rising interop evidence are primary;
network sources are only used to fill exact gaps.

## Local Unity Graphics Source

Local source inspected:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/Common/DynamicResolutionHandler.cs`

The Core RenderGraph files were missing from the local reference tree and were
downloaded from Unity's official `Unity-Technologies/Graphics` 2022.3 staging
branch into `ref/UnityGraphics-2022.3/.../Runtime/RenderGraph/`.

Official HDRP DLSS call chain:

1. `RenderPostProcess(...)` calls `DoDLSSPasses(...)` at the configured HDRP
   DLSS injection point: before post, after depth of field, or after post.
2. `DoDLSSPasses(...)` gates on `m_DLSSPassEnabled` and the HDRP asset
   `DLSSInjectionPoint`, then creates the DLSS color-mask pass and calls
   `DoDLSSPass(...)`.
3. `DoDLSSPass(...)` adds a RenderGraph pass named `Deep Learning Super Sampling`.
   It declares `source`, `depth`, `motionVectors`, optional `biasColorMask`, and
   writes an output from `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`.
4. The pass render function calls:
   `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(data.resourceHandles), ctx.cmd)`.
5. `DLSSPass.GetCameraResources(...)` converts `TextureHandle` groups into real
   `Texture` objects via `GetViewResources(...)` and the implicit
   `TextureHandle -> Texture` conversion.
6. `DLSSPass.Render(...)` enters `InternalNVIDIARender(...)`, builds
   `inputRes=hdCamera.actualWidth/actualHeight` and
   `outputRes=DynamicResolutionHandler.instance.finalViewport`, then calls
   `cameraState.SubmitCommands(...)`.
7. `ViewState.SubmitDlssCommands(...)` builds the NVIDIA texture table
   (`colorInput`, `colorOutput`, `depth`, `motionVectors`, `biasColorMask`) and
   submits `m_Device.ExecuteDLSS(cmdBuffer, m_DlssContext, textureTable)`.

This means the official evaluate boundary is not `GetTexture` discovery in
general. It is the `Deep Learning Super Sampling` RenderGraph pass execution
window, after resources are declared and materialized, when `DLSSPass.GetCameraResources`
turns the handles into actual textures and `DLSSPass.Render` submits the command.

## RenderGraph Resource Timing

The downloaded Unity Core RenderGraph source explains the valid resource window:

- `RenderGraph.ExecuteCompiledPass(...)` calls `PreRenderPassExecute(...)`,
  then `passInfo.pass.Execute(m_RenderGraphContext)`, then
  `PostRenderPassExecute(...)`.
- `PreRenderPassExecute(...)` creates needed pooled resources for the pass and
  sets render targets, using the current `RenderGraphContext`.
- `RenderGraphResourceRegistry.GetTexture(TextureHandle)` returns the
  `TextureResource.graphicsResource` as an `RTHandle`, and throws if the texture
  has not been created or has already been released.
- `RenderGraphResourceRegistry.CreateTextureCallback(...)` only handles
  creation-time work such as fast-memory and optional clear; it does not by
  itself mean the DLSS pass is consuming the color/depth/motion/output tuple.

Unity's public `TextureHandle` docs match this: a handle is scoped to one
RenderGraph record+execute and may not represent an actual texture if the pass is
culled or the resource is not allocated. Texture handles should not be kept or
used outside the graph execution context.

## V Rising Interop Evidence

`scripts/probe-vrising-render-metadata.ps1 -GamePath C:\Software\VRising -Json`
was rerun on 2026-06-06.

Confirmed present in V Rising generated interop:

- `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler`
- `HDRenderPipeline.GetPostprocessUpsampledOutputHandle`
- `HDRenderPipeline.DoDLSSPasses`
- `HDRenderPipeline.DoDLSSPass`
- `HDRenderPipeline.RenderPostProcess`
- `HDRenderPipeline.FinalPass`
- `DLSSPass.ViewResourceHandles` with `source`, `output`, `depth`,
  `motionVectors`, and `biasColorMask`
- `DLSSPass.ViewResources` with `Texture` fields for the same categories
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`
- `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)`
- `RenderGraphResourceRegistry.GetTexture(TextureHandle&)`,
  `BeginExecute(int)`, `CreateTextureCallback(RenderGraphContext, IRenderGraphResource)`
- `RenderGraph.PreRenderPassExecute(ref CompiledPassInfo, RenderGraphPass, RenderGraphContext)`

Also confirmed absent from local game metadata/runtime scan:

- Built-in `nvngx` / `nvsdk` / `NGX` runtime candidates.
- Unity NVIDIA module feature names such as `DLSSContext`,
  `DLSSTextureTable`, and `NVUnityPlugin`.

So the official HDRP DLSS shape exists as code/metadata landmarks, but V Rising
does not appear to ship the complete Unity NVIDIA DLSS runtime stack. We should
use HDRP's boundary as a map, not assume the game's built-in DLSS switch can be
turned on as-is.

## Network Blind-Spot Checks

Sources checked:

- Unity HDRP DLSS manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/deep-learning-super-sampling-in-hdrp.html`
- Unity HDRP Dynamic Resolution manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/Dynamic-Resolution.html`
- Unity `TextureHandle` API:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/api/UnityEngine.Rendering.RenderGraphModule.TextureHandle.html`
- Unity Graphics official source:
  `https://github.com/Unity-Technologies/Graphics/tree/2022.3/staging`
- BepInEx runtime patching docs:
  `https://docs.bepinex.dev/master/articles/dev_guide/runtime_patching.html`
- NVIDIA NGX programming guide:
  `https://docs.nvidia.com/ngx/latest/programming-guide/index.html`
- NVIDIA Streamline programming guide:
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
- OptiScaler README/INI:
  `https://github.com/optiscaler/OptiScaler`
  `https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini`

Useful external confirmations:

- Unity documents HDRP DLSS as tied to HDRP Dynamic Resolution, project-level
  DLSS enablement, and per-camera Allow Dynamic Resolution / Allow DLSS.
- Unity documents HDRP Dynamic Resolution as lowering main render targets and
  upscaling to the back buffer at frame end.
- NVIDIA NGX expects feature creation followed by evaluate calls with concrete
  D3D resources and warns that DirectX evaluate mutates command-list state, so
  callers must manage state around the evaluate boundary.
- Streamline models DLSS around per-frame resource tagging/evaluate with color,
  output, depth, and motion-vector resource categories, plus resource lifecycle.
- OptiScaler's public design intercepts existing upscaler inputs and outputs
  rather than discovering arbitrary engine textures from every resource lookup.

## Local Runtime Evidence Against Candidate Boundaries

Rejected or weak boundaries:

- Direct `DLSSPass.Render` Harmony prefix is rejected. It crashed V Rising in
  `UnityPlayer.dll` with `0x80000003` after patching and before the prefix logged.
- Broad compiler-generated HDRP render-function patching is rejected. It crashed
  in `coreclr.dll` before a useful scope log.
- Injecting a new diagnostic RenderGraph pass is rejected for ordinary diagnostics.
  It injected in gameplay and then crashed in `coreclr.dll` before its render
  function logged.
- Prefix-time calls to `RenderGraphResourceRegistry.GetTexture(TextureHandle&)`
  are rejected. Unity's source and local logs agree this can happen outside a
  valid created-resource scope.
- `TextureHandle` implicit-conversion patching is rejected. It produced IL2CPP
  trampoline errors.
- `RenderGraphResourceRegistry.CreateTextureCallback(...)` is patch-stable but
  not sufficient. The 2026-06-06 `dlss-user-rendering-materialization-no-evaluate`
  gameplay run disabled the global GetTexture probe and enabled materialization-only
  discovery. It patched `BeginExecute`/`CreateTextureCallback` cleanly, but observed
  `0` `RenderGraph texture materialization #` logs, `0` materialization SR input
  candidates, and no no-evaluate acceptance before the candidate was stopped. The
  protected `11111` save was restored with `ChangeCount=0`.

Still useful diagnostic boundaries:

- Passive `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix is
  accepted as a diagnostic resource-discovery path because engine-owned calls happen
  inside valid scopes. It proved the first input tuples and later SR tuples.
- The same postfix is no longer viable as steady-state production placement. The
  no-evaluate performance series reproduced severe FPS loss without native DLSS
  evaluate, even after logging suppression, reflection/member caches, tuple reuse,
  and resource-name-first filtering. R4 still measured `194.424 -> 119.573` FPS
  with low candidate GPU utilization.
- `DLSSPass.GetViewResources` / `GetCameraResources` remains an isolated research
  route. It is closer to the official resource conversion point and did not crash
  in a short main-menu helper run, but that run did not observe calls. It likely
  only becomes useful if the official DLSS pass is actually built/executed.

## Route Decision

The official boundary to imitate is:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

The safest next mod-accessible equivalent is not another global texture lookup.
It is a narrowly filtered pass-execution boundary:

1. First prove, read-only, whether `RenderGraph.PreRenderPassExecute` or nearby
   non-generic RenderGraph execution methods are called during real gameplay in
   this IL2CPP build.
2. If callable, log only pass names and types at first. Filter for HDRP upscale
   and postprocess passes, especially `Deep Learning Super Sampling` if the
   official path can be enabled, or the existing visible upscaler/final passes
   such as `Edge Adaptive Spatial Upsampling`, `Final Pass`, and related postprocess
   output passes.
3. Only after a pass-name proof, use that pass execution window to resolve already
   declared resources for the specific pass. Avoid global per-`GetTexture` steady
   state work.
4. Keep the current `GetTexture` postfix as a diagnostic fallback and tuple oracle,
   not the production frame path.

If `PreRenderPassExecute` still does not fire in gameplay, the next narrow option
is a deliberately isolated `DLSSPass.GetCameraResources` gameplay test under a
configuration that attempts to make HDRP construct the official DLSS pass. That is
not a production route yet because direct `DLSSPass.Render` is rejected and V Rising
does not ship the full NVIDIA module/runtime.

## Next Minimal Experiment

Build a read-only `rendergraph-pass-boundary` diagnostic stage:

- Patch only `RenderGraph.PreRenderPassExecute(...)` or, if that wrapper is dead
  in gameplay, one adjacent non-generic execution method such as
  `ExecuteCompiledPass(ref CompiledPassInfo, int)`.
- Do not patch compiler-generated render delegates.
- Do not call `GetTexture` from the prefix.
- Log capped pass names, pass indices, culled state, async state, and whether the
  pass name matches DLSS/upscale/final-postprocess candidates.
- Run at true `1920x1080` Windowed against the protected `11111` save.
- Pass if gameplay logs a stable pass sequence including the current upscaler/final
  boundary without crash.
- Fail if no pass-execution calls appear, or if any crash/IL2CPP trampoline error
  occurs.

Only after that proof should the mod attempt resource resolution/evaluate inside a
targeted pass boundary.

## Implementation Follow-Up

Implemented on 2026-06-06:

- Added `Diagnostics.EnableRenderGraphPassBoundaryProbe=false` by default.
- Added helper stage `rendergraph-pass-boundary`.
- The stage patches only `RenderGraph.PreRenderPassExecute(...)`.
- The patch accepts both the V Rising interop shape
  `PreRenderPassExecute(ref CompiledPassInfo, RenderGraphPass, RenderGraphContext)`
  and Unity Core 2022.3's source shape
  `PreRenderPassExecute(in CompiledPassInfo, RenderGraphContext)`.
- The postfix logs capped pass metadata only: method, pass name, pass type,
  category (`dlss`, `upscale`, `final`, `postprocess`, `temporal`, or `other`),
  and safe `CompiledPassInfo` fields such as culled/async/ref-count/sync state.
- In pass-boundary-only mode the postfix returns before reading
  `RenderGraph.m_Resources`, before collecting texture candidates, and before any
  native bridge or DLSS evaluate path.

Build and package validation passed, but the first runtime proof rejected this
Harmony boundary:

- Run: `rendergraph-pass-boundary-1080p-20260606-r1`.
- Conditions: true `1920x1080` Windowed startup, protected `11111` save backed up
  and restored.
- Result: `RenderGraph.PreRenderPassExecute(CompiledPassInfo&, RenderGraphPass,
  RenderGraphContext)` patched successfully, native bridge API `12` loaded, and
  no `RenderGraph pass boundary #` line was emitted.
- Failure: V Rising crashed before gameplay/Continue with Windows Application
  Error `coreclr.dll`, exception `0xc0000005`, at `2026-06-06 17:19:02`.
- Cleanup: loader config, ClientSettings, release-safe native state, and the
  `11111` save were restored; save compare after restore reported `ChangeCount=0`.

Conclusion: `PreRenderPassExecute` is now rejected for normal diagnostics in this
IL2CPP build. The official boundary remains the correct conceptual target, but a
safe mod-accessible equivalent must avoid Harmony patching this ref-`CompiledPassInfo`
RenderGraph executor wrapper.

## Narrow Follow-Up After Pass-Boundary Rejection

Question restated:

- In Unity HDRP/RenderGraph, where does official DLSS obtain resources and submit
  evaluate?
- Is there a BepInEx/Harmony-accessible boundary with the same safety properties?

Local source is still the primary evidence. The relevant upstream Unity 2022.3
source lines are now pinned more precisely:

- `HDRenderPipeline.PostProcess.cs` line 526, 552, and 604 call
  `DoDLSSPasses(...)` from `RenderPostProcess(...)` at the HDRP upsampler
  schedule points.
- `DoDLSSPasses(...)` lines 708-717 gates on `m_DLSSPassEnabled` and the HDRP
  asset `DLSSInjectionPoint`, runs the color-mask pass, then calls
  `DoDLSSPass(...)`.
- `DoDLSSPass(...)` lines 720-755 registers the `Deep Learning Super Sampling`
  RenderGraph pass. It declares `source`, `output`, `depth`, and
  `motionVectors`; writes an output named `DLSS destination`; and runs
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(...), ctx.cmd)`
  inside the render function.
- `DLSSPass.cs` lines 40-52 convert `TextureHandle` groups to real `Texture`
  resources; lines 91-105 create `CameraResources`; lines 197-205 enter
  `Render(...)`; lines 406-415 build the NVIDIA texture table and call
  `ExecuteDLSS`; lines 687-713 set input/output resolution, jitter, reset, and
  pre-exposure before submitting.
- `RenderGraph.cs` lines 1465-1485 execute each compiled pass as
  `PreRenderPassExecute(...) -> pass.Execute(...) -> PostRenderPassExecute(...)`.
  Lines 1552-1597 create resources and set render targets before pass execution.
- `RenderGraphResourceRegistry.cs` lines 103-113 show why prefix-time
  `GetTexture(TextureHandle)` is unsafe: it throws if the resource was not yet
  created or was already released.

Fresh V Rising interop evidence from
`scripts/probe-vrising-render-metadata.ps1 -GamePath C:\Software\VRising -Json`
and direct `ilspycmd` inspection:

- `HDRenderPipeline.RenderPostProcess`, `GetPostprocessUpsampledOutputHandle`,
  `DoDLSSPasses`, `DoDLSSPass`, and `FinalPass` all exist in generated interop.
- The compiler-generated official DLSS render function wrapper exists as
  `_DoDLSSPass_b__969_0(DLSSData, RenderGraphContext)`.
- `DLSSPass.ViewResourceHandles` contains `source`, `output`, `depth`,
  `motionVectors`, and `biasColorMask`; `ViewResources` contains matching
  `Texture` fields.
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`,
  and `Render(Parameters, CameraResources, CommandBuffer)` all exist.
- `RenderGraph` exposes `OnPassAdded(RenderGraphPass)`,
  `ExecuteCompiledPass(ref CompiledPassInfo)`,
  `PreRenderPassExecute(ref CompiledPassInfo, RenderGraphPass, RenderGraphContext)`,
  and `PostRenderPassExecute(ref CompiledPassInfo, RenderGraphContext)`.
- `RenderGraphResourceRegistry` exposes `GetTexture(ref TextureHandle)`,
  `BeginExecute(int)`, `EndExecute()`, and
  `CreateTextureCallback(RenderGraphContext, IRenderGraphResource)`.
- The local metadata still does not expose the complete Unity NVIDIA runtime
  stack (`DLSSContext`, `DLSSTextureTable`, `DLSSQuality`, `NVUnityPlugin`, NGX
  symbols), so the built-in HDRP DLSS path remains a boundary map, not a working
  turnkey route.

Narrow network checks did not change the route:

- Unity HDRP DLSS documentation ties DLSS to the NVIDIA package, HDRP Dynamic
  Resolution, HDRP Asset DLSS enablement, camera Allow Dynamic Resolution, and
  camera Allow DLSS.
- Unity HDRP Dynamic Resolution documentation says HDRP requires Dynamic
  Resolution to be enabled in the HDRP Asset and per camera, then driven through
  `DynamicResolutionHandler.SetDynamicResScaler(...)`.
- Unity RenderGraph documentation says internal resources are scoped to one
  RenderGraph execution; pass setup declares `ReadTexture`/`WriteTexture`; and
  `SetRenderFunc` runs after graph compile/execute, which matches the source.
- NVIDIA Streamline DLSS guidance centers on per-frame resource tags for
  render-resolution color input, final-resolution color output, depth, and motion
  vectors, with volatile/current-frame lifetimes.
- OptiScaler's public README/INI reinforces the same design shape: it intercepts
  existing upscaler inputs and redirects them to an output backend. It does not
  solve this project by discovering arbitrary textures from every RenderGraph
  resource lookup.
- BepInEx/HarmonyX documentation confirms runtime patching is available, including
  ref patch parameters, but this does not override local crash evidence for specific
  IL2CPP wrappers.

### Boundary Classification

| Boundary | What it provides | Local status | Decision |
| --- | --- | --- | --- |
| `DLSSPass.Render(...)` | Exact official evaluate submission | Exists, but targeted patch crashed in `UnityPlayer.dll` before prefix log | Rejected |
| `_DoDLSSPass_b__969_0(DLSSData, RenderGraphContext)` and broad generated render funcs | Official render-func execution window | Broad generated render-func patching crashed in `coreclr.dll` | Rejected as normal route |
| `RenderGraph.PreRenderPassExecute(...)` | Near-execution pass metadata/resource creation window | Patched, logged zero pass-boundary lines, then crashed in `coreclr.dll` | Rejected |
| `RenderGraph.ExecuteCompiledPass(ref CompiledPassInfo)` / `PostRenderPassExecute(ref CompiledPassInfo, ...)` | Adjacent executor wrappers | Same ref-`CompiledPassInfo` family as rejected `PreRenderPassExecute` | Do not use next without stronger reason |
| `RenderGraphResourceRegistry.GetTexture(ref TextureHandle)` postfix | Engine-owned valid-scope real `RTHandle` discovery | Proved tuples and evaluates, but no-evaluate tests show severe steady-state FPS collapse | Diagnostic oracle only |
| `RenderGraphResourceRegistry.CreateTextureCallback(...)` | Resource creation callback | Patch-stable, but materialization-only gameplay saw zero useful callbacks/candidates | Rejected as replacement boundary |
| `DLSSPass.GetViewResources` / `GetCameraResources` | Closest official handle-to-texture conversion helper | Exists and short main-menu patch did not crash, but no calls observed; likely only useful if official DLSS pass executes | Research-only candidate |
| `RenderGraph.OnPassAdded(RenderGraphPass)` | Pass-recording/name proof without ref executor wrapper | Exists in V Rising interop; not yet tested | Possible narrow read-only pass-name probe, not an evaluate boundary |
| Existing safe dynamic-resolution/camera callbacks such as `DynamicResolutionHandler.Update(...)` | Stable per-frame-ish local driver point | Already used safely by render-scale control | Best near-term driver for cached accepted tuples, not an official resource boundary |

Current conclusion:

There is no proven safe BepInEx/Harmony hook that is exactly equivalent to the
official HDRP DLSS evaluate boundary. The official boundary is precise and useful
as a map, but the closest managed wrappers that would expose it either already
crashed or only fire if Unity's built-in DLSS pass is active, which V Rising does
not appear able to run as shipped.

The next implementation loop should therefore avoid more executor-wrapper probes.
The most conservative path is:

1. Keep global `GetTexture` as a temporary discovery oracle only until one valid
   SR tuple has been accepted.
2. Move steady-state no-evaluate/evaluate attempts to an already stable callback
   such as the render-scale-control `DynamicResolutionHandler.Update(...)` route,
   using the cached accepted tuple.
3. Make the `GetTexture` postfix return as early as possible after tuple
   acceptance, so the next performance test directly answers whether the remaining
   FPS collapse is the hot global `GetTexture` path.
4. Separately, if pass-name evidence is needed, test `RenderGraph.OnPassAdded` as
   a read-only recording-stage probe. Treat it as a map/diagnostic only, because it
   does not provide live resources or an evaluate-safe command-buffer boundary.

Implementation update:

- Added `Diagnostics.EnableDlssCachedTupleDriverProbe=false` and helper stage
  `dlss-user-rendering-cached-driver-no-evaluate`.
- The new path keeps `GetTexture` as a temporary tuple oracle until first SR tuple
  acceptance, then fast-skips the hot `GetTexture` postfix in no-evaluate cached
  driver mode.
- The cached tuple is driven from the already stable
  `DynamicResolutionHandler.Update(...)` postfix via the render-scale-control probe.
- This is not the official HDRP DLSS boundary and it still does not prove a
  production evaluate placement. It is the next minimal performance isolation to
  test whether the remaining no-evaluate collapse was mostly steady-state
  `GetTexture` postfix overhead.

Runtime update:

- `cached-driver-no-evaluate-1080p-20260606-r1` passed that isolation. The paired
  true-1080p run measured `204.201 -> 198.079` average FPS, with candidate GPU
  utilization/power dropping to `64.556%`/`86.590 W`, `82` cached-driver
  invocations, `84` no-evaluate acceptances, `0` native evaluate results, and `0`
  broad `RenderGraph GetTexture call #` logs.
- This confirms the hot global `GetTexture` placement, not NGX evaluate and not
  render-scale-only, caused most of the previous no-evaluate collapse.
- The practical next boundary remains the stable `DynamicResolutionHandler.Update`
  cached-driver route for now. The official HDRP pass boundary is still the design
  map, but not yet a safe Harmony hook point in this IL2CPP build.
