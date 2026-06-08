# Phase 1 Gameplay Automation Coverage Guard - 2026-06-08

Status: added a repeatable no-runtime guard for the proven Phase 1 automatic
gameplay-entry route.

## Purpose

Phase 1 route A is already proven for the known local/private `11111` fixture:
the session harness can launch V Rising in true `1920x1080` Windowed mode,
Computer Use can click Continue exactly once, and cleanup restores the protected
save to `ChangeCount=0`.

This guard makes that evidence machine-checkable so future work does not regress
to semi-automatic assumptions or unsafe input fallback.

## Guard

Script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-phase1-gameplay-automation-coverage.ps1
```

Local full-evidence mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-phase1-gameplay-automation-coverage.ps1 -GamePath C:\Software\VRising -SaveName 11111 -Json
```

Both modes are read-only:

- `LaunchesGame=false`
- `ModifiesGameFiles=false`

## Checked Evidence

The CI-safe mode verifies that the durable Phase 1 documents and scripts still
record:

- automatic gameplay entry proven for the `11111` fixture;
- direct command-line auto-continue as weak/rejected for now;
- true `1920x1080` Windowed control through `WindowMode=3`;
- protected `SaveName 11111` session usage;
- one bounded Computer Use Continue click;
- save restore evidence ending at `ChangeCount=0`;
- Computer Use as a local validation-only tool, not part of the DLSS mod;
- deferral when Computer Use is closed, rather than fallback foreground input;
- no movement-key discipline for the protected fixture.

When `-GamePath` is provided, the guard also verifies:

- `C:\Software\VRising\VRising.exe` exists;
- `scripts\find-vrising-save-fixture.ps1 -SaveName 11111 -RequireOne` finds one
  usable local fixture without launching or modifying the game;
- `scripts\test-hdrp-dlss-contract-bind-stage.ps1` dry-runs the next protected
  runtime proof with `-ProtectSave`, `ClientWindowMode 3`, no SDK-wrapper native
  use, no launch, and a proof plan that requires Computer Use and disallows
  movement keys.

## Integration

GitHub Actions now runs the CI-safe guard before the runtime-distribution and
MVP safety semantic guards.

`scripts\get-release-readiness-status.ps1` now includes the guard as an
`Evidence` item. When readiness is run with `-GamePath C:\Software\VRising`, the
same item upgrades to local evidence with `LocalEvidenceStatus=Pass`,
`SaveFixtureStatus=Pass`, and `ContractBindStatus=Pass`.

## Local Result

On this pass:

```text
Status=Pass
Phase1Status=AutomaticGameplayEntryProvenFor11111
CheckCount=25
LocalEvidenceStatus=Pass
LaunchesGame=False
ModifiesGameFiles=False
```

This does not make the DLSS MVP ready. It only preserves the automation route and
the protected runtime-test entry protocol while the main DLSS boundary work
continues.
