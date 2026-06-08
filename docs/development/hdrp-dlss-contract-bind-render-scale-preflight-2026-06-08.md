# HDRP DLSS Contract-Bind Render-Scale Preflight - 2026-06-08

## Purpose

Create the next default-off diagnostic stage after the contract-gap analyzer:
bind HDRP source/depth/motion evidence to the engine-owned
`Uber Post -> EASU -> Final Pass` RenderGraph chain in one log, before any
bounded no-write or visible DLSS write-back attempt.

No V Rising runtime was launched for this pass.

## New Stage

Stage name:

```text
hdrp-dlss-contract-bind-render-scale
```

This stage is intentionally not a DLSS evaluate path. It configures:

- `DLSS.EnableDLSS=false`
- `Diagnostics.EnableRenderGraphPassListProbe=true`
- `Diagnostics.EnableRenderGraphPassResourceDeclarationProbe=true`
- `Diagnostics.EnableRenderGraphPassDataSnapshotProbe=true`
- `Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe=true`
- `Diagnostics.EnableRenderGraphCompiledPassInfoProbe=true`
- `Diagnostics.EnableHdrpPostProcessRenderArgsProbe=true`
- `Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe=true`
- `Diagnostics.EnableRenderScaleControlProbe=true`
- `Diagnostics.EnableUpscalerStateProbe=true`
- `Diagnostics.EnableRenderGraphGetTextureProbe=false`
- `Diagnostics.EnableHookProbe=false`

It does not enable:

- native render-function entry/argument/context detours;
- command-buffer plugin events;
- D3D11 validation;
- NGX runtime loading;
- DLSS feature create/evaluate;
- visible write-back;
- schedule-gate mutation;
- mod-owned RenderGraph pass injection.

The only intentional state change is the existing render-scale control request,
needed to make the normal V Rising HDRP path produce a Super Resolution-sized
chain under `1920x1080` Windowed test conditions.

## Analyzer Contract

`scripts/analyze-hdrp-dlss-schedule-audit.ps1` now also reads HDRP postprocess
render-argument snapshots:

- `HdrpPostProcessRenderArgSnapshots`
- `HdrpPostProcessDepthMotionInputMatches`
- `HdrpEasuCorrelationAdvanced`
- `HdrpEasuCorrelationReady`
- `SuperResolutionChainsWithHdrpDepthMotion`
- `Boundary.FirstSuperResolutionChainWithHdrpDepthMotion`
- `Contract.EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved`

The target non-DLSS verdict for this stage is:

```text
Status=NoOfficialDlssPassObserved
Contract.Status=EasuSuperResolutionChainWithHdrpDepthMotionObservedButContractIncomplete
```

That verdict means one log contains:

1. a RenderGraph `Uber Post -> EASU -> Final Pass` chain;
2. an EASU `input < output` Super Resolution shape;
3. HDRP postprocess source/depth/motion snapshots matching the EASU input size;
4. no official `"Deep Learning Super Sampling"` pass;
5. no native evaluate/user-rendering pollution.

It is still not an official DLSS RenderGraph contract because EASU declarations
do not include depth/motion reads. It is a precondition for the next bounded
no-write cost proof.

## Validation Performed

Dry-run config accepted the new stage and produced the intended switch matrix:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -Stage hdrp-dlss-contract-bind-render-scale -OutputPath artifacts\dryrun\VrisingDLSS-hdrp-dlss-contract-bind-render-scale.cfg -DryRun
```

Dry-run diagnostic accepted the new stage without launching V Rising:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage hdrp-dlss-contract-bind-render-scale -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080 -DryRun
```

Analyzer regression on the old menu schedule audit still reports the expected
same-sized incomplete contract:

```text
Status=NoOfficialDlssPassObserved
Contract.Status=EasuChainObservedButContractIncomplete
CompleteUberEasuFinalChains=73
CompleteSuperResolutionChains=0
HdrpPostProcessDepthMotionInputMatches=0
```

Analyzer regression on the old visible user-rendering log intentionally remains
`Fail` because it contains evaluate/user-rendering pollution and no RenderGraph
pass-data snapshots, even though it contains older HDRP/EASU correlation lines.

## Future Runtime Command

When deliberately running this stage, use a protected gameplay session, true
`1920x1080` Windowed, and V Rising FSR Off:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage hdrp-dlss-contract-bind-render-scale -ArtifactLabel hdrp-dlss-contract-bind-render-scale-1080p-gameplay-<date>-r1 -DurationSeconds 90 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Do not use `-UseSdkWrapperNative` or `-DlssRuntimePath`; this stage should not
load NGX or evaluate DLSS.

After the run, analyze:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\analyze-hdrp-dlss-schedule-audit.ps1 -LogPath artifacts\runtime-logs\LogOutput-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-<date>-r1.log -Json
```

## Cleanup Expectations

The diagnostic runner must restore:

- loader config to the safe loader stage;
- `ClientSettings.json` if resolution/window mode was changed;
- no V Rising process left running;
- no SDK-wrapper native DLL swap, because this stage does not request one.

If a protected gameplay fixture is used, save restore must still end with
`ChangeCount=0`.

## Decision

This is the next normal runtime classification step if runtime work resumes.
Do not rerun the current `dlss-user-rendering` visible EASU candidate unchanged.
Do not use schedule-gate, mod-owned RenderGraph pass injection, or
`DLSSPass.Render` patching as the next performance-fix route.
