# Gameplay Continue UI Navigation Protocol - 2026-06-06

Status: in progress. The observation-only Computer Use session passed; the next step is
the first bounded `Continue` navigation proof.

## Question

Can Codex automatically move from a controlled V Rising launch to the local/private
`Continue` flow for the known save `11111` without human input, while preserving a
reliable cleanup path?

## Hypothesis

The existing launch/window/screenshot helpers can prepare a safe no-DLSS session, and
Computer Use can select the real `VRising` Unity window instead of the BepInEx console.
Because the main menu exposes `Continue` with `11111`, a small follow-up can attempt a
single Continue activation and then use screenshots/logs to classify progress.

## Session Harness

Dry run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -ArtifactLabel automation-session-continue-computeruse-20260606 -SetClientResolution -DryRun
```

Actual start:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -ArtifactLabel automation-session-continue-computeruse-20260606 -SetClientResolution
```

Cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-automation-session-continue-computeruse-20260606.json"
```

The start script intentionally leaves V Rising running only when `Status=Ready` and
`CleanupRequired=true`. The stop script is mandatory after any observation or UI action.

## Observation-Only Result

The observation run `automation-session-continue-computeruse-20260606` passed:

- Start session: `Status=Ready`, `VisibilityStatus=VisibleGameWindow`,
  `ScreenshotAccepted=true`, and `RemainingVRisingProcessCount=1`.
- Player log: `SetResolution 1920, 1080, fullScreenMode FullScreenWindow`.
- Computer Use app selection: exactly one app match,
  `process:C:\Software\VRising\VRising.exe`.
- Computer Use window selection: real game window title `VRising`, not the BepInEx
  console.
- Computer Use screenshot: persisted at
  `artifacts/gameplay-automation/ComputerUseScreenshot-automation-session-continue-computeruse-20260606.jpg`.
- Visible menu evidence: the Chinese main menu shows the Continue entry with save
  name `11111`, plus Start, Load, Movies, Options, and Exit entries.
- Cleanup: `Status=Pass`, `CrashEventCount=0`, `RestoredClientSettings=true`,
  `RestoredLoaderConfig=true`, and `RemainingVRisingProcessCount=0`.

This confirms the user's recollection that the local game named with many `1`
characters is the active Continue target.

## Next Continue Proof

Question: can one bounded Computer Use action activate Continue for `11111` and reach a
loading or gameplay-progress state?

Expected evidence:

- Start session reaches `Status=Ready`.
- Computer Use selects `VRising` and captures the main menu with `11111`.
- Exactly one Continue activation is attempted, preferably by stable coordinate on the
  visible Chinese Continue label or by keyboard if a focus state can be proven.
- Follow-up screenshot changes away from the unchanged main menu, or logs show local
  server/save progress.
- Stop session reports `Status=Pass`, `CrashEventCount=0`, and no remaining process.

Pass signal:

- A loading/gameplay-progress screenshot or log-state transition is recorded, cleanup
  passes, and the action attempted no unrelated menu choices.

Fail signal:

- Computer Use cannot reacquire the real game window, the click/key does not change
  state, an unrelated menu opens, a crash event appears, or cleanup fails.

Cleanup path:

- Always run `scripts\stop-vrising-automation-session.ps1` with the active session JSON.
- If the game reaches gameplay or local server startup, still close the client through
  the stop script; do not save/alter the local fixture further in the same proof.

## Resolution Note

This route does not require a true `1920x1080` standalone window. The current evidence
supports the user's suspicion that the game is effectively using a fullscreen-window
presentation mode: launch options and `ClientSettings.json` make `Player.log` report
`1920x1080`, but capture surfaces may remain desktop-sized. Treat that as acceptable
for menu automation, while keeping true windowed mode open as a separate blocker.
