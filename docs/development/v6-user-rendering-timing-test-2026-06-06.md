# V6 User-Rendering Timing Test - 2026-06-06

Status: completed; timing evidence collected, performance still blocked.

## Question

With V Rising `FsrQualityMode=Off`, the v6 render-scale intervention, and the
instrumented SDK-wrapper `dlss-user-rendering` path at true `1920x1080` Windowed,
where is the candidate spending frame time when FPS drops and GPU utilization falls?

## Hypothesis

The previous r2 comparison proved `960x540 -> 1920x1080` DLSS evaluate success but
failed performance hard. The new timing fields should show whether the stall is in:

- C# bridge wall time;
- native texture describe/query overhead;
- native prepare/create/mutex time; or
- `NGX_D3D11_EVALUATE_DLSS_EXT(...)`.

## Test Shape

- Game path: `C:\Software\VRising`
- Output: `1920x1080` Windowed constructive shape
- V Rising FSR: `Off`
- Candidate stage: `dlss-user-rendering`
- Candidate runtime: local SDK-wrapper native plus
  `Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll`
- Scene entry: Computer Use selects the real `VRising` game window and clicks the
  known Chinese Continue / `11111` entry once per run.
- Save handling: back up the `11111` save before launch, archive after-run state,
  restore from backup, then require `ChangeCount=0`.
- No movement or gameplay keys should be sent.

## Expected Evidence

- Baseline run captures a nonblank gameplay PNG and performance summary.
- Candidate run waits for `DLSS user rendering evaluate succeeded` before capture.
- Candidate run captures a nonblank gameplay PNG and performance summary.
- Candidate log includes `render=960x540`, `target=1920x1080`, and repeated
  `DLSS user rendering evaluate succeeded`.
- Candidate log includes:
  - `bridgeTiming=lastMs=...,avgMs=...,maxMs=...,samples=...`
  - `nativeTimingMs=(describe=...,query=...,prepare=...,evaluate=...,total=...)`
- Cleanup restores loader config, release-safe native DLL, FSR mode, and
  `ClientSettings.json`.
- No V Rising or V Rising server process remains.
- The `11111` save compare after restore reports `ChangeCount=0`.

## Pass Signal

The test produces enough timing evidence to classify the performance regression's
likely source. FPS improvement is not required for this diagnostic pass.

## Fail Signal

Any of the following are failures to persist:

- Computer Use cannot enter the `11111` gameplay fixture.
- Ready file times out.
- Screenshot is blank, wrong-window, wrong-resolution, or not gameplay.
- Candidate does not reach `DLSS user rendering evaluate succeeded`.
- Candidate log lacks the new timing fields.
- Crash/WER is recorded.
- Release-safe cleanup or save restore fails.

## Cleanup

Let `scripts\run-vrising-visual-comparison.ps1` close the game and restore
release-safe state after each run. After the helper exits, confirm no game process
remains, run `scripts\protect-vrising-save.ps1 -Mode Restore -ArchiveCurrent`, and
confirm the after-restore comparison reports `ChangeCount=0`.

## Completed Run

Run label: `v6-user-rendering-1080p-timing-20260606-r3`.

Artifacts:

- Baseline screenshot:
  `artifacts\visual-validation\v6-user-rendering-1080p-timing-20260606-r3-baseline-loader.png`
- Candidate screenshot:
  `artifacts\visual-validation\v6-user-rendering-1080p-timing-20260606-r3-user-rendering.png`
- Comparison:
  `artifacts\visual-validation\v6-user-rendering-1080p-timing-20260606-r3-baseline-vs-user-rendering.txt`
- Baseline FPS:
  `artifacts\fps-validation\v6-user-rendering-1080p-timing-20260606-r3-baseline-loader.txt`
- Candidate FPS:
  `artifacts\fps-validation\v6-user-rendering-1080p-timing-20260606-r3-user-rendering.txt`
- Candidate log:
  `artifacts\runtime-logs\LogOutput-v6-user-rendering-1080p-timing-20260606-r3-user-rendering.log`
