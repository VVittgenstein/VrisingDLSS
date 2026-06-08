# V Rising HDRP DLSS Official Contract Guard - 2026-06-08

## Purpose

Convert the local decompilation/unpack evidence into a repeatable no-launch
guard. This is not a runtime probe and does not modify or redistribute game
files. It checks whether the current local V Rising HDRP evidence still supports
the clean-room boundary decision:

- use `DoDLSSPass` as the official resource-order contract;
- do not treat the active `EASU` pass alone as a complete DLSS-equivalent
  evaluate payload.

## Implementation

`scripts\inspect-vrising-hdrp-dlss-static-route.ps1` now parses each requested
`dump.cs` type block independently and stops at the next type header. The earlier
fixed-window parser could merge adjacent nested pass-data classes, which made
`EASUData` appear to contain `FinalPassData` fields. That would be unsafe for a
contract guard because it could hide the fact that EASU itself is only a
source/destination scaling pass.

`scripts\test-vrising-hdrp-dlss-official-contract.ps1` wraps the static-route
inspector and asserts:

- the inspector itself reports `LaunchesGame=false` and
  `ModifiesGameFiles=false`;
- `RenderPostProcess`, `DoDLSSPasses`, `DoDLSSPass`,
  `GetPostprocessUpsampledOutputHandle`, `EdgeAdaptiveSpatialUpsampling`, and
  `FinalPass` anchors are present;
- `DoDLSSPass` takes source, depth, motion-vector, and bias handles;
- `DLSSData`, `DLSSPass.ViewResourceHandles`, and `DLSSPass.Parameters` expose
  the resource/parameter shape needed for official DLSS evaluation, including
  reset-history and pre-exposure inputs;
- `EASUData` exposes only scaling/source/destination fields and does not expose
  depth, motion-vector, bias, parameter, resource-handle, or pass fields;
- `FinalPassData` consumes the dynamic-resolution source/destination path;
- the active serialized HDRP asset is RenderGraph + hardware dynamic resolution
  + `EdgeAdaptiveScalingUpres`, with official DLSS disabled;
- xref evidence keeps `DoDLSSPass` as a RenderGraph contract while the normal
  DLSS activation chain is absent;
- `DLSSPass` execution remains inert while resource helper methods are distinct.

## Local Result

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-vrising-hdrp-dlss-official-contract.ps1 -GamePath C:\Software\VRising -Json
```

Summary:

```text
Status=Pass
LaunchesGame=false
ModifiesGameFiles=false
CheckCount=11
```

Release readiness now includes this as a `GamePath`-gated `Evidence` item. It is
not wired into GitHub Actions because CI does not have the user's local licensed
game installation.

## Boundary Implication

The current static evidence says the active V Rising path is:

```text
Uber/Postprocess color -> EASU source/destination scaling -> FinalPass
```

The official DLSS contract additionally needs current-frame depth, motion
vectors, bias mask, reset-history, pre-exposure, and DRS/camera state. Therefore
the already-working EASU `ctx.cmd` evaluate/write-back point remains useful but
incomplete. The next runtime proof should bind HDRP depth/motion correlation to
the engine-owned `Uber -> EASU -> FinalPass` chain before any no-write cost proof
or visible DLSS write-back.
