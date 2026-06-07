# Native RenderFunc Resource Resolve Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

After the menu proof, can the default-off
`native-renderfunc-resource-resolve` preflight safely enter the protected
`11111` gameplay fixture at true `1920x1080` Windowed, resolve the focused EASU
`source` / `destination` handles to RenderGraph `TextureResource` metadata, and
then restore the save with no movement or gameplay keyboard input?

## Test Contract

- Stage: `native-renderfunc-resource-resolve`
- Artifact label:
  `native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1`
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Window mode/resolution: `1920x1080` Windowed.
- UI action: one Computer Use click on the visible Chinese Continue / `11111`
  entry area at `(205, 354)` in a `1283x751` Computer Use screenshot.
- Forbidden actions: no movement keys and no gameplay keyboard input.
- Expected proof boundary: `GetTextureResource(ResourceHandle&)` metadata only;
  no `GetTexture(TextureHandle&)`, native texture pointer reads, D3D11 texture
  validation, command-buffer access, generated render-func Harmony patch, NGX, or
  DLSS evaluate.

## Commands

Backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-resolve -ArtifactLabel native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Stop session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.json"
```

Restore save:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Gameplay Entry Evidence

Computer Use selected the real Unity `VRising` window, not the BepInEx console.
The main menu screenshot was `1283x751`, and the visible Chinese Continue /
`11111` entry was clicked once at `(205, 354)`. Five seconds later the game was
on the loading/local-server startup screen. After `45` seconds, Computer Use
observed gameplay with quest text, character, minimap, health bar, and action
bar visible.

No movement keys or gameplay keyboard input were sent.

The saved gameplay screenshot artifact is:

`artifacts\gameplay-automation\ComputerUseGameplay-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.jpg`

## Runtime Evidence

Analyzer:

- `Native RenderFunc Resource Resolve=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Entry=Pass`
- `Stage 4 Native Bridge=Pass`
- DLSS evaluate/input/output/write-back/user-rendering stages stayed `Missing`.
- `Stage 5B D3D11 Texture=Missing`, as expected for this no-native-texture
  preflight.

Positive evidence:

- first resolve advanced line appeared at `compile=4`;
- `managedPassData=0x19821F412A0`;
- `nativeLastPassData=0x19821F412A0`;
- `passDataMatches=True`;
- `tupleReady=True`;
- `resourceReady=True`;
- `graphicsReady=False`;
- pass: `Edge Adaptive Spatial Upsampling`;
- tuple metadata:
  `input=1920x1080`,
  `output=1920x1080`,
  `source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"`,
  `destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"`;
- source resolve:
  `textureResourceReady=True`, `graphicsResourceReady=False`,
  `GetTextureResource returned TextureResource; graphicsResource=null`;
- destination resolve:
  `textureResourceReady=True`, `graphicsResourceReady=False`,
  `GetTextureResource returned TextureResource; graphicsResource=null`.

Focused counts:

- `Native render-func resource resolve advanced:`: `1`
- `Native render-func resource resolve status #`: `82`
- `resourceReady=True`: `80`
- `textureResourceReady=True`: `80`
- `graphicsReady=True`: `0`
- `graphicsReady=False`: `83`
- `RenderGraph GetTexture call #`: `0`
- `Native texture validation`: `0`
- `D3D11 texture probe`: `0`
- `ExecuteDLSS`: `0`
- `NGX`: `0`
- `Native render-func resource resolve data=not found`: `0`
- `RenderGraph pass-list logging failed`: `0`
- `failed`: `0`
- `Exception`: `0`
- `access violation`: `0`
- `Fatal`: `0`

`DLSS evaluate` appeared only inside startup warning text that describes what
the preflight does not do; there was no `ExecuteDLSS`, NGX, DLSS runtime probe,
or DLSS evaluate stage pass.

The player log confirmed the requested launch shape:

- `-windowed`
- `-screen-width 1920`
- `-screen-height 1080`
- `-force-d3d11`
- `SetResolution 1920, 1080, fullScreenMode Windowed`

It also confirmed local `11111` fixture entry through the known save id:

- `Found GameConnect Data! ServerSaveName: f0e07524-03f4-4ef4-945c-b1f7e982071b`
- `Found GameConnect Data! Address: SteamIPv4://127.0.0.1:9876 ServerSaveName: f0e07524-03f4-4ef4-945c-b1f7e982071b`
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
- `EnableNativeRenderFuncResourceResolveProbe=false`
- `EnableRenderGraphGetTextureProbe=true`
- `EnableHookProbe=true`
- `EnableDLSS=false`

No V Rising or UnityCrashHandler process remained after cleanup.

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.jpg`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1.json`

## Interpretation

This proves protected gameplay safety for `TextureResource` metadata resolution
at the focused EASU native render-func boundary. The result matches the menu
proof: both focused handles resolve to `TextureResource`, but both still have
`graphicsResource=null`.

Do not treat this as actual native texture-pointer proof. The next engineering
step is to design a separately guarded actual native texture-pointer preflight,
or prove from local source/metadata that no safe equivalent boundary exists.
That next step must remain default-off and must not combine command-buffer access
or DLSS evaluate in the same change.
