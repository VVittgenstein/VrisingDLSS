# V Rising IL2CPP HDRP Decompilation Kickoff - 2026-06-07

Status: local source/decompilation-guided investigation started.

## Why Now

The protected gameplay proof
`native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1`
proved that, under V Rising `FsrQualityMode=Off` plus mod-owned render scale,
the focused HDRP EASU pass exposes both:

- a low-resolution source native texture pointer:
  `Uber Post Destination` / `Apply Exposure Destination_960x540...`
- a full-resolution output native texture pointer:
  `Edge Adaptive Spatial Upsampling_1920x1080...`

That makes blind RenderGraph probing less useful. The better route is now to
align V Rising's actual IL2CPP metadata with Unity HDRP source around the
official upscale/evaluate boundaries.

## Local Inputs

- Game assembly:
  `C:\Software\VRising\GameAssembly.dll`
- Metadata:
  `C:\Software\VRising\VRising_Data\il2cpp_data\Metadata\global-metadata.dat`
- BepInEx interop:
  `C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.HighDefinition.Runtime.dll`
- Local decompiler:
  `C:\Software\dotnet-tools\.store\ilspycmd\8.2.0.7535\...\ilspycmd.dll`
- Existing upstream source:
  `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/`

Generated ILSpy interop outputs are local reference material under:

`ref/decompilation-vrising-2026-06-07/ilspy-types/`

Do not package or redistribute generated game/interop decompilation output.
Commit only small derived notes needed for implementation decisions.

## V Rising IL2CPP Symbols

`Unity.RenderPipelines.HighDefinition.Runtime.dll` interop confirms the
relevant HDRP symbols exist in V Rising's IL2CPP metadata.

`HDRenderPipeline` methods:

- `RenderPostProcess(...)`: token `100663789`
- `DoDLSSPasses(...)`: token `100663792`
- `DoDLSSPass(...)`: token `100663793`
- `EdgeAdaptiveSpatialUpsampling(...)`: token `100663869`
- `FinalPass(...)`: token `100663870`

Generated render funcs:

- `_DoDLSSPass_b__969_0(DLSSData data, RenderGraphContext ctx)`:
  token `100664365`
- `_EdgeAdaptiveSpatialUpsampling_b__1066_0(EASUData data, RenderGraphContext ctx)`:
  token `100664389`
- `_FinalPass_b__1069_0(FinalPassData data, RenderGraphContext ctx)`:
  token `100664390`

`DLSSPass` methods:

- `GetViewResources(ref ViewResourceHandles)`: token `100667453`
- `CreateCameraResources(HDCamera, RenderGraph, RenderGraphBuilder, ref ViewResourceHandles)`:
  token `100667454`
- `GetCameraResources(ref CameraResourcesHandles)`: token `100667455`
- `SetupFeature(HDRenderPipelineGlobalSettings)`: token `100667456`
- `Create(HDRenderPipelineGlobalSettings)`: token `100667457`
- `BeginFrame(HDCamera)`: token `100667458`
- `SetupDRSScaling(bool, Camera, XRPass, ref GlobalDynamicResolutionSettings)`:
  token `100667459`
- `Render(Parameters, CameraResources, CommandBuffer)`: token `100667460`

## Source Alignment

Upstream HDRP 2022.3 source maps cleanly to the symbols above:

- `RenderPostProcess(...)` calls `DoDLSSPasses(...)` at the configured
  DLSS injection points.
- If dynamic-resolution upsampling is scheduled `AfterPost` and the camera is
  not using HDRP DLSS, HDRP calls CAS and then
  `EdgeAdaptiveSpatialUpsampling(...)`.
- `EdgeAdaptiveSpatialUpsampling(...)` declares `EASUData` with:
  `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`, `source`, and
  `destination`.
- It reads `source`, writes `GetPostprocessUpsampledOutputHandle(...,
  "Edge Adaptive Spatial Upsampling")`, then dispatches EASU compute from the
  render func.
