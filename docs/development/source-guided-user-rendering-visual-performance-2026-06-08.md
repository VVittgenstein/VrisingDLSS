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

## Candidate-Only Performance Rerun

After the harness fix, a candidate-only runtime repro verified that the new
structured PresentMon path can capture FPS for the current source-guided
`dlss-user-rendering` candidate:

- Artifact label:
  `candidate-user-rendering-perf-1080p-20260608-r1`
- Shape: true `1920x1080` Windowed, V Rising `FsrQualityMode=Off`,
  `DLSS.EnableDLSS=true`, protected local save, manual Continue click only.
- Computer Use selected the real
  `process:C:\Software\VRising\VRising.exe` Unity window, clicked Continue once,
  and sent no movement/gameplay keys.
- User-rendering evidence was detected at `2026-06-08T14:12:01.4409834+08:00`.
- Screenshot:
  `artifacts\visual-validation\candidate-user-rendering-perf-1080p-20260608-r1-user-rendering.png`
  with `Width=1920`, `Height=1080`, `AverageLuma=24.685`,
  `NearBlackRatio=0.310741`, and SHA-256
  `057A21D3365DA16E6BC5D27ED5474A9A74BFA37BD71CE16D557AAA0DD93ADD8B`.
- FPS summary:
  `artifacts\fps-validation\candidate-user-rendering-perf-1080p-20260608-r1-user-rendering.txt`
  with `Status=Pass`.

| Metric | Candidate-only |
| --- | ---: |
| Average FPS | 136.322 |
| 1% low FPS | 105.096 |
| P95 frame time | 8.624 ms |
| P99 frame time | 9.515 ms |
| Average GPU utilization | 53.111% |
| P95 GPU utilization | 58.2% |
| Average GPU power | 85.199 W |
| Average process CPU | 6.427% |
| Average GPU memory | 4563.333 MB |

Runtime cleanup passed: no crash/WER evidence, `ClosedByScript=True`, no
remaining V Rising process, loader/native/client/BepInEx config restored, V
Rising FSR restored to `Off`, and protected save restore ended with
`CompareStatus=Restored` and final `ChangeCount=0`.

This is a measurement-harness success and useful candidate diagnostic, not an
MVP performance pass. Cross-run comparison against the earlier paired baseline
(`AverageFps=156.105`, `OnePercentLowFps=90.552`, `P95FrameMs=9.209`) would put
the candidate at about `-12.67%` average FPS, `+16.06%` 1% low, and `-6.35%`
P95 frame time, but that comparison is not controlled because this was
candidate-only. The readiness gate remains blocked until a same-run paired
baseline/candidate comparison produces `Status=Pass` performance summaries and
a human visual review.

## Source/Decompilation Direction

The candidate-only rerun changes the next technical question. The current
source-guided EASU `ctx.cmd` route is stable enough to measure, avoids the old
hot `RenderGraph.GetTexture` path, and produces nonblank visible output. More
blind runtime loops are now lower value than a narrow source/decompilation pass.

Use local Unity HDRP source plus V Rising IL2CPP metadata/decompilation to
compare the official
`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> DLSSPass.Render(..., ctx.cmd)`
path against the current EASU `ctx.cmd` candidate. The narrow questions are:

- Which official per-frame values are passed to DLSS but missing or approximated
  in the candidate: jitter, motion-vector scale, reset/history state,
  pre-exposure, sharpness, camera/resource history, render size, and output size?
- Where does official HDRP create/reuse/reset the DLSS feature across resize,
  camera, dynamic-resolution, and history changes?
- Does the official pass declare/read/write resources differently from the
  current EASU-visible write-back route in a way that would explain lower GPU
  utilization or synchronization/present behavior?
- Is there a BepInEx/Harmony-safe equivalent boundary closer to
  `DoDLSSPass`/`DLSSPass.Render` than the EASU render func, without broad
  steady-state resource discovery?

Keep any decompiled-game evidence local and summarized. Do not copy proprietary
method bodies or game assets into the public package; use the result as a map for
clean-room patches and focused probes only.

