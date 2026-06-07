# Native RenderFunc Resource Native Pointer + Render Scale Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

When V Rising's built-in `FsrQualityMode` is `Off` and the mod-owned
`RenderScaleControlProbe` forces Performance scale, can the focused EASU
`source` / `destination` handles observe actual non-zero native texture
pointers while the EASU tuple remains:

```text
input=960x540; output=1920x1080
```

## Hypothesis

Yes. The prior combined render-scale tuple proof showed the focused EASU
render func reports low-input/full-output sizing, and the combined
resource-resolve proof showed those handles resolve to `TextureResource`
metadata. The next narrow step is to observe only Unity-owned
`GetTexture(TextureHandle&)` postfix returns for those same handles, without a
broad resource discovery loop.

This run must not run D3D11 validation, issue command-buffer work, initialize
NGX, or evaluate DLSS.

## Setup

- V Rising `FsrQualityMode`: `Off`.
- Resolution/window mode: true `1920x1080` Windowed.
- Stage: `native-renderfunc-resource-native-pointer-render-scale`.
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Artifact label:
  `native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1`.

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableUpscalerStateProbe=true`
- `EnableHookProbe=false`
- `EnableDLSS=false`

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\set-vrising-fsr-mode.ps1 -Mode Off
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-resource-native-pointer-render-scale -ArtifactLabel native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\capture-vrising-window.ps1 -ArtifactLabel native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1 -OutputPath artifacts\gameplay-automation\CaptureGameplay-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.png -WindowTitlePattern "^VRising$" -Method Auto
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.json"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Automation Notes

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- The main-menu screenshot was `1283x751`.
- The visible Chinese Continue / `11111` entry was clicked once at `(205,354)`.
- No keyboard, movement, or gameplay keys were sent.
- Computer Use observed gameplay after about `45` seconds with HUD, quest text,
  character, minimap, health bar, and action bar visible.
- Player log confirmed protected gameplay entry:
  - `SetResolution 1920, 1080, fullScreenMode Windowed`
  - `Found GameConnect Data! ServerSaveName: f0e07524-03f4-4ef4-945c-b1f7e982071b`
  - `ClientSteamTransport.Connect - ConnectAddress: SteamIPv4://127.0.0.1:9876`
  - `Instantiating Loaded UI Prefab. GameObject: HUDCanvas`
  - `Created Camera TopDownCamera`
  - `Assigned Camera TopDownCamera to LocalUser`
- A passive window capture helper also produced a valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.png`.

## Result

Pass.

- Analyzer: `Native RenderFunc Resource Native Pointer=Pass`
- Analyzer: `Native RenderFunc Resource Tuple=Pass`
- Analyzer: `Native RenderFunc Resource Identity=Pass`
- Analyzer: `Native RenderFunc Args=Pass`
- Analyzer: `Native RenderFunc Entry=Pass`
- Analyzer: `Stage 2C Render-Scale Control Probe=Pass`
- `Frame resource RenderGraph GetTexture postfix patched:` `1`
- `Native render-func resource native-pointer target armed:` `1`
- `Native render-func resource native-pointer advanced:` `1`
- `Native render-func resource native-pointer status`: `4`
- `tuple=input=960x540; output=1920x1080`: `229`
- `tuple=input=1920x1080; output=1920x1080`: `0`
- `nativePtr=0x`: `5`
- `GetCurrentScale=0.5`: `31`
- `GetResolvedScale=(0.50, 0.50)`: `31`
- broad `RenderGraph GetTexture call #`: `0`
- D3D11 probe/validation lines: `0`
- NGX/DLSS evaluate/runtime lines: `0`
- source native-pointer zero patterns: `0`
- destination native-pointer zero patterns: `0`
- not-found failure patterns: `0`
- entry/pass-list failure patterns: `0`
- exception/access-violation/fatal patterns: `0`
- `CrashEventCount=0`

The only D3D11/DLSS/evaluate text in the log is startup safety wording that
states what this preflight does not do.

The advanced line:

```text
Native render-func resource native-pointer advanced:
source=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; nativePtr=0x21EA3F0B420; nativeOwner=UnityEngine.Texture name=Apply Exposure Destination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic width=960 height=540 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Uber Post Destination; frame=4)
destination=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"; nativePtr=0x21EA3F111A0; nativeOwner=UnityEngine.Texture name=Edge Adaptive Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32_Tex2DArray width=1920 height=1080 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Edge Adaptive Spatial Upsampling; frame=4)
targetCompile=4; targetManagedPassData=0x21D23086D80; tuple=input=960x540; output=1920x1080
```

The sampled status lines showed three source observations and one destination
observation at the armed target. Source was the `Uber Post Destination`
RTHandle with a `960x540` `Apply Exposure Destination` Unity texture.
Destination was the `Edge Adaptive Spatial Upsampling` RTHandle with a
`1920x1080` Unity texture.

## Cleanup

`stop-vrising-automation-session.ps1` returned `Status=Pass`:

- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- `RemainingVRisingProcessCount=0`
- `CrashEventCount=0`

Save restore:

- `CompareStatus=Restored`
- `ChangeCount=0`

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1.json`

## Interpretation

This proves that, under the same mod-owned render-scale condition that gives
EASU `input=960x540; output=1920x1080`, both focused EASU handles can observe
actual non-zero Unity native texture pointers from engine-owned valid-scope
`GetTexture(TextureHandle&)` returns.

This is stronger than metadata-only `TextureResource` resolution, but still is
not a production evaluate boundary. It does not prove command-buffer ordering,
D3D11 device compatibility, NGX feature lifecycle, or DLSS output correctness.

The practical next step should shift from blind runtime probing to narrow
source/decompilation-guided boundary selection. The runtime evidence now gives
specific symbols and data to look for in local IL2CPP/HDRP decompilation:
`HDRenderPipeline.EASUData`, the EASU render func that consumes the
`Uber Post Destination` source and `Edge Adaptive Spatial Upsampling`
destination, `DoDLSSPasses`, `DoDLSSPass`, and `DLSSPass.Render/ExecuteDLSS`.
Only after that source-guided boundary is understood should a separate guarded
D3D11/device/dimension or command-buffer preflight be added.
