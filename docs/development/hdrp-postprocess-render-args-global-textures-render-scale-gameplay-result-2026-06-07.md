# HDRP PostProcess Render Args Global Textures + Render Scale Gameplay Result - 2026-06-07

Run label:

```text
hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1
```

## Question

At the protected `DarkForeground.Render(CommandBuffer, HDCamera, RTHandle,
RTHandle)` custom postprocess boundary, can the mod see render-scale-controlled
low-resolution color plus HDRP-bound global depth/motion textures without using
RenderGraph `GetTexture`, D3D11 validation, command-buffer work, NGX, or DLSS
evaluate?

## Hypothesis

HDRP source shows `DoCustomPostProcess(...)` binds `data.depthBuffer` to
`_CameraDepthTexture` and `data.motionVecTexture` to
`_CameraMotionVectorsTexture` immediately before calling
`customPostProcess.Render(ctx.cmd, data.hdCamera, data.source,
data.destination)`. If V Rising's `DarkForeground.Render(...)` is reached under
the mod-owned 50% render-scale control, `Shader.GetGlobalTexture(...)` should
expose depth and motion textures aligned with the 960x540 render space.

## Setup

- V Rising `FsrQualityMode=Off`.
- Resolution/window mode: true `1920x1080` Windowed.
- Stage: `hdrp-postprocess-render-args-global-textures-render-scale`.
- The stage enabled only:
  - `EnableHdrpPostProcessRenderArgsProbe=true`
  - `EnableHdrpPostProcessRenderArgsGlobalTextureProbe=true`
  - `EnableRenderScaleControlProbe=true`
  - `EnableRenderGraphGetTextureProbe=false`
  - `EnableHookProbe=false`
  - `EnableDLSS=false`
- It did not load the native bridge, run D3D11 validation, initialize NGX, issue
  command-buffer plugin events, evaluate DLSS, or write visible output.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\set-vrising-fsr-mode.ps1 -Mode Off
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage hdrp-postprocess-render-args-global-textures-render-scale -ArtifactLabel hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1.json"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Result

Pass.

- Analyzer: `Stage 2C Render-Scale Control Probe=Pass`
- Analyzer: `HDRP PostProcess Render Args=Pass`
- Analyzer: `HDRP PostProcess Render Args Global Textures=Pass`
- Snapshots logged: `9`
- Global-texture advanced lines: `1`
- `_CameraDepthTexture=null`: `0`
- `_CameraMotionVectorsTexture=null`: `0`
- `RenderGraph GetTexture call #`: `0`
- D3D11 validation: `0`
- NGX/native DLSS runtime: `0`
- DLSS evaluate/writeback: `0`
- Crash/exception/access violation: `0`
- `CrashEventCount=0`
- `RemainingVRisingProcessCount=0`
- Save restore: `ChangeCount=0`

Player log confirmed gameplay:

```text
SetResolution 1920, 1080, fullScreenMode Windowed
Created Camera TopDownCamera
Assigned Camera TopDownCamera to LocalUser
```

## Key Evidence

First advanced line:

```text
camera.actualWidth=960; camera.actualHeight=540; camera.pixelWidth=1920; camera.pixelHeight=1080
source=CameraColor_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic
destination=CustomPostProcesDestination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic
_CameraDepthTexture=CameraDepthBufferMipChain_960x810_R32_SFloat_Tex2DArray_dynamic; nativePtr=0x1C3CE5BB920
_CameraMotionVectorsTexture=Motion Vectors_960x540_R16G16_SFloat_Tex2DArray_dynamic; nativePtr=0x1C3CE5BB660
```

Subsequent snapshots showed the depth global stabilizing to the direct
`CameraDepthStencil_960x540_None_Tex2DArray_dynamic` texture with native pointer
`0x1C3CE5BB3A0`, while motion remained
`Motion Vectors_960x540_R16G16_SFloat_Tex2DArray_dynamic`.

## Interpretation

This proves the ProjectM/HDRP custom postprocess boundary can expose a useful
low-resolution DLSS input side under mod-owned render-scale control:

- color: `960x540`
- depth: `960x540` after the first logged transition
- motion vectors: `960x540`
- managed command buffer and HDCamera are present

It is still not a full Super Resolution evaluate boundary. The custom
postprocess destination is also `960x540`, while the proven EASU/native
render-func boundary exposes the full-size `1920x1080` output. The next guard
should correlate this low-resolution color/depth/motion boundary with the
already proven full-size EASU output/native command-buffer boundary. Do not
combine that with broad `GetTexture` discovery, D3D11 validation, NGX, or DLSS
evaluate until a separate no-evaluate payload proof exists.
