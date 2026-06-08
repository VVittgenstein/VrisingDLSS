# Doc Next-Recommendation Contract - 2026-06-08

Status: added a no-runtime guard against stale user-facing next-step guidance.

## Problem

The runtime and visual status scripts now correctly defer the known-regressed
`dlss-user-rendering` EASU `ctx.cmd` route, but the install/MVP docs could still
drift back toward telling a tester to rerun the same unchanged candidate as the
next proof.

That would waste a runtime pass and could hide the actual issue: clean DLSS
evaluate succeeded, but performance regressed with low GPU utilization, so the
next useful boundary is the protected
`hdrp-dlss-contract-bind-render-scale` proof.

## Guard

Script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-doc-next-recommendation-contract.ps1 -Json
```

The guard is read-only:

- `LaunchesGame=false`
- `ModifiesGameFiles=false`

It checks:

- the latest `dlss-user-rendering` visual gate is still blocked by regression
  evidence;
- the visual gate's recommendation points away from unchanged
  `dlss-user-rendering` and toward `hdrp-dlss-contract-bind-render-scale`;
- `docs\mvp.md` calls the current user-rendering route known-regressed;
- `docs\install.md` frames further `dlss-user-rendering` visual captures as
  intentional reproduction/investigation, not the main next proof;
- the stale phrase that directly made another user-rendering visual run the
  next validation is absent;
- durable context records this guard.

## Current Guidance

Do not rerun the same EASU `ctx.cmd` `dlss-user-rendering` candidate unchanged
as the next MVP proof. When Computer Use is available, run the protected
`hdrp-dlss-contract-bind-render-scale` gameplay proof at true `1920x1080`
Windowed with `-ProtectSave -SaveName 11111`, click Continue/`11111` once,
send no movement keys, restore the save to `ChangeCount=0`, and analyze the log
with `scripts\analyze-hdrp-dlss-schedule-audit.ps1`.
