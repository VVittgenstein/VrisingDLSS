# DLSS Performance Investigation - 2026-06-06

Status: initial investigation after the first controlled `dlss-user-rendering`
visual/performance comparison.

## Question

Why does the v6 `dlss-user-rendering` path report repeated successful DLSS Super
Resolution evaluates while performing far worse than the baseline, even in
Performance mode with a `960x540 -> 1920x1080` tuple?

## Local Evidence

Run label: `v6-user-rendering-1080p-auto-visual-20260606-r2`.

The good evidence:

- V Rising FSR mode: `Off`.
- Window shape: true `1920x1080` Windowed.
- Candidate tuple: `CameraColor`, `CameraDepthStencil`, and `Motion Vectors` at
  `960x540`; output `Edge Adaptive Spatial Upsampling` at `1920x1080`.
- Candidate log reached `sequenceCreates=1`, `sequenceEvaluates=11700`, and
  `evaluateSuccesses=11700`.
- Baseline and candidate screenshots were valid gameplay captures, not black frames
  or wrong-window captures.

The bad evidence:

- Baseline average FPS: `203.617`.
- Candidate average FPS: `80.242` (`-60.592%`).
- Baseline 1% low FPS: `156.078`.
- Candidate 1% low FPS: `58.688` (`-62.398%`).
- Baseline P95 frame time: `5.947 ms`.
- Candidate P95 frame time: `14.775 ms` (`+148.445%`).
- Baseline average GPU utilization/power: `97.5%`, `131.254 W`.
- Candidate average GPU utilization/power: `43.444%`, `81.371 W`.

This is not the older repeated-evaluate-per-frame bug. The r2 log advances roughly
one evaluate per Unity frame and reuses one feature. The low GPU utilization and power
strongly suggest a CPU/render-thread synchronization or submission-placement problem,
not normal GPU-bound DLSS cost.

## Official Guidance Checked

Primary sources:

- NVIDIA Streamline programming guide:
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
- NVIDIA Streamline DLSS programming guide:
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md`
- NVIDIA Streamline manual hooking guide:
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideManualHooking.md`
- NVIDIA DLSS 4 Streamline integration blog:
  `https://developer.nvidia.com/blog/how-to-integrate-nvidia-dlss-4-into-your-game-with-nvidia-streamline/`
- NVIDIA NGX programming guide:
  `https://docs.nvidia.com/ngx/latest/programming-guide/`
- Unity HDRP Dynamic Resolution manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4013.0/manual/Dynamic-Resolution.html`

Useful constraints from those sources:

- DLSS SR should be added on the rendering thread at the upscaling location, with the
  same frame token and viewport used across tags, constants, options, and evaluate.
- Required DLSS SR resources are render-resolution color input, final-resolution color
  output, depth, and motion vectors.
- When dynamic resolution is used, resource extents should be provided for each tagged
  resource.
- Per-frame camera constants matter: matrices should not contain jitter offsets, and
  motion-vector scale must match the buffer convention.
- Streamline examples restore command-list/buffer state after evaluate, and the manual
  hooking guide treats present-path integration as mandatory for correct behavior.
- NVIDIA's DLSS SR checklist says SR should be integrated close to the start of
  post-processing, should validate performance benefits, and should only replace the
  primary upscale pass on the main render target.
- NGX D3D11 evaluation takes a device context plus feature handle and parameters; NGX
  error codes include missing RW/UAV access and missing inputs.
- Unity HDRP dynamic resolution lowers the main render targets, then upscales back to
  the back-buffer resolution at the end of each frame.

## Local Mismatch

Current v6 evaluates from `FrameResourceProbe.TryRunDlssUserRendering`, which is
called by the `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix when
the tuple happens to be visible.

That hook is excellent for discovery because it proved the real tuple exists. It is
not a proper render/upscale pass. It can synchronously enter NGX while RenderGraph is
resolving texture handles, before we have an explicit command-buffer/pass boundary,
state-restoration contract, or stable placement relative to HDRP's own upscale pass.

The native function also does per-frame pointer inspection:

- `TryDescribeEvaluateTexture(...)` for color/output/depth/motion.
- `TryQueryD3D11Resource(...)` for color/output/depth/motion.
- `NGX_D3D11_EVALUATE_DLSS_EXT(...)` under the frame-sequence mutex.

