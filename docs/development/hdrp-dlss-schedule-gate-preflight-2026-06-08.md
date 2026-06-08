# HDRP DLSS Schedule Gate Preflight - 2026-06-08

Status: implemented, non-runtime validated, not runtime-tested yet.

## Question

If we deliberately set V Rising/HDRP's official DLSS scheduling gates without
starting the mod's native/user-rendering DLSS candidate, does the official
RenderGraph `"Deep Learning Super Sampling"` pass shell appear?

This follows the read-only `hdrp-dlss-schedule-audit` result, which captured
normal EASU/final passes but no official DLSS pass. The important gate evidence
was:

- `allowDeepLearningSuperSampling=True`
- `cameraCanRenderDLSS=False`
- `GlobalDynamicResolutionSettings.enableDLSS=False`
- `HDCamera.IsDLSSEnabled=False`
- `UpsampleSyncPoint=AfterPost`

Unity HDRP source shows `SetupDLSSForCameraDataAndDynamicResHandler` only sets
`cameraCanRenderDLSS` when the camera requests dynamic resolution, DLSS platform
support is detected, camera DLSS is allowed, and HDRP asset dynamic-resolution
settings have both `enabled` and `enableDLSS` true.

## Probe Design

Added default-off config key:

- `Diagnostics.EnableHdrpDlssScheduleGateProbe=false`

When enabled, `HdrpDlssScheduleGateProbe` patches only:

- `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler(...)`

The probe intentionally does not:

- set `DLSS.EnableDLSS=true`
- load NGX or require `DlssRuntimePath`
- enable any SDK-wrapper evaluate/write-back probe
- enable native render-func detours
- patch `DLSSPass.Render`
- call broad `RenderGraph.GetTexture`

The prefix/postfix mutate and log only scheduling gates:

- `HDAdditionalCameraData.allowDynamicResolution=true`
- `HDAdditionalCameraData.allowDeepLearningSuperSampling=true`
- custom DLSS quality/attributes set to the selected quality mode
- `UnityEngine.Camera.allowDynamicResolution=true`
- `cameraRequestedDynamicRes=true`
- `GlobalDynamicResolutionSettings.enabled=true`
- `GlobalDynamicResolutionSettings.enableDLSS=true`
- `useMipBias=true`
- `DLSSUseOptimalSettings=false`
- `DLSSInjectionPoint=BeforePost`
- `dynResType=Hardware`
- `upsampleFilter=TAAU`
- forced percentage based on `DLSS.QualityMode` (`Performance` defaults to
  `50%`)

The postfix also forces `cameraCanRenderDLSS=true` if official setup still
leaves it false. This is deliberate for the gate experiment: if the official
pass shell still does not appear, the next blocker is likely `m_DLSSPass`,
`DLSSPass.Create`, or NVIDIA module availability rather than camera gate state.

Each call logs:

- platform `DLSSDetected`
- `m_DLSSPass`
- `m_DLSSPassEnabled`
- camera request state
- `HDAdditionalCameraData` DLSS fields
- Unity camera dynamic-resolution state
- `outDrsSettings`
- HDRP asset dynamic-resolution settings

## Stage

Added diagnostic stage:

