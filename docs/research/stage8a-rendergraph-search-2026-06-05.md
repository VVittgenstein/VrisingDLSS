# Stage 8A RenderGraph Search - 2026-06-05

Goal: turn the latest Stage 8A runtime evidence into a concrete technical route for first DLSS evaluate in V Rising.

This is engineering research, not legal advice.

## Current Local Evidence

- V Rising uses Unity `2022.3.58f1`, HDRP, IL2CPP, and D3D11 in the local test install.
- Stage 8A has observed HDRP RenderGraph callbacks in the main menu:
  - `HDRenderPipeline.RenderCameraMotionVectors(RenderGraph, HDCamera, TextureHandle depthBuffer, TextureHandle motionVectorsBuffer)`
  - `HDRenderPipeline.DoCustomPostProcess(RenderGraph, HDCamera, TextureHandle& source, TextureHandle depthBuffer, TextureHandle normalBuffer, TextureHandle motionVectors, ...)`
  - `HDRenderPipeline.ResolveMotionVector(RenderGraph, HDCamera, TextureHandle input)`
- The exposed RenderGraph resource names include `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer`.
- Calling `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` from an ordinary Harmony prefix is not safe: the local log showed IL2CPP trampoline error output when the handle was outside a declared read/write pass scope.
- The current diagnostic code therefore does not call `GetTexture` from prefixes. It records handle/resource state and listens for engine-owned `GetTexture` calls through a postfix.
- Local static interop inspection also shows HDRP dynamic-resolution/upscale symbols in V Rising's build: `SetFSRParameters`, `GetUpscaleFilter`, `SetUpscaleFilter`, `HDDynamicResolution`, `DoDLSSPasses`, `DoDLSSPass`, `DoTemporalAntialiasing`, `UberPass`, and `FinalPass`.
- The generated HDRP render-function methods include entries such as `_DoDLSSPass_b__969_0(DLSSData, RenderGraphContext)`, `_DoTemporalAntialiasing_b__1007_0(TemporalAntiAliasingData, RenderGraphContext)`, `_DoCustomPostProcess_b__997_0(CustomPostProcessData, RenderGraphContext)`, `_UberPass_b__1060_0(UberPostPassData, RenderGraphContext)`, and `_FinalPass_b__1069_0(FinalPassData, RenderGraphContext)`.

## Source Findings

### Unity RenderGraph Texture Handles

Unity's Core RP documentation says a `TextureHandle` is tied to a specific RenderGraph record+execute phase and should not be used outside the RenderGraph execution context. It also says a handle does not necessarily represent an allocated actual texture, because passes can be culled or resources can be internally managed.

This matches the local Stage 8A evidence: method-prefix access sees named handles, but no live `RTHandle`/`Texture` exists at that point.

Source:

- `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/api/UnityEngine.Experimental.Rendering.RenderGraphModule.TextureHandle.html`

### Unity RenderGraph Pass Declaration

Unity's Core RP 14.1 API documentation exposes the Unity 2022-era RenderGraphBuilder shape used by V Rising's generated interop:

- `ReadTexture(in TextureHandle)` declares a texture read.
- `ReadWriteTexture(in TextureHandle)` declares read/write.
- `UseColorBuffer(in TextureHandle, int)` declares and binds a color render target.
- `UseDepthBuffer(in TextureHandle, DepthAccess)` declares and binds a depth buffer.
- `SetRenderFunc<PassData>(...)` is required for a valid pass.

Unity's newer manual wording is consistent: set the texture handle in pass data, call the relevant `UseTexture`/attachment method during graph recording, and use the handle from `SetRenderFunc`.

Local interop check: `C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.Core.Runtime.dll` exposes `RenderGraphBuilder.UseColorBuffer`, `UseDepthBuffer`, `ReadTexture`, `WriteTexture`, `ReadWriteTexture`, and `SetRenderFunc` with `TextureHandle&` parameters, so this route matches the tested game build.

Sources:

- `https://docs.unity.cn/cn/Packages-cn/com.unity.render-pipelines.core%4014.1/api/UnityEngine.Rendering.RenderGraphModule.RenderGraphBuilder.html`
- `https://docs.unity.cn/6000.0/Documentation/Manual/urp/render-graph-read-write-texture.html`

Inference for this project:

- A plain prefix on HDRP methods such as `DoCustomPostProcess` can discover names and ordering, but should not be the first evaluate point.
- The next evaluate-input probe should run inside a valid RenderGraph pass or inside an engine-owned RenderGraph execution callback after HDRP has declared the texture usage.
- A safe diagnostic pass should declare at least the color, depth, and motion-vector `TextureHandle`s as reads and a separate output texture as a write/attachment. It should then convert to `RTHandle`/`Texture` only inside `SetRenderFunc`.

