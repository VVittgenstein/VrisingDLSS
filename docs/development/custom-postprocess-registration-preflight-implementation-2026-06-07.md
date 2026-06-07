# HDRP Custom PostProcess Registration Preflight Implementation - 2026-06-07

Status: implemented, statically validated, and menu validated.

## Question

After the narrow HDRP DLSS boundary refresh identified
`CustomPostProcessVolumeComponent.Render(cmd, camera, source, destination)` as
a source-backed official HDRP command-buffer boundary, can V Rising/BepInEx
register an HDRP custom post-process type with HDRP global settings without
touching render resources or DLSS?

This preflight answers only the registration half of that question. It does not
prove that mounting a volume component or rendering through the custom
post-process boundary is safe.

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
- Keeps `RegistrationComponent.IsActive()` returning `false`.
- Removes the type string on plugin unload.

Safety boundary:

- No `Render(...)` body work.
- No `VolumeProfile.Add(Type)` call.
- No custom `Volume` creation.
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
- The install line reports `addedToGlobalSettings=True`,
  `volumeCreated=False`, and `renderActive=False`.
- No `RenderGraph GetTexture call #`, D3D11, NGX, `ExecuteDLSS`, or evaluate
  lines appear.

Blocked:

- `HDRenderPipelineGlobalSettings.instance` is null.
- `afterPostProcessCustomPostProcesses` is null.
- The build lacks local V Rising HDRP interop assemblies and uses the stub.

Rejected sub-route:

- The first menu run attempted to also create an inactive `VolumeProfile`
  component using `VolumeProfile.Add(Type)`.
- That path registered the IL2CPP type but then threw
  `NullReferenceException` in `UnityEngine.Rendering.VolumeComponent.OnEnable`.
- It is not safe to treat injected `VolumeComponent` instantiation as proven
  from this stage.

Even a pass is only a global-settings registration proof. A later mount/render
proof must be a separate default-off stage that avoids or solves the
`VolumeComponent.OnEnable` failure, copies source to destination or otherwise
preserves the HDRP post-process chain, and has its own launch contract and
cleanup plan.

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

Runtime validation:

- First menu run
  `custom-postprocess-registration-1080p-menu-20260607-r1` was stable but
  failed the stage: analyzer reported
  `HDRP Custom PostProcess Registration=Fail`, BepInEx logged
  `Custom post-process registration probe failed: System.NullReferenceException`,
  and Player log showed the exception came from
  `UnityEngine.Rendering.VolumeComponent.OnEnable`. Cleanup still restored
  config/native/ClientSettings and left no game process.
- The probe was narrowed to global-settings registration only, with
  `volumeCreated=False`.
- Second menu run
  `custom-postprocess-registration-1080p-menu-20260607-r2` passed at true
  `1920x1080` Windowed. Analyzer reported
  `HDRP Custom PostProcess Registration=Pass`; the install line showed
  `addedToGlobalSettings=True; volumeCreated=False; renderActive=False`.
  `CrashEventCount=0`, BepInEx and Player logs had `0` `NullReference` lines,
  `RenderGraph GetTexture call #=0`, D3D11/NGX/DLSS evaluate patterns were
  `0`, cleanup restored loader config, release-safe native DLL, and
  ClientSettings, and no game process remained.

See
`docs/development/custom-postprocess-registration-menu-result-2026-06-07.md`.
