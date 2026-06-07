# Native RenderFunc Resource Tuple + Render Scale Gameplay Result - 2026-06-07

Status: protected `11111` gameplay proof passed.

## Question

When V Rising's built-in `FsrQualityMode` is `Off` and the mod-owned
`RenderScaleControlProbe` forces Performance scale, does the already proven
focused EASU native render-func tuple boundary report the expected Super
Resolution shape:

```text
input=960x540; output=1920x1080
```

## Hypothesis

Yes. Earlier render-scale evidence proved the active handler can force
`GetCurrentScale=0.5`, and the Stage 8E path previously accepted a low-input /
full-output tuple. The EASU pass should expose the same boundary through managed
`EASUData` plus the focused native render-func entry detour.

This run must not call broad `RenderGraphResourceRegistry.GetTexture`, resolve
native texture pointers, validate D3D11 textures, load NGX, or evaluate DLSS.

## Setup

- V Rising `FsrQualityMode`: `Off`.
- Resolution/window mode: true `1920x1080` Windowed.
- Stage: `native-renderfunc-resource-tuple-render-scale`.
- Save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Artifact label:
  `native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1`.

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
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
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-resource-tuple-render-scale -ArtifactLabel native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\capture-vrising-window.ps1 -ArtifactLabel native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1 -OutputPath artifacts\gameplay-automation\CaptureGameplay-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.png -WindowTitlePattern "^VRising$" -Method Auto
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.json"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Automation Notes

- Computer Use selected the real `VRising` Unity window, not the BepInEx console.
- The main-menu screenshot was `1283x751`.
- The visible Chinese Continue / `11111` entry was clicked once at `(205,354)`.
- No keyboard, movement, or gameplay keys were sent.
- After loading, Computer Use returned a screenshot of the Codex window even
  after reacquiring the `VRising` handle. No further UI input was sent after
  that mismatch.
- Player log proved protected gameplay entry:
  - `SetResolution 1920, 1080, fullScreenMode Windowed`
  - `Found GameConnect Data! ServerSaveName: f0e07524-03f4-4ef4-945c-b1f7e982071b`
  - `ClientSteamTransport.Connect - ConnectAddress: SteamIPv4://127.0.0.1:9876`
  - `Instantiating Loaded UI Prefab. GameObject: HUDCanvas`
  - `Created Camera TopDownCamera`
  - `Assigned Camera TopDownCamera to LocalUser`
- A passive window capture helper produced the valid gameplay screenshot:
  `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.png`.

## Result

Pass.

- Analyzer: `Native RenderFunc Resource Tuple=Pass`
- Analyzer: `Native RenderFunc Resource Identity=Pass`
- Analyzer: `Native RenderFunc Args=Pass`
- Analyzer: `Native RenderFunc Entry=Pass`
- Analyzer: `Stage 2C Render-Scale Control Probe=Pass`
- First tuple advanced line appeared at `compile=4`.
- Tuple advanced lines: `1`
- Tuple status lines: `108`
- `tuple=input=960x540; output=1920x1080`: `109`
- `tuple=input=1920x1080; output=1920x1080`: `0`
- `tuple=input=960x540; output=960x540`: `0`
- `passDataMatches=True`: `212`
- `tupleReady=True`: `106`
- `GetCurrentScale=0.5`: `31`
- `GetResolvedScale=(0.50, 0.50)`: `31`
- `RenderGraph GetTexture call #`: `0`
- D3D11 probe/validation patterns: `0`
- NGX/DLSS/evaluate patterns: `0`
- native render-func entry/tuple failure patterns: `0`
- access-violation text patterns: `0`
- `CrashEventCount=0`

The first advanced line:

```text
Native render-func resource tuple advanced: compile=4; sampleCount=1; managedPassData=0x1B88F963780; nativeLastPassData=0x1B88F963780; passDataMatches=True; tupleReady=True; pass="Edge Adaptive Spatial Upsampling"; tuple=input=960x540; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"
```

The final sampled status remained the same shape:

```text
Native render-func resource tuple status #8400: compile=9756; entryCount=8397; sampleCount=8397; passDataMatches=True; tupleReady=True; pass="Edge Adaptive Spatial Upsampling"; tuple=input=960x540; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=87"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=88"
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

- `artifacts/gameplay-automation/Session-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/CaptureGameplay-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-resource-tuple-render-scale-gameplay-1080p-20260607-r1.json`

## Interpretation

This is the strongest local evidence so far for a safe official-boundary-adjacent
Super Resolution locator. Under the mod-owned render-scale control, the focused
EASU render-func pass data already exposes the exact low-input/full-output tuple
needed for DLSS Super Resolution sizing:

```text
Camera render/input: 960x540
EASU output target: 1920x1080
```

This turns the next problem from broad resource discovery into a focused EASU
source/destination resolution problem. The next guard should use this tuple as
the locator for a separately tested resource-resolution or native-pointer
observation path. Do not jump directly to command-buffer work or DLSS evaluate
from this proof.
