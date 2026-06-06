# Camera Dynamic Resolution Investigation - 2026-06-06

This note records the static/runtime follow-up after
`fsr-off-render-scale-1080p-hwdrs-v2-20260606` through
`fsr-off-render-scale-1080p-handler-request-v4-20260606`.

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

The sharper hypothesis after v2/v3 was that the effective current-camera request
inside `DynamicResolutionHandler` might not be reliably true at the point where
`GetScaledSize(...)` computes `HDCamera.actualWidth/actualHeight`.

The current hook changed the `SetupDLSS...` argument array, but that does not
guarantee the outer render-loop local `cameraRequestedDynamicRes` is changed for
later calls. If the handler's `m_CurrentCameraRequest` remains false, HDRP will
keep full-size targets even when `forcedPercentage=50`.

## Code Change After Initial Investigation

`RenderScaleControlProbe` now mutates the active
`DynamicResolutionHandler` instance inside the already-observed
`DynamicResolutionHandler.Update(...)` prefix:

```text
m_CurrentCameraRequest=True
```

This was deliberately narrower than switching the entire route to software
fallback. The v4 runtime test then determined that a true handler request is not
enough to make `GetScaledSize(...)` produce the expected `960x540 -> 1920x1080`
constructive tuple.

## Superseded Runtime Test

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

This test was executed as v4 and is now superseded by the software-fallback route.
Cleanup requirements remain unchanged: `1920x1080` Windowed, back up and restore the
local/private `11111` save, restore loader config and release-safe native DLL, and
leave no `VRising` process running.

## Handler-Request V3 Result

Run `fsr-off-render-scale-1080p-handler-request-v3-20260606` completed safely but
failed the MVP tuple proof:

- Computer Use entered the `11111` gameplay fixture at `1920x1080` Windowed.
- Cleanup passed and restored the `11111` save to `ChangeCount=0`.
- Stage 8E did not accept a Super Resolution tuple.
- `CameraColor_960` count was `0`; `CameraColor_1920` count was `455`.
- The gameplay camera stayed `actualWidth=1920,actualHeight=1080`.
- Auxiliary `960x540` resources appeared only for low/half-resolution effect targets
  such as LowResDepthBuffer, AO, bloom, and low-res transparent buffers.
- No `m_CurrentCameraRequest` readback appeared, so the run did not prove whether the
  handler request was false, already true, or hidden from reflection.

Follow-up code change:

- `RenderScaleControlProbe` now directly invokes
  `DynamicResolutionHandler.SetCurrentCameraRequest(true)` from the observed
  `DynamicResolutionHandler.Update(...)` prefix.
- The probe now emits capped `Render-scale control handler request diagnostic` lines
  with handler type, direct invocation result, `m_CurrentCameraRequest` before/after
  readback, and whether the private field is writable.

This motivated v4. V4 proved the handler request is true while `CameraColor` remains
full-size, so the active next route is the explicit software-fallback /
ScalableBufferManager diagnostic below.

## Handler-Request V4 Result

Run `fsr-off-render-scale-1080p-handler-request-v4-20260606` completed safely and
ruled out the handler request as the remaining blocker:

- Computer Use entered the `11111` gameplay fixture at `1920x1080` Windowed.
- Cleanup passed and restored the `11111` save to `ChangeCount=0`.
- `Render-scale control handler request diagnostic` appeared 12 times.
- The active handler showed `before=True; invokedSetCurrentCameraRequest=True;
  fieldWritable=True; after=True`.
- Stage 8E did not accept a Super Resolution tuple.
- `CameraColor_960` count was `0`; `CameraColor_1920` count was `463`.
- The gameplay camera stayed `actualWidth=1920,actualHeight=1080`.
- Auxiliary `960x540` resources still appeared, but not as the color/depth/motion
  tuple needed by DLSS.

## Software Fallback Source Evidence

Relevant Core RP behavior:

- `DynamicResolutionHandler.ForceSoftwareFallback()` sets
  `m_ForceSoftwareFallback=true`.
- `SoftwareDynamicResIsEnabled()` returns true when the current camera request is
  true, DRS is enabled, the fraction is not 100 percent, and either
  `m_ForceSoftwareFallback` is true or the type is Software.
