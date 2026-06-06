# FSR Off Render-Scale HWDRS Runtime Result - 2026-06-06

Run label: `fsr-off-render-scale-1080p-hwdrs-v2-20260606`.

Purpose: rerun the FSR Off `dlss-user-rendering` gameplay proof after the targeted
render-scale diagnostic change that:

- verifies reflected member writes by reading back the post-write value;
- requests `RTHandles.SetHardwareDynamicResolutionState(true)`;
- keeps V Rising FSR Off and uses mod-owned render-scale control.

## Test Shape

- Game path: `C:\Software\VRising`.
- Stage: `dlss-user-rendering`.
- DLSS runtime: `Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll`.
- Native path: SDK-wrapper native DLL for the run, restored afterward.
- Resolution/window mode: `1920x1080`, `GraphicSettings.WindowMode=3`.
- Player log evidence: `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Gameplay entry: Computer Use clicked the Chinese Continue entry for local/private
  `11111` once and reached stable gameplay.

## Artifacts

- Test plan:
  `artifacts/gameplay-automation/TestPlan-fsr-off-render-scale-1080p-hwdrs-v2-20260606.json`
- Session:
  `artifacts/gameplay-automation/Session-fsr-off-render-scale-1080p-hwdrs-v2-20260606.json`
- BepInEx log:
  `artifacts/gameplay-automation/LogOutput-fsr-off-render-scale-1080p-hwdrs-v2-20260606.log`
- Analysis:
  `artifacts/gameplay-automation/Analysis-fsr-off-render-scale-1080p-hwdrs-v2-20260606.txt`
- Cleanup:
  `artifacts/gameplay-automation/Cleanup-fsr-off-render-scale-1080p-hwdrs-v2-20260606.json`
- Save restore:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-fsr-off-render-scale-1080p-hwdrs-v2-20260606.json`

## Result

Classification: fail/partial for the MVP render-scale proof.

The targeted diagnostic worked, but it did not make the main render targets honor
dynamic resolution under FSR Off.

Key log counts:

- `RTHandles.SetHardwareDynamicResolutionState=true`: 16.
- `Render-scale control member write did not stick`: 20, capped.
- Hardware dynamic-resolution request failures: 0.
- `DLSS super-resolution input probe accepted`: 0.
- Same-size SR rejection `color=1920x1080 output=1920x1080`: 10.
- HDCamera full-size observations `actualWidth=1920,actualHeight=1080`: 429.
- `allowDynamicResolution=False` observations: 443.
- `HDAdditionalCameraData,allowDynamicResolution=True` observations: 11.

Representative chain:

```text
Render-scale control member write did not stick #1:
UnityEngine.Camera.allowDynamicResolution; before=False; expected=True; after=False

Render-scale control prefix #1 ... changes=RTHandles.SetHardwareDynamicResolutionState=true; ...
forceResolution=False->True; forcedPercentage=0->50

Upscaler state probe call #1 ... arg0=HDAdditionalCameraData,allowDynamicResolution=True ...
camera=Camera,name=CameraParent,...,allowDynamicResolution=False

HDCamera.IsDLSSEnabled ... actualWidth=1920,actualHeight=1080 ...
allowDynamicResolution=False

DLSS super-resolution input probe not accepted:
output was not larger than render input; color=1920x1080 output=1920x1080
```

## Cleanup

- Stop-session cleanup passed.
- `CrashEventCount=0`.
- `RestoredClientSettings=True`.
- `RestoredLoaderConfig=True`.
- `RestoredReleaseSafeNative=True`.
- `RemainingVRisingProcessCount=0`.

Save state:

- The `11111` save was backed up before entry.
- Gameplay entry changed the save directory from 12 files to 8 files, with 6
  manifest changes.
- The changed state was archived at
  `artifacts/gameplay-automation/SaveAfterRun-fsr-off-render-scale-1080p-hwdrs-v2-20260606.zip`.
- The save was restored from backup; corrected comparison reports
  `Status=Restored`, `RestoredFileCount=12`, and `ChangeCount=0`.

## Conclusion

`RTHandles.SetHardwareDynamicResolutionState(true)` is not the missing switch by
itself. The run confirms a sharper blocker: the actual gameplay
`UnityEngine.Camera.allowDynamicResolution` property refuses or immediately loses the
`true` write, while `HDAdditionalCameraData.allowDynamicResolution` and
`GlobalDynamicResolutionSettings` can be mutated.

Do not rerun the same `dlss-user-rendering` proof unchanged. The next technical loop
should investigate a different camera dynamic-resolution route, such as:

- why the `UnityEngine.Camera.allowDynamicResolution` IL2CPP setter does not stick;
- whether the value is backed by a native engine flag that needs a direct interop call
  or a different object identity;
- whether `HDCamera` creation/update pulls dynamic-resolution permission from another
  source after the current prefix mutation;
- whether an earlier camera/component lifecycle hook can set the value before HDRP
  constructs the `HDCamera`.

Follow-up static source review:

- `docs/development/camera-dynamic-resolution-investigation-2026-06-06.md`
  confirms that `HDCamera.allowDynamicResolution` reads
  `HDAdditionalCameraData.allowDynamicResolution`, while the main render size is
  ultimately gated by `DynamicResolutionHandler.GetScaledSize(...)`.
- The next diagnostic patch does not repeat the RTHandles-only route. It forces
  the handler instance field `m_CurrentCameraRequest=true` from the already-called
  `DynamicResolutionHandler.Update(...)` prefix, then expects the next run to prove
  whether the main camera scales to roughly `960x540 -> 1920x1080`.

Later follow-up: v3/v4 proved the handler request is true but insufficient, v5 proved
software fallback alone keeps the active fraction at `1.0`, and v6 passed the FSR Off
tuple/evaluate proof by forcing the active handler's post-update fraction to `0.5`.
See `docs/development/post-update-fraction-runtime-result-2026-06-06.md`.
