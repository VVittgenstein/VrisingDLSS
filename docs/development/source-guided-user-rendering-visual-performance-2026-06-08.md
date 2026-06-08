# Source-Guided User-Rendering Visual/Performance Run - 2026-06-08

Status: partial; visual/DLSS/save cleanup passed, candidate FPS capture failed.

## Question

Can the current source-guided `dlss-user-rendering` candidate produce a paired
`1920x1080` Windowed gameplay visual/performance comparison in the protected
local `11111` fixture with V Rising `FsrQualityMode=Off`?

## Test Shape

- Game path: `C:\Software\VRising`
- Artifact label: `source-guided-user-rendering-1080p-20260608-r1`
- Candidate stage: `dlss-user-rendering`
- DLSS runtime: `Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll`
- Capture mode: `-ManualCapture`
- Window/settings: `1920x1080`, `WindowMode=3`, V Rising FSR `Off`
- Harness protections:
  - `-ProtectSave` on the local/private save
  - temporary BepInEx console disable + disk instant flushing
  - release-safe native/config restore after each run
- Computer Use action:
  - selected the real `process:C:\Software\VRising\VRising.exe` Unity window
  - clicked the Chinese Continue / `11111` entry once for baseline
  - clicked the Chinese Continue / `11111` entry once for candidate
  - sent no movement/gameplay keys

Two wrapper-start attempts failed before launching the game because the detached
PowerShell command line first split the `SaveDir` path and then mishandled
`-CapturePerformance:$true`. The actual run used quoted paths and boolean values
without the colon syntax. Those failed starts did not launch V Rising and are not
runtime evidence.

## Artifacts

- Baseline screenshot:
  `artifacts\visual-validation\source-guided-user-rendering-1080p-20260608-r1-baseline-loader.png`
- Candidate screenshot:
  `artifacts\visual-validation\source-guided-user-rendering-1080p-20260608-r1-user-rendering.png`
- Image comparison:
  `artifacts\visual-validation\source-guided-user-rendering-1080p-20260608-r1-baseline-vs-user-rendering.txt`
- Baseline FPS summary:
  `artifacts\fps-validation\source-guided-user-rendering-1080p-20260608-r1-baseline-loader.txt`
- Candidate system metrics only:
  `artifacts\fps-validation\source-guided-user-rendering-1080p-20260608-r1-user-rendering.metrics.csv`
- Candidate log:
  `artifacts\runtime-logs\LogOutput-source-guided-user-rendering-1080p-20260608-r1-user-rendering.log`
- Candidate analysis:
  `artifacts\runtime-logs\Analysis-source-guided-user-rendering-1080p-20260608-r1-user-rendering.txt`
- Save restore check:
  `artifacts\gameplay-automation\SaveCompareAfterRestore-source-guided-user-rendering-1080p-20260608-r1-protected-save.json`

## Visual Result

The paired gameplay screenshots were both valid `1920x1080` captures from the
same protected fixture. The comparison matched dimensions and reported:

- `MeanAbsRgbDelta=2.0072`
- `MeanAbsLumaDelta=1.8884`
- `ChangedRatioGt10=0.026254`
- baseline near-black/near-white: `0.292396` / `0.000009`
- candidate near-black/near-white: `0.311211` / `0.000009`
- baseline SHA-256:
  `958D4A9113215772BE6581E2F79848C83EC942DAA4009B32188B1758DB299773`
- candidate SHA-256:
  `E50A62639F00DA8A4899DC8D989E9A889DC19C2DC62F05CB739236E6A1E0C69F`

This is useful visual evidence, but it is not a human image-quality pass.

## DLSS Runtime Evidence

The candidate analyzer reported:

- `Native RenderFunc CommandBuffer DLSS User Rendering=Pass`
- `DLSS User Rendering Candidate=Pass`

Key candidate log evidence:

