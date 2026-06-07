# Native RenderFunc Resource Tuple Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

After the menu proof, can the default-off
`native-renderfunc-resource-tuple` preflight safely enter the protected `11111`
gameplay fixture at true `1920x1080` Windowed, format the matched native EASU
`passDataPtr` / managed `EASUData` into tuple metadata, and then restore the
save with no movement or gameplay keyboard input?

## Test Contract

- Stage: `native-renderfunc-resource-tuple`
- Artifact label:
  `native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1`
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Window mode/resolution: `1920x1080` Windowed.
- UI action: one Computer Use click on the visible Chinese Continue / `11111`
  entry area at `(205, 354)` in a `1283x751` Computer Use screenshot.
- Forbidden actions: no movement keys and no gameplay keyboard input.

## Commands

Backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-tuple -ArtifactLabel native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Stop session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.json"
```

Restore save:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Gameplay Entry Evidence

Computer Use selected the real Unity `VRising` window, not the BepInEx console.
The main menu screenshot was `1283x751`, and the visible Chinese Continue /
`11111` entry was clicked once at `(205, 354)`. Five seconds later the game was
on the loading/connecting screen. After about `45` seconds, Computer Use
observed gameplay with quest text, character, health bar, and action bar
visible.

The Computer Use gameplay screenshot included a neighboring window on the right,
so a cropped gameplay screenshot artifact was also saved for review.

No movement keys or gameplay keyboard input were sent.

## Runtime Evidence

Analyzer:

- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Entry=Pass`

Positive evidence:

- first tuple advanced line appeared at `compile=4`;
- `managedPassData=0x2151E640D80`;
- `nativeLastPassData=0x2151E640D80`;
- `passDataMatches=True`;
- `tupleReady=True`;
- pass: `Edge Adaptive Spatial Upsampling`;
- tuple metadata:
  `input=1920x1080`,
  `output=1920x1080`,
  `source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"`,
  `destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"`;
- final tuple status reached `#900` with `entryCount=897` and
  `sampleCount=897`;
- final argument status reached `entryCount=1032`, `sampleCount=1032`, and all
  four raw pointer categories nonzero `1032/1032`;
- final entry status reached `entryCount=1032` and `observations=1034`.

Negative evidence:

- `CrashEventCount=0`
- `RenderGraph GetTexture call #=0`
- `DLSS user rendering evaluate succeeded=0`
- `DLSS super-resolution evaluate succeeded=0`
- `DLSS frame-sequence evaluate succeeded=0`
- `DLSS runtime probe succeeded=0`
- `Native render-func entry probe failed=0`
- `Native render-func resource tuple data=not found=0`
- access-violation text patterns: `0`

The player log confirmed the requested launch shape:

- `-windowed`
- `-screen-width 1920`
- `-screen-height 1080`
- `-force-d3d11`
- `SetResolution 1920, 1080, fullScreenMode Windowed`

It also confirmed local `11111` fixture entry through the known save id:

- `Found GameConnect Data! ServerSaveName: f0e07524-03f4-4ef4-945c-b1f7e982071b`
- `ClientSteamTransport.Connect - ConnectAddress: SteamIPv4://127.0.0.1:9876`
- `Instantiating Loaded UI Prefab. GameObject: HUDCanvas`

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
- `EnableNativeRenderFuncResourceTupleProbe=false`
- `EnableRenderGraphGetTextureProbe=true`
- `EnableHookProbe=true`
- `EnableDLSS=false`

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.jpg`
- `artifacts/gameplay-automation/GameplayScreenshotCropped-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1.json`

## Interpretation

This proves protected gameplay safety for tuple metadata at the focused native
EASU render-func boundary. It still does not prove actual texture/resource
resolution, command-buffer availability, or DLSS evaluate safety.

Next engineering step: design the first separately guarded resource-resolution
preflight, using this proven native render-func tuple metadata as the locator.
Keep it default-off and menu-first. Do not add command-buffer access or DLSS
evaluate in the same step.
