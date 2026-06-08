# Official-Equivalent RenderGraph Boundary Feasibility - 2026-06-08

## Purpose

Follow up the `m_DLSSPass` xref audit by answering the next practical question:

Can a managed BepInEx plugin safely create or influence a narrow
official-equivalent RenderGraph pass boundary, or should the next route stay on
engine-owned upscaler passes such as EASU/FinalPass?

No V Rising runtime was launched for this pass.

## Inputs

- Current worktree after `cce535e`.
- Existing source:
  - `src/VrisingDLSS.Plugin/RenderGraphDiagnosticPass.cs`
  - `src/VrisingDLSS.Plugin/FrameResourceProbe.cs`
  - `src/VrisingDLSS.Plugin/ModConfig.cs`
  - `scripts/analyze-hdrp-dlss-schedule-audit.ps1`
- Existing runtime evidence:
  - `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-crash-gameplay-2026-06-05-083418.log`
  - `artifacts/runtime-logs/WER-stage8a-rendergraph-diagnostic-pass-crash-gameplay-2026-06-05-083423.wer`
  - `artifacts/runtime-logs/LogOutput-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.log`
- Existing docs:
  - `docs/research/stage8a-rendergraph-search-2026-06-05.md`
  - `docs/research/hdrp-dlss-rendergraph-safe-boundary-followup-2026-06-06.md`
  - `docs/development/native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-result-2026-06-07.md`
  - `docs/development/vrising-hdrp-dlss-m-dlsspass-xref-audit-2026-06-08.md`

## Answer 1: AddRenderPass/SetRenderFunc Is Technically Possible, But Rejected As The Normal Route

`RenderGraphDiagnosticPass` already answers the generic feasibility question:
with local V Rising interop assemblies, managed plugin code can register an
IL2CPP pass-data type and call:

```text
RenderGraph.AddRenderPass<TPassData>(...)
RenderGraphBuilder.ReadTexture(...)
RenderGraphBuilder.ReadWriteTexture(...)
RenderGraphBuilder.SetRenderFunc<TPassData>(...)
```

Evidence from archived logs:

- `RenderGraph diagnostic pass configured #1`
- `pass=VrisingDLSS DLSS input diagnostic`
- `hasRenderFunc=True`
- `allowPassCulling=False`
- `RenderGraph diagnostic pass injected #1`
- `color=CameraColor`
- `depth=CameraDepthStencil`
- `motion=Motion Vectors`

The same path was then tested in local/private gameplay. V Rising configured and
injected the diagnostic pass twice, then crashed before any diagnostic render
function logged. Windows Error Reporting recorded:

- `EventType=APPCRASH`
- `NsAppName=VRising.exe`
- fault module `coreclr.dll`
- exception code `c0000005`

Evidence level: strong runtime evidence.

Decision: do not use new mod-owned RenderGraph pass injection as the next
normal proof. It can remain behind
`Diagnostics.EnableRenderGraphDiagnosticPass=false` for deliberate
crash-recovery research only.

## Answer 2: The Existing Engine-Owned EASU -> Final Chain Is Observable And Stable

