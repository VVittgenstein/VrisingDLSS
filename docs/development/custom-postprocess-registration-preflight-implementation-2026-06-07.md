# HDRP Custom PostProcess Registration Preflight Implementation - 2026-06-07

Status: implemented and statically validated. Runtime menu/gameplay validation
has not been run yet.

## Question

After the narrow HDRP DLSS boundary refresh identified
`CustomPostProcessVolumeComponent.Render(cmd, camera, source, destination)` as
a source-backed official HDRP command-buffer boundary, can V Rising/BepInEx
register and mount an HDRP custom post-process component without touching
render resources or DLSS?

This preflight answers only the registration half of that question. It does not
prove that rendering through the custom post-process boundary is safe.

## Implementation

Added config key:

`Diagnostics.EnableCustomPostProcessRegistrationProbe=false`

Helper stage:

`custom-postprocess-registration`

The stage enables:

- `EnableCustomPostProcessRegistrationProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`
- `EnableDLSS=false`

Runtime behavior:

- Registers an injected `RegistrationComponent` with `ClassInjector`.
- Marks it as implementing HDRP `IPostProcessComponent` via
  `Il2CppImplementsAttribute`.
- Appends the injected component type string to
  `HDRenderPipelineGlobalSettings.afterPostProcessCustomPostProcesses`.
- Calls `HDRenderPipelineGlobalSettings.RefreshPostProcessTypes()`.
- Creates a hidden, inactive global `Volume` with a private `VolumeProfile`.
- Adds the injected component to that profile and sets `component.active=false`.
- Keeps `RegistrationComponent.IsActive()` returning `false`.
- Removes the type string and destroys the probe object on plugin unload.

Safety boundary:

- No `Render(...)` body work.
- No command-buffer commands.
- No RenderGraph resource lookup.
- No native texture pointer reads.
- No D3D11 validation.
- No NGX/DLSS init or evaluate.
- No generated HDRP render-func Harmony patch.

## Expected Runtime Interpretation

Pass:

- Analyzer reports `HDRP Custom PostProcess Registration=Pass`.
- Log contains `Custom post-process registration probe installed:`.
- The install line reports `componentActive=False` and `isActive=False`.
- No `RenderGraph GetTexture call #`, D3D11, NGX, `ExecuteDLSS`, or evaluate
  lines appear.

Blocked:

- `HDRenderPipelineGlobalSettings.instance` is null.
- `afterPostProcessCustomPostProcesses` is null.
- The build lacks local V Rising HDRP interop assemblies and uses the stub.

Even a pass is only a registration proof. A later render proof must be a
separate default-off stage that copies source to destination or otherwise
preserves the HDRP post-process chain, with its own launch contract and cleanup
plan.

## Validation

Local validation completed without launching V Rising:

- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
  passed with `0` warnings and `0` errors.
- `scripts\write-diagnostic-config.ps1 -Stage custom-postprocess-registration -OutputPath artifacts\dryrun\VrisingDLSS.cfg -DryRun`
  reported `LaunchesGame : False` and produced a config with only
  `EnableCustomPostProcessRegistrationProbe=true`,
  `EnableRenderGraphGetTextureProbe=false`, `EnableHookProbe=false`, and
  `EnableDLSS=false`.
- `scripts\check-release-boundary.ps1` passed.
- `scripts\package-thunderstore.ps1` passed release-boundary and Thunderstore
  validation and recreated `dist\VrisingDLSS-0.1.0-thunderstore.zip`.
- `scripts\validate-thunderstore-package.ps1 -PackagePath dist\VrisingDLSS-0.1.0-thunderstore.zip`
  passed, including packaged default
  `EnableCustomPostProcessRegistrationProbe = false`.
- `git diff --check` passed.
