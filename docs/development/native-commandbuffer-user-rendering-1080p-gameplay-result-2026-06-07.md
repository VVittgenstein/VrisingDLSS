# Native Command-buffer DLSS User Rendering Gameplay Result - 2026-06-07

## Question

Can `DLSS.EnableDLSS=true` use the source-guided native EASU `ctx.cmd`
command-buffer route as the normal user-rendering path, without returning to
the hot global `RenderGraph.GetTexture` route?

## Result

Pass on protected gameplay run
`native-commandbuffer-user-rendering-1080p-20260607-r3`.

The run used true `1920x1080` Windowed, V Rising `FsrQualityMode=Off`,
the local SDK-wrapper native DLL, and the protected `11111` save fixture.
Computer Use clicked Continue once and sent no keyboard, movement, combat, or
gameplay keys. An independent window screenshot confirmed gameplay after the
click.

## Implementation Fix

The preceding `r2` run was misread as a no-evaluate result because the native
status string was immediately overwritten by the next frame's pending payload.
The native consumed counter still reached `3029` with `eventId=260615` and no
set/issue/consume failures, which meant the native callback was consuming
payloads successfully.

The fix keeps a separate native
`VrisingDlss_GetRenderEventFrameDescriptorPayloadLastConsumedStatus()` export
and changes managed user-rendering success detection to treat
`consumed > 0 && lastEventId == 260615` as the callback/evaluate success
signal. Waiting logs for "HDRP/EASU descriptor not ready" are now throttled to
avoid large startup logs in normal-user runs.

## Evidence

Analyzer results:

- `Native RenderFunc CommandBuffer DLSS User Rendering=Pass`
- `DLSS User Rendering Candidate=Pass`
- `Stage 4 Native Bridge=Pass`

Key runtime evidence:

- `eventId=260615`
- `setSuccesses=124`
- `issueSuccesses=124`
- `consumed=124`
- `sequenceCreates=1`
- `sequenceEvaluates=124`
- `evaluateSuccesses=124`
- `evaluateResult=1`
- `input=960x540`
- `output=1920x1080`
- `validation=D3D11-succeeded`
- `sameDevice=yes`
- `scratchOutput=no`
- `visibleOutput=yes`
- `persistent=yes`
- `shutdown=pending`, expected for sustained user rendering with
  `targetSuccesses=120000`
- steady native timing:
  `nativeTimingMs=(describe=0.000,query=0.000,prepare=0.003,evaluate=0.092,total=0.096)`

Negative checks:

- `RenderGraph GetTexture call #`: `0`
- `DLSS visible write-back failed`: `0`
- `render event frame descriptor payload consume failed`: `0`
- `AccessViolationException`: `0`
- `nvwgf2umx`: `0`
- Windows crash events: `0`

Cleanup:

- Game process closed.
- ClientSettings restored.
- Loader config restored.
- BepInEx config restored.
- Release-safe native DLL restored and then refreshed to the new MSVC
  release-safe build.
- Protected save restore had `BeforeChangeCount=2` and final `ChangeCount=0`.

## Artifacts

- `artifacts/gameplay-automation/LogOutput-native-commandbuffer-user-rendering-1080p-20260607-r3.log`
- `artifacts/gameplay-automation/Analysis-native-commandbuffer-user-rendering-1080p-20260607-r3.txt`
- `artifacts/gameplay-automation/Player-native-commandbuffer-user-rendering-1080p-20260607-r3.log`
- `artifacts/gameplay-automation/ManualState-native-commandbuffer-user-rendering-1080p-20260607-r3.png`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-commandbuffer-user-rendering-1080p-20260607-r3.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-commandbuffer-user-rendering-1080p-20260607-r3.json`

## Next

This proves the normal-user candidate can perform sustained SDK-wrapper DLSS
evaluate into the visible EASU output at the source-guided `ctx.cmd` boundary.
The next gates are paired visual review, controlled performance comparison,
resize/reset behavior, fallback behavior, and release-boundary/runtime
distribution work.
