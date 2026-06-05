# Pause State - 2026-06-05

Status: paused by user request after the current research/persistence round.

The system goal tracker still exposes only `active`, `complete`, and `blocked` states. It does not provide a tool-level `paused` state, so this file is the local project pause marker.

## Current Goal

Build a free, non-commercial, distributable V Rising DLSS Super Resolution mod package that can eventually be released through GitHub and the V Rising/Thunderstore mod ecosystem.

## Latest Durable State

- Diagnostic package is release-boundary clean, but the playable MVP is still blocked.
- The correct product-value comparison is V Rising `FsrQualityMode=Off` for both baseline and candidate.
- Built-in V Rising FSR Performance proved the expected `1920x1080 -> 3840x2160` tuple for 4K Performance-mode transition diagnostics, but it cannot satisfy the MVP gate.
- The mod-owned render-scale path under FSR Off is the missing proof.
- API 12 added the build-validated `dlss-optimal-settings` probe; it still needs actual game-runtime validation.
- PureDark is reference-only. Borrow concepts, not code, binaries, ABI, package layout, or wording.
- No blind testing: every next runtime test needs a written question, expected evidence, pass/fail signal, and cleanup path.

## Resume Here

Recommended next step after resuming:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage dlss-optimal-settings -UseSdkWrapperNative -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll" -DurationSeconds 60 -DryRun
```

If the dry run matches the intended stage, run the actual Stage 6B test only with the game-test protocol written down first. Do not start V Rising just to inspect behavior.

After Stage 6B, continue with `docs/development/fsr-off-render-scale-test-protocol-2026-06-05.md`.
