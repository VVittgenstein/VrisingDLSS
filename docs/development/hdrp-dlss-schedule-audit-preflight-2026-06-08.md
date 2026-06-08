# HDRP DLSS Schedule Audit Preflight - 2026-06-08

Status: implemented and runtime-tested. Runtime result is recorded in
`docs/development/hdrp-dlss-schedule-audit-runtime-result-2026-06-08.md`.

## Question

Does V Rising's HDRP RenderGraph ever schedule Unity's official
`"Deep Learning Super Sampling"` pass under current local settings, and can we
observe that boundary without using broad `RenderGraph.GetTexture`, patching
generated render funcs, patching `DLSSPass.Render`, or submitting native DLSS
work?

This is the narrow follow-up to the rejected same-shape EASU `ctx.cmd`
candidate. The official-HDRP-like feature flags and invert-axis parity are now
correctness alignment, but they did not fix the low-GPU-utilization performance
regression.

## Design

Added diagnostic stage:

```powershell
scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage hdrp-dlss-schedule-audit -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

The stage writes a release-safe/read-only config shape:

- `DLSS.EnableDLSS=false`
- `Diagnostics.EnableRenderGraphPassListProbe=true`
- `Diagnostics.EnableRenderGraphPassResourceDeclarationProbe=true`
- `Diagnostics.EnableRenderGraphPassDataSnapshotProbe=true`
- `Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe=true`
- `Diagnostics.EnableRenderGraphCompiledPassInfoProbe=true`
- `Diagnostics.EnableUpscalerStateProbe=true`
- `Diagnostics.EnableRenderGraphGetTextureProbe=false`
- `Diagnostics.EnableHookProbe=false`

It intentionally does not enable:

- `Diagnostics.EnableDlssUserRenderingNoEvaluateProbe`
- any SDK-wrapper DLSS evaluate/write-back probe
- any native render-func detour/proxy
- `DLSS.EnableDLSS=true`

The reason `DLSS.EnableDLSS` remains false is important: in the current plugin
that setting starts the experimental user-rendering candidate. The schedule
audit must first observe HDRP state and RenderGraph pass scheduling without
polluting the evidence with our native candidate path.

## Added Analyzer

Added:

```powershell
scripts\analyze-hdrp-dlss-schedule-audit.ps1 -LogPath <archived-LogOutput.log>
```

The analyzer counts:

- `"Deep Learning Super Sampling"` pass/category evidence
- DLSS pass data/declaration/render-func/compiled-info lines
- EASU/final-pass mentions
- `Upscaler state probe` snapshots/calls
- `HDCamera.IsDLSSEnabled`, `GlobalDynamicResolutionSettings.enableDLSS`,
  `allowDeepLearningSuperSampling`, and `cameraCanRenderDLSS` state hints
- pollution indicators: user-rendering evaluate, broad `RenderGraph GetTexture`
  calls, crash/access-violation indicators

Possible statuses:

- `OfficialDlssPassObserved`: official pass shell appeared; next work should use
  the logged `DLSSData`/resource declarations to design a no-native
  official-equivalent boundary proof.
- `NoOfficialDlssPassObserved`: RenderGraph/upscaler logs were captured but no
  official DLSS pass was scheduled; next work should identify which camera or
  global dynamic-resolution state gates the pass off before any state-changing
  patch.
- `Fail`: the audit was polluted by native user-rendering/GetTexture/crash
  evidence or did not capture required logs.
- `Incomplete`: rerun longer or in a better scene.

## Runtime Preflight

Before running the stage:

1. Verify no `VRising` process is already running.
2. Use true `1920x1080` Windowed.
3. Keep V Rising FSR state recorded; do not rely on FSR for this audit.
4. State the expected evidence in the runtime note before launch.

Expected acceptable outcomes:

- Official pass appears:
  `Deep Learning Super Sampling` pass entry plus focused pass-data/declaration
  logs, with no native evaluate, no `RenderGraph GetTexture` logs, and no crash.
- Official pass does not appear:
  RenderGraph compile snapshots and upscaler-state logs appear, no native
  evaluate/GetTexture/crash evidence appears, and state hints explain why DLSS is
  gated off.

Failure signals:

- Any `DLSS user rendering evaluate succeeded` line.
- Any `Native render-func command-buffer DLSS user-rendering` line.
- Any broad `RenderGraph GetTexture call #` line.
- Any `0xc0000005`, access violation, `coreclr`, or `nvwgf2umx` crash evidence.
- Missing RenderGraph compile snapshots or missing upscaler-state evidence.

Cleanup requirements:

- Game process closed.
- Loader config restored with `DLSS.EnableDLSS=false`.
- Dangerous probes disabled.
- Release-safe native restored if a diagnostic install copied files.
- Protected save restored to `ChangeCount=0` if gameplay is entered.
- Archived `LogOutput`, generic analyzer output, schedule-audit analyzer output,
  WER output if present, and player log/resolution evidence.

## Current Decision

Do not rerun the same EASU `ctx.cmd` visual/performance candidate unchanged.
The next runtime step is this schedule audit because it separates two questions
that were previously tangled:

1. Does V Rising/HDRP ever create the official DLSS RenderGraph pass shell in
   practice?
2. If not, which state gate prevents it, and is there a BepInEx-safe boundary to
   approach before `DoDLSSPass` without patching `DLSSPass.Render`?

## Non-Runtime Validation

Validation performed without launching V Rising:

- `scripts\write-diagnostic-config.ps1 -Stage hdrp-dlss-schedule-audit -DryRun`
  produced the intended safe config: `EnableDLSS=false`, no user-rendering
  no-evaluate probe, no native render-func entry probe, no broad
  `RenderGraph.GetTexture`, with the focused RenderGraph/upscaler probes on.
- `scripts\run-vrising-diagnostic.ps1 -Stage hdrp-dlss-schedule-audit -DryRun`
  accepted the stage and reported `LaunchesGame=False`.
- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
  passed with 0 warnings and 0 errors.
- `scripts\get-release-readiness-status.ps1 -GamePath C:\Software\VRising`
  still reports `DiagnosticPackageReady_MvpBlocked` and now recommends this
  schedule audit instead of rerunning the rejected EASU candidate unchanged.
- `scripts\get-visual-validation-status.ps1 -Root Z:\VrisingDLSS` remains
  blocked by the known official-flags candidate performance regression and now
  points to this schedule audit as the next technical action.
- Analyzer sanity checks on existing read-only RenderGraph logs classified them
  as `NoOfficialDlssPassObserved` with no issues:
  `LogOutput-rendergraph-pass-data-1080p-menu-20260606-r3.log` and
  `LogOutput-rendergraph-renderfunc-metadata-1080p-menu-20260606-r3.log`.
- Analyzer sanity check on the rejected
  `LogOutput-official-flags-paired-user-rendering-1080p-20260608-r2-user-rendering.log`
  classified it as `Fail`, because it contains native user-rendering/evaluate
  evidence and is therefore not valid schedule-audit evidence.
