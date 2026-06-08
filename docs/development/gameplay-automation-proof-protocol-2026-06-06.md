# Gameplay Automation Proof Protocol - 2026-06-06

Status: updated after five no-DLSS automation proof runs, three harmless-input
proof runs, one observation-only Computer Use session, one `WindowMode=3` proof, and
one successful automatic Continue-to-gameplay proof.

## Question

Can Codex launch V Rising in a controlled `1920x1080` D3D11 loader state, detect
the real Unity game window, capture a valid screenshot, archive logs, and restore a
safe state without human input? A stricter sub-question is whether that state is a
true `1920x1080` windowed client rather than Unity `FullScreenWindow`.

## Hypothesis

Stunlock/Unity launch options plus the existing visibility and screenshot helpers are
enough for the first automation proof-of-control. This does not prove menu navigation,
keyboard/mouse input, or gameplay entry yet.

## Test Command

Dry run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-automation-proof.ps1 -GamePath "C:\Software\VRising" -DryRun
```

Actual run, only after the dry run matches the intended plan:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-automation-proof.ps1 -GamePath "C:\Software\VRising" -SetClientResolution -WaitForWindowSeconds 90 -WaitForNonBlankScreenshotSeconds 90 -ObservationSeconds 10
```

Harmless input dry run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-automation-proof.ps1 -GamePath "C:\Software\VRising" -SetClientResolution -SendHarmlessInput -HarmlessInputKey Escape -WaitForWindowSeconds 90 -WaitForNonBlankScreenshotSeconds 90 -ObservationSeconds 5 -PostInputWaitSeconds 3 -DryRun
```

Harmless input actual run, only after the dry run matches the intended plan:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-automation-proof.ps1 -GamePath "C:\Software\VRising" -ArtifactLabel automation-proof-harmless-input-escape-20260606 -SetClientResolution -SendHarmlessInput -HarmlessInputKey Escape -WaitForWindowSeconds 90 -WaitForNonBlankScreenshotSeconds 90 -ObservationSeconds 5 -PostInputWaitSeconds 3
```

## Expected Evidence

- `VisibleGameWindow` from `inspect-vrising-visibility.ps1`.
- A PNG screenshot under `artifacts/gameplay-automation/` with captured client size recorded.
- The screenshot must be nonblank; a near-black, near-white, or near-binary loading/capture frame is not enough.
- The `Player.log` `SetResolution` line must be parsed into game-reported resolution and `fullScreenMode`.
- When `-SendHarmlessInput` is used, the selected `UnityWndClass` window handle, input
  key, virtual key, `SendInput` count, foreground attempt, and after-input screenshot
  must be recorded.
- Archived player/BepInEx logs under `artifacts/gameplay-automation/`.
- A result JSON under `artifacts/gameplay-automation/`.
- `CrashEventCount=0`.
- No `VRising.exe` process after cleanup.
- Loader config restored.

## Pass Signal

The result JSON reports `Status=Pass`, `VisibilityStatus=VisibleGameWindow`,
`ScreenshotCreated=true`, `ScreenshotAccepted=true`, `CaptureClientSizeMatchesRequested=true`,
`CrashEventCount=0`, `RemainingVRisingProcessCount=0`, `RestoredLoaderConfig=true`,
and `RestoredClientSettings=true` when `-SetClientResolution` is used. For a full
windowed pass, `WindowedModeReady=true`.

For harmless input mode, `Status=Pass` means the smaller input proof passed:
`AutomationControlReady=true`, `InputAttempted=true`, `InputSent=true`,
`InputAfterScreenshotCreated=true`, `InputAfterScreenshotNonBlank=true`,
`InputProofReady=true`, `CrashEventCount=0`, and no V Rising process remains. This
does not prove menu navigation or gameplay entry.

## Partial Signal

The result JSON may report `Status=Partial` when automation control succeeds but
the exact windowed shape is not proven. The known case is:

- `AutomationControlReady=true`.
- `GameResolutionMatchesRequested=true`.
- `GameReportedFullScreenMode=FullScreenWindow`.
- `CaptureClientSizeMatchesRequested=false`.

This means V Rising accepted the requested `1920x1080` resolution internally, but
Unity still presented a fullscreen-window client area matching the desktop.

## Fail Signal

Any of the following is a failure:

- No visible game window before timeout.
- Early process exit.
- Missing or invalid screenshot artifact.
- Screenshot exists but remains blank/invalid until timeout.
- Screenshot exists but the capture is blank/invalid.
- Neither capture size nor `Player.log` reports the requested `1920x1080` state.
- Windows Application Error event for V Rising, Unity, coreclr, or VrisingDLSS.
- Harmless input requested but no key was sent, `SendInput` did not report a full
  key down/up pair, or the after-input screenshot is missing/blank.
- Game process remains after cleanup.
- Loader config restore fails.

## Cleanup Path

The script closes the V Rising main window, force-stops the process if needed,
archives logs/WER/result data, and writes the `loader` diagnostic config again.
When `-SetClientResolution` is used, the original `ClientSettings.json` is copied to
the artifact folder first and restored during cleanup. This test does not use SDK-wrapper
native DLLs, DLSS runtime paths, FSR mode changes, or deep DLSS probes.

## Follow-Up If This Passes

The next route should test controlled input separately. Do not jump directly to
gameplay entry. A safe follow-up should define one harmless input, expected visual or
log evidence, and a cleanup path before sending keyboard or mouse events.

## First Run Note

The first actual run on 2026-06-06 launched a visible `1920x1080` `UnityWndClass`
window and cleaned up correctly, but the screenshot was a black loading/capture frame
with `NearBlackRatio=1`. That exposed a script gate bug: visible window alone is not a
valid proof-of-control. The script now waits for a nonblank screenshot before returning
`Pass`.

