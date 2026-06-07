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

## V6 Visual/Performance Follow-up

Run label: `v6-user-rendering-1080p-auto-visual-20260606-r2`.

Result:

- The visual helper temporarily forced `GraphicSettings.WindowMode=3` and
  `1920x1080`, then restored `ClientSettings.json` during cleanup.
- Computer Use selected the real `VRising` window for both baseline and candidate,
  clicked the known `11111` Continue entry once per run at `(205, 354)` in the current
  `1283x751` screenshot, and sent no movement/gameplay keys.
- The baseline and candidate both reached stable gameplay and produced valid
  `1920x1080` screenshots.
- The candidate reached repeated `DLSS user rendering evaluate succeeded` lines.
- Cleanup restored FSR mode, loader config, release-safe native DLL, client settings,
  and the `11111` save (`ChangeCount=0` after restore).
- Technical result: visual capture/evaluate succeeded, but performance failed badly.
  The candidate regressed from `203.617` to `80.242` average FPS and GPU utilization
  dropped from `97.5%` to `43.444%`. Treat this as a DLSS placement/timing blocker,
  not an automation failure.

## V6 Timing Follow-up

Run label: `v6-user-rendering-1080p-timing-20260606-r3`.

Result:

- The same Computer Use route selected the real `VRising` window for both baseline
  and candidate, clicked the known `11111` Continue entry once per run, and sent no
  movement/gameplay keys.
- Both runs reached stable gameplay and produced valid `1920x1080` screenshots.
- Cleanup restored FSR mode, loader config, release-safe native DLL, client settings,
  and the `11111` save (`ChangeCount=0` after restore).
- Technical result: timing fields were collected. Stable native DLSS evaluate CPU wall
  time was about `0.08-0.11 ms`, so the ongoing FPS regression is not explained by the
  direct NGX evaluate call itself.

## Render-Scale-Only Performance Follow-up

Run label: `render-scale-only-1080p-20260606-r1`.

Result:

- The same Computer Use route selected the real `VRising` window for both baseline and
  candidate, clicked the known `11111` Continue entry once per run at `(205, 354)` in
  the current `1283x751` screenshot, and sent no movement/gameplay keys.
- Both runs reached stable gameplay and produced valid `1920x1080` script-side
  screenshots.
- Candidate stage was `render-scale-control`, so no SDK-wrapper native DLL or
  `nvngx_dlss.dll` was required.
- Cleanup restored FSR mode, loader config, release-safe native DLL, client settings,
  and the `11111` save (`ChangeCount=0` after restore).
- Technical result: render-scale-only did not reproduce the FPS collapse. Average FPS
  stayed essentially flat (`204.419 -> 205.410`) while GPU utilization/power dropped
  (`98.222%/135.571 W -> 65.556%/95.183 W`), consistent with lower internal rendering
  cost rather than a render-scale blocker.

## No-Evaluate Performance Follow-up

Run labels:

- `user-rendering-no-evaluate-1080p-20260606-r1`
- `user-rendering-no-evaluate-1080p-20260606-r2`
- `user-rendering-no-evaluate-1080p-20260606-r3`
- `user-rendering-no-evaluate-1080p-20260606-r4`

Result:

- The visual-comparison helper again used the true `1920x1080` Windowed harness and
  protected the local/private `11111` save.
- Computer Use selected the real `VRising` window for baseline and candidate runs,
  clicked the known Continue entry once per run at `(205, 354)` in the current
  `1283x751` screenshot, and sent no movement/gameplay keys.
- One r3 activation briefly surfaced another foreground window; the fix was to
  reselect the real `VRising` process/window before clicking. Do not click when the
  capture is ambiguous or shows the BepInEx console.
- One r4 baseline `get_window_state` returned a selected `VRising` target while the
  screenshot still showed the Codex/browser surface. The safe fix was to cross-check
  with the script-side visibility probe/screenshot before sending input. Treat
  Computer Use window selection as untrusted until the current screenshot itself shows
  the intended game window.