- `HardwareDynamicResIsEnabled()` returns false when `m_ForceSoftwareFallback` is
  true.
- `GetResolvedScale()` uses `m_CurrentFraction` instead of
  `ScalableBufferManager.widthScaleFactor/heightScaleFactor` when software fallback
  is forced.
- `ApplyScalesOnSize(...)` rounds software/fallback scaled dimensions to even sizes
  and clamps them to the original size.

HDRP itself calls `ForceSoftwareFallback()` when Hardware DRS is requested for a
camera that cannot use `camera.allowDynamicResolution`. Because v4 proved the handler
request is true while the main targets remain full-size, the next smallest diagnostic
is to call the same fallback method directly on the active handler and read back the
result.

## Next Runtime Test

Do not repeat v3 or v4 unchanged.

Next launch question:

- With `DynamicResolutionHandler.ForceSoftwareFallback()` invoked on the active
  handler, does FSR Off `1920x1080` Windowed gameplay produce a usable
  `960x540 -> 1920x1080` tuple?

Expected evidence:

- `Render-scale control software fallback diagnostic` logs appear.
- `SoftwareDynamicResIsEnabled=True` and `GetResolvedScale` is near 0.5.
- Pass requires Stage 8E or user-rendering to accept an output-larger-than-input
  tuple.

Useful fail evidence:

- `SoftwareDynamicResIsEnabled=True` and `GetResolvedScale` is near 0.5, but
  `HDCamera.actualWidth/actualHeight` and `CameraColor` remain full-size. That would
  point to a later camera-size or RTHandle allocation point rather than another
  request/settings toggle.

## Software-Fallback V5 Result

Run `fsr-off-render-scale-1080p-software-fallback-v5-20260606` completed safely and
proved the next missing piece:

- `ForceSoftwareFallback()` stuck: `HardwareDynamicResIsEnabled=False` appeared in
  all fallback diagnostics, and `SoftwareDynamicResIsEnabled=True` appeared after
  the handler became enabled.
- The active fraction did not change: `GetCurrentScale=1` and
  `GetResolvedScale=(1.00, 1.00)` appeared in every fallback diagnostic.
- The gameplay camera stayed full-size: `actualWidth=1920,actualHeight=1080`.
- `CameraColor_960` count was `0`; `CameraColor_1920` count was `752`.
- Stage 8E did not accept a Super Resolution tuple.

V5 therefore ruled out "fallback flag only" as the complete fix. The relevant
runtime field was `m_CurrentFraction`, together with the enabled/forcing/min/max
state that makes `DynamicResolutionHandler.GetScaledSize(...)` return the scaled
size.

## Post-Update Fraction V6 Result

Run `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606` completed safely
and passed the camera dynamic-resolution proof:

- The `DynamicResolutionHandler.Update(...)` postfix wrote
  `m_CurrentFraction=0.5`, `m_MinScreenFraction=0.5`, `m_MaxScreenFraction=1`,
  `m_ForcingRes=True`, `m_ForceSoftwareFallback=True`, and
  `m_CurrentCameraRequest=True`.
- `GetCurrentScale=0.5`, `GetResolvedScale=(0.50, 0.50)`, and
  `SoftwareDynamicResIsEnabled=True` were repeatedly logged.
- `HDCamera` observations switched from full-size to
  `actualWidth=960,actualHeight=540`.
- Stage 8E accepted the expected `960x540 -> 1920x1080` tuple with
  `CameraColor`, `CameraDepthStencil`, and `Motion Vectors` all at `960x540`.
- `DLSS user rendering evaluate succeeded` reached a persistent SDK-wrapper path
  with `sequenceCreates=1`, `render=960x540`, `target=1920x1080`, and
  `evaluateSuccesses=9000` in the final logged success line.

Current interpretation: the static Core RP model was correct, but the missing state
was not just camera permission or the fallback bit. For this game/runtime, the
intervention must ensure the active handler's post-update fraction is `0.5` before
HDRP allocates/scales the gameplay camera resources.

Do not repeat the camera-request, hardware-DRS, or fallback-only diagnostics
unchanged. The next engineering work is to turn the v6 diagnostic intervention into
a guarded normal-user feature and validate image correctness, performance,
resize/reset behavior, and safe fallback.
