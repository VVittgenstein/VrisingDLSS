# Source-Guided Boundary Check - 2026-06-08

Status: local read-only source/metadata confirmation. No game launch, no native
runtime test, and no game files or decompiled method bodies are included here.

## Question

Would having full or partial important game/source context reduce the repeated
trial loop for the V Rising DLSS route?

## Short Answer

Yes. For this problem, the useful "source" is already mostly available as a
three-part map:

- Unity HDRP 2022.3 source explains the official RenderGraph/DLSS method
  bodies and expected pass order.
- V Rising IL2CPP metadata and BepInEx interop prove which HDRP symbols,
  tokens, wrappers, fields, and generated render funcs exist in the actual
  game build.
- Prior protected gameplay logs prove which source-aligned boundary is safe and
  performant enough to keep testing.

This is enough to avoid broad blind probing. It does not mean public mod
artifacts may include V Rising binaries, metadata, or generated decompilation
output.

## Fresh Local Checks

Read-only probe:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\probe-vrising-render-metadata.ps1 -GamePath "C:\Software\VRising" -Json
```

Confirmed positives:

- `HDRenderPipeline`
- `HDCamera`
- `DynamicResolutionHandler`
- `Deep Learning Super Sampling`
- `DLSS Color Mask`
- `DLSS destination`
- `HDRenderPipeline.GetPostprocessUpsampledOutputHandle`
- `HDRenderPipeline.DoDLSSPasses`
- `HDRenderPipeline.DoDLSSPass`
- `DLSSPass.ViewResourceHandles` with `source`, `output`, `depth`,
  `motionVectors`, and `biasColorMask`
- `DLSSPass.GetViewResources`, `CreateCameraResources`, `GetCameraResources`,
  and `Render(Parameters, CameraResources, CommandBuffer)`

Confirmed negatives:

- The local game scan still does not expose the complete Unity NVIDIA runtime
  stack: `DLSSContext`, `DLSSCommandInitializationData`, `DLSSTextureTable`,
  `DLSSQuality`, `NVUnityPlugin`, `NGX`, and `nvsdk_ngx` were absent.
- No DLSS/NGX runtime candidate DLLs were found in the game runtime scan.

Preflight probe:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\get-native-renderfunc-entry-preflight.ps1 -Root "Z:\VrisingDLSS" -DeepInspect -Json
```

Result: `PreflightPass_DesignOnly`.

The latest render-func metadata gameplay log still has stable entries for:

- `Uber Post`: `<UberPass>b__1060_0`, token `100664386`
- `Edge Adaptive Spatial Upsampling`: `<EdgeAdaptiveSpatialUpsampling>b__1066_0`,
  token `100664389`
- `Final Pass`: `<FinalPass>b__1069_0`, token `100664390`

The deep preflight also confirmed the local detour support shape used by the
current source-guided native route: `NativeDetour(IntPtr from, IntPtr to)`,
method pointer access, and Il2CppInterop Harmony detouring via method pointers.

## Source Alignment

The official HDRP DLSS path remains:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render(..., ctx.cmd)`.

The current working V Rising candidate does not use the absent built-in NVIDIA
runtime stack. Instead, it uses the source-aligned HDRP EASU render-func
boundary:

`Edge Adaptive Spatial Upsampling -> RenderGraphContext.cmd -> native plugin event -> SDK-wrapper DLSS evaluate`.

The protected r3 gameplay proof shows this is no longer just a theory:

- `DLSS.EnableDLSS=true`
- `eventId=260615`
- `input=960x540`
- `output=1920x1080`
- `setSuccesses=124`
- `issueSuccesses=124`
- `consumed=124`
- `sequenceCreates=1`
- `sequenceEvaluates=124`
- `evaluateSuccesses=124`
- `visibleOutput=yes`
- `RenderGraph.GetTexture call #=0`
- no crash/access-violation/NVIDIA driver fault

See `docs/development/native-commandbuffer-user-rendering-1080p-gameplay-result-2026-06-07.md`.

## Decision

Full proprietary game source would be convenient, but it is not required for
the current DLSS boundary. The combination of Unity HDRP source, V Rising
metadata/interops, and protected runtime proofs is sufficient to keep the work
source-guided.

The next high-value work should not be another broad decompilation sweep. It
should be a normal-user visual/performance validation of the already-proven
source-guided command-buffer route, followed by resize/reset, fallback, and
runtime distribution gates.

If performance is still wrong, then the next source pass should be narrow:
compare the working EASU `ctx.cmd` candidate against the official `DoDLSSPass`
resource lifecycle for differences in history/reset/jitter/pre-exposure and
state around command-buffer submission.
