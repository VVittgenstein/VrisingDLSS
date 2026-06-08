# DLSS Resize Reset Validation

This template is for a future playable-MVP validation record. Do not rename or
copy it to `docs/release/dlss-resize-reset-validation.md` until the evidence is
complete and intentional.

Validation Route: TBD

Game Version: TBD

Mod Build: TBD

Runtime Route: TBD

Test Matrix: TBD

Resolution Change Evidence: TBD

Camera/History Reset Evidence: TBD

Feature Recreate/Reuse Evidence: TBD

Cleanup Evidence: TBD

Artifacts: TBD

Reviewer: TBD

Validation Date: TBD

## Notes

- The record must prove resize or resolution change behavior, not just startup.
- `Validation Route:` must describe real gameplay validation, not synthetic,
  dry-run, menu-only, startup-only, or paper-only evidence.
- `Test Matrix:` and `Resolution Change Evidence:` must show an actual
  resolution/resize transition, such as two concrete `WIDTHxHEIGHT` entries.
- The record must prove camera/history reset behavior and feature lifecycle
  handling after the reset, not just first-frame `reset=1`.
- The record must point to local artifacts such as logs, screenshots, and
  cleanup/save-restore evidence.
- `Artifacts:` must reference local paths under `artifacts/`.
- `Cleanup Evidence:` must prove process cleanup and restored/release-safe state.
- The record must not contain placeholders when used as the live validation
  file.
