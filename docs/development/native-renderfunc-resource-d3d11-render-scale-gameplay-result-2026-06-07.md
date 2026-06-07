# Native RenderFunc Resource D3D11 + Render Scale Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

When V Rising's built-in `FsrQualityMode` is `Off` and the mod-owned
`RenderScaleControlProbe` forces Performance scale, can the proven EASU
`source` / `destination` native pointers be validated by the native bridge as
a same-device D3D11 texture pair with the expected Super Resolution shape?

Expected shape:

```text
source=960x540; destination=1920x1080; sameDevice=yes
```

This run must not initialize NGX, evaluate DLSS, access a command buffer, or
fall back to broad RenderGraph `GetTexture` discovery.

## Setup

- V Rising `FsrQualityMode`: `Off`.
- Resolution/window mode: true `1920x1080` Windowed.
- Stage: `native-renderfunc-resource-d3d11-render-scale`.
- Native bridge API version observed in game log: `13`.
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Artifact label:
  `native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1`.

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableNativeRenderFuncResourceD3D11Probe=true`
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
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-resource-d3d11-render-scale -ArtifactLabel native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\capture-vrising-window.ps1 -ArtifactLabel native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1-gameplay -OutputPath artifacts\gameplay-automation\CaptureGameplay-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.png -WindowTitlePattern "^VRising$" -Method Auto
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.json"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Automation Notes

- Computer Use selected the real `VRising` Unity window, not the BepInEx
  console.
- A transient Node REPL top-level binding name conflict happened while listing
  apps; it was recovered with block-local variables and did not require a reset.
- The main-menu screenshot was `1283x751`; the Chinese Continue entry was
  clicked once at `(199,352)`.
- The click went straight to the loading screen; no save-list interaction was
  needed.
- After about `60` seconds, Computer Use observed gameplay with HUD, quest
  text, character, minimap, health bar, and action bar visible.
- No keyboard, movement, or gameplay keys were sent.
- Player log confirmed local gameplay entry:
  - `SetResolution 1920, 1080, fullScreenMode Windowed`
  - `Found GameConnect Data! ServerSaveName: f0e07524-03f4-4ef4-945c-b1f7e982071b`
  - `ClientSteamTransport.Connect - ConnectAddress: SteamIPv4://127.0.0.1:9876`
  - `Instantiating Loaded UI Prefab. GameObject: HUDCanvas`
  - `Created Camera TopDownCamera`
  - `Assigned Camera TopDownCamera to LocalUser`
- A passive window capture helper produced a valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.png`.

## Result

Pass.

- Analyzer: `Native RenderFunc Resource D3D11=Pass`
- Analyzer: `Native RenderFunc Resource Native Pointer=Pass`
- Analyzer: `Native RenderFunc Resource Tuple=Pass`
- Analyzer: `Native RenderFunc Resource Identity=Pass`
- Analyzer: `Native RenderFunc Args=Pass`
- Analyzer: `Native RenderFunc Entry=Pass`
- Analyzer: `Stage 2C Render-Scale Control Probe=Pass`
- Analyzer: `Stage 4 Native Bridge=Pass`
- `Native bridge API version: 13`
- `Native render-func resource D3D11 pair advanced:` `1`
- `Native render-func resource D3D11 pair failed:` `0`
- `D3D11 texture pair probe rejected:` `0`
- `Native render-func resource native-pointer advanced:` `1`
- `tuple=input=960x540; output=1920x1080`: `268`
- `tuple=input=1920x1080; output=1920x1080`: `0`
- `actualWidth=960,actualHeight=540`: `486`
- `GetCurrentScale=0.5`: `31`
- `GetResolvedScale=(0.50, 0.50)`: `31`
- broad `RenderGraph GetTexture call #`: `0`
- `ExecuteDLSS`: `0`
- `NGX` / `nvngx`: `0`
- DLSS evaluate success patterns: `0`
- `CrashEventCount=0`

The advanced line:

```text
Native render-func resource D3D11 pair advanced:
source=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; nativePtr=0x1A4A4B2DD20; nativeOwner=UnityEngine.Texture name=Apply Exposure Destination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic width=960 height=540 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Uber Post Destination; frame=4)
destination=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"; nativePtr=0x1A4A4B30660; nativeOwner=UnityEngine.Texture name=Edge Adaptive Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32_Tex2DArray width=1920 height=1080 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Edge Adaptive Spatial Upsampling; frame=4)
targetCompile=4; targetManagedPassData=0x1A31C235C00; tuple=input=960x540; output=1920x1080
D3D11 texture pair probe succeeded; sameDevice=yes; source=960x540 fmt=26 mips=1 array=1; destination=1920x1080 fmt=26 mips=1 array=1; scale=(2.000x,2.000x)
```

## Cleanup

`stop-vrising-automation-session.ps1` returned `Status=Pass`:

- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- `RemainingVRisingProcessCount=0`
- `CrashEventCount=0`

Save restore:

- Before restore: `BeforeChangeCount=1`
- `CompareStatus=Restored`
- `ChangeCount=0`

Local game config after cleanup returned to loader-safe defaults:

- `EnableDLSS=false`
- `EnableNativeRenderFuncResourceD3D11Probe=false`
- `EnableNativeRenderFuncResourceNativePointerProbe=false`
- `EnableRenderScaleControlProbe=false`
- `EnableHookProbe=true`

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1.json`

## Interpretation

This proves the strongest resource-level precondition so far: under mod-owned
render scale, the focused EASU pass exposes a low-resolution source native
texture and a full-resolution output native texture that are both valid D3D11
resources on the same device.

It still does not prove a safe command-buffer/evaluate boundary, NGX feature
lifetime, resize/reset handling, or visual/performance correctness. The next
guard should stay source/decompilation-guided and move one boundary closer to
official HDRP DLSS execution: inspect or patch only an equivalent of
`DoDLSSPass -> DLSSPass.GetCameraResources -> DLSSPass.Render(..., ctx.cmd)`,
with command-buffer access tested separately before any real DLSS evaluate.