The per-frame COM queries are worth timing, but the stronger suspect is evaluate
placement. An expensive or blocking call inside a passive resource-discovery postfix
matches the observed signature: candidate FPS falls hard while GPU utilization falls,
instead of DLSS making the workload more GPU-efficient.

## Working Hypotheses

1. Primary hypothesis: synchronous NGX evaluate from the `GetTexture` postfix is
   stalling the render thread or forcing unfavorable GPU/CPU synchronization.
2. Secondary hypothesis: the selected output resource is the right visible target, but
   evaluate should replace HDRP's upscale operation from a command-buffer/pass point
   rather than racing that operation from resource discovery.
3. Secondary hypothesis: per-frame D3D11 resource description/query overhead is adding
   measurable CPU cost, especially if the callback runs near a hot RenderGraph path.
4. Image-quality hypotheses still remain open: jitter, exposure/pre-exposure,
   motion-vector scale, and reset handling are currently not production-quality, but
   they do not explain the large GPU-utilization drop by themselves.

## Timing Instrumentation Added

Follow-up patch after this investigation adds bounded timing fields to the existing
`dlss-user-rendering` evidence line:

- C# bridge wall time:
  `bridgeTiming=lastMs=<n>,avgMs=<n>,maxMs=<n>,samples=<n>`
- Native frame-sequence timing:
  `nativeTimingMs=(describe=<n>,query=<n>,prepare=<n>,evaluate=<n>,total=<n>)`

The native split means:

- `describe`: `TryDescribeEvaluateTexture(...)` across color/output/depth/motion.
- `query`: `TryQueryD3D11Resource(...)` across color/output/depth/motion.
- `prepare`: mutex wait plus session recreate/setup work before NGX evaluate.
- `evaluate`: `NGX_D3D11_EVALUATE_DLSS_EXT(...)`.
- `total`: native function time through evaluate completion, before resource release.

The logging cadence remains low-noise: first successes and every 300th success, plus
bounded failures.

## Next Diagnostic Test

Run another `1920x1080` Windowed, V Rising FSR Off, `dlss-user-rendering` candidate
test with the same save protection and cleanup protocol.

Question: where is the candidate spending frame time when FPS drops and GPU
utilization falls?

Pass signal for this diagnostic is not high FPS. It should answer where the time is
going:

- If native `NGX_D3D11_EVALUATE_DLSS_EXT` itself is taking most of the frame, move the
  evaluate call out of the discovery postfix into a real render/upscale pass.
- If pointer description/query dominates, cache stable resource metadata and only
  refresh on pointer/size changes.
- If C# wall time is small but FPS remains low, instrument GPU submission/present
  timing next.

## Timing Test Result

Run label: `v6-user-rendering-1080p-timing-20260606-r3`.

The timing fields worked and changed the diagnosis:

- Baseline average FPS: `205.255`.
- Candidate average FPS: `86.761` (`-57.730%`).
- Baseline 1% low FPS: `153.451`.
- Candidate 1% low FPS: `67.061` (`-56.298%`).
- Baseline P95 frame time: `5.896 ms`.
- Candidate P95 frame time: `13.642 ms` (`+131.377%`).
- Baseline average GPU utilization/power: `98.111%`, `137.760 W`.
- Candidate average GPU utilization/power: `40.889%`, `78.541 W`.

The first frame-sequence create was expensive:

- C# bridge first call: `604.85 ms`.
- Native prepare/create portion: `604.451 ms`.
- Native evaluate on the first call: `0.296 ms`.

Stable frames were not expensive inside the measured native call:

- At `sequenceSuccesses=12000`, C# bridge last call was `0.092 ms`.
- Native total was `0.085 ms`.
- Native evaluate was `0.083 ms`.
- Native describe/query/prepare were each about `0.001 ms` or less.

Across the 45 logged timing samples, the first create dominated the average. Stable
`NGX_D3D11_EVALUATE_DLSS_EXT(...)` CPU wall time stayed around `0.07-0.11 ms`, far
below the observed candidate frame time around `11.5 ms`.

Additional hot-path counts from the candidate log:

- `RenderGraph GetTexture call`: `18414`.
- Logged `DLSS user rendering evaluate succeeded` samples: `45` for `12000` total
  successes.
- `DLSS user rendering evaluate failed/blocked/skipped`: `0`.
- `Render-scale control software fallback diagnostic`: `32`.

