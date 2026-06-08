# Doc Next-Recommendation Contract - 2026-06-08

Status: updated the no-runtime guard against stale user-facing next-step
guidance after the contract-bind proof passed.

## Problem

The runtime and visual status scripts now correctly defer the known-regressed
`dlss-user-rendering` EASU `ctx.cmd` route, but the install/MVP docs could still
drift back toward telling a tester to rerun the same unchanged candidate as the
next proof.

That would waste a runtime pass and could hide the actual issue: clean DLSS
evaluate succeeded, but performance regressed with low GPU utilization. After
the protected `hdrp-dlss-contract-bind-render-scale` proof passed, stale docs
could also waste the next runtime pass by asking for the same contract-bind run
again. The current useful boundary is bounded no-write B/C/D cost isolation.

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
  `dlss-user-rendering`, toward `hdrp-dlss-contract-bind-render-scale` only
  until that proof exists, and toward bounded no-write B/C/D after it passes;
- `docs\mvp.md` calls the current user-rendering route known-regressed;
- `docs\install.md` frames further `dlss-user-rendering` visual captures as
  intentional reproduction/investigation, not the main next proof;
- `docs\development\hdrp-dlss-contract-bind-render-scale-gameplay-result-2026-06-08.md`
  contains machine-readable proof markers for no-artifact/CI status;
- the stale phrase that directly made another user-rendering visual run the
  next validation is absent;
- durable context records this guard.

## Current Guidance

Do not rerun the same EASU `ctx.cmd` `dlss-user-rendering` candidate unchanged
as the next MVP proof. The protected `hdrp-dlss-contract-bind-render-scale`
proof has passed with `SaveAfterRestoreChangeCount=0`,
`RenderGraphGetTextureCalls=0`, `UserRenderingCandidateStarted=0`,
`DlssEvaluateSucceeded=0`, and
`EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved=true`.

The next runtime proof is bounded no-write B/C/D cost isolation under the same
true `1920x1080` Windowed protected `11111` fixture:

- B: EASU carrier-only cost.
- C: native D3D11 resource-desc validate-only.
- D: empty existing command-buffer plugin-event callback.