## API 21 Paired Visual/Performance Rerun

After the API 21 parameter-alignment patch, a same-run protected paired
comparison was captured:

- Artifact label:
  `api21-paired-user-rendering-1080p-20260608-r1`
- Shape: true `1920x1080` Windowed, V Rising `FsrQualityMode=Off`,
  protected local/private `11111` save, SDK-wrapper native and local research
  `nvngx_dlss.dll` only for the candidate.
- Computer Use selected the real
  `process:C:\Software\VRising\VRising.exe` Unity window for both runs, clicked
  Continue once per run, sent no movement/gameplay keys, and was disconnected
  after the game had exited and cleanup completed.
- Additional system snapshots were saved under
  `artifacts/system-snapshots/api21-paired-user-rendering-1080p-20260608-r1-*.json`.

The baseline returned to the earlier high-performance range. This supports the
user's observation that the previous `156 FPS` baseline was likely an
environment/measurement-timing drift rather than save-state drift:

| Metric | Baseline | Candidate | Delta |
| --- | ---: | ---: | ---: |
| Average FPS | 199.704 | 126.358 | -36.727% |
| 1% low FPS | 150.016 | 99.225 | -33.857% |
| Average frame time | 5.007 ms | 7.914 ms | +58.058% |
| P95 frame time | 6.061 ms | 9.088 ms | +49.942% |
| P99 frame time | 6.666 ms | 10.078 ms | +51.164% |
| Average GPU utilization | 97.75% | 51.0% | -46.75 pp |
| Average GPU power | 138.106 W | 86.064 W | -52.042 W |
| Average GPU memory | 4975.625 MB | 4799.444 MB | -176.181 MB |
| Average process CPU | 8.175% | 6.608% | -1.567 pp |

Image comparison:

- `BaselineSha256=C5208146D248FED25133380B8720E897E416CA2F2D22D6456C002CAB81DA4255`
- `CandidateSha256=E0750646B64C7A90186933E0C76BEA9774C14D2EF788B2F034D09D7B59463D4C`
- `MeanAbsRgbDelta=1.8288`
- `ChangedRatioGt10=0.021332`
- both captures were `1920x1080`.

Candidate DLSS evidence stayed technically clean:

- Readiness selected this comparison as the current evidence.
- `CandidateEvidenceProved=True`, `UserRenderingProved=True`.
- Candidate log counts:
  `Native bridge API version: 21` = `1`,
  `dlssFrameParams=` = `11`,
  `dlssEvaluateParams=` = `1`,
  native `jitter/mvScale/preExposure` status = `66`,
  `DLSS user rendering evaluate succeeded` = `1`,
  `RenderGraph GetTexture call #` = `0`,
  explicit user-rendering failed/blocked/skipped = `0`,
  access violation / `0xc0000005` / `nvwgf2umx` = `0`.

System snapshot summary:

- Baseline gameplay-ready snapshot:
  GPU `96%`, `138.86 W`, `87 C`, `4997 MB`; CPU total `26%`.
- Candidate gameplay-ready snapshot:
  GPU `48%`, `87.93 W`, `75 C`, `4801 MB`; CPU total `12%`.
- The snapshots do not point to an external GPU-heavy process stealing the
  candidate run. They reinforce the same signal as PresentMon: the candidate is
  running with much lower GPU utilization/power while frame time is worse.

Cleanup passed: crash count `0`, no remaining V Rising process, release-safe
state restored, BepInEx config restored, client settings restored, FSR restored
to `Off`, changed post-run save archived, and protected save restore ended with
`CompareStatus=Restored` and `ChangeCount=0`.

Readiness remains blocked for the right reason: the current API 21 command-buffer
candidate regresses performance in a same-run paired comparison. This is not a
missing-metrics problem anymore. The next useful route is source/decompilation
analysis of official HDRP `DLSSPass` behavior versus the current EASU `ctx.cmd`
candidate, especially feature flags, lifecycle/reset, resource declarations,
pass ordering, and whether V Rising modifies the HDRP/postprocess/dynamic-res
flow in ways not covered by upstream Unity source.

