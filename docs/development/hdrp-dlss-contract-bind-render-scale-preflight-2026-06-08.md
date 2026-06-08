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

When deliberately running this stage in gameplay, use a protected automation
session, true `1920x1080` Windowed, and V Rising FSR Off. The session harness now
accepts `-ProtectSave -SaveName 11111` so it resolves the local/private
CloudSaves fixture, backs it up before launch, and the stop script restores it
during cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath C:\Software\VRising -Stage hdrp-dlss-contract-bind-render-scale -ArtifactLabel hdrp-dlss-contract-bind-render-scale-1080p-gameplay-<date>-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080 -ProtectSave -SaveName 11111
```

Manual `-SaveDir <local-save-dir>` remains a fallback if the fixture resolver is
unavailable or the local machine has multiple same-named saves.

Do not use `-UseSdkWrapperNative` or `-DlssRuntimePath`; this stage should not
load NGX or evaluate DLSS.

After the game window is ready, use Computer Use to select the real `VRising`
window, click the known Continue / `11111` entry once, send no movement keys, and
wait for the stable local/private scene. Then stop the session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-<date>-r1.json"
```

The cleanup must report `SaveRestored=True`, `SaveAfterRestoreChangeCount=0`,
`RestoredLoaderConfig=True`, `RestoredClientSettings=True`,
`RestoredBepInExConfig=True`, and `RemainingVRisingProcessCount=0`.

After the run, analyze:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\analyze-hdrp-dlss-schedule-audit.ps1 -LogPath artifacts\gameplay-automation\LogOutput-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-<date>-r1.log -Json
```

## Cleanup Expectations

The diagnostic runner must restore:

- loader config to the safe loader stage;
- `ClientSettings.json` if resolution/window mode was changed;
- no V Rising process left running;
- no SDK-wrapper native DLL swap, because this stage does not request one.

If a protected gameplay fixture is used, save restore must still end with
`ChangeCount=0`.

## Deferred Runtime Attempt - 2026-06-08

The first resumed attempt to run the protected gameplay proof was deliberately
deferred before launching V Rising because Computer Use returned:

```text
Windows computer-use client is closed
```

No game process was started, no configuration was written to the game
directory, and the protected `11111` save was not touched. This is not runtime
evidence for or against the stage; it only records that the automation-control
precondition was unavailable.

Static/regression checks performed during the deferral:

- `git status --short` was clean.
- `Get-Process VRising,VRisingServer` found no running game process.
- The protected save path still existed.
- `scripts/analyze-hdrp-dlss-schedule-audit.ps1` on the archived menu audit
  still reported `Status=NoOfficialDlssPassObserved` and
  `Contract.Status=EasuChainObservedButContractIncomplete`.
- `scripts/write-diagnostic-config.ps1 -Stage hdrp-dlss-contract-bind-render-scale -DryRun`
  still emitted the intended no-native/no-evaluate switch matrix with
  `LaunchesGame=False`.
- `scripts/get-release-readiness-status.ps1 -GamePath C:\Software\VRising`
  still reported `DiagnosticPackageReady_MvpBlocked` and recommended this
  contract-bind stage as the next normal runtime proof.

## Static Stage Guard - 2026-06-08

`scripts\test-hdrp-dlss-contract-bind-stage.ps1` now makes the preflight
repeatable without launching V Rising or writing game files. It asserts the
`hdrp-dlss-contract-bind-render-scale` dry-run config still enables the intended
RenderGraph/pass-data/HDRP-postprocess/render-scale evidence switches while
keeping native bridge smoke, D3D11 validation, NGX/DLSS runtime probes, DLSS
feature/evaluate/write-back probes, broad `RenderGraph.GetTexture`, schedule
gate mutation, custom postprocess probes, and hook/call probes disabled.

Local checks passed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-hdrp-dlss-contract-bind-stage.ps1 -GamePath C:\Software\VRising -RequirePass -Json
```

Result summary:

- `Status=Pass`
- `LaunchesGame=false`
- `ModifiesGameFiles=false`
- `RequiredTrueCount=10`
- `RequiredFalseCount=50`
- `CheckCount=62`
- `DiagnosticDryRun.LaunchesGame=false`
- `DiagnosticDryRun.UseSdkWrapperNative=false`
- `DiagnosticDryRun.RestoresReleaseSafeNative=false`
- `DiagnosticDryRun.ClientWindowMode=3`

Negative smoke also passed: using `-RequirePass` with a deliberately missing
`GamePath` produced `Contract-bind stage guard status=Blocked` and threw instead
of silently passing.

The same guard also passed with the current local `11111` save supplied through
`-SaveName`, confirming the automation session dry-run resolves exactly one
fixture and preserves `ProtectSave=true`, `RestoresProtectedSave=true`,
`LaunchesGame=false`, and `UseSdkWrapperNative=false`.

`scripts\find-vrising-save-fixture.ps1 -SaveName 11111 -RequireOne -Json` now
resolves that local/private fixture without launching V Rising or modifying save
files. On the current machine it reports `Status=Pass`, `MatchCount=1`,
`AutoSaveCount=8`, `HasServerGameSettings=true`, and `Usable=true`. The session
harness and contract-bind guard can now call the same resolver through
`-SaveName 11111`, so the long CloudSaves path no longer has to be copied into
normal protected-run commands.

`scripts\get-release-readiness-status.ps1` now includes this guard as an
`Evidence` readiness item. With `-GamePath`, it includes the diagnostic dry-run
plan check and, when the `11111` fixture resolver passes, the protected-save
automation session dry-run; without `-GamePath`, it still checks the stage config
matrix.
The GitHub Actions package workflow also runs the same config-only guard on
`windows-2022` before packaging with `-RequirePass`, so `Fail` or `Blocked`
guard results fail the workflow. Release readiness now requires that enforcing
CI guard step to remain present.

The guard JSON also emits a `RuntimeProofPlan` when `-GamePath` and
`-SaveName`/`-SaveDir` are supplied. This is a no-launch machine-readable plan
for the next protected gameplay proof. It records the question/hypothesis, the
recommended `start-vrising-automation-session.ps1` command with
`-ProtectSave -SaveName 11111`, the required Computer Use action, stop/analyze
command templates, pass signals, and fail signals. Local validation on
2026-06-08 confirmed `RuntimeProofPlan.RequiresComputerUse=true`,
`MovementKeysAllowed=false`, and `StartCommand` uses `-SaveName 11111` while the
guard itself still reports `LaunchesGame=false`.

When Computer Use is available again, resume with the protected session command
above, using a fresh artifact label such as
`hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r2` if the earlier
label already exists.

## Decision

This is the next normal runtime classification step if runtime work resumes.
Do not rerun the current `dlss-user-rendering` visible EASU candidate unchanged.
Do not use schedule-gate, mod-owned RenderGraph pass injection, or
`DLSSPass.Render` patching as the next performance-fix route.