- During the r4 candidate phase, a coordinate click returned `window changed; call
  get_window_state before issuing coordinate input`. Reacquiring `VRising` and
  refreshing `get_window_state` produced the correct menu screenshot, then the single
  Continue click was safe.
- The visual-comparison helper removes its ready-file marker at the start of each
  run. If using an out-of-band ready marker or manual coordination, recreate it for
  the candidate phase instead of assuming the baseline marker persists.
- Cleanup restored FSR mode, loader config, release-safe native DLL state, client
  settings, and the `11111` save (`ChangeCount=0` after restore for each run).
- Technical result: no-evaluate reproduced the FPS collapse without native DLSS
  evaluate. Logging suppression, tuple/reflection caching, and resource-name-first
  filtering improved candidate FPS from roughly `97` to `120`, but did not restore the
  roughly `194-203` FPS baseline. This points away from Computer Use or save/state
  handling and toward the hot global RenderGraph hook placement.

Pitfall:

- When calling `scripts\protect-vrising-save.ps1` through nested PowerShell, quote
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\...` paths. An unquoted
  `Stunlock Studios` segment is split and causes `Resolve-Path` to fail before the
  restore does any work. The corrected recovery command used `-ExecutionPolicy Bypass`
  plus single-quoted `-SaveDir` and `-ReferenceDir` values.

## Materialization-Only No-Evaluate Follow-up

Run label: `materialization-only-no-evaluate-1080p-20260606-r1`.

Result:

- The same `1920x1080` Windowed harness and Computer Use Continue route worked for
  the baseline and candidate.
- Computer Use selected the real `VRising` window, clicked the known `11111`
  Continue entry once per run, and sent no movement/gameplay keys.
- The candidate disabled the global RenderGraph GetTexture probe and waited for a
  materialization-only no-evaluate acceptance, but no materialization tuple appeared.
- Because candidate readiness never arrived, the safe cleanup action was to stop the
  candidate V Rising process and let the harness restore FSR mode, client settings,
  loader config, and release-safe state.
- Save protection still worked: the changed post-run state was archived and the
  `11111` save restored with `ChangeCount=0`.

## Cached-Driver No-Evaluate Follow-up

Run label: `cached-driver-no-evaluate-1080p-20260606-r1`.

Result:

- The paired visual helper again required two separate Computer Use Continue
  activations: one for baseline and one for candidate.
- After baseline closed, the candidate process reused the same app identity but a
  new `VRising` window id. The safe pattern was to call `list_apps`, choose the
  real `VRising` window, refresh `get_window_state`, and verify the screenshot
  showed the main menu before clicking.
- Computer Use clicked the known Continue point once per run and sent no movement or
  gameplay keys.
- The candidate reached gameplay, the ready file was recreated for the candidate
  phase, and the helper detected no-evaluate readiness immediately after the ready
  marker.
- Cleanup restored FSR mode, client settings, loader config, release-safe native DLL,
  and the `11111` save with `ChangeCount=0`.
- Technical result: cached-driver no-evaluate recovered performance to
  `204.201 -> 198.079` FPS while logging `82` cached-driver invocations and `0`
  native evaluate results. This confirms the UI automation path was stable enough
  for the performance diagnosis.

## Cached-Driver Real-Evaluate Failure Notes

Run labels:

- `cached-driver-evaluate-1080p-20260606-r1`.
- `cached-driver-evaluate-deferred-1080p-20260606-r1`.

Automation behavior:

- Baseline runs used the same Computer Use flow as earlier: select the real
  `VRising` window, verify the main menu, click `继续游戏` once at the known
  coordinate, wait for the static `11111` scene, then write the ready file.
- In the first candidate run, Computer Use saw the V Rising title/menu transition,
  but the process exited before the candidate ready marker could be written.
- In the corrected second candidate run, the helper launched the candidate and the
  process exited before Computer Use could click Continue. This means the crash can
  occur before entering the `11111` gameplay scene.
- Both runs restored the protected save afterward; after-restore comparisons
  reported `ChangeCount=0`.

Technical result:

- The corrected run achieved the intended UI/tool boundary: no movement keys and no
  candidate Continue click happened before the crash.
- Candidate log still reached cached-driver `sequenceSuccesses=600`, with
  `GetTexture` evaluate success count `0` and output follow-up count `0`.
- Windows Application Error reported `0xc0000005` in `nvwgf2umx.dll` for the
  corrected run, so future tests should treat cached-driver real-evaluate as a
  rejected boundary rather than a Computer Use/gameplay-entry failure.

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

## Native RenderFunc Args Gameplay Proof Notes

Run label: `native-renderfunc-args-gameplay-1080p-20260606-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx console.
- The current Computer Use screenshot was `1283x751`; the known Chinese Continue /
  `11111` entry was clicked once at `(205, 354)`.
