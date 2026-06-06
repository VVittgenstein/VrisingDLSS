# FSR-Off Render-Scale Test Protocol - 2026-06-05

Status: first `1920x1080` Windowed run completed on 2026-06-06 with partial control
and failed MVP proof. Do not repeat the same runtime test unchanged until the camera
dynamic-resolution blocker is addressed.

This protocol exists to prevent blind testing. Do not launch V Rising for this step until the test question, expected evidence, pass/fail signals, and cleanup path are still accurate.

## Test Question

With V Rising `FsrQualityMode=Off`, `DLSS.EnableDLSS=true`, and `DLSS.QualityMode=Performance`, does the mod-owned render-scale control produce a lower-resolution DLSS input and a full-resolution output target without relying on the game's FSR upscaler?

For the default `1920x1080` Windowed constructive test target, the expected
Performance-mode diagnostic tuple is approximately:

- Render/input: `960x540`
- Output/present target: `1920x1080`
- Per-axis scale: `50%`

For a later controlled 3840x2160 output target, the expected Performance-mode tuple is
approximately:

- Render/input: `1920x1080`
- Output/present target: `3840x2160`
- Per-axis scale: `50%`

## Pre-Test Setup

- Confirm no stale `VRising.exe` process is running.
- Install the current local package into `C:\Software\VRising`.
- Write an explicit diagnostic config instead of reusing an unknown previous config.
- Confirm V Rising settings show `FsrQualityMode=Off`.
- Confirm the game output target is `1920x1080` Windowed before entering a scene.
- Back up the local/private `11111` save before entering gameplay, then compare and
  restore afterward unless retaining changes is intentional.
- Record the planned test in `docs/development/runtime-validation.md` or a dated local artifact before launch.

