# Bounded No-Write Cost Matrix Contract - 2026-06-08

## Question

After the protected `hdrp-dlss-contract-bind-render-scale` gameplay proof, which
official-equivalent no-write layer first explains the known low-GPU-utilization
`dlss-user-rendering` performance regression?

## Why this guard exists

The contract-bind run is a functional boundary proof, not a cost proof. It
intentionally enabled several RenderGraph metadata probes so the analyzer could
bind HDRP depth/motion evidence to the engine-owned `Uber -> EASU -> FinalPass`
chain. Reusing that same heavy stage as B would blur the cost question.

The new guard makes the next runtime work explicit and machine-readable:

- B must be a lighter EASU carrier-only stage.
- C must validate the native D3D11 descriptor shape without NGX/evaluate.
- D must issue the existing command-buffer plugin event with no DLSS evaluate
  and no visible write-back.

## Guarded stage mapping

`scripts/test-bounded-no-write-cost-matrix-contract.ps1` now maps the first
three no-write matrix layers to concrete stages:

| Layer | Matrix id | Stage | Boundary |
| --- | --- | --- | --- |
| A | baseline | `baseline-fsr-off` | Same fixture baseline with PresentMon, GPU/process metrics, and before/after system snapshots. |
| B | `easu-carrier-only-cost` | `easu-carrier-only-cost-render-scale` | No native bridge, no NGX, no evaluate, no visible write, no broad `RenderGraph.GetTexture`; uses focused RenderGraph pass-data plus HDRP postprocess/global texture and render-scale evidence. |
| C | `native-desc-validate-only` | `native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale` | Native same-device D3D11 resource descriptor validation only; no NGX runtime, no feature create, no evaluate, no visible write. |
| D | `empty-plugin-event-callback` | `native-renderfunc-commandbuffer-event-render-scale` | Existing EASU `ctx.cmd` command-buffer plugin-event callback only; no DLSS runtime/evaluate and no visible write. |

## Evidence

Local guard result on 2026-06-08:

- Command:
  `scripts/test-bounded-no-write-cost-matrix-contract.ps1 -GamePath C:\Software\VRising -Json`
- Status: `Pass`
- Launches game: `False`
- Modifies game files: `False`
- Contract-bind gameplay proof status: `Pass`
- Stage count: `3`
- Check count: `203`
- B: `UsesNativeBridge=False`, `EnablesDlssRuntime=False`,
  `EnablesDlssEvaluate=False`, `EnablesVisibleWrite=False`,
  `EnablesBroadGetTexture=False`
- C/D: native boundary enabled, but `EnablesDlssRuntime=False`,
  `EnablesDlssEvaluate=False`, `EnablesVisibleWrite=False`,
  `EnablesBroadGetTexture=False`
- With local `GamePath`, all three session dry-runs preserve:
  `LaunchesGame=False`, `UseSdkWrapperNative=False`, `ProtectSave=True`,
  `RestoresProtectedSave=True`, `SaveFixtureMatchCount=1`, and
  `ClientWindowMode=3`.

## Runtime plan

Do not rerun unchanged `dlss-user-rendering` or unchanged contract-bind next.
The next real runtime loop should use true `1920x1080` Windowed, V Rising FSR
Off, protected `SaveName=11111`, and Computer Use to click Continue once with no
movement keys.

For each B/C/D layer:

- capture a same-fixture baseline with PresentMon frame metrics;
- capture GPU/process metrics and before/after system snapshots;
- stop through `scripts/stop-vrising-automation-session.ps1`;
- require `SaveRestored=True`, `SaveAfterRestoreChangeCount=0`, and
  `RemainingVRisingProcessCount=0`;
- preserve logs, cleanup JSON, FPS CSV/summaries, metrics CSV, snapshots, and
  any screenshots.

Pass criteria:

- average FPS ratio >= `0.98` versus same-run baseline;
- P95 frame-time delta <= `0.5 ms`;
- P99 frame-time delta <= `1.0 ms`;
- no GPU utilization or power collapse;
- no NGX/DLSS runtime load, feature create, evaluate, visible write-back,
  broad `RenderGraph.GetTexture` loop, crash, or save drift.

Fail criteria:

- any B/C/D layer reproduces the low-GPU-utilization collapse;
- any DLSS runtime/evaluate/visible-write signal appears before B/C/D pass;
- Computer Use unavailable before launch;
- save restore failure, crash/WER, or residual V Rising process.

## Current status

The contract is now enforced by:

- `scripts/test-bounded-no-write-cost-matrix-contract.ps1`
- `scripts/get-release-readiness-status.ps1`
- `.github/workflows/build-package.yml`

This is still a no-runtime guard. It prepares the next runtime loop; it does not
yet prove that B/C/D are cheap in gameplay.
