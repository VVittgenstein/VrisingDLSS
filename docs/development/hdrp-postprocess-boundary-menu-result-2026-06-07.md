# HDRP PostProcess Boundary Menu Result - 2026-06-07

Status: ProjectM-only target set is menu-stable but partial. All-target direct
Harmony patching is rejected unchanged.

## Question

Can the default-off `hdrp-postprocess-boundary` stage safely patch postprocess
boundaries and observe runtime hits at true `1920x1080` Windowed main menu,
without `GetTexture`, native texture access, command-buffer work, or DLSS
evaluate?

## Conditions

- Game path: `C:\Software\VRising`
- Stage: `hdrp-postprocess-boundary`
- Resolution: true `1920x1080`
- Window mode: `Windowed`
- Duration: `75` seconds
- Native bridge: release-safe restored after each run
- DLSS: disabled
- `RenderGraph.GetTexture`: disabled
- `HookProbe`: disabled
- Save: protected `11111` save not entered/touched

## Run r1

Run label:

`hdrp-postprocess-boundary-1080p-menu-20260607-r1`

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage hdrp-postprocess-boundary -ArtifactLabel hdrp-postprocess-boundary-1080p-menu-20260607-r1 -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Artifacts:

- `artifacts/runtime-logs/LogOutput-hdrp-postprocess-boundary-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/Analysis-hdrp-postprocess-boundary-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/Player-hdrp-postprocess-boundary-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/WER-hdrp-postprocess-boundary-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/ClientSettings-hdrp-postprocess-boundary-1080p-menu-20260607-r1.before.json`

Result:

- `CrashEventCount=1`
- `ExitedBeforeWindow=True`
- WER: `coreclr.dll`, exception code `0xc0000005`
- Analyzer: `HDRP PostProcess Boundary=Partial`
- BepInEx log patched all 10 initial targets:
  - `HDRenderPipeline.RenderPostProcess`
  - `HDRenderPipeline.DoDLSSPasses`
  - `HDRenderPipeline.DoDLSSPass`
  - `HDRenderPipeline.CustomPostProcessPass`
  - six ProjectM concrete custom postprocess `Render(...)` overrides
- `HDRP postprocess boundary probe call #` count: `0`
- `RenderGraph GetTexture call #`: `0`
- D3D11/NGX/DLSS/evaluate patterns: `0`
- Cleanup restored loader config, release-safe native DLL, and
  `ClientSettings.json`.

Decision after r1:

The first prefix shape requested Harmony `__instance` and `__args`, which is
risky for IL2CPP HDRP signatures containing value-type/byref parameters such as
`TextureHandle` and `PrepassOutput&`. The prefix was narrowed to
`__originalMethod` only.

## Run r2

Run label:

`hdrp-postprocess-boundary-1080p-menu-20260607-r2`

Result:

- Same command shape and 1080p Windowed conditions as r1.
- `CrashEventCount=1`
- `ExitedBeforeWindow=True`
- WER: `coreclr.dll`, exception code `0xc0000005`
- Analyzer: `HDRP PostProcess Boundary=Partial`
- BepInEx log again patched all 10 initial targets.
- `HDRP postprocess boundary probe call #` count: `0`
- `RenderGraph GetTexture call #`: `0`
- D3D11/NGX/DLSS/evaluate patterns: `0`
- Cleanup restored loader config, release-safe native DLL, and
  `ClientSettings.json`.

Decision after r2:

Reject unchanged all-target direct Harmony patching. The failure persisted even
with a no-args prefix, so at least one direct HDRP pipeline method patch in the
combined target set is unsafe in this runtime. Keep
`HDRenderPipeline.RenderPostProcess -> DoDLSSPasses -> DoDLSSPass` as static
xref/source evidence for now; do not direct-Harmony-patch those methods in the
next normal runtime route.

## Run r3

Run label:

`hdrp-postprocess-boundary-1080p-menu-20260607-r3`

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage hdrp-postprocess-boundary -ArtifactLabel hdrp-postprocess-boundary-1080p-menu-20260607-r3 -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Artifacts:

- `artifacts/runtime-logs/LogOutput-hdrp-postprocess-boundary-1080p-menu-20260607-r3.log`
- `artifacts/runtime-logs/Analysis-hdrp-postprocess-boundary-1080p-menu-20260607-r3.txt`
- `artifacts/runtime-logs/Player-hdrp-postprocess-boundary-1080p-menu-20260607-r3.log`
- `artifacts/runtime-logs/ClientSettings-hdrp-postprocess-boundary-1080p-menu-20260607-r3.before.json`

Result:

- Active target set: ProjectM concrete custom postprocess `Render(...)` only.
- Patched methods: `6`
- `CrashEventCount=0`
- `ExitedBeforeWindow=False`
- `ClosedByScript=True`
- Analyzer: `HDRP PostProcess Boundary=Partial`
- `HDRP postprocess boundary probe call #` count: `0`
- `RenderGraph GetTexture call #`: `0`
- D3D11/NGX/DLSS/evaluate patterns: `0`
- `prefix failed`: `0`
- `failed to patch`: `0`
- Player log reported `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Cleanup restored loader config, release-safe native DLL, and
  `ClientSettings.json`; no V Rising process remained.

Interpretation:

The ProjectM concrete custom postprocess render override target set is safe in
main-menu conditions, but the main menu did not invoke those overrides. This is
a stable partial, not a pass.

## Decision

- Reject all-target direct Harmony patching of HDRP pipeline methods plus
  ProjectM concrete renders as the next normal route.
- Keep the narrowed ProjectM-only `hdrp-postprocess-boundary` stage because it
  is stable and may produce the needed boundary hit in gameplay.
- The next runtime proof should be protected `11111` gameplay at true
  `1920x1080` Windowed, no movement keys, with the ProjectM-only target set.
- Pass signal for gameplay: at least one
  `HDRP postprocess boundary probe call #` from a ProjectM concrete
  `Render(...)` override.
- If gameplay still produces no hit, reject this ProjectM custom postprocess
  render route as a practical evaluate-boundary candidate and return to a
  different official-boundary-adjacent approach.
