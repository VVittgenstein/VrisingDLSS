# DLSS Theoretical Performance Model - 2026-06-06

Status: research model, not runtime proof.

This note answers a narrow question: what performance shape should a correct DLSS
Super Resolution integration have, and what does the current V Rising evidence say
when compared against that theory?

## Source Anchors

- NVIDIA describes DLSS Super Resolution as producing a higher-resolution output
  from a lower-resolution input, using motion data and prior-frame feedback:
  <https://developer.nvidia.com/rtx/dlss>
- NVIDIA's DLSS 2.0 technical blog states that the quality modes control internal
  rendering resolution, and that Performance mode can enable up to 4x super
  resolution in a 1080p-to-4K example:
  <https://developer.nvidia.com/blog/dlss-2-0-ai-rendering>
- NVIDIA's UE4 DLSS plugin guidance lists default input-resolution percentages:
  Ultra Performance 33%, Performance 50%, Balanced 58%, Quality 66%:
  <https://developer.nvidia.com/blog/tips-getting-the-most-out-of-the-dlss-unreal-engine-4-plugin/>
- NVIDIA's older DLSS FAQ is still useful for the bottleneck model: DLSS benefits
  are largest at high GPU load and higher resolutions, and low-resolution/high-FPS
  cases may not improve when fixed DLSS execution time is larger than the saved
  render time:
  <https://www.nvidia.com/en-gb/geforce/news/nvidia-dlss-your-questions-answered/>
- Unity HDRP Dynamic Resolution lowers the resolution of the render targets used
  by main rendering passes, then upscales to the back buffer:
  <https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@16.0/manual/Dynamic-Resolution.html>
- Unity HDRP DLSS is exposed through Dynamic Resolution, camera Allow Dynamic
  Resolution/Allow DLSS, quality mode, and optional DLSS-driven optimal settings:
  <https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4012.0/manual/deep-learning-super-sampling-in-hdrp.html>
- Streamline's DLSS guide says to query optimal settings, render at the returned
  render size, tag required current-frame resources, and evaluate at the upscaling
  point in the rendering pipeline:
  <https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md>

## Pixel-Work Model

The table below is a diagnostic model based on NVIDIA's published default DLSS
input percentages and the common square-law relationship between axis scale and
pixel count. It is useful for expectation-setting, but production code should ask
the runtime for optimal settings rather than hard-code these values.

| Mode | Approx input scale per axis | Approx input pixels | Scalable pixel-work upper bound |
| --- | ---: | ---: | ---: |
| DLAA/native | 100% | 100.0% | 1.00x |
| Quality | 66% | 43.6% | 2.30x |
| Balanced | 58% | 33.6% | 2.97x |
| Performance | 50% | 25.0% | 4.00x |
| Ultra Performance | 33% | 10.9% | 9.18x |

For the current constructive 1080p Performance-mode fixture:

- Output: `1920x1080` = `2.074 MP`.
- Expected Performance input at 50% per axis: `960x540` = `0.518 MP`.
- Pixel fraction: `0.518 / 2.074 = 25%`.
- Pixel-work-only upper bound: `4x`.

That `4x` is not an FPS promise. It is only the upper bound for the portion of the
frame that truly scales with input pixel count.

## Frame-Time Model

Use this model for reasoning about results:

```text
T_dlss = T_fixed + T_scalable * pixelFraction + T_dlssOverhead + T_sync
speedup = T_native / T_dlss
```

Where:

- `T_fixed` is CPU, gameplay simulation, culling, submission, UI, present, driver
  overhead, and other work that does not shrink with render resolution.
- `T_scalable` is mostly GPU work that scales with render-target pixel count.
- `pixelFraction` is about `0.25` for Performance, `0.336` for Balanced, `0.436`
  for Quality, and `0.109` for Ultra Performance under the default-percentage model.
