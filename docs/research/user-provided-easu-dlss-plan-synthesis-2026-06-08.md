# User-Provided EASU/DLSS Plan Synthesis - 2026-06-08

Status: distilled from two user-provided local reference files. No game launch.

Local reference files:

- `ref\user-provided\v_rising_dlss_fsr1_easu_research_plan_with_citations_5.4.md`
- `ref\user-provided\v_rising_dlss_fsr1_easu_research_plan_with_citations_5.5.md`

The raw reference files stay under ignored `ref/` material. This document records
only the project-facing synthesis.

## Evidence-Aligned Conclusions

The user-provided plans agree with current repository evidence:

- FSR1/EASU can remain a display-chain carrier and resource-handoff observation
  point, but it is not by itself a complete DLSS temporal contract.
- The performance failure shape, especially low FPS with low GPU utilization
  and a no-evaluate hot path also regressing, is more consistent with
  submission, synchronization, hot-hook, or resource-lifetime problems than
  with DLSS compute cost.
- The official-equivalent contract must bind color, output, depth, motion,
  jitter, motion-vector scale, pre-exposure, reset/history, viewport/extent,
  camera, and frame token semantics. Matching texture dimensions is only weak
  evidence.
- Broad steady-state `RenderGraphResourceRegistry.GetTexture` discovery,
  `DynamicResolutionHandler.Update(...)` cached-driver evaluate, forced/inert
  `DLSSPass` activation, new mod-owned RenderGraph pass productionization, and
  direct visible evaluate without no-write/scratch layers should stay stopped
  unless new evidence explicitly challenges those locks.

## Difference Between 5.4 and 5.5

`5.4` pushes harder toward finding an earlier temporal-friendly boundary,
especially runtime `CustomPass BeforePostProcess`, before treating EASU as the
main evaluate carrier. It also rates `CustomPass` as potentially more practical
than `CustomPostProcess` for a BepInEx/Thunderstore mod because a pass/volume may
be code-created, while Custom Post Process ordering usually depends on HDRP
Global Settings.

`5.5` is more compatible with the current repository route: keep the already
planned `hdrp-dlss-contract-bind-render-scale` proof first, then run a strict
layered cost matrix on the narrow engine-owned EASU/command-buffer path before
allowing visible write-back. It still keeps `CustomPostProcess` and `CustomPass`
as research candidates, but not ahead of the current contract-bind proof.

## Route Impact

This does not change the immediate next runtime proof:

1. Run protected `hdrp-dlss-contract-bind-render-scale` at true `1920x1080`
   Windowed when Computer Use can list apps.
2. Use Computer Use to click Continue/`11111` once.
3. Send no movement keys.
4. Stop through `scripts\stop-vrising-automation-session.ps1`.
5. Require final save restore `ChangeCount=0`.
6. Analyze with `scripts\analyze-hdrp-dlss-schedule-audit.ps1`.

The main addition is what should come after a successful contract-bind proof:

```text
A. Baseline: FSR Off, 1080p Windowed, protected 11111 fixture.
B. EASU carrier-only cost: no native, no evaluate, no broad GetTexture.
C. Native descriptor validate-only: same device and D3D11 desc audit, no NGX.
D. Empty plugin-event callback: issue event on the existing command buffer.
E. NGX init/create steady-state: create once, no per-frame recreate, no evaluate.
F. Scratch evaluate not consumed: output to scratch, no FinalPass consumption.
G. Scratch evaluate plus controlled copy: dummy copy first, EASU destination later.
H. Visible write: only after B-G pass.
I. 4K GPU-bound product-value test: only for the single surviving candidate.
```

Recommended pass thresholds from the plan:

- B/C/D: average FPS at least `98%` of baseline, P95 no more than `+0.5 ms`,
  P99 no more than `+1.0 ms`, and no low-GPU-utilization collapse.
- F: stable NGX success with no crash and no GPU utilization/power collapse.
- H: no recurrence of the current `~200 -> ~120-150 FPS` low-GPU-utilization
  shape before moving to 4K value testing.

## Implementation Guidance

Use a strict split:

- discovery: short-lived and not in steady-state;
- contract: compact per-frame ledger keyed by frame/camera/pass/resource/extent;
- evaluate: native event or equivalent existing `ctx.cmd` boundary;
- writeback: scratch first, visible only after no-write layers pass;
- diagnostics: limited logging and external metrics, never hot unbounded probes.

Candidate architecture names from the plans map well to existing work:

- `FrameContractLedger`: evolve current HDRP/EASU correlation evidence.
- `BoundaryAdapter(EASU / CustomPostProcess / CustomPass)`: keep EASU first,
  but preserve CustomPass/CustomPostProcess as explicit alternative boundaries.
- `ExperimentMatrixConfig`: encode B-H layers as mutually exclusive stages.
- `LogVerifier`: turn each stage's evidence into machine-readable pass/fail.

## Open Questions

- Can runtime `CustomPassVolume`/`CustomPass` be created safely in V Rising's
  IL2CPP HDRP build, and does the active HDRP asset have Custom Pass support
  enabled?
- Can `CustomPostProcess` be registered at runtime without modifying game
  assets or relying on a brittle HDRP Global Settings mutation?
- Does a strict EASU carrier-only run remain near baseline when using the
  existing focused render-func boundary and no native work?
- Is the first bad layer B/C/D/E/F/G/H? That answer should decide whether to
  repair hook overhead, native event scheduling, NGX evaluate boundary, copy,
  or visible handoff.
