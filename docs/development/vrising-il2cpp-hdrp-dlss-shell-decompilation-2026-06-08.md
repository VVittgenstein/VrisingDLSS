# V Rising IL2CPP HDRP DLSS Shell Decompilation - 2026-06-08

Status: local/private reverse-engineering note. This is clean-room design
evidence only; do not copy proprietary game method bodies or game assets into
the public package.

## Question

Does V Rising's IL2CPP build contain a directly usable Unity HDRP NVIDIA DLSS
execution path, or only the HDRP pass shell/types that upstream Unity would use
when NVIDIA support is compiled in?

## Local Inputs

- Game binary: `C:\Software\VRising\GameAssembly.dll`
- Metadata: `C:\Software\VRising\VRising_Data\il2cpp_data\Metadata\global-metadata.dat`
- Tool output: `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/`
- Tool: `C:\Software\Il2CppDumper-6.7.46\Il2CppDumper.exe`

Il2CppDumper completed with metadata version `31` and IL2CPP version `31`.
Cpp2IL `2022.0.7` was tried only as a cross-check and rejected because it
supports older metadata versions (`24-29`) rather than V Rising's metadata
version `31`.

## Evidence

The HDRP postprocess and DLSS pass shell is present:

| Symbol | Evidence |
| --- | --- |
| `HDRenderPipeline.DoDLSSPasses` | `script.json` address `157746560`, `dump.cs` RVA `0x9670580` |
| `HDRenderPipeline.DoDLSSPass` | `script.json` address `157747008`, `dump.cs` RVA `0x9670740` |
| Generated `DoDLSSPass` render func | `dump.cs` shows `<DoDLSSPass>b__969_0(HDRenderPipeline.DLSSData, RenderGraphContext)` at RVA `0x96F56E0` |
| Generated EASU render func | `dump.cs` shows `<EdgeAdaptiveSpatialUpsampling>b__1066_0(HDRenderPipeline.EASUData, RenderGraphContext)` at RVA `0x96FE1C0` |
| Generated final pass render func | `dump.cs` shows `<FinalPass>b__1069_0(HDRenderPipeline.FinalPassData, RenderGraphContext)` at RVA `0x96FE7F0` |
| Pass strings | `stringliteral.json` contains `"Deep Learning Super Sampling"`, `"DLSS destination"`, and `"Edge Adaptive Spatial Upsampling"` |

The resource/parameter structs line up with upstream HDRP:

| Struct | Local fields |
| --- | --- |
| `DLSSPass.Parameters` | `resetHistory`, `preExposure`, `hdCamera`, `drsSettings` |
| `DLSSPass.ViewResourceHandles` | `source`, `output`, `depth`, `motionVectors`, `biasColorMask` |
| `DLSSPass.CameraResourcesHandles` | `resources`, `copyToViews`, `tmpView0`, `tmpView1` |
| `HDRenderPipeline.DLSSData` | `parameters`, `resourceHandles`, `pass` |
| `HDRenderPipeline.EASUData` | EASU compute/input/output fields, including source/destination handles and dimensions |

The helper methods that move resource handles into runtime resource objects have
real addresses:

| Symbol | Address |
| --- | ---: |
| `DLSSPass.GetViewResources` | `158455744` |
| `DLSSPass.CreateCameraResources` | `158456528` |
| `DLSSPass.GetCameraResources` | `158457216` |
| `DLSSPass.SetupFeature` | `24318624` |
| `DLSSPass.Create` | `24377088` |

The important negative evidence is the execution body:

| Symbol | Address |
| --- | ---: |
| `DLSSPass.BeginFrame` | `24240496` |
| `DLSSPass.SetupDRSScaling` | `24240496` |
| `DLSSPass.Render` | `24240496` |
| `DLSSPass..ctor` | `24240496` |

These all map to the same `RVA 0x171E170`, a common empty/no-op stub used by
many stripped or not-compiled method bodies in the dump. In contrast,
`DoDLSSPass`, `DoDLSSPasses`, the generated DLSS render func, and the EASU
render func have distinct real addresses.

## V Rising-Specific Graphics Landmarks

V Rising does customize or expose graphics/postprocess control around the HDRP
path:

- `ProjectM.GraphicsSettingsManager` includes `GetDynResForQualityMode`,
  `TurnOffFSR`, `TurnOnFSR`, and `SetFSRQuality`.
- `ProjectM.FSRQualityMode` maps `Off=0`, `UltraQuality=1`, `Quality=2`,
  `Balanced=3`, and `Performance=4`.
- HDRP exposes FSR/upscale methods such as `SetFSRParameters`,
  `GetUpscaleRes`, `SetUpscaleFilter`, `GetUseMipBias`, `GetSharpnessFSR`, and
  `GetUpscaleFilter`.
- V Rising includes custom postprocess components such as `DarkForeground`,
  `VisualLineOfSightDebug`, `CustomVignette`, `LineOfSightVision`,
  `BatFormFog`, `LineOfSight`, and `ContestAreaEffect`.

These landmarks confirm that V Rising has a real HDRP/postprocess customization
surface, but they do not turn the built-in NVIDIA DLSS renderer on.

## Interpretation

The game contains the official HDRP DLSS pass shell: pass names, pass-data
structs, resource-handle structs, helper methods, and generated RenderGraph
render-func symbols. It does not appear to contain the compiled NVIDIA module
body behind `DLSSPass.Render`, `BeginFrame`, or `SetupDRSScaling`.

That means the project should not assume a hidden official Unity DLSS renderer
can be enabled in place. The official HDRP path is still the best semantic map
for clean-room behavior: resource declarations, output placement, feature
flags, jitter, motion-vector scale, pre-exposure, reset/history, resize, and
feature reuse. The mod still needs to provide NGX execution itself, and any
closer boundary near the official pass must replace or augment the missing body
rather than merely call it.

## Immediate Design Consequence

- Current EASU `ctx.cmd` user-rendering remains the only proven normal-user
  visible-output boundary.
- The official `DoDLSSPass -> Deep Learning Super Sampling -> DLSSPass.Render`
  boundary is source-correct but not directly callable as a working DLSS
  implementation in this game.
- Future experiments can investigate an independent or injected
  DLSSData/RenderGraph-pass-equivalent boundary, but the first test should be a
  no-DLSS/no-native pass-creation proof because patching `DLSSPass.Render`
  directly has already been rejected by crash evidence.
