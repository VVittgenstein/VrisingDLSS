# Native RenderFunc Args Runtime Result - 2026-06-06

Status: menu runtime proof passed.

## Question

Can the default-off `native-renderfunc-args` preflight safely reuse the focused
EASU native render-function entry detour in V Rising, sample raw callback
argument pointer values, and immediately call the original trampoline without
crashing, hot resource discovery, command-buffer access, or DLSS evaluate?

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-args -DurationSeconds 75 -ArtifactLabel native-renderfunc-args-1080p-menu-20260606-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

No gameplay input was sent. The test remained menu-only.

## Runtime Shape

- Game path: `C:\Software\VRising`
- Stage: `native-renderfunc-args`
- Window: true `1920x1080` Windowed
- Graphics API: D3D11
- Duration: `75` seconds
- Crash event count: `0`
- Exited before window: `False`
- Closed by script: `True`
- Restored loader config: `True`
- Restored release-safe native DLL: `True`
- Restored client settings: `True`

Player log evidence:

- command line included `-windowed -screen-width 1920 -screen-height 1080 -screen-fullscreen 0 -force-d3d11`
- `SetResolution 1920, 1080, fullScreenMode Windowed`

## Artifacts

- `artifacts/runtime-logs/LogOutput-native-renderfunc-args-1080p-menu-20260606-r1.log`
- `artifacts/runtime-logs/Analysis-native-renderfunc-args-1080p-menu-20260606-r1.txt`
- `artifacts/runtime-logs/Player-native-renderfunc-args-1080p-menu-20260606-r1.log`
- `artifacts/runtime-logs/ClientSettings-native-renderfunc-args-1080p-menu-20260606-r1.before.json`

No WER artifact was produced because `CrashEventCount=0`.

## Analyzer Result

`Native RenderFunc Args=Pass`

Evidence line:

```text
Native render-func argument sample advanced: sampleCount=1; nonzeroThis=1; nonzeroPassData=1; nonzeroContext=1; nonzeroMethodInfo=1; lastThis=0x16F11E03480; lastPassData=0x16F12B31AE0; lastContext=0x16F11961DC0; lastMethodInfo=0x16E397EAFE0; pass="Edge Adaptive Spatial Upsampling"
```

`Native RenderFunc Entry=Pass` also remained true in the same run.

## Log Summary

- Candidate observed lines: `82`
- Entry status lines: `93`
- Argument status lines: `93`
- Detour installed lines: `1`
- Entry count advanced lines: `1`
- Argument sample advanced lines: `1`
- Probe failed lines: `0`
- `RenderGraph GetTexture call #` lines: `0`
- Crash-like lines: `0`
- Exception-like lines: `0`
- Actual DLSS evaluate/probe/native-call patterns: `0`

Final focused status:

```text
Native render-func entry status #3900: compile=3900; installed=True; entryCount=778; observations=780; candidatePointer=0x7FF85E8AE1C0; pass="Edge Adaptive Spatial Upsampling"; methodName=unknown; declaringType=unknown; reflectedType=unknown; metadataToken=unknown
Native render-func argument status #3900: compile=3900; installed=True; entryCount=778; sampleCount=778; nonzeroThis=778; nonzeroPassData=778; nonzeroContext=778; nonzeroMethodInfo=778; lastThis=0x16F11E03480; lastPassData=0x16F12B31AE0; lastContext=0x16F11961DC0; lastMethodInfo=0x16E397EAFE0; candidatePointer=0x7FF85E8AE1C0; pass="Edge Adaptive Spatial Upsampling"
```

Install/sample sequence:

- compile `1`: EASU `method_ptr=0x7FF85E8AE1C0`, observations `1`;
- compile `2`: same pointer, observations `2`;
- compile `3`: same pointer, observations `3`, detour installed;
- compile `4`: `entryCount=1`, `sampleCount=1`, all four raw callback argument
  pointer categories nonzero, sample advanced.

The broad literal text `DLSS evaluate` appears in the safety warning
`no pointer dereference, command buffer access, resource resolution, or DLSS
evaluate`; specific evaluate/probe/native-call patterns were all absent.

## Interpretation

This proves menu runtime safety for raw argument pointer sampling on the focused
EASU native render-function entry in this V Rising build. It extends the prior
entry ABI proof by showing the callback receives stable nonzero raw pointer
arguments for `thisPtr`, `passDataPtr`, `renderGraphContextPtr`, and
`methodInfoPtr`.

It does not prove gameplay safety, pass-data layout, resource identity, command
buffer safety, DLSS evaluate safety, or image correctness.

The preflight still does not dereference pointers, resolve resources, call
`GetTexture`, touch command buffers, load DLSS, or evaluate DLSS.

## Cleanup

Post-run checks confirmed:

- no V Rising or UnityCrashHandler process remained;
- `Diagnostics.EnableNativeRenderFuncArgumentProbe=false`;
- `Diagnostics.EnableNativeRenderFuncEntryProbe=false`;
- `Diagnostics.EnableRenderGraphGetTextureProbe=true`;
- `DLSS.EnableDLSS=false`;
- `scripts\get-runtime-validation-status.ps1 -IncludeArchivedLogs` reported
  `ConfiguredStage=loader` and recognized `Native RenderFunc Args=Pass` from
  archived logs.

## Next Step

The protected `11111` gameplay proof has since passed; see
`docs/development/native-renderfunc-args-gameplay-result-2026-06-06.md`.

The next step is a separate default-off resource-identity preflight designed from
the raw argument evidence. It must not dereference pointers in the native
callback, touch command buffers, or evaluate DLSS.
