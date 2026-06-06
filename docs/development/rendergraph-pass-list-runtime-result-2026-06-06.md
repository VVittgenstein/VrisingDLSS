# RenderGraph Pass-List Runtime Result - 2026-06-06

## Question

Can a default-off Harmony postfix on
`UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraph.CompileRenderGraph(int)`
observe HDRP RenderGraph pass names from `m_RenderPasses` without touching
textures, `GetTexture`, generated render functions, executor wrappers, or DLSS
evaluate?

## Hypothesis

`CompileRenderGraph(int)` runs after normal RenderGraph pass recording and before
`ClearRenderPasses()`, so a postfix should be able to snapshot pass names/categories
from `m_RenderPasses` with lower crash risk than `PreRenderPassExecute(...)` and
better signal than `OnPassAdded(RenderGraphPass)`.

## Implementation

- Added `Diagnostics.EnableRenderGraphPassListProbe=false`.
- Added helper stage `rendergraph-pass-list`.
- The stage enables native smoke and upscaler state, disables
  `EnableRenderGraphGetTextureProbe`, disables the hook probe, and leaves
  `DLSS.EnableDLSS=false`.
- The probe patches only `CompileRenderGraph(int)`.
- The postfix logs capped `RenderGraph pass-list compile #` summaries and
  `RenderGraph pass-list entry #` pass-name/type/category lines.
- It does not resolve textures, call `GetTexture`, inject a pass, load DLSS, or
  evaluate a frame.

## Runtime Runs

### `rendergraph-pass-list-1080p-menu-20260606-r1`

- Shape: V Rising main-menu smoke, `1920x1080` Windowed.
- Result: completed, `CrashEventCount=0`, closed by script.
- Cleanup: loader config, release-safe native DLL, and `ClientSettings.json` restored.
- Game-reported resolution: `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Analyzer: `RenderGraph Pass List=Pass`.
- Log counts: enabled `1`, patched `1`, compile lines `4809`, entry lines `378`,
  failures `0`.
- Category counts: upscale `16`, postprocess `19`, final `35`, dlss `0`,
  temporal `86`.
- Key pass order observed: `Uber Post`, `Edge Adaptive Spatial Upsampling`,
  `Final Pass`, plus motion-vector passes.
- Follow-up change: summary logging was capped more tightly because the first run
  logged one compile summary for nearly every frame.

### `rendergraph-pass-list-1080p-menu-20260606-r2`

- Shape: V Rising main-menu smoke, `1920x1080` Windowed.
- Result: completed, `CrashEventCount=0`, closed by script.
- Cleanup: loader config, release-safe native DLL, and `ClientSettings.json` restored.
- Game-reported resolution: `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Analyzer: `RenderGraph Pass List=Pass`.
- Log counts after capped summary logging: enabled `1`, patched `1`, compile lines
  `90`, entry lines `357`, failures `0`, target-missing `0`.
- Category counts: upscale `16`, postprocess `19`, final `28`, dlss `0`,
  temporal `72`.
- Key pass order observed repeatedly:
  - `Objects Motion Vectors Rendering`
  - `Camera Motion Vectors Rendering`
  - `Uber Post`
  - `Edge Adaptive Spatial Upsampling`
  - `Final Pass`

## Interpretation

`CompileRenderGraph(int)` is a useful read-only pass-list observation boundary in
the main menu. It is safer and more informative than the rejected
`PreRenderPassExecute(...)` route and the safe-but-silent `OnPassAdded(...)` route.
It is not an evaluate boundary by itself: it does not provide live command-buffer
ordering or resolved textures. It does, however, identify the existing HDRP
postprocess/upscale/final pass names and their compile-time order without entering
the known hot `GetTexture` path.

The absence of `category=dlss` is expected for this diagnostic shape because the
game is not running Unity HDRP's built-in DLSS stack. The observed EASU/final
sequence is still useful because it maps the upscaler-equivalent stage V Rising
already uses.

## Next Step

Run `rendergraph-pass-list` once in the protected `11111` gameplay fixture using
the standard save backup/restore flow. If gameplay confirms the same focused pass
sequence without crashes, the next implementation candidate is a default-off,
resource-declaration-only snapshot for the focused compile-time passes, still with
`GetTexture` disabled and no DLSS evaluate.
