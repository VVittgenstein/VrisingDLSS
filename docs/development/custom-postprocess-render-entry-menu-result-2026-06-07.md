# HDRP Custom PostProcess Render-Entry Menu Result - 2026-06-07

Status: rejected as an unchanged runtime route. The r2 fix removed the crash,
but `VolumeProfile.Add(...)` still cannot safely instantiate the injected
`VolumeComponent`.

## Question

Can the default-off `custom-postprocess-render-entry` stage mount an active
injected HDRP custom post-process volume and reach
`Render(cmd, camera, source, destination)` in a true `1920x1080` Windowed menu
run, without native texture access or DLSS evaluate?

## Conditions

- Scope: main-menu / startup only.
- Gameplay: not entered.
- Protected `11111` save: not touched.
- Graphics: forced Direct3D11 by the diagnostic helper.
- Resolution target: `1920x1080` Windowed.
- Inputs: none.
- Native/DLSS: no native bridge smoke, no D3D11 probe, no NGX/DLSS runtime,
  no DLSS evaluate.
- Cleanup: diagnostic helper restores loader config, release-safe native DLL,
  and `ClientSettings.json`.

## First Run

Artifact label:

`custom-postprocess-render-entry-1080p-menu-20260607-r1`

Artifacts:

- `artifacts/runtime-logs/LogOutput-custom-postprocess-render-entry-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/Analysis-custom-postprocess-render-entry-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/Player-custom-postprocess-render-entry-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/WER-custom-postprocess-render-entry-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/ClientSettings-custom-postprocess-render-entry-1080p-menu-20260607-r1.before.json`

Result:

- `VRising` exited before the diagnostic window ended.
- `CrashEventCount=1`.
- WER: `KERNELBASE.dll`, exception `0xc00000fd`.
- Analyzer: `HDRP Custom PostProcess Render Entry=Partial`.
- BepInEx log reached:
  `Custom post-process render-entry probe IL2CPP type registered.`
- BepInEx log reached:
  `Custom post-process render-entry probe global settings registered: ... addedToGlobalSettings=True`
- There was no `volume mounted` line and no `Render #` line.
- `RenderGraph GetTexture call #`, D3D11, NGX, `ExecuteDLSS`, and DLSS
  evaluate counts were `0`.
- Cleanup restored loader config, release-safe native DLL, and
  `ClientSettings.json`.

Decision:

- Reject the injected `OnEnable()` override that called `base.OnEnable()`.
- The likely failure mode is virtual dispatch recursion in the generated
  IL2CPP wrapper, producing stack overflow before the mount step could log.

## Fix

The probe was changed to:

- Remove the injected component's `OnEnable()` override.
- Keep `parameterList` initialization in the injected constructor.
- Also set `component.parameterList` after `VolumeProfile.Add(...)` returns,
  if it ever returns.

This makes the stage no longer crash unchanged, but it does not prove a usable
render-entry boundary.

## Second Run

Artifact label:

`custom-postprocess-render-entry-1080p-menu-20260607-r2`

Artifacts:

- `artifacts/runtime-logs/LogOutput-custom-postprocess-render-entry-1080p-menu-20260607-r2.log`
- `artifacts/runtime-logs/Analysis-custom-postprocess-render-entry-1080p-menu-20260607-r2.txt`
- `artifacts/runtime-logs/Player-custom-postprocess-render-entry-1080p-menu-20260607-r2.log`
- `artifacts/runtime-logs/ClientSettings-custom-postprocess-render-entry-1080p-menu-20260607-r2.before.json`

Run summary:

- `CrashEventCount=0`.
- `ExitedBeforeWindow=False`.
- `ClosedByScript=True`.
- `RestoredLoaderConfig=True`.
- `RestoredReleaseSafeNative=True`.
- `RestoredClientSettings=True`.
- Player log:
  `SetResolution 1920, 1080, fullScreenMode Windowed`.

Analyzer:

- `Stage 1 Loader=Pass`.
- `HDRP Custom PostProcess Render Entry=Fail`.
- Failure evidence:
  `Custom post-process render-entry probe failed: System.NullReferenceException`.

Focused evidence:

- BepInEx log reached:
  `Custom post-process render-entry probe IL2CPP type registered.`
- BepInEx log reached:
  `Custom post-process render-entry probe global settings registered: ... addedToGlobalSettings=True`
- BepInEx log then reported:
  `Custom post-process render-entry probe failed: System.NullReferenceException: Object reference not set to an instance of an object.`
- Player log showed:
  `NullReferenceException ... at UnityEngine.Rendering.VolumeComponent.OnEnable()`.
- BepInEx log showed:
  `Custom post-process render-entry probe global settings unregistered.`
- `Render #`: `0`.
- `Custom post-process render-entry probe volume mounted`: `0`.
- `RenderGraph GetTexture call #`: `0`.
- D3D11/NGX/`nvngx`/`ExecuteDLSS`/DLSS evaluate patterns: `0`.
- `copy failed`: `0`.

## Decision

Reject the current `VolumeProfile.Add(Il2CppType.Of<RenderEntryComponent>())`
mount path as a safe runtime route for this injected `VolumeComponent`.

The r2 code is still worth keeping because it removes the stack-overflow
failure from the default-off stage, but the unchanged stage should not be
rerun as the next normal route.

Next work should avoid `VolumeProfile.Add(...)` for injected volume creation,
or use a different boundary entirely. Reasonable follow-ups include:

- Inspecting whether `VolumeManager` / `VolumeStack` can be safely extended
  with a default component without `VolumeProfile.Add(...)`.
- Inspecting whether an existing V Rising/HDRP custom post-process instance can
  be observed or used as a clean-room boundary without reusing private
  implementation.
- Returning to official RenderGraph pass-equivalent boundaries if the volume
  route remains blocked.
