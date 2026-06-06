# Native RenderFunc Entry Probe Implementation - 2026-06-06

Status: implemented and statically validated. Runtime proof has not been run.

## Scope

Added a separate default-off `native-renderfunc-entry` diagnostic stage for the
official HDRP RenderGraph execution-boundary investigation.

The probe:

- uses `CompileRenderGraph(int)` only as the safe observation point;
- targets one pass: `Edge Adaptive Spatial Upsampling`;
- waits for the same nonzero `method_ptr` to be observed three times;
- creates an Il2CppInterop detour through
  `Il2CppInteropRuntime.Instance.DetourProvider.Create(...)`;
- generates the original trampoline before applying the detour;
- increments one atomic counter in the native entry callback;
- immediately calls the original trampoline;
- emits capped status and counter logs from the compile postfix;
- does not resolve textures, call `GetTexture`, touch command buffers, read
  pass data, load DLSS, or evaluate DLSS.

## Files

- `src/VrisingDLSS.Plugin/ModConfig.cs`
- `src/VrisingDLSS.Plugin/Plugin.cs`
- `src/VrisingDLSS.Plugin/FrameResourceProbe.cs`
- `scripts/write-diagnostic-config.ps1`
- `scripts/run-vrising-diagnostic.ps1`
- `scripts/start-vrising-automation-session.ps1`
- `scripts/analyze-bepinex-log.ps1`
- `scripts/get-runtime-validation-status.ps1`
- `package/thunderstore/VrisingDLSS.cfg`
- `scripts/validate-thunderstore-package.ps1`

## Static Validation

Build:

```powershell
$env:DOTNET_ROOT='C:\Software\dotnet'
& C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
```

Result: success, `0` warnings, `0` errors.

Stage config dry-run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -Stage native-renderfunc-entry -OutputPath artifacts\tmp-native-renderfunc-entry.cfg -DryRun
```

Result: `LaunchesGame=False`; the stage enables
`EnableNativeBridgeSmokeTest=true`, `EnableNativeRenderFuncEntryProbe=true`,
`EnableRenderGraphGetTextureProbe=false`, `EnableUpscalerStateProbe=true`, and
`EnableHookProbe=false`.

## Runtime Protocol

Do not use this as a production path yet. First proof must be menu-only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-entry -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Use true `1920x1080` Windowed. Do not enter gameplay and do not touch the
protected `11111` save unless a later protocol explicitly requires it.

Pass criteria:

- no WER crash;
- analyzer reports `Native RenderFunc Entry=Pass`;
- log contains `Native render-func entry detour installed:`;
- log contains `Native render-func entry count advanced:`;
- `RenderGraph GetTexture call #=0`;
- release-safe config/settings restored afterward.

Failure criteria:

- any crash or black screen;
- `Native render-func entry probe failed:`;
- no counter advance after install;
- any resource resolution, command buffer access, or DLSS evaluate attempt.
