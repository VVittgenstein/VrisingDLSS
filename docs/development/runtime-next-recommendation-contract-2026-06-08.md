# Runtime Next-Recommendation Contract - 2026-06-08

Status: added a no-runtime guard against stale runtime guidance.

## Problem

`get-runtime-validation-status.ps1` correctly reported the historical
`DLSS User Rendering Candidate=Pass`, but its stage-level next recommendation
could still say the next engineering step was another paired
`dlss-user-rendering` visual/performance run.

That became stale after the latest normal-user visual/performance artifacts
showed severe FPS regression and low GPU utilization. The current mainline is
not to rerun the same EASU `ctx.cmd` candidate unchanged; it is to bind
source/output plus depth/motion evidence through the protected
`hdrp-dlss-contract-bind-render-scale` proof.

## Change

`get-runtime-validation-status.ps1` now consults
`scripts\get-visual-validation-status.ps1 -RequiredCandidateStage dlss-user-rendering`
before returning the old user-rendering success recommendation. If the visual
gate is blocked by candidate FPS / frame-time regression, runtime status reuses
the visual gate's stronger recommendation:

- do not rerun the same EASU `ctx.cmd` candidate unchanged;
- run the protected `hdrp-dlss-contract-bind-render-scale` proof;
- use Computer Use for the `11111` Continue click;
- send no movement keys;
- require save restore with `ChangeCount=0`.

## Guard

Script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-runtime-next-recommendation-contract.ps1
```

Local full-evidence mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-runtime-next-recommendation-contract.ps1 -GamePath C:\Software\VRising -Json
```

Both modes are read-only:

- `LaunchesGame=false`
- `ModifiesGameFiles=false`

On this pass, local full-evidence mode reported:

```text
Status=Pass
VisualPerformanceRegressionEvidence=True
CheckCount=6
RuntimeNextRecommendation=Do not rerun the same EASU ctx.cmd ...
```

This does not add new runtime proof. It prevents the status system from
recommending a known-regressed route after the visual/performance gate has
already explained why the route is blocked.
