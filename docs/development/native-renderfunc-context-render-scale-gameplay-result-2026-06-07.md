# Native RenderFunc Context + Render Scale Gameplay Result - 2026-06-07

## Question

Can the proven EASU native render-func boundary safely wrap the raw
`RenderGraphContext` pointer and read `ctx.cmd` identity during protected
`11111` gameplay at true `1920x1080` Windowed, with V Rising FSR Off and
mod-owned render scale active?

## Hypothesis

If the native render-func callback is running inside the real RenderGraph pass
execute window, the interop `RenderGraphContext` wrapper should expose a
non-null `CommandBuffer` with a non-zero Il2Cpp pointer. The probe should log
that identity only; it must not issue command-buffer work, resolve textures
through broad `GetTexture`, validate D3D11 resources, load NGX, or evaluate
DLSS.

## Stage

`native-renderfunc-context-render-scale`

Important config:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableNativeRenderFuncResourceNativePointerProbe=false`
- `EnableNativeRenderFuncResourceD3D11Probe=false`
- `EnableDLSS=false`

## Artifacts

- Session:
  `artifacts/gameplay-automation/Session-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.json`
- BepInEx log:
  `artifacts/gameplay-automation/LogOutput-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.log`
- Analysis:
  `artifacts/gameplay-automation/Analysis-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.txt`
- Runtime analysis copy:
  `artifacts/runtime-logs/Analysis-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.txt`
- Gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.png`
- Cleanup:
  `artifacts/gameplay-automation/Cleanup-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.json`
- Save restore:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1.json`

## Result

Pass.

Computer Use selected the real `VRising` Unity window, clicked the known
Chinese Continue entry once, and sent no keyboard or movement input. Gameplay
loaded successfully and the passive gameplay screenshot captured a nonblank
`1920x1080` game window.

Analyzer status:

- `Stage 2C Render-Scale Control Probe=Pass`
- `Native RenderFunc Entry=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native bridge API version: 13`

Key evidence:

```text
Native render-func resource tuple advanced: compile=4; sampleCount=1; managedPassData=0x20398794000; nativeLastPassData=0x20398794000; passDataMatches=True; tupleReady=True; pass="Edge Adaptive Spatial Upsampling"; tuple=input=960x540; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77"
Native render-func context advanced: sampleCount=1; nonzeroContext=1; wrapSuccess=1; cmdNonNull=1; cmdPointerNonZero=1; wrapFailures=0; lastContext=0x204BEE9F700; lastWrappedContext=0x204BEE9F700; lastCmd=0x204BEF85EC0; cmd="UnityEngine.Rendering.CommandBuffer name="; pass="Edge Adaptive Spatial Upsampling"
Native render-func context status #8100: compile=8100; installed=True; entryCount=6699; sampleCount=6699; nonzeroContext=6699; wrapSuccess=6699; cmdNonNull=6699; cmdPointerNonZero=6699; wrapFailures=0; lastContext=0x206EFB81A80; lastWrappedContext=0x206EFB81A80; lastCmd=0x204BEF85EC0; cmd="UnityEngine.Rendering.CommandBuffer name="; failure="none"; candidatePointer=0x7FFFA56AE1C0; pass="Edge Adaptive Spatial Upsampling"
```

Counts:

- `Native render-func context advanced:` `1`
- `Native render-func context status #` `141`
- `wrapFailures=[1-9]` `0`
- broad `RenderGraph GetTexture call #` `0`
- `Native render-func resource native-pointer` `0`
- `Native render-func resource D3D11` `0`
- `ExecuteDLSS` `0`
- `NGX` `0`
- `DLSS user rendering` `0`
- native entry failures `0`
- detour dispose failures `0`
- crash patterns `0`

Cleanup passed:

- `CrashEventCount=0`
- `RestoredClientSettings=true`
- `RestoredLoaderConfig=true`
- `RestoredReleaseSafeNative=true`
- `RemainingVRisingProcessCount=0`
- before restore the save had two added autosaves
- after restore `CompareStatus=Restored` and `ChangeCount=0`

## Interpretation

This proves that the focused EASU native render-func callback is close enough to
the official HDRP RenderGraph execute boundary to read a live
`RenderGraphContext.cmd` identity safely under gameplay conditions. It also
keeps the proven low-to-full EASU tuple under V Rising FSR Off:
`960x540 -> 1920x1080`.

This does not prove command-buffer work, plugin-event ordering, NGX lifecycle,
DLSS evaluate, resize/reset behavior, image correctness, or performance. Those
must remain separate guards.

## Next Step

The next source-guided guard can test a no-op command-buffer/plugin-event timing
proof at this exact EASU render-func boundary. It should still avoid DLSS
evaluate in the same step.
