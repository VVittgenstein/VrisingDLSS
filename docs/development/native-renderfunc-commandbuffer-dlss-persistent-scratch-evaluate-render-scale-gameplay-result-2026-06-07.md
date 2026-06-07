# Native RenderFunc CommandBuffer DLSS Persistent Scratch Evaluate + Render Scale Gameplay Result - 2026-06-07

Status: protected gameplay proof passed.

## Question

Can the source-guided EASU `ctx.cmd` boundary reuse one DLSS frame sequence
across multiple protected gameplay callbacks, evaluate into scratch output
three times, and shut down without visible write-back?

## Hypothesis

After target refresh is allowed until the persistent success target is reached,
the stage should keep the frame sequence alive, avoid recreating the DLSS
feature after the first evaluate, and finish with `sequenceCreates=1`,
`sequenceEvaluates=3`, `evaluateSuccesses=3`, and `shutdown=completed`.

## Stage

`native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale`

Important config:

- `EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe=true`
- `EnableDlssRuntimeProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe=false`
- `EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe=false`
- `EnableNativeRenderFuncCommandBufferDlssFeatureCreateProbe=false`
- `EnableDLSS=false`

Native bridge API version observed in game log: `19`.

## Protocol

- Confirmed no V Rising process was running.
- Confirmed `Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll` existed.
- Confirmed V Rising `FsrQualityMode=Off`.
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

- `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.log`
- `artifacts/gameplay-automation/SaveBackup-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.zip`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r2.json`

## Result

Pass.

Analyzer reported:

- `Native RenderFunc CommandBuffer DLSS Persistent Scratch Evaluate=Pass`
- `HDRP/EASU Input Output Correlation=Pass`
- `HDRP PostProcess Render Args Global Textures=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- `Stage 2C Render-Scale Control Probe=Pass`
- `Stage 5D DLSS Runtime=Pass`

Key evidence:

```text
Native render-func command-buffer DLSS persistent scratch evaluate advanced:
setAttempts=3; setSuccesses=3; setFailures=0;
issueAttempts=3; issueSuccesses=3; issueFailures=0;
consumed=3; lastEventId=260613; sequence=3;
input=960x540; output=1920x1080;
validation=D3D11-succeeded; sameDevice=yes;
source=960x540; visibleDestination=1920x1080;
depth=960x540; motion=960x540;
scratchOutput=yes; visibleOutput=no; persistent=yes;
targetSuccesses=3; sequenceCreates=1; sequenceEvaluates=3;
evaluateSuccesses=3; evaluateResult=1; shutdownResult=1;
shutdown=completed; recreated=no; evaluateLast=0x00000001;
nativeTimingMs=(describe=0.001,query=0.000,prepare=0.003,evaluate=0.228,total=0.232);
release=0x00000001; destroy=0x00000001; shutdown=0x00000001;
pass="Edge Adaptive Spatial Upsampling"
```

The three set records stayed on the current EASU resources:

- sequence `1`: `hdrpFrame=4688`, EASU source/destination frame `4688`,
  source handle index `86`, destination handle index `87`.
- sequence `2`: `hdrpFrame=4690`, EASU source/destination frame `4690`,
  source handle index `86`, destination handle index `87`.
- sequence `3`: `hdrpFrame=4692`, EASU source/destination frame `4692`,
  source handle index `88`, destination handle index `89`.

The final HDRP/EASU correlation in the same run reported `hdrpFrame=4688`,
`easuSourceFrame=4688`, `easuDestinationFrame=4688`, HDRP color/depth/motion at
`960x540`, EASU source `TAA Destination_960x540`, EASU destination
`Edge Adaptive Spatial Upsampling_1920x1080`, and tuple
`input=960x540; output=1920x1080`.

Counts and checks:

- persistent scratch advanced `1`
- persistent scratch set advanced `3`
- native max `consumed=3`
- max `sequenceCreates=1`
- max `sequenceEvaluates=3`
- max `evaluateSuccesses=3`
- `evaluateResult=1`
- `shutdownResult=1`
- `evaluateLast=0x00000001`
- `scratchOutput=yes`
- `visibleOutput=no`
- `validation=D3D11-succeeded`
- `sameDevice=yes`
- D3D11/scratch/evaluate failures `0`
- SDK-wrapper blocked lines `0`
- `DLSS persistent scratch evaluate failed` `0`
- `visibleOutput=yes` `0`
- `DLSS visible write-back` `0`
- `ExecuteDLSS` `0`
- `DLSS user rendering evaluate` `0`
- `RenderGraph GetTexture call #` `0`
- crash/access-violation patterns `0`

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

## Prior Iteration

`native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1`
was Partial, not a DLSS failure. It reached `sequenceCreates=1`,
`sequenceEvaluates=2`, and `evaluateSuccesses=2`, with `shutdown=pending`.
After two successes the managed target could remain armed to an older compile,
and RenderGraph handle indexes were later reused by unrelated resources. The
fix was to continue target refresh while persistent set/issue successes are
below the target count.

## Interpretation

This proves the source-guided EASU `RenderGraphContext.cmd` callback can carry
the full Super Resolution descriptor, reuse a single DLSS frame sequence across
multiple callbacks, and complete repeated scratch-output evaluates without
visible output writes.

The one-shot scratch run spent about one second in first-call NGX preparation.
This persistent run shows the steady-state path after feature creation is tiny:
the final evaluate status reported `prepare=0.003ms`, `evaluate=0.228ms`, and
`total=0.232ms`. That supports the current performance hypothesis: the bad
performance observed earlier is much more likely to come from hot hooks,
resource discovery, synchronization, or visible-path integration than from DLSS
evaluate cost itself.

This still does not prove visible image correctness, resize/reset behavior,
fallback behavior, legal runtime distribution, or normal-user-path performance.
The next guard can move from scratch-output lifecycle proof to a separately
gated visible write-back timing/quality proof, or keep following the local
decompilation/source map to find a cleaner official DLSS-pass-equivalent
boundary before touching visible output.
