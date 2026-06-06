# Pause State - 2026-06-05

Status: paused by user request after the current research/persistence round.

The system goal tracker still exposes only `active`, `complete`, and `blocked` states. It does not provide a tool-level `paused` state, so this file is the local project pause marker.

## Current Goal

Build a free, non-commercial, distributable V Rising DLSS Super Resolution mod package that can eventually be released through GitHub and the V Rising/Thunderstore mod ecosystem.

## Latest Durable State

- Diagnostic package is release-boundary clean, but the playable MVP is still blocked
  on visual/performance, resize/reset/fallback, productionization, and runtime
  distribution validation.
- The correct product-value comparison is V Rising `FsrQualityMode=Off` for both baseline and candidate.
- Built-in V Rising FSR Performance proved the expected `1920x1080 -> 3840x2160` tuple for 4K Performance-mode transition diagnostics, but it cannot satisfy the MVP gate.
- The mod-owned render-scale path under FSR Off has a passing constructive proof:
  v6 produced `960x540 -> 1920x1080` and repeated SDK-wrapper user-rendering
  evaluates.
- API 12 added the `dlss-optimal-settings` probe; as of 2026-06-06 it has passed actual local SDK-wrapper game-runtime validation in run `dlss-optimal-settings-20260606-115921`.
- Constructive runtime tests now default to `1920x1080` Windowed by temporarily writing `GraphicSettings.WindowMode=3` and restoring the user's `ClientSettings.json` afterward.
- First FSR Off render-scale gameplay run `fsr-off-render-scale-1080p-v1-20260606` proved automation and cleanup, but failed the MVP tuple proof: settings were forced to 50 percent while the gameplay camera/main targets stayed full-size. Do not repeat that run unchanged.
- Follow-up v2-v5 render-scale runs are negative evidence and should not be repeated
  unchanged. V6 `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606` is the
  current positive proof and is summarized in
  `docs/development/post-update-fraction-runtime-result-2026-06-06.md`.
- PureDark is reference-only. Borrow concepts, not code, binaries, ABI, package layout, or wording.
- No blind testing: every next runtime test needs a written question, expected evidence, pass/fail signal, and cleanup path.

## Resume Here

Recommended next step after resuming:

Read `docs/development/post-update-fraction-runtime-result-2026-06-06.md`, then
continue with visual correctness, performance, resize/reset, fallback, and release
boundary validation for the v6 render-scale/user-rendering route.

Do not start V Rising just to inspect behavior.
