# Native RenderFunc CommandBuffer DLSS Visible Write-back + Render Scale Gameplay Result - 2026-06-07

Status: protected gameplay proof passed.

## Question

Can the source-guided EASU `ctx.cmd` boundary write DLSS output into the visible
EASU destination for three callbacks, then shut down, without old GetTexture
steady-state work, normal-user rendering, or a crash?

## Hypothesis

The visible write-back stage should reuse one DLSS frame sequence and finish
with `visibleOutput=yes`, `scratchOutput=no`, `sequenceCreates=1`,
`sequenceEvaluates=3`, `evaluateSuccesses=3`, and `shutdown=completed`.

## Stage

`native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale`

Important config:

- `EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe=true`
- `EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe=false`
- `EnableDlssVisibleWritebackProbe=false`
- `EnableDlssRuntimeProbe=true`
- `EnableRenderScaleControlProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`
- `EnableDLSS=false`

Native bridge API version observed in game log: `20`.

## Protocol

- Confirmed no V Rising process was running.
- Backed up the protected save:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`
- Started the automation session at `1920x1080` Windowed with
  `GraphicSettings.WindowMode=3`, `-UseSdkWrapperNative`, and
  `Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll`.
- Used Computer Use to select the real `VRising` Unity window, not the BepInEx
  console.
- Clicked the Chinese Continue entry once in the main menu.
- Sent no keyboard movement, combat, or gameplay keys.
- Waited passively after gameplay loaded.
- Captured a gameplay screenshot.
- Stopped the session, archived logs, restored loader config, restored
  ClientSettings, restored the release-safe native DLL, and restored the
  protected save from backup.

## Artifacts

- `artifacts/gameplay-automation/Session-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SessionScreenshot-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/GameplayScreenshot-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.png`
- `artifacts/gameplay-automation/LogOutput-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/SaveBackup-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.zip`
- `artifacts/gameplay-automation/SaveCompareBeforeRestore-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-1080p-20260607-r1.json`

## Result

Pass.

Analyzer reported:

- `Native RenderFunc CommandBuffer DLSS Visible Write-back=Pass`
- `HDRP/EASU Input Output Correlation=Pass`
- `HDRP PostProcess Render Args Global Textures=Pass`
- `Native RenderFunc Context=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- `Stage 2C Render-Scale Control Probe=Pass`
- `Stage 5D DLSS Runtime=Pass`

Key evidence:

```text
Native render-func command-buffer DLSS visible write-back advanced:
setAttempts=3; setSuccesses=3; setFailures=0;
issueAttempts=3; issueSuccesses=3; issueFailures=0;
consumed=3; lastEventId=260614; sequence=3;
input=960x540; output=1920x1080;
validation=D3D11-succeeded; sameDevice=yes;
source=960x540; visibleDestination=1920x1080;
depth=960x540; motion=960x540;
scratchOutput=no; visibleOutput=yes; persistent=yes;
targetSuccesses=3; sequenceCreates=1; sequenceEvaluates=3;
evaluateSuccesses=3; evaluateResult=1; shutdownResult=1;
shutdown=completed; recreated=no; evaluateLast=0x00000001;
nativeTimingMs=(describe=0.001,query=0.000,prepare=0.001,evaluate=0.206,total=0.209);
release=0x00000001; destroy=0x00000001; shutdown=0x00000001;
pass="Edge Adaptive Spatial Upsampling"
```

Counts and checks:

- visible write-back advanced `1`
- consumed visible write-back status lines `18`
- `eventId=260614` lines `113`
- `shutdown=completed` lines `18`
- `DLSS visible write-back failed` `0`
- `DLSS visible write-back blocked` `0`
- `RenderGraph GetTexture call #` `0`
- old `DLSS visible write-back probe` `0`
- `DLSS user rendering evaluate succeeded` `0`
- crash events `0`

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

This is the first source-guided protected gameplay proof that DLSS can write
into the visible EASU output at the focused `ctx.cmd` boundary and then cleanly
release/destroy/shutdown. It also proves this can happen without the older
global `RenderGraph.GetTexture` hot path, without old Stage 10A, and without
normal-user rendering.

The proof is intentionally bounded: it writes three frames and stops. It is not
yet the final MVP path. The next guard should turn this into a normal-user
candidate or visual/performance comparison while preserving the same placement,
limiting per-frame discovery, and keeping resize/reset/fallback behavior
explicit.