### HDRP Dynamic Resolution and FSR Landmarks

Unity's HDRP dynamic-resolution documentation groups DLSS, FSR2, FSR1, TAA Upscale, Catmull-Rom, and CAS as upscale filters that operate after HDRP renders at a lower resolution. Unity's HDRP asset documentation describes FSR1 as a spatial super-resolution option in that same upscale-filter area.

This is useful for V Rising because the local build exposes FSR/upscale and DLSS-related HDRP symbols. FSR1 is not a direct substitute for DLSS Super Resolution, because DLSS still needs frame-aligned depth and motion-vector inputs. However, the existing FSR/TAA/DLSS upscale route is a strong landmark for the buffers and scale state the mod needs: low-resolution color/source, full-resolution output/target, depth, motion vectors, render scale, and post-upscale final pass.

Sources:

- `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4013.0/manual/Dynamic-Resolution.html`
- `https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.high-definition/Documentation~/HDRP-Asset.md`

### NGX/DLSS Evaluate Requirements

NVIDIA's NGX programming guide documents D3D11 init, create, evaluate, release, and shutdown APIs. For D3D11 evaluate, NGX takes an `ID3D11DeviceContext`, a feature handle, and a parameter map. It also says feature input buffers such as color, albedo, normals, and depth must be provided as parameters as `ID3D*` resources or CUDA memory buffers.

This reinforces the current Stage 8A gate: first evaluate should not be attempted until the plugin has valid D3D11 resources for the frame inputs in the same frame and on the same device/context.

Sources:

- `https://docs.nvidia.com/ngx/latest/programming-guide/`

### NGX Runtime Distribution Reminder

The NVIDIA guide says that during development `nvngx_*.dll` files are copied next to the executable or plugin so the runtime can find them, and that only the feature DLLs used by the application should be distributed with the application. It also says products with NGX integrated should notify NVIDIA before release and use an assigned compatible application ID.

This does not change the current release boundary decision: keep the fallback package source-safe without bundling `nvngx_dlss.dll`, and treat any convenience package with the runtime as a separate release review.

Source:

- `https://docs.nvidia.com/ngx/latest/programming-guide/`

### Thunderstore Package Shape

Thunderstore's current package format docs still require a zip root containing `icon.png`, `README.md`, and `manifest.json`, with `CHANGELOG.md` optional. The manifest fields include name, description, semantic version, dependencies, and website URL.

The current package script remains aligned.

Source:

- `https://new.thunderstore.io/package/create/docs/`

## Route Decision

Continue the direct NGX/D3D11 route, but move Stage 8A from ordinary method-prefix probing to existing RenderGraph execution scope.

Preferred next implementation order:

