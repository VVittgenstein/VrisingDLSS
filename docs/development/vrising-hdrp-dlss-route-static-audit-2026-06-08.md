# V Rising HDRP/DLSS Route Static Audit - 2026-06-08

Status: local/static investigation completed. No V Rising runtime launch was
performed for this pass.

## Scope And Clean-Room Boundary

This investigation answers one narrow question: what does the local V Rising
IL2CPP build actually contain around HDRP RenderGraph, dynamic resolution,
postprocess, EASU, FinalPass, and the official HDRP DLSS pass shell?

Allowed evidence recorded here:

- Local type names, method names, signatures, field names, tokens, RVAs, string
  markers, and pass/resource relationships.
- Distilled comparisons against local UnityGraphics 2022.3 HDRP source.
- Runtime log summaries already produced by our own diagnostics.

Not allowed in release artifacts:

- Modified game files.
- Decompiled V Rising method bodies or assets.
- NVIDIA SDK/runtime binaries or proprietary Unity/NVIDIA code beyond
  separately reviewed redistribution terms.

## Inputs

- V Rising binary and metadata:
  - `C:\Software\VRising\GameAssembly.dll`
  - `C:\Software\VRising\VRising_Data\il2cpp_data\Metadata\global-metadata.dat`
- Local Il2CppDumper output:
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/dump.cs`
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/script.json`
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/stringliteral.json`
- Local BepInEx/Il2CppInterop wrapper output:
  - `ref/decompilation-vrising-2026-06-07/ilspy-types/`
- Local upstream reference source:
  - `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/`
  - `ref/hdrp-rendergraph-boundary-2026-06-06/HDRenderPipeline.PostProcess.cs`
- Prior runtime evidence:
  - `docs/development/hdrp-dlss-schedule-audit-runtime-result-2026-06-08.md`
  - `docs/development/official-hdrp-dlss-flag-invert-paired-result-2026-06-08.md`

## Finding 1: V Rising Contains The Official HDRP Route Shell

V Rising's local IL2CPP metadata contains the expected HDRP postprocess and
upscale symbols:

| Symbol | Local evidence |
| --- | --- |
| `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler` | `dump.cs` RVA `0x9640FE0` |
| `HDRenderPipeline.GetPostprocessUpsampledOutputHandle` | `dump.cs` RVA `0x966EA00` |
| `HDRenderPipeline.RenderPostProcess` | `dump.cs` RVA `0x966EF40` |
| `HDRenderPipeline.DoDLSSColorMaskPass` | `dump.cs` RVA `0x966FE60` |
| `HDRenderPipeline.DoDLSSPasses` | `dump.cs` RVA `0x9670580` |
| `HDRenderPipeline.DoDLSSPass` | `dump.cs` RVA `0x9670740` |
| `HDRenderPipeline.EdgeAdaptiveSpatialUpsampling` | `dump.cs` RVA `0x9696960` |
| `HDRenderPipeline.FinalPass` | `dump.cs` RVA `0x9697090` |
| Generated DLSS render func | `<DoDLSSPass>b__969_0(DLSSData, RenderGraphContext)` at RVA `0x96F56E0` |
| Generated EASU render func | `<EdgeAdaptiveSpatialUpsampling>b__1066_0(EASUData, RenderGraphContext)` at RVA `0x96FE1C0` |
| Generated FinalPass render func | `<FinalPass>b__1069_0(FinalPassData, RenderGraphContext)` at RVA `0x96FE7F0` |

The pass strings are present too: `stringliteral.json` includes
`"Deep Learning Super Sampling"`, `"DLSS destination"`, and
`"Edge Adaptive Spatial Upsampling"`.

Evidence level: strong metadata/signature/string/RVA evidence. The exact local
native method bodies are not copied into this repository.

Inference: the route layout is the Unity HDRP 2022.3 route shell, not a
completely custom V Rising upscaler rewrite.

## Finding 2: The Built-In NVIDIA DLSS Execution Body Is Not Usable As-Is

The wrapper/metadata evidence distinguishes shell from implementation:

| Symbol group | Evidence |
| --- | --- |
| Real helper/shell methods | `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`, `SetupFeature`, and `Create` have distinct non-stub addresses in previous Il2CppDumper/script evidence. |
| Missing/inert execution body | `DLSSPass.BeginFrame`, `DLSSPass.SetupDRSScaling`, `DLSSPass.Render`, and `DLSSPass..ctor` all map to the same `RVA 0x171E170` / address `24240496`, a common empty/no-op-style stub in this dump. |

Evidence level: strong local metadata/RVA evidence.

Inference: V Rising includes the HDRP DLSS pass shell and resource structures,
but not a working compiled NVIDIA-backed `DLSSPass.Render` path we can simply
turn on. `m_DLSSPass` may be null, inert, or unable to progress to a real
NVIDIA evaluate path depending on creation/module state; that distinction can
be classified later, but it is no longer the expected performance fix.

## Finding 3: The Official Scheduling Gates Match Unity HDRP Source

Local Unity HDRP source shows `SetupDLSSForCameraDataAndDynamicResHandler`
sets `cameraCanRenderDLSS` only when all of these are true:

- The camera requested dynamic resolution.
- `HDDynamicResolutionPlatformCapabilities.DLSSDetected` is true.
- The camera allows DLSS.
- HDRP asset dynamic-resolution settings have `enableDLSS=true`.
- HDRP asset dynamic-resolution settings have `enabled=true`.

Local V Rising metadata exposes the same gate fields:

| Field/property | Local evidence |
| --- | --- |
| `HDAdditionalCameraData.allowDynamicResolution` | `dump.cs` offset `0xA6` |
| `HDAdditionalCameraData.allowDeepLearningSuperSampling` | `dump.cs` offset `0xD4` |
| `HDAdditionalCameraData.cameraCanRenderDLSS` | `dump.cs` offset `0xE4` |
| `HDDynamicResolutionPlatformCapabilities.DLSSDetected` | local type and property present |
| `GlobalDynamicResolutionSettings.enabled` | `dump.cs` offset `0x0` |
| `GlobalDynamicResolutionSettings.enableDLSS` | `dump.cs` offset `0x2` |
| `GlobalDynamicResolutionSettings.DLSSInjectionPoint` | `dump.cs` offset `0x8` |

Follow-up asset unpack evidence is recorded in
`docs/development/vrising-hdrp-asset-unpack-followup-2026-06-08.md`. It shows
Unity `GraphicsSettings.m_CustomRenderPipeline` points to `HDRP DefaultSettings`
(`path_id=9008`), whose serialized values include `m_UseRenderGraph=1`,
`dynamicResolutionSettings.enabled=1`, `dynamicResolutionSettings.enableDLSS=0`,
`DLSSInjectionPoint=0` (`BeforePost`), and `upsampleFilter=4`
(`EdgeAdaptiveScalingUpres` / FSR 1.0 EASU).

The read-only menu audit already captured V Rising's safe-settings state:

- `allowDeepLearningSuperSampling=True`
- `cameraCanRenderDLSS=False`
- `GlobalDynamicResolutionSettings.enableDLSS=False`
- `HDCamera.IsDLSSEnabled=False`
- `UpsampleSyncPoint=AfterPost`
- no `"Deep Learning Super Sampling"` RenderGraph pass observed

Evidence level: strong local source/metadata/serialized-asset/runtime-log
evidence.

Inference: under normal current settings, V Rising does not schedule the
official HDRP DLSS pass shell because the official gates are not all true.

## Finding 4: Official DLSS, EASU, And FinalPass Resource Relationships

Local interop metadata and Unity source line up on pass data shapes:

| Pass data | Key fields |
| --- | --- |
| `HDRenderPipeline.DLSSData` | `parameters`, `resourceHandles`, `pass` |
| `DLSSPass.Parameters` | `resetHistory`, `preExposure`, `hdCamera`, `drsSettings` |
| `DLSSPass.ViewResourceHandles` | `source`, `output`, `depth`, `motionVectors`, `biasColorMask` |
| `DLSSPass.CameraResourcesHandles` | `resources`, `copyToViews`, `tmpView0`, `tmpView1` |
| `HDRenderPipeline.EASUData` | `easuCS`, `mainKernel`, `viewCount`, `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`, `hdroutParams`, `source`, `destination` |
| `HDRenderPipeline.FinalPassData` | `performUpsampling`, `dynamicResIsOn`, `dynamicResFilter`, `drsSettings`, `source`, `afterPostProcessTexture`, `alphaTexture`, `uiBuffer`, `destination`, `postProcessIsFinalPass` |

The official HDRP sequence is:

```text
RenderPostProcess
  -> DoDLSSPasses at the configured DLSSInjectionPoint
  -> DoDLSSPass
  -> RenderGraph pass named "Deep Learning Super Sampling"
  -> source/depth/motion/bias-mask read handles plus "DLSS destination" write handle
  -> DLSSPass.GetCameraResources(...)
  -> DLSSPass.Render(..., ctx.cmd)
