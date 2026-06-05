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

Continue the direct NGX/D3D11 route, but move Stage 8A from ordinary method-prefix probing to RenderGraph-scope probing.

Preferred next implementation order:

1. Keep the current prefix probes for discovery only: resource names, handle index/type, and method ordering.
2. Keep the `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix as a passive detector for engine-owned valid resource access.
3. Add a diagnostic path that hooks an existing HDRP RenderGraph method and injects a small RenderGraph pass after HDRP has exposed `CameraColor`, `CameraDepthStencil`, and `Motion Vectors`.
4. In that pass, declare read access for color/depth/motion and write to a separate diagnostic output texture; convert to native pointers only inside `SetRenderFunc`.
5. Run `VrisingDlss_ProbeDlssEvaluateInputs` inside that valid pass before any NGX evaluate call.
6. Only after Stage 8A passes, wire the SDK-wrapper-backed DLSS feature lifecycle to the real frame path.

Local follow-up evidence: a builder-declaration probe now observes named `RenderGraphBuilder` declarations for `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer` without calling `GetTexture(TextureHandle&)`. This narrows the remaining Stage 8A work to execution inside a declared RenderGraph pass or delegate.

Additional local negative evidence: `RenderGraph.PreRenderPassExecute` can be patched but was not observed as called in the main menu; `RenderGraphPass<T>.Execute(RenderGraphContext)` cannot be patched as an open generic method with the current Harmony route; and patching `TextureHandle` implicit conversions produced repeated IL2CPP trampoline `NullReferenceException` logs. These results make an explicit diagnostic `AddRenderPass`/`SetRenderFunc` path the preferred next implementation step.

Implementation follow-up: the explicit diagnostic pass path compiles when local V Rising interop assemblies are present. It can inject an `AddRenderPass`/`SetRenderFunc` pass with `hasRenderFunc=True` and `allowPassCulling=False` from both `DoCustomPostProcess` arguments and aggregated builder declarations. Main-menu runs configured the pass but did not call its render function. A local/private gameplay run then configured/injected the pass twice and crashed `VRising.exe` in `coreclr.dll` with `0xc0000005` before any render-function log. This makes new diagnostic pass injection a rejected normal Stage 8A route for now; it remains behind `Diagnostics.EnableRenderGraphDiagnosticPass=false` for deliberate crash-recovery research only.

Updated route decision: continue passive RenderGraph discovery and engine-owned `GetTexture` postfix monitoring, but move first native input validation to a known-executing existing HDRP/RenderGraph path or a proven engine-owned resource materialization point instead of injecting a new diagnostic pass.

Rejected or deferred:

- Calling `GetTexture(TextureHandle&)` from ordinary Harmony prefixes.
- Patching the open generic `RenderGraphPass<T>.Execute(RenderGraphContext)` method directly.
- Patching `TextureHandle` implicit conversion operators as a broad diagnostic route.
- Injecting a new diagnostic RenderGraph pass as part of ordinary `dlss-evaluate-inputs`; this caused a CoreCLR access violation in gameplay and is high-risk only.
- Evaluating DLSS from main-menu HDCamera exposure/global texture evidence.
- Replacing the primary route with Streamline before first direct-NGX evaluate.
- Bundling `nvngx_dlss.dll` before a separate release review.

## Updated Time Estimate

Starting from current local evidence:

- If a RenderGraph execution callback or injected pass can be added cleanly: first DLSS evaluate-input pass in 1-2 weeks, first visible DLSS image in 2-4 weeks, private playable alpha in 4-6 weeks, public MVP in 6-9 weeks.
- If V Rising/HDRP blocks safe pass injection or the motion-vector resource is not valid in gameplay: first visible DLSS image in 4-8 weeks, private playable alpha in 8-12 weeks, public MVP in 10-14+ weeks.
- Runtime-bundling/legal review remains separate and can add unbounded time. The source-safe no-runtime package path should remain the default MVP fallback.