```powershell
scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage hdrp-dlss-schedule-gate -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Generated config shape:

- `DLSS.EnableDLSS=false`
- `Diagnostics.EnableHdrpDlssScheduleGateProbe=true`
- `Diagnostics.EnableRenderGraphPassListProbe=true`
- `Diagnostics.EnableRenderGraphPassResourceDeclarationProbe=true`
- `Diagnostics.EnableRenderGraphPassDataSnapshotProbe=true`
- `Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe=true`
- `Diagnostics.EnableRenderGraphCompiledPassInfoProbe=true`
- `Diagnostics.EnableUpscalerStateProbe=true`
- `Diagnostics.EnableRenderGraphGetTextureProbe=false`
- `Diagnostics.EnableHookProbe=false`
- all native/evaluate/user-rendering probes remain false

## Expected Evidence

Acceptable success:

- `HDRP DLSS schedule-gate prefix:` / `postfix:` lines appear.
- `cameraCanRenderDLSS` is true after the postfix, or the log explains why the
  write failed.
- RenderGraph observation lines appear.
- The official `"Deep Learning Super Sampling"` pass appears with pass-data,
  resource declarations, render-func metadata, and/or compiled-pass info.
- No native/user-rendering/evaluate/GetTexture/crash evidence appears.

Acceptable negative result:

- The schedule-gate logs appear and prove the intended gate writes.
- RenderGraph/upscaler logs appear.
- No official `"Deep Learning Super Sampling"` pass appears.
- The gate logs show whether `m_DLSSPass=null` or `m_DLSSPassEnabled=false`.
- No native/user-rendering/evaluate/GetTexture/crash evidence appears.

Failure signals:

- Any `DLSS user rendering evaluate succeeded` line.
- Any `Native render-func command-buffer DLSS user-rendering` line.
- Any broad `RenderGraph GetTexture call #` line.
- Any `0xc0000005`, access violation, `coreclr`, or `nvwgf2umx` crash evidence.
- `HDRP DLSS schedule-gate failed to patch`.
- `HDRP DLSS schedule-gate member write did not stick`.
- Missing RenderGraph compile snapshots or missing upscaler-state evidence.

## Runtime Protocol

Menu-first only for the first run:

1. Verify no `VRising` process is already running.
2. Use true `1920x1080` Windowed.
3. Do not click Continue or enter gameplay.
4. Do not use Computer Use unless window cleanup requires it.
5. Run the stage for about 75 seconds.
6. Close the game through the script cleanup.

Cleanup requirements:

- Game process closed.
- Loader config restored with `DLSS.EnableDLSS=false`.
- `Diagnostics.EnableHdrpDlssScheduleGateProbe=false`.
- Dangerous probes disabled.
- Release-safe native state unchanged/restored.
- Client settings restored if the diagnostic changed resolution/window mode.
- Protected save untouched because the first run must not enter gameplay.
- Archive `LogOutput`, generic analyzer output, schedule analyzer output, WER
  output if present, player log, and before/after `ClientSettings`.

## Analyzer Updates

`scripts\analyze-bepinex-log.ps1` now has an `HDRP DLSS Schedule Gate` stage.

`scripts\analyze-hdrp-dlss-schedule-audit.ps1` now also counts schedule-gate
logs:

- `HdrpDlssScheduleGateLogs`
- `HdrpDlssScheduleGateForcedCamera`
- `HdrpDlssScheduleGateMissingPass`

For a schedule-gate log with no official pass, its next recommendation now
points to `m_DLSSPass` / `DLSSPass.Create` / NVIDIA module availability instead
of another camera-gate audit.

## Non-Runtime Validation

Completed without launching V Rising:

- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
  passed with 0 warnings and 0 errors.
- `scripts\write-diagnostic-config.ps1 -Stage hdrp-dlss-schedule-gate -DryRun`
  accepted the stage and produced the intended no-native/no-evaluate config.
- `scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage hdrp-dlss-schedule-gate -DryRun`
  accepted the stage and reported `LaunchesGame=False`.

## Current Decision

Do not rerun the same EASU `ctx.cmd` `dlss-user-rendering` candidate unchanged.

After the later 2026-06-08 static-route pivot, do not treat this as the
immediate next runtime action. The systematic local static audit in
`docs/development/vrising-hdrp-dlss-route-static-audit-2026-06-08.md` found
that V Rising contains the HDRP DLSS pass shell, but the key
`DLSSPass.Render`/`BeginFrame`/`SetupDRSScaling` execution methods map to the
same no-op-style stub address. That makes this stage a classification tool for
`m_DLSSPass`/gate state, not a likely performance fix.

If this stage is run later, it must still be menu-only and its main branch point
is:

- If the official pass shell appears, use the logged official `DLSSData`
  resource relationship to design the next no-native official-equivalent
  boundary proof.
- If it still does not appear and `m_DLSSPass=null`, focus on the missing
  HDRP/NVIDIA DLSS pass object/module path rather than more camera gate writes.
- If it appears but render/evaluate remains no-op, keep treating the official
  HDRP path as a semantic map and avoid patching `DLSSPass.Render` directly.
