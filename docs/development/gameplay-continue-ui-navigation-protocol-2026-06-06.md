# Gameplay Continue UI Navigation Protocol - 2026-06-06

Status: passed for the known local/private `11111` fixture under `1920x1080`
Windowed conditions.

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
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -ArtifactLabel automation-continue-click-windowed-v1-20260606 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -DryRun
```

Actual start:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -ArtifactLabel automation-continue-click-windowed-v1-20260606 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-automation-continue-click-windowed-v1-20260606.json"
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

## Continue Proof Contract

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

## Continue Activation Result

Run label: `automation-continue-click-windowed-v1-20260606`.

Preconditions:

- The target save folder was backed up first:
  `artifacts/gameplay-automation/SaveBackup-automation-continue-click-computeruse-v1-20260606.zip`.
- The session used `-SetClientResolution -SetClientWindowMode -ClientWindowMode 3`.
- A separate window-mode proof, `automation-windowmode3-1080p-v1-20260606`, showed
  `SetResolution 1920, 1080, fullScreenMode Windowed` and a `1920x1080` script-side
  screenshot.

Result:

- Start session: `Status=Ready`, `ScreenshotWidth=1920`, `ScreenshotHeight=1080`,
  `SetClientWindowMode=true`, and `ClientWindowMode=3`.
- Player log: `WindowMode=3` and `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Computer Use before screenshot: main menu with Continue / `11111`.
- Computer Use action: exactly one click at window-relative coordinate `(205, 354)`
  in the current `1283x751` screenshot, targeting the visible Continue label.
- 20-second follow-up: the menu was gone and the game was in loading/progress.
- 50-second follow-up: stable gameplay was visible, with character, HUD, hotbar,
  quest text, and minimap.
- Player log: game connect data found, local dedicated server process started, client
  connected to `SteamIPv4://127.0.0.1:9876`.
- Server log: loaded
  `CloudSaves/.../v4/f0e07524-03f4-4ef4-945c-b1f7e982071b/AutoSave_23.save.gz` and
  character `Helen` connected.
- Cleanup: `Status=Pass`, `CrashEventCount=0`, `RestoredClientSettings=true`,
  `RestoredLoaderConfig=true`, and `RemainingVRisingProcessCount=0`.

Conclusion:

- Automatic gameplay entry is proven for the local/private `11111` fixture.
- Future runtime tests should default to the session harness plus Computer Use to enter
  gameplay automatically, not to the semi-automatic human-ready protocol, unless this
  route regresses.

## Save Mutation Note

Entering gameplay triggered save rotation: `AutoSave_24.save.gz` was added and some
older autosaves were removed. The changed post-proof state was archived at
`artifacts/gameplay-automation/SaveAfterProof-automation-continue-click-windowed-v1-20260606.zip`.
The save was then restored from the pre-proof backup, and
`SaveCompareAfterRestore-automation-continue-click-windowed-v1-20260606.json`
reported `Status=Restored`, `BeforeFileCount=12`, `AfterFileCount=12`, and
`ChangeCount=0`.

Rule: any future automated gameplay-entry proof or runtime test against the `11111`
fixture must back up the save first and either restore it after the test or explicitly
record why the new save state should be retained.

## Resolution Note

`ClientSettings.json` does not normally persist `GraphicSettings.WindowMode`, but the
game dumps `WindowMode=1` and presents `FullScreenWindow` by default. Temporarily adding
`GraphicSettings.WindowMode=3` under the session harness makes V Rising report
`fullScreenMode Windowed` and produces a `1920x1080` script-side screenshot. The
original settings file is restored by the stop-session script.
