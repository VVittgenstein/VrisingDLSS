# Native RenderFunc Resource Native-Pointer Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

After the menu proof, can the default-off
`native-renderfunc-resource-native-pointer` preflight safely enter the protected
`11111` gameplay fixture at true `1920x1080` Windowed, observe the focused EASU
`source` / `destination` native texture pointers during Unity-owned
`GetTexture(TextureHandle&)` scope, and then restore the save with no movement
or gameplay keyboard input?

## Test Contract

- Stage: `native-renderfunc-resource-native-pointer`
- Artifact label:
  `native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1`
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Window mode/resolution: `1920x1080` Windowed.
- UI action: one Computer Use click on the visible Chinese Continue / `11111`
  entry area at `(205, 354)` in a `1283x751` Computer Use screenshot.
- Forbidden actions: no movement keys and no gameplay keyboard input.
- Expected proof boundary: passive Unity-owned
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix for the
  armed EASU source/destination handles only; no command-buffer access, no D3D11
  validation, no generated render-func Harmony patch, no NGX, and no DLSS
  evaluate.

## Commands

Backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-native-pointer -ArtifactLabel native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Stop session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.json"
```

Restore save:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Gameplay Entry Evidence

Computer Use selected the real Unity `VRising` window, not the BepInEx console.
The main menu screenshot was `1283x751`, and the visible Chinese Continue /
`11111` entry was clicked once at `(205, 354)`. Five seconds later the game was
on the server-start/loading screen.

After about `45` seconds, the first screenshot returned a stale/crossed capture
of Codex rather than the game. No input was sent while the capture was
ambiguous. Computer Use refreshed the app list, reselected
`process:C:\Software\VRising\VRising.exe`, rehydrated the `VRising` window, and
then captured gameplay with quest text, character, minimap, health bar, and
action bar visible.

No movement keys or gameplay keyboard input were sent.

The saved gameplay screenshot artifact is:

`artifacts\gameplay-automation\ComputerUseGameplay-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.jpg`

## Runtime Evidence

Analyzer:

- `Native RenderFunc Resource Native Pointer=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Entry=Pass`
- `Stage 4 Native Bridge=Pass`
- DLSS evaluate/input/output/write-back/user-rendering stages stayed `Missing`.
- `Stage 5B D3D11 Texture=Missing`, as expected for this no-D3D11 preflight.

Positive evidence:

- GetTexture postfix patched:
  `RenderGraphResourceRegistry.GetTexture(TextureHandle& handle) -> RTHandle`;
- first native-pointer advanced line appeared at `frame=4`;
- `targetCompile=4`;
- `targetManagedPassData=0x1BF14614660`;
- tuple metadata:
  `input=1920x1080`,
  `output=1920x1080`,
  `source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"`,
  `destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"`;
- source:
  `nativePtr=0x1C09CF519A0`,
  `UnityEngine.Texture name=Apply Exposure Destination_1920x1080_B10G11R11_UFloatPack32_Tex2DArray_dynamic`,
  result `RTHandle name=Uber Post Destination`;
- destination:
  `nativePtr=0x1C09D040620`,
  `UnityEngine.Texture name=Edge Adaptive Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32_Tex2DArray`,
  result `RTHandle name=Edge Adaptive Spatial Upsampling`.

Focused counts:

- `Frame resource RenderGraph GetTexture postfix patched:`: `1`
- `Native render-func resource native-pointer target armed:`: `1`
- `Native render-func resource native-pointer status #`: `4`
- `Native render-func resource native-pointer advanced:`: `1`
- `RenderGraph GetTexture call #`: `0`
- `D3D11 probe`: `0`
- `D3D11 texture probe`: `0`
- `ExecuteDLSS`: `0`
- `NGX`: `0`
- `DLSS user rendering evaluate succeeded`: `0`
- `DLSS super-resolution evaluate succeeded`: `0`
- `DLSS frame-sequence evaluate succeeded`: `0`
- `Native render-func resource native-pointer data=not found`: `0`
- `RenderGraph pass-list logging failed`: `0`
- `Exception`: `0`
- `access violation`: `0`
- `Fatal`: `0`

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

- restore-before compare: `ChangeCount=1`
- only changed save file: added `AutoSave_24.save.gz`
- restore result: `CompareStatus=Restored`
- after-restore compare: `ChangeCount=0`

Local config after cleanup:

- `EnableNativeRenderFuncResourceResolveProbe=false`
- `EnableNativeRenderFuncResourceNativePointerProbe=false`
- `EnableD3D11TextureProbe=false`
- `EnableRenderGraphGetTextureProbe=true`
- `EnableHookProbe=true`
- `EnableDLSS=false`

No V Rising or UnityCrashHandler process remained after cleanup.

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.jpg`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompare-BeforeRestore-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1.json`

## Interpretation

This proves protected gameplay safety for actual native texture-pointer
availability at the focused EASU native render-func boundary. The menu and
protected gameplay proofs now agree: the EASU source/destination handles can be
identified at `CompileRenderGraph(int)` and can be observed as actual `RTHandle`
/ native texture pointers during Unity-owned `GetTexture(TextureHandle&)`
scope.

This is still not a command-buffer or DLSS evaluate proof. The next engineering
step must be a separately guarded preflight for the next official-boundary
question, with its own hypothesis and cleanup plan. Do not combine
command-buffer access, D3D11 validation, or DLSS evaluate with this proof.
