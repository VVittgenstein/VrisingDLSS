# Native RenderFunc Resource Identity Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

After the menu proof, can the default-off
`native-renderfunc-resource-identity` preflight safely enter the protected
`11111` gameplay fixture at true `1920x1080` Windowed, correlate the raw native
EASU render-func `passDataPtr` with managed `EASUData` / TextureHandle identity,
and then restore the save with no gameplay movement keys?

## Test Contract

- Stage: `native-renderfunc-resource-identity`
- Artifact label:
  `native-renderfunc-resource-identity-gameplay-1080p-20260607-r1`
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Window mode/resolution: `1920x1080` Windowed.
- UI action: one Computer Use click on the visible Chinese Continue / `11111`
  entry area at `(205, 354)` in a `1283x751` Computer Use screenshot.
- Forbidden actions: no movement keys and no gameplay keyboard input.

## Commands

Backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-identity-gameplay-1080p-20260607-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-resource-identity -ArtifactLabel native-renderfunc-resource-identity-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Stop session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.json"
```

Restore save:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-identity-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Gameplay Entry Evidence

Computer Use selected the real Unity `VRising` window, not the BepInEx console.
The main menu screenshot was `1283x751`, and the visible Chinese Continue label
was clicked once at `(205, 354)`. Five seconds later the screenshot showed the
loading screen (`服务器正在启动`). After about `45` seconds, Computer Use observed
gameplay with quest text, character, HUD, health bar, and action bar visible.

No movement keys or gameplay keyboard input were sent.

The original Computer Use screenshot included part of a neighboring Chrome
window on the right; a cropped artifact keeps only the visible V Rising gameplay
region for review.

## Runtime Evidence

Analyzer:

- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Entry=Pass`

Positive evidence:

- first advanced line appeared at `compile=4`;
- `managedPassData=0x166A6073300`;
- `nativeLastPassData=0x166A6073300`;
- `passDataMatches=True`;
- `hasTextureIdentity=True`;
- pass: `Edge Adaptive Spatial Upsampling`;
- focused managed members included `source:texture` and `destination:texture`
  ResourceHandles;
- final resource-identity status line reached `#900` with `entryCount=897` and
  `sampleCount=897`;
- final entry/argument status lines reached `entryCount=1072`,
  `sampleCount=1072`, and all four raw pointer categories nonzero `1072/1072`.

Negative evidence:

- `CrashEventCount=0`
- `RenderGraph GetTexture call #=0`
- actual native/DLSS evaluate patterns: `0`
- actual DLSS probe/native-call patterns: `0`
- `probe failed`, `data=not found`, or logging failure patterns: `0`
- crash/exception/access-violation/fatal patterns: `0`

## Cleanup

`stop-vrising-automation-session.ps1` returned `Status=Pass`:

- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- `RemainingVRisingProcessCount=0`
- `CrashEventCount=0`

Save restore:

- `BeforeChangeCount=1`
- `CompareStatus=Restored`
- `ChangeCount=0`

Local config after cleanup:

- `EnableNativeRenderFuncEntryProbe=false`
- `EnableNativeRenderFuncArgumentProbe=false`
- `EnableNativeRenderFuncResourceIdentityProbe=false`
- `EnableRenderGraphGetTextureProbe=true`
- `EnableHookProbe=true`
- `EnableDLSS=false`

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/GameplayScreenshotCropped-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-identity-gameplay-1080p-20260607-r1.json`

## Interpretation

This proves protected gameplay safety for the resource-identity correlation
preflight. It still does not prove command-buffer access, actual texture/resource
resolution, or DLSS evaluate safety.

Next engineering step: decide whether the proven managed EASU pass-data and
TextureHandle identity can support a separate, default-off
official-boundary-adjacent resource preflight. Do not add command-buffer access
or DLSS evaluate without another explicit preflight and cleanup contract.
