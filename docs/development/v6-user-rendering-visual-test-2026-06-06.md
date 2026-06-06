# V6 User-Rendering Visual Test - 2026-06-06

Status: completed and blocked by performance regression.

## Question

With V Rising `FsrQualityMode=Off`, `DLSS.EnableDLSS=true`, SDK-wrapper local
runtime enabled, and the local/private `11111` save entered at `1920x1080`
Windowed, can the v6 `dlss-user-rendering` route produce captureable gameplay
baseline/candidate images and performance summaries?

## Hypothesis

The v6 runtime proof already showed the candidate can expose
`CameraColor/Depth/Motion=960x540` with output `1920x1080` and repeated
SDK-wrapper DLSS evaluates. The paired visual helper should therefore capture a
loader baseline and a `dlss-user-rendering` candidate in the same local scene, then
record screenshot hashes, FPS summaries, and candidate DLSS evidence.

## Test Shape

- Game path: `C:\Software\VRising`
- Output: `1920x1080` Windowed constructive shape
- V Rising FSR: `Off`
- Candidate stage: `dlss-user-rendering`
- Candidate runtime: local SDK-wrapper native plus
  `Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll`
- Scene entry: Computer Use clicks the known Chinese Continue / `11111` entry.
- Save handling: back up the `11111` save before launch, archive after-run state,
  restore from backup, then require `ChangeCount=0`.

## Expected Evidence

- Baseline run captures a nonblank gameplay PNG and performance summary.
- Candidate run waits for `DLSS user rendering evaluate succeeded` before capture.
- Candidate run captures a nonblank gameplay PNG and performance summary.
- Comparison artifact exists for baseline versus user-rendering candidate.
- BepInEx candidate log includes `render=960x540`, `target=1920x1080`, and
  repeated `DLSS user rendering evaluate succeeded`.
- Cleanup restores loader config, release-safe native DLL, FSR mode, and
  `ClientSettings.json`.
- No V Rising or V Rising server process remains.
- The `11111` save compare after restore reports `ChangeCount=0`.

## Pass Signal

The test produces both gameplay captures, both performance summaries, a comparison
artifact, candidate DLSS evidence, no crash, release-safe cleanup, and restored save.
This is still not a final human image-quality pass; it is the first v6 visual data
capture.

## Fail Signal

Any of the following are failures to persist:

- Computer Use cannot enter the `11111` gameplay fixture.
- Ready file times out.
- Screenshot is blank, wrong-window, wrong-resolution, or not gameplay.
- Candidate does not reach `DLSS user rendering evaluate succeeded`.
- Crash/WER is recorded.
- Release-safe cleanup or save restore fails.
- Candidate performance regresses enough that the visual status script blocks review.

## Cleanup

Let `scripts\run-vrising-visual-comparison.ps1` close the game and restore
release-safe state after each run. After the helper exits, confirm no game process
remains, run `scripts\protect-vrising-save.ps1 -Mode Restore -ArchiveCurrent`, and
confirm the after-restore comparison reports `ChangeCount=0`.

## Aborted First Attempt

Run label: `v6-user-rendering-1080p-auto-visual-20260606`.

The first visual helper launch was stopped after the baseline capture because the
capture was `3840x2160` instead of the required constructive `1920x1080` Windowed
shape. The helper did not yet force `ClientSettings.json` resolution/window mode.
Cleanup stopped V Rising, restored loader/native/FSR state, archived the partial log,
and restored the `11111` save. The save comparison after restore reported
`ChangeCount=0`.

This attempt exposed a harness gap, not a DLSS result.

## Harness Fix

`scripts\run-vrising-visual-comparison.ps1` now supports:

- `-Width` and `-Height`, defaulting to `1920` and `1080`.
- `-SetClientResolution`.
- `-SetClientWindowMode -ClientWindowMode 3`.

When requested, the helper backs up `ClientSettings.json`, writes the temporary
resolution/window mode, launches with matching screen arguments, and restores the
original settings in `finally`.

