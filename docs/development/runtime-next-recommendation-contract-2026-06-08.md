# Runtime Next-Recommendation Contract - 2026-06-08

Status: updated the no-runtime guard so runtime guidance advances after the
contract-bind proof passes.

## Problem

`get-runtime-validation-status.ps1` correctly reported the historical
`DLSS User Rendering Candidate=Pass`, but its stage-level next recommendation
could still say the next engineering step was another paired
`dlss-user-rendering` visual/performance run.

That became stale after the latest normal-user visual/performance artifacts
showed severe FPS regression and low GPU utilization. The next stale state was
the inverse: after the protected `hdrp-dlss-contract-bind-render-scale` proof
passed, status still wanted to run contract-bind again. The current mainline is
not to rerun the same EASU `ctx.cmd` candidate unchanged and not to rerun
contract-bind unchanged; it is to move to bounded no-write B/C/D cost isolation.

## Change

`get-runtime-validation-status.ps1` now consults
`scripts\get-visual-validation-status.ps1 -RequiredCandidateStage dlss-user-rendering`
before returning the old user-rendering success recommendation. It also consults
`scripts\get-contract-bind-gameplay-proof.ps1`, which prefers local gameplay
artifacts plus schedule-analyzer evidence and falls back to the durable result
doc when ignored artifacts are absent.

If the visual gate is blocked by candidate FPS / frame-time regression and the
contract-bind proof is not present yet, runtime status still recommends the
protected contract-bind proof:

- do not rerun the same EASU `ctx.cmd` candidate unchanged;
- run the protected `hdrp-dlss-contract-bind-render-scale` proof;
- use Computer Use for the `11111` Continue click;
- send no movement keys;
- require save restore with `ChangeCount=0`.

If the contract-bind proof is present, runtime status advances to:

- bounded no-write B/C/D cost isolation;
- B: EASU carrier-only cost;
- C: native D3D11 resource-desc validate-only;
- D: empty existing command-buffer plugin-event callback;
- no visible DLSS write-back until B-G pass.

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
ContractBindGameplayProofStatus=Pass
RuntimeNextRecommendation=... bounded no-write cost proof ...
```

This does not add new runtime work by itself. It prevents the status system from
recommending a known-regressed route or a completed contract-bind proof after
the local/durable evidence has already advanced the route.
