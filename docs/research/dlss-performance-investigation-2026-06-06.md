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

## Next Diagnostic Step

Add bounded timing instrumentation before another gameplay run:

- In C#, time `bridge.EvaluateDlssFrameSequence(...)` wall-clock duration and log
  average/max every few hundred frames.
- In native code, optionally split timing for describe/query/create/evaluate.
- Preserve the current one-evaluate-per-Unity-frame throttle.

Pass signal for this diagnostic is not high FPS. It should answer where the time is
going:

- If native `NGX_D3D11_EVALUATE_DLSS_EXT` itself is taking most of the frame, move the
  evaluate call out of the discovery postfix into a real render/upscale pass.
- If pointer description/query dominates, cache stable resource metadata and only
  refresh on pointer/size changes.
- If C# wall time is small but FPS remains low, instrument GPU submission/present
  timing next.

## Route Decision

Do not treat `DLSS user rendering evaluate succeeded` as a performance pass. The
current route proves the tuple and SDK wrapper can evaluate. MVP readiness still
requires a rendering placement that improves or at least does not severely regress
frame time in a controlled FSR Off comparison.
