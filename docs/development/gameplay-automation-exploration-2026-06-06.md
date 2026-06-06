# Gameplay Automation Exploration - 2026-06-06

Status: Phase 1 automatic gameplay entry is proven for the known local/private
`11111` fixture under `1920x1080` Windowed conditions.

Goal: determine whether Codex can automatically enter a stable local/private V Rising
gameplay scene for runtime validation. Do not fall back to semi-automatic testing until
all reasonable automatic routes have been investigated and recorded.

## Sources Checked

Local evidence:

- Current repository scripts.
- `C:\Software\VRising`.
- `%USERPROFILE%\AppData\LocalLow\Stunlock Studios\VRising`.
- Existing `Player.log`, `Player-server.log`, `ClientSettings.json`, and cloud-save folders.
- [Gameplay direct-entry route search](gameplay-direct-entry-route-search-2026-06-06.md).

External sources checked:

- Stunlock Studios launch options article: confirms Unity/V Rising launch flags for windowing, resolution, D3D backend, logging, and batch/headless mode.
  - https://guides.playvrising.com/hc/en-us/articles/28584998378653-How-to-Set-Launch-Options-for-V-Rising-Steam
- Stunlock Studios dedicated-server instructions for V Rising 1.1.x PC: confirms server configuration files, `-persistentDataPath`, and command-line overrides such as `-saveName`.
  - https://github.com/StunlockStudios/vrising-dedicated-server-instructions/blob/master/1.1.x-pc/INSTRUCTIONS.md

## Local Facts From First Pass

- Game path exists: `C:\Software\VRising\VRising.exe`.
- BepInEx is installed under `C:\Software\VRising\BepInEx`.
- Existing scripts already provide:
  - game launch for fixed-duration diagnostics;
  - manual-ready visual comparison;
  - window visibility detection;
  - screenshot capture with `PrintWindow` and `ScreenCopy` fallback;
  - PresentMon + `nvidia-smi` performance capture;
  - release-safe cleanup for native DLL/config in existing diagnostic flows.
- PresentMon is available at `C:\Software\PresentMon\PresentMon-2.4.1-x64.exe`.
- Current client settings file:
  - path: `%USERPROFILE%\AppData\LocalLow\Stunlock Studios\VRising\Settings\v4\ClientSettings.json`;
  - `GraphicSettings.Resolution = 3840x2160`;
  - `GraphicSettings.FsrQualityMode = 0`;
  - `GraphicSettings.FPSLimitValue = 300`;
  - `GraphicSettings.GameFPSCapMode = 0`;
  - the simple excerpt did not expose a VSync field, so VSync state needs a separate verification path before final performance tests.
- `ClientSettings.json` does not expose a visible `WindowMode` field, but `Player.log`
  dumps `"WindowMode": 1` and the game reports `fullScreenMode FullScreenWindow`.
- Temporarily adding `GraphicSettings.WindowMode = 3` through the session harness makes
  `Player.log` report `SetResolution 1920, 1080, fullScreenMode Windowed` and keeps
  the script-side screenshot at `1920x1080`.
- `ServerHistory.json` contains a continue-able local/private entry for `Name=11111`,
  `SessionGUID=25fe20c1-44bb-4fe8-bca7-1bc7cb322429`, and
  `ConnectAddress=SteamIPv4://192.168.1.7:9876`.
- The user independently recalled that the target local game is named with many `1`
  characters and should be continuable directly, matching the `Name=11111` local
  history entry.
- Local save exists:
  - Steam/user folder: `76561198564171843`;
  - save UUID: `f0e07524-03f4-4ef4-945c-b1f7e982071b`;
  - latest observed autosave: `AutoSave_23.save.gz`;
  - character evidence in server log: `Helen`.
- `Player.log` showed a plain client launch line: `CommandLine: C:\Software\VRising\VRising.exe`.
- `Player-server.log` showed the local private-game server sub-process command line:
  - `-batchMode -nographics`;
  - `-saveName f0e07524-03f4-4ef4-945c-b1f7e982071b`;
  - `-persistentDataPath ...\LocalLow\Stunlock Studios\VRising`;
  - `-hostServer`;
  - `-parentPID <client pid>`;
  - `-userSave`.
