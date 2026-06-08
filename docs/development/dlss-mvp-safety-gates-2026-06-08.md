# DLSS MVP Safety Gates - 2026-06-08

Status: resize/reset and fallback gates are open MVP blockers. This pass did not
launch V Rising and did not modify game files.

## Purpose

`get-release-readiness-status.ps1` no longer treats normal-user safety as one
generic hard-coded blocker. It now delegates to:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-dlss-mvp-safety-gates.ps1 -Json
```

The validator checks future release records for:

- `docs/release/dlss-resize-reset-validation.md`
- `docs/release/dlss-fallback-validation.md`

Until those live records exist and pass marker/placeholder checks, readiness
reports both gates as `Blocked`.

## Required Evidence

Resize/reset validation must prove:

- resolution or resize behavior, not just startup;
- camera/history reset behavior after the first frame;
- DLSS feature recreate/reuse behavior after resize or reset;
- cleanup and protected-save recovery;
- exact artifacts such as logs, screenshots, and performance captures.

Fallback validation must prove:

- missing-runtime behavior;
- unsupported-GPU or no-DLSS-support behavior, or a documented substitute when
  the local machine cannot exercise that path;
- missing-resource behavior;
- disable/restore behavior that leaves native rendering unchanged or restored;
- user-facing status or logs explaining the fallback reason;
- cleanup and protected-save recovery.

Templates live at:

- `docs/release/dlss-resize-reset-validation.template.md`
- `docs/release/dlss-fallback-validation.template.md`

The templates intentionally contain `TBD`, so they fail the validator when used
as live validation records.
