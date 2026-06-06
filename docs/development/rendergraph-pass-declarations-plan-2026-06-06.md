# RenderGraph Pass Declarations Plan - 2026-06-06

## Question

Can the safe `CompileRenderGraph(int)` observation point provide resource-declaration
shape for the focused HDRP passes seen in gameplay without touching actual textures,
`GetTexture`, generated render functions, executor wrappers, or DLSS evaluate?

## Prior Evidence

`rendergraph-pass-list-gameplay-1080p-20260606-r1` proved that a read-only postfix on
`CompileRenderGraph(int)` works in protected `11111` gameplay with `GetTexture`
disabled. It repeatedly observed the focused sequence:

- `Objects Motion Vectors Rendering`
- `Camera Motion Vectors Rendering`
- `Motion Blur`
- `Uber Post`
- `Edge Adaptive Spatial Upsampling`
- `Final Pass`

## Implementation

- Added `Diagnostics.EnableRenderGraphPassResourceDeclarationProbe=false`.
- Added helper stage `rendergraph-pass-declarations`.
- The stage enables native smoke and upscaler state, disables
  `EnableRenderGraphGetTextureProbe`, disables the hook probe, and keeps
  `DLSS.EnableDLSS=false`.
- The probe reuses the safe `CompileRenderGraph(int)` postfix.
- It logs capped `RenderGraph pass declaration #` lines only for focused passes:
  upscaler/postprocess/final/DLSS categories plus motion-vector/temporal AA pass
  names.
- Each declaration line summarizes pass-local `colorBuffers`, `depthBuffer`,
  `resourceReadLists`, and `resourceWriteLists` handle declarations.

## Safety Boundary

This probe is declaration-only:

- Does not call `RenderGraphResourceRegistry.GetTexture(...)`.
- Does not call `GetTextureResource(...)`.
- Does not query RenderGraph resource names.
- Does not resolve native texture pointers.
- Does not inject a RenderGraph pass.
- Does not load or evaluate DLSS.

## Pass/Fail

Pass if a `1920x1080` Windowed smoke logs `RenderGraph pass declaration #` lines for
focused passes without a WER crash and with `0` broad `RenderGraph GetTexture call #`
lines.

Fail if the stage patches but emits no declaration lines, logs
`RenderGraph pass-list logging failed`, crashes, or causes cleanup/config/save
restore failure.

## Runtime Evidence

### `rendergraph-pass-declarations-1080p-menu-20260606-r1`

- Shape: V Rising main-menu smoke, `1920x1080` Windowed.
- Result: completed, `CrashEventCount=0`, closed by script.
- Cleanup: loader config, release-safe native DLL, and `ClientSettings.json`
  restored.
- Game-reported resolution: `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Analyzer: `RenderGraph Pass Declarations=Pass`.
- Log counts: enabled `1`, patched `1`, declaration lines `297`, broad
  `RenderGraph GetTexture call #` lines `0`, failures `0`.
- Focused pass counts: `Uber Post=43`, `Edge Adaptive Spatial Upsampling=48`,
  `Final Pass=43`, motion-vector pass lines `119`.
- Representative declaration flow:
  - motion-vector passes declare depth/color resources around the expected
    prepass outputs.
  - `Uber Post` reads source/postprocess resources and writes the next
    postprocess destination.
  - `Edge Adaptive Spatial Upsampling` reads the `Uber Post` output and writes
    the upsampled output.
  - `Final Pass` reads the EASU output and writes/presents final output state.

### `rendergraph-pass-declarations-gameplay-1080p-20260606-r1`

This run should be treated as startup/window-only evidence, not as protected
gameplay proof.

- Shape: V Rising launched at `1920x1080` Windowed and reached a visible window,
  but Continue was not clicked and gameplay was not entered.
- Stop-session cleanup: `Status=Pass`, `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- Save restore: backup restored with `ChangeCount=0`.
- Analyzer: `RenderGraph Pass Declarations=Pass`.
- Log counts: enabled `1`, patched `1`, declaration lines `399`, broad
  `RenderGraph GetTexture call #` lines `0`, failures `0`.
- Focused pass counts: `Uber Post=48`, `Edge Adaptive Spatial Upsampling=43`,
  `Final Pass=43`, motion-vector pass lines `221`.

The startup/window-only signal strengthens patch-safety confidence but does not
replace the required protected `11111` gameplay declaration proof.

### `rendergraph-pass-declarations-gameplay-1080p-20260606-r2`

- Shape: protected `11111` gameplay proof, `1920x1080` Windowed.
- Save protection: backed up `12` files before launch.
- UI route: Computer Use selected the real `VRising` Unity window, clicked the
  visible Chinese Continue entry exactly once, and sent no movement/gameplay keys.
- Gameplay evidence: Computer Use screenshots showed stable gameplay with
  character, HUD/hotbar, quest text, and minimap. Durable screenshot artifact:
  `artifacts/gameplay-automation/ComputerUseGameplay-rendergraph-pass-declarations-gameplay-1080p-20260606-r2.png`.
- Player log: `SetResolution 1920, 1080, fullScreenMode Windowed`, then local
  connect flow to `SteamIPv4://127.0.0.1:9876`.
- Stop-session cleanup: `Status=Pass`, `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- Save restore: gameplay changed `4` files before restore; the changed state was
  archived and after-restore comparison reported `ChangeCount=0`.
- Analyzer: `RenderGraph Pass Declarations=Pass`.
- Log counts: enabled `1`, patched `1`, declaration lines `529`, broad
  `RenderGraph GetTexture call #` lines `0`, failures `0`, target-missing `0`.
- Focused pass counts: `Uber Post=279`, `Edge Adaptive Spatial Upsampling=48`,
  `Final Pass=45`, motion-vector pass lines `112`.
- Representative declaration chain:
  - `Objects Motion Vectors Rendering` declares color handles around indices
    `20`, `22`, `23`, depth index `21`, and corresponding read/write lists.
  - `Camera Motion Vectors Rendering` reads depth index `21` and writes motion
    vector index `20`.
  - `Uber Post` reads source/postprocess resources and writes index `73` on the
    first compile, then index `78` on the next compile.
  - `Edge Adaptive Spatial Upsampling` reads the `Uber Post` output
    (`73`/`78`) and writes the upsampled output (`74`/`79`).
  - `Final Pass` reads the EASU output (`74`/`79`) and final/UI resources before
    writing the final target.

## Next Step After Runtime Proof

Menu and protected gameplay proof both pass. Do not rerun
`rendergraph-pass-declarations` unchanged. The next implementation loop should
inspect the declaration summaries for the focused upscaler/final sequence and
decide whether there is a safe mapping from declarations to a real current-frame
command-buffer boundary. Do not attempt another DLSS evaluate until that boundary
is grounded by this declaration evidence.
