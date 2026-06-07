# Native RenderFunc CommandBuffer Event + Render Scale Gameplay Result - 2026-06-07

## Question

Can the proven EASU native render-func boundary safely issue one native no-op
plugin event through the live `RenderGraphContext.cmd` during protected `11111`
gameplay at true `1920x1080` Windowed, with V Rising FSR Off and mod-owned
render scale active?

## Hypothesis

If this native render-func callback is inside the real RenderGraph pass execute
window, `ctx.cmd.IssuePluginEvent(callback, 260607)` should enqueue and reach the
native render-event callback once. The probe must not pass texture resources
through the event, validate D3D11 resources, load NGX, evaluate DLSS, or write
visible output.

## Stage

`native-renderfunc-commandbuffer-event-render-scale`

Important config:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferEventProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableNativeRenderFuncResourceResolveProbe=false`
- `EnableNativeRenderFuncResourceNativePointerProbe=false`
- `EnableNativeRenderFuncResourceD3D11Probe=false`
- `EnableDLSS=false`

## Artifacts

Menu smoke:

- BepInEx log:
  `artifacts/runtime-logs/LogOutput-native-renderfunc-commandbuffer-event-render-scale-1080p-menu-20260607-r1.log`
- Analysis:
  `artifacts/runtime-logs/Analysis-native-renderfunc-commandbuffer-event-render-scale-1080p-menu-20260607-r1.txt`

Protected gameplay proof:

- Session:
  `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.json`
- BepInEx log:
  `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.log`
- Analysis:
  `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.txt`
- Runtime analysis copy:
  `artifacts/runtime-logs/Analysis-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.txt`
- Gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.png`
- Cleanup:
  `artifacts/gameplay-automation/Cleanup-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.json`
- Save restore:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1.json`

## Menu Smoke Result

Pass.

The menu smoke run reached the command-buffer event guard before gameplay input.
Analyzer reported `Native RenderFunc CommandBuffer Event=Pass`,
`Native RenderFunc Context=Pass`, `Native RenderFunc Resource Tuple=Pass`, and
`Stage 2C Render-Scale Control Probe=Pass`.

Key evidence:

```text
Native render-func command-buffer event advanced: issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeCount=0; currentCount=1; lastEventId=260607; callback=0x7FF89AFE1000; lastCmd=0x187CBE1E3A0; eventId=260607; status="render event count=1; last event id=260607; D3D11 device is not queried yet"; pass="Edge Adaptive Spatial Upsampling"
```

Menu counts:

- `Native render-func command-buffer event advanced:` `1`
- `Native render-func command-buffer event status #` `91`
- `issueFailures=[1-9]` `0`
- `callbackReached=False` `3`, only before the event was installed/reached
- broad `RenderGraph GetTexture call #` `0`
- native-pointer/D3D11/NGX/DLSS/evaluate/user-rendering patterns `0`
- native entry/detour failure patterns `0`
- access-violation patterns `0`

Cleanup passed with `CrashEventCount=0`, restored loader config,
ClientSettings, and release-safe native DLL, and left no V Rising process.

## Gameplay Result

Pass.

Computer Use selected the real `VRising` Unity window, clicked the known Chinese
Continue entry once at `(205,354)`, and sent no keyboard or movement input.
Gameplay loaded successfully and a passive screenshot captured a nonblank true
`1920x1080` game window.

Analyzer status:

- `Stage 2C Render-Scale Control Probe=Pass`
- `Native RenderFunc Entry=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc CommandBuffer Event=Pass`
- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native bridge API version: 13`

Key evidence:

```text
Native render-func resource tuple advanced: compile=4; sampleCount=1; managedPassData=0x24296F5F2A0; nativeLastPassData=0x24296F5F2A0; passDataMatches=True; tupleReady=True; pass="Edge Adaptive Spatial Upsampling"; tuple=input=960x540; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"
Native render-func context advanced: sampleCount=1; nonzeroContext=1; wrapSuccess=1; cmdNonNull=1; cmdPointerNonZero=1; wrapFailures=0; lastContext=0x24297025B80; lastWrappedContext=0x24297025B80; lastCmd=0x243BCB10E40; cmd="UnityEngine.Rendering.CommandBuffer name="; pass="Edge Adaptive Spatial Upsampling"
Native render-func command-buffer event advanced: issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeCount=0; currentCount=1; lastEventId=260607; callback=0x7FF89FD11000; lastCmd=0x243BCB10E40; eventId=260607; status="render event count=1; last event id=260607; D3D11 device is not queried yet"; pass="Edge Adaptive Spatial Upsampling"
Native render-func command-buffer event status #15600: compile=15600; installed=True; issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeCount=0; currentCount=1; lastEventId=260607; callbackReached=True; callback=0x7FF89FD11000; lastCmd=0x243BCB10E40; eventId=260607; status="render event count=1; last event id=260607; D3D11 device is not queried yet"; failure="none"; candidatePointer=0x7FFFA935E1C0; pass="Edge Adaptive Spatial Upsampling"
```

Counts:

- `Native render-func command-buffer event advanced:` `1`
- `Native render-func command-buffer event status #` `142`
- `issueFailures=[1-9]` `0`
- `callbackReached=False` `3`, only before the event was installed/reached
- broad `RenderGraph GetTexture call #` `0`
- `Native render-func resource native-pointer` `0`
- `Native render-func resource D3D11` `0`
- `ExecuteDLSS` `0`
- `NGX` `0`
- `DLSS user rendering` `0`
- native entry failures `0`
- detour dispose failures `0`
- access-violation patterns `0`

Cleanup passed:

- `CrashEventCount=0`
- `RestoredClientSettings=true`
- `RestoredLoaderConfig=true`
- `RestoredReleaseSafeNative=true`
- `RemainingVRisingProcessCount=0`
- before restore the save had two added autosaves
- after restore `CompareStatus=Restored` and `ChangeCount=0`

## Interpretation

This proves that the focused EASU native render-func callback can use the live
`RenderGraphContext.cmd` to enqueue a native render event that executes on the
native callback path. It is a stronger timing/order proof than merely reading
`ctx.cmd`, and it preserves the proven V Rising FSR Off EASU tuple:
`960x540 -> 1920x1080`.

This still does not prove DLSS evaluate, NGX feature lifecycle, texture payload
handoff, resize/reset behavior, visible image correctness, or performance. It
also does not mean the earlier broad `GetTexture` discovery route should be
revived; the value here is the narrow official-boundary-adjacent execution
window.

## Source/Decompilation Implication

This result supports making local source/decompilation analysis the next main
route. With IL2CPP/HDRP metadata and native xrefs, the remaining work should be
to map the exact official `DoDLSSPass -> DLSSPass.GetCameraResources ->
DLSSPass.Render(..., ctx.cmd)` lifecycle and find a BepInEx/Harmony-accessible
equivalent boundary. Runtime guards are still required, but they should now be
driven by decompiled/static evidence rather than repeated broad experiments.

## Next Step

The next guard should be a separately gated native callback payload/lifecycle
proof at this same EASU `ctx.cmd` boundary. It may validate that a minimal,
non-texture payload survives command-buffer ordering, but it should still avoid
DLSS evaluate and visible write-back in the same step.
