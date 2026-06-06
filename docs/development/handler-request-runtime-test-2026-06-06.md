# Handler Request Runtime Test - 2026-06-06

Status: completed; failed MVP tuple proof, but proved the handler request is not
the remaining blocker.

## Question

With V Rising `FsrQualityMode=Off`, `DLSS.EnableDLSS=true`, SDK-wrapper local
runtime enabled, and `1920x1080` Windowed launch shape, does forcing
`DynamicResolutionHandler.m_CurrentCameraRequest=true` inside the observed
`DynamicResolutionHandler.Update(...)` prefix allow HDRP to produce a real Super
Resolution tuple without using V Rising's built-in FSR upscaler?

## Hypothesis

The previous hardware-DRS run showed that HDRP settings and
`RTHandles.SetHardwareDynamicResolutionState(true)` were being requested, but the
main gameplay camera stayed `1920x1080`. Static HDRP/Core source review shows
`DynamicResolutionHandler.GetScaledSize(...)` returns the original size when
`m_CurrentCameraRequest` is false. If that private request bit is the missing gate,
the next gameplay run should reduce the main camera or accepted color input to about
`960x540` while preserving a `1920x1080` output target.

## Expected Evidence

- Start-session artifact for `fsr-off-render-scale-1080p-handler-request-v3-20260606`
  shows `Stage=dlss-user-rendering`, SDK-wrapper native path, local `nvngx_dlss.dll`,
  `SetClientResolution=true`, `SetClientWindowMode=true`, and `ClientWindowMode=3`.
- Computer Use activates the real `VRising` window, clicks the Continue / `11111`
  entry once, and observes loading or stable gameplay.
- BepInEx log includes render-scale control lines showing
  `m_CurrentCameraRequest=False->True` or an equivalent successful write.
- Pass evidence is either `HDCamera.actualWidth/actualHeight` near `960x540` for the
  gameplay camera, or Stage 8E / user-rendering acceptance of an output-larger-than
  input tuple near `960x540 -> 1920x1080`.
- Cleanup artifacts show no matching Windows crash event, no remaining V Rising
  process, loader config restored, release-safe native DLL restored, ClientSettings
  restored, and the local/private `11111` save restored from its pre-run backup.

## Pass Signal

FSR remains Off and the run accepts a Super Resolution tuple for the normal user
rendering route under the `1920x1080` Windowed constructive test shape.

## Fail Signal

The handler request write is logged but the gameplay camera and candidate resources
remain full-size (`1920x1080 -> 1920x1080`), or the run crashes/hangs/cleans up
unsafely.

## Cleanup

After observation, run `scripts/stop-vrising-automation-session.ps1` with the active
session artifact. Archive BepInEx/Player/WER evidence, restore the local package and
loader config, restore the user's `ClientSettings.json`, archive then restore the
`11111` save directory from the pre-run backup, and confirm the restored save has
`ChangeCount=0`.

## Runtime Result

Run label: `fsr-off-render-scale-1080p-handler-request-v3-20260606`.

Artifacts:

- `artifacts/gameplay-automation/Session-fsr-off-render-scale-1080p-handler-request-v3-20260606.json`
- `artifacts/gameplay-automation/LogOutput-fsr-off-render-scale-1080p-handler-request-v3-20260606.log`
- `artifacts/gameplay-automation/Analysis-fsr-off-render-scale-1080p-handler-request-v3-20260606.txt`
- `artifacts/gameplay-automation/Player-fsr-off-render-scale-1080p-handler-request-v3-20260606.log`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-fsr-off-render-scale-1080p-handler-request-v3-20260606.json`

Automation and cleanup passed:

- Start session reached `Status=Ready` with `Stage=dlss-user-rendering`,
  SDK-wrapper native, local `nvngx_dlss.dll`, `SetClientResolution=true`,
  `SetClientWindowMode=true`, `ClientWindowMode=3`, and screenshot size
  `1920x1080`.
- Computer Use selected the real `VRising` window, clicked Continue once at the
  known `11111` menu entry, observed loading after 20 seconds, and observed stable
  gameplay with HUD/character after 55 seconds.
- Stop session reported `Status=Pass`, `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The `11111` save changed during gameplay entry (`ChangeCount=6` before restore),
  was archived, and was restored from the pre-run backup with
  `ChangeCount=0`.

