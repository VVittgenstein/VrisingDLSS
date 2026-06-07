# Native RenderFunc CommandBuffer DLSS Scratch Evaluate + Render Scale Gameplay Result - 2026-06-07

Status: protected gameplay proof passed.

## Question

Can the source-guided EASU `ctx.cmd` boundary evaluate DLSS once into a native
scratch output texture during protected `1920x1080` Windowed gameplay, with V
Rising FSR Off and no visible output write-back?

## Hypothesis

The same source/output/depth/motion descriptor that passed D3D11 validation
should be valid for one SDK-wrapper DLSS frame-sequence evaluate when the output
is a scratch texture cloned from the visible destination descriptor. The visible
EASU output should remain untouched.

## Stage

`native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale`

Important config:

- `EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe=true`
- `EnableDlssRuntimeProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe=false`
- `EnableNativeRenderFuncCommandBufferDlssFeatureCreateProbe=false`
- `EnableDLSS=false`

Native bridge API version observed in game log: `18`.

## Protocol

- Confirmed no V Rising process was running.
- Confirmed `Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll` existed.
- Set V Rising `FsrQualityMode=Off`.
- Backed up the protected save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Started the automation session at `1920x1080` Windowed with
  `GraphicSettings.WindowMode=3`, `-UseSdkWrapperNative`, and the DLSS runtime.
- Used Computer Use to select the real `VRising` Unity window, not the BepInEx
  console.
- Clicked the Chinese Continue entry once in the main menu.
- Sent no keyboard movement or gameplay keys.
- Waited passively after gameplay loaded.
- Stopped the session, archived logs, restored loader config, restored
  ClientSettings, restored the release-safe native DLL, and restored the
  protected save from backup.

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/SaveBackup-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveAfterRun-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1.json`

## Result

Pass.

Analyzer reported:

- `Native RenderFunc CommandBuffer DLSS Scratch Evaluate=Pass`
- `HDRP/EASU Input Output Correlation=Pass`
- `HDRP PostProcess Render Args Global Textures=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- `Stage 2C Render-Scale Control Probe=Pass`
- `Stage 5D DLSS Runtime=Pass`

Key evidence:

```text
Native render-func command-buffer DLSS scratch evaluate advanced: setAttempts=1; setSuccesses=1; setFailures=0; issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeConsumed=0; consumed=1; lastEventId=260612; ... status="render event frame descriptor DLSS scratch evaluate consumed: ... input=960x540; output=1920x1080; hdrpFrame=3352; easuSourceFrame=3352; easuDestinationFrame=3352; sourceFrameDelta=0; destinationFrameDelta=0; validation=D3D11-succeeded; sameDevice=yes; source=960x540 fmt=26 mips=1 array=1; visibleDestination=1920x1080 fmt=26 mips=1 array=1; depth=960x540 fmt=19 mips=1 array=1; motion=960x540 fmt=33 mips=1 array=1; scale=(2.000x,2.000x); scratchOutput=yes; visibleOutput=no; evaluateResult=1; shutdownResult=1; evaluateStatus="DLSS frame-sequence evaluate probe completed via SDK wrapper ProjectID; ... render=960x540; target=1920x1080; perfQuality=0; flags=0x00000040; ... sequenceCreates=1; sequenceEvaluates=1; evaluateSuccesses=1; create=0x00000001; feature=yes; evaluateLast=0x00000001; nativeTimingMs=(describe=0.001,query=0.000,prepare=1005.944,evaluate=0.446,total=1006.392)"; shutdownStatus="DLSS frame-sequence shutdown completed; hadSession=yes; sequenceCreates=1; sequenceEvaluates=1; evaluateSuccesses=1; release=0x00000001; destroy=0x00000001; shutdown=0x00000001""; pass="Edge Adaptive Spatial Upsampling"
```

Counts and checks:

- scratch evaluate advanced `1`
- scratch evaluate set advanced `1`
- native max `consumed=1`
- max `sequenceCreates=1`
- max `sequenceEvaluates=1`
- max `evaluateSuccesses=1`
- `evaluateResult=1`
- `shutdownResult=1`
- `evaluateLast=0x00000001`
- `scratchOutput=yes`
- `visibleOutput=no`
- `validation=D3D11-succeeded`
- `sameDevice=yes`
- source/depth/motion `960x540`
- visible destination `1920x1080`
- D3D11/scratch/evaluate failures `0`
- SDK-wrapper blocked lines `0`
- `DLSS user rendering` `0`
- actual visible write-back `0`
- `ExecuteDLSS` `0`
- crash/access-violation patterns `0`

The repeated status lines after the pass reused the same native status; they did
not mean repeated evaluate. The max values remained `consumed=1`,
`sequenceCreates=1`, and `sequenceEvaluates=1`.

## Cleanup

Stop-session cleanup passed:

- `CrashEventCount=0`
- `RestoredClientSettings=true`
- `RestoredLoaderConfig=true`
- `RestoredReleaseSafeNative=true`
- `RemainingVRisingProcessCount=0`

Save restore passed:

- `BeforeChangeCount=1`
- final `CompareStatus=Restored`
- final `ChangeCount=0`

## Interpretation

This proves DLSS can evaluate successfully at the focused EASU
`RenderGraphContext.cmd` callback when using the same source-guided
source/output/depth/motion descriptor and a native scratch output. It also
supports the user's source-first intuition: the local IL2CPP/HDRP source map
helped move the work from broad hot-path discovery to a single meaningful
boundary proof.

It still does not prove persistent feature reuse, visible image correctness,
resize/reset behavior, legal runtime distribution, or performance. The
one-shot result is important for performance diagnosis: most of the first call
time was feature/init preparation (`prepare=1005.944ms`), while the actual
evaluate was short (`evaluate=0.446ms`). The next source-guided guard should
therefore keep one scratch DLSS feature alive across frames at this same
boundary before any visible write-back or normal-user rendering change.
