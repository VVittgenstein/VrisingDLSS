# Gameplay Automation Proof Protocol - 2026-06-06

Status: updated after five no-DLSS automation proof runs.

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

## Expected Evidence

- `VisibleGameWindow` from `inspect-vrising-visibility.ps1`.
- A PNG screenshot under `artifacts/gameplay-automation/` with captured client size recorded.
- The screenshot must be nonblank; a near-black, near-white, or near-binary loading/capture frame is not enough.
- The `Player.log` `SetResolution` line must be parsed into game-reported resolution and `fullScreenMode`.
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