Runtime proof result:

- Fail for MVP tuple. Stage 8E did not accept a Super Resolution tuple.
- `CameraColor_960` count was `0`; `CameraColor_1920` count was `455`.
- `DLSS super-resolution input probe succeeded` count was `0`.
- `output was not larger than render input` count was `10`, with candidates such as
  `color=1920x1080 output=1920x1080`.
- `HDCamera.actualWidth/actualHeight` remained `1920x1080` for the gameplay camera.
- `960x540` resources appeared, but only for auxiliary low/half-resolution targets
  such as `LowResDepthBuffer`, AO packed data, bloom mip resources, and low-res
  transparent buffers. They were not a usable color/depth/motion/output DLSS tuple.
- No `m_CurrentCameraRequest` write/read diagnostic appeared in the log, so this run
  did not prove whether the private handler request bit was missing, already true, or
  hidden from reflection.

Follow-up implemented after the run:

- `RenderScaleControlProbe` now directly invokes
  `DynamicResolutionHandler.SetCurrentCameraRequest(true)` from the observed
  `DynamicResolutionHandler.Update(...)` prefix before attempting the private-field
  write.
- The probe now emits capped `Render-scale control handler request diagnostic` lines
  with handler type, `m_CurrentCameraRequest` before/after readback, whether direct
  invocation succeeded, and whether the private field is writable.

This direct handler-request follow-up was executed as v4. V4 proved
`SetCurrentCameraRequest(true)` succeeds and `m_CurrentCameraRequest` is true while
`CameraColor` and the gameplay camera remain full-size, so the active next route is
the explicit software-fallback/ScalableBufferManager diagnostic below.

## Direct Handler Request V4 Plan

Run label: `fsr-off-render-scale-1080p-handler-request-v4-20260606`.

Question:

- With the direct `DynamicResolutionHandler.SetCurrentCameraRequest(true)`
  invocation in the observed `DynamicResolutionHandler.Update(...)` prefix, does the
  FSR Off `1920x1080` Windowed gameplay route finally produce a usable
  output-larger-than-input tuple for DLSS user rendering?

Hypothesis:

- V3 did not log handler request readback, so the field write may not have reached
  the effective handler state. Directly invoking the handler method should either make
  the request bit true or prove that the request is already true/irrelevant.

Expected evidence:

- Start-session artifact shows `Stage=dlss-user-rendering`, SDK-wrapper native, local
  `nvngx_dlss.dll`, `SetClientResolution=true`, `SetClientWindowMode=true`, and
  `ClientWindowMode=3`.
- Computer Use enters the known `11111` gameplay fixture with exactly one Continue
  activation.
- BepInEx log includes `Render-scale control handler request diagnostic` lines with
  handler type, direct invocation result, and `m_CurrentCameraRequest` before/after
  readback.
- Pass: Stage 8E or DLSS user rendering accepts a tuple near
  `960x540 -> 1920x1080`.
- Fail: handler request invocation/readback is true or successful, but gameplay
  `CameraColor`, depth, motion, and output candidates remain `1920x1080`.

Cleanup:

- Stop the session through `scripts/stop-vrising-automation-session.ps1`.
- Restore loader config, release-safe native DLL, and `ClientSettings.json`.
- Archive and restore the `11111` save from the pre-run backup and confirm
  `ChangeCount=0`.
- Leave no `VRising` or `VRisingServer` process running.

## Direct Handler Request V4 Result

Run label: `fsr-off-render-scale-1080p-handler-request-v4-20260606`.

Artifacts:

