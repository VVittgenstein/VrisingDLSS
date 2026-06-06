# RenderGraph RenderFunc Metadata Gameplay Result - 2026-06-06

Status: protected `11111` gameplay proof passed. This remains read-only metadata
evidence, not an execution-layer hook, not a generated render-function patch, and
not a DLSS evaluate boundary.

## Question

Can the `rendergraph-renderfunc-metadata` probe that passed in the main menu also
run through real local/private `11111` gameplay at true `1920x1080` Windowed,
with no resource resolution, no broad `GetTexture` activity, no movement keys, no
crash, and full save restore?

## Test Contract

Hypothesis:

- The already-proven `CompileRenderGraph(int)` postfix remains safe in gameplay
  when it only reads focused pass `renderFunc` delegate metadata.
- The probe should identify the same generated HDRP pass methods for Uber, EASU,
  and Final passes without invoking them.

Pass signals:

- V Rising starts at true `1920x1080` Windowed.
- Computer Use clicks Continue once for the known `11111` fixture.
- Stable gameplay is reached without movement or gameplay-key input.
- Analyzer reports `RenderGraph RenderFunc Metadata=Pass`.
- Metadata lines are present, with `0` `renderFunc=not found`, `0` metadata
  failures, and `0` broad `RenderGraph GetTexture call #` lines.
- Cleanup closes V Rising, restores loader config and `ClientSettings.json`, and
  records `CrashEventCount=0`.
- Protected save restore reports `ChangeCount=0`.

Fail signals:

- Any WER/coreclr/UnityPlayer crash.
- Failure to enter gameplay or wrong-window/menu-only capture.
- Any metadata not-found/failure line.
- Any broad GetTexture log.
- Any cleanup or save-restore failure.

## Commands

Save backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage rendergraph-renderfunc-metadata -ArtifactLabel rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Computer Use:

- Selected app `process:C:\Software\VRising\VRising.exe`.
- Selected the real game window titled `VRising`, not the BepInEx console.
- Captured the Chinese main menu.
- Clicked the Continue entry once at window-relative `(205, 354)` in the current
  `1283x751` Computer Use screenshot.
- Sent no movement or gameplay keys.

Gameplay screenshot:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\capture-vrising-window.ps1 -OutputPath artifacts\gameplay-automation\GameplayScreenshot-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.png -ProcessName VRising -WaitSeconds 10 -Method Auto
```

Stop session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.json"
```

Save restore:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1 -ArchiveCurrent
```

## Artifacts

- Session JSON:
  `artifacts/gameplay-automation/Session-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.json`
- Cleanup JSON:
  `artifacts/gameplay-automation/Cleanup-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.json`
- BepInEx log:
  `artifacts/gameplay-automation/LogOutput-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.log`
- Analyzer:
  `artifacts/gameplay-automation/Analysis-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.txt`
- Player log:
  `artifacts/gameplay-automation/Player-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.log`
- Menu/session screenshot:
  `artifacts/gameplay-automation/SessionScreenshot-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.png`
- Gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.png`
- Save backup:
  `artifacts/gameplay-automation/SaveBackup-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.zip`
- Archived changed save state:
  `artifacts/gameplay-automation/SaveAfterRun-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.zip`
- Save restore compare:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.json`

## Result

Session and cleanup:

- Start session `Status=Ready`.
- Stop session `Status=Pass`.
- `CrashEventCount=0`.
- `RestoredClientSettings=True`.
- `RestoredLoaderConfig=True`.
- `RestoredReleaseSafeNative=True`.
- `RemainingVRisingProcessCount=0`.

Resolution/gameplay:

- Player log reported `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Player log confirmed local `11111` flow via save
  `f0e07524-03f4-4ef4-945c-b1f7e982071b` and
  `SteamIPv4://127.0.0.1:9876`.
- Gameplay screenshot was `1920x1080`, nonblank, with
  `NearBlackRatio=0.290826`, `NearWhiteRatio=0.000008`, and SHA-256
  `B9D2842A5E3B4A5A15CD0E7CF3744873EFCFCD3D7B4C1C7F56D989BA3EC6B98A`.

Analyzer summary:

- `Stage 4 Native Bridge=Pass`.
- `Stage 2B Upscaler State Probe=Pass`.
- `RenderGraph RenderFunc Metadata=Pass`.

Focused log counts:

- `RenderGraph pass render-func metadata #`: `300`.
- `RenderGraph pass render-func metadata renderFunc=not found`: `0`.
- metadata typed-read/logging failures: `0`.
- `RenderGraph GetTexture call #`: `0`.
- `<UberPass>b__1060_0`: `76`.
- `<EdgeAdaptiveSpatialUpsampling>b__1066_0`: `75`.
- `<FinalPass>b__1069_0`: `149`.

Save protection:

- Before restore, gameplay entry changed `1` save-manifest item.
- The changed state was archived.
- After restore, `SaveCompareAfterRestore` reported
  `CompareStatus=Restored` and `ChangeCount=0`.

Release-safe state after cleanup:

- No `VRising` process remained.
- `Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe=false`.
- `Diagnostics.EnableNativeBridgeSmokeTest=false`.
- `Diagnostics.EnableHookProbe=true`.
- `DLSS.EnableDLSS=false`.

## Decision

Accept `rendergraph-renderfunc-metadata` as proven menu-safe and
protected-gameplay-safe for this local V Rising build.

This still does not prove a safe execution-time hook, resource-resolution window,
or evaluate boundary. It proves only that the safe `CompileRenderGraph(int)`
observation point can map the focused pass names to their generated render
function method identities in gameplay without causing the earlier generated
render-func patch crashes.

Do not rerun this stage unchanged. Do not patch generated render funcs from this
evidence alone. The next useful route is a new local source/interop design step
for a safer equivalent to the official HDRP execution boundary, using these
method identities and the earlier pass declaration/data chain as maps.
