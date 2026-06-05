# DLSS Render-Scale Route Research - 2026-06-05

This note records the current answer to a confusing testing question: DLSS Super Resolution does not depend on V Rising's built-in FSR setting. The mod needs to provide or activate a lower render-resolution path and a higher output-resolution target, then run DLSS with valid temporal inputs.

## Primary References

- Unity HDRP DLSS documentation: `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4012.0/manual/deep-learning-super-sampling-in-hdrp.html`
- Unity HDRP Camera documentation: `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4017.0/manual/HDRP-Camera.html`
- Unity Core RP `DynamicResolutionHandler` API: `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4012.1/api/UnityEngine.Rendering.DynamicResolutionHandler.html`
- Unity Graphics HDRP Asset documentation/source mirror: `https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.render-pipelines.high-definition/Documentation~/HDRP-Asset.md`
- NVIDIA DLSS developer page: `https://developer.nvidia.com/rtx/dlss`
- NVIDIA Streamline programming guide: `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`

## What The Search Says

Unity's HDRP DLSS path is built on dynamic resolution. The official HDRP DLSS page says DLSS requires the NVIDIA package, HDRP Asset dynamic resolution, camera dynamic resolution, camera DLSS permission, and a DLSS quality mode. It also says the default "Use Optimal Settings" behavior lets DLSS set the dynamic resolution scale automatically.

Unity's camera documentation exposes two relevant camera gates: `Allow Dynamic Resolution` and `Allow DLSS`. Its HDRP Asset documentation lists DLSS under `Advanced Upscalers By Priority`, separate from FSR1, FSR2, STP, TAA Upscale, and other fallback upscalers.

NVIDIA's public DLSS page describes DLSS Super Resolution as producing higher-resolution frames from lower-resolution input, using motion data and feedback from previous frames. The Streamline guide makes the render-scale contract explicit: when using DLSS, the application asks for optimal settings from the selected DLSS mode and output size, then renders the viewport at the returned render width and height.

## Local V Rising Interop Findings

The local V Rising install exposes HDRP/Core interop methods that match the official route:

- `UnityEngine.Rendering.DynamicResolutionHandler.SetDynamicResScaler(...)`
- `UnityEngine.Rendering.DynamicResolutionHandler.SetUpscaleFilter(Camera, DynamicResUpscaleFilter)`
- `UnityEngine.Rendering.DynamicResolutionHandler.GetCurrentScale()`
- `UnityEngine.Rendering.DynamicResolutionHandler.finalViewport`
- `UnityEngine.Rendering.HighDefinition.HDRenderPipeline.SetUpscaleFilter(DynamicResUpscaleFilter, float)`
- `UnityEngine.Rendering.HighDefinition.HDRenderPipeline.GetUpscaleRes()`
- `UnityEngine.Rendering.HighDefinition.HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler(...)`
- `UnityEngine.Rendering.HighDefinition.HDRenderPipeline.DoDLSSPasses(...)`
- `UnityEngine.Rendering.HighDefinition.HDRenderPipeline.DoDLSSPass(...)`
- `UnityEngine.Rendering.HighDefinition.DLSSPass` resources for `source`, `output`, `depth`, `motionVectors`, and `biasColorMask`

The local game folder does not appear to include `nvngx_dlss.dll` or a Unity NVIDIA module DLL by default. That means "just flip Unity's built-in DLSS setting" is not assumed to work until runtime probes prove it. The clean-room native bridge remains necessary for the distributable fallback path.

## Decision

`FsrQualityMode=Performance` is transition evidence only. It was useful because it forced V Rising/HDRP to expose an input-smaller-than-output tuple such as `1920x1080 -> 3840x2160`, letting the current probes prove texture discovery and NGX evaluate behavior.

It is not the MVP route. The MVP product-value comparison is:

1. Baseline: V Rising FSR Off, native 4K output, `DLSS.EnableDLSS=false`.
2. Candidate: V Rising FSR Off, same output resolution and scene, `DLSS.EnableDLSS=true`, with the mod controlling render scale/upscale.

The implementation route should therefore target a guarded dynamic-resolution/DLSS integration:

1. Done: the read-only upscaler-state probe now observes `DynamicResolutionHandler` state, camera upscale filters, `HDCamera.RequestDynamicResolution`, `HDCamera.IsDLSSEnabled`, `HDCamera.UpsampleSyncPoint`, and `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler`.
2. Done: `Diagnostics.EnableRenderScaleControlProbe=true` now requests a DLSS-Performance-equivalent HDRP dynamic-resolution percentage while leaving V Rising `FsrQualityMode=Off`. It forces HDRP dynamic resolution and uses `TAAU` as the non-FSR upscaler landmark; it does not force Unity's internal DLSS pass.
3. Next: runtime-validate that the probe produces a render-input-smaller-than-output tuple under `FsrQualityMode=Off`.
4. Reuse the existing native bridge only after the frame has the correct low-resolution color, output-resolution target, depth, and motion-vector resources.
5. Validate one DLSS evaluate per Unity frame, resize/reset cleanup, image quality, and FPS improvement against native 4K FSR Off.

The similar names are easy to mix up:

- `DLSS.QualityMode=Performance` is the mod's intended DLSS Super Resolution quality mode.
- V Rising `FsrQualityMode=Performance` is the game's built-in FSR setting and should be Off for the final MVP comparison.
