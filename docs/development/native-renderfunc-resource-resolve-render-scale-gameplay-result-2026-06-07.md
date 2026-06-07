# Native RenderFunc Resource Resolve + Render Scale Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

When V Rising's built-in `FsrQualityMode` is `Off` and the mod-owned
`RenderScaleControlProbe` forces Performance scale, can the focused EASU
`source` / `destination` handles resolve to RenderGraph `TextureResource`
metadata while the EASU tuple remains:

```text
input=960x540; output=1920x1080
```

## Hypothesis

Yes. The ordinary `native-renderfunc-resource-resolve` proof showed the focused
EASU handles can resolve to `TextureResource` metadata at the native render-func
boundary, and the prior `native-renderfunc-resource-tuple-render-scale` proof
showed the same EASU boundary reports low-input/full-output sizing under
render-scale.

This run must not call broad `RenderGraphResourceRegistry.GetTexture`, read
native texture pointers, validate D3D11 textures, issue command-buffer work,
load NGX, or evaluate DLSS.

## Setup

- V Rising `FsrQualityMode`: `Off`.
- Resolution/window mode: true `1920x1080` Windowed.
- Stage: `native-renderfunc-resource-resolve-render-scale`.
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Artifact label:
  `native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1`.

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceResolveProbe=true`
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
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-resource-resolve-render-scale -ArtifactLabel native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\capture-vrising-window.ps1 -ArtifactLabel native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1 -OutputPath artifacts\gameplay-automation\CaptureGameplay-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.png -WindowTitlePattern "^VRising$" -Method Auto
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.json"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
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
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.png`.

## Result

Pass.

- Analyzer: `Native RenderFunc Resource Resolve=Pass`
- Analyzer: `Native RenderFunc Resource Tuple=Pass`
- Analyzer: `Native RenderFunc Resource Identity=Pass`
- Analyzer: `Native RenderFunc Args=Pass`
- Analyzer: `Native RenderFunc Entry=Pass`
- Analyzer: `Stage 2C Render-Scale Control Probe=Pass`
- First resolve advanced line appeared at `compile=4`.
- Resolve advanced lines: `1`
- Resolve status lines: `107`
- `tuple=input=960x540; output=1920x1080`: `216`
- `tuple=input=1920x1080; output=1920x1080`: `0`
- `resourceReady=True`: `104`
- `textureResourceReady=True`: `104`
- `graphicsReady=True`: `0`
- `graphicsReady=False`: `108`
- `GetCurrentScale=0.5`: `31`
- `GetResolvedScale=(0.50, 0.50)`: `31`
- `RenderGraph GetTexture call #`: `0`
- actual native texture pointer read patterns: `0`
- D3D11 probe/validation patterns: `0`
- NGX/DLSS/evaluate patterns: `0`
- resolve failure patterns: `0`
- access-violation text patterns: `0`
- `CrashEventCount=0`

One log line contains the phrase "read native texture pointers" only inside the
startup warning that describes what this preflight does not do:

```text
Native render-func resource resolve preflight enabled... it does not call GetTexture, read native texture pointers, touch command buffers, or evaluate DLSS.
```

The first advanced line:

```text
Native render-func resource resolve advanced: compile=4; sampleCount=1; managedPassData=0x1BB1ACDBDE0; nativeLastPassData=0x1BB1ACDBDE0; passDataMatches=True; tupleReady=True; resourceReady=True; graphicsReady=False; pass="Edge Adaptive Spatial Upsampling"; tuple=input=960x540; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"; resolve=source=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; textureResourceReady=True; graphicsResourceReady=False; details="renderGraph.m_Resources.GetTextureResource returned UnityEngine.Experimental.Rendering.RenderGraphModule.TextureResource; graphicsResource=null"); destination=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"; textureResourceReady=True; graphicsResourceReady=False; details="renderGraph.m_Resources.GetTextureResource returned UnityEngine.Experimental.Rendering.RenderGraphModule.TextureResource; graphicsResource=null")
```

The final sampled status remained the same shape:

```text
Native render-func resource resolve status #8100: compile=9476; entryCount=8097; sampleCount=8097; passDataMatches=True; tupleReady=True; resourceReady=True; graphicsReady=False; pass="Edge Adaptive Spatial Upsampling"; tuple=input=960x540; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=87"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=88"; resolve=source=(textureResourceReady=True; graphicsResourceReady=False; graphicsResource=null); destination=(textureResourceReady=True; graphicsResourceReady=False; graphicsResource=null)
```

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

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-resolve-render-scale-gameplay-1080p-20260607-r1.json`

## Interpretation

This proves that, under the same mod-owned render-scale condition that gives
EASU `input=960x540; output=1920x1080`, both focused EASU handles can resolve
to RenderGraph `TextureResource` metadata at the native render-func boundary.

The result still intentionally stops before actual native texture pointer
availability. `graphicsResource=null` is the expected metadata-only finding from
this boundary. The next separately guarded step should be focused EASU
source/destination native-pointer observation under render scale, still with no
command-buffer work, no D3D11 validation, and no DLSS evaluate in that same
change.
