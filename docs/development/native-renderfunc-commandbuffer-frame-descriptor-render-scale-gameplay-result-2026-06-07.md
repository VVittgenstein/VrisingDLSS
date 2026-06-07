# Native RenderFunc CommandBuffer Frame Descriptor + Render Scale Gameplay Result - 2026-06-07

Status: protected gameplay proof passed.

## Question

Can the source/decompilation-guided EASU `ctx.cmd` boundary carry a complete
frame descriptor made of focused EASU source/output plus HDRP depth/motion
native pointers during protected gameplay at true `1920x1080` Windowed, with
V Rising FSR Off and mod-owned render scale active?

## Hypothesis

The HDRP/EASU correlation state should become ready in gameplay once
`DarkForeground.Render(...)` and the focused EASU native-pointer observations
land in the same Unity frame. After that, the plugin should set one native
frame-descriptor payload and issue one event through the same EASU
`RenderGraphContext.cmd`. The native callback should consume the descriptor and
log metadata only:

```text
validation=D3D11-not-queried; ngx=not-loaded; evaluate=not-run
```

## Stage

`native-renderfunc-commandbuffer-frame-descriptor-render-scale`

Important config:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferFrameDescriptorProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableHdrpPostProcessRenderArgsProbe=true`
- `EnableHdrpPostProcessRenderArgsGlobalTextureProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableNativeRenderFuncResourceD3D11Probe=false`
- `EnableDLSS=false`

Native bridge API version observed in game log: `16`.

## Protocol

- Confirmed no V Rising process was running.
- Set V Rising `FsrQualityMode=Off`.
- Backed up the protected save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Started the automation session at `1920x1080` Windowed with
  `GraphicSettings.WindowMode=3`.
- Used Computer Use to select the real `VRising` Unity window, not the BepInEx
  console.
- Clicked the Chinese Continue entry once in the main menu.
- Sent no keyboard movement or gameplay keys.
- Waited passively after gameplay loaded.
- Stopped the session, archived logs, restored loader config, restored
  ClientSettings, restored the release-safe native DLL, and restored the
  protected save from backup.

Commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\set-vrising-fsr-mode.ps1 -Mode Off

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-commandbuffer-frame-descriptor-render-scale -ArtifactLabel native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.json"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveBackup-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.json`

## Result

Pass.

Analyzer reported:

- `Native RenderFunc CommandBuffer Frame Descriptor=Pass`
- `HDRP/EASU Input Output Correlation=Pass`
- `HDRP PostProcess Render Args Global Textures=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- `Stage 2C Render-Scale Control Probe=Pass`

Key evidence:

```text
HDRP/EASU input-output correlation advanced: hdrpFrame=4110; easuSourceFrame=4110; easuDestinationFrame=4110; sourceFrameDelta=0; destinationFrameDelta=0; ... CameraDepthStencil_960x540 ... Motion Vectors_960x540 ... source=(... nativePtr=0x139757656A0 ... width=960 height=540 ...); destination=(... nativePtr=0x13BB07A85A0 ... width=1920 height=1080 ...); tuple=input=960x540; output=1920x1080

Native render-func command-buffer frame descriptor set advanced: ... descriptorFrames=hdrp:4110,easuSource:4110,easuDestination:4110; size=input:960x540,output:1920x1080; beforeConsumed=0; eventId=260610; sequence=1; status="render event frame descriptor payload pending: setAttempts=1; setSuccesses=1; setFailures=0; consumed=0; consumeFailures=0; eventId=260610; sequence=1; sourcePtr=00000139757656A0; destinationPtr=0000013BB07A85A0; depthPtr=0000013B504199E0; motionPtr=0000013B50419CA0; input=960x540; output=1920x1080; hdrpFrame=4110; easuSourceFrame=4110; easuDestinationFrame=4110; validation=D3D11-not-queried; ngx=not-loaded; evaluate=not-run"

Native render-func command-buffer frame descriptor advanced: setAttempts=1; setSuccesses=1; setFailures=0; issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeConsumed=0; consumed=1; lastEventId=260610; ... status="render event frame descriptor payload consumed: ... sourcePtr=00000139757656A0; destinationPtr=0000013BB07A85A0; depthPtr=0000013B504199E0; motionPtr=0000013B50419CA0; input=960x540; output=1920x1080; hdrpFrame=4110; easuSourceFrame=4110; easuDestinationFrame=4110; sourceFrameDelta=0; destinationFrameDelta=0; validation=D3D11-not-queried; ngx=not-loaded; evaluate=not-run"; pass="Edge Adaptive Spatial Upsampling"
```

Counts:

- `Native render-func command-buffer frame descriptor advanced:` `1`
- `Native render-func command-buffer frame descriptor set advanced:` `1`
- `render event frame descriptor payload consumed` `25`
- `validation=D3D11-not-queried` `26`
- `ngx=not-loaded` `26`
- `evaluate=not-run` `26`
- `D3D11 pair advanced` `0`
- `D3D11 pair failed` `0`
- `ExecuteDLSS` `0`
- `DLSS user rendering` `0`
- broad `RenderGraph GetTexture call #` `0`
- crash/access-violation patterns `0`

The one broad `visible write-back` string in the log was the startup warning
that this stage performs no visible write-back, not an actual write-back event.

## Cleanup

Stop-session cleanup passed:

- `CrashEventCount=0`
- `RestoredClientSettings=true`
- `RestoredLoaderConfig=true`
- `RestoredReleaseSafeNative=true`
- `RemainingVRisingProcessCount=0`

Save restore passed:

- `BeforeChangeCount=1`
- post-run save archived as
  `SaveAfterRun-native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1.zip`
- final `CompareStatus=Restored`
- final `ChangeCount=0`

## Interpretation

This is the strongest release-safe, no-evaluate boundary proof so far. It links:

- the source/decompilation-guided HDRP low-resolution input side;
- global depth and motion-vector native pointers;
- the focused EASU source/output native-pointer side;
- live `RenderGraphContext.cmd` event ordering;
- native render-event payload lifetime.

It brings the clean-room route closer to the official HDRP shape:

```text
DoDLSSPass -> DLSSPass.GetCameraResources -> DLSSPass.Render(..., ctx.cmd)
```

It still does not prove D3D11 compatibility for all four resources, DLSS
evaluate correctness, resize/reset behavior, visible image correctness, legal
runtime distribution, or performance. It proves only that the complete
four-pointer descriptor can be transported and consumed safely at this boundary
without broad steady-state `GetTexture` discovery.

## Next Step

Use this descriptor as the next source-guided base. The next minimal guard
should be separate:

- either D3D11/SR input validation for the four resources; or
- a bounded SDK-wrapper-only no-write evaluate preflight at this same callback.

Do not combine D3D11 validation, NGX lifecycle, DLSS evaluate, and visible
write-back into one test.