Updated interpretation: the sustained regression is not explained by C# bridge wall
time, native describe/query cost, or direct NGX evaluate CPU wall time. The next
isolation should test the render-scale/HDRP path without DLSS evaluate, because the
remaining likely sources are the v6 render-scale/software-fallback path, the very hot
RenderGraph resource-discovery hook, HDRP's own upscale path, or GPU submission/present
behavior not captured by CPU-side timing.

## External Practice Check

Searched on 2026-06-06 after the repeated "DLSS succeeds but performance is wrong"
signature appeared locally.

Primary references:

- NVIDIA DLSS developer page:
  `https://developer.nvidia.com/rtx/dlss`
- NVIDIA NGX programming guide:
  `https://docs.nvidia.com/ngx/latest/programming-guide/`
- Unity HDRP DLSS manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4012.0/manual/deep-learning-super-sampling-in-hdrp.html`
- Unity HDRP Dynamic Resolution manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4013.0/manual/Dynamic-Resolution.html`
- Unity HDRP Camera manual:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4017.0/manual/HDRP-Camera.html`
- Unity DynamicResolutionSample:
  `https://github.com/Unity-Technologies/DynamicResolutionSample`

Useful implications:

- NVIDIA describes DLSS Super Resolution as outputting a higher-resolution frame from
  lower-resolution inputs, using motion data and prior-frame feedback. A correctly
  placed SR integration should normally reduce heavy rendering work before adding
  reconstruction cost.
- Unity's HDRP DLSS path is explicitly tied to Dynamic Resolution: enable dynamic
  resolution in the HDRP asset, allow it per camera, then allow DLSS per camera.
- HDRP Dynamic Resolution lowers the main render targets and upscales to the
  back-buffer resolution. Unity notes HDRP does not automatically choose the scale
  unless an integration/policy drives the handler.
- Unity's dynamic-resolution sample warns that only one scaling/timing controller
  should run; collecting timing data multiple times per frame wastes work. This is a
  useful reminder for our hot-hook route, even though our current issue is much larger
  than a normal timing-query cost.
- Community reports of "DLSS on but FPS worse / low GPU utilization" are common, but
  anecdotal. They are useful as symptom matches only. The recurring credible pattern is
  that low GPU utilization plus worse FPS points to a CPU/render-thread, frame-limiter,
  or integration-placement bottleneck rather than useful GPU-bound DLSS work.

The external references strengthen the local expectation: Performance-mode DLSS should
not cut FPS in half when the scene is GPU-bound. A successful evaluate status is only
one integration signal; performance validation must prove that the engine is actually
submitting the cheaper render workload and presenting without a synchronization trap.

## Render-Scale-Only Isolation

Run label: `render-scale-only-1080p-20260606-r1`.

This run used V Rising `FsrQualityMode=Off`, true `1920x1080` Windowed,
`CandidateStage=render-scale-control`, and no SDK-wrapper native/DLSS runtime. The
candidate did not call DLSS evaluate.

Performance:

- Baseline average FPS: `204.419`.
- Candidate average FPS: `205.410`.
- Baseline 1% low FPS: `154.841`.
- Candidate 1% low FPS: `140.222`.
- Baseline P95 frame time: `5.929 ms`.
- Candidate P95 frame time: `6.188 ms`.
- Baseline average GPU utilization/power: `98.222%`, `135.571 W`.
- Candidate average GPU utilization/power: `65.556%`, `95.183 W`.

Candidate log checks:

- `GetCurrentScale=0.5`: `31`.
- `GetResolvedScale=(0.50, 0.50)`: `31`.
- `DLSS user rendering evaluate succeeded`: `0`.
- `RenderGraph GetTexture call`: `0`.

Cleanup passed: helper cleanup restored release-safe state, no V Rising process
remained, loader config returned to `EnableDLSS=false` with empty `DlssRuntimePath`,
and the `11111` save restored with `ChangeCount=0`.

Updated interpretation: the v6 render-scale/HDRP dynamic-resolution intervention is
not the source of the severe FPS drop. Lower GPU utilization with unchanged average
FPS is the expected shape for reduced internal resolution in this low-cost 1080p
fixture. The remaining blocker is inside the `dlss-user-rendering` path: hot
RenderGraph tuple discovery, the DLSS evaluate/writeback placement, GPU
submission/present behavior, or some combination of those.

## Route Decision

Do not treat `DLSS user rendering evaluate succeeded` as a performance pass. The
current route proves the tuple and SDK wrapper can evaluate. MVP readiness still
requires a rendering placement that improves or at least does not severely regress
frame time in a controlled FSR Off comparison. Do not repeat render-scale-only as the
next primary suspect unless new evidence changes the setup; the next diagnostic should
separate the hot RenderGraph discovery hook from native DLSS evaluate/writeback, or
move evaluation into a real render/upscale pass boundary.

