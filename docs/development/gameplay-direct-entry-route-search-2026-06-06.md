# Gameplay Direct-Entry Route Search - 2026-06-06

Status: first lightweight local/official search complete. No game launch was performed
for this note.

## Question

Can V Rising be launched directly into the known local/private gameplay session, or
into a direct server connection, without keyboard/mouse UI automation?

## Scope

This search covered:

- Current Stunlock launch-options article.
- Current Stunlock dedicated-server instructions for V Rising `1.1.x` PC.
- Local `ClientSettings.json`, `ServerHistory.json`, `Player.log`, and
  `Player-server.log`.
- Local BepInEx IL2CPP interop assemblies by string scan only.

## Findings

### Official Launch Options

The Stunlock launch-options article lists display/windowing, graphics/rendering,
performance, and miscellaneous Unity launch flags, including `-windowed`,
`-fullscreen`, `-popupwindow`, `-screen-width`, `-screen-height`,
`-screen-fullscreen`, `-force-d3d11`, `-single-instance`, and `-logFile`.

It does not list a client-side launch option for auto-continue, auto-join,
direct-connect, `saveName`, or direct server address connection.

Source:

- https://guides.playvrising.com/hc/en-us/articles/28584998378653-How-to-Set-Launch-Options-for-V-Rising-Steam

### Official Dedicated Server Instructions

The dedicated-server docs confirm that `-persistentDataPath` and `-saveName` are
server-side settings. They can be used to run or transfer a server save, but the docs
do not describe a client-side command-line route that connects the client directly to
that server.

Source:

- https://raw.githubusercontent.com/StunlockStudios/vrising-dedicated-server-instructions/master/1.1.x-pc/INSTRUCTIONS.md

### Local Client Settings And Logs

Current local `ClientSettings.json` contains:

- `GraphicSettings.Resolution = 3840x2160`
- `GraphicSettings.FsrQualityMode = 0`
- `GraphicSettings.FPSLimitValue = 300`
- `GraphicSettings.GameFPSCapMode = 0`
- no visible `WindowMode` field

Recent `Player.log` dumps still contain `"WindowMode": 1` and
`SetResolution 3840, 2160, fullScreenMode FullScreenWindow` for a normal launch.
The no-DLSS automation proof with temporary `1920x1080` resolution override reported
`SetResolution 1920, 1080, fullScreenMode FullScreenWindow`. This supports the current
Route 1 judgment: internal resolution can be controlled, but true windowed mode is not
yet proven.

### Local Server History

`ServerHistory.json` contains one continue-able local/private history entry:

- `SessionGUID = 25fe20c1-44bb-4fe8-bca7-1bc7cb322429`
- `Name = 11111`
- `ConnectAddress = SteamIPv4://192.168.1.7:9876`
- `FallbackConnectAddress = SteamP2P://85568398538181520`
- `HideInContinue = false`
- `QueryPort = 9877`
- `UserId = 76561198564171843`
- `IsDedicatedServer = false`

The cloud-save folder has matching local/private save data:

- save folder: `f0e07524-03f4-4ef4-945c-b1f7e982071b`
- `SessionId.json = 25fe20c1-44bb-4fe8-bca7-1bc7cb322429`
- `ServerHostSettings.json` name: `11111`

This is strong evidence that the in-game `Continue` path has enough persisted data to
reopen the local/private session, but it is not evidence of a command-line direct-entry
route.

The user also recalled that the relevant local game name is "many 1s" and that it
should be possible to continue directly into it. This matches the local
`ServerHistory.json` evidence for `Name=11111` and makes the `Continue` UI path the
preferred target after the harmless input proof.

The observation-only Computer Use run
`automation-session-continue-computeruse-20260606` confirmed this target on the live
main menu: the Chinese Continue entry was visible with `11111` underneath.

The bounded Continue proof `automation-continue-click-windowed-v1-20260606` then
activated that menu entry with one Computer Use click and reached stable gameplay. This
proves the UI route for the known local/private fixture; it does not create new
evidence for a client command-line direct-entry flag.

### Interop String Scan

The local interop string scan found client/UI symbols related to continuing and
connecting:

- `ProjectM.HUD.dll`
  - `ProjectM.UI.PlayContinueMenuView`
  - `ContinueButton_OnClick`
  - `GoTo_ContinueMenu`
  - `JoinGame`
  - `LaunchGameHelper`
  - `OnButtonClick_DirectConnect`
  - `TryConnectToServerIpv4`
  - `TryConnectToServerEOS`
  - `CreateConnectAddresses`
  - `ServerHistory`
  - `WindowMode`
- `ProjectM.dll`
  - `ContinueHost`
  - `ContinueJoin`
  - `ContinueLatestHost`
  - `ContinueLatestJoin`
  - `DirectConnect`
  - `ServerHistoryEntry`
  - `TryGetServerHistory`
- `ProjectM.Shared.dll`
  - `ConnectAddressUtility`
  - `SaveName`
  - `WindowMode`
- `Stunlock.Network.dll`
  - `ConnectAddress.TryParse`
  - `CreateSteamIPv4`
  - `CreateSteamP2P`
  - `CreateLocalOnly`

These symbols make UI automation and possibly a future mod-side diagnostic auto-entry
experiment plausible. They do not by themselves prove a stable, supported client
command-line interface.

## Rejected/Unsafe Inspection Route

Attempting to load `ProjectM.HUD.dll` through normal PowerShell/.NET reflection caused
the child PowerShell process to terminate with `StackOverflowException`. Do not use
plain `Assembly.LoadFrom` reflection on these IL2CPP interop assemblies in future
investigations. Use string scans, a dedicated metadata reader, or purpose-built tooling.

## Current Route Judgment

Route 2, client command-line auto-continue/direct-connect, remains weak and should not
be the next runtime bet unless new evidence appears.

The stronger next automation route is:

1. Treat `FullScreenWindow` as acceptable for control tests.
2. Drive the known UI route with keyboard/mouse or a small input helper.
3. Use screenshots and logs to detect state transitions.
4. Prefer `Continue` from `ServerHistory.json` before attempting server direct-connect.

Route 3, starting a server first, remains useful only if paired with a client connection
route. The current official docs support server-side save startup, but not client-side
auto-connect.

## Next Minimal Test Candidate

For future runtime tests, use the proven automatic UI route:

- Start a fresh session with `start-vrising-automation-session.ps1`.
- Include `-SetClientResolution -SetClientWindowMode -ClientWindowMode 3` for
  `1920x1080` Windowed.
- Back up the `11111` save folder first.
- Use Computer Use to reacquire the real `VRising` window and capture the main menu.
- Activate the visible Continue / `11111` entry.
- Capture follow-up screenshots and inspect logs for loading/gameplay progress.
- Run `stop-vrising-automation-session.ps1` and require clean restore/no crash/no
  remaining process.
- Compare the save to the backup and restore it unless the test explicitly needs to
  keep the changed state.

Use
[gameplay-continue-ui-navigation-protocol-2026-06-06.md](gameplay-continue-ui-navigation-protocol-2026-06-06.md)
for pass/fail and cleanup details.
