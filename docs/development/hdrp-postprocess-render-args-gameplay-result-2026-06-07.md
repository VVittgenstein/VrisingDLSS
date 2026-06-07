# HDRP PostProcess Render Args Gameplay Result - 2026-06-07

Run label:

```text
hdrp-postprocess-render-args-gameplay-1080p-20260607-r1
```

## Question

Can a default-off, no-native probe at the gameplay-proven
`DarkForeground.Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` boundary
snapshot source/destination resource shapes in the protected `11111` gameplay
fixture?

## Hypothesis

The boundary will be reached in gameplay and will expose managed RTHandle and
RenderTexture metadata. The run should not touch `GetTexture`, native texture
pointers, D3D11 validation, NGX, or DLSS evaluate.

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-render-args-gameplay-1080p-20260607-r1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage hdrp-postprocess-render-args -ArtifactLabel hdrp-postprocess-render-args-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-hdrp-postprocess-render-args-gameplay-1080p-20260607-r1.json"
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-hdrp-postprocess-render-args-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-render-args-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Computer Use

- Selected the real `VRising` Unity window, not the BepInEx console.
- Main-menu screenshot dimensions were `1283x751`.
- Clicked the known Chinese Continue / `11111` entry once at `(205,354)`.
- Sent no keyboard, movement, or gameplay keys.
- Waited about `45` seconds for gameplay.
- Observed gameplay with quest text, character, health/action bar, and minimap.
- Saved screenshot evidence:
  `artifacts/gameplay-automation/ComputerUseGameplay-hdrp-postprocess-render-args-gameplay-1080p-20260607-r1.jpg`

## Result

Pass.

- Analyzer: `HDRP PostProcess Render Args=Pass`
- Patched methods: `1`
- Snapshots logged: `9`
- First/hit method:
  `DarkForeground.Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination) -> Void`
- `RenderGraph GetTexture` count: `0`
- D3D11 count: `0`
- NGX count: `0`
- DLSS/evaluate count: `0`
- Prefix failures: `0`
- Patch failures: `0`
- `CrashEventCount=0`
- `RemainingVRisingProcessCount=0`
- `RestoredClientSettings=True`
- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- Save restore: `ChangeCount=0`

Player log confirmed:

```text
SetResolution 1920, 1080, fullScreenMode Windowed
```

## Key Snapshot

The first snapshot showed:

- `camera.name="CameraParent"`
- `camera.actualWidth=1920`
- `camera.actualHeight=1080`
- `camera.camera.allowDynamicResolution=False`
- `source.name="CameraColor"`
- `source.rt.name="CameraColor_1920x1080_B10G11R11_UFloatPack32_Tex2DArray"`
- `source.rt.width=1920`
- `source.rt.height=1080`
- `source.rt.graphicsFormat=B10G11R11_UFloatPack32`
- `destination.name="CustomPostProcesDestination"`
- `destination.rt.name="CustomPostProcesDestination_1920x1080_B10G11R11_UFloatPack32_Tex2DArray_dynamic"`
- `destination.rt.width=1920`
- `destination.rt.height=1080`
- `destination.rt.graphicsFormat=B10G11R11_UFloatPack32`

## Interpretation

This is a good source-driven boundary proof: the existing game postprocess
callback exposes the managed source/destination resources without using the
previous hot `GetTexture` route.

It is not yet a DLSS Super Resolution resource tuple. Under this run's 1080p
Windowed loader/default state, both source and destination were full-size
`1920x1080`, and the camera reported `allowDynamicResolution=False`.

Next work should not jump directly to DLSS evaluate at this boundary. The next
separate guard should prove whether this same boundary can observe the
dynamic-resolution render input state needed for Super Resolution, while still
avoiding native pointer reads and DLSS evaluate.
