# DLSS MVP Measurement Plan

This page records the measurement approach for deciding when the V Rising DLSS mod can move from diagnostic evidence to a normal-user rendering path.

## Source-Backed Constraints

NVIDIA describes DLSS Super Resolution as reconstructing a higher-resolution output from lower-resolution images, motion data, and feedback from prior frames. That makes screenshot validity necessary but not sufficient: temporal inputs, motion-vector scale, exposure, reset behavior, and stable history all matter.

Primary references:

- NVIDIA DLSS developer page: `https://developer.nvidia.com/rtx/dlss`
- NVIDIA Streamline DLSS programming guide: `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md`
- NVIDIA Streamline programming guide: `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
- NVIDIA FrameView overview: `https://www.nvidia.com/en-gb/geforce/technologies/frameview/`
- NVIDIA FrameView benchmarking article: `https://www.nvidia.com/en-us/geforce/news/nvidia-frameview-power-and-performance-benchmarking-app-download/`
- FrameView user guide PDF: `https://images.nvidia.com/content/geforce/technologies/frameview/frameview-1-7-user-guide-web-version.pdf`
- PresentMon console application README: `https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md`
- Unity HDRP DLSS documentation: `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4012.0/manual/deep-learning-super-sampling-in-hdrp.html`
- Unity HDRP Camera documentation: `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4017.0/manual/HDRP-Camera.html`
- Unity Core RP DynamicResolutionHandler API: `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4012.1/api/UnityEngine.Rendering.DynamicResolutionHandler.html`
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

The MVP visual/performance gate is intentionally stricter than the existing diagnostic package gate. Release readiness requires the normal-user `dlss-user-rendering` route; Stage 10A visual comparisons remain diagnostic evidence and cannot satisfy the MVP visual gate by themselves.

Required evidence:

1. Paired baseline and candidate captures from the same stable gameplay scene.
2. Candidate run log proving the selected DLSS route succeeded. For the normal-user MVP candidate this means `dlss-user-rendering` with `DLSS user rendering evaluate succeeded` and `sequenceSuccesses=...`; Stage 10A diagnostic comparisons still use visible write-back success with `sequenceSuccesses=30/30`.
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

Use `scripts/get-visual-validation-status.ps1` to inspect paired visual comparisons. It returns `Pass` only when the comparison artifact, candidate evidence log, baseline/candidate performance summaries, gameplay-resolution captures, and matching human review are all present. The script recognizes both Stage 10A `baseline-vs-stage10a` artifacts and normal-user `baseline-vs-user-rendering` artifacts; pass `-RequiredCandidateStage dlss-user-rendering` for the MVP release gate.