The updated schedule-audit analyzer now extracts EASU/FinalPass boundary counts
from existing no-native logs. Running:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\analyze-hdrp-dlss-schedule-audit.ps1 -LogPath artifacts\runtime-logs\LogOutput-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.log -Json
```

reported:

| Evidence | Count |
| --- | ---: |
| Official `"Deep Learning Super Sampling"` pass | 0 |
| DLSS pass data/resource/render-func/compiled-info | 0 |
| EASU pass-data snapshots | 75 |
| EASU SR-sized pass-data snapshots | 0 |
| EASU resource declarations | 44 |
| EASU render-func metadata | 75 |
| EASU compiled-pass info | 36 |
| EASU destination -> FinalPass source chains | 73 |
| FinalPass data snapshots | 87 |
| Motion-vector pass mentions | 233 |
| Broad `RenderGraph.GetTexture` calls | 0 |
| DLSS evaluate/user-rendering pollution | 0 |
| crash/access-violation indicators | 0 |

First extracted chain:

```text
compile=1; easu=1920x1080->1920x1080; easuSource=73; easuDestination/finalSource=74; finalDestination=13
```

Evidence level: strong no-native log/analyzer evidence for menu. Protected
gameplay evidence for the EASU command-buffer descriptor path already exists in
the 2026-06-07 native render-func frame-descriptor D3D11 proof.

Interpretation:

- The official DLSS pass shell is absent under current safe settings.
- The engine-owned EASU pass and FinalPass form a stable, observable chain.
- In this menu audit EASU was not Super Resolution-sized, but earlier protected
  gameplay render-scale proofs showed the same EASU route reaching
  `960x540 -> 1920x1080`.
- EASU pass data declares source/destination only; DLSS still needs depth and
  motion, which must be supplied through the already-proven HDRP postprocess
  global texture correlation path rather than EASU pass data alone.

## Answer 3: The Next No-Native Boundary Proof Should Not Inject A New Pass

The safe path is not:

- force official `m_DLSSPass`/DLSSDetected again;
- inject a new mod-owned RenderGraph pass;
- patch `DLSSPass.Render`;
- patch broad compiler-generated render functions;
- return to steady-state global `GetTexture` discovery.

The next aligned route is:

1. Use the official `DoDLSSPass` source as the resource contract:
   source, destination, depth, motion vectors, optional bias color mask,
   command-buffer evaluation in a RenderGraph pass.
2. Use existing safe read-only schedule-audit logs to classify the actual
   `Uber Post -> EASU -> Final Pass` resource flow.
3. Use the already-proven engine-owned EASU command-buffer boundary only if the
   proof remains no-native/no-evaluate or bounded native validation.
4. Preserve the already-learned gap explicitly: EASU gives source/destination
   placement; HDRP global/postprocess correlation gives depth/motion; the
   combination is official-like enough to test, but it is not identical to a
   built-in DLSS pass.

## Analyzer Change

`scripts/analyze-hdrp-dlss-schedule-audit.ps1` now reports:

- `EasuPassDataSnapshots`
- `EasuSuperResolutionPassDataSnapshots`
- `EasuResourceDeclarations`
- `EasuRenderFuncMetadata`
- `EasuCompiledPassInfo`
- `UberEasuSourceChains`
- `EasuFinalSourceChains`
- `CompleteUberEasuFinalChains`
- `CompleteSuperResolutionChains`
- `FinalPassDataSnapshots`
- `MotionVectorPassMentions`
- `Boundary.FirstEasuFinalChain`
- `Boundary.FirstCompleteUberEasuFinalChain`
- `Contract.Status`
- `Contract.MissingForOfficialEquivalentBoundary`

It also fixes the previous `compiled-pass-info` spelling in the observation and
DLSS compiled-pass patterns.

The follow-up contract/gap result is recorded in
`docs/development/official-dlss-contract-vs-easu-chain-analysis-2026-06-08.md`.

## Repeatable Guard

The route decision is now mechanically checked by:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-rendergraph-boundary-route-status.ps1 -RequirePass -Json
```

The guard launches no game process and modifies no game files. It checks:

- `RenderGraphDiagnosticPass.cs` still contains the local
  `AddRenderPass`/`SetRenderFunc` proof path;
- the archived diagnostic-pass gameplay log configured and injected a
  color/depth/motion pass with `hasRenderFunc=True` and
  `allowPassCulling=False`;
- the paired WER file still proves `VRising.exe -> coreclr.dll -> c0000005`;
- `ModConfig`, Thunderstore package validation, and the contract-bind guard keep
  `EnableRenderGraphDiagnosticPass=false` and
  `EnableExistingRenderFuncProbe=false` on the normal route;
- the current safe schedule-audit analyzer still observes an engine-owned
  `Uber -> EASU -> FinalPass` chain while rejecting the menu log as an
  official-equivalent DLSS contract.

Local validation on 2026-06-08 reported `Status=Pass`, `CheckCount=18`,
`LaunchesGame=false`, `ModifiesGameFiles=false`,
`RouteDecision=RejectedAsNormalRoute`, analyzer status
`NoOfficialDlssPassObserved`, analyzer contract
`EasuChainObservedButContractIncomplete`, and `73` complete
`Uber -> EASU -> FinalPass` chains.

## Decision

Current mainline:

```text
official DLSS source contract
  + existing safe schedule-audit EASU/FinalPass chain evidence
  + already-proven EASU ctx.cmd frame descriptor
  -> next bounded no-native/no-evaluate or no-write proof
```

Do not spend the next normal iteration on a new mod-owned RenderGraph pass. The
old `AddRenderPass` proof is useful evidence, but the crash history makes it the
wrong direction for a playable MVP path.