- `T_dlssOverhead` is the DLSS evaluate cost and related resource preparation.
- `T_sync` is any avoidable stall from bad placement, copies, state transitions,
  cross-thread waits, hot hooks, or per-frame resource discovery.

Consequences:

- If almost all frame time is scalable GPU work and overhead is small, Performance
  mode can approach the 4x pixel-work upper bound.
- If only half the frame is scalable, Performance mode is capped near:
  `1 / (0.5 + 0.5 * 0.25) = 1.60x` before DLSS overhead.
- If the test is CPU-bound, frame-capped, vsynced, or already very high-FPS, DLSS
  may not raise FPS much. The expected sign is still lower GPU utilization and power.
- If DLSS is enabled, GPU utilization is low, and FPS is much worse, the likely
  explanation is not "DLSS math is slow." It is usually a CPU/render-thread stall,
  synchronization wait, hot hook, resource copy, per-frame reflection/enumeration,
  bad evaluate placement, or a similar integration bug.

## Current Evidence Fit

The current local evidence matches the bad-integration shape, not a normal DLSS
Performance-mode result.

Positive control:

- `render-scale-only-1080p-20260606-r1` used true `1920x1080` Windowed, V Rising FSR
  Off, active `0.5` dynamic-resolution scale, and `0` DLSS evaluates.
- Average FPS stayed near baseline: `204.419 -> 205.410`.
- GPU utilization and power fell: `98.222% / 135.571 W -> 65.556% / 95.183 W`.
- This is the expected low-resolution 1080p fixture shape: not much FPS gain, but
  visibly less GPU work.

Negative path:

- `v6-user-rendering-1080p-auto-visual-20260606-r2` evaluated DLSS repeatedly but
  regressed average FPS from `203.617` to `80.242`.
- `v6-user-rendering-1080p-timing-20260606-r3` still regressed `205.255 -> 86.761`,
  while stable native evaluate CPU wall time was only about `0.08-0.11 ms`.
- `dlss-user-rendering-no-evaluate` reproduced the severe collapse with no native
  DLSS evaluate at all:
  - r1: `202.741 -> 96.867`, `0` evaluates.
  - r2: `200.115 -> 102.505`, `0` evaluates.
  - r3: `201.802 -> 111.842`, `0` evaluates.

Interpretation:

- The 1080p fixture cannot prove final DLSS value, but it can disprove a path that
  halves FPS without even evaluating DLSS.
- The direct NGX evaluate cost is not large enough to explain the sustained
  frame-time regression.
- Render-scale-only control is not the culprit.
- The leading suspect remains the global
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix and nearby
  steady-state resource-discovery placement. Even when generic logging and most
  repeated reflection work are suppressed, the path still sits in a hot render-thread
  location.

## Pass Expectations

For constructive 1080p tests:

- FPS may stay roughly flat because this fixture can become CPU/driver/present bound.
- GPU utilization/power should fall when Performance-mode render scale is active.
- Severe FPS regression is a fail even if screenshots look correct and NGX evaluate
  succeeds.

For the final product-value matrix:

- Use a controlled GPU-bound scene, preferably 4K/high-load.
- Keep VSync off and FPS cap unlimited.
- Compare V Rising FSR Off native baseline against mod-owned DLSS SR candidate.
- Use the same scene, camera, graphics settings, and output resolution.
- Record average FPS, 1% low, P95/P99 frame time, GPU utilization, power, VRAM, and
  candidate DLSS success logs.
- A correct Performance-mode DLSS integration should clearly improve FPS over native
  in a GPU-bound 4K scene, unless some other bottleneck dominates.

## Immediate Technical Implication

The next useful engineering move is not to repeat "DLSS enabled" performance tests
inside the same global `GetTexture` discovery placement. The next production-oriented
path should cache discovery results and move evaluate/writeback toward a targeted
HDRP render/upscale pass boundary, or patch a more specific current-frame resource
submission point where the resources are already valid and the hot path is narrow.