For `dlss-user-rendering` MVP checks, the status script also blocks obvious performance regressions before any human review can pass the artifact. Defaults are: average FPS may not regress more than `10%`, 1% low FPS may not regress more than `15%`, and P95 frame time may not worsen more than `15%`. These are guardrails for MVP evidence, not the final performance target.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\get-visual-validation-status.ps1 -RequiredCandidateStage dlss-user-rendering
```

The same status output reports baseline/candidate `AverageFps`, `OnePercentLowFps`, `P95FrameMs`, and simple deltas when both performance summaries exist. These values are evidence, not an automatic pass threshold; a surprising or negative delta should be repeated and inspected before deciding whether the DLSS route is useful.

## Performance Capture Rules

Use the same graphics settings, camera, scene, window mode, and resolution for baseline and candidate. Prefer a GPU-bound scene; if GPU utilization is low, the result may not demonstrate DLSS benefit even if the rendering path works.

On Windows desktop scaling, capture helpers must report physical pixels rather than DPI-virtualized logical pixels. For example, a 3840x2160 display at 150% scaling can appear as 2560x1440 to a DPI-unaware PowerShell process. `scripts/capture-vrising-window.ps1` declares DPI awareness before enumerating and copying the V Rising client window so visual evidence can be checked against the actual output resolution.

Do not confuse the mod's intended DLSS defaults with V Rising's built-in FSR setting. The MVP DLSS target remains `QualityMode=Performance` and `PresetMode=Recommended`. Local interop inspection shows V Rising's `FsrQualityMode` values are `Off=0`, `UltraQuality=1`, `Quality=2`, `Balanced=3`, and `Performance=4`. Current Stage 10A diagnostics need an upscale situation where the render input is smaller than the output; using `FsrQualityMode=Performance` is transition evidence only because it forces HDRP to expose a Super Resolution tuple.

The render-scale parameter for the default MVP test is source-backed: NVIDIA's UE DLSS technical blog lists Performance as 50% input resolution per axis, and NVIDIA's DLSS SDK blog maps DLSS Auto at 4K to Performance. For a 3840x2160 output target, the expected Performance render input is therefore `1920x1080`. The cleaner long-term integration should query DLSS optimal settings from the runtime and use its returned render size; the fixed percentages are only a diagnostic fallback.

The final product-value comparison must use V Rising `FsrQualityMode=Off` for both sides: native 4K with `DLSS.EnableDLSS=false` versus mod-owned `DLSS.EnableDLSS=true` with the plugin controlling render scale/upscale. Existing negative-control evidence showed that with FSR Off and no effective mod-owned render-scale control, the candidate saw `CameraColor` and output both at `3840x2160`. The v6 constructive proof fixed that for a `1920x1080` Windowed target by producing `960x540 -> 1920x1080`; the final matrix still needs the same idea validated in a controlled visual/performance comparison.

The first controlled v6 `dlss-user-rendering` gameplay comparison at `1920x1080`
Windowed proved the candidate is captureable and can evaluate repeatedly, but it
failed the performance gate. Run `v6-user-rendering-1080p-auto-visual-20260606-r2`
recorded baseline `AverageFps=203.617`, candidate `AverageFps=80.242`, baseline
`OnePercentLowFps=156.078`, candidate `OnePercentLowFps=58.688`, baseline
`P95FrameMs=5.947`, candidate `P95FrameMs=14.775`, and candidate GPU utilization
dropped to `43.444%` from `97.5%`. Treat this as evidence that DLSS evaluate success
does not yet mean DLSS performance success. The next technical question is where the
render-thread/native evaluate time is spent and whether the current `RenderGraph
GetTexture` postfix placement is forcing a stall.

Use `scripts/set-vrising-fsr-mode.ps1` for local test setup when changing V Rising's built-in FSR mode. It backs up `ClientSettings.json` under ignored local artifacts before writing and does not launch the game. The visual comparison helper can do this automatically with `-FsrMode Off` for the final MVP comparison, or `-FsrMode Performance` for explicitly labeled transition diagnostics; it restores the previous value during cleanup.

When `KeepDlssVisibleWritebackProbeRunning=true` is used, candidate performance captures measure diagnostic hold-mode overhead. A large negative FPS delta under that mode means the proof loop is too expensive, not that the normal-user DLSS path is necessarily slow. Use `-CandidateStage dlss-user-rendering` for the MVP performance question: one persistent feature, at most one evaluate per Unity frame, no repeated proof loop, and explicit cleanup on resize/settings changes.

Recommended MVP command shape, after the candidate owns render-scale/upscale while V Rising FSR remains Off:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-visual-comparison.ps1 -GamePath "C:\path\to\VRising" -CandidateStage dlss-user-rendering -FsrMode Off -ManualCapture -ReadyFile "Z:\VrisingDLSS\artifacts\visual-validation\ready.txt" -ReadyTimeoutSeconds 900 -CaptureAtSeconds 150 -CapturePerformance:$true -WaitForUserRendering:$true -DlssRuntimePath "C:\path\to\nvngx_dlss.dll" -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

If a test still requires `-FsrMode Performance`, label it as transition evidence. It can prove DLSS evaluate behavior on an HDRP Super Resolution tuple, but it cannot prove that the mod delivers normal-user value over native 4K with the game's FSR setting disabled.

Before creating the ready file for a tester-coordinated capture, confirm Codex can see the game process and likely game window:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-visibility.ps1 -GamePath "C:\path\to\VRising" -Json
```

Proceed only when the preflight returns `Status=VisibleGameWindow`. `Missing` means no `VRising` process is visible to the capture machine, and `ProcessOnly` means the process exists but its main window does not look like the game window.

Recommended capture shape:

- Warm up in the scene before starting the capture.
- Capture at least 30 seconds per run.
- Record average FPS, 1% low FPS, 5% low FPS, average frame time, P95/P99 frame time, CPU percent, GPU utilization, VRAM, power, and temperature.
- Repeat any surprising result rather than relying on one run.
- Treat identical screenshots plus unchanged performance as suspicious; it may mean the candidate write-back is not visible in the final image.

This plan answers "what to measure." It does not replace an actual V Rising in-game A/B pass.
