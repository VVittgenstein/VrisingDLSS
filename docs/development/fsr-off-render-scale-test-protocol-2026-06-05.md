# FSR-Off Render-Scale Test Protocol - 2026-06-05

Status: not yet run after this protocol was written.

This protocol exists to prevent blind testing. Do not launch V Rising for this step until the test question, expected evidence, pass/fail signals, and cleanup path are still accurate.

## Test Question

With V Rising `FsrQualityMode=Off`, `DLSS.EnableDLSS=true`, and `DLSS.QualityMode=Performance`, does the mod-owned render-scale control produce a lower-resolution DLSS input and a full-resolution output target without relying on the game's FSR upscaler?

For a 3840x2160 output target, the expected Performance-mode diagnostic tuple is approximately:

- Render/input: `1920x1080`
- Output/present target: `3840x2160`
- Per-axis scale: `50%`

## Pre-Test Setup

- Confirm no stale `VRising.exe` process is running.
- Install the current local package into `C:\Software\VRising`.
- Write an explicit diagnostic config instead of reusing an unknown previous config.
- Confirm V Rising settings show `FsrQualityMode=Off`.
- Confirm the game output target is the intended test resolution before entering a scene.
- Record the planned test in `docs/development/runtime-validation.md` or a dated local artifact before launch.

Suggested tuple-only staging commands for a manual test where DLSS evaluate is intentionally disabled:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-local-package.ps1 -GamePath 'C:\Software\VRising'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-diagnostic-config.ps1 -GamePath 'C:\Software\VRising' -Stage render-scale-control
```

Suggested full candidate command shape when the local SDK-wrapper native DLL and a local research `nvngx_dlss.dll` are available:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath 'C:\Software\VRising' -Stage dlss-user-rendering -UseSdkWrapperNative -DlssRuntimePath 'Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll' -DurationSeconds 120
```

Optional pre-game API check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath 'C:\Software\VRising' -Stage dlss-optimal-settings -UseSdkWrapperNative -DlssRuntimePath 'Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll' -DurationSeconds 60
```

This API check still launches the game to acquire a Unity D3D11 device, but it does not create a DLSS feature or evaluate a gameplay frame.

## Evidence To Capture

- `BepInEx\LogOutput.log` lines showing render-scale control is enabled, `forceResolution=true`, and the forced percentage is `50`.
- Log lines from the texture/resource probe showing a candidate where output dimensions are larger than input dimensions.
- A DLSS evaluate path that accepts the same tuple at most once per Unity frame.
- A screenshot or capture note confirming the game is rendering at the intended output resolution.
- FPS, CPU, and GPU capture only after the tuple is proven correct.
- Cleanup note confirming `VRising.exe` was closed and the config was restored to a safe loader/default state.

## Pass Signals

- V Rising FSR remains Off for the test.
- The accepted candidate tuple is approximately `1920x1080 -> 3840x2160` for a 4K output target, or an equivalent 50 percent Performance tuple for the confirmed output target.
- DLSS evaluates successfully without repeated per-present over-evaluation.
- The game remains stable long enough to capture a steady-state performance sample.
- Candidate FPS is meaningfully higher than native 4K FSR Off baseline in the same scene, with no obvious image corruption from human review.

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
