# V Rising Systematic Local Decompilation Investigation - 2026-06-08

Status: local/static investigation completed for this pass. No V Rising runtime
launch was performed, and no game files were modified.

Follow-up repeatable audit:
`docs/development/vrising-hdrp-dlss-static-route-audit-2026-06-08.md`.
The corresponding local JSON artifact is
`artifacts/research/vrising-hdrp-dlss-static-route-audit-20260608.json`.

Native-stub/boundary refresh:
`docs/development/vrising-local-decompilation-boundary-refresh-2026-06-08.md`.
This follow-up adds a repeatable PE entry-byte audit via
`scripts/inspect-vrising-hdrp-dlss-native-stubs.ps1`, confirming that
`DLSSPass.SetupFeature` returns false, `DLSSPass.Create` returns null, and
`DLSSPass.BeginFrame` / `SetupDRSScaling` / `Render` / `.ctor` return
immediately, while `RenderPostProcess`, `DoDLSSPass`, and
`DLSSPass.CreateCameraResources` remain non-stub shell/resource-contract
methods.

## Scope And Clean-Room Boundary

Goal: reconstruct the practical V Rising HDRP / RenderGraph / dynamic
resolution / postprocess route well enough to choose the smallest stable
runtime patch boundary for a clean-room DLSS Super Resolution mod.

Allowed evidence in this document:

- local type names, method names, signatures, RVAs/addresses, field offsets,
  string markers, xref summaries, and pass/resource relationships;
- distilled comparisons against local UnityGraphics 2022.3 HDRP source;
- summaries of our own diagnostic runtime logs.

Not allowed in release artifacts:

- modified game files;
- copied decompiled V Rising method bodies or game assets;
- redistributed Unity/NVIDIA/game proprietary code or binaries beyond their
  separately reviewed redistribution terms.

## Inputs

- Game binary and metadata:
  - `C:\Software\VRising\GameAssembly.dll`
  - `C:\Software\VRising\VRising_Data\il2cpp_data\Metadata\global-metadata.dat`