- `DoDLSSPass(...)` declares a `Deep Learning Super Sampling` RenderGraph pass,
  reads source/depth/motion vectors, writes
  `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`, stores
  `DLSSPass.CreateCameraResources(...)`, then its render func calls
  `DLSSPass.GetCameraResources(data.resourceHandles)` immediately before
  `data.pass.Render(data.parameters, ..., ctx.cmd)`.

This explains the runtime native-pointer proof: the EASU `source` and
`destination` handles we observed are exactly the handles authored by
`EdgeAdaptiveSpatialUpsampling(...)`.

Additional local alignment on 2026-06-07 confirmed the game build embeds Unity
`2022.3.58f1` in `VRising_Data/globalgamemanagers`. That makes the local
`ref/UnityGraphics-2022.3` HDRP source a strong method-body reference for the
render path, while the V Rising IL2CPP interop/xref output supplies the actual
runtime symbols, tokens, fields, wrapper signatures, and caller/xref ranges.
For the DLSS route this is enough "important source" to reduce blind runtime
trial: official HDRP records `source`, `output`, `depth`, `motionVectors`, and
optional `biasColorMask` in `DoDLSSPass(...)`, then converts them through
`DLSSPass.GetCameraResources(...)` inside the pass render func immediately
before submitting on `ctx.cmd`. The local metadata still lacks Unity's complete
NVIDIA module stack, so the built-in DLSS pass remains a design map rather than
an already-active runtime path.

## Practical Implications

- A complete proprietary game source tree is not required for the next step;
  V Rising's IL2CPP metadata plus Unity HDRP source already gives the specific
  pass data, generated render func names, and official control flow.
- The current best boundary is not broad
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` discovery. The
  focused EASU render func is now proven enough to drive narrow tests.
- The practical "source" answer is three-part: IL2CPP metadata/interop proves
  what V Rising actually contains, BepInEx xref/cache proves call adjacency and
  wrapper accessibility, and Unity HDRP 2022.3 source supplies the relevant
  method bodies. Full proprietary source is not required for the HDRP
  upscaler boundary, but full generated/decompiled game output must remain
  local and must not be redistributed.
- Direct Harmony prefixing of `DLSSPass.Render(...)` remains rejected by prior
  crash evidence, despite the method being present and named.
- The ordinary `DLSSPass.GetCameraResources(...)` wrapper still has poor
  accessibility as a patch target in this runtime, but its source role is
  important: resource conversion happens inside the official render func, right
  before command-buffer submission.
- The next guard should not combine DLSS evaluate. It should first use the
  source-aligned EASU boundary to validate whether the raw
  `RenderGraphContext` argument at `_EdgeAdaptiveSpatialUpsampling_b__1066_0`
  can safely expose or be correlated with `ctx.cmd`/command-buffer submission
  timing.
- The focused source/destination D3D11 device/dimension guard has now passed in
  protected gameplay; see
  `docs/development/native-renderfunc-resource-d3d11-render-scale-gameplay-result-2026-06-07.md`.
  The proven pair is `sameDevice=yes`, `source=960x540`,
  `destination=1920x1080`, and `scale=(2.000x,2.000x)`.

## Next Questions

1. Can the existing native render-func detour for
   `_EdgeAdaptiveSpatialUpsampling_b__1066_0` safely correlate its raw
   `RenderGraphContext` pointer with a managed `RenderGraphContext`/`CommandBuffer`
   wrapper without dereferencing unsafe memory blindly?
2. If not, can a separate source-guided managed hook observe only EASU pass
   data and `ctx.cmd` at this exact generated render func without reproducing
   the earlier broad generated-render-func crash?
3. What is the smallest reversible command-buffer preflight that proves timing
   and handle validity without calling NGX or DLSS evaluate?

Conservative answer for now: the D3D11/device/dimension guard is complete.
The next separate guard should test command-buffer boundary access/correlation
near the generated EASU or official DLSS render func, still without NGX
initialization or DLSS evaluate.
