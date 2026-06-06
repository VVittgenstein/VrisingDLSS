# Computer Use Notes for V Rising Automation - 2026-06-06

Status: active Phase 1 operating note.

Purpose: preserve the working Computer Use route and the pitfalls found while using it
to observe V Rising. This note is specifically for local V Rising gameplay-entry
automation, not for DLSS runtime validation by itself.

Product boundary: Computer Use has no relationship to the DLSS mod implementation. It
is only a local Codex-side automation/testing tool for entering and observing the game
during validation. It is not a mod feature, not a runtime dependency, and must not be
included in the GitHub/Thunderstore release package.

## Recommended Workflow

1. Use PowerShell scripts only for non-UI setup and cleanup:
   - `scripts\start-vrising-automation-session.ps1`
   - `scripts\stop-vrising-automation-session.ps1`
2. Use Computer Use for game-window observation and UI input.
3. Always start with `list_apps` and match the process-backed app:
   - expected id: `process:C:\Software\VRising\VRising.exe`
   - expected display name: `VRising`
4. Select the real game window by title:
   - use window title `VRising`
   - do not select `BepInEx ... - VRising`
5. Rehydrate the selected window before observing:
   - call `get_window` on the returned window object
   - activate the selected game window when the proof needs foreground input
   - call `get_window_state`
   - carry forward the returned `state.window` for later actions
6. For game menus, expect weak accessibility data. Use screenshots and stable
   window-relative coordinates or simple key input, but only after a screenshot proves
   the current state.
7. After every observation or UI action, run the stop-session script and verify:
   - `Status=Pass`
   - `CrashEventCount=0`
   - `RestoredClientSettings=true` when resolution was changed
   - `RestoredLoaderConfig=true`
   - `RemainingVRisingProcessCount=0`
8. For the preferred constructive test shape, start sessions with:
   - `-SetClientResolution`
   - `-SetClientWindowMode -ClientWindowMode 3`
   This makes the player log report `fullScreenMode Windowed` and keeps the
   script-side screenshot at `1920x1080`.
9. Before entering the `11111` save, back up its save directory. Gameplay entry can
   rotate autosaves even if no further input is sent.
10. For DLSS runtime gameplay sessions, use the session harness' diagnostic stage
    parameters rather than hand-editing config/native DLL state:
    - `-Stage dlss-user-rendering`
    - `-UseSdkWrapperNative`
    - `-DlssRuntimePath <local nvngx_dlss.dll>`
    The stop-session script restores the release-safe native DLL and loader config.

## Safety Boundary

PowerShell launch/cleanup and Computer Use UI control can coexist in one proof only if
their responsibilities stay separate:

- PowerShell: install local package, write loader config, temporarily edit
  `ClientSettings.json`, start V Rising, capture script-side logs/screenshots, stop the
  process, restore settings/config, archive WER.
- Computer Use: choose the visible app/window, snapshot the window, click/press keys
  when a written protocol allows it.

Do not mix PowerShell/Win32 `SendInput` and Computer Use input in the same V Rising UI
proof. Previous Win32 input proof remains valid evidence, but future multi-step menu
navigation should use Computer Use unless a separate protocol explicitly chooses the
Win32 route.

## Observation Proof

Run label: `automation-session-continue-computeruse-20260606`.

Artifacts:

- Session JSON:
  `artifacts/gameplay-automation/Session-automation-session-continue-computeruse-20260606.json`
- Cleanup JSON:
  `artifacts/gameplay-automation/Cleanup-automation-session-continue-computeruse-20260606.json`
- Computer Use observation JSON:
  `artifacts/gameplay-automation/ComputerUseObservation-automation-session-continue-computeruse-20260606.json`
- Computer Use screenshot:
  `artifacts/gameplay-automation/ComputerUseScreenshot-automation-session-continue-computeruse-20260606.jpg`

Result:

- Computer Use found exactly one V Rising app match.
- The app exposed two windows:
  - `VRising`
  - `BepInEx 6.0.0-dev+... - VRising`
- The real game window was `VRising`.
- The captured main menu showed the Chinese Continue entry with save name `11111`.
- Cleanup passed and left no game process.

## Continue Proof

Run label: `automation-continue-click-windowed-v1-20260606`.

Result:

- The session used `GraphicSettings.WindowMode=3` and `1920x1080`.
- Computer Use captured the main menu, clicked the visible Continue label exactly once
  at `(205, 354)` in the `1283x751` screenshot, and then observed gameplay.
