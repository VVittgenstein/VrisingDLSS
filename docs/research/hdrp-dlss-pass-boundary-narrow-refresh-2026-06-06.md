# HDRP DLSS Pass Boundary Narrow Refresh - 2026-06-06

Status: local/source-first refresh after the `native-renderfunc-args` menu and
protected gameplay proofs. No game launch in this pass.

Follow-up in the same implementation loop: the proposed default-off
`native-renderfunc-resource-identity` preflight was implemented and statically
validated in
`docs/development/native-renderfunc-resource-identity-preflight-implementation-2026-06-06.md`.

## Question

Where does official Unity HDRP DLSS obtain real resources and submit evaluate
inside RenderGraph, and is there a BepInEx/Harmony-accessible equivalent boundary
that is safe in V Rising?

This refresh intentionally avoids broad DLSS performance theory. Local Unity
Graphics source, V Rising interop, and previous runtime proofs are primary.
Network checks only fill precise RenderGraph/DLSS/modding blind spots.

## Local Source Answer

Official HDRP DLSS boundary:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> "Deep Learning Super Sampling" RenderGraph render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`

Local source anchors:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
  - `RenderPostProcess(...)` calls `DoDLSSPasses(...)` at the HDRP upsampler
    schedule points: lines `526`, `552`, and `604`.
  - `DoDLSSPasses(...)` gates on `m_DLSSPassEnabled` and the configured
    `DLSSInjectionPoint`, then calls `DoDLSSPass(...)`: lines `708-717`.
  - `DoDLSSPass(...)` creates the RenderGraph pass named
    `Deep Learning Super Sampling`, declares `source`, `output`, `depth`,
    `motionVectors`, optional `biasColorMask`, writes `DLSS destination`, and
    sets the render function: lines `720-755`.
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
  - `GetViewResources(...)` and `GetCameraResources(...)` convert
    `TextureHandle` groups into real `Texture` objects: lines `40-105`.
  - `DLSSPass.Render(...)` forwards to the NVIDIA path: lines `197-205`.
  - `ViewState.SubmitDlssCommands(...)` builds the table containing
    `colorInput`, `colorOutput`, `depth`, `motionVectors`, and `biasColorMask`,
    then submits `ExecuteDLSS(...)`: lines `380-415`.
  - `InternalNVIDIARender(...)` computes current-frame quality, input/output
    resolution, jitter, reset, and pre-exposure: lines `687-713`.
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
  - `ExecuteCompiledPass(...)` runs `PreRenderPassExecute(...)`,
    `passInfo.pass.Execute(m_RenderGraphContext)`, then
    `PostRenderPassExecute(...)`: lines `1465-1485`.
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphPass.cs`
  - `RenderGraphPass<T>.Execute(...)` invokes the stored `renderFunc(data,
    renderGraphContext)`: lines `141-143`.
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`
  - `GetTexture(in TextureHandle)` returns the actual resource only if the
    handle is valid and the resource is alive; otherwise Unity throws: lines
    `103-112`.
  - `CreateTextureCallback(...)` is resource creation/clear work, not the
    upscaler submission boundary: lines `466-488`.

Therefore official DLSS does not discover resources by polling global
`GetTexture` callbacks. It declares pass data first, then converts handles to
actual resources inside the specific RenderGraph render function, where
`RenderGraphContext.cmd` is valid and ordering matches the upscaler pass.

## V Rising Interop Refresh

`scripts/probe-vrising-render-metadata.ps1 -GamePath C:\Software\VRising -Json`
confirmed:

- `HDRenderPipeline.RenderPostProcess`, `GetPostprocessUpsampledOutputHandle`,
  `DoDLSSPasses`, and `DoDLSSPass` exist.
- Strings for `Deep Learning Super Sampling`, `DLSS Color Mask`, and
  `DLSS destination` exist.
- `DLSSPass.ViewResourceHandles` exposes `source`, `output`, `depth`,
  `motionVectors`, and `biasColorMask`.
- `DLSSPass.ViewResources` exposes matching `Texture` fields.
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`,
  and `Render(Parameters, CameraResources, CommandBuffer)` exist.
- The local metadata still does not expose complete Unity NVIDIA runtime types:
  `DLSSContext`, `DLSSCommandInitializationData`, `DLSSTextureTable`,
  `DLSSQuality`, `NVUnityPlugin`, `NGX`, and `nvsdk_ngx` are absent.

Direct `ilspycmd` inspection with local `DOTNET_ROOT=C:\Software\dotnet`
confirmed the generated RenderGraph render function method infos:

