# Render-Scale-Only Performance Test - 2026-06-06

Status: completed and cleaned up.

## Question

With V Rising `FsrQualityMode=Off` at true `1920x1080` Windowed, does the v6
`render-scale-control` path alone cause the same FPS/GPU-utilization regression seen
in `dlss-user-rendering`, when no DLSS evaluate is enabled?

## Hypothesis

The r3 timing run showed stable native DLSS evaluate CPU wall time is about
`0.08-0.12 ms`, far below the observed candidate frame time. If render-scale-only is
also slow, the blocker is likely in the v6 render-scale/HDRP path, HDRP's fallback
upscale path, or hot hook overhead. If render-scale-only is fast, the blocker remains
specific to the user-rendering RenderGraph/evaluate path or GPU submission behavior.

## Test Shape

- Game path: `C:\Software\VRising`
- Output: `1920x1080` Windowed constructive shape
- V Rising FSR: `Off`
- Candidate stage: `render-scale-control`
- Candidate runtime: release-safe native only; no SDK-wrapper native and no
  `nvngx_dlss.dll`
- Scene entry: Computer Use selects the real `VRising` game window and clicks the
  known Chinese Continue / `11111` entry once per run.
- Save handling: back up the `11111` save before launch, archive after-run state,
  restore from backup, then require `ChangeCount=0`.
- No movement or gameplay keys should be sent.

## Expected Evidence

- Baseline run captures a nonblank gameplay PNG and performance summary.
- Candidate run captures a nonblank gameplay PNG and performance summary.
- Comparison artifact exists for baseline versus render-scale-control candidate.
- Candidate log includes render-scale control evidence such as
  `GetCurrentScale=0.5` or `GetResolvedScale=(0.50, 0.50)`.
- Candidate log does not include `DLSS user rendering evaluate succeeded`.
- Cleanup restores loader config, release-safe native DLL, FSR mode, and
  `ClientSettings.json`.
- No V Rising or V Rising server process remains.
- The `11111` save compare after restore reports `ChangeCount=0`.

## Pass Signal

This diagnostic passes if it clearly separates render-scale-only performance from
DLSS-evaluate performance:

- render-scale-only fast: investigate user-rendering RenderGraph/evaluate placement;
- render-scale-only slow: investigate v6 render-scale/HDRP fallback/upscale and hook
  overhead before changing NGX integration.

## Fail Signal

Any of the following are failures to persist:

- Computer Use cannot enter the `11111` gameplay fixture.
- Ready file times out.
- Screenshot is blank, wrong-window, wrong-resolution, or not gameplay.
- Candidate log lacks render-scale-control evidence.
- Candidate accidentally runs DLSS evaluate.
- Crash/WER is recorded.
- Release-safe cleanup or save restore fails.

## Cleanup

Let `scripts\run-vrising-visual-comparison.ps1` close the game and restore
release-safe state after each run. After the helper exits, confirm no game process
remains, run `scripts\protect-vrising-save.ps1 -Mode Restore -ArchiveCurrent`, and
confirm the after-restore comparison reports `ChangeCount=0`.

## Result

Run label: `render-scale-only-1080p-20260606-r1`.

The test answered the diagnostic question: render-scale-only did not reproduce the
`dlss-user-rendering` FPS collapse.

Performance:

- Baseline average FPS: `204.419`.
- Candidate average FPS: `205.410`.
- Baseline 1% low FPS: `154.841`.
- Candidate 1% low FPS: `140.222`.
- Baseline P95 frame time: `5.929 ms`.
- Candidate P95 frame time: `6.188 ms`.
- Baseline average GPU utilization/power: `98.222%`, `135.571 W`.
- Candidate average GPU utilization/power: `65.556%`, `95.183 W`.

Evidence:

- Baseline screenshot:
  `artifacts/visual-validation/render-scale-only-1080p-20260606-r1-baseline-loader.png`
- Candidate screenshot:
  `artifacts/visual-validation/render-scale-only-1080p-20260606-r1-render-scale-control.png`
- Comparison artifact:
  `artifacts/visual-validation/render-scale-only-1080p-20260606-r1-baseline-vs-render-scale-control.txt`
- Baseline FPS summary:
  `artifacts/fps-validation/render-scale-only-1080p-20260606-r1-baseline-loader.txt`
- Candidate FPS summary:
  `artifacts/fps-validation/render-scale-only-1080p-20260606-r1-render-scale-control.txt`
- Candidate log:
  `artifacts/runtime-logs/LogOutput-render-scale-only-1080p-20260606-r1-render-scale-control.log`
- Save restore comparison:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-render-scale-only-1080p-20260606-r1.json`

Candidate log checks:

- `GetCurrentScale=0.5`: `31`.
- `GetResolvedScale=(0.50, 0.50)`: `31`.
- `DLSS user rendering evaluate succeeded`: `0`.
- `RenderGraph GetTexture call`: `0`.

Cleanup checks:

- The visual helper restored FSR mode, loader config, release-safe native DLL, and
  `ClientSettings.json`.
- No `VRising` or `VRisingServer` process remained after the run.
- Loader config returned to safe state with `EnableDLSS=false` and an empty
  `DlssRuntimePath`.
- The `11111` save was restored from the pre-run backup with `ChangeCount=0`.

## Interpretation

The v6 render-scale/HDRP dynamic-resolution intervention by itself is not the source
of the severe regression. It lowers GPU workload as expected, which explains the
lower GPU utilization and power, while preserving average FPS around the baseline.

The performance blocker is therefore specific to the `dlss-user-rendering` path that
adds RenderGraph tuple discovery and DLSS evaluation/writeback behavior. The next
isolation should separate hot `RenderGraphResourceRegistry.GetTexture` discovery from
native DLSS evaluate/writeback, for example with a user-rendering no-evaluate
candidate or a proper render/upscale pass placement experiment.
