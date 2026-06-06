# FSR-Off Render-Scale Runtime Result - 2026-06-06

Status: partial control, MVP proof failed.

## Question

With V Rising `FsrQualityMode=Off`, `DLSS.EnableDLSS=true`,
`DLSS.QualityMode=Performance`, SDK-wrapper native DLL, and a `1920x1080` Windowed
player shape, does the mod-owned render-scale control produce an accepted
input-smaller-than-output `dlss-user-rendering` tuple without relying on the game's
built-in FSR upscaler?

Expected constructive tuple: approximately `960x540 -> 1920x1080`.

## Run

Run label: `fsr-off-render-scale-1080p-v1-20260606`

Session start:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage dlss-user-rendering -UseSdkWrapperNative -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll" -ArtifactLabel fsr-off-render-scale-1080p-v1-20260606 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Computer Use then selected the real `VRising` window, clicked the visible Chinese
Continue entry once at `(205, 354)` in the `1283x751` screenshot, and observed gameplay.

Session stop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-fsr-off-render-scale-1080p-v1-20260606.json"
```

## Artifacts

- `artifacts/gameplay-automation/Session-fsr-off-render-scale-1080p-v1-20260606.json`
- `artifacts/gameplay-automation/Cleanup-fsr-off-render-scale-1080p-v1-20260606.json`
- `artifacts/gameplay-automation/LogOutput-fsr-off-render-scale-1080p-v1-20260606.log`
- `artifacts/gameplay-automation/Analysis-fsr-off-render-scale-1080p-v1-20260606.txt`
- `artifacts/gameplay-automation/Player-fsr-off-render-scale-1080p-v1-20260606.log`
- `artifacts/gameplay-automation/SessionScreenshot-fsr-off-render-scale-1080p-v1-20260606.png`
- `artifacts/gameplay-automation/SaveManifestBefore-fsr-off-render-scale-1080p-v1-20260606.json`
- `artifacts/gameplay-automation/SaveChangedArchive-fsr-off-render-scale-1080p-v1-20260606/`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-fsr-off-render-scale-1080p-v1-20260606.json`

## Pass Evidence

- Start session reached `Status=Ready`.
- Computer Use reached gameplay; the follow-up screenshot showed character, HUD,
  hotbar, task text, and minimap.
- Player log reported:
  - `"FsrQualityMode": 0`
  - `"WindowMode": 3`
  - `SetResolution 1920, 1080, fullScreenMode Windowed`
- Cleanup reported:
  - `Status=Pass`
  - `CrashEventCount=0`
  - `RestoredClientSettings=True`
  - `RestoredLoaderConfig=True`
  - `RestoredReleaseSafeNative=True`
  - `RemainingVRisingProcessCount=0`
- Save restore reported:
  - `Status=Restored`
  - `ChangeCount=0`

## Failed Proof

The render-scale control hook did mutate HDRP dynamic-resolution settings:

```text
Render-scale control prefix #1 ... forceResolution=False->True; forcedPercentage=0->50
Render-scale control prefix #3 ... enabled=False->True; ... forceResolution=False->True; forcedPercentage=100->50
```

But the gameplay camera and the accepted resource tuple did not become a 50 percent
Super Resolution tuple:

```text
DLSS evaluate input probe succeeded ... color=1920x1080 ... output=1920x1080 ... depth=1920x1080 ... motion=1920x1080
DLSS super-resolution input probe not accepted ... output was not larger than render input; color=1920x1080 output=1920x1080
```

The upscaler state logs also showed the important blocker shape:

```text
camera=CameraParent,pixelWidth=1920,pixelHeight=1080,scaledPixelWidth=1920,scaledPixelHeight=1080,allowDynamicResolution=False
IsDLSSEnabled=False
```

Some non-primary resources did appear at 50 percent dimensions, such as
`BloomMipDown_960x540` and `AO Packed data_960x540`, but the main `CameraColor`,
`CameraDepthStencil`, and `Motion Vectors` resources stayed at `1920x1080`. This is
not sufficient for DLSS Super Resolution.

## Result

This run proves the automation/session harness can support a real `dlss-user-rendering`
gameplay proof with SDK-wrapper native setup and release-safe cleanup. It does not prove
the FSR Off render-scale route.

Classification:

- Gameplay automation: pass.
- `1920x1080` Windowed test shape: pass.
- Release-safe cleanup: pass.
- Save backup/restore: pass.
- FSR Off render-scale MVP proof: fail/partial.

## Next Action

Do not repeat this same runtime test unchanged. The next technical loop should
investigate why the attempted `allowDynamicResolution=true` mutation is not taking
effect on the actual gameplay camera/main render targets. Candidate areas:

- whether `UnityEngine.Camera.allowDynamicResolution` needs a different setter route
  under IL2CPP;
- whether `HDAdditionalCameraData` or `HDCamera` by-ref data needs a different writeback;
- whether the dynamic-resolution request must happen earlier than
  `SetupDLSSForCameraDataAndDynamicResHandler`;
- whether a safer HDRP route exists for enabling hardware dynamic resolution without
  forcing Unity's internal DLSS pass.

## Follow-up Diagnostic Fix

After this result, `RenderScaleControlProbe.TrySetMember` was tightened so a reflected
write is only reported as a change when the post-write value equals the intended value.
Previously a failed camera write could be logged as `allowDynamicResolution=False->False`,
which looked like a mutation but was actually evidence that the setter did not stick.

The next run should therefore show a capped warning like
`Render-scale control member write did not stick` if `UnityEngine.Camera.allowDynamicResolution`
still refuses the reflected write.

Static metadata follow-up using `C:\Software\Python314` plus `dnfile` found:

- `UnityEngine.Camera.set_allowDynamicResolution` exists as a public managed IL2CPP
  interop wrapper, but the previous log still showed the immediate post-write value
  as `False`;
- `UnityEngine.Rendering.GlobalDynamicResolutionSettings` exposes the mutated values as
  writable public fields, matching the successful `forceResolution=True` /
  `forcedPercentage=50` evidence;
- `UnityEngine.Rendering.RTHandles.SetHardwareDynamicResolutionState(bool)` and
  `RTHandleSystem.SetHardwareDynamicResolutionState(bool)` exist as public methods.

`RenderScaleControlProbe` now also requests
`RTHandles.SetHardwareDynamicResolutionState(true)` from the same guarded diagnostic
path, with capped success/failure logging. The next run should look for
`RTHandles.SetHardwareDynamicResolutionState=true` in render-scale control logs before
deciding whether the main camera/main targets still ignore FSR Off dynamic resolution.

Local verification: `C:\Software\dotnet\dotnet.exe build
src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release --no-restore` passed with
0 warnings and 0 errors.
