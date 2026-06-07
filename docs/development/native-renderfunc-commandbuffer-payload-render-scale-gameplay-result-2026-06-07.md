# Native RenderFunc CommandBuffer Payload + Render Scale Gameplay Result - 2026-06-07

## Question

Can the focused EASU native render-func boundary carry the proven
source/destination texture pair through a native pending payload and consume it
from a `ctx.cmd` plugin event during protected `11111` gameplay at true
`1920x1080` Windowed, with V Rising FSR Off and mod-owned render scale active?

## Hypothesis

The EASU render-func detour runs before the original render func calls
`GetTexture`, so the first callback may not yet have source/destination native
pointers. If the targeted native-pointer observer arms a payload after the EASU
source/output pointers are seen, a later EASU `RenderGraphContext.cmd` callback
should issue event `260608`, and the native render-event callback should consume
that payload as a same-device `960x540 -> 1920x1080` pair. The probe must not
load NGX, evaluate DLSS, write visible output, or use broad `GetTexture`
diagnostic logging.

## Stage

`native-renderfunc-commandbuffer-payload-render-scale`

Important config:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferPayloadProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableNativeRenderFuncCommandBufferEventProbe=false`
- `EnableNativeRenderFuncResourceD3D11Probe=false`
- `EnableDLSS=false`

Native bridge API version observed in game log: `14`.

## Artifacts

Menu smoke:

- BepInEx log:
  `artifacts/runtime-logs/LogOutput-native-renderfunc-commandbuffer-payload-render-scale-1080p-menu-20260607-r1.log`
- Analysis:
  `artifacts/runtime-logs/Analysis-native-renderfunc-commandbuffer-payload-render-scale-1080p-menu-20260607-r1.txt`

Protected gameplay proof:

- Session:
  `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.json`
- BepInEx log:
  `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.log`
- Analysis:
  `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.txt`
- Runtime analysis copy:
  `artifacts/runtime-logs/Analysis-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.txt`
- Gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.png`
- Cleanup:
  `artifacts/gameplay-automation/Cleanup-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.json`
- Save restore:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1.json`

## Menu Smoke Result

Pass.

Analyzer reported `Native RenderFunc CommandBuffer Payload=Pass`,
`Native RenderFunc Context=Pass`, `Native RenderFunc Resource Native Pointer=Pass`,
`Native RenderFunc Resource Tuple=Pass`, and
`Stage 2C Render-Scale Control Probe=Pass`.

Key evidence:

```text
Native render-func command-buffer payload set advanced: ... tuple=input=960x540; output=1920x1080; ... beforeConsumed=0; eventId=260608; sequence=1; status="render event texture payload pending: setAttempts=1; setSuccesses=1; setFailures=0; consumed=0; consumeFailures=0; eventId=260608; sequence=1; sourcePtr=0000021623B6B760; destinationPtr=0000021623B709E0"
Native render-func command-buffer payload advanced: setAttempts=1; setSuccesses=1; setFailures=0; issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeConsumed=0; consumed=1; lastEventId=260608; callback=0x7FF8BC941000; lastCmd=0x214A185BE40; eventId=260608; sequence=1; status="render event texture payload consumed: setAttempts=1; setSuccesses=1; setFailures=0; consumed=1; consumeFailures=0; eventId=260608; sequence=1; sourcePtr=0000021623B6B760; destinationPtr=0000021623B709E0; sameDevice=yes; source=960x540 fmt=26 mips=1 array=1; destination=1920x1080 fmt=26 mips=1 array=1; scale=(2.000x,2.000x)"; pass="Edge Adaptive Spatial Upsampling"
```

Menu counts:

- `Native render-func command-buffer payload advanced:` `1`
- `Native render-func command-buffer payload set advanced:` `1`
- `Native render-func command-buffer payload status #` `91`
- `render event texture payload consume failed` `0`
- payload set/event failures `0`
- broad `RenderGraph GetTexture call #` `0`
- native D3D11 pair probe `0`
- `ExecuteDLSS`, `nvngx`, and `DLSS user rendering` `0`
- access-violation patterns `0`

Cleanup passed with `CrashEventCount=0`, restored loader config,
ClientSettings, and release-safe native DLL, and left no V Rising process.

## Gameplay Result

Pass.

Computer Use selected the real `VRising` Unity window, not the BepInEx console,
clicked the known Chinese Continue entry once at `(205,354)`, and sent no
keyboard or movement input. Gameplay loaded successfully and a passive window
capture produced a nonblank true `1920x1080` screenshot.

Analyzer status:

- `Stage 2C Render-Scale Control Probe=Pass`
- `Native RenderFunc Entry=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc CommandBuffer Payload=Pass`
- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- `Native bridge API version: 14`

Key evidence:

```text
Native render-func context advanced: sampleCount=1; nonzeroContext=1; wrapSuccess=1; cmdNonNull=1; cmdPointerNonZero=1; wrapFailures=0; lastContext=0x2CA955828C0; lastWrappedContext=0x2CA955828C0; lastCmd=0x2CBF84E1E20; cmd="UnityEngine.Rendering.CommandBuffer name="; pass="Edge Adaptive Spatial Upsampling"
Native render-func resource native-pointer advanced: source=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; nativePtr=0x2CC1D734C20; nativeOwner=UnityEngine.Texture name=Apply Exposure Destination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic width=960 height=540 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Uber Post Destination rtHandleProperties=UnityEngine.Rendering.RTHandleProperties; frame=4); destination=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"; nativePtr=0x2CC1D7385E0; nativeOwner=UnityEngine.Texture name=Edge Adaptive Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32_Tex2DArray width=1920 height=1080 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Edge Adaptive Spatial Upsampling rtHandleProperties=UnityEngine.Rendering.RTHandleProperties; frame=4); targetCompile=4; targetManagedPassData=0x2CA9576FCC0; tuple=input=960x540; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"
Native render-func command-buffer payload set advanced: ... beforeConsumed=0; eventId=260608; sequence=1; status="render event texture payload pending: setAttempts=1; setSuccesses=1; setFailures=0; consumed=0; consumeFailures=0; eventId=260608; sequence=1; sourcePtr=000002CC1D734C20; destinationPtr=000002CC1D7385E0"
Native render-func command-buffer payload advanced: setAttempts=1; setSuccesses=1; setFailures=0; issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeConsumed=0; consumed=1; lastEventId=260608; callback=0x7FF89B311000; lastCmd=0x2CBF84E1E20; eventId=260608; sequence=1; status="render event texture payload consumed: setAttempts=1; setSuccesses=1; setFailures=0; consumed=1; consumeFailures=0; eventId=260608; sequence=1; sourcePtr=000002CC1D734C20; destinationPtr=000002CC1D7385E0; sameDevice=yes; source=960x540 fmt=26 mips=1 array=1; destination=1920x1080 fmt=26 mips=1 array=1; scale=(2.000x,2.000x)"; pass="Edge Adaptive Spatial Upsampling"
```

Counts:

- `Native render-func command-buffer payload advanced:` `1`
- `Native render-func command-buffer payload set advanced:` `1`
- `Native render-func command-buffer payload status #` `121`
- `render event texture payload consume failed` `0`
- payload set/event failures `0`
- `Native render-func resource native-pointer advanced` `1`
- `Native render-func context advanced` `1`
- broad `RenderGraph GetTexture call #` `0`
- separate native D3D11 pair probe `0`
- `ExecuteDLSS` `0`
- `nvngx` `0`
- `DLSS user rendering` `0`
- access-violation/crash patterns `0`

Cleanup passed:

- `CrashEventCount=0`
- `RestoredClientSettings=true`
- `RestoredLoaderConfig=true`
- `RestoredReleaseSafeNative=true`
- `RemainingVRisingProcessCount=0`
- before restore the save had one change
- after restore `CompareStatus=Restored` and `ChangeCount=0`

## Interpretation

This links the previously separate proofs:

- focused EASU resource identity and native pointer observation
- live EASU `RenderGraphContext.cmd`
- native render-event callback timing

The native bridge now proves that the EASU source/output texture pair can be
held as a short-lived native payload and consumed from a command-buffer-issued
render event. That is a closer approximation to the official
`DLSSPass.GetCameraResources -> DLSSPass.Render(..., ctx.cmd)` lifecycle than
the earlier broad `RenderGraphResourceRegistry.GetTexture` route.

This still does not prove NGX/DLSS feature lifecycle, depth/motion-vector
payload handoff, evaluate correctness, resize/reset behavior, visual
correctness, or performance. It only proves the source/output texture payload
and command-buffer callback lifecycle for the EASU boundary.

## Next Step

Use local IL2CPP/HDRP decompilation and upstream HDRP source as the map for the
next guard. The next minimal runtime step should not return to broad
`GetTexture`; it should either add depth/motion payload discovery at an
official-boundary-equivalent point, or add a local SDK-wrapper-only DLSS
frame-sequence lifecycle preflight at this exact callback boundary without
visible write-back first.