- The same server log showed successful save load and local character connection:
  - `CreateAndHostServer ... Loaded Save: AutoSave_21.save.gz`;
  - `Character: 'Helen' connected`.
- Computer Use is available in the Codex app and has been proven against the live
  V Rising window. Use it for multi-step menu observation/navigation while keeping
  PowerShell scripts responsible for launch, log capture, and cleanup. Operating notes
  are in
  [computer-use-vrising-automation-notes-2026-06-06.md](computer-use-vrising-automation-notes-2026-06-06.md).
- The first full automatic Continue proof,
  `automation-continue-click-windowed-v1-20260606`, reached stable gameplay without
  human input. The 50-second follow-up Computer Use screenshot showed character, HUD,
  hotbar, quest text, and minimap. Player/server logs confirmed local server startup,
  save load, and character `Helen` connection. Cleanup passed, and the save was
  restored from a pre-proof backup after autosave rotation was detected.

## Route Matrix

### Route 1 - Stable Launch Options

Question: can launch options make every automation run start in a predictable windowed
test shape?

Evidence so far:

- Official Stunlock launch options include `-windowed`, `-popupwindow`, `-screen-width`, `-screen-height`, `-screen-fullscreen`, `-force-d3d11`, `-logFile`, and `-single-instance`.

Current judgment:

- Good foundation for constructive tests.
- Does not by itself enter gameplay.
- On this local machine, launch options plus `ClientSettings.json` resolution override
  can make `Player.log` report `SetResolution 1920, 1080`, but Unity may still present
  `fullScreenMode FullScreenWindow` with a desktop-sized capture client area unless
  `GraphicSettings.WindowMode=3` is also temporarily injected.

Current preferred launch shape:

- Launch with `-windowed -screen-width 1920 -screen-height 1080 -screen-fullscreen 0 -force-d3d11 -single-instance -logFile <artifact log>`.
- Temporarily set `GraphicSettings.Resolution = 1920x1080` and
  `GraphicSettings.WindowMode = 3`.
- Record both the captured client size and the game-reported `SetResolution` line.
- Cleanup: close/kill `VRising.exe`/server process, restore ClientSettings and loader
  config, archive logs/screenshots.

### Route 2 - Client Command-Line Auto-Continue or Auto-Connect

Question: does the V Rising client expose a supported command line to continue the last
local save or connect directly to a local server?

Evidence so far:

- Official Stunlock launch option list did not show an auto-continue or direct-connect client flag.
- Current `Player.log` for normal launches showed no such client arguments.
- Web search found discussion claiming no automatic client connection option, but this is not authoritative and should not close the route by itself.
- Follow-up official/local search on 2026-06-06 still found no supported client
  command-line auto-continue or direct-connect flag. The route note is
  [gameplay-direct-entry-route-search-2026-06-06.md](gameplay-direct-entry-route-search-2026-06-06.md).
- Local interop strings expose UI and internal symbols such as `ContinueLatestHost`,
  `ContinueLatestJoin`, `PlayContinueMenuView`, `ContinueButton_OnClick`,
  `OnButtonClick_DirectConnect`, `JoinGame`, `LaunchGameHelper`, and
  `TryConnectToServerIpv4`, but this is not proof of a supported external launch
  interface.

Current judgment:

- Weak as a command-line route. Keep it open only for future source/metadata evidence.
- Stronger as a UI automation route because the local `ServerHistory.json` entry gives
  the in-game Continue flow enough persisted state.

Next investigation:

- Do not spend the next runtime loop on blind command-line guesses.
- If revisiting this route, use a dedicated metadata reader or purpose-built tooling;
  plain PowerShell `Assembly.LoadFrom` reflection against IL2CPP interop assemblies
  caused a `StackOverflowException` in the child shell.

### Route 3 - Dedicated/Local Server First, Then Client Connect

Question: can Codex start the known local save as a server and then automatically connect
the client to it?

Evidence so far:

- Official dedicated-server docs confirm `-persistentDataPath` and `-saveName` command-line overrides.
- Local `Player-server.log` proves the private-game flow starts a background batch server with the save UUID and ports.

Current judgment:

- Good candidate for a stable backend, but it still needs a client connection route.
- It may be useful if UI automation can reliably direct-connect to localhost or if a client command/console route is found.
- Official docs support server-side save startup with `-saveName` and
  `-persistentDataPath`, but they do not solve client auto-connect.

Next test:

- Dry-run a server command based on the observed log without launching, then decide whether to run it in a contained test.
- Do not run a separate server until port conflicts, save writes, and cleanup are documented.

### Route 4 - UI Automation From Main Menu / Continue

Question: can PowerShell/Win32 drive the client from launch to the last local gameplay
scene using keyboard/mouse automation?

Evidence so far:

- Existing scripts can start V Rising, detect a real game window, bring it forward for capture, and capture screenshots.
- PowerShell can use `Add-Type`; existing screenshot code already calls Win32 APIs such as `SetForegroundWindow`.
- No repository script currently sends keyboard/mouse input to the game.
- First no-DLSS automation run on 2026-06-06 launched a visible `1920x1080` Unity window and cleaned up, but the screenshot was still a blank black frame. This rejects "visible window only" as proof-of-control; screenshot acceptance now requires a nonblank image.
- Second no-DLSS automation run showed `Process.MainWindowHandle` can point at the BepInEx console while the Unity window is a separate top-level window. Visibility detection now enumerates all process windows and chooses a visible non-console Unity/game window.
- Third no-DLSS automation run got a nonblank game screenshot and cleaned up, but V Rising changed back to `3840x2160` despite `-screen-width 1920 -screen-height 1080`. Launch options alone are therefore insufficient for the standard constructive test shape on this local setup; temporary `ClientSettings.json` resolution override is now part of the next proof attempt.
- Fourth no-DLSS automation run with `-SetClientResolution` got a nonblank game screenshot, archived logs, restored settings/config, and left no V Rising process. `Player.log` reported `SetResolution 1920, 1080, fullScreenMode FullScreenWindow`, while screenshot capture saw a `3840x2160` client area. This is likely fullscreen-window behavior rather than a failure to set the internal resolution.
- Fifth no-DLSS automation run used revised gates and correctly returned `Status=Partial`: `AutomationControlReady=true`, `GameResolutionMatchesRequested=true`, `GameReportedFullScreenMode=FullScreenWindow`, and `WindowedModeReady=false`.
- Harmless input proof passed on the third input run,
  `automation-proof-harmless-input-escape-v3-20260606`: `InputSent=true`,
  `InputSendInputCount=2`, `InputAfterScreenshotNonBlank=true`,
  `InputProofReady=true`, `CrashEventCount=0`, and no remaining V Rising process.
- The first two harmless-input runs are retained as negative evidence: one failed on a
  PowerShell `[ushort]` cast bug, and one failed because the Win32 `INPUT` structure was
  too small before adding the full mouse/keyboard/hardware union.

Current judgment:

- Proven first automation implementation route.
- Conservative proof-of-control now covers launch, window selection, nonblank capture,
  one harmless key input, log archival, and cleanup.
- Proof-of-control is established for automatic launch, game-window selection, nonblank
  screenshot capture, log archival, cleanup, and true `1920x1080` Windowed mode through
  temporary `GraphicSettings.WindowMode=3`.
- Computer Use is available in the Codex app and should be considered for multi-step UI
  navigation, especially because it can snapshot occluded windows and press keys against
  a selected window.
- Observation-only Computer Use proof passed with label
  `automation-session-continue-computeruse-20260606`: it selected the real `VRising`
  window rather than the BepInEx console, captured the Chinese main menu, and showed
  the Continue entry with save name `11111`. Cleanup then passed with `CrashEventCount=0` and no
  remaining process.
- Continue activation proof passed with label
  `automation-continue-click-windowed-v1-20260606`: one Computer Use click on the
  Continue label reached stable gameplay under `1920x1080` Windowed conditions.

Next default:

- Future runtime tests should enter gameplay through the session harness plus Computer
  Use, using
  [gameplay-continue-ui-navigation-protocol-2026-06-06.md](gameplay-continue-ui-navigation-protocol-2026-06-06.md)
  and save backup/restore for the `11111` fixture. Semi-automatic gameplay entry is not
  the default path unless this route regresses.

### Route 5 - Screenshot/Image-State Recognition

Question: can Codex detect main menu, continue button, loading, and gameplay readiness
from screenshots?

Evidence so far:

- Existing screenshot helper can capture the real Unity window with `ScreenCopy` fallback.
- Previous false `PrintWindow` captures are detected and rejected.

Current judgment:

- Feasible as a state detector and already useful for pass/fail classification.
- Computer Use screenshots now provide known main-menu, loading/progress, and stable
  gameplay reference frames for the `11111` route.

Next improvement:

- Build small deterministic detectors before relying on them in tests.

### Route 6 - Log-State Detection

Question: can logs determine that gameplay has loaded without requiring screenshot
classification?

Evidence so far:

- `Player-server.log` includes `CreateAndHostServer`, save load, and `Character: 'Helen' connected`.
- BepInEx and Player logs already support existing analyzer/status scripts.

Current judgment:

- Strong readiness detector once the path reaches gameplay.
- Not enough to drive UI by itself.

Next test:

- Define log patterns for `server started`, `save loaded`, `character connected`, `gameplay stable`, and `shutdown`.
- Combine with screenshot/window checks.

### Route 7 - Fixed Local Test Scene

Question: can the existing local save become a deterministic test fixture?

Evidence so far:

- One local save UUID exists and was used for prior tests.
- The save has recent autosaves and a known character.

Current judgment:

- Useful fixture for repeated tests.
- Requires snapshot/backup protocol before automation starts modifying it.
- First successful Continue proof confirmed this is not optional: entering gameplay
  rotated autosaves, so the post-proof save was archived and then restored from the
  pre-proof backup.

Default protocol:

- Back up the save directory before automated gameplay/runtime tests.
- Compare after the test.
- Restore unless retaining the changed state is explicitly intended and documented.
- Record expected scene/location after entry.

### Route 8 - Mod-Side Gameplay State Detection

Question: can the plugin expose a safe default-off diagnostic signal when gameplay
resources/world state are actually present?

Evidence so far:

- Existing plugin already logs render/HDRP/RenderGraph states.
- It does not currently solve entry into gameplay, but it can help detect success once entry occurs.

Current judgment:

- Useful as an auxiliary detector, not the primary automation mechanism.

Next investigation:

- Search local interop for safe `ProjectM` or scene/world/character signals that can be read without mutating gameplay.

## Required Semi-Automatic Protocol If Automation Fails

Only use this after the automatic routes above are explored and rejected with evidence.

Minimum durable protocol must define:

- Human action: enter the named local/private gameplay scene, stop moving, send the ready phrase, and immediately return focus to the game window.
- Codex action: deploy, configure, launch, wait, verify visible window, capture screenshots/FPS/GPU/logs, close game, restore release-safe config/native DLL/settings, and archive artifacts.
- Ready phrase: `ok 已经停稳`.
- Timeout policy.
- Window-not-visible policy.
- Cleanup path for game process, BepInEx config, native DLL, FSR/resolution/FPS/VSync state, and artifacts.

## Immediate Next Action

Phase 1 route A is achieved for the local/private `11111` fixture. Do not fall back to
the semi-automatic protocol by default. Future runtime/DLSS tests should use the
proven automated gameplay-entry path:

1. Back up the `11111` save directory.
2. Start V Rising with `scripts/start-vrising-automation-session.ps1` using
   `-SetClientResolution -SetClientWindowMode -ClientWindowMode 3`.
3. Use Computer Use to reacquire the real `VRising` window and activate Continue.
4. Confirm gameplay with screenshots and/or Player/server log patterns.
5. Run `scripts/stop-vrising-automation-session.ps1`.
6. Compare the save directory and restore it unless the changed save state is
   intentionally retained.

After this, resume the DLSS runtime path from `docs/development/pause-state-2026-06-05.md`.