- Tool output:
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/dump.cs`
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/script.json`
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/stringliteral.json`
- BepInEx interop and xref cache:
  - `C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.HighDefinition.Runtime.dll`
  - `C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.Core.Runtime.dll`
  - `C:\Software\VRising\BepInEx\interop\MethodAddressToToken.db`
  - `C:\Software\VRising\BepInEx\interop\MethodXrefScanCache.db`
- Local reference source:
  - `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/`
  - `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.core/`

Representative commands used:

```powershell
rg -n "HDRenderPipeline\$\$(SetupDLSSFeature|SetupDLSSForCameraDataAndDynamicResHandler|InitializePostProcess|RenderPostProcess|GetPostprocessUpsampledOutputHandle|DoDLSSPasses|DoDLSSPass|EdgeAdaptiveSpatialUpsampling|FinalPass)" ref\decompilation-vrising-2026-06-08\il2cpp-dumper\script.json
rg -n "DLSSPass\$\$(Create|SetupFeature|BeginFrame|SetupDRSScaling|Render|GetViewResources|CreateCameraResources|GetCameraResources|\.ctor)" ref\decompilation-vrising-2026-06-08\il2cpp-dumper\script.json
C:\Software\dotnet\dotnet.exe artifacts\tools\InteropXrefProbe\bin\Release\net6.0\InteropXrefProbe.dll C:\Software\VRising
C:\Software\w64devkit\bin\strings.exe C:\Software\VRising\VRising_Data\globalgamemanagers.assets
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-vrising-hdrp-dlss-static-route.ps1 -GamePath C:\Software\VRising -Json
```

The repeatable audit script mechanically checks the same local IL2CPP method
anchors, DLSSPass execution shape, pass strings, field/layout evidence, HDRP
asset unpack, interop xref summary, ProjectM FSR/DLSS metadata search, and
upscaler-runtime file search. On this pass it reported `Status=Pass`,
`LaunchesGame=false`, `ModifiesGameFiles=false`, `HDRP anchors=9/9`,
`DLSSPass methods=9/9`, `DLSSPass execution shared address=0x171E170`,
`active asset enableDLSS=0`, `upsampleFilter=EdgeAdaptiveScalingUpres`,
`DoDLSSPassDeclaresRenderGraphBoundary=True`, `ActivateDLSSCallerCount=0`,
`ProjectM DLSS hits=0`, and `UpscalerRuntimeFilesOutsideMod=0`.

## Evidence 1: V Rising Contains The Official HDRP Postprocess Route Shell

Local `script.json` contains these HDRP anchors:

| Symbol | Address |
| --- | --- |
| `HDRenderPipeline.SetupDLSSFeature` | `157537088` / `0x963D340` |
| `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler` | `157552608` / `0x9640FE0` |
| `HDRenderPipeline.InitializePostProcess` | `157725152` / `0x966B7E0` |
| `HDRenderPipeline.GetPostprocessUpsampledOutputHandle` | `157739520` / `0x966EA00` |
| `HDRenderPipeline.RenderPostProcess` | `157740864` / `0x966EF40` |
| `HDRenderPipeline.DoDLSSPasses` | `157746560` / `0x9670580` |
| `HDRenderPipeline.DoDLSSPass` | `157747008` / `0x9670740` |
| `HDRenderPipeline.EdgeAdaptiveSpatialUpsampling` | `157903200` / `0x9696960` |
| `HDRenderPipeline.FinalPass` | `157905040` / `0x9697090` |

Local `stringliteral.json` also contains:

- `"Deep Learning Super Sampling"`
- `"DLSS destination"`
- `"Edge Adaptive Spatial Upsampling"`
- `"1.AMD FSR 1.0"`
- `"TAAU\n"`
- `"FSR Mode {0}\n"`

Local xref cache, read through `InteropXrefProbe`, confirms:

- `DoDLSSPasses` has `CallerCount=5`, and all users are
  `HDRenderPipeline.RenderPostProcess`.
- `DoDLSSPass` has `CallerCount=1`, from `DoDLSSPasses`.
- `DoDLSSPass` outgoing xrefs include `RenderGraph.AddRenderPass`,
  `RenderGraphBuilder.ReadTexture`, `DLSSPass.CreateCameraResources`,
  `RenderFunc<T>.ctor`, and `RenderGraphBuilder.SetRenderFunc`.
- `FinalPass` has `CallerCount=1`, from `RenderPostProcess`.

Evidence level: strong metadata, string, and xref evidence.

Inference: V Rising did not replace the HDRP postprocess/upscale route with a
completely custom renderer. The Unity HDRP 2022.3 postprocess route shell is
present and remains the best semantic map for resource order.

## Evidence 2: The Built-In DLSS Activation/Object Lifecycle Is Absent Or Inert

Local `script.json` distinguishes real DLSS resource helpers from inert
execution bodies:

| Symbol | Address |
| --- | --- |
| `DLSSPass.GetViewResources` | `158455744` / `0x971D7C0` |
| `DLSSPass.CreateCameraResources` | `158456528` / `0x971DAD0` |
| `DLSSPass.GetCameraResources` | `158457216` / `0x971DD80` |
| `DLSSPass.SetupFeature` | `24318624` / `0x17312A0` |
| `DLSSPass.Create` | `24377088` / `0x173F700` |
| `DLSSPass.BeginFrame` | `24240496` / `0x171E170` |
| `DLSSPass.SetupDRSScaling` | `24240496` / `0x171E170` |
| `DLSSPass.Render` | `24240496` / `0x171E170` |
| `DLSSPass..ctor` | `24240496` / `0x171E170` |

Local xref evidence from the earlier m_DLSSPass audit remains decisive:

- `HDRenderPipeline.SetupDLSSFeature` is called by HDRP setup paths, but its
  outgoing xrefs do not resolve to `DLSSPass.SetupFeature` or
  `HDDynamicResolutionPlatformCapabilities.ActivateDLSS`.
- `HDDynamicResolutionPlatformCapabilities.ActivateDLSS` has `CallerCount=0`.
- `HDRenderPipeline.InitializePostProcess` has no resolved outgoing xref to
  `DLSSPass.Create`.
- `DLSSPass.Render`, `BeginFrame`, `SetupDRSScaling`, and `.ctor` share the same
  no-op-style address.

Focused filesystem search under `C:\Software\VRising` found no NVIDIA/DLSS/NGX
runtime file names other than our own mod files under `BepInEx\plugins`.

Evidence level: strong for the absent official activation chain and inert render
body; moderate for missing runtime files.

Inference: trying to "turn on" V Rising's built-in `m_DLSSPass` object is not a
good mainline. It is likely null, absent, or backed by a stripped/stubbed
implementation. `DoDLSSPass` is useful as a resource/schedule contract, not as a
native DLSS implementation to call.

## Evidence 3: Official HDRP DLSS Stage And Resource Contract

Local UnityGraphics 2022.3 source shows the official stage:

- `RenderPostProcess` may call `DoDLSSPasses` at `BeforePost`,
  `AfterDepthOfField`, or `AfterPost` depending on the upsample schedule.
- `DoDLSSPasses` returns early unless `m_DLSSPassEnabled` is true and the
  current schedule equals
  `currentAsset.currentPlatformRenderPipelineSettings.dynamicResolutionSettings.DLSSInjectionPoint`.
- `DoDLSSPass` adds a RenderGraph pass named `"Deep Learning Super Sampling"`.
- That pass reads source, depth, motion vectors, and optional bias color mask;
  writes a `"DLSS destination"` postprocess upsampled output; builds camera
  resources through `DLSSPass.CreateCameraResources`; and calls
  `data.pass.Render(..., ctx.cmd)` from the generated render function.

The same local source shows EASU and FinalPass as separate stages:

- `EdgeAdaptiveSpatialUpsampling` writes a postprocess upsampled output named
  `"Edge Adaptive Spatial Upsampling"`.
- `FinalPass` consumes the postprocess source and final target resources.

Evidence level: strong source evidence, aligned with local V Rising
metadata/xrefs.

Inference: our current EASU `ctx.cmd` candidate is an engine-owned visible
output boundary, but it is not semantically identical to the official DLSS pass
because EASU declares source/destination, while the official DLSS pass declares
source/output/depth/motion/bias resources as one pass contract.

## Evidence 4: Runtime And Serialized Asset Gate Values

Static metadata exposes the official gate fields:

| Field/property | Local evidence |
| --- | --- |
| `HDAdditionalCameraData.allowDynamicResolution` | `dump.cs` offset `0xA6` |
| `HDAdditionalCameraData.allowDeepLearningSuperSampling` | `dump.cs` offset `0xD4` |
| `HDAdditionalCameraData.cameraCanRenderDLSS` | `dump.cs` offset `0xE4` |
| `HDDynamicResolutionPlatformCapabilities.DLSSDetected` | local type/property present |
| `GlobalDynamicResolutionSettings.enabled` | `dump.cs` offset `0x0` |
| `GlobalDynamicResolutionSettings.enableDLSS` | `dump.cs` offset `0x2` |
| `GlobalDynamicResolutionSettings.DLSSInjectionPoint` | `dump.cs` offset `0x8` |

The follow-up asset unpack is recorded in
`docs/development/vrising-hdrp-asset-unpack-followup-2026-06-08.md`. It used
`UnityPy 1.25.0` plus `TypeTreeGeneratorAPI 0.0.10` against local
Il2CppDumper `DummyDll` type trees and read the Unity asset objects without
modifying game files.

Key serialized asset evidence:

- Unity `GraphicsSettings.m_CustomRenderPipeline` points to path id `9008`,
  `HDRP DefaultSettings`.
- `HDRP DefaultSettings` has `m_UseRenderGraph=1`.
- `HDRP DefaultSettings.dynamicResolutionSettings.enabled=1`.
- `HDRP DefaultSettings.dynamicResolutionSettings.enableDLSS=0`.
- `HDRP DefaultSettings.dynamicResolutionSettings.DLSSInjectionPoint=0`
  (`BeforePost`).
- `HDRP DefaultSettings.dynamicResolutionSettings.dynResType=1`
  (`Hardware`).
- `HDRP DefaultSettings.dynamicResolutionSettings.upsampleFilter=4`
  (`EdgeAdaptiveScalingUpres` / FSR 1.0 EASU).
- Additional `HDRP_Low` and `HDRP_Medium` assets also have `enableDLSS=0`;
  both have `dynamicResolutionSettings.enabled=0`.

Our read-only schedule-audit runtime log captured this normal menu state:

- `allowDeepLearningSuperSampling=True`
- `cameraCanRenderDLSS=False`
- `GlobalDynamicResolutionSettings.enabled=True`
- `GlobalDynamicResolutionSettings.enableDLSS=False`
- `DLSSInjectionPoint=BeforePost`
- `HDCamera.IsDLSSEnabled=False`
- `HDCamera.UpsampleSyncPoint=AfterPost`
- no `"Deep Learning Super Sampling"` RenderGraph pass observed

Earlier raw string extraction from `globalgamemanagers.assets`,
`resources.assets`, and `sharedassets0.assets` only found type/string markers.
The follow-up type-tree parse supersedes that limitation for the
`HDRenderPipelineAsset` objects.

Evidence level: strong for metadata fields, serialized active HDRP asset values,
and diagnostic runtime values. `HDRenderPipelineGlobalSettings` structured
fields are still only partially parsed; its object identity and embedded custom
postprocess type strings are reliable.

Inference: the practical normal game path does not schedule official HDRP DLSS
because both the serialized active asset gate (`enableDLSS=0`) and runtime
camera/gate snapshot (`cameraCanRenderDLSS=False`, `IsDLSSEnabled=False`) agree.
The active EASU path is not accidental: the active asset's upscaler is
explicitly `EdgeAdaptiveScalingUpres`.

## Evidence 5: V Rising Has Its Own FSR/Dynamic-Resolution Control Layer

Local V Rising-specific symbols include:

| Symbol | Address |
| --- | --- |
| `ProjectM.GraphicsSettingsManager.InitializeGlobalSettings` | `131550384` |
| `ProjectM.GraphicsSettingsManager.InitializeGameSettings` | `131550704` |
| `ProjectM.GraphicsSettingsManager.TryApplyGameSettings` | `131551280` |
| `ProjectM.GraphicsSettingsManager.TryApplyGraphicsSettingsToCamera` | `131558992` |
| `ProjectM.GraphicsSettingsManager.ActiveTAA` | `131560400` |
| `ProjectM.GraphicsSettingsManager.GetDynResForQualityMode` | `131560496` |
| `ProjectM.GraphicsSettingsManager.TurnOffFSR` | `131560576` |
| `ProjectM.GraphicsSettingsManager.TurnOnFSR` | `131560912` |
| `ProjectM.GraphicsSettingsManager.SetFSRQuality` | `131561184` |
| `ProjectM.ClientConsoleCommandSystem.GetFSRQualityModeSuggestions` | `124599536` |
| `ProjectM.ClientConsoleCommandSystem.DetermineFSRQualityMode` | `124600208` |

The enum is present locally:

```text
FSRQualityMode.Off = 0
FSRQualityMode.UltraQuality = 1
FSRQualityMode.Quality = 2
FSRQualityMode.Balanced = 3
FSRQualityMode.Performance = 4
```

Evidence level: strong metadata/signature/string evidence.

Inference: V Rising actively drives AMD FSR / TAAU / dynamic-resolution settings
through its own graphics settings layer. So far, no local evidence shows a
game-specific DLSS replacement layer.

## Boundary Assessment

Rejected as normal mainline:

- patching `DLSSPass.Render` directly;
- forcing `m_DLSSPass` as if the built-in object were a working NVIDIA path;
- broad per-frame `RenderGraphResourceRegistry.GetTexture` discovery;
- new mod-owned RenderGraph pass injection as the default route, given prior
  `coreclr.dll` crash evidence;
- re-running the same EASU visible-writeback candidate unchanged.

Useful evidence sources:

- `RenderGraph.CompileRenderGraph` / pass-list / pass-data / declarations:
  safe read-only schedule evidence, but too early for evaluate authority.
- `HDRenderPipeline.DoDLSSPass` xrefs: best official semantic contract.
- Engine-owned `Uber -> EASU -> FinalPass`: proven observable and visible, but
  incomplete as a DLSS contract unless same-log HDRP depth/motion correlation is
  bound.
- V Rising graphics settings symbols: useful for understanding why FSR/TAAU and
  dynamic-resolution state differs from pure upstream HDRP defaults.

## Repeatable Official-Contract Guard

Follow-up guard:
`scripts\test-vrising-hdrp-dlss-official-contract.ps1 -GamePath C:\Software\VRising`
now converts the key local decompilation/unpack findings into pass/fail evidence.
It also fixes the static-route inspector's pass-data layout parsing so adjacent
HDRP nested classes are not merged into one field list.

Local guard result:

```text
Status=Pass
LaunchesGame=false
ModifiesGameFiles=false
CheckCount=11
```

The guarded contract split is:

- official `DoDLSSPass`: color source/output plus depth, motion vectors, bias
  mask, reset-history, pre-exposure, camera, and DRS state;
- active V Rising EASU path: source/destination scaling plus `FinalPass`, without
  those DLSS-specific resources/parameters on EASU itself.

This evidence is recorded in
`docs/development/vrising-hdrp-dlss-official-contract-guard-2026-06-08.md` and is
now included as a `GamePath`-gated release-readiness evidence item.

## Current Answer To The User's Target Questions

### Is V Rising's HDRP route consistent with Unity HDRP source?

Yes for the postprocess scheduling shell and resource-contract shape:
`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass` exists locally, and xrefs show
the official RenderGraph add/read/write/set-render-func pattern.

No for the built-in NVIDIA activation/execution path: local xrefs and shared
stub-style addresses show the official `DLSSPass` object lifecycle is absent or
inert.

### Does `m_DLSSPass` exist, and when is it initialized?

The field exists in metadata. Static evidence does not show the normal upstream
assignment through `InitializePostProcess -> DLSSPass.Create`. The most likely
interpretation is null/inert in normal V Rising runtime.

### What are the actual gate values and sources?

The gate fields are present in metadata. Follow-up serialized asset parsing now
shows the active Unity `GraphicsSettings.m_CustomRenderPipeline` points to
`HDRP DefaultSettings`, with `m_UseRenderGraph=1`,
`dynamicResolutionSettings.enabled=1`, `enableDLSS=0`, `DLSSInjectionPoint=0`
(`BeforePost`), and `upsampleFilter=4` (`EdgeAdaptiveScalingUpres` / FSR 1.0
EASU). Our read-only runtime evidence separately shows
`cameraCanRenderDLSS=False`, `HDCamera.IsDLSSEnabled=False`, and no official
DLSS pass under normal menu conditions.

### Where is the official equivalent evaluate boundary?

Semantically, it is the `DoDLSSPass` RenderGraph pass: source/depth/motion/bias
reads, DLSS destination write, `DLSSPass.CreateCameraResources`, generated render
func, then `ctx.cmd`.

Practically, the built-in `DLSSPass.Render` implementation is not usable in this
V Rising build, so the mod needs an official-equivalent runtime boundary rather
than enabling Unity's own DLSS object.

### Is Computer Use/runtime probing the best next step?

Not for the mainline. The immediate next runtime action, if any, should be the
default-off `hdrp-dlss-contract-bind-render-scale` preflight created in commit
`f36991d`, because it binds HDRP source/depth/motion evidence to the observed
engine-owned `Uber -> EASU -> FinalPass` chain without native DLSS evaluate.

For static work, the next deeper step would be native-body inspection in
Ghidra/IDA using Il2CppDumper symbols for the listed RVAs, recording only
branch/resource summaries. That may refine patch placement, but it should still
not produce or distribute decompiled game code.

## Durable Decision

Use the official `DoDLSSPass` path as the resource-order contract, not as a
callable implementation. The current performance failure should be treated as a
boundary/lifecycle/synchronization problem: DLSS evaluate can succeed, but the
EASU visible-writeback point is not yet proven official-equivalent or cheap.

Mainline next step remains:

1. produce or inspect the no-native `hdrp-dlss-contract-bind-render-scale`
   evidence;
2. only if that binds source/depth/motion to the engine-owned chain, run a
   bounded no-write cost proof;
3. only after the no-write boundary is cheap, reintroduce NGX evaluate.