- `artifacts/gameplay-automation/Session-fsr-off-render-scale-1080p-handler-request-v4-20260606.json`
- `artifacts/gameplay-automation/LogOutput-fsr-off-render-scale-1080p-handler-request-v4-20260606.log`
- `artifacts/gameplay-automation/Analysis-fsr-off-render-scale-1080p-handler-request-v4-20260606.txt`
- `artifacts/gameplay-automation/Player-fsr-off-render-scale-1080p-handler-request-v4-20260606.log`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-fsr-off-render-scale-1080p-handler-request-v4-20260606.json`

Automation and cleanup passed:

- Start session reached `Status=Ready` with `Stage=dlss-user-rendering`,
  SDK-wrapper native, local `nvngx_dlss.dll`, `SetClientResolution=true`,
  `SetClientWindowMode=true`, `ClientWindowMode=3`, and screenshot size
  `1920x1080`.
- Computer Use selected the real `VRising` window, clicked Continue once at the
  known `11111` menu entry, observed loading after 20 seconds, and observed stable
  gameplay after 60 seconds.
- No movement or gameplay keys were sent during the automated interaction.
- Stop session reported `Status=Pass`, `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The `11111` save changed during gameplay entry (`ChangeCount=6` before restore),
  was archived, and was restored from the pre-run backup with `ChangeCount=0`.

Runtime proof result:

- Fail for MVP tuple. Stage 8E did not accept a Super Resolution tuple.
- `Render-scale control handler request diagnostic` appeared 12 times.
- Handler request lines showed direct invocation succeeded and the request was true,
  for example `before=True; invokedSetCurrentCameraRequest=True;
  fieldWritable=True; after=True`.
- `CameraColor_960` count was `0`; `CameraColor_1920` count was `463`.
- `LowResDepthBuffer_960` count was `75`, confirming auxiliary half-resolution
  resources still existed but were not the DLSS color input.
- `DLSS super-resolution input probe succeeded` count was `0`.
- `output was not larger than render input` count was `10`, with candidates such as
  `color=1920x1080 output=1920x1080`.
- `HDCamera` observations still stayed `actualWidth=1920,actualHeight=1080`.

Conclusion:

- The direct handler request route is ruled out as the remaining blocker. The
  effective `DynamicResolutionHandler` request is true in the observed `Update(...)`
  path, but HDRP still allocates the main gameplay color/depth/motion/output
  candidates at full size.
- Do not repeat V3 or V4 unchanged. The next diagnostic should explicitly exercise
  `DynamicResolutionHandler.ForceSoftwareFallback()` and record
  `SoftwareDynamicResIsEnabled()`, `HardwareDynamicResIsEnabled()`,
  `DynamicResolutionEnabled()`, `GetCurrentScale()`, `GetResolvedScale()`, and
  `ScalableBufferManager` state.

## Software Fallback Diagnostic V5 Plan

Next label: `fsr-off-render-scale-1080p-software-fallback-v5-20260606`.

Question:

- If the same FSR Off `1920x1080` Windowed gameplay route forces
  `DynamicResolutionHandler.ForceSoftwareFallback()` on the active handler, does HDRP
  finally compute the gameplay camera/main DLSS candidates at about
  `960x540 -> 1920x1080`?

Expected evidence:

- BepInEx log includes `Render-scale control software fallback diagnostic` lines.
- Pass: Stage 8E or DLSS user rendering accepts a tuple near
  `960x540 -> 1920x1080`.
- Useful fail: `SoftwareDynamicResIsEnabled=True` and `GetResolvedScale` is near
  `0.5`, but `CameraColor` and `HDCamera.actualWidth/actualHeight` remain
  `1920x1080`; this would move the next hook closer to `HDCamera.GetScaledSize` or
  actual-size assignment.
- Unsafe fail: crash/hang/cleanup failure; preserve WER/log artifacts and restore the
  `11111` save before further investigation.

Implementation status:

- `RenderScaleControlProbe` now invokes `ForceSoftwareFallback()` from the same
  observed `DynamicResolutionHandler.Update(...)` route and emits capped software
  fallback diagnostics.
