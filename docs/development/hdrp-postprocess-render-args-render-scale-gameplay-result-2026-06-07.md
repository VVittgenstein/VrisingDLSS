# HDRP PostProcess Render Args + Render Scale Gameplay Result - 2026-06-07

Run label:

```text
hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1
```

## Question

When V Rising's built-in `FsrQualityMode` is `Off` and the mod-owned
`RenderScaleControlProbe` forces Performance scale, can the gameplay-proven
`DarkForeground.Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` boundary
see the scaled render resources?

## Hypothesis

The existing v6 render-scale intervention will force the active HDRP dynamic
resolution handler to `0.5`. If `DarkForeground.Render(...)` runs in the same
scaled render space, its managed argument snapshot should show
`actualWidth=960`, `actualHeight=540`, and `CameraColor_960x540`.

The test must not call `RenderGraph GetTexture`, native texture pointer reads,
D3D11 validation, NGX, or DLSS evaluate.

## Setup

- V Rising `FsrQualityMode` was explicitly set to `Off`.
- Previous FSR mode was already `Off`.
- Resolution/window mode: true `1920x1080` Windowed.
- Stage: `hdrp-postprocess-render-args-render-scale`.
- The stage enabled only:
  - `EnableHdrpPostProcessRenderArgsProbe=true`
  - `EnableRenderScaleControlProbe=true`
  - `EnableRenderGraphGetTextureProbe=false`
  - `EnableHookProbe=false`
  - `EnableDLSS=false`

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\set-vrising-fsr-mode.ps1 -Mode Off
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage hdrp-postprocess-render-args-render-scale -ArtifactLabel hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\capture-vrising-window.ps1 -ArtifactLabel hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1 -OutputPath artifacts\gameplay-automation\CaptureGameplay-hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1.png -WindowTitlePattern "^VRising$" -Method Auto
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1.json"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Automation Notes

- Computer Use selected the real `VRising` Unity window and clicked the known
  Chinese Continue entry once at `(205,354)`.
- No keyboard, movement, or gameplay keys were sent.
- After loading, Computer Use window capture returned a stale/wrong Codex
  window image even after reacquiring the `VRising` handle. Because the target
  screenshot channel was untrustworthy, no further UI input was sent.
- Player log and process state showed gameplay was reached.
- A passive `capture-vrising-window.ps1` screenshot of the real
  `UnityWndClass` was used as the visual artifact instead:
  `artifacts/gameplay-automation/CaptureGameplay-hdrp-postprocess-render-args-render-scale-gameplay-1080p-20260607-r1.png`.

## Result

Pass, with an important limitation.

- Analyzer: `Stage 2C Render-Scale Control Probe=Pass`
- Analyzer: `HDRP PostProcess Render Args=Pass`
- Snapshots logged: `9`
- Render-scale control prefix/postfix lines: `557`
- Software fallback diagnostics: `32`
- `GetCurrentScale=0.5`: `31`
- `GetResolvedScale=(0.50, 0.50)`: `31`
- `CameraColor_960x540` / `actualWidth=960` evidence count: `9`
- `CameraColor_1920x1080` / `actualWidth=1920` evidence count: `0`
- `CustomPostProcesDestination_960x540`: `9`
- `CustomPostProcesDestination_1920x1080`: `0`
- `RenderGraph GetTexture`: `0`
- D3D11: `0`
- NGX: `0`
- DLSS/evaluate: `0`
- Prefix/patch failures: `0`
- `CrashEventCount=0`
- `RemainingVRisingProcessCount=0`
- Save restore: `ChangeCount=0`

Player log confirmed gameplay:

```text
SetResolution 1920, 1080, fullScreenMode Windowed
Created Camera TopDownCamera
Assigned Camera TopDownCamera to LocalUser
```

## Key Snapshot

The first `DarkForeground.Render(...)` snapshot showed:

- `camera.actualWidth=960`
- `camera.actualHeight=540`
- `camera.camera.pixelWidth=1920`
- `camera.camera.pixelHeight=1080`
- `source.name="CameraColor"`
- `source.referenceSize=(960, 540)`
- `source.rt.name="CameraColor_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic"`
- `source.rt.width=960`
- `source.rt.height=540`
- `destination.name="CustomPostProcesDestination"`
- `destination.referenceSize=(960, 540)`
- `destination.rt.name="CustomPostProcesDestination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic"`
- `destination.rt.width=960`
- `destination.rt.height=540`

## Interpretation

This proves the gameplay-proven ProjectM custom postprocess boundary can see
mod-owned dynamic-resolution render-space resources under V Rising
`FsrQualityMode=Off`. It is a valuable clean-room boundary because it avoids the
previous hot `GetTexture` discovery loop and still exposes the low-resolution
color texture.

It is not yet a full DLSS Super Resolution evaluate tuple. Both source and
destination were `960x540`, not `960x540 -> 1920x1080`. This boundary can
probably supply low-resolution input color, but it does not by itself provide a
full-size output target.

## Next Step

Do not jump directly to DLSS evaluate at this boundary. The next separate guard
should locate a full-size output target reachable from the same frame/lifecycle,
or prove a safe handoff from this scaled custom-postprocess boundary to the
known full-size EASU/output RenderGraph resource path.
