# DLSS Fallback Validation

This template is for a future playable-MVP validation record. Do not rename or
copy it to `docs/release/dlss-fallback-validation.md` until the evidence is
complete and intentional.

Validation Route: TBD

Game Version: TBD

Mod Build: TBD

Fallback Cases: TBD

Runtime Missing Behavior: TBD

Unsupported GPU Behavior: TBD

Resource Missing Behavior: TBD

Disable/Restore Behavior: TBD

User-Facing Status: TBD

Cleanup Evidence: TBD

Artifacts: TBD

Reviewer: TBD

Validation Date: TBD

## Notes

- The record must prove that failed DLSS prerequisites leave native rendering
  unchanged or restored.
- `Validation Route:` must describe real gameplay validation, not synthetic,
  dry-run, menu-only, startup-only, or paper-only evidence.
- The record must cover missing runtime, unsupported/no RTX path, and resource
  acquisition failure, unless a case is impossible on the tested machine and
  documented with a substitute proof.
- Runtime-missing, unsupported-GPU, resource-missing, and disable/restore
  behavior fields must not say `not tested`, `skipped`, `not run`, or
  `unverified`.
- The record must show user-facing status or log output that explains the
  fallback reason.
- `Artifacts:` must reference local paths under `artifacts/`.
- `Cleanup Evidence:` must prove process cleanup and restored/release-safe state.
- The record must not contain placeholders when used as the live validation
  file.