- After about `45` seconds, Computer Use observed stable gameplay with HUD,
  character, quest text, and minimap visible.
- No movement or gameplay keys were sent.
- Cleanup closed the game, restored ClientSettings/config/native state, and the
  `11111` save was restored with `ChangeCount=0`.

## Native RenderFunc Resource Identity Gameplay Proof Notes

Run label: `native-renderfunc-resource-identity-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx console.
- The main menu screenshot was `1283x751`; the known Chinese Continue / `11111`
  area was clicked once at `(205, 354)`.
- After five seconds the game was on the loading screen. After about `45`
  seconds, Computer Use observed gameplay with quest text, character, HUD,
  health bar, and action bar visible.
- The original Computer Use gameplay screenshot included part of a neighboring
  Chrome window on the right, so a cropped gameplay screenshot artifact was also
  saved for review.
- No movement or gameplay keys were sent.
- Cleanup closed the game, restored ClientSettings/config/native state, archived
  the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc Resource Tuple Gameplay Proof Notes

Run label: `native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main menu screenshot was `1283x751`; the known Chinese Continue / `11111`
  area was clicked once at `(205, 354)`.
- After five seconds the game was on the loading/connecting screen. After about
  `45` seconds, Computer Use observed gameplay with quest text, character,
  health bar, and action bar visible.
- The original Computer Use gameplay screenshot included part of a neighboring
  window on the right, so raw and cropped gameplay screenshot artifacts were
  both saved for review.
- No movement or gameplay keys were sent.
- Cleanup closed the game, restored ClientSettings/config/native state, archived
  the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## HDRP PostProcess Boundary Gameplay Proof Notes

Run label: `hdrp-postprocess-boundary-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main menu screenshot was `1283x751`; the known Chinese Continue / `11111`
  entry was clicked once at `(205,354)`.
- After about `45` seconds, Computer Use observed gameplay with HUD, quest text,
  character, health/action bar, and minimap visible.
- No keyboard, movement, or gameplay keys were sent.
- The proof saved
  `artifacts/gameplay-automation/ComputerUseGameplay-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.jpg`
  and matching JSON metadata.
- Cleanup closed the game, restored ClientSettings/config/native state, archived
  the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## HDRP PostProcess Render Args Gameplay Proof Notes

Run label: `hdrp-postprocess-render-args-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the known Chinese Continue / `11111`
  entry was clicked once at `(205,354)`.
- The click went straight to the loading screen; no save-list interaction was
  needed.
- After about `45` seconds, Computer Use observed gameplay with HUD, quest
  text, character, health/action bar, and minimap visible.
- No keyboard, movement, or gameplay keys were sent.
- The proof saved
  `artifacts/gameplay-automation/ComputerUseGameplay-hdrp-postprocess-render-args-gameplay-1080p-20260607-r1.jpg`
  and matching JSON metadata.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## HDRP PostProcess Render Args + Render Scale Gameplay Notes

Run label:
`hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the known Chinese Continue / `11111`
  entry was clicked once at `(205,354)`.
- The click went straight to the loading screen; no save-list interaction was
  needed.
- No keyboard, movement, or gameplay keys were sent.
- After the wait, Computer Use returned a screenshot of the Codex window even
  though `list_apps()` still reported the real `VRising` Unity window and
  reacquiring that handle succeeded. Treat this as a Computer Use screenshot
  channel failure for this run; no further UI input was sent after the mismatch.
- Player log showed gameplay was reached (`TopDownCamera` created/assigned).
- A passive window capture helper produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1.png`.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc Resource Tuple + Render Scale Gameplay Notes