A second run exposed another automation bug: `Process.MainWindowHandle` can point at
the BepInEx console window instead of the Unity game window. `inspect-vrising-visibility.ps1`
now enumerates all top-level windows for the V Rising process and selects a visible
non-console `UnityWndClass`/game-title window.

A third run proved the top-level-window fix and nonblank screenshot wait, but the game
switched from the requested `1920x1080` launch options back to `3840x2160`. Treat that
run as a partial proof only. The script can temporarily override `ClientSettings.json`
resolution with automatic restoration.

A fourth run used `-SetClientResolution`. The player log reported
`SetResolution 1920, 1080, fullScreenMode FullScreenWindow`, while the nonblank
screenshot captured a `3840x2160` client area. This supports the user's observation
that the game is launching fullscreen while still using a 1080p internal resolution
setting. The script now records game-reported resolution separately from capture
client size and can return `Partial` for this fullscreen-window case instead of
misclassifying it as a pure screenshot failure.

A fifth run with the revised gates produced the intended classification:
`Status=Partial`, `AutomationControlReady=true`, `ScreenshotAccepted=true`,
`GameResolutionMatchesRequested=true`, `GameReportedFullScreenMode=FullScreenWindow`,
`WindowedModeReady=false`, `CrashEventCount=0`, and `RemainingVRisingProcessCount=0`.
The local artifact label is `automation-proof-1920-window-v5-20260606`.

## Harmless Input Proof Note

The script now supports `-SendHarmlessInput` with `Escape`, `Enter`, or `Space`. The
first intended runtime proof uses `Escape` because it is low risk and does not attempt
to select `Continue` or enter gameplay. The proof only asks whether Codex can bring the
real game window forward, send one harmless key through Win32 `SendInput`, capture an
after-input screenshot, archive logs, and restore state.

The first harmless-input run, `automation-proof-harmless-input-escape-20260606`,
failed after reaching `AutomationControlReady=true` because the PowerShell cast used
`[ushort]`; PowerShell requires `[UInt16]`. The game did not crash, settings/config were
restored, and no V Rising process remained.

The second harmless-input run, `automation-proof-harmless-input-escape-v2-20260606`,
fixed that cast but `SendInput` returned `0` because the C# `INPUT` structure did not
include the full mouse/keyboard/hardware union size. It still produced nonblank
before/after screenshots, restored settings/config, and left no V Rising process.

The third harmless-input run, `automation-proof-harmless-input-escape-v3-20260606`,
passed: `Status=Pass`, `AutomationControlReady=true`, `InputAttempted=true`,
`InputSent=true`, `InputStructSize=40`, `InputSendInputCount=2`,
`InputAfterScreenshotCreated=true`, `InputAfterScreenshotNonBlank=true`,
`InputProofReady=true`, `CrashEventCount=0`, and `RemainingVRisingProcessCount=0`.
The run still reported `GameReportedFullScreenMode=FullScreenWindow`, which confirms
the input proof is robust to the fullscreen-window shape.

## Session Harness And Computer Use Note

The scripts `start-vrising-automation-session.ps1` and
`stop-vrising-automation-session.ps1` now provide a bounded session harness for UI
navigation proofs. The start script can leave V Rising open only when `Status=Ready`
and `CleanupRequired=true`; the stop script closes the scoped game process, archives
logs/WER, restores `ClientSettings.json`, rewrites the loader config, and records a
cleanup JSON.

The first observation-only Computer Use run,
`automation-session-continue-computeruse-20260606`, passed. It selected the real
`VRising` game window rather than the BepInEx console, captured the main menu, and
showed the target Chinese Continue entry with `11111` underneath. Cleanup then passed with
`CrashEventCount=0`, `RestoredClientSettings=true`, `RestoredLoaderConfig=true`, and
`RemainingVRisingProcessCount=0`.

Use
[computer-use-vrising-automation-notes-2026-06-06.md](computer-use-vrising-automation-notes-2026-06-06.md)
and
[gameplay-continue-ui-navigation-protocol-2026-06-06.md](gameplay-continue-ui-navigation-protocol-2026-06-06.md)
for future gameplay-entry automation.

## Windowed And Gameplay Entry Result

`automation-windowmode3-1080p-v1-20260606` proved the user's preferred constructive
test shape. Temporarily writing `GraphicSettings.WindowMode=3` alongside the existing
resolution override made `Player.log` report:

```text
SetResolution 1920, 1080, fullScreenMode Windowed
```

The script-side screenshot was `1920x1080`, cleanup passed, and the user's original
`ClientSettings.json` was restored with no persisted `WindowMode` field.

`automation-continue-click-windowed-v1-20260606` then proved automatic gameplay entry:
Computer Use clicked Continue exactly once from the `11111` menu, observed loading at
20 seconds, and observed stable gameplay with character/HUD at 50 seconds. Player and
server logs confirmed the local server started, loaded the known save, and connected
character `Helen`. Cleanup passed with `CrashEventCount=0` and no remaining process.

Entering gameplay rotated autosaves, so the save was restored from the pre-proof backup.
Future gameplay-entry tests must include the same save backup/compare/restore discipline.

As of 2026-06-08, use the save fixture resolver before protected gameplay runs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\find-vrising-save-fixture.ps1 -SaveName 11111 -RequireOne -Json
```

It resolves the local/private fixture path from `CloudSaves`. The resolver is
read-only, requires exactly one usable match, and lets follow-up commands pass
`-ProtectSave -SaveDir <SelectedSaveDir>` without manually copying the
CloudSaves path.