1. Keep the current prefix probes for discovery only: resource names, handle index/type, and method ordering.
2. Keep the `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix as a passive detector for engine-owned valid resource access.
3. Do not patch compiler-generated HDRP render functions in ordinary diagnostics. That route was useful to identify likely pass-data structures, but it reproduced a CoreCLR access violation before any render-function scope log.
4. Continue looking for a safer engine-owned resource materialization point, for example a non-delegate registry/resource callback or another HDRP method that exposes already-created `RTHandle`/`Texture` objects without broad patching of generated render delegates.
5. Convert to native pointers only from an engine-owned successful `GetTexture` call or another proven valid resource scope.
6. Run `VrisingDlss_ProbeDlssEvaluateInputs` inside that valid existing execution context before any NGX evaluate call.
7. Only after Stage 8A passes, wire the SDK-wrapper-backed DLSS feature lifecycle to the real frame path.

Local follow-up evidence: a builder-declaration probe now observes named `RenderGraphBuilder` declarations for `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer` without calling `GetTexture(TextureHandle&)`. This narrows the remaining Stage 8A work to finding a safe engine-owned resource materialization point.

Additional local negative evidence: `RenderGraph.PreRenderPassExecute` can be patched but was not observed as called in the main menu; `RenderGraphPass<T>.Execute(RenderGraphContext)` cannot be patched as an open generic method with the current Harmony route; and patching `TextureHandle` implicit conversions produced repeated IL2CPP trampoline `NullReferenceException` logs.

Implementation follow-up: the explicit diagnostic pass path compiles when local V Rising interop assemblies are present. It can inject an `AddRenderPass`/`SetRenderFunc` pass with `hasRenderFunc=True` and `allowPassCulling=False` from both `DoCustomPostProcess` arguments and aggregated builder declarations. Main-menu runs configured the pass but did not call its render function. A local/private gameplay run then configured/injected the pass twice and crashed `VRising.exe` in `coreclr.dll` with `0xc0000005` before any render-function log. This makes new diagnostic pass injection a rejected normal Stage 8A route for now; it remains behind `Diagnostics.EnableRenderGraphDiagnosticPass=false` for deliberate crash-recovery research only.

Follow-up evidence: a main-menu diagnostic run on 2026-06-05 patched 10 compiler-generated existing HDRP render functions, including `_DoTemporalAntialiasing_b__1007_0`, `_DoCustomPostProcess_b__997_0`, `_UberPass_b__1060_0`, and `_FinalPass_b__1069_0`. V Rising then crashed in `coreclr.dll` with `0xc0000005` before any `Existing HDRP render-func scope` log. A second run reproduced the same Windows Error Reporting fault bucket. This makes broad compiler-generated render-function Harmony patching a rejected normal Stage 8A route; it is now gated behind `Diagnostics.EnableExistingRenderFuncProbe=false` for deliberate crash-recovery research only.

Updated route decision after that follow-up: continue passive RenderGraph discovery and engine-owned `GetTexture` postfix monitoring, but do not inject a new diagnostic pass and do not patch compiler-generated HDRP render functions in ordinary diagnostics. The FSR/dynamic-resolution symbols remain landmarks for the eventual route, not a safe hook mechanism by themselves.

Implementation follow-up: the next safer candidate is `RenderGraphResourceRegistry.CreateTextureCallback(RenderGraphContext, IRenderGraphResource)`, paired with `BeginExecute(int)` for per-execution reset. Static interop inspection shows `TextureResource` inherits the generic RenderGraph resource base that exposes `graphicsResource`; when Unity's callback returns success, a postfix can observe the already-created `RTHandle`/Texture path without calling `GetTexture(TextureHandle&)` from an invalid prefix scope. This is now implemented behind `Diagnostics.EnableResourceMaterializationProbe=false` by default and enabled by the `dlss-evaluate-inputs` helper stage. It is build/package validated but not yet runtime-validated in gameplay.

Additional FSR evidence: local metadata and interop inspection confirm V Rising exposes `AMD FSR 1.0`, `SetFSRParameters(float, bool)`, `GetUpscaleRes()`, `SetUpscaleFilter(DynamicResUpscaleFilter, float)`, `GetUpscaleFilter()`, `SetupDLSSForCameraDataAndDynamicResHandler(...)`, `GetPostprocessUpsampledOutputHandle(...)`, `DoDLSSPasses(...)`, and `DoDLSSPass(...)`. FSR1 helps identify the existing dynamic-resolution/upscale controls, but it remains a spatial upscaler and does not remove DLSS's requirement for depth and motion-vector inputs.

Rejected or deferred:

- Calling `GetTexture(TextureHandle&)` from ordinary Harmony prefixes.
- Patching the open generic `RenderGraphPass<T>.Execute(RenderGraphContext)` method directly.
- Patching `TextureHandle` implicit conversion operators as a broad diagnostic route.
- Injecting a new diagnostic RenderGraph pass as part of ordinary `dlss-evaluate-inputs`; this caused a CoreCLR access violation in gameplay and is high-risk only.
- Patching compiler-generated HDRP RenderGraph render-function delegates as part of ordinary `dlss-evaluate-inputs`; this reproduced the same CoreCLR access-violation crash before the postfix logged.
- Treating FSR1 as a DLSS replacement instead of an upscale-path landmark.
- Evaluating DLSS from main-menu HDCamera exposure/global texture evidence.
- Replacing the primary route with Streamline before first direct-NGX evaluate.
- Bundling `nvngx_dlss.dll` before a separate release review.

## Updated Time Estimate

Starting from current local evidence:

- If a safe engine-owned resource materialization point is found without patching generated render delegates or injecting a pass: first DLSS evaluate-input pass in 1-2 weeks, first visible DLSS image in 2-4 weeks, private playable alpha in 4-6 weeks, public MVP in 6-9 weeks.
- If V Rising/HDRP continues to block safe resource-scope access or the motion-vector resource is not valid in gameplay: first visible DLSS image in 4-8 weeks, private playable alpha in 8-12 weeks, public MVP in 10-14+ weeks.
- Runtime-bundling/legal review remains separate and can add unbounded time. The source-safe no-runtime package path should remain the default MVP fallback.
