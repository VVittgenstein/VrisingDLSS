# Experiment Evidence-Lock Contract - 2026-06-08

Status: added a no-runtime guard for stopped routes and the next cost matrix.

## Problem

Recent evidence and the user-provided `5.4`/`5.5` plans agree that the project
should not keep rediscovering the same rejected runtime paths. The next runtime
work must stay split into small layers: carrier, native validation, plugin
event, NGX create, scratch evaluate, controlled copy, visible write, then 4K
value proof.

## Artifact

Machine-readable facts live in:

```powershell
docs\development\experiment-facts.json
```

They record:

- evidence locks for rejected or known-regressed routes;
- the allowed evidence needed to challenge each lock;
- the A-I boundary cost matrix;
- near-baseline thresholds for no-write/no-evaluate layers;
- the rule that visible write requires prior B-G layers to pass.

## Guard

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-experiment-evidence-lock-contract.ps1 -Json
```

The guard is read-only:

- `LaunchesGame=false`
- `ModifiesGameFiles=false`

This does not replace runtime proof. It keeps the next runtime proof disciplined
so the project does not rerun broad `GetTexture`, cached-driver evaluate,
inert-DLSSPass activation, mod-owned RenderGraph production, unchanged
`dlss-user-rendering`, or visible write without scratch/no-write layers.
