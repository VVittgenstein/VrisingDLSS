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
- API 12 added the `dlss-optimal-settings` probe; as of 2026-06-06 it has passed actual local SDK-wrapper game-runtime validation in run `dlss-optimal-settings-20260606-115921`.
- Constructive runtime tests now default to `1920x1080` Windowed by temporarily writing `GraphicSettings.WindowMode=3` and restoring the user's `ClientSettings.json` afterward.
- PureDark is reference-only. Borrow concepts, not code, binaries, ABI, package layout, or wording.
- No blind testing: every next runtime test needs a written question, expected evidence, pass/fail signal, and cleanup path.

## Resume Here

Recommended next step after resuming:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage dlss-user-rendering -UseSdkWrapperNative -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll" -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -DryRun
```

If the dry run matches the intended stage, continue with the FSR Off render-scale proof
only under `docs/development/fsr-off-render-scale-test-protocol-2026-06-05.md`.
For the default 1080P Windowed constructive proof, expect a Performance-mode tuple near
`960x540 -> 1920x1080`; reserve 4K/native-output performance comparison for the later
controlled final validation matrix.

Do not start V Rising just to inspect behavior.
