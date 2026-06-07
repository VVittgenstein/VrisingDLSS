# HDRP Custom PostProcess Render-Entry Preflight Implementation - 2026-06-07

Status: implemented, statically validated, and runtime rejected as an unchanged
mount route. See
`docs/development/custom-postprocess-render-entry-menu-result-2026-06-07.md`.

## Question

Can the CustomPostProcess route be advanced from global-settings registration
to an actual HDRP render-entry proof without touching native texture pointers
or evaluating DLSS?

This preflight adds the next default-off stage only. It is not runtime evidence
that V Rising calls the injected component yet.

## Source Basis

Unity HDRP 2022.3 `HDRenderPipeline.PostProcess.cs` records custom
post-processes by:

- Looking up each type string from
  `HDRenderPipelineGlobalSettings.afterPostProcessCustomPostProcesses`.
- Calling `hdCamera.volumeStack.GetComponent(type)`.
- Requiring the component to implement `IPostProcessComponent` and return
  `IsActive() == true`.
- Recording a RenderGraph pass that reads depth, normal, motion vectors, and
  source.
- In the pass render function, binding `_CameraDepthTexture`,
  `_NormalBufferTexture`, `_CameraMotionVectorsTexture`, and
  `_CustomPostProcessInput`, then calling
  `customPostProcess.Render(ctx.cmd, hdCamera, source, destination)`.

Unity CoreRP 2022.3 volume source explains the earlier failure:

- `VolumeProfile.Add(Type)` creates the component through
  `ScriptableObject.CreateInstance(type)`.
- `VolumeComponent.OnEnable()` immediately calls `parameterList.Clear()`.
- The previous injected component failed when its IL2CPP wrapper reached
  `OnEnable()` with `parameterList == null`.

## Implementation

Added config key:

`Diagnostics.EnableCustomPostProcessRenderEntryProbe=false`

Added helper stage:

`custom-postprocess-render-entry`

The stage enables:

- `EnableCustomPostProcessRenderEntryProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`
- `EnableDLSS=false`

Runtime behavior when deliberately enabled:

- Registers an injected `RenderEntryComponent` with `ClassInjector`.
- Appends its type string to
  `HDRenderPipelineGlobalSettings.afterPostProcessCustomPostProcesses`.
- Creates a hidden, global, layer-0 `Volume`.
- Creates a hidden `VolumeProfile`.
- Adds the injected component to the profile using the IL2CPP type handle.
- Initializes the injected component's `parameterList` in its constructor, and
  also after `VolumeProfile.Add(...)` returns if it ever returns.
- Returns `IsActive() == true`.
- In `Render(...)`, calls only
  `HDUtils.BlitCameraTexture(cmd, source, destination)` to preserve the post
  process chain, then logs the first entry and every 300th entry.
- Removes the global-settings type string and destroys the mounted objects on
  plugin unload.

Safety boundary:

- No native bridge required.
- No native texture pointer read.
- No D3D11 validation.
- No NGX/DLSS runtime load, init, feature creation, or evaluate.
- No RenderGraph `GetTexture` discovery.
- No generated HDRP render-func Harmony patching.
- No movement/gameplay input.

## Expected Runtime Interpretation

Pass:

- Analyzer reports `HDRP Custom PostProcess Render Entry=Pass`.
- Log contains `Custom post-process render-entry probe Render #1`.
- Log contains `copy=HDUtils.BlitCameraTexture`.
- `RenderGraph GetTexture call #`, D3D11, NGX, `ExecuteDLSS`, and DLSS
  evaluate lines remain absent.
- No `VolumeComponent.OnEnable` `NullReferenceException` appears.

Started but not pass:

- Global settings registration and volume mount log, but no
  `Render #` line. This means the component was mounted but HDRP did not call
  the render boundary in the observed scene/window.

Fail:

- `Custom post-process render-entry probe failed:`
- `Custom post-process render-entry probe copy failed`
- `VolumeComponent.OnEnable` `NullReferenceException`

## Validation

Local validation completed without launching V Rising:

- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
  passed with `0` warnings and `0` errors.
- `scripts\write-diagnostic-config.ps1 -Stage custom-postprocess-render-entry -OutputPath artifacts\dryrun\VrisingDLSS-custom-postprocess-render-entry.cfg -DryRun`
  reported `LaunchesGame : False` and produced a config with only
  `EnableCustomPostProcessRenderEntryProbe=true`,
  `EnableRenderGraphGetTextureProbe=false`,
  `EnableHookProbe=false`, and `EnableDLSS=false`.
- `scripts\write-diagnostic-config.ps1 -Stage custom-postprocess-render-entry -OutputPath artifacts\dryrun\VrisingDLSS-custom-postprocess-render-entry.cfg`
  wrote the same launch-free helper config.
- `scripts\check-release-boundary.ps1` passed.
- `scripts\package-thunderstore.ps1` passed release-boundary and Thunderstore
  validation and recreated `dist\VrisingDLSS-0.1.0-thunderstore.zip`.
- `scripts\validate-thunderstore-package.ps1 -PackagePath dist\VrisingDLSS-0.1.0-thunderstore.zip`
  passed.
- `git diff --check` passed.

## Runtime Result

Two menu-only runtime runs were completed after this implementation:

- `custom-postprocess-render-entry-1080p-menu-20260607-r1` crashed before the
  diagnostic window ended with WER exception `0xc00000fd` in `KERNELBASE.dll`.
  The likely failure was the injected component's `OnEnable()` override calling
  `base.OnEnable()` through a generated IL2CPP wrapper that still used virtual
  dispatch, causing stack overflow.
- The `OnEnable()` override was removed.
- `custom-postprocess-render-entry-1080p-menu-20260607-r2` no longer crashed:
  `CrashEventCount=0`, `ExitedBeforeWindow=False`, `ClosedByScript=True`, and
  Player log reported `SetResolution 1920, 1080, fullScreenMode Windowed`.
  However, the analyzer reported
  `HDRP Custom PostProcess Render Entry=Fail` because
  `VolumeProfile.Add(...)` still threw `NullReferenceException` from
  `UnityEngine.Rendering.VolumeComponent.OnEnable()`. There was no
  `volume mounted` line and no `Render #` line.

Decision: do not rerun `custom-postprocess-render-entry` unchanged as the next
normal route. The r2 code is retained because it removes the stack-overflow
variant from this default-off stage, but `VolumeProfile.Add(...)` remains
rejected for injected component mounting.
