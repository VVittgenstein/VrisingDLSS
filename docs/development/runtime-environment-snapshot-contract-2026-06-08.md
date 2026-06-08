# Runtime Environment Snapshot Contract - 2026-06-08

Status: implemented as a no-runtime guard. It does not launch V Rising and does
not modify game files.

## Purpose

The current DLSS candidate can evaluate successfully, but paired gameplay runs
show FPS loss with low GPU utilization and lower GPU power. Future performance
comparisons need enough environment context to tell candidate regressions apart
from machine-state drift, thermal limits, unrelated heavy processes, or missing
GPU-bound load.

`scripts\test-runtime-environment-snapshot-contract.ps1` makes that evidence
shape explicit.

## Guarded Behavior

The guard verifies:

- `scripts\capture-system-snapshot.ps1` dry-run is no-launch;
- a short system snapshot writes JSON without launching the game;
- the snapshot includes CPU, memory, GPU, GPU utilization, GPU power, GPU
  temperature, and bounded top CPU/memory process lists;
- `scripts\capture-vrising-fps.ps1 -DryRun` enables system metrics and
  before/after system snapshots by default;
- `scripts\run-vrising-visual-comparison.ps1` routes performance capture through
  `capture-vrising-fps.ps1` and does not disable snapshots.

The guard is hardware tolerant for CI: machines without `nvidia-smi` may report
`Gpu.Available=false`, but the GPU object and expected fields must still exist.
On the local NVIDIA machine the smoke snapshot also records utilization, power,
temperature, clocks, VRAM, and GPU process context.

## Runtime Implication

Future paired visual/performance runs and the later GPU-bound matrix should
preserve:

- PresentMon frame metrics;
- per-interval process/GPU metrics CSV;
- before/after `artifacts/system-snapshots/*.snapshot.json` files for baseline
  and candidate;
- summary docs that compare FPS/frametime with GPU utilization, power,
  temperature, VRAM, and notable competing processes.

This does not make the current `dlss-user-rendering` route acceptable. It only
prevents future runtime evidence from losing the environmental context needed to
diagnose low-GPU-utilization regressions.