Run label:
`native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the known Chinese Continue / `11111`
  entry was clicked once at `(205,354)`.
- The click went straight to the loading screen; no save-list interaction was
  needed.
- No keyboard, movement, or gameplay keys were sent.
- After the wait, Computer Use again returned a screenshot of the Codex window
  even though the selected target handle was the `VRising` game window. Treat
  this as a recurring Computer Use screenshot-channel mismatch after V Rising
  loads; no further UI input should be sent when it happens.
- Player log proved gameplay was reached (`HUDCanvas`, `TopDownCamera`
  created/assigned).
- A passive window capture helper produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.png`.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc Resource Resolve + Render Scale Gameplay Notes

Run label:
`native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the known Chinese Continue / `11111`
  entry was clicked once at `(205,354)`.
- The click went straight to the loading screen; no save-list interaction was
  needed.
- After about `45` seconds, Computer Use observed gameplay with HUD, quest
  text, character, minimap, health bar, and action bar visible.
- No keyboard, movement, or gameplay keys were sent.
- Player log confirmed local `11111` entry and `TopDownCamera`
  created/assigned.
- A passive window capture helper also produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.png`.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc Resource Native Pointer + Render Scale Gameplay Notes

Run label:
`native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- A transient Node REPL top-level binding name conflict happened while listing
  apps; it was recovered with block-local variables and did not require a REPL
  reset.
- The main-menu screenshot was `1283x751`; the known Chinese Continue /
  `11111` entry was clicked once at `(205,354)`.
- The click went straight to the loading screen; no save-list interaction was
  needed.
- After about `45` seconds, Computer Use observed gameplay with HUD, quest
  text, character, minimap, health bar, and action bar visible.
- No keyboard, movement, or gameplay keys were sent.
- Player log confirmed local `11111` entry and `TopDownCamera`
  created/assigned.
- A passive window capture helper also produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.png`.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc Resource D3D11 + Render Scale Gameplay Notes

Run label:
`native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- A transient Node REPL top-level binding name conflict happened while listing
  apps; it was recovered with block-local variables and did not require a reset.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(199,352)`.
- The click went straight to the loading screen; no save-list interaction was
  needed.
- After about `60` seconds, Computer Use observed gameplay with HUD, quest
  text, character, minimap, health bar, and action bar visible.
- No keyboard, movement, or gameplay keys were sent.
- Player log confirmed local `11111` entry and `TopDownCamera`
  created/assigned.
- A passive window capture helper produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.png`.
- Runtime proof passed: the focused EASU source/destination pair validated as
  same-device D3D11 textures with `source=960x540`,
  `destination=1920x1080`, and `scale=(2.000x,2.000x)`.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc Context + Render Scale Gameplay Notes

Run label:
`native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(205,354)`.
- The click went straight to gameplay after loading; no save-list interaction
  was needed.
- After about `45` seconds, Computer Use observed gameplay with HUD, quest
  text, character, minimap, health bar, and action bar visible.
- No keyboard, movement, or gameplay keys were sent.
- A passive window capture helper produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.png`.
- Runtime proof passed: the focused EASU native render-func boundary safely
  exposed a live `RenderGraphContext.cmd` identity with
  `cmdPointerNonZero=6699` and `wrapFailures=0` by the final sampled status.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc CommandBuffer Event + Render Scale Gameplay Notes

Run label:
`native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(205,354)`.
- The click went straight to gameplay after loading; no save-list interaction
  was needed.
- After about `50` seconds, Computer Use observed gameplay with HUD, quest
  text, character, minimap, health bar, and action bar visible.