## Official DLSSPass Audit Result

The source/decompilation comparison is recorded in
`docs/development/official-dlsspass-vs-easu-candidate-audit-2026-06-08.md`.
Fresh IL2CPP shell evidence is recorded in
`docs/development/vrising-il2cpp-hdrp-dlss-shell-decompilation-2026-06-08.md`.

Key findings:

- Official HDRP creates DLSS with `IsHDR | MVLowRes | DepthInverted |
  DoSharpening` (`0x2B` in the current NGX headers), while the candidate run
  used `AutoExposure` only (`0x40`).
- Official eval sets invert Y to `1`; the current native eval leaves the NGX
  invert-axis fields at zero.
- The current command-buffer path carries jitter, motion-vector scale,
  pre-exposure, and camera reset into the native payload, but the native frame
  sequence only applies reset on the first evaluate. Official HDRP also applies
  later camera reset/history requests.
- Official HDRP writes a `"DLSS destination"` postprocess-upsampled output
  handle and then uses that as the source; the candidate writes into the EASU
  visible output target.
- V Rising IL2CPP evidence confirms the HDRP DLSS pass shell, generated
  `DoDLSSPass` render func, resource structs, and pass strings exist locally.
  The execution methods that should submit NVIDIA work (`DLSSPass.Render`,
  `BeginFrame`, and `SetupDRSScaling`) all map to the same no-op-style address,
  so the built-in official renderer should not be treated as directly usable.

Next runtime work should follow a small source-backed patch, not another blind
rerun. The first likely experiment is official feature flags plus invert-axis
parity, with reset/lifecycle parity either included if tiny or left for the next
focused patch.

## Official Flags/Invert Paired Result

The official-HDRP-like feature flag and invert-axis parity experiment has now
run as `official-flags-paired-user-rendering-1080p-20260608-r2`; see
`docs/development/official-hdrp-dlss-flag-invert-paired-result-2026-06-08.md`.

The patch was active and technically clean:

- candidate logs included `flags=0x0000002B` and `invertAxis=(0,1)`;
- `DLSS user rendering evaluate succeeded from native command-buffer EASU
  ctx.cmd`;
- `RenderGraph GetTexture call #=0`;
- no crash/access-violation/driver evidence;
- cleanup restored release-safe state and the protected save to `ChangeCount=0`.

It did not fix performance:

| Metric | Baseline | Candidate | Delta |
| --- | ---: | ---: | ---: |
| Average FPS | 202.794 | 128.745 | -36.514% |
| 1% low FPS | 151.105 | 97.431 | -35.521% |
| P95 frame time | 6.004 ms | 9.251 ms | +54.081% |
| Average GPU utilization | 97.143% | 54.643% | -42.500 pp |
| Average GPU power | 136.757 W | 90.929 W | -45.828 W |

Conclusion: feature flags and invert axes were real mismatches and should stay
aligned with official HDRP behavior, but they are not the core FPS blocker. The
remaining symptom is still pipeline/placement/synchronization shaped: lower GPU
utilization and power while frame time worsens.

## System Snapshot Harness Follow-Up

After the user pointed out the old `203-205 FPS` baseline versus the later
`156.105 FPS` baseline drift, the FPS helper was extended to capture wider
machine context automatically:

- New script: `scripts\capture-system-snapshot.ps1`.
- `scripts\capture-vrising-fps.ps1` now records before/after snapshot paths in
  every FPS summary unless `-SkipSystemSnapshots` is passed.
- Each snapshot includes top CPU/memory processes, the target `VRising` process
  row when present, OS memory, CPU summary, NVIDIA GPU utilization/memory/power/
  temperature/clocks/driver/P-state, and any GPU process rows exposed by
  `nvidia-smi`.

This does not launch the game and does not decide the DLSS performance bug by
itself. It makes the next paired run much easier to compare when baseline
performance drifts for non-save reasons.
