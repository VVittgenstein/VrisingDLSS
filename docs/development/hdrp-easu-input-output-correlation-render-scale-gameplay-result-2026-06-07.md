# HDRP/EASU Input Output Correlation + Render Scale Gameplay Result - 2026-06-07

Run labels:

```text
hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r1
hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r2
hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r3
```

## Question

Can one protected gameplay run correlate the low-resolution HDRP/ProjectM
`DarkForeground.Render(...)` color/depth/motion input side with the focused EASU
RenderGraph source/output native-pointer side, without D3D11 validation,
command-buffer plugin events, NGX feature lifecycle, DLSS evaluate, user
rendering, or visible write-back?

## Hypothesis

Under mod-owned 50% render-scale control, `DarkForeground.Render(...)` should
observe HDRP color/depth/motion at `960x540`, while the focused EASU pass should
observe a source at `960x540` and a destination at `1920x1080`. A valid
correlation must use current frame-adjacent observations, not stale
RenderGraph resource-handle indices from an earlier compile.

## Setup

- V Rising `FsrQualityMode=Off`.
- Resolution/window mode: true `1920x1080` Windowed.
- Stage: `hdrp-easu-input-output-correlation-render-scale`.
- Protected save fixture: `11111`.
- Computer Use clicked Continue once per run and sent no keyboard/movement
  input.

The stage enabled only the HDRP render-args/global-texture snapshot, focused
EASU native-pointer observation, render-scale control, upscaler state logging,
and native bridge smoke-test. It did not run D3D11 validation, issue
command-buffer events/payloads, initialize NGX, evaluate DLSS, run user
rendering, or write visible output.

## Iterations

- `r1`: Partial. EASU native-pointer observation happened at frame `4`; the
  first HDRP `DarkForeground` snapshot happened at frame `5281`. The five-frame
  correlation window correctly rejected this stale pairing.
- `r2`: False-positive caught during manual evidence review. The analyzer still
  reported pass, but the advanced line paired the stale EASU tuple with actual
  `CoC Mip_60x34` / `BloomMipUp_60x34` observations. Fix: pass now requires the
  actual EASU source observation to contain the EASU input size and the actual
  destination observation to contain the EASU output size; while correlation is
  pending, later compiles may re-arm the focused EASU target.
- `r3`: Pass.

## r3 Result

Analyzer:

- `Stage 2C Render-Scale Control Probe=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- `HDRP PostProcess Render Args=Pass`
- `HDRP PostProcess Render Args Global Textures=Pass`
- `HDRP/EASU Input Output Correlation=Pass`

Key pass line:

```text
HDRP/EASU input-output correlation advanced: hdrpFrame=3005; easuSourceFrame=3005; easuDestinationFrame=3005; sourceFrameDelta=0; destinationFrameDelta=0; frameDeltaWithinWindow=True; hdrpCameraMatchesEasuInput=True; hdrpColorMatchesEasuInput=True; hdrpDepthMotionMatchEasuInput=True; easuSourceMatchesEasuInput=True; easuDestinationMatchesEasuOutput=True; easuUpscales=True
```

Key resource evidence:

- HDRP camera: `actualWidth=960`, `actualHeight=540`, Unity camera pixels
  `1920x1080`.
- HDRP color source: `CameraColor_960x540_B10G11R11_UFloatPack32`.
- HDRP depth: `CameraDepthStencil_960x540` with non-zero native pointer.
- HDRP motion: `Motion Vectors_960x540_R16G16_SFloat` with non-zero native
  pointer.
- EASU source: `TAA Destination_960x540_B10G11R11_UFloatPack32` with non-zero
  native pointer.
- EASU destination: `Edge Adaptive Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32`
  with non-zero native pointer.
- EASU tuple: `input=960x540; output=1920x1080`.

Counts from the r3 BepInEx log:

- Correlation advanced: `1`
- Correlation status: `8`
- Native pointer advanced: `1`
- Native pointer status: `98`
- HDRP global advanced: `1`
- Broad `RenderGraph GetTexture call #`: `0`
- D3D11 pair advanced/failed: `0` / `0`
- Command-buffer event/payload advanced: `0` / `0`
- DLSS feature-create advanced: `0`
- NGX: `0`
- `ExecuteDLSS`: `0`
- `DLSS user rendering`: `0`
- Visible write-back: `0`
- Crash/access violation: `0`
- `CrashEventCount=0`

Cleanup:

- Game process stopped.
- Loader config restored.
- ClientSettings restored.
- Release-safe native DLL restored.
- Protected save restored with `ChangeCount=0`.

## Interpretation

This proves the mod can correlate the low-resolution color/depth/motion input
side with the full-size EASU output side in the same gameplay frame window. The
result is still a diagnostic proof only: it does not evaluate DLSS, prove a
native payload layout for depth/motion, prove resize/reset, visual correctness,
legal runtime distribution, or performance.

Next guard: build a no-evaluate native payload descriptor that carries EASU
color/output plus HDRP depth/motion native pointers toward the already-proven
EASU `ctx.cmd` callback boundary. Keep D3D11 validation, NGX lifecycle, and DLSS
evaluate separate from that payload-shape proof.