`scripts\protect-vrising-save.ps1` was added for the local/private `11111` fixture.
It can back up, compare, and restore a V Rising CloudSaves directory while refusing
paths outside the V Rising CloudSaves root.

## Completed Paired Run

Run label: `v6-user-rendering-1080p-auto-visual-20260606-r2`.

Command shape:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Z:\VrisingDLSS\scripts\run-vrising-visual-comparison.ps1 -GamePath C:\Software\VRising -CandidateStage dlss-user-rendering -FsrMode Off -ManualCapture -ReadyFile Z:\VrisingDLSS\artifacts\visual-validation\v6-user-rendering-1080p-automated-r2.ready -DurationSeconds 180 -CaptureAtSeconds 80 -CapturePerformance true -PerformanceSeconds 20 -WaitForUserRendering true -DlssRuntimePath Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll -ArtifactLabel v6-user-rendering-1080p-auto-visual-20260606-r2 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Artifacts:

- Baseline screenshot:
  `artifacts\visual-validation\v6-user-rendering-1080p-auto-visual-20260606-r2-baseline-loader.png`
- Candidate screenshot:
  `artifacts\visual-validation\v6-user-rendering-1080p-auto-visual-20260606-r2-user-rendering.png`
- Comparison:
  `artifacts\visual-validation\v6-user-rendering-1080p-auto-visual-20260606-r2-baseline-vs-user-rendering.txt`
- Baseline FPS:
  `artifacts\fps-validation\v6-user-rendering-1080p-auto-visual-20260606-r2-baseline-loader.txt`
- Candidate FPS:
  `artifacts\fps-validation\v6-user-rendering-1080p-auto-visual-20260606-r2-user-rendering.txt`
- Candidate log:
  `artifacts\runtime-logs\LogOutput-v6-user-rendering-1080p-auto-visual-20260606-r2-user-rendering.log`

Result:

- Baseline capture was valid gameplay at `1920x1080`.
- Candidate capture was valid gameplay at `1920x1080`.
- Comparison dimensions matched and reported `MeanAbsRgbDelta=1.6523`.
- Candidate log proved `render=960x540`, `target=1920x1080`,
  `sequenceCreates=1`, and `evaluateSuccesses=11700`.
- The helper restored FSR mode, `ClientSettings.json`, release-safe native DLL, and
  loader config, then left no V Rising process running.
- Save protection restored the `11111` save after `BeforeChangeCount=8`; the
  after-restore comparison reported `ChangeCount=0`.

## Performance Result

The route is visually captureable and DLSS evaluation succeeds, but the performance
gate failed hard:

| Metric | Baseline | Candidate | Delta |
| --- | ---: | ---: | ---: |
| Average FPS | 203.617 | 80.242 | -60.592% |
| 1% low FPS | 156.078 | 58.688 | -62.398% |
| P95 frame time | 5.947 ms | 14.775 ms | +148.445% |
| Average GPU utilization | 97.5% | 43.444% | -54.056 points |
| Average GPU power | 131.254 W | 81.371 W | -49.883 W |

`scripts\get-visual-validation-status.ps1 -RequiredCandidateStage dlss-user-rendering`
correctly reports `Status=Blocked` because performance regressed beyond the MVP
guardrails and no human visual review should override that.

## Interpretation

This is not the earlier repeated-proof-loop issue. The r2 candidate reuses one DLSS
feature and advances approximately one evaluate per Unity frame. The failure signature
is worse: FPS collapses while GPU utilization and power drop, which points toward a
CPU/render-thread stall or an unfavorable synchronization/submission point.

Current suspect: `dlss-user-rendering` still calls NGX synchronously from the
`RenderGraph GetTexture` resource-discovery postfix. That hook is useful for proving
the tuple exists, but it is not a proper HDRP upscale pass. The next step should add
timing diagnostics around the C# bridge call and native describe/query/evaluate
sections, then move evaluation toward a real render/upscale pass if the timing confirms
the stall.
