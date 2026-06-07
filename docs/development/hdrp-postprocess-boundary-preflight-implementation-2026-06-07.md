# HDRP PostProcess Boundary Preflight Implementation - 2026-06-07

Status: implemented, statically validated, and menu-runtime partial. Runtime
result is recorded in
`docs/development/hdrp-postprocess-boundary-menu-result-2026-06-07.md`.
Runtime r1/r2 rejected the all-target direct Harmony patch shape; r3 proved the
active ProjectM-only target set is menu-stable but not reached in the main menu.

## Question

After local IL2CPP/HDRP xref analysis, can a default-off no-native Harmony probe
observe which official HDRP and existing ProjectM postprocess boundaries are
actually reached in V Rising without using broad RenderGraph `GetTexture`
discovery?

## Why This Exists

The previous injected custom postprocess mount route is rejected unchanged:
`VolumeProfile.Add(...)` still fails in `VolumeComponent.OnEnable()` before
`Render(...)`. The decompilation/xref pass then showed two narrower boundary
families:

- Official HDRP postprocess/DLSS methods:
  `RenderPostProcess`, `DoDLSSPasses`, `DoDLSSPass`,
  `CustomPostProcessPass`.
- Existing ProjectM concrete custom postprocess renders:
  `CustomVignette`, `LineOfSightVision`, `LineOfSight`, `BatFormFog`,
  `DarkForeground`, and `ProjectM.ContestAreaEffect`.

This preflight turns that evidence into a runtime hit-map only.

## Implementation

New plugin file:

- `src/VrisingDLSS.Plugin/HdrpPostProcessBoundaryProbe.cs`

New config key:

```ini
[Diagnostics]
EnableHdrpPostProcessBoundaryProbe = false
```

New helper stage:

```text
hdrp-postprocess-boundary
```

Runtime behavior when deliberately enabled:

- Installs a Harmony prefix on:
  - `CustomVignette.Render`
  - `LineOfSightVision.Render`
  - `LineOfSight.Render`
  - `BatFormFog.Render`
  - `DarkForeground.Render`
  - `ProjectM.ContestAreaEffect.Render`
- Logs sparse call lines:

```text
HDRP postprocess boundary probe call #...
```

- Summarizes method role and original method only. It deliberately does not
  request `__instance` or `__args` from Harmony because the HDRP methods include
  IL2CPP value-type/byref parameters such as `TextureHandle` and
  `PrepassOutput&`.

The stage explicitly does not:

- Directly patch `HDRenderPipeline.RenderPostProcess`, `DoDLSSPasses`,
  `DoDLSSPass`, or `CustomPostProcessPass`.
- Call or patch `RenderGraphResourceRegistry.GetTexture(TextureHandle&)`.
- Create or mount a custom `Volume`.
- Resolve RenderGraph resources.
- Read native texture pointers.
- Use D3D11 validation.
- Issue command-buffer work.
- Load the native bridge.
- Initialize NGX or evaluate DLSS.

## Script Integration

Updated scripts:

- `scripts/write-diagnostic-config.ps1`
- `scripts/run-vrising-diagnostic.ps1`
- `scripts/start-vrising-automation-session.ps1`
- `scripts/analyze-bepinex-log.ps1`
- `scripts/get-runtime-validation-status.ps1`
- `scripts/get-release-readiness-status.ps1`
- `scripts/get-visual-validation-status.ps1`

Dry-run config should show:

- `EnableHdrpPostProcessBoundaryProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`
- `EnableDLSS=false`
- no native/D3D11/DLSS diagnostic switches enabled

## Static Validation

Completed without launching V Rising:

```powershell
C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
```

Result: passed with `0` warnings and `0` errors.

PowerShell parser validation passed for the updated scripts:

- `scripts/write-diagnostic-config.ps1`
- `scripts/run-vrising-diagnostic.ps1`
- `scripts/start-vrising-automation-session.ps1`
- `scripts/analyze-bepinex-log.ps1`
- `scripts/get-runtime-validation-status.ps1`
- `scripts/get-release-readiness-status.ps1`
- `scripts/get-visual-validation-status.ps1`

Dry-run config validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -Stage hdrp-postprocess-boundary -OutputPath artifacts\dryrun\VrisingDLSS-hdrp-postprocess-boundary.cfg -DryRun
```

Result: `LaunchesGame=False` and only the intended boundary probe switch was
enabled.

`git diff --check` passed.

## Runtime Contract

The first ProjectM-only menu runtime run used:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage hdrp-postprocess-boundary -ArtifactLabel hdrp-postprocess-boundary-1080p-menu-20260607-r3 -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Question: can the existing ProjectM custom postprocess `Render(...)` overrides
be patched safely, and are any reached in the main menu?

Hypothesis: the ProjectM concrete render overrides can be patched without the
coreclr crash seen in r1/r2. They may require gameplay and can remain absent in
a menu-only run.

Pass signal:

- Analyzer reports `HDRP PostProcess Boundary=Pass`.
- BepInEx log contains at least one
  `HDRP postprocess boundary probe call #` line.

Partial signal:

- Probe patches methods but no boundary call appears in menu logs. This should
  lead to a protected `11111` gameplay proof, not an immediate rejection.

Fail signal:

- Harmony patch failure.
- Prefix failure.
- WER crash or early process exit.
- Any unexpected `RenderGraph GetTexture call #`, D3D11, NGX, or DLSS evaluate
  evidence.

Cleanup path:

- Restore loader config.
- Restore release-safe native DLL.
- Restore `ClientSettings.json`.
- Leave no V Rising process.
- The protected `11111` save should not be touched in the menu-only run.

## Runtime Rejections So Far

- `hdrp-postprocess-boundary-1080p-menu-20260607-r1` patched all 10 initial
  targets, including direct `HDRenderPipeline.*` methods, but crashed before
  the diagnostic window ended with WER `0xc0000005` in `coreclr.dll`. No
  `call #`, `GetTexture`, D3D11/NGX/DLSS/evaluate lines appeared.
- r1 likely over-requested Harmony wrapping by asking for `__instance` and
  `__args` on methods with IL2CPP value-type/byref parameters.
- The prefix was narrowed to `__originalMethod` only.
- `hdrp-postprocess-boundary-1080p-menu-20260607-r2` still crashed the same
  way after patching all 10 targets and before any `call #` line.

Decision: reject unchanged all-target direct Harmony patching for this probe.
Keep official `HDRenderPipeline.RenderPostProcess -> DoDLSSPasses ->
DoDLSSPass` as static xref/source evidence only for now. Runtime proof should
first test the safer ProjectM concrete custom postprocess render overrides.

## Menu Runtime Result

Run `hdrp-postprocess-boundary-1080p-menu-20260607-r3` passed patch stability
but did not reach a ProjectM custom postprocess render override in the menu:

- `CrashEventCount=0`
- `ExitedBeforeWindow=False`
- `ClosedByScript=True`
- patched ProjectM concrete `Render(...)` methods: `6`
- `HDRP postprocess boundary probe call #`: `0`
- `RenderGraph GetTexture call #`: `0`
- D3D11/NGX/DLSS/evaluate patterns: `0`
- cleanup restored loader config, release-safe native, and `ClientSettings.json`

Decision: keep the ProjectM-only stage and run a protected `11111` gameplay
proof next. If gameplay also produces no call, reject this ProjectM custom
postprocess render route as a practical evaluate-boundary candidate.
