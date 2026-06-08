# Official HDRP DLSS Flag/Invert Paired Result - 2026-06-08

Status: protected runtime result. The official-HDRP-like feature flag and
invert-axis parity patch is technically active, but it does not fix the current
performance blocker.

## Question

Does changing the current EASU `ctx.cmd` user-rendering candidate from
AutoExposure-only feature creation to official-HDRP-like feature flags
(`0x2B`) and NGX invert axis `(0,1)` reduce the low-GPU-utilization FPS
regression seen in the prior API 21 paired run?

## Run

- Artifact label:
  `official-flags-paired-user-rendering-1080p-20260608-r2`
- Shape: true `1920x1080` Windowed, V Rising `FsrQualityMode=Off`,
  protected local/private `11111` save.
- Baseline: loader/release-safe native, `DLSS.EnableDLSS=false`.
- Candidate: `dlss-user-rendering`, SDK-wrapper native, local research
  `nvngx_dlss.dll`, `DLSS.EnableDLSS=true`.
- Computer Use selected the real
  `process:C:\Software\VRising\VRising.exe` window for both runs, clicked
  Continue once per run, and sent no movement/gameplay keys.
- Automatic before/after system snapshots were produced for both FPS captures.

There was an earlier `r1` launch attempt that failed before game launch because
the external background launcher split the protected save path at the
`Stunlock Studios` space. It did not start V Rising and did not touch the save.
`r2` is the actual runtime result.

## Performance Result

| Metric | Baseline | Candidate | Delta |
| --- | ---: | ---: | ---: |
| Average FPS | 202.794 | 128.745 | -36.514% |
| 1% low FPS | 151.105 | 97.431 | -35.521% |
| Average frame time | 4.931 ms | 7.767 ms | +57.514% |
| P95 frame time | 6.004 ms | 9.251 ms | +54.081% |
| P99 frame time | 6.618 ms | 10.264 ms | +55.095% |
| Average GPU utilization | 97.143% | 54.643% | -42.500 pp |
| Average GPU power | 136.757 W | 90.929 W | -45.828 W |
| Average GPU temperature | 87.071 C | 77.857 C | -9.214 C |
| Average process CPU | 7.743% | 6.715% | -1.028 pp |

Readiness blocks for the right reason:

- Average FPS regression: `-36.514%` where the MVP gate allows at worst `-10%`.
- 1% low FPS regression: `-35.521%` where the MVP gate allows at worst `-15%`.
- P95 frame time worsened: `+54.081%` where the MVP gate allows at most `+15%`.
- Human visual review is still missing, but performance already blocks MVP.

## Image Result

- Baseline screenshot:
  `artifacts\visual-validation\official-flags-paired-user-rendering-1080p-20260608-r2-baseline-loader.png`
- Candidate screenshot:
  `artifacts\visual-validation\official-flags-paired-user-rendering-1080p-20260608-r2-user-rendering.png`
- Comparison artifact:
  `artifacts\visual-validation\official-flags-paired-user-rendering-1080p-20260608-r2-baseline-vs-user-rendering.txt`
- Both captures were `1920x1080`.
- `MeanAbsRgbDelta=1.588`
- `ChangedRatioGt10=0.015755`
- Baseline SHA-256:
  `B8F1AEC10FC57C159FC5324844B45016C1FB5C457BE3F59FB9D3399BDB4F656C`
- Candidate SHA-256:
  `8805C178D459883E67FF8E198D2A2B09A90DDBB76A5A566AF015B721EB1F3810`

## Candidate Technical Evidence

The parity patch was active:

- Candidate log contains `flags=0x0000002B`.
- Candidate log contains `invertAxis=(0,1)`.
- Candidate log contains `Native bridge API version: 21`.
- Candidate log contains `DLSS user rendering evaluate succeeded from native
  command-buffer EASU ctx.cmd`.
- Candidate log reports `input=960x540`, `output=1920x1080`,
  `sameDevice=yes`, `visibleOutput=yes`, `persistent=yes`,
  `sequenceCreates=1`, and repeated `evaluateSuccesses`.
- Candidate log reports `RenderGraph GetTexture call #=0`.
- Candidate log has no access-violation, `0xc0000005`, or `nvwgf2umx` evidence.

The candidate also kept native evaluate CPU wall time tiny in steady state:
late status lines showed native total/evaluate timings around `0.09-0.17 ms`,
so the persistent symptom remains low GPU utilization and worse frame time, not
a large CPU wall time in the NGX evaluate call itself.

## System Snapshot Result

Snapshot artifacts:

- `artifacts\system-snapshots\official-flags-paired-user-rendering-1080p-20260608-r2-baseline-loader.before.snapshot.json`
- `artifacts\system-snapshots\official-flags-paired-user-rendering-1080p-20260608-r2-baseline-loader.after.snapshot.json`
- `artifacts\system-snapshots\official-flags-paired-user-rendering-1080p-20260608-r2-user-rendering.before.snapshot.json`
- `artifacts\system-snapshots\official-flags-paired-user-rendering-1080p-20260608-r2-user-rendering.after.snapshot.json`

The snapshots reinforce the PresentMon signal: baseline was GPU-bound/high
power, while the candidate ran substantially lower GPU utilization and power.
They do not point to another GPU-heavy process as the explanation.

## Cleanup

Cleanup passed:

- `CrashEventCount=0` for both runs.
- No remaining `VRising` process.
- Release-safe native/config restored.
- BepInEx config restored.
- Client settings restored.
- V Rising FSR restored to `Off`.
- Protected save restore attempted and succeeded:
  `BeforeChangeCount=3`, `CompareStatus=Restored`, final `ChangeCount=0`.

After cleanup, `C:\Software\VRising\BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg`
was back to `DLSS.EnableDLSS=false` with dangerous probes disabled.

## Conclusion

Official-HDRP-like feature flags and invert-axis parity are worth keeping as
correctness alignment, but they are not the performance root cause. The
candidate still behaves like a pipeline/placement/synchronization problem:
DLSS evaluates successfully from the EASU `ctx.cmd` callback, but the frame runs
with much lower GPU utilization/power and worse frame time than the FSR-Off
baseline.

Do not rerun this same 1080p candidate shape unchanged. The next useful route is
to move from per-frame NGX parameter parity to boundary/lifecycle parity. A
first no-runtime preflight for that route is now implemented as
`hdrp-dlss-schedule-audit`; see
`docs/development/hdrp-dlss-schedule-audit-preflight-2026-06-08.md`.

- Run `hdrp-dlss-schedule-audit` to check whether the official
  `"Deep Learning Super Sampling"` RenderGraph pass is ever scheduled under
  current V Rising/HDRP state without native evaluate or broad
  `RenderGraph.GetTexture` discovery.
- Investigate an official-equivalent RenderGraph/DLSSData pass boundary that
  does not rely on the no-op built-in `DLSSPass.Render` body.
- Compare resource declarations and ordering around official `"DLSS
  destination"` versus the current EASU visible output.
- Add reset/history and resize lifecycle parity as a focused correctness patch,
  but do not expect it alone to fix steady-state FPS.
- Treat lower GPU utilization with worse FPS as the key symptom to explain.
