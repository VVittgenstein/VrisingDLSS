# V Rising HDRP Asset Unpack Follow-Up - 2026-06-08

Status: local/static investigation completed. No V Rising runtime launch was
performed, and no game files were modified.

## Scope And Clean-Room Boundary

This is a follow-up to
`docs/development/vrising-systematic-local-decompilation-investigation-2026-06-08.md`.
It answers the asset-side part of the same question: which HDRP asset V Rising
actually points Unity `GraphicsSettings` at, and what do its serialized dynamic
resolution / DLSS fields say?

Allowed evidence here:

- local asset object names, path ids, script bindings, serialized field values,
  method/type names, field offsets, and xref summaries;
- tool and command notes needed to reproduce the read-only inspection.

Not allowed in release artifacts:

- modified V Rising files;
- copied decompiled game method bodies or assets;
- redistributed Unity/NVIDIA/game binaries outside separately reviewed terms.

## Inputs

- Game root: `C:\Software\VRising`
- Game version: `VRising: v1.1.13.0-r99712-b17 (202605251526)`
- Unity version from `globalgamemanagers`: `2022.3.58f1`
- Asset files:
  - `C:\Software\VRising\VRising_Data\globalgamemanagers`
  - `C:\Software\VRising\VRising_Data\globalgamemanagers.assets`
  - `C:\Software\VRising\VRising_Data\resources.assets`
  - `C:\Software\VRising\VRising_Data\sharedassets0.assets`
  - `C:\Software\VRising\VRising_Data\sharedassets1.assets`
