# Native RenderFunc Entry Gameplay Result - 2026-06-06

Status: protected `11111` gameplay proof passed.

## Question

After the menu proof, can the default-off `native-renderfunc-entry` no-op probe
survive real protected `11111` gameplay at true `1920x1080` Windowed, count EASU
render-function entries, and immediately call the original trampoline without
crashing or touching RenderGraph resources?

## Test Protocol

- Game path: `C:\Software\VRising`
- Stage: `native-renderfunc-entry`
- Artifact label: `native-renderfunc-entry-gameplay-1080p-20260606-r1`
- Window: true `1920x1080` Windowed
- Graphics API: D3D11
- Save fixture:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Save backup before launch:
  `artifacts/gameplay-automation/SaveBackup-native-renderfunc-entry-gameplay-1080p-20260606-r1.zip`
- UI automation: Computer Use selected the real `VRising` Unity window and
  clicked the known Chinese Continue / `11111` entry once.
- No movement or gameplay keys were sent.

## Commands

Backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-entry-gameplay-1080p-20260606-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-entry -ArtifactLabel native-renderfunc-entry-gameplay-1080p-20260606-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Stop session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-entry-gameplay-1080p-20260606-r1.json"
```

Restore save:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-entry-gameplay-1080p-20260606-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-entry-gameplay-1080p-20260606-r1 -ArchiveCurrent
```

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-entry-gameplay-1080p-20260606-r1.json`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-entry-gameplay-1080p-20260606-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-entry-gameplay-1080p-20260606-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-entry-gameplay-1080p-20260606-r1.log`
- `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-entry-gameplay-1080p-20260606-r1.png`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-entry-gameplay-1080p-20260606-r1.json`
- `artifacts/gameplay-automation/SaveCompare-native-renderfunc-entry-gameplay-1080p-20260606-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-entry-gameplay-1080p-20260606-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-entry-gameplay-1080p-20260606-r1.json`

## Runtime Evidence

Analyzer:

- `Native RenderFunc Entry=Pass`
- evidence:
  `Native render-func entry count advanced: entryCount=1; pass="Edge Adaptive Spatial Upsampling"; candidatePointer=0x7FF8973EE1C0`

Log summary:

- candidate observed lines: `82`
- status lines: `142`
- detour installed lines: `1`
- count advanced lines: `1`
- probe failed lines: `0`
- `RenderGraph GetTexture call #` lines: `0`
- crash-like lines: `0`
- final status line: `entryCount=776`, `observations=778`,
  `candidatePointer=0x7FF8973EE1C0`

Player log:

- `Forcing GfxDevice: Direct3D 11`
- `graphicsDeviceType: Direct3D11`
- `SetResolution 1920, 1080, fullScreenMode Windowed`
- local server process started for save
  `f0e07524-03f4-4ef4-945c-b1f7e982071b`
- client connected and loaded HUD/gameplay scenes

Screenshot:

- `GameplayScreenshot-native-renderfunc-entry-gameplay-1080p-20260606-r1.png`
  captured the `1920x1080` gameplay HUD/character/minimap.

## Cleanup Evidence

Session cleanup:

- `Status=Pass`
- `CrashEventCount=0`
- `RemainingVRisingProcessCount=0`
- `RestoredClientSettings=True`
- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`

Save protection:

- pre-restore compare detected one autosave rotation:
  `Added AutoSave_24.save.gz`
- restore archived the changed state to
  `SaveAfterRun-native-renderfunc-entry-gameplay-1080p-20260606-r1.zip`
- after-restore compare reported `CompareStatus=Restored` and `ChangeCount=0`

## Interpretation

This proves the no-op native method-pointer detour is stable not only in the
main menu but also in protected `11111` gameplay. It is still only an execution
entry ABI proof.

It does not prove:

- safe pass-data/resource dereference from the native callback;
- safe `RenderGraphContext` or command-buffer access;
- DLSS evaluate safety at this boundary;
- image correctness or performance.

The next narrow engineering step should be a separately default-off
native-entry argument/resource preflight that starts by logging only pointer
presence and type identity from a safe managed observation point. It must keep
`GetTexture=0`, avoid command buffers and NGX evaluate, and start menu-first
again before any gameplay rerun.
