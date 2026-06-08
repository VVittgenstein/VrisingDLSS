# Official DLSS Contract vs EASU Chain Analysis - 2026-06-08

## Purpose

Turn the previous source/decompilation conclusion into a repeatable local
check: given a safe HDRP schedule-audit log, can we prove that the existing
engine-owned `Uber Post -> EASU -> Final Pass` chain is an official-equivalent
DLSS resource contract?

No V Rising runtime was launched for this pass.

## Inputs

- `scripts/analyze-hdrp-dlss-schedule-audit.ps1`
- `artifacts/runtime-logs/LogOutput-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.log`
- `docs/development/official-equivalent-rendergraph-boundary-feasibility-2026-06-08.md`
- `docs/development/native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-result-2026-06-07.md`
- `docs/development/hdrp-easu-input-output-correlation-render-scale-gameplay-result-2026-06-07.md`

## Analyzer Change

`scripts/analyze-hdrp-dlss-schedule-audit.ps1` now parses and reports:

- `UberPassDataSnapshots`
- `UberEasuSourceChains`
- `CompleteUberEasuFinalChains`
- `CompleteSuperResolutionChains`
- `EasuSingleReadSingleWriteDeclarations`
- `EasuMultiReadDeclarations`
- `EasuNonZeroDepthAttachmentDeclarations`
- `Boundary.FirstCompleteUberEasuFinalChain`
- `Contract.Status`
- `Contract.MissingForOfficialEquivalentBoundary`

The script still launches no game process. It reads an existing log and emits
`LaunchesGame=false`.

## Result On The Current Menu Audit

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\analyze-hdrp-dlss-schedule-audit.ps1 -LogPath artifacts\runtime-logs\LogOutput-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.log -Json
```

Key output:

| Evidence | Value |
| --- | ---: |
| Analyzer status | `NoOfficialDlssPassObserved` |
| Contract status | `EasuChainObservedButContractIncomplete` |
| Official DLSS pass/data/declaration | `0` |
| Uber pass-data snapshots | `75` |
| EASU pass-data snapshots | `75` |
| Uber destination -> EASU source chains | `73` |
| EASU destination -> Final source chains | `73` |
| Complete Uber -> EASU -> Final chains | `73` |
| Complete Super Resolution chains | `0` |
| EASU single-read/single-write declarations | `44` |
| EASU multi-read declarations | `0` |
| EASU non-zero depth attachments | `0` |
| Motion-vector pass mentions | `233` |
| Broad `RenderGraph.GetTexture` calls | `0` |
| DLSS evaluate/user-rendering pollution | `0` |
| crash/access-violation indicators | `0` |

First complete chain:

```text
compile=1; uberDestination/easuSource=73; easu=1920x1080->1920x1080; easuDestination/finalSource=74; finalDestination=13
```

## Interpretation

Evidence now mechanically proves the menu audit has a stable engine-owned
postprocess/upscale/final color-output chain:

```text
Uber Post destination
  -> Edge Adaptive Spatial Upsampling source
  -> Edge Adaptive Spatial Upsampling destination
  -> Final Pass source
```

It does not prove an official-equivalent DLSS contract:

- no `"Deep Learning Super Sampling"` pass shell appears in the log;
- no `"DLSS destination"` write handle appears in the log;
- this menu audit is same-sized (`1920x1080 -> 1920x1080`), not the gameplay
  Super Resolution shape;
- the EASU pass declaration is source/destination only, with one read and one
  write;
- EASU does not declare DLSS-style depth or motion-vector reads.

Separate protected gameplay evidence still matters:

- `hdrp-easu-input-output-correlation-render-scale-gameplay-result-2026-06-07`
  proves HDRP color/depth/motion at `960x540` can be correlated with the EASU
  `960x540 -> 1920x1080` route.
- `native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-result-2026-06-07`
  proves the focused EASU `ctx.cmd` callback can carry source/output/depth/motion
  as same-device D3D11 resources, with `ngx=not-loaded` and `evaluate=not-run`.

Therefore the current EASU boundary is a usable carrier for a four-resource
descriptor, but it is not itself the official DLSS RenderGraph resource
contract.

## Decision

Do not treat the EASU pass declaration alone as official-equivalent. The next
normal proof should be one of:

1. a no-native/no-evaluate log stage that binds the separate HDRP depth/motion
   correlation evidence to the observed `Uber -> EASU -> Final` chain in one
   run; or
2. a bounded no-write proof that uses the existing four-resource descriptor at
   the engine-owned EASU `ctx.cmd` callback, while explicitly measuring whether
   the extra work remains cheap before any visible DLSS write-back is allowed.

Still rejected for the normal route:

- forcing camera gates or `m_DLSSPass` as a performance fix;
- injecting a new mod-owned RenderGraph pass;
- patching `DLSSPass.Render`;
- returning to broad steady-state `RenderGraph.GetTexture` discovery;
- rerunning the same visible EASU `ctx.cmd` DLSS candidate unchanged.
