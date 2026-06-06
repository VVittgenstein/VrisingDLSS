# HDRP RenderGraph Boundary Refresh - 2026-06-06

Status: narrow search refresh. No game launch.

## Question

This pass answers only one question:

Where does Unity HDRP's official DLSS path obtain resources and submit evaluate,
and is there a BepInEx/Harmony-accessible boundary in V Rising with comparable
resource lifetime and command-buffer ordering?

It intentionally does not revisit broad DLSS performance theory.

## Evidence Order

Local and upstream source remain primary:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraph.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphPass.cs`
- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`

The local Unity Graphics package snapshot is `com.unity.render-pipelines.high-definition`
`14.0.12` / Unity `2022.3`, which matches the V Rising HDRP evidence used by the
interop probes.

## Source Answer

Official HDRP DLSS is a RenderGraph pass-execution boundary:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

Key source facts:

- `RenderPostProcess(...)` calls `DoDLSSPasses(...)` at the HDRP upsampler
  schedule points.
- `DoDLSSPass(...)` registers the `Deep Learning Super Sampling` pass and
  declares `source`, `output`, `depth`, `motionVectors`, and optional
  `biasColorMask`.
- The DLSS pass render function calls
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(...), ctx.cmd)`.
- `DLSSPass.GetCameraResources(...)` converts the current pass's
  `TextureHandle` group into real `Texture` objects.
- `DLSSPass.Render(...)` builds the DLSS input/output resolution, jitter, reset,
  pre-exposure, and texture table, then submits `ExecuteDLSS(...)`.

So the official point is not `GetTexture` resource discovery and not
`CreateTextureCallback(...)`. It is the upscaler pass render function after
RenderGraph has compiled the graph and created current-pass resources.

## Network Refresh

Newly saved reference snapshots:

- `ref/hdrp-rendergraph-boundary-2026-06-06/Unity-HDRP-DLSS-16.0.html`
- `ref/hdrp-rendergraph-boundary-2026-06-06/Unity-HDRP-Dynamic-Resolution-13.1.html`
- `ref/hdrp-rendergraph-boundary-2026-06-06/BepInEx-Runtime-Patching.html`

These supplement the existing local snapshots for Unity RenderGraph
fundamentals, Unity RenderGraph writing, NVIDIA Streamline, and OptiScaler.

The external checks reinforce the existing route:

- Unity RenderGraph documentation says actual resources are accessible in render
  pass execution code, while pass setup only declares handles.
- Unity HDRP DLSS documentation ties DLSS to HDRP Dynamic Resolution, HDRP Asset
  DLSS enablement, camera Allow Dynamic Resolution, camera Allow DLSS, and the
  NVIDIA package.
- BepInEx confirms runtime patching support through HarmonyX and RuntimeDetour,
  but that generic capability does not override local crash evidence for specific
  V Rising IL2CPP wrappers.
- OptiScaler's public model continues to support the "known temporal upscaler
  input boundary" pattern, not arbitrary high-frequency texture discovery.

## Boundary Decision

There is still no proven safe BepInEx/Harmony-equivalent boundary for V Rising's
official HDRP DLSS execution window.

Keep this classification:

| Boundary | Decision |
| --- | --- |
| `RenderGraph.CompileRenderGraph(int)` | Accepted as read-only map only. Too early for evaluate. |
| pass-list/pass-declaration/pass-data/renderFunc metadata | Accepted as compile-time evidence only. |
| `RenderGraphResourceRegistry.GetTexture(...)` postfix | Diagnostic tuple oracle only. Too hot for production placement. |
| `CreateTextureCallback(...)` | Rejected as replacement boundary; no useful materialization-only gameplay signal. |
| `DynamicResolutionHandler.Update(...)` cached driver | Rejected as real evaluate boundary; no-evaluate isolation was useful, real evaluate crashed. |
| `DLSSPass.GetCameraResources(...)` | Research-only; no callbacks observed and likely depends on the official DLSS pass executing. |
| `DLSSPass.Render(...)` | Rejected; targeted Harmony patch crashed before prefix log. |
| generated HDRP render funcs | Rejected as normal Harmony route; prior patching crashed. |
| ref-`CompiledPassInfo` executor wrappers | Rejected as next normal route; `PreRenderPassExecute` crashed. |
| `RenderGraphPass<T>.Execute` / `RenderFunc<T>.Invoke` wrappers | Rejected as next normal route; local wrapper/delegate evidence and silent probe make them poor targets. |

## Next Step

Do not rerun unchanged rejected probes and do not launch a gameplay test from this
search result alone.

The safest immediate path is:

1. Use `rendergraph-compiled-pass-info` only as a menu-first, read-only
   `CompileRenderGraph(int)` map/lifetime proof if that runtime signal is still
   needed.
2. If approaching the true execution boundary, first design a separate
   `native-renderfunc-entry` no-op method-pointer probe. It must count entry only,
   resolve no textures, touch no command buffer, run no DLSS, start menu-only, and
   be treated as a new risk class rather than ordinary Harmony patching.
