# V Rising Local Decompilation Investigation Guard - 2026-06-08

Status: implemented as a no-runtime guard. It does not launch V Rising and does
not modify game files.

## Purpose

`scripts\test-vrising-local-decompilation-investigation.ps1` turns the local
HDRP/DLSS decompilation and unpack investigation into a repeatable contract.
It exists to prevent the project from drifting back to broad runtime probing or
from treating the inert built-in `DLSSPass` body as a usable implementation.

Without `-GamePath`, the guard checks that the durable investigation docs still
state the clean-room boundary, separate evidence from inference, answer the
target HDRP/DLSS questions, and preserve the safe next-step chain.

With `-GamePath C:\Software\VRising -RequireLocalEvidence`, it also runs the
local read-only evidence scripts:

- `scripts\inspect-vrising-hdrp-dlss-static-route.ps1`
- `scripts\inspect-vrising-hdrp-dlss-native-stubs.ps1`
- `scripts\test-vrising-hdrp-dlss-official-contract.ps1`

## Guarded Conclusions

The local evidence must continue to support these conclusions before the next
runtime test is considered:

- the HDRP postprocess shell contains `RenderPostProcess`, `DoDLSSPasses`,
  `DoDLSSPass`, `EdgeAdaptiveSpatialUpsampling`, and `FinalPass`;
- the built-in NVIDIA `DLSSPass` execution body is inert or stub-like, while
  `DoDLSSPass` and resource helpers remain useful as a contract;
- the active serialized HDRP asset uses RenderGraph plus EASU/FSR, with
  official HDRP DLSS disabled;
- V Rising has ProjectM FSR/dynamic-resolution control symbols, with no focused
  ProjectM DLSS/NGX/Streamline layer found by this audit;
- the official DLSS pass contract and active EASU contract remain distinct:
  DLSS needs color/output/depth/motion/bias and frame parameters, while EASU
  declares source/destination scaling.

## Clean-Room Boundary

Allowed evidence: method names, RVAs, entry-byte classifications, field offsets,
xref summaries, serialized asset values, local artifact paths, and distilled
resource-contract summaries.

Not release material: decompiled V Rising method bodies, modified game files,
game assets, or proprietary Unity/NVIDIA/game binaries outside a separately
reviewed redistribution path.

## Current Result

Local verification on `C:\Software\VRising` is expected to report:

```text
Status=Pass
LaunchesGame=False
ModifiesGameFiles=False
LocalEvidenceStatus=Pass
```

The readiness report now includes this guard as an `Evidence` item. CI runs the
doc/contract half without `-GamePath`; local readiness with `-GamePath` runs the
full read-only game-file evidence chain.
