# HDRP DLSS Contract-Bind Render-Scale Gameplay Result - 2026-06-08

Status: Pass

## Protocol

Question: can the no-native/no-evaluate `hdrp-dlss-contract-bind-render-scale`
stage bind HDRP depth/motion evidence to the engine-owned `Uber -> EASU ->
Final` chain in protected gameplay?

Hypothesis: the stage should produce same-run RenderGraph
pass/resource/depth/motion evidence without NGX, native DLSS evaluate, broad
`RenderGraph.GetTexture` discovery, or save drift.

Runtime condition:

- Game path: `C:\Software\VRising`
- Stage: `hdrp-dlss-contract-bind-render-scale`
- Artifact label: `hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r1`
- Windowing: true `1920x1080` Windowed, `ClientWindowMode=3`
- Save protection: `-ProtectSave -SaveName 11111`
- Computer Use action: selected the real V Rising Unity window, clicked
  Continue once, sent no movement keys, and waited for stable gameplay.

## Artifacts

Local artifacts are intentionally under ignored `artifacts/` paths:

- `artifacts/gameplay-automation/Session-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r1.json`
- `artifacts/gameplay-automation/Cleanup-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r1.json`
- `artifacts/gameplay-automation/LogOutput-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r1.log`
- `artifacts/gameplay-automation/Analysis-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r1.txt`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r1-protected-save.json`

## Cleanup Evidence

Cleanup result:

- `Status=Pass`
- `CrashEventCount=0`
- `UseSdkWrapperNative=False`
- `ProtectSave=True`
- `SaveRestoreAttempted=True`
- `SaveRestored=True`
- `SaveBeforeRestoreChangeCount=1`
- `SaveAfterRestoreChangeCount=0`
- `SaveCompareStatus=Restored`
- `RemainingVRisingProcessCount=0`
- `CleanupRequired=False`

## Analyzer Evidence

`scripts\analyze-hdrp-dlss-schedule-audit.ps1 -LogPath artifacts\gameplay-automation\LogOutput-hdrp-dlss-contract-bind-render-scale-1080p-gameplay-20260608-r1.log -Json`
reported:

- `Status=NoOfficialDlssPassObserved`
- `Contract.Status=EasuSuperResolutionChainWithHdrpDepthMotionObservedButContractIncomplete`
- `OfficialContractObserved=false`
- `EngineOwnedChainObserved=true`
- `EngineOwnedSuperResolutionChainObserved=true`
- `EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved=true`
- `EasuDeclaresDepthMotion=false`
- `CompleteUberEasuFinalChains=73`
- `CompleteSuperResolutionChains=73`
- `SuperResolutionChainsWithHdrpDepthMotion=73`
- `HdrpPostProcessDepthMotionInputMatches=8`
- `RenderGraphGetTextureCalls=0`
- `UserRenderingCandidateStarted=0`
- `DlssEvaluateSucceeded=0`
- `AccessViolationIndicators=0`
- `DeepLearningSuperSamplingPass=0`
- `EasuSingleReadSingleWriteDeclarations=101`
- `EasuMultiReadDeclarations=0`

## Interpretation

Evidence: the protected gameplay run reached stable gameplay and bound an
engine-owned Super Resolution-sized `Uber -> EASU -> Final` chain to separate
HDRP source/depth/motion evidence. It did so without NGX/native evaluate,
without broad `RenderGraph.GetTexture`, without the normal-user
`dlss-user-rendering` candidate, without access violations, and with the
protected save restored to `ChangeCount=0`.

Inference: this is still not an official DLSS RenderGraph pass contract because
V Rising did not expose an active official `Deep Learning Super Sampling` pass,
and EASU itself still declares only source/destination reads and writes. The
proof is useful because it closes the "find the equivalent boundary" question
well enough to stop rerunning contract-bind unchanged and move to cost-layer
isolation.

## Decision

Do not rerun `hdrp-dlss-contract-bind-render-scale` unchanged as the next MVP
runtime proof.

Next work is a bounded no-write cost proof using the evidence-lock matrix:

- B: EASU carrier-only cost.
- C: native D3D11 resource-desc validate-only.
- D: empty existing command-buffer plugin-event callback.

Keep the same `1920x1080` Windowed protected `11111` fixture, Computer Use
Continue click, no movement keys, save restore requirement, and broader system
snapshot capture. Do not attempt visible DLSS write-back until B-G pass or a new
written exception explains the evidence.
