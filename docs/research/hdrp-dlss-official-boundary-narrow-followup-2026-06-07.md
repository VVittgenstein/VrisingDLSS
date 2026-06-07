# HDRP DLSS Official Boundary Narrow Follow-Up - 2026-06-07

Status: local/upstream source first, narrow network/source refresh second. No
game launch.

## Question

Where does Unity HDRP/RenderGraph's official DLSS path obtain live resources and
submit evaluate, and is there a BepInEx/Harmony-accessible boundary with similar
safety in V Rising?

This follow-up intentionally avoids broad DLSS performance theory. It only
checks the official HDRP execution boundary and nearby mod-accessible analogs.

## Source Answer

The official HDRP boundary remains:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

Local source anchors:

- `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
  calls `DoDLSSPasses(...)` from `RenderPostProcess(...)` at the HDRP dynamic
  resolution upsampler schedule points.
- `DoDLSSPasses(...)` returns unchanged unless `m_DLSSPassEnabled` is true and
  the active schedule matches the HDRP asset `DLSSInjectionPoint`.
- `DoDLSSPass(...)` records a RenderGraph pass named `Deep Learning Super
  Sampling`, declares `source`, `output`, `depth`, `motionVectors`, and optional
  `biasColorMask`, and writes `GetPostprocessUpsampledOutputHandle(...,
  "DLSS destination")`.
- The pass render func calls
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(data.resourceHandles), ctx.cmd)`.
- `DLSSPass.GetCameraResources(...)` converts the pass-local handle group into
  actual `Texture` resources. `DLSSPass.Render(...)` then prepares render/output
  sizes, jitter, reset, pre-exposure, texture table, and calls `ExecuteDLSS(...)`
  when Unity's NVIDIA module path is present.
- Core RenderGraph executes compiled passes as
  `PreRenderPassExecute(...) -> pass.Execute(ctx) -> PostRenderPassExecute(...)`.

Unity's RenderGraph documentation matches this: actual resources are only
available in render pass execution code; resources are created just before their
first needed pass and released after their last use. Therefore a global
`RenderGraphResourceRegistry.GetTexture(...)` callback is a diagnostic oracle,
not the official production boundary.

## V Rising Evidence

Fresh static metadata probe:

```powershell
.\scripts\probe-vrising-render-metadata.ps1 -GamePath "C:\Software\VRising" -Json
```

Relevant positives:

- `Deep Learning Super Sampling`, `DLSS Color Mask`, and `DLSS destination`
  strings are present.
- `HDRenderPipeline.GetPostprocessUpsampledOutputHandle`, `DoDLSSPasses`, and
  `DoDLSSPass` are present in generated HDRP interop.
- `DLSSPass.ViewResourceHandles` has `source`, `output`, `depth`,
  `motionVectors`, and `biasColorMask`.
- `DLSSPass.ViewResources` exposes matching `Texture` fields.
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`,
  and `Render(Parameters, CameraResources, CommandBuffer)` exist.

Relevant negatives:

- The local metadata/runtime scan still does not expose Unity's complete NVIDIA
  module stack: `DLSSContext`, `DLSSCommandInitializationData`,
  `DLSSTextureTable`, `DLSSQuality`, `NVUnityPlugin`, `NGX`, and `nvsdk_ngx`
  are absent.
- Prior local evidence remains binding: direct `DLSSPass.Render(...)` Harmony
  patch crashed in `UnityPlayer.dll`; generated HDRP render-func Harmony routes
  crashed in `coreclr.dll`; RenderGraph ref-executor wrapper routes crashed or
  produced no useful signal; `CreateTextureCallback(...)` is creation support,
  not evaluate.

## Narrow Mod References

OptiScaler does not solve this boundary for V Rising. Its public model is to
intercept a game that already reaches DLSS/XeSS/FSR-style upscaler API inputs
and translate them to another backend. That is useful when the game has an
existing temporal upscaler API boundary. It does not provide Unity RenderGraph
resources when V Rising's built-in HDRP DLSS pass is absent/inactive.

PureDark's V Rising PerfMod is a more relevant local reference:

- `ref/PureDark-VRisingPerfMod/PerfMod/Patches/UpscalePatches.cs` patches
  `CustomVignette.IsActive` and `CustomVignette.Render`.
- The render postfix calls `UpscaleManager.instance.UpscaleFlat.Render(cmd,
  camera, source, destination)`.
- `ref/PureDark-VRisingPerfMod/PerfMod/Upscale/UpscaleFlat.cs` gathers
  `source.rt`, `destination.rt`, `_CameraDepthTexture`, and
  `_CameraMotionVectorsTexture`, then submits native work via
  `cmd.IssuePluginEvent(GetEvaluateFunc(), id)`.
- The same file keeps commented traces of a direct `CustomPostProcessVolumeComponent`
  route, but the released/reference code uses an existing `CustomVignette`
  boundary instead.

That makes HDRP Custom Post Process or an existing custom post-process component
the only newly plausible BepInEx-adjacent direction. It is still not equivalent
to official `DLSSPass.GetCameraResources(...)`: it gives current `CommandBuffer`,
source/destination RTHandles, and globally bound depth/motion textures, but not
Unity's `DLSSPass.CameraResources` structure.

## Decision

| Boundary | Decision |
| --- | --- |
| Official `DoDLSSPass -> DLSS render func -> GetCameraResources -> Render(ctx.cmd)` | Exact map only; built-in NVIDIA DLSS stack is absent/inactive. |
| `DLSSPass.Render(...)` Harmony patch | Rejected; local crash. |
| Generated render funcs / RenderGraph ref-executor wrappers | Rejected as normal route; local crash/no-signal evidence. |
| `CompileRenderGraph(int)` | Safe metadata observation only. |
| `RenderGraphResourceRegistry.GetTexture(...)` | Keep as diagnostic tuple/native-pointer oracle only; too hot and no `ctx.cmd`. |
| `CreateTextureCallback(...)` | Not equivalent; creation/clear support only. |
| OptiScaler-style API proxy | Requires an existing upscaler API call boundary; not enough for V Rising. |
| Existing/custom HDRP post-process boundary | Best next BepInEx-accessible candidate, but must first prove safe component/Volume or existing component entry without native/DLSS. |

## Next Experiment

The next safe branch should be a default-off HDRP custom-postprocess path proof:

1. Prove injected/custom-postprocess `VolumeComponent` creation can be made safe
   in V Rising IL2CPP, after the earlier registration-only pass succeeded and
   hidden Volume/Profile creation failed with `VolumeComponent.OnEnable` NRE.
2. If creation is safe, prove `Render(...)` can be reached in a true `1920x1080`
   Windowed menu run with no native calls, no resource pointer probing, no
   DLSS, and capped logs.
3. Only after that, consider a no-evaluate resource snapshot from that boundary.

Do not rerun rejected Harmony render-func, `DLSSPass.Render`, ref-executor, or
global steady-state `GetTexture` routes unchanged.