Suggested tuple-only staging commands for a manual test where DLSS evaluate is intentionally disabled:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-local-package.ps1 -GamePath 'C:\Software\VRising'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-diagnostic-config.ps1 -GamePath 'C:\Software\VRising' -Stage render-scale-control
```

Suggested full candidate command shape when the local SDK-wrapper native DLL and a local research `nvngx_dlss.dll` are available:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath 'C:\Software\VRising' -Stage dlss-user-rendering -UseSdkWrapperNative -DlssRuntimePath 'Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll' -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Optional pre-game API check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath 'C:\Software\VRising' -Stage dlss-optimal-settings -UseSdkWrapperNative -DlssRuntimePath 'Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll' -DurationSeconds 60 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

This API check still launches the game to acquire a Unity D3D11 device, but it does not create a DLSS feature or evaluate a gameplay frame.
The 2026-06-06 actual run `dlss-optimal-settings-20260606-115921` passed in this
`1920x1080` Windowed launch shape.

## First Runtime Result

Run `fsr-off-render-scale-1080p-v1-20260606` entered gameplay automatically through
Computer Use and cleaned up safely, but did not produce the expected
`960x540 -> 1920x1080` accepted tuple.

Result summary:

- FSR Off and `1920x1080` Windowed shape: pass.
- Render-scale control mutation: partial pass. Logs showed `forceResolution=True` and
  `forcedPercentage=50`.
- DLSS user-rendering Super Resolution tuple: fail. Logs kept reporting
  `color=1920x1080 output=1920x1080`.
- Save restore: pass with `Status=Restored` and `ChangeCount=0`.

Details: `docs/development/fsr-off-render-scale-runtime-result-2026-06-06.md`.

## Evidence To Capture

- `BepInEx\LogOutput.log` lines showing render-scale control is enabled, `forceResolution=true`, and the forced percentage is `50`.
- Log lines from the texture/resource probe showing a candidate where output dimensions are larger than input dimensions.
- A DLSS evaluate path that accepts the same tuple at most once per Unity frame.
- A screenshot or capture note confirming the game is rendering at `1920x1080` Windowed.
- FPS, CPU, and GPU capture only after the tuple is proven correct.
- Cleanup note confirming `VRising.exe` was closed and the config was restored to a safe loader/default state.

## Pass Signals

- V Rising FSR remains Off for the test.
- The accepted candidate tuple is approximately `960x540 -> 1920x1080` for the default
  1080P Windowed constructive target, or an equivalent 50 percent Performance tuple
  for the confirmed output target.
- DLSS evaluates successfully without repeated per-present over-evaluation.
- The game remains stable long enough to capture a steady-state performance sample.
- Candidate FPS moves in the expected direction for the same 1080P scene, with no
  obvious image corruption from human review. This is constructive evidence only;
  final product-value proof still requires the later controlled GPU-bound matrix.

## Fail Signals

- Input and output dimensions remain identical under FSR Off.
- The tuple only appears after enabling V Rising FSR.
- Texture discovery finds no stable color/depth/motion/output candidate.
- DLSS evaluates many times per presented frame again.
- The game crashes, hangs, or requires unsafe cleanup.
- FPS does not improve once the tuple and evaluate cadence are correct.

## Cleanup

After the run, close the game and restore the local install to a safe diagnostic-loader state:

```powershell
Stop-Process -Name VRising -Force -ErrorAction SilentlyContinue
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-local-package.ps1 -GamePath 'C:\Software\VRising'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-diagnostic-config.ps1 -GamePath 'C:\Software\VRising' -Stage loader
```

Do not start a follow-up run until the previous result has been summarized in a durable local record.

Current follow-up rule: do not launch the same `dlss-user-rendering` runtime test
unchanged. Run `fsr-off-render-scale-1080p-hwdrs-v2-20260606` already confirmed that
`RTHandles.SetHardwareDynamicResolutionState=true` is requested successfully while
`UnityEngine.Camera.allowDynamicResolution` refuses the `true` write and the main
candidate remains full-size. The next launch must follow a new targeted camera
dynamic-resolution route rather than only repeating the RTHandles/member-readback
diagnostic.

Current next diagnostic after static HDRP/Core source review and v4 runtime evidence:

- `HDCamera.allowDynamicResolution` is backed by `HDAdditionalCameraData`, and v4
  proved the active `DynamicResolutionHandler` request is already true/successfully
  invoked in the observed `Update(...)` route.
- `RenderScaleControlProbe` now invokes
  `DynamicResolutionHandler.ForceSoftwareFallback()` from that same observed handler
  route and logs `SoftwareDynamicResIsEnabled`, `HardwareDynamicResIsEnabled`,
  `DynamicResolutionEnabled`, `GetCurrentScale`, `GetResolvedScale`, and
  `ScalableBufferManager` state.
- The next `1920x1080` Windowed run should pass only if the main gameplay camera
  reaches approximately `actualWidth=960,actualHeight=540` or Stage 8E/user
  rendering accepts an output-larger-than-input tuple.
- If software fallback reports a near-0.5 resolved scale but the camera remains
  full-size, the next route should move closer to `HDCamera.GetScaledSize(...)` or
  actual RTHandle/camera-size assignment rather than another settings/request rerun.

Handler-request runtime result:

- `fsr-off-render-scale-1080p-handler-request-v3-20260606` reached stable `11111`
  gameplay automatically and cleaned up safely, but still failed the MVP tuple proof.
- `CameraColor_960` count was `0`, `CameraColor_1920` count was `455`, and Stage 8E
  did not accept a Super Resolution tuple.
- Auxiliary `960x540` resources appeared only for low/half-resolution effects such
  as LowResDepthBuffer, AO, bloom, and low-res transparent buffers.
- No `m_CurrentCameraRequest` readback appeared in that log, so the next run must use
  the newer direct `DynamicResolutionHandler.SetCurrentCameraRequest(true)`
  invocation/readback diagnostic from the `Update(...)` prefix.

Direct handler-request runtime result:

- `fsr-off-render-scale-1080p-handler-request-v4-20260606` reached stable `11111`
  gameplay automatically and cleaned up safely, but still failed the MVP tuple proof.
- Handler diagnostics proved the active handler request is true/successfully invoked:
  `before=True; invokedSetCurrentCameraRequest=True; fieldWritable=True; after=True`.
- `CameraColor_960` count was `0`, `CameraColor_1920` count was `463`, and Stage 8E
  did not accept a Super Resolution tuple.
- The `11111` save was restored from the pre-run backup with `ChangeCount=0`.

Do not repeat `fsr-off-render-scale-1080p-handler-request-v3-20260606` or
`fsr-off-render-scale-1080p-handler-request-v4-20260606` unchanged. The next launch is
`fsr-off-render-scale-1080p-software-fallback-v5-20260606`; it should either produce a
usable `960x540 -> 1920x1080` tuple or prove through fallback diagnostics where the
scale stops applying.
