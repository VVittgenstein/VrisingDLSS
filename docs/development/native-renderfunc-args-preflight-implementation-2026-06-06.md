# Native RenderFunc Args Preflight Implementation - 2026-06-06

Status: implemented and statically validated; runtime proof not yet run.

## Scope

Added a separate default-off `native-renderfunc-args` diagnostic stage after the
passed `native-renderfunc-entry` menu and protected gameplay proofs.

This is an argument-shape preflight only. It reuses the existing focused EASU
native render-function entry detour and samples the raw callback argument
pointers:

- `thisPtr`
- `passDataPtr`
- `renderGraphContextPtr`
- `methodInfoPtr`

The callback does only atomic counters and last-pointer snapshots, then calls the
original trampoline. It does not dereference any pointer, read pass data, resolve
textures, call `GetTexture`, touch command buffers, load DLSS, or evaluate DLSS.
Status and evidence logs are emitted later from the existing
`CompileRenderGraph(int)` postfix path.

## Files

- `src/VrisingDLSS.Plugin/ModConfig.cs`
- `src/VrisingDLSS.Plugin/Plugin.cs`
- `src/VrisingDLSS.Plugin/FrameResourceProbe.cs`
- `scripts/write-diagnostic-config.ps1`
- `scripts/run-vrising-diagnostic.ps1`
- `scripts/start-vrising-automation-session.ps1`
- `scripts/analyze-bepinex-log.ps1`
- `scripts/get-runtime-validation-status.ps1`
- `scripts/get-release-readiness-status.ps1`
- `scripts/get-visual-validation-status.ps1`
- `package/thunderstore/VrisingDLSS.cfg`
- `scripts/validate-thunderstore-package.ps1`

## Static Validation

Build:

```powershell
& C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
```

Result: success, `0` warnings, `0` errors.

Stage config dry-run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -Stage native-renderfunc-args -OutputPath artifacts\tmp-native-renderfunc-args.cfg -DryRun
```

Result: `LaunchesGame=False`; the stage enables
`EnableNativeBridgeSmokeTest=true`, `EnableNativeRenderFuncEntryProbe=true`,
`EnableNativeRenderFuncArgumentProbe=true`,
`EnableRenderGraphGetTextureProbe=false`, `EnableUpscalerStateProbe=true`, and
`EnableHookProbe=false`. `EnableDLSS=false`.

Package validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-thunderstore-package.ps1 -PackagePath dist\VrisingDLSS-0.1.0-thunderstore.zip
```

Result: release boundary check passed; Thunderstore package validation passed.

## Runtime Protocol

Menu-first command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-args -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Use true `1920x1080` Windowed. Do not enter gameplay during the first menu proof.

Question: can the already proven EASU native render-function detour collect raw
callback argument pointers without crashing or causing hot resource discovery?

Expected evidence:

- analyzer reports `Native RenderFunc Args=Pass`;
- log contains `Native render-func argument preflight enabled`;
- log contains `Native render-func argument sample advanced:`;
- status lines include `sampleCount`, nonzero counts, and last pointer values;
- `RenderGraph GetTexture call #=0`;
- no resource, command-buffer, or DLSS evaluate logs;
- no crash or black screen;
- release-safe config/settings restored afterward.

Protected gameplay should only follow after the menu proof passes. Use the
existing `11111` save-protection protocol, send no movement keys, and restore the
protected save to `ChangeCount=0`.

## Failure Criteria

- any crash or black screen;
- `Native render-func entry probe failed:`;
- `Native render-func entry detour dispose failed:`;
- no `Native render-func argument sample advanced:` after entry install;
- any pointer dereference, resource resolution, command buffer access, or DLSS
  evaluate attempt in this stage.

## Next Boundary

If this passes in menu and protected gameplay, do not jump directly to
`DLSSPass.Render(ctx.cmd)` or a real evaluate. The next step would be a separate,
default-off resource-identity preflight designed from the observed argument
shape, still with no command-buffer access and no DLSS evaluate.
