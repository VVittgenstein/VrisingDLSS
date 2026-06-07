# Native RenderFunc CommandBuffer Frame Descriptor D3D11 + Render Scale Gameplay Result - 2026-06-07

Status: protected gameplay proof passed.

## Question

Can the source/decompilation-guided EASU `ctx.cmd` boundary validate a complete
frame descriptor made of focused EASU source/output plus HDRP depth/motion
native pointers as a same-device D3D11 resource set during protected gameplay at
true `1920x1080` Windowed, with V Rising FSR Off and mod-owned render scale
active?

## Hypothesis

The already-proven HDRP/EASU correlation should produce source, destination,
depth, and motion pointers in the same frame window. The plugin should set one
D3D11-validation descriptor and issue one event through the same EASU
`RenderGraphContext.cmd`. The native callback should consume the descriptor and
log shape validation only:

```text
validation=D3D11-succeeded; sameDevice=yes; ngx=not-loaded; evaluate=not-run
```

## Stage

`native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale`

Important config:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncContextProbe=true`
- `EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableHdrpPostProcessRenderArgsProbe=true`
- `EnableHdrpPostProcessRenderArgsGlobalTextureProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableNativeRenderFuncCommandBufferFrameDescriptorProbe=false`
- `EnableNativeRenderFuncResourceD3D11Probe=false`
- `EnableDLSS=false`

Native bridge API version observed in game log: `17`.

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

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale -ArtifactLabel native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.json"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveBackup-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.json`

## Result

Pass.

Analyzer reported:

- `Native RenderFunc CommandBuffer Frame Descriptor D3D11=Pass`
- `HDRP/EASU Input Output Correlation=Pass`
- `HDRP PostProcess Render Args Global Textures=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- `Stage 2C Render-Scale Control Probe=Pass`

Key evidence:

```text
Native render-func command-buffer frame descriptor D3D11 advanced: setAttempts=1; setSuccesses=1; setFailures=0; issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeConsumed=0; consumed=1; lastEventId=260611; ... eventId=260611; sequence=1; status="render event frame descriptor D3D11 validation consumed: ... sourcePtr=000001674CA7A1A0; destinationPtr=000001674CA830A0; depthPtr=000001674CA9EE20; motionPtr=000001674CAA48E0; input=960x540; output=1920x1080; hdrpFrame=3675; easuSourceFrame=3675; easuDestinationFrame=3675; sourceFrameDelta=0; destinationFrameDelta=0; validation=D3D11-succeeded; sameDevice=yes; source=960x540 fmt=26 mips=1 array=1; destination=1920x1080 fmt=26 mips=1 array=1; depth=960x540 fmt=19 mips=1 array=1; motion=960x540 fmt=33 mips=1 array=1; scale=(2.000x,2.000x); ngx=not-loaded; evaluate=not-run"; pass="Edge Adaptive Spatial Upsampling"
```

Counts:

- `Native render-func command-buffer frame descriptor D3D11 advanced:` `1`
- `Native render-func command-buffer frame descriptor D3D11 set advanced:` `1`
- `render event frame descriptor D3D11 validation consumed` `22`
- `validation=D3D11-succeeded` `22`
- `sameDevice=yes` `22`
- `source=960x540` `22`
- `destination=1920x1080` `22`
- `depth=960x540` `22`
- `motion=960x540` `22`
- `ngx=not-loaded` `23`
- `evaluate=not-run` `23`
- `D3D11 validation failed` `0`
- `ExecuteDLSS` `0`
- `DLSS user rendering` `0`
- actual visible write-back `0`
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
  `SaveAfterRun-native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1.zip`
- final `CompareStatus=Restored`
- final `ChangeCount=0`

## Interpretation

This proves the current source-guided route has reached a coherent D3D11
Super Resolution resource boundary:

- HDRP input color/depth/motion are all low-resolution `960x540`;
- EASU destination is the high-resolution `1920x1080` output;
- all four resources are on the same D3D11 device;
- the event is issued through the live EASU `RenderGraphContext.cmd`;
- the native callback can consume the descriptor safely without NGX/evaluate.

It still does not prove DLSS evaluate correctness, NGX feature reuse,
resize/reset behavior, visible image correctness, legal runtime distribution,
or performance. It does prove that future evaluate experiments should use this
descriptor boundary instead of returning to broad steady-state
`RenderGraph.GetTexture` discovery.

## Next Step

Use this D3D11 descriptor as the next source-guided base. The next minimal guard
should be a bounded SDK-wrapper-only no-write DLSS frame-sequence evaluate at
the same callback. Keep visible write-back, user rendering, and broad
`RenderGraph.GetTexture` disabled until no-write evaluate is proven.