- `DLSS user rendering evaluate succeeded from native command-buffer EASU ctx.cmd`
- `eventId=260615`
- `setSuccesses=12`
- `consumed=12`
- `consumeFailures=0`
- `input=960x540`
- `output=1920x1080`
- `validation=D3D11-succeeded`
- `sameDevice=yes`
- `scratchOutput=no`
- `visibleOutput=yes`
- `persistent=yes`
- `sequenceCreates=1`
- `sequenceEvaluates=12`
- `evaluateSuccesses=12`
- `evaluateResult=1`
- native timing `evaluate=0.139ms`, `total=0.141ms`

Negative checks:

- `RenderGraph GetTexture call #`: `0`
- user-rendering blocked/failed/skipped lines: `0`
- access violation / `0xc0000005`: `0`
- `nvwgf2umx`: `0`
- WER artifact: absent

## Performance Result

The baseline PresentMon capture succeeded:

| Metric | Baseline |
| --- | ---: |
| Average FPS | 156.105 |
| 1% low FPS | 90.552 |
| P95 frame time | 9.209 ms |
| Average CPU | 8.171% |
| Average GPU utilization | 81.4% |
| Average GPU power | 124.864 W |
| Average GPU memory | 4902.8 MB |

The candidate performance capture did not produce a PresentMon CSV or FPS summary.
`capture-vrising-fps.ps1` threw:

```text
PresentMon did not create a CSV file:
artifacts\fps-validation\source-guided-user-rendering-1080p-20260608-r1-user-rendering.csv
```

The parallel system metrics job did record six samples while the candidate process
was alive:

| Metric | Candidate system metrics only |
| --- | ---: |
| Average CPU | 6.563% |
| Average GPU utilization | 33.0% |
| Average GPU power | 62.24 W |
| Average GPU memory | 4815 MB |
| Average GPU temperature | 68.833 C |

Because the candidate FPS CSV is missing, this run cannot decide the MVP
performance gate. The low candidate GPU utilization/power still matches the
previous stall-like symptom and should be investigated, but without PresentMon
frame rows it is not a controlled FPS comparison.

## Cleanup

Cleanup passed:

- V Rising process count after the run: `0`
- loader config restored
- release-safe native restored by `install-local-package.ps1`
- V Rising FSR restored to `Off`
- `ClientSettings.json` restored
- BepInEx config restored
- protected save restore:
  - `BeforeChangeCount=2`
  - `CompareStatus=Restored`
  - final `ChangeCount=0`

## Interpretation

This run is not a DLSS placement failure. It strengthens the source-guided
command-buffer route: the candidate produced a valid gameplay screenshot, reached
normal-user DLSS evaluate through the EASU `ctx.cmd` boundary, and avoided the old
hot `RenderGraph.GetTexture` path.

The actionable blocker is measurement/harness reliability for candidate
performance. The next small step should make the visual comparison helper preserve
partial performance-capture failures as structured result fields and/or make
`capture-vrising-fps.ps1` emit an explicit failure summary when PresentMon exits
without a CSV. Then rerun the paired comparison, or run a shorter candidate-only
performance repro to isolate why PresentMon returned success but wrote no frame
CSV.

## Follow-Up Harness Fix

Implemented after this partial run:

- `scripts/capture-vrising-fps.ps1` now writes a structured summary even when
  PresentMon exits successfully but creates no CSV, when PresentMon exits
  nonzero, or when the CSV has no usable `MsBetweenPresents` samples.
- Successful summaries now include `Status=Pass`; failure summaries include a
  specific status such as `PresentMonCsvMissing` and a `FailureReason`, while
  still preserving any system metrics CSV averages that were captured.
- `scripts/get-visual-validation-status.ps1` now blocks if a baseline or
  candidate performance summary has a non-`Pass` status or lacks required FPS
  metrics: `AverageFps`, `OnePercentLowFps`, or `P95FrameMs`.

Validation was intentionally non-runtime: a fake PresentMon script exited `0`
without writing a CSV, and the FPS helper produced
`Status=PresentMonCsvMissing` with empty FPS fields. A temporary readiness check
confirmed that such a summary is reported as a performance capture failure and
does not satisfy the MVP visual/performance gate. A second fake PresentMon script
wrote a three-row CSV and confirmed the success path still emits `Status=Pass`
with `AverageFps`, `OnePercentLowFps`, and `P95FrameMs`.