- The 50-second follow-up screenshot showed stable gameplay with character, HUD,
  hotbar, quest text, and minimap.
- Player/server logs confirmed local server startup, save load, and character `Helen`
  connection.
- Cleanup passed with no crash and no remaining V Rising process.

This proves automatic gameplay entry for the local/private `11111` fixture. Computer
Use remains a local validation tool only; it is not part of the DLSS mod.

## DLSS Runtime Gameplay Proof

Run label: `fsr-off-render-scale-1080p-v1-20260606`.

Result:

- The session harness started V Rising with `Stage=dlss-user-rendering`,
  SDK-wrapper native DLL, `GraphicSettings.WindowMode=3`, and `1920x1080`.
- Computer Use selected the real `VRising` game window, clicked the visible Chinese
  Continue label once at `(205, 354)` in the current `1283x751` screenshot, and
  reached gameplay.
- Stop-session cleanup passed with `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The technical DLSS result was partial/failed for the MVP proof: render-scale settings
  changed to 50 percent, but the main candidate stayed `1920x1080 -> 1920x1080`.
- The user accidentally pressed `W` during the run. The save was restored from the
  pre-run backup; `SaveCompareAfterRestore-fsr-off-render-scale-1080p-v1-20260606.json`
  reports `Status=Restored` and `ChangeCount=0`.

## Pitfalls Found

- Current role: Computer Use is the best proven direction for entering and observing
  the local/private `11111` gameplay fixture from Codex. It is not part of the DLSS
  mod, not related to DLSS runtime selection, and must not be treated as a user-facing
  feature or package dependency.
- `Process.MainWindowHandle` and app-window lists can point at the BepInEx console.
  Always enumerate/select the real Unity/game window, not the console.
- V Rising may report `SetResolution 1920, 1080, fullScreenMode FullScreenWindow`
  while the captured surface is desktop-sized. This is acceptable for menu automation
  but does not prove true `1920x1080` windowed mode.
- Different capture paths report different dimensions:
  - script-side `ScreenCopy` observed `3840x2160` in the session artifact;
  - Computer Use observed a `2560x1440` logical screenshot.
  Treat coordinates as belonging to the current Computer Use screenshot, not to the
  script-side PNG or physical monitor size.
- After `WindowMode=3`, the script-side screenshot can be `1920x1080` while Computer
  Use sees a smaller decorated/logical window screenshot such as `1283x751`. Continue
  click coordinates still belong to the Computer Use screenshot.
- Black/near-black startup frames are common. A visible window is not enough; wait for
  a nonblank screenshot before assuming the UI is ready.
- The main menu was localized in Chinese. The target Continue entry is the Chinese
  Continue label with `11111` beneath it.
- Do not attempt direct client command-line auto-continue guesses in this loop. The
  stronger current path is the observed Continue menu.
- Do not leave a `Status=Ready` session open without running the stop script. The start
  script intentionally leaves `CleanupRequired=true`.
- Do not assume gameplay entry leaves the local save untouched. The first successful
  Continue proof created `AutoSave_24.save.gz` and rotated older autosaves. The save
  was restored from the pre-proof backup; future tests need the same backup/restore
  discipline.

## HWDRS Render-Scale Follow-up

Run label: `fsr-off-render-scale-1080p-hwdrs-v2-20260606`.

Result:

- The session harness again started V Rising with `Stage=dlss-user-rendering`,
  SDK-wrapper native DLL, `GraphicSettings.WindowMode=3`, and `1920x1080`.
- Computer Use selected the real `VRising` game window, clicked the visible Chinese
  Continue label once at `(205, 354)` in the `1283x751` screenshot, observed loading
  after 20 seconds, and observed stable gameplay after about 65 seconds.
- No movement or gameplay keys were sent.
- Stop-session cleanup passed with `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The technical DLSS result still failed the MVP tuple proof: the targeted diagnostic
  logged `RTHandles.SetHardwareDynamicResolutionState=true`, but
  `UnityEngine.Camera.allowDynamicResolution` writes did not stick and main candidates
  remained `1920x1080 -> 1920x1080`.
- The `11111` save changed during gameplay entry, was archived, and was restored from
  backup; corrected comparison reports `Status=Restored` and `ChangeCount=0`.

## Handler-Request Render-Scale Follow-up

Run label: `fsr-off-render-scale-1080p-handler-request-v3-20260606`.

Result:

- The same automation route still worked after the handler-request render-scale patch.
- Start-session used `Stage=dlss-user-rendering`, SDK-wrapper native DLL,
  `GraphicSettings.WindowMode=3`, and `1920x1080` Windowed setup.
- Computer Use selected the real `VRising` game window, clicked Continue once at the
  known `(205, 354)` coordinate in the current `1283x751` screenshot, observed loading
  after 20 seconds, and observed stable gameplay with HUD/character after 55 seconds.
- No movement or gameplay keys were sent.
- Stop-session cleanup passed with `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The `11111` save changed during gameplay entry (`ChangeCount=6` before restore),
  was archived, and was restored from the pre-run backup with `ChangeCount=0`.
- Product boundary remains unchanged: Computer Use is a local Codex validation tool
  only, not a DLSS mod dependency or release artifact.

## Direct Handler-Request Render-Scale Follow-up

Run label: `fsr-off-render-scale-1080p-handler-request-v4-20260606`.

Result:

- The same Computer Use route again selected the real `VRising` window, clicked
  Continue once at the known `11111` menu entry, observed loading after 20 seconds,
  and observed stable gameplay after 60 seconds.
- Start-session used `Stage=dlss-user-rendering`, SDK-wrapper native DLL,
  `GraphicSettings.WindowMode=3`, and `1920x1080` Windowed setup.
- No movement or gameplay keys were sent by automation.
- Stop-session cleanup passed with `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The `11111` save changed during gameplay entry (`ChangeCount=6` before restore),
  was archived, and was restored from the pre-run backup with `ChangeCount=0`.
- Technical result: direct handler request was proven true/successful, but the main
  DLSS tuple still stayed full-size. The next technical run is software fallback, not
  another identical handler-request run.

## Software-Fallback Render-Scale Follow-up

Run label: `fsr-off-render-scale-1080p-software-fallback-v5-20260606`.

Result:

- The same Computer Use route selected the real `VRising` window, clicked Continue
  once at the known `11111` menu entry, and reached stable gameplay.
- Start-session used `Stage=dlss-user-rendering`, SDK-wrapper native DLL,
  `GraphicSettings.WindowMode=3`, and `1920x1080` Windowed setup.
- No movement or gameplay keys were sent by automation.
- One follow-up observation returned a stale/crossed window capture rather than the
  real game foreground. No input was sent while the capture was ambiguous. The fix was
  to run `list_apps` again, select `process:C:\Software\VRising\VRising.exe`, rehydrate
  the `VRising` window, then capture a fresh screenshot.
- Stop-session cleanup passed with `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The `11111` save changed during gameplay entry, was archived, and was restored from
  the pre-run backup with `ChangeCount=0`.
- Technical result: `ForceSoftwareFallback()` worked, but `GetCurrentScale` and
  `GetResolvedScale` stayed `1.0`; the main DLSS tuple remained full-size.

## Post-Update Fraction Render-Scale Follow-up

Run label: `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606`.

Result:

- The same Computer Use route again selected the real `VRising` window, clicked
  Continue once at the known `11111` menu entry, observed loading after about
  20 seconds, and observed stable gameplay after about 65 seconds.
- Start-session used `Stage=dlss-user-rendering`, SDK-wrapper native DLL,
  `GraphicSettings.WindowMode=3`, and `1920x1080` Windowed setup.
- No movement or gameplay keys were sent by automation.
- Stop-session cleanup passed with `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The `11111` save changed during gameplay entry, was archived, and was restored from
  the pre-run backup with `ChangeCount=0`.
- Technical result: v6 passed the FSR Off tuple proof. The main camera/resources
  switched to `960x540`, Stage 8E accepted `960x540 -> 1920x1080`, and
  `DLSS user rendering evaluate succeeded` reached repeated SDK-wrapper successes.

## Next Click Protocol Notes

For future Continue activations:

- Start a fresh session with a new artifact label.
- Use `-SetClientResolution -SetClientWindowMode -ClientWindowMode 3`.
- Back up the `11111` save folder first.
- Reacquire the `VRising` window through Computer Use.
- Capture the main menu screenshot and record the screenshot dimensions.
- Use only one intended action:
  - preferred: click a stable point inside the visible Chinese Continue label area
    from the current Computer Use screenshot;
  - alternative: keyboard activation only if focus/selection evidence is clear.
- Take one follow-up screenshot after a short wait.
- Classify the result as loading/progress, no-op, wrong menu, crash, or cleanup failure.
- Always run the stop-session script after classification.
- Compare the save directory to the backup and restore it unless the test explicitly
  needs to retain the new save state.
