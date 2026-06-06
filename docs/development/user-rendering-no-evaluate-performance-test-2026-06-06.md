# User-Rendering No-Evaluate Performance Test - 2026-06-06

Status: complete diagnostic, MVP still blocked.

## Question

Does the severe `dlss-user-rendering` performance regression require native DLSS
evaluate/writeback, or can the same regression be reproduced by the RenderGraph
resource-discovery and tuple-acceptance path alone?

Hypothesis:

- If no-evaluate performance is near baseline, the blocker is likely native evaluate,
  output writeback, or GPU submission around NGX.
- If no-evaluate performance still collapses, the blocker is likely the hot hook,
  reflection/resource discovery, synchronization around resource access, or another
  render-thread placement issue before NGX evaluate.

## Diagnostic Stage

Added `dlss-user-rendering-no-evaluate`:

- Enables the same render-scale intervention as `dlss-user-rendering`.
- Enables the same RenderGraph resource tuple discovery/acceptance path.
- Accepts and logs a valid DLSS input/output tuple.
- Returns before native frame-sequence creation and before
  `NGX_D3D11_EVALUATE_DLSS_EXT`.
- Leaves `EnableDLSS=false` and `DlssRuntimePath=` empty in the generated diagnostic
  config, so it does not need the SDK-wrapper native runtime.

## Results

All runs used true `1920x1080` Windowed gameplay, V Rising `FsrQualityMode=Off`, the
known local/private `11111` Continue fixture, and protected save backup/restore.

| Run | Change under test | Baseline FPS | Candidate FPS | Baseline 1% low | Candidate 1% low | Baseline P95 | Candidate P95 | Baseline GPU | Candidate GPU | Log proof |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| `user-rendering-no-evaluate-1080p-20260606-r1` | Initial no-evaluate route | `202.741` | `96.867` | `152.292` | `75.677` | `5.972 ms` | `12.076 ms` | `97.889% / 136.469 W` | `34.444% / 57.632 W` | `74` no-evaluate accepts, `0` evaluates, `32111` GetTexture-call logs |
| `user-rendering-no-evaluate-1080p-20260606-r2` | Suppressed broad GetTexture diagnostic logging/probe | `200.115` | `102.505` | `153.132` | `75.922` | `6.052 ms` | `11.676 ms` | `97.889% / 134.799 W` | `36.300% / 61.256 W` | `61` no-evaluate accepts, `0` evaluates, `0` GetTexture-call logs |
| `user-rendering-no-evaluate-1080p-20260606-r3` | Added reflection/member caches and accepted-tuple reuse | `201.802` | `111.842` | `155.421` | `78.655` | `5.974 ms` | `10.846 ms` | `97.333% / 133.537 W` | `37.700% / 66.195 W` | `53` no-evaluate accepts, `0` evaluates, `57` cached-tuple reuse lines |

## Interpretation

The regression does not require native DLSS evaluate/writeback. Even with no native
DLSS frame sequence, candidate FPS stays around `97-112` while the matching baselines
stay around `200-203`.

Disabling generic `RenderGraph GetTexture call` logging/probe only gave a small
improvement. Caching reflection and reusing the accepted tuple helped more, but still
did not approach baseline. That means the remaining cost is probably not just log I/O
or repeated reflection. The global
`RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix remains the leading
suspect because it sits in a very hot render-thread path and still executes broadly
even when most follow-up work is suppressed.

## Artifacts

- Screenshots and comparison summaries:
  `artifacts/visual-validation/*user-rendering-no-evaluate-1080p-20260606-r1*`,
  `artifacts/visual-validation/*user-rendering-no-evaluate-1080p-20260606-r2*`,
  and `artifacts/visual-validation/*user-rendering-no-evaluate-1080p-20260606-r3*`.
- Save protection evidence:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-user-rendering-no-evaluate-1080p-20260606-r1.json`,
  `artifacts/gameplay-automation/SaveCompareAfterRestore-user-rendering-no-evaluate-1080p-20260606-r2.json`,
  and `artifacts/gameplay-automation/SaveCompareAfterRestore-user-rendering-no-evaluate-1080p-20260606-r3.json`.

Each run restored the loader config to release-safe state, left no V Rising process
running, and restored the `11111` save with `ChangeCount=0`.

## Route Decision

Keep the global `GetTexture` hook as a diagnostic discovery aid only. The production
path should move toward a targeted render/upscale pass boundary where the relevant
resources are already declared and valid, then evaluate or copy from that boundary
without broad per-texture resource discovery in steady state.

## Follow-up Patch

After r3, the `GetTexture` postfix was narrowed so it reads the RenderGraph resource
name first and skips native pointer/owner reflection for non-candidate resources when
diagnostic GetTexture logging and output-followup are inactive. This is a hot-path
cost reduction only; it does not change the route decision above.

The same patch also changes cached-tuple no-evaluate logging to say that the input
probe was not repeated for that frame. This avoids reporting stale
`GetDlssSuperResolutionInputStatus()` text as if it were fresh evidence.

Needed r4 test:

- Stage: `dlss-user-rendering-no-evaluate`.
- Conditions: true `1920x1080` Windowed, V Rising `FsrQualityMode=Off`, protected
  local/private `11111` save.
- Question: does resource-name-first filtering significantly improve candidate FPS
  over r3's `111.842` average FPS?
- Pass signal for this patch: candidate FPS moves materially toward baseline while
  still logging no native evaluate.
- Fail signal: candidate remains around r3 (`~110 FPS`), meaning the global postfix
  call volume itself remains too expensive even after avoiding most native pointer
  reflection.
