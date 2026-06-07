# Native RenderFunc CommandBuffer DLSS Feature Create + Render Scale Gameplay Result - 2026-06-07

Status: menu smoke and protected gameplay proof passed.

## Question

At the focused HDRP EASU render-func execution boundary, can the mod carry the
already-proven source/output native texture payload through one `ctx.cmd`
plugin event and use the SDK-wrapper native bridge to create and immediately
release one NGX DLSS feature, without evaluating DLSS or writing visible output?

## Stage

`native-renderfunc-commandbuffer-dlss-create-render-scale`

This stage is SDK-wrapper/local-test only. It:

- uses V Rising `FsrQualityMode=Off`;
- forces mod-owned render scale to `0.5` at `1920x1080` Windowed;
- targets the source-aligned `Edge Adaptive Spatial Upsampling` render func;
- sets the focused source/destination native texture pointers as a native
  pending payload;
- issues one plugin event through the live `RenderGraphContext.cmd`;
- validates same-device D3D11 texture dimensions in native code;
- creates/releases/destroys/shuts down one NGX DLSS feature through the
  SDK-wrapper path.

It does not call DLSS evaluate, does not run user rendering, does not write back
to a visible texture, and does not enable broad steady-state
`RenderGraph.GetTexture` diagnostics.

## Menu Smoke

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-commandbuffer-dlss-create-render-scale -ArtifactLabel native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-menu-20260607-r1 -DurationSeconds 90 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080 -UseSdkWrapperNative -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll"
```

Artifacts:

- `artifacts/runtime-logs/LogOutput-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/Analysis-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/Player-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-menu-20260607-r1.log`

Result:

- Analyzer reported `Native RenderFunc CommandBuffer DLSS Feature Create=Pass`.
- Native bridge API version was `15`.
- Game reported `SetResolution 1920, 1080, fullScreenMode Windowed`.
- The feature-create payload set and advanced once.
- Native status consumed the payload with `eventId=260609`, `sameDevice=yes`,
  `source=960x540`, `destination=1920x1080`, and `scale=(2.000x,2.000x)`.
- NGX SDK-wrapper lifecycle status completed:
  `init=0x00000001`, `capability=0x00000001`, `available=1`,
  `create=0x00000001`, `feature=yes`, `release=0x00000001`,
  `destroy=0x00000001`, `shutdown=0x00000001`.
- Counts: feature-create advanced `1`, feature-create set advanced `1`,
  consumed-status lines `90`, create failures `0`, SDK-wrapper-blocked lines
  `0`, `ExecuteDLSS` `0`, `DLSS user rendering` `0`, visible write-back `0`,
  crash/exception/access-violation patterns `0`.
- Cleanup restored loader config, release-safe native DLL, and
  `ClientSettings.json`; no V Rising process remained.

## Protected Gameplay Proof

Protocol:

- Backed up protected save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Confirmed FSR mode was already `Off`.
- Started a bounded automation session at `1920x1080` Windowed with
  SDK-wrapper native and local `nvngx_dlss.dll`.
- Used Computer Use to click `Continue` once from the main menu.
- Sent no keyboard movement input.
- Waited passively after gameplay loaded.
- Stopped the session, restored diagnostic state, archived logs, archived the
  post-run save, and restored the protected save from backup.

Commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-commandbuffer-dlss-create-render-scale -ArtifactLabel native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080 -UseSdkWrapperNative -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.json"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1 -ArchiveCurrent
```

Artifacts:

- `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.json`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.log`
- `artifacts/gameplay-automation/SaveBackup-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1.json`

Result:

- Analyzer reported `Native RenderFunc CommandBuffer DLSS Feature Create=Pass`,
  `Stage 2C Render-Scale Control Probe=Pass`, `Native RenderFunc Context=Pass`,
  `Native RenderFunc Resource Tuple=Pass`, and
  `Native RenderFunc Resource Native Pointer=Pass`.
- Native bridge API version was `15`.
- Gameplay logs showed `actualWidth=960`, `actualHeight=540`,
  `finalViewport=1920x1080`, `GetCurrentScale=0.5`, and
  `GetResolvedScale=(0.50, 0.50)`.
- The feature-create payload set once with source pointer
  `0000019D22E25120`, destination pointer `0000019D22F148E0`, and then
  consumed once from event `260609`.
- Native callback status showed `sameDevice=yes`, `source=960x540 fmt=26`,
  `destination=1920x1080 fmt=26`, and `scale=(2.000x,2.000x)`.
- NGX SDK-wrapper lifecycle status completed:
  `init=0x00000001`, `capability=0x00000001`, `available=1`,
  `create=0x00000001`, `feature=yes`, `release=0x00000001`,
  `destroy=0x00000001`, `shutdown=0x00000001`.
- Counts: feature-create advanced `1`, feature-create set advanced `1`,
  consumed-status lines `111`, create failures `0`, SDK-wrapper-blocked lines
  `0`, resource tuple advanced `1`, resource native-pointer advanced `1`,
  broad `RenderGraph GetTexture call #` `0`, `ExecuteDLSS` `0`,
  `DLSS user rendering` `0`, visible write-back `0`,
  crash/exception/access-violation patterns `0`.
- Stop-session cleanup passed with `CrashEventCount=0`,
  `RestoredClientSettings=True`, `RestoredLoaderConfig=True`,
  `RestoredReleaseSafeNative=True`, and `RemainingVRisingProcessCount=0`.
- Save restore reported `BeforeChangeCount=1` and final `ChangeCount=0`.

## Interpretation

This proves that the source/decompilation-guided EASU execution window can carry
the focused source/output texture payload through a real command-buffer plugin
event and perform a complete NGX DLSS feature create/release lifecycle on the
same D3D11 device, using the runtime dimensions `960x540 -> 1920x1080`.

It still does not prove DLSS evaluate, depth/motion-vector resource capture,
resize/reset handling, visible correctness, legal distribution of a runtime
DLL, or performance. The next source-guided guard should decide how to add
depth and motion-vector payloads or a strictly bounded no-write evaluate
preflight without returning to broad `GetTexture` discovery or direct
`DLSSPass.Render(...)` patching.