- No keyboard, movement, or gameplay keys were sent.
- A passive window capture helper produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.png`.
- Runtime proof passed: the focused EASU native render-func boundary issued one
  native no-op plugin event through `ctx.cmd`, the native render-event callback
  advanced from `0` to `1`, and `lastEventId=260607`.
- The proof did not pass texture resources, validate D3D11 resources, load NGX,
  or evaluate DLSS.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc CommandBuffer Payload + Render Scale Gameplay Notes

Run label:
`native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(205,354)`.
- The click went to the loading screen, then into gameplay after about `55`
  seconds; no save-list interaction was needed.
- No keyboard, movement, or gameplay keys were sent.
- A passive window capture helper produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.png`.
- Runtime proof passed: the focused EASU source/output native texture pointers
  were set as a native pending payload and consumed from one `ctx.cmd` plugin
  event with `eventId=260608`, `sameDevice=yes`, `source=960x540`, and
  `destination=1920x1080`.
- The proof did not load NGX, evaluate DLSS, or write visible output.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc CommandBuffer DLSS Feature Create + Render Scale Gameplay Notes

Run label:
`native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(203,353)`.
- The click went to the loading screen, then into gameplay after about `25`
  seconds; no save-list interaction was needed.
- No keyboard, movement, or gameplay keys were sent.
- Runtime proof passed: the focused EASU source/output native texture payload
  was consumed from one `ctx.cmd` plugin event with `eventId=260609`, then the
  SDK-wrapper native path created and immediately released/destroyed/shut down
  one NGX DLSS feature.
- Evidence included `sameDevice=yes`, `source=960x540`, `destination=1920x1080`,
  `scale=(2.000x,2.000x)`, `create=0x00000001`, `feature=yes`,
  `release=0x00000001`, `destroy=0x00000001`, and
  `shutdown=0x00000001`.
- The proof did not call DLSS evaluate, did not run user rendering, and did not
  write visible output.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## HDRP PostProcess Global Textures + Render Scale Gameplay Notes

Run label:
`hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(205,354)`.
- The click went to the loading screen, then into gameplay after about `30`
  seconds.
- No keyboard, movement, or gameplay keys were sent.
- Runtime proof passed: `DarkForeground.Render(CommandBuffer,HDCamera,RTHandle,
  RTHandle)` saw `CameraColor_960x540`, `CustomPostProcesDestination_960x540`,
  `_CameraMotionVectorsTexture=Motion Vectors_960x540`, and depth stabilizing
  to `CameraDepthStencil_960x540`, with non-zero native pointers for depth and
  motion.
- The proof did not use RenderGraph `GetTexture`, D3D11 validation, NGX, DLSS
  evaluate, command-buffer plugin events, user rendering, or visible write-back.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## HDRP/EASU Input Output Correlation + Render Scale Gameplay Notes

Run labels:

- `hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r1`
- `hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r2`
- `hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r3`

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked at approximately `(205,354)`.
- No keyboard, movement, or gameplay keys were sent in any run.
- `r1` was Partial because EASU source/output native pointers were captured at
  frame `4`, while the first HDRP `DarkForeground.Render(...)` snapshot arrived
  at frame `5281`.
- `r2` caught a false-positive hazard: stale EASU tuple handles later resolved
  to `60x34` bloom/CoC resources, so the analyzer was tightened to require the
  actual EASU source and destination observations to match input/output sizes.
- `r3` passed. Evidence showed `hdrpFrame=3005`,
  `easuSourceFrame=3005`, `easuDestinationFrame=3005`, frame deltas `0`, HDRP
  color/depth/motion at `960x540`, EASU source `TAA Destination_960x540`, and
  EASU destination `Edge Adaptive Spatial Upsampling_1920x1080`.
- The proof did not run D3D11 pair validation, command-buffer plugin events,
  NGX, DLSS evaluate, user rendering, or visible write-back.
- Each run cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc CommandBuffer Frame Descriptor + Render Scale Gameplay Notes

Run label:
`native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(204,352)`.
- The click went to the loading screen, then into gameplay after about `35`
  seconds.
- No keyboard, movement, or gameplay keys were sent.
- Runtime proof passed: the correlated EASU source/output pointers plus HDRP
  depth/motion pointers were set as one native frame descriptor and consumed
  from a focused EASU `ctx.cmd` plugin event with `eventId=260610`.