- Local generated metadata/type inputs:
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/DummyDll/`
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/dump.cs`
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/script.json`

Additional read-only tooling installed into the user's requested local Python
environment:

- `UnityPy 1.25.0`
- `TypeTreeGeneratorAPI 0.0.10`

Tooling note: `TypeTreeGeneratorAPI.load_il2cpp()` failed against the local
`GameAssembly.dll` / metadata v31 pair, but `load_local_dll_folder()` succeeded
with the Il2CppDumper `DummyDll` folder and generated usable type trees for
`HDRenderPipelineAsset` and `GlobalDynamicResolutionSettings`.

PowerShell note: regexes containing IL2CPP names such as
`HDRenderPipeline$$(...)` must be single-quoted. In double quotes, PowerShell can
treat `$(` as expression syntax.

## Evidence 1: Unity GraphicsSettings Selects HDRP DefaultSettings

`UnityPy` can read the built-in `GraphicsSettings` object from
`globalgamemanagers`.

Key serialized value:

| Field | Value |
| --- | --- |
| `GraphicsSettings.m_CustomRenderPipeline.m_FileID` | `1` |
| `GraphicsSettings.m_CustomRenderPipeline.m_PathID` | `9008` |

The corresponding `MonoBehaviour` in `globalgamemanagers.assets` is:

| Path id | Name | Script |
| --- | --- | --- |
| `9008` | `HDRP DefaultSettings` | `HDRenderPipelineAsset` |

Evidence level: strong serialized asset evidence.

Inference: the active SRP asset for this local V Rising build is
`HDRP DefaultSettings`, not `HDRP_Low` or `HDRP_Medium`.

## Evidence 2: Active HDRP Asset Uses RenderGraph And FSR/EASU, Not DLSS

Using type trees generated from local Il2CppDumper `DummyDll`, the
`HDRenderPipelineAsset` instances parse cleanly.

Active asset:

| Field | `HDRP DefaultSettings` |
| --- | --- |
| `path_id` | `9008` |
| `allowShaderVariantStripping` | `1` |
| `enableSRPBatcher` | `1` |
| `m_UseRenderGraph` | `1` |
| `m_Version` | `22` |
| `dynamicResolutionSettings.enabled` | `1` |
| `dynamicResolutionSettings.useMipBias` | `1` |
| `dynamicResolutionSettings.enableDLSS` | `0` |
| `dynamicResolutionSettings.DLSSPerfQualitySetting` | `0` |
| `dynamicResolutionSettings.DLSSInjectionPoint` | `0` |
| `dynamicResolutionSettings.DLSSUseOptimalSettings` | `1` |
| `dynamicResolutionSettings.DLSSSharpness` | `0.5` |
| `dynamicResolutionSettings.fsrOverrideSharpness` | `0` |
| `dynamicResolutionSettings.fsrSharpness` | `0.9200000166893005` |
| `dynamicResolutionSettings.maxPercentage` | `100.0` |
| `dynamicResolutionSettings.minPercentage` | `1.0` |
| `dynamicResolutionSettings.dynResType` | `1` |
| `dynamicResolutionSettings.upsampleFilter` | `4` |
| `dynamicResolutionSettings.forceResolution` | `0` |
| `dynamicResolutionSettings.forcedPercentage` | `100.0` |

Enum meanings from local dump/upstream source:

| Value | Meaning |
| --- | --- |
| `DLSSInjectionPoint=0` | `DynamicResolutionHandler.UpsamplerScheduleType.BeforePost` |
| `dynResType=1` | `DynamicResolutionType.Hardware` |
| `upsampleFilter=4` | `DynamicResUpscaleFilter.EdgeAdaptiveScalingUpres` / FSR 1.0 EASU |

Evidence level: strong serialized asset plus enum metadata evidence.

Inference: V Rising's active HDRP asset is configured for RenderGraph and
hardware dynamic resolution with FSR/EASU as the upscaler, while official HDRP
DLSS is disabled at the asset gate (`enableDLSS=0`).

## Evidence 3: Low/Medium HDRP Assets Also Do Not Enable DLSS

Additional `HDRenderPipelineAsset` objects in `globalgamemanagers.assets`:

| Path id | Name | Dynamic resolution enabled | DLSS enabled | Upscale filter |
| --- | --- | ---: | ---: | ---: |
| `9009` | `HDRP_Low` | `0` | `0` | `4` |
| `9010` | `HDRP_Medium` | `0` | `0` | `4` |

They otherwise share the same DLSS defaults:

- `DLSSInjectionPoint=0` (`BeforePost`)
- `DLSSUseOptimalSettings=1`
- `DLSSSharpness=0.5`
- `fsrSharpness=0.9200000166893005`
- `forcedPercentage=100.0`

Evidence level: strong serialized asset evidence.

Inference: switching among these bundled HDRP quality assets would not reveal a
serialized official DLSS-on asset. The only active default asset has dynamic
resolution enabled, but still has official DLSS disabled.

## Evidence 4: Global Settings Confirm V Rising Custom Postprocess Types

`HDRenderPipelineGlobalSettings` is present as a `MonoBehaviour`:

| Path id | Name | Script |
| --- | --- | --- |
| `9004` | `HDRenderPipelineGlobalSettings` | `HDRenderPipelineGlobalSettings` |

Full type-tree parsing for this object failed with both the BepInEx interop
generator and the Il2CppDumper `DummyDll` generator, but its serialized string
payload is readable and includes V Rising custom postprocess type names:

- `CustomVignette, ProjectM`
- `DarkForeground, ProjectM`
- `BatFormFog, ProjectM`
- `ProjectM.ContestAreaEffect, ProjectM`

Evidence level: strong for object identity and embedded type-name strings;
insufficient for every structured list/field in `HDRenderPipelineGlobalSettings`.

Inference: V Rising does have custom HDRP postprocess registration in global
settings. This supports the earlier conclusion that the game drives a real
HDRP/postprocess customization surface, but it does not show a game-specific
DLSS implementation.

## Evidence 5: ProjectM FSR Layer Exists; ProjectM DLSS Layer Not Found

Local IL2CPP metadata still shows a V Rising-specific FSR/dynamic-resolution
control layer:

| Symbol | Address |
| --- | ---: |
| `ProjectM.GraphicsSettingsManager.InitializeGlobalSettings` | `131550384` |
| `ProjectM.GraphicsSettingsManager.InitializeGameSettings` | `131550704` |
| `ProjectM.GraphicsSettingsManager.TryApplyGameSettings` | `131551280` |
| `ProjectM.GraphicsSettingsManager.TryApplyGraphicsSettingsToCamera` | `131558992` |
| `ProjectM.GraphicsSettingsManager.GetDynResForQualityMode` | `131560496` |
| `ProjectM.GraphicsSettingsManager.TurnOffFSR` | `131560576` |
| `ProjectM.GraphicsSettingsManager.TurnOnFSR` | `131560912` |
| `ProjectM.GraphicsSettingsManager.SetFSRQuality` | `131561184` |

The local enum remains:

| `FSRQualityMode` | Value |
| --- | ---: |
| `Off` | `0` |
| `UltraQuality` | `1` |
| `Quality` | `2` |
| `Balanced` | `3` |
| `Performance` | `4` |

Focused search for `dlss`, `ngx`, `nvidia`, `streamline`, and `nvngx` under
local `ProjectM` metadata did not find a V Rising-specific DLSS control layer.
Focused filesystem search under `C:\Software\VRising`, excluding our
`BepInEx/plugins/VrisingDLSS` and config files, found no NVIDIA/DLSS/NGX/
Streamline runtime files.

Evidence level: strong for the FSR layer; moderate negative evidence for a
game-specific DLSS layer and local runtime files.

Inference: V Rising's game-side graphics layer wraps FSR/dynamic resolution, not
a hidden DLSS/NGX/Streamline implementation.

## Updated Answers

### Does the actual HDRP asset enable official DLSS?

No. The active `GraphicsSettings.m_CustomRenderPipeline` points to
`HDRP DefaultSettings` (`path_id=9008`), whose serialized
`dynamicResolutionSettings.enableDLSS` is `0`.

### Does V Rising use RenderGraph in this HDRP route?

Yes. The active HDRP asset has `m_UseRenderGraph=1`, and local xrefs already
show the HDRP postprocess/DLSS/EASU/FinalPass RenderGraph shell.

### Why does the official DLSS pass not appear under normal settings?

Evidence now covers both sides of the gate:

- serialized asset gate: `dynamicResolutionSettings.enableDLSS=0`;
- runtime snapshot: `cameraCanRenderDLSS=False`, `HDCamera.IsDLSSEnabled=False`,
  and no `"Deep Learning Super Sampling"` pass observed.

The static xref evidence still shows the activation/object lifecycle is absent
or inert, so simply flipping the asset gate is not expected to be the
performance fix.

### Is the current EASU boundary accidental?

No. The active HDRP asset explicitly uses
`DynamicResUpscaleFilter.EdgeAdaptiveScalingUpres` (`upsampleFilter=4`), and
the V Rising graphics layer exposes FSR quality controls. The EASU boundary is
the game's configured dynamic-resolution upscaler path, but it is still not the
official DLSS RenderGraph contract because EASU declares only a source and
destination, not the DLSS source/output/depth/motion/bias contract.

## Durable Decision

Promote the asset evidence from "string markers only" to "serialized active
asset values." The official HDRP DLSS shell remains useful as the semantic
resource-order contract, but the actual V Rising asset and xrefs both explain
why the shell is not scheduled normally.

Mainline remains unchanged:

1. do not try to publish a route that patches game assets or distributes
   modified game files;
2. do not treat `m_DLSSPass` activation as the likely performance fix;
3. continue with the no-native `hdrp-dlss-contract-bind-render-scale` proof
   when Computer Use is available;
4. if static work continues before runtime, inspect only branch/resource
   summaries around the listed RVAs in a native disassembler and record no
   proprietary method bodies.
