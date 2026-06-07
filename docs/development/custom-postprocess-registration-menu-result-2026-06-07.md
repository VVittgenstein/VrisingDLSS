# HDRP Custom PostProcess Registration Menu Result - 2026-06-07

Status: menu proof passed after narrowing the probe to HDRP global-settings
registration only. Volume-component instantiation remains rejected for this
stage.

## Question

Can the default-off `custom-postprocess-registration` stage safely register an
injected HDRP `CustomPostProcessVolumeComponent` type with
`HDRenderPipelineGlobalSettings.afterPostProcessCustomPostProcesses` in a true
`1920x1080` Windowed V Rising menu run, while avoiding render resources,
command buffers, native texture pointers, and DLSS evaluate?

## Conditions

- Scope: main-menu / startup only.
- Gameplay: not entered.
- Protected `11111` save: not touched.
- Duration: `75` seconds per run.
- Graphics: forced Direct3D11 by the diagnostic helper.
- Resolution: Player log reported
  `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Cleanup: diagnostic helper restored loader config, release-safe native DLL,
  and ClientSettings.

## First Run

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage custom-postprocess-registration -ArtifactLabel custom-postprocess-registration-1080p-menu-20260607-r1 -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Artifacts:

- `artifacts/runtime-logs/LogOutput-custom-postprocess-registration-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/Analysis-custom-postprocess-registration-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/Player-custom-postprocess-registration-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/ClientSettings-custom-postprocess-registration-1080p-menu-20260607-r1.before.json`

Result:

- Run stability: stable, no Windows crash event.
- Analyzer: `HDRP Custom PostProcess Registration=Fail`.
- BepInEx log:
  `Custom post-process registration probe IL2CPP type registered.`
- BepInEx log:
  `Custom post-process registration probe failed: System.NullReferenceException: Object reference not set to an instance of an object.`
- Player log:
  `NullReferenceException: Object reference not set to an instance of an object.`
  at `UnityEngine.Rendering.VolumeComponent.OnEnable`.
- Cleanup restored loader config, release-safe native DLL, ClientSettings, and
  no game process remained.

Decision:

- Reject `VolumeProfile.Add(Type)` / injected `VolumeComponent` instantiation
  as proven-safe in this stage.
- Keep the result as useful negative evidence: IL2CPP type registration worked,
  but volume-component OnEnable initialization did not.

## Fix

The probe was narrowed to global-settings registration only:

- Register the injected type through `ClassInjector`.
- Append the type string to
  `HDRenderPipelineGlobalSettings.afterPostProcessCustomPostProcesses`.
- Call `HDRenderPipelineGlobalSettings.RefreshPostProcessTypes()`.
- Do not call `VolumeProfile.Add(Type)`.
- Do not create a custom `Volume`.
- Log `volumeCreated=False; renderActive=False`.

## Second Run

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage custom-postprocess-registration -ArtifactLabel custom-postprocess-registration-1080p-menu-20260607-r2 -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Artifacts:

- `artifacts/runtime-logs/LogOutput-custom-postprocess-registration-1080p-menu-20260607-r2.log`
- `artifacts/runtime-logs/Analysis-custom-postprocess-registration-1080p-menu-20260607-r2.txt`
- `artifacts/runtime-logs/Player-custom-postprocess-registration-1080p-menu-20260607-r2.log`
- `artifacts/runtime-logs/ClientSettings-custom-postprocess-registration-1080p-menu-20260607-r2.before.json`

Run summary:

- `CrashEventCount=0`.
- `ExitedBeforeWindow=False`.
- `ClosedByScript=True`.
- `RestoredLoaderConfig=True`.
- `RestoredReleaseSafeNative=True`.
- `RestoredClientSettings=True`.
- `GameReportedWidth=1920`.
- `GameReportedHeight=1080`.
- `GameReportedFullScreenMode=Windowed`.

Analyzer summary:

- `Stage 1 Loader=Pass`.
- `HDRP Custom PostProcess Registration=Pass`.
- Native/DLSS/RenderGraph resource stages: `Missing`, as expected.

Focused evidence:

- `Custom post-process registration probe IL2CPP type registered.` count: `1`.
- `Custom post-process registration probe installed:` count: `1`.
- Install line:
  `addedToGlobalSettings=True; volumeCreated=False; renderActive=False`.
- BepInEx log `NullReference`: `0`.
- Player log `NullReference`: `0`.
- `RenderGraph GetTexture call #`: `0`.
- `D3D11 texture pointer probe`: `0`.
- `NGX` / `nvngx` / `ExecuteDLSS`: `0`.
- `DLSS evaluate` / `DLSS *evaluate probe`: `0`.

## Decision

Accept `custom-postprocess-registration` as a menu-validated HDRP
global-settings registration proof only.

Do not treat it as a volume mount, render-function, command-buffer, resource,
or DLSS evaluate proof. The next CustomPostProcess step must be separately
guarded and must first address the `VolumeComponent.OnEnable` instantiation
failure or use another safe way to observe/drive the boundary.