- `_DoDLSSPass_b__969_0_Internal_Void_DLSSData_RenderGraphContext_0`
- `_UberPass_b__1060_0_Internal_Void_UberPostPassData_RenderGraphContext_0`
- `_EdgeAdaptiveSpatialUpsampling_b__1066_0_Internal_Void_EASUData_RenderGraphContext_0`
- `_FinalPass_b__1069_0_Internal_Void_FinalPassData_RenderGraphContext_0`

It also confirmed `EASUData` fields include `inputWidth`, `inputHeight`,
`outputWidth`, `outputHeight`, `source`, and `destination`; this matches the
safe `rendergraph-pass-data` gameplay proof and the native exact-method target.

## Network Blind-Spot Checks

Network checks did not change the route:

- Unity RenderGraph docs say pass setup declares handles, `SetRenderFunc` runs
  after graph compile, and actual resources are accessed inside the rendering
  function. They also state that implicit conversion outside a rendering function
  can throw because resources may not be allocated yet.
- Unity HDRP DLSS docs tie DLSS to HDRP Dynamic Resolution, HDRP Asset DLSS
  enablement, camera dynamic-resolution permission, and NVIDIA package support.
- NVIDIA Streamline DLSS requires render-resolution input color, final-resolution
  output color, depth, and motion vectors, then calls evaluate on the rendering
  thread at the upscaling point with matching current-frame tags/constants.
- OptiScaler's public model is also input-boundary-driven: it intercepts an
  existing upscaler input and redirects it to another backend; it is not a model
  for arbitrary global texture discovery.
- BepInEx confirms HarmonyX/RuntimeDetour support exists, but generic patching
  support does not override this project's V Rising-specific crash/silent-wrapper
  evidence.

## Boundary Decision

There is still no proven safe BepInEx/Harmony equivalent to official
`DoDLSSPass -> DLSSPass.GetCameraResources -> DLSSPass.Render(ctx.cmd)` in
current V Rising.

Rejected or limited:

- `DLSSPass.Render(...)`: exact official wrapper, but targeted Harmony patch
  crashed in `UnityPlayer.dll` before prefix signal.
- Broad compiler-generated render-func Harmony patching: crashed in `coreclr.dll`.
- `RenderGraph.PreRenderPassExecute(...)` and ref-`CompiledPassInfo` executor
  wrappers: rejected after local crash evidence.
- `RenderGraphPass<T>.Execute` / `GetExecuteDelegate<T>` managed wrappers:
  static/patch-stability evidence only; focused callback probes were silent.
- `RenderGraphResourceRegistry.GetTexture(...)`: proven diagnostic tuple oracle
  only; no-evaluate performance runs show it is too hot for steady-state.
- `CreateTextureCallback(...)`: patch-stable, but not a useful replacement
  boundary.
- `DynamicResolutionHandler.Update(...)`: useful performance driver only; real
  cached evaluate crashed in the NVIDIA D3D11 user-mode driver.

Most plausible current direction:

- Keep the exact native method pointer for
  `_EdgeAdaptiveSpatialUpsampling_b__1066_0` as the nearest active pass-owned
  boundary.
- Use the proven `CompileRenderGraph(int)` observation point to read managed
  pass-data identity and `TextureHandle` resource-handle summaries.
- Use the proven native render-func argument preflight only to sample raw pointer
  values; do not dereference pointers in the native callback.
- Next experiment should be a default-off resource-identity preflight that
  correlates the native `passDataPtr` with the managed `EASUData` object observed
  at compile time. It should not touch `GetTexture`, command buffers, native
  resource pointers, or DLSS evaluate.

## Sources

- Unity Graphics 2022.3 `HDRenderPipeline.PostProcess.cs`:
  https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs
- Unity Graphics 2022.3 `DLSSPass.cs`:
  https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs
- Unity Graphics 2022.3 `RenderGraph.cs`:
  https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs
- Unity Graphics 2022.3 `RenderGraphPass.cs`:
  https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphPass.cs
- Unity Graphics 2022.3 `RenderGraphResourceRegistry.cs`:
  https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs
- Unity RenderGraph writing guide:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4016.0/manual/render-graph-writing-a-render-pipeline.html
- Unity HDRP DLSS guide:
  https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4016.0/manual/deep-learning-super-sampling-in-hdrp.html
- NVIDIA Streamline DLSS guide:
  https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md
- BepInEx runtime patching docs:
  https://docs.bepinex.dev/articles/dev_guide/runtime_patching.html
- OptiScaler README:
  https://github.com/optiscaler/OptiScaler