## No-Evaluate Isolation

Follow-up document: [../development/user-rendering-no-evaluate-performance-test-2026-06-06.md](../development/user-rendering-no-evaluate-performance-test-2026-06-06.md).

The new `dlss-user-rendering-no-evaluate` stage enables the same v6 dynamic-resolution
and RenderGraph tuple path, accepts the same DLSS input/output tuple, but deliberately
returns before creating or evaluating a native DLSS frame sequence. This was designed
to answer whether the severe performance regression needs NGX evaluate/writeback.

Results:

| Run | Baseline FPS | Candidate FPS | Baseline 1% low | Candidate 1% low | Baseline P95 | Candidate P95 | Baseline GPU | Candidate GPU | Key candidate log |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| `user-rendering-no-evaluate-1080p-20260606-r1` | `202.741` | `96.867` | `152.292` | `75.677` | `5.972 ms` | `12.076 ms` | `97.889% / 136.469 W` | `34.444% / 57.632 W` | `74` accepted, `0` evaluate, `32111` GetTexture-call logs |
| `user-rendering-no-evaluate-1080p-20260606-r2` | `200.115` | `102.505` | `153.132` | `75.922` | `6.052 ms` | `11.676 ms` | `97.889% / 134.799 W` | `36.300% / 61.256 W` | `61` accepted, `0` evaluate, `0` GetTexture-call logs |
| `user-rendering-no-evaluate-1080p-20260606-r3` | `201.802` | `111.842` | `155.421` | `78.655` | `5.974 ms` | `10.846 ms` | `97.333% / 133.537 W` | `37.700% / 66.195 W` | `53` accepted, `0` evaluate, `57` cached-tuple reuse lines |
| `user-rendering-no-evaluate-1080p-20260606-r4` | `194.424` | `119.573` | `138.013` | `73.957` | `6.453 ms` | `10.826 ms` | `97.375% / 133.344 W` | `41.250% / 71.701 W` | `88` accepted, `0` evaluate, `92` cached-tuple reuse lines, `0` GetTexture-call logs |

Interpretation:

- The severe regression reproduces without native DLSS evaluate/writeback. That rules
  out direct NGX evaluate CPU time as a required cause of the FPS collapse.
- Disabling broad `RenderGraph GetTexture call` diagnostic logging/probe helped only
  slightly, from about `96.9` to `102.5` candidate FPS.
- Caching reflection lookups and reusing the accepted tuple helped again, from about
  `102.5` to `111.8` candidate FPS, but the path still remains far below the roughly
  `200` FPS baseline.
- Resource-name-first filtering before native pointer/owner reflection helped again,
  from `111.842` to `119.573` candidate FPS. The paired baseline still remained
  `194.424` FPS, so native pointer/owner reflection was not the whole blocker.
- The remaining primary suspect is the placement of the global
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix itself. It is still
  in a very hot render-thread path even when logging and most repeated reflection work
  are suppressed.

All four runs used true `1920x1080` Windowed gameplay, the protected `11111` save was
backed up and restored, and cleanup returned the loader config to release-safe state.

## External Practice Follow-up

Additional references were downloaded into
`ref/dlss-performance-investigation-2026-06-06/` on 2026-06-06:

- Unity HDRP DLSS manual.
- Unity HDRP Dynamic Resolution manual.
- Unity Core RenderGraph fundamentals and pipeline-writing manuals.
- NVIDIA Streamline programming guide and DLSS-specific guide.
- NVIDIA NGX programming guide PDF.
- OptiScaler README and INI.
- NVIDIA Developer Forum thread for a 2026 Unity RenderGraph DLSS integration.

Useful technical convergence:

- Unity HDRP DLSS is not a free-floating texture postprocess. The documented path is
  tied to HDRP Dynamic Resolution and camera-level "Allow Dynamic Resolution" /
  "Allow DLSS" controls. DLSS can drive the dynamic-resolution scale when "Use Optimal
  Settings" is enabled.
- Unity RenderGraph resources are handle-based during setup. Actual texture resources
  are intended to be accessed in render pass execution code after explicit read/write
  declarations. Unity's own docs emphasize per-frame graph setup/execution and resource
  lifetime derived from declared pass usage.