- Evidence showed same-frame `hdrpFrame=4110`, `easuSourceFrame=4110`,
  `easuDestinationFrame=4110`, `input=960x540`, `output=1920x1080`,
  `validation=D3D11-not-queried`, `ngx=not-loaded`, and `evaluate=not-run`.
- The proof did not run D3D11 pair validation, NGX, DLSS evaluate, user
  rendering, or actual visible write-back.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc CommandBuffer Frame Descriptor D3D11 + Render Scale Gameplay Notes

Run label:
`native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(204,352)`.
- The click went to the loading screen, then into gameplay after about `30`
  seconds.
- No keyboard, movement, or gameplay keys were sent.
- Runtime proof passed: the correlated EASU source/output pointers plus HDRP
  depth/motion pointers were set as one native frame descriptor, consumed from
  a focused EASU `ctx.cmd` plugin event with `eventId=260611`, and validated as
  a same-device D3D11 resource set.
- Evidence showed same-frame `hdrpFrame=3675`, `easuSourceFrame=3675`,
  `easuDestinationFrame=3675`, `input=960x540`, `output=1920x1080`,
  `validation=D3D11-succeeded`, `sameDevice=yes`, source/depth/motion at
  `960x540`, destination at `1920x1080`, `scale=(2.000x,2.000x)`,
  `ngx=not-loaded`, and `evaluate=not-run`.
- The proof did not load NGX, call DLSS evaluate, run user rendering, or perform
  actual visible write-back.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc CommandBuffer DLSS Scratch Evaluate + Render Scale Gameplay Notes

Run label:
`native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1`.

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(203,352)`.
- The click went to the loading screen, then into gameplay after about `25`
  seconds.
- No keyboard, movement, or gameplay keys were sent.
- Runtime proof passed: the correlated EASU source/output pointers plus HDRP
  depth/motion pointers were set as one native frame descriptor, consumed from
  a focused EASU `ctx.cmd` plugin event with `eventId=260612`, and evaluated by
  DLSS into a native scratch output texture.
- Evidence showed `consumed=1`, `sequenceCreates=1`, `sequenceEvaluates=1`,
  `evaluateSuccesses=1`, `input=960x540`, `output=1920x1080`,
  `validation=D3D11-succeeded`, `sameDevice=yes`, `scratchOutput=yes`,
  `visibleOutput=no`, `evaluateResult=1`, `shutdownResult=1`, and
  `evaluateLast=0x00000001`.
- The proof did not run user rendering or perform actual visible write-back.
  Repeated status lines were status re-logging, not repeated evaluate.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived the changed post-run save state, and restored the `11111` save with
  `ChangeCount=0`.

## Native RenderFunc CommandBuffer DLSS Persistent Scratch Evaluate + Render Scale Gameplay Notes

Run labels:

- `native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1`
- `native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2`

Result:

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once near `(205,354)`.
- No keyboard, movement, combat, or gameplay keys were sent.
- `r1` was Partial, not a game or DLSS crash. It reached
  `sequenceCreates=1`, `sequenceEvaluates=2`, and `evaluateSuccesses=2`, then
  stopped short of the target because the managed target was allowed to go
  stale while RenderGraph handle indexes were reused.
- `r2` passed after the target-refresh fix. Evidence showed `eventId=260613`,
  `setSuccesses=3`, `issueSuccesses=3`, `consumed=3`, `sequenceCreates=1`,
  `sequenceEvaluates=3`, `evaluateSuccesses=3`, `scratchOutput=yes`,
  `visibleOutput=no`, and `shutdown=completed`.
- The proof did not run normal user rendering, did not call `ExecuteDLSS`, did
  not write visible output, and did not use broad `RenderGraph.GetTexture`.
- Cleanup closed the game, restored ClientSettings/config/native state,
  archived logs, restored the release-safe native DLL, left no V Rising
  process, and restored the `11111` save with `ChangeCount=0`.
