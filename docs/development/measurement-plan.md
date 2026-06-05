# DLSS MVP Measurement Plan

This page records the measurement approach for deciding when the V Rising DLSS mod can move from diagnostic evidence to a normal-user rendering path.

## Source-Backed Constraints

NVIDIA describes DLSS Super Resolution as reconstructing a higher-resolution output from lower-resolution images, motion data, and feedback from prior frames. That makes screenshot validity necessary but not sufficient: temporal inputs, motion-vector scale, exposure, reset behavior, and stable history all matter.

Primary references:

- NVIDIA DLSS developer page: `https://developer.nvidia.com/rtx/dlss`
- NVIDIA Streamline DLSS programming guide: `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md`
- NVIDIA FrameView overview: `https://www.nvidia.com/en-gb/geforce/technologies/frameview/`
- NVIDIA FrameView benchmarking article: `https://www.nvidia.com/en-us/geforce/news/nvidia-frameview-power-and-performance-benchmarking-app-download/`
- FrameView user guide PDF: `https://images.nvidia.com/content/geforce/technologies/frameview/frameview-1-7-user-guide-web-version.pdf`
- PresentMon console application README: `https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md`
- Unity resolution scaling overview: `https://docs.unity.cn/6000.0/Documentation/Manual/resolution-scale-introduction.html`
- Unity HDRP motion vectors manual: `https://docs.unity3d.com/cn/Packages/com.unity.render-pipelines.high-definition%4010.4/manual/Motion-Vectors.html`

Useful implications for this project:

- DLSS SR needs render-resolution color input, output-resolution color output, depth, and motion vectors.
- If exposure is not provided, auto-exposure must be intentional.
- Camera matrices used by DLSS/Streamline-style integrations should not include jitter offsets.
- Motion-vector scale must match the buffer convention.
- HDRP motion vectors can be camera-only or object+camera depending on frame settings and renderer settings; transparent motion vectors are a special case.
- Unity resolution scaling renders at a lower resolution and then upscales. In Unity's current documentation, HDRP DLSS is an upscaler that uses multiple input textures, while FSR 1 uses only the frame buffer.
- Performance should be measured with frame-time data, not only an on-screen FPS counter. PresentMon/FrameView-style metrics such as average FPS, low-percentile FPS, frame-time percentiles, GPU utilization, power, and CPU utilization are appropriate.

## Evidence Gates

The MVP visual/performance gate is intentionally stricter than the existing diagnostic package gate.

Required evidence:

1. Paired baseline and candidate captures from the same stable gameplay scene.
2. Candidate run log proving Stage 10A visible write-back success with `sequenceSuccesses=30/30`.
3. Baseline and candidate performance summaries from `scripts/capture-vrising-fps.ps1`.
4. Valid screenshots at gameplay resolution. The readiness gate currently requires at least 1280x720.
5. Human review tied to the exact image hashes, because automated pixel-difference statistics can catch gross capture failures but cannot prove temporal image quality.

Generate a review template from the current comparison artifact:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-visual-review.ps1
```

Passing review must be explicit after inspecting the images:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-visual-review.ps1 -ReviewStatus Pass -ConfirmImageCorrectness -Scene "stable gameplay scene" -Notes "No black/white frame, wrong-window capture, severe blur, ghosting, unstable UI, or obvious temporal artifacts observed." -Force
```

Review file shape:

```json
{
  "reviewStatus": "Pass",
  "reviewer": "local",
  "reviewedAt": "2026-06-05T00:00:00Z",
  "scene": "stable gameplay scene, camera and settings described here",
  "baselineSha256": "<BaselineSha256 from comparison artifact>",
  "candidateSha256": "<CandidateSha256 from comparison artifact>",
  "notes": "No black/white frame, wrong-window capture, severe blur, ghosting, unstable UI, or obvious temporal artifacts observed."
}
```

Use `scripts/get-visual-validation-status.ps1` to inspect the latest paired visual comparison. It returns `Pass` only when the comparison artifact, Stage 10A log, baseline/candidate performance summaries, gameplay-resolution captures, and matching human review are all present.

The same status output reports baseline/candidate `AverageFps`, `OnePercentLowFps`, `P95FrameMs`, and simple deltas when both performance summaries exist. These values are evidence, not an automatic pass threshold; a surprising or negative delta should be repeated and inspected before deciding whether the DLSS route is useful.

## Performance Capture Rules

Use the same graphics settings, camera, scene, window mode, and resolution for baseline and candidate. Prefer a GPU-bound scene; if GPU utilization is low, the result may not demonstrate DLSS benefit even if the rendering path works.

On Windows desktop scaling, capture helpers must report physical pixels rather than DPI-virtualized logical pixels. For example, a 3840x2160 display at 150% scaling can appear as 2560x1440 to a DPI-unaware PowerShell process. `scripts/capture-vrising-window.ps1` declares DPI awareness before enumerating and copying the V Rising client window so visual evidence can be checked against the actual output resolution.

Do not confuse the mod's intended DLSS defaults with V Rising's built-in FSR setting. The MVP DLSS target remains `QualityMode=Performance` and `PresetMode=Recommended`. Local interop inspection shows V Rising's `FsrQualityMode` values are `Off=0`, `UltraQuality=1`, `Quality=2`, `Balanced=3`, and `Performance=4`. Current Stage 10A diagnostics need an upscale situation where the render input is smaller than the output; native 3840x2160 rendering with `FsrQualityMode=0` is a useful negative control but cannot prove a DLSS performance uplift.

Recommended capture shape:

- Warm up in the scene before starting the capture.
- Capture at least 30 seconds per run.
- Record average FPS, 1% low FPS, 5% low FPS, average frame time, P95/P99 frame time, CPU percent, GPU utilization, VRAM, power, and temperature.
- Repeat any surprising result rather than relying on one run.
- Treat identical screenshots plus unchanged performance as suspicious; it may mean the candidate write-back is not visible in the final image.

This plan answers "what to measure." It does not replace an actual V Rising in-game A/B pass.