- Save restore:
  `artifacts\gameplay-automation\SaveCompareAfterRestore-v6-user-rendering-1080p-timing-20260606-r3.json`

Result:

- Baseline capture was valid gameplay at `1920x1080`.
- Candidate capture was valid gameplay at `1920x1080`.
- Comparison dimensions matched and reported `MeanAbsRgbDelta=1.5974`.
- Candidate log proved `render=960x540`, `target=1920x1080`,
  `sequenceCreates=1`, and `evaluateSuccesses=12000`.
- Candidate log included the new `bridgeTiming=...` and `nativeTimingMs=(...)`
  fields.
- The helper restored FSR mode, `ClientSettings.json`, release-safe native DLL, and
  loader config, then left no V Rising process running.
- Save protection restored the `11111` save after `BeforeChangeCount=7`; the
  after-restore comparison reported `ChangeCount=0`.

## Performance Result

The candidate still failed the MVP performance gate:

| Metric | Baseline | Candidate | Delta |
| --- | ---: | ---: | ---: |
| Average FPS | 205.255 | 86.761 | -57.730% |
| 1% low FPS | 153.451 | 67.061 | -56.298% |
| P95 frame time | 5.896 ms | 13.642 ms | +131.377% |
| Average GPU utilization | 98.111% | 40.889% | -57.222 points |
| Average GPU power | 137.760 W | 78.541 W | -59.219 W |

`scripts\get-visual-validation-status.ps1 -RequiredCandidateStage dlss-user-rendering`
correctly reports `Status=Blocked` for this artifact.

## Timing Result

Representative user-rendering timing lines:

- First evaluate: `bridgeTiming=lastMs=604.85,avgMs=604.85,maxMs=604.85,samples=1`;
  `nativeTimingMs=(describe=0.003,query=0.000,prepare=604.451,evaluate=0.296,total=604.750)`.
- Stable evaluate at `sequenceSuccesses=12000`:
  `bridgeTiming=lastMs=0.092,avgMs=0.142,maxMs=604.85,samples=12000`;
  `nativeTimingMs=(describe=0.001,query=0.000,prepare=0.001,evaluate=0.083,total=0.085)`.

Across the 45 logged timing rows, the first create dominates average/max:

- `BridgeLastMs` average/max: `13.535 ms` / `604.85 ms`.
- `NativePrepareMs` average/max: `13.434 ms` / `604.451 ms`.
- `NativeEvaluateMs` average/max: `0.089 ms` / `0.296 ms`.
- `NativeTotalMs` average/max: `13.524 ms` / `604.750 ms`.

After creation, the stable per-frame bridge/native time is about `0.08-0.12 ms`.
This is far below the observed candidate frame time of about `11.526 ms`.

Additional hot-path evidence from the candidate log:

- `RenderGraph GetTexture call` lines: `18414`.
- `DLSS user rendering evaluate succeeded` lines: `45` logged samples for
  `12000` successes.
- `DLSS user rendering evaluate failed/blocked/skipped`: `0`.
- `Render-scale control software fallback diagnostic` lines: `32`.

## Interpretation

This diagnostic classifies the r2/r3 regression more narrowly:

- The one-time DLSS session creation is expensive but not the sustained FPS problem.
- Stable `NGX_D3D11_EVALUATE_DLSS_EXT(...)` CPU wall time is tiny in this setup.
- Per-frame native texture describe/query overhead is also tiny.
- The performance regression likely lives outside the measured native evaluate call:
  either the hot `RenderGraph GetTexture` postfix/resource-discovery path, the v6
  render-scale/HDRP software fallback path, HDRP's own upscale path, or GPU submission
  behavior not reflected in CPU wall time.

Next isolation test should compare baseline against a `render-scale-control` candidate
with V Rising FSR Off and no DLSS evaluate. If that candidate is also slow, prioritize
productionizing render-scale control and reducing hook/log overhead. If render-scale
only is fast, isolate the `dlss-user-rendering` RenderGraph/evaluate path separately.