```

The current proven visible-output candidate instead uses the EASU pass
`ctx.cmd` and the EASU `source -> destination` relationship.

Evidence level: strong local source/interop metadata evidence.

Inference: our current EASU boundary is close enough to see the right
`960x540 -> 1920x1080` tuple, but it is not semantically identical to the
official DLSS pass boundary. That mismatch is a plausible source of the low GPU
utilization/performance regression even when NGX evaluate itself reports tiny
CPU wall time.

## Finding 5: V Rising Adds Real FSR/Dynamic-Resolution/Postprocess Control

V Rising-specific local metadata confirms a graphics layer around HDRP:

- `ProjectM.GraphicsSettingsManager` exposes `GetDynResForQualityMode`,
  `TurnOffFSR`, `TurnOnFSR`, and `SetFSRQuality`.
- `ProjectM.FSRQualityMode` maps `Off=0`, `UltraQuality=1`, `Quality=2`,
  `Balanced=3`, and `Performance=4`.
- V Rising includes concrete custom postprocess types such as
  `DarkForeground`, `VisualLineOfSightDebug`, `CustomVignette`,
  `LineOfSightVision`, `BatFormFog`, `LineOfSight`, and
  `ProjectM.ContestAreaEffect`.

Evidence level: strong metadata evidence.

Inference: V Rising customizes or drives FSR/dynamic-resolution/postprocess, but
no local evidence found so far shows a game-specific DLSS replacement layer.

## Boundary Assessment

Rejected or deprioritized for the next normal route:

- Re-running the same EASU `ctx.cmd` `dlss-user-rendering` candidate unchanged.
- Returning to broad per-frame `RenderGraphResourceRegistry.GetTexture` discovery.
- Patching `DLSSPass.Render` directly as the normal path; it has prior crash
  history and local static evidence points to a no-op-style body.
- Patching broad compiler-generated render-func families unchanged; previous
  attempts crashed before useful scoped evidence.
- Modifying or distributing game files.

Useful but not the immediate mainline:

- `hdrp-dlss-schedule-gate` remains a default-off menu-only classification tool.
  It can tell us whether forced gates make the official pass shell appear and
  whether `m_DLSSPass` is null, but it should not be treated as a likely
  performance fix because the execution body is missing/inert.

Best current mainline:

1. Keep using local decompilation/metadata/source evidence to identify the
   smallest official-equivalent boundary that avoids hot callbacks.
2. Treat the official DLSS pass as the semantic contract for resource ordering,
   not as an implementation to call.
3. Design the next proof as no-native/no-DLSS first: observe or construct a
   narrow RenderGraph/pass boundary with declared source/output/depth/motion
   handles and command-buffer timing comparable to the official DLSS pass.
4. Only after that boundary is proven cheap should NGX evaluate be introduced.

## Current Interpretation Of The Performance Failure

The latest candidate proves DLSS evaluate can succeed with:

- `input=960x540 output=1920x1080`
- official-HDRP-like flags `0x0000002B`
- `invertAxis=(0,1)`
- `RenderGraph GetTexture=0`
- no crash

But it still regresses FPS and drops GPU utilization. The best current
explanation is not "DLSS cannot run"; it is that evaluate/output submission is
still happening at a non-official-equivalent boundary or lifecycle, producing a
stall, synchronization bubble, resource hazard, or missed overlap.

## Next Static Questions

Before another gameplay/runtime probe, answer as much as possible locally:

1. Where exactly is `m_DLSSPass` assigned in V Rising, and can local xrefs prove
   whether `DLSSPass.Create(m_GlobalSettings)` is reachable or returns null?
2. Does `DLSSPass.Create`/`SetupFeature` reference an NVIDIA module that is
   absent/stripped, or does it create an inert object whose render body is stubbed?
3. Which BepInEx/Harmony-accessible boundary can observe official-like
   `source/output/depth/motion` handles without patching `DLSSPass.Render` and
   without broad `GetTexture`?
4. Can an official-equivalent no-native pass be inserted or selected near EASU /
   FinalPass with explicit resource declarations, then proven cheap before any
   NGX evaluate?

## Durable Decision

Pause direct runtime probing for this branch. The schedule-gate probe is
implemented and available, but the mainline next step is deeper local static
route work around `m_DLSSPass` creation and a no-native official-equivalent
RenderGraph/pass boundary.

## 2026-06-08 Follow-Up

The follow-up xref audit is recorded in
`docs/development/vrising-hdrp-dlss-m-dlsspass-xref-audit-2026-06-08.md`.
It found that `HDRenderPipeline.SetupDLSSFeature` is called locally, but does
not xref `DLSSPass.SetupFeature` or `HDDynamicResolutionPlatformCapabilities.ActivateDLSS`;
`ActivateDLSS` has `CallerCount=0`; and `InitializePostProcess` does not xref
`DLSSPass.Create`. The official `DoDLSSPasses` / `DoDLSSPass` RenderGraph shell
and resource contract remain useful, but the built-in `m_DLSSPass` activation
route should now be treated as absent/inert rather than as the likely next
performance fix.
