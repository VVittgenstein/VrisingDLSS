# Gameplay Automation Exploration - 2026-06-06

Status: Phase 1 in progress. This first pass did not launch V Rising.

Goal: determine whether Codex can automatically enter a stable local/private V Rising
gameplay scene for runtime validation. Do not fall back to semi-automatic testing until
all reasonable automatic routes have been investigated and recorded.

## Sources Checked

Local evidence:

- Current repository scripts.
- `C:\Software\VRising`.
- `%USERPROFILE%\AppData\LocalLow\Stunlock Studios\VRising`.
- Existing `Player.log`, `Player-server.log`, `ClientSettings.json`, and cloud-save folders.

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
- Current tool discovery did not expose a dedicated computer-use/game-control tool. The available practical route is currently PowerShell/Win32 automation plus existing screenshots/log detectors. `node_repl` exists, but it is browser-oriented and not a native game UI control tool.

## Route Matrix

### Route 1 - Stable Launch Options

Question: can launch options make every automation run start in a predictable windowed
test shape?

Evidence so far:

- Official Stunlock launch options include `-windowed`, `-popupwindow`, `-screen-width`, `-screen-height`, `-screen-fullscreen`, `-force-d3d11`, `-logFile`, and `-single-instance`.

Current judgment:

- Good foundation for constructive tests.
- Does not by itself enter gameplay.

Next test:

- Launch with `-windowed -screen-width 1920 -screen-height 1080 -screen-fullscreen 0 -force-d3d11 -single-instance -logFile <artifact log>`.
- Pass if the visible game window is detected at the expected size and logs are written to the requested path.
- Cleanup: close/kill `VRising.exe`, restore loader config, archive log/screenshot.

### Route 2 - Client Command-Line Auto-Continue or Auto-Connect

Question: does the V Rising client expose a supported command line to continue the last
local save or connect directly to a local server?

Evidence so far:

- Official Stunlock launch option list did not show an auto-continue or direct-connect client flag.
- Current `Player.log` for normal launches showed no such client arguments.
- Web search found discussion claiming no automatic client connection option, but this is not authoritative and should not close the route by itself.

Current judgment:

- Unproven and likely weak, but not fully rejected.

Next investigation:

- Search local binaries/interops/configs for likely client parameters such as `connect`, `continue`, `server`, `ip`, `join`, `saveName`, and `direct`.
- Search official/current sources for client console/direct-connect options.

### Route 3 - Dedicated/Local Server First, Then Client Connect

Question: can Codex start the known local save as a server and then automatically connect
the client to it?

Evidence so far:

- Official dedicated-server docs confirm `-persistentDataPath` and `-saveName` command-line overrides.
- Local `Player-server.log` proves the private-game flow starts a background batch server with the save UUID and ports.

Current judgment:

- Good candidate for a stable backend, but it still needs a client connection route.
- It may be useful if UI automation can reliably direct-connect to localhost or if a client command/console route is found.

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

Current judgment:

- Most likely first automation implementation route.
- Needs a conservative proof-of-control test before attempting full gameplay entry.

Next test:

- Add or prototype a no-DLSS automation helper that launches the game in `1920x1080` windowed mode, waits for a visible game window, captures a screenshot, sends one harmless input, and records before/after screenshots/logs.
- Do not proceed to menu navigation until the proof-of-control artifact is clear.

### Route 5 - Screenshot/Image-State Recognition

Question: can Codex detect main menu, continue button, loading, and gameplay readiness
from screenshots?

Evidence so far:

- Existing screenshot helper can capture the real Unity window with `ScreenCopy` fallback.
- Previous false `PrintWindow` captures are detected and rejected.

Current judgment:

- Feasible as a state detector.
- Needs templates, image hashes, or a simple visual classifier based on real screenshots.

Next test:

- Capture launch/main-menu/loading/gameplay states during a controlled run and save them under `artifacts/gameplay-automation/`.
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
- Needs snapshot/backup protocol before automation starts modifying it.

Next test:

- Create a documented backup/restore process for the save directory or pick a dedicated copied test save.
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

Do not run DLSS probes yet. The next small reversible step should be a no-DLSS automation
proof-of-control plan or script dry-run:

1. Define exact launch command for 1920x1080 windowed D3D11.
2. Capture/verify the visible game window.
3. Test whether a controlled Win32 input action reaches the game.
4. Archive screenshots/logs and restore the process.
