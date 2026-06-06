# Native RenderFunc Args Gameplay Result - 2026-06-06

Status: protected `11111` gameplay proof passed.

## Question

After the menu proof, can the default-off `native-renderfunc-args` preflight
survive real protected `11111` gameplay at true `1920x1080` Windowed, sample raw
callback argument pointer values, and immediately call the original trampoline
without crashing, hot `GetTexture` discovery, command-buffer access, or DLSS
evaluate?

## Test Protocol

- Game path: `C:\Software\VRising`
- Stage: `native-renderfunc-args`
- Artifact label: `native-renderfunc-args-gameplay-1080p-20260606-r1`
- Window: true `1920x1080` Windowed
- Graphics API: D3D11
- Save fixture:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Save backup before launch:
  `artifacts/gameplay-automation/SaveBackup-native-renderfunc-args-gameplay-1080p-20260606-r1.zip`
- UI automation: Computer Use selected the real `VRising` Unity window and
  clicked the known Chinese Continue / `11111` entry once at `(205, 354)` in the
  current `1283x751` Computer Use screenshot.
- No movement or gameplay keys were sent.

## Commands

Backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-args-gameplay-1080p-20260606-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-args -ArtifactLabel native-renderfunc-args-gameplay-1080p-20260606-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Stop session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-args-gameplay-1080p-20260606-r1.json"
```

Restore save:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-args-gameplay-1080p-20260606-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-args-gameplay-1080p-20260606-r1 -ArchiveCurrent
```

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-args-gameplay-1080p-20260606-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-args-gameplay-1080p-20260606-r1.json`
- `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-args-gameplay-1080p-20260606-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-args-gameplay-1080p-20260606-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-args-gameplay-1080p-20260606-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-args-gameplay-1080p-20260606-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-args-gameplay-1080p-20260606-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-args-gameplay-1080p-20260606-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-args-gameplay-1080p-20260606-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-args-gameplay-1080p-20260606-r1.json`

## Runtime Evidence

Analyzer:

- `Native RenderFunc Args=Pass`
- `Native RenderFunc Entry=Pass`
- evidence:
  `Native render-func argument sample advanced: sampleCount=1; nonzeroThis=1; nonzeroPassData=1; nonzeroContext=1; nonzeroMethodInfo=1; lastThis=0x2881D5F8E60; lastPassData=0x2881D9629C0; lastContext=0x2881E25E0C0; lastMethodInfo=0x287097EAFE0; pass="Edge Adaptive Spatial Upsampling"`

Log summary:

- candidate observed lines: `82`
- entry status lines: `132`
- argument status lines: `132`
- detour installed lines: `1`
- entry count advanced lines: `1`
- argument sample advanced lines: `1`
- probe failed lines: `0`
- `RenderGraph GetTexture call #` lines: `0`
- crash-like lines: `0`
- exception-like lines: `0`
- actual NGX/DLSS evaluate/probe/native-call patterns: `0`

Final focused status:

```text
Native render-func entry status #15600: compile=15600; installed=True; entryCount=841; observations=843; candidatePointer=0x7FF85E8AE1C0; pass="Edge Adaptive Spatial Upsampling"; methodName=unknown; declaringType=unknown; reflectedType=unknown; metadataToken=unknown
Native render-func argument status #15600: compile=15600; installed=True; entryCount=841; sampleCount=841; nonzeroThis=841; nonzeroPassData=841; nonzeroContext=841; nonzeroMethodInfo=841; lastThis=0x2881D5F8E60; lastPassData=0x2881D9629C0; lastContext=0x2881E25E0C0; lastMethodInfo=0x287097EAFE0; candidatePointer=0x7FF85E8AE1C0; pass="Edge Adaptive Spatial Upsampling"
```

Player log:

- command line included `-windowed -screen-width 1920 -screen-height 1080 -screen-fullscreen 0 -force-d3d11`;
- `SetResolution 1920, 1080, fullScreenMode Windowed`;
- local server process started for save
  `f0e07524-03f4-4ef4-945c-b1f7e982071b`;
- client loaded `HudSubScene`, instantiated `HUDCanvas`, and spawned the HUD chat
  window.

Screenshot:

- `GameplayScreenshot-native-renderfunc-args-gameplay-1080p-20260606-r1.png`
  captured the stable `1920x1080` gameplay HUD/character/minimap view.

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
  `SaveAfterRun-native-renderfunc-args-gameplay-1080p-20260606-r1.zip`
- after-restore compare reported `CompareStatus=Restored` and `ChangeCount=0`

## Interpretation

This proves the raw-argument sampling preflight is stable not only in the main
menu but also in protected `11111` gameplay. It extends the prior
`native-renderfunc-entry` gameplay proof by showing the callback receives
nonzero raw pointer values for `thisPtr`, `passDataPtr`,
`renderGraphContextPtr`, and `methodInfoPtr` throughout gameplay.

It does not prove:

- safe pointer dereference;
- pass-data or `RenderGraphContext` layout;
- safe resource identity extraction;
- command-buffer access;
- DLSS evaluate safety at this boundary;
- image correctness or performance.

The preflight still does not resolve resources, call `GetTexture`, touch command
buffers, load DLSS, or evaluate DLSS.

## Next Step

Design a separate default-off resource-identity preflight from this raw argument
evidence. It must not dereference pointers in the native callback, must avoid
command-buffer access and DLSS evaluate, and should start menu-first before any
protected gameplay rerun.
