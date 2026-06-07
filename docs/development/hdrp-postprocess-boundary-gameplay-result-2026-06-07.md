# HDRP PostProcess Boundary Gameplay Result - 2026-06-07

Status: pass. Protected `11111` gameplay proved the ProjectM-only
`hdrp-postprocess-boundary` stage reaches an existing HDRP custom postprocess
render boundary without native/DLSS/resource work.

## Question

Can the ProjectM-only `hdrp-postprocess-boundary` probe observe a concrete
custom postprocess `Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` call in
true `1920x1080` Windowed gameplay, while avoiding `GetTexture`, D3D11 native
pointer access, NGX, DLSS evaluate, and command-buffer work?

## Conditions

- Game path: `C:\Software\VRising`
- Stage: `hdrp-postprocess-boundary`
- Resolution: true `1920x1080`
- Window mode: `Windowed`
- Gameplay fixture: protected local/private `11111` save
- UI automation: Computer Use selected the real `VRising` Unity window, clicked
  Continue / `11111` once at `(205,354)`, and sent no keyboard or movement
  input
- Native bridge: release-safe build, not used by the stage
- DLSS: disabled
- `RenderGraph.GetTexture`: disabled
- D3D11/native pointer probing: disabled

## Commands

Save backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Backup -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-boundary-gameplay-1080p-20260607-r1
```

Start session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage hdrp-postprocess-boundary -ArtifactLabel hdrp-postprocess-boundary-gameplay-1080p-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Cleanup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-vrising-automation-session.ps1 -SessionPath "Z:\VrisingDLSS\artifacts\gameplay-automation\Session-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.json"
```

Save restore:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\protect-vrising-save.ps1 -Mode Restore -SaveDir "C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b" -ReferenceDir "Z:\VrisingDLSS\artifacts\gameplay-automation\SaveBackupDir-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1\f0e07524-03f4-4ef4-945c-b1f7e982071b" -Label hdrp-postprocess-boundary-gameplay-1080p-20260607-r1 -ArchiveCurrent
```

## Artifacts

- `artifacts/gameplay-automation/Session-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/ComputerUseGameplay-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.jpg`
- `artifacts/gameplay-automation/ComputerUseGameplay-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/LogOutput-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Analysis-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.txt`
- `artifacts/gameplay-automation/Player-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.log`
- `artifacts/gameplay-automation/Cleanup-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-hdrp-postprocess-boundary-gameplay-1080p-20260607-r1.json`

## Result

Analyzer:

- `HDRP PostProcess Boundary=Pass`

Counts:

- `HDRP postprocess boundary probe patched:` `6`
- `HDRP postprocess boundary probe call #` log lines: `29`
- highest sampled call number: `6300`
- hit method: `DarkForeground.Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination) -> Void`
- `RenderGraph GetTexture call #`: `0`
- `D3D11 texture pointer probe`: `0`
- `NGX`: `0`
- `DLSS evaluate`: `0`
- `ExecuteDLSS`: `0`
- `evaluate succeeded`: `0`
- `evaluate failed`: `0`
- `prefix failed`: `0`
- `failed to patch`: `0`
- `Exception`: `0`
- `Error`: `0`

Cleanup:

- `CrashEventCount=0`
- `RemainingVRisingProcessCount=0`
- `RestoredClientSettings=True`
- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- Before save restore, gameplay entry added `AutoSave_24.save.gz`
  (`BeforeChangeCount=1`).
- The changed save state was archived and the protected `11111` save was
  restored with `ChangeCount=0`.

Player log evidence:

- Unity version: `2022.3.58f1`
- Command line included `-windowed -screen-width 1920 -screen-height 1080
  -screen-fullscreen 0 -force-d3d11`
- Player log reported `SetResolution 1920, 1080, fullScreenMode Windowed`
- Local server connection reached gameplay after Continue / `11111`.

## Interpretation

This run proves the local IL2CPP/xref conclusion was useful: at least one
existing ProjectM HDRP custom postprocess render override is a stable and
reachable gameplay boundary. The concrete hit was `DarkForeground.Render(...)`.

This does not prove DLSS, visible write-back, or the official HDRP DLSS pass. It
proves a BepInEx/Harmony-accessible command-buffer boundary adjacent to HDRP
postprocessing, with source/destination `RTHandle` arguments available at the
signature level.

## Decision

- Promote `DarkForeground.Render(...)` from "static candidate" to "gameplay
  proven boundary".
- Keep direct Harmony patching of `HDRenderPipeline.RenderPostProcess`,
  `DoDLSSPasses`, `DoDLSSPass`, and `CustomPostProcessPass` rejected unchanged
  because the all-target route crashed in `coreclr.dll`.
- Do not return to broad steady-state `RenderGraph.GetTexture` discovery as a
  production path.
- The next safe step should be a separate default-off no-native resource-argument
  snapshot for `DarkForeground.Render(...)`: log only `cmd`, `camera`,
  `source`, and `destination` identity/shape first, still with no native pointer
  dereference and no DLSS evaluate.