- Unity's HDRP `DLSSPass` source creates/recreates DLSS state only when the view,
  size, quality, optimal-settings flag, or context changes. Per frame, it submits DLSS
  from the upscale pass with explicit color, depth, motion-vector, exposure, bias-color,
  and output resources plus jitter/reset metadata.
- Streamline likewise frames DLSS SR as a render-thread evaluate at the upscaling
  location, using current-frame resources. Its resource-tagging guidance is explicit
  about frame tokens, local evaluate inputs, resource lifecycle, and avoiding
  unnecessary volatile/`OnlyValidNow` behavior.
- OptiScaler's public shape is also instructive: it generally replaces or intercepts an
  existing upscaler input path rather than discovering arbitrary engine resources on
  every texture lookup. Its pattern-search options are startup/load-time oriented, not
  a per-`GetTexture` production path.
- The 2026 NVIDIA forum Unity thread is useful for debugging expectations: successful
  `NGX_D3D11_EVALUATE_DLSS_EXT` from a RenderGraph callback may not be visible in
  RenderDoc because DLSS can use a private path. Screenshot/performance evidence is
  more reliable than RenderDoc alone for our final correctness gate.

Updated route decision: keep the current `GetTexture` tuple path as a diagnostic and
short-term discovery aid only. The next production-oriented attempt should move tuple
use/evaluate to a targeted render/upscale pass boundary, or patch a more specific HDRP
resource submission point, with the accepted tuple cached by frame/view and no global
per-texture resource-discovery work in the steady state.

Implementation follow-up result: the `GetTexture` postfix now filters by RenderGraph
resource name before resolving native texture pointers whenever raw GetTexture logging
and output-followup are inactive. The r4 no-evaluate run confirmed that this is useful
but insufficient runtime evidence: paired FPS improved to `194.424 -> 119.573`, with
`0` native evaluate/dispatch successes and `0` broad `RenderGraph GetTexture call`
logs, but the candidate still ran with only `41.250%` average GPU utilization. Keep
this as a diagnostic optimization, not as the production steady-state route.

Materialization-only follow-up: `materialization-only-no-evaluate-1080p-20260606-r1`
disabled the global `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` probe
and enabled only the `BeginExecute` / `CreateTextureCallback` materialization route
plus no-evaluate tuple acceptance. The candidate patched the materialization methods
and skipped the GetTexture postfix as expected, but gameplay produced `0`
`RenderGraph texture materialization #` logs, `0` SR input candidates, and `0`
no-evaluate acceptances from materialization before the candidate was stopped. The
protected `11111` save restored with `ChangeCount=0`. This rejects
`CreateTextureCallback` as a sufficient replacement boundary for steady-state tuple
discovery.

Narrow HDRP source follow-up: see
[hdrp-dlss-execution-boundary-2026-06-06.md](hdrp-dlss-execution-boundary-2026-06-06.md).
Local Unity source and V Rising interop show the official DLSS boundary is the
`Deep Learning Super Sampling` RenderGraph pass execution window:
`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.
Because local `PreRenderPassExecute` testing rejected the ref-`CompiledPassInfo`
executor wrapper family, the next near-term isolation is the default-off
`dlss-user-rendering-cached-driver-no-evaluate` stage: use `GetTexture` only as a
temporary tuple oracle, then drive the cached no-evaluate tuple from
`DynamicResolutionHandler.Update(...)` while fast-skipping steady-state `GetTexture`
postfix work.

## Theoretical Performance Follow-up

See [dlss-theoretical-performance-model-2026-06-06.md](dlss-theoretical-performance-model-2026-06-06.md).

The source-backed model makes the current failure sharper rather than softer:

- Performance-mode DLSS commonly uses about 50% input resolution per axis, so the
  1080p constructive fixture should be about `960x540 -> 1920x1080`, or 25% of
  native pixel count.
- That does not promise a 4x FPS gain, because CPU, present, driver, UI, and other
  fixed costs can dominate low-resolution/high-FPS tests.
- It does mean that render-scale-only at 1080p is expected to show lower GPU
  utilization/power even if FPS stays flat, which matches
  `render-scale-only-1080p-20260606-r1`.
- A path that collapses from roughly 200 FPS to roughly 80-120 FPS while GPU
  utilization is low, and while native DLSS evaluate is disabled or only costs about
  0.1 ms CPU wall time, is not a normal DLSS Performance-mode result. It is
  consistent with a stall, hot hook, synchronization/copy issue, or bad render-stage
  placement.
