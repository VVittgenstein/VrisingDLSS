# Camera Dynamic Resolution Investigation - 2026-06-06

This note records the static follow-up after
`fsr-off-render-scale-1080p-hwdrs-v2-20260606`.

## Question

Why did the FSR Off render-scale probe mutate HDRP dynamic-resolution settings to
50 percent while the main gameplay camera and DLSS candidate still stayed
`1920x1080 -> 1920x1080`?

## Local Source Evidence

Closest public source reference:

- `ref/UnityGraphics-2022.3`
- Branch: `2022.3/staging`
- Commit: `03ca85dffdde4b7bc1d6870074e6f5ff9f0352a3`
- The game reports Unity `2022.3.58f1`.

Relevant HDRP/Core control flow:

- `HDRenderPipeline.cs` computes the local request before the current
  `SetupDLSSForCameraDataAndDynamicResHandler(...)` hook:
  `cameraRequestedDynamicRes = hdCam.allowDynamicResolution && camera.cameraType == CameraType.Game`.
- The same loop later calls:
  `dynResHandler.SetCurrentCameraRequest(cameraRequestedDynamicRes)`,
  then `dynResHandler.Update(drsSettings)`, then
  `PrepareAndCullCamera(..., cameraRequestedDynamicRes, ...)`.
- `DynamicResolutionHandler.GetScaledSize(...)` returns the original size when
  either `m_Enabled` or `m_CurrentCameraRequest` is false.
- `HDCamera.Update(...)` sets `actualWidth/actualHeight` to the full viewport,
  then calls `DynamicResolutionHandler.instance.GetScaledSize(...)` only if the
  camera is a game camera.
- `HDCamera.allowDynamicResolution` is backed by
  `HDAdditionalCameraData.allowDynamicResolution`, not by
  `UnityEngine.Camera.allowDynamicResolution`.

## Runtime Evidence

Latest HWDRS run:

- `RTHandles.SetHardwareDynamicResolutionState=true` was logged 16 times.
- `GlobalDynamicResolutionSettings` was repeatedly mutated to
  `forceResolution=True`, `forcedPercentage=50`, and `upsampleFilter=TAAU`.
- `UnityEngine.Camera.allowDynamicResolution` writes did not stick.
- `HDAdditionalCameraData.allowDynamicResolution=True` appeared in
  `SetupDLSSForCameraDataAndDynamicResHandler(...)` argument summaries.
- Main `HDCamera` observations still stayed
  `actualWidth=1920,actualHeight=1080`.
- The SR candidate still rejected same-size tuples:
  `color=1920x1080 output=1920x1080`.

Important negative evidence:

- `DynamicResolutionHandler.Update(...)` is definitely being patched and called.
- The tiny wrapper methods `SetCurrentCameraRequest(...)` and
  `HDCamera.RequestDynamicResolution(...)` were patched during install, but the
  run did not show useful runtime call logs for them. Treat those tiny methods as
  unreliable intervention points until proven otherwise.

## Updated Interpretation

The blocker is probably not just the failed
`UnityEngine.Camera.allowDynamicResolution` setter. HDRP's camera-side DRS
permission comes from `HDAdditionalCameraData.allowDynamicResolution`, and that
object is visible as `true` inside the setup hook.

The sharper hypothesis is that the effective current-camera request inside
`DynamicResolutionHandler` is not reliably true at the point where
`GetScaledSize(...)` computes `HDCamera.actualWidth/actualHeight`.

The current hook changed the `SetupDLSS...` argument array, but that does not
guarantee the outer render-loop local `cameraRequestedDynamicRes` is changed for
later calls. If the handler's `m_CurrentCameraRequest` remains false, HDRP will
keep full-size targets even when `forcedPercentage=50`.

## Code Change After This Investigation

`RenderScaleControlProbe` now mutates the active
`DynamicResolutionHandler` instance inside the already-observed
`DynamicResolutionHandler.Update(...)` prefix:

```text
m_CurrentCameraRequest=True
```

This is deliberately narrower than switching the entire route to software
fallback. The next runtime test should first determine whether a true handler
request is enough to make `GetScaledSize(...)` produce the expected
`960x540 -> 1920x1080` constructive tuple.

## Next Runtime Test

Do not repeat `fsr-off-render-scale-1080p-hwdrs-v2-20260606` unchanged.

Next launch question:

- With the new `m_CurrentCameraRequest=True` diagnostic, does
  `DynamicResolutionHandler.GetScaledSize(...)` reduce the main gameplay camera
  from `1920x1080` to approximately `960x540` under V Rising FSR Off?

Expected pass evidence:

- Render-scale logs include `m_CurrentCameraRequest=False->True` or show the
  field already true during `DynamicResolutionHandler.Update(...)`.
- `HDCamera` observations show `actualWidth`/`actualHeight` near `960x540`.
- Stage 8E or user-rendering accepts an output-larger-than-input tuple.

Fail evidence:

- `m_CurrentCameraRequest=True` is logged but `HDCamera.actualWidth/actualHeight`
  stay full-size. That would point at hardware DRS / ScalableBufferManager /
  `UnityEngine.Camera.allowDynamicResolution` and justify a follow-up software
  fallback diagnostic.
- The private field write does not stick or cannot be found. That would require
  an earlier lifecycle hook or a different IL2CPP/native field route.

Cleanup requirements remain unchanged: `1920x1080` Windowed, back up and restore
the local/private `11111` save, restore loader config and release-safe native DLL,
and leave no `VRising` process running.
