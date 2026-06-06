# RenderGraph Compiled Pass Info Plan - 2026-06-06

Status: implemented, build-validated, and menu runtime-validated.

## Question

Can the already proven `RenderGraph.CompileRenderGraph(int)` observation point
also expose compiled pass state for the focused HDRP upscaler/final pass chain?

This is a map-refinement step only. It is not a DLSS evaluate boundary.

## Hypothesis

The safe compile-time postfix can read compiled pass info after Unity has
compiled/cull/scheduled the graph and before `ClearRenderPasses()`.
For the focused gameplay chain, this should reveal whether `Uber Post`,
`Edge Adaptive Spatial Upsampling`, and `Final Pass` are culled, their refCount
and async/sync state, and the shape of resource create/release lists.

Useful proof would be:

- focused `RenderGraph compiled-pass-info #` lines for `Uber Post`, EASU, and
  `Final Pass`;
- no `RenderGraph pass-list logging failed`;
- no broad `RenderGraph GetTexture call #` lines;
- no WER crash.

## Implementation

Added default-off config:

`Diagnostics.EnableRenderGraphCompiledPassInfoProbe=false`.

Added helper stage:

`rendergraph-compiled-pass-info`.

The stage:

- patches only `RenderGraph.CompileRenderGraph(int)`;
- reads `m_RenderPasses` and
  `m_CurrentCompiledGraph.compiledPassInfos`, with direct/default graph
  fallbacks;
- handles Unity `DynamicArray<T>` by reading `size` and enumerating `m_Array`;
- logs only focused compiled pass info:
  - pass name/category;
  - compiled index and pass index;
  - `culled`, `culledByRendererList`, `hasSideEffect`, `allowPassCulling`;
  - `enableAsyncCompute`, `syncToPassIndex`, `syncFromPassIndex`,
    `needGraphicsFence`;
  - `resourceCreateList` / `resourceReleaseList` group and item counts.

It does not resolve textures, does not call `GetTexture`, does not inspect
native pointers, does not touch command buffers, does not call render functions,
and does not evaluate DLSS.

## First Runtime Result

Menu proof `rendergraph-compiled-pass-info-1080p-menu-20260606-r2` passed after
fixing the interop source chain from direct `m_CompiledPassInfos` to
`m_CurrentCompiledGraph.compiledPassInfos`.

Result summary:

- true `1920x1080` Windowed;
- `CrashEventCount=0`;
- analyzer `RenderGraph Compiled Pass Info=Pass`;
- `299` focused `RenderGraph compiled-pass-info #` lines;
- first compile summary:
  `source=m_CurrentCompiledGraph.compiledPassInfos; compiledCount=80; enumerated=80; focusCount=6`;
- focused `Uber Post`, `Edge Adaptive Spatial Upsampling`, and `Final Pass`
  entries were all `culled=False`;
- `RenderGraph GetTexture call #=0`;
- `compiledPassInfos=not found=0`;
- loader config, release-safe native DLL, and `ClientSettings.json` restored.

Artifacts are recorded in
`docs/development/rendergraph-compiled-pass-info-runtime-result-2026-06-06.md`.

## First Runtime Protocol

Menu smoke first:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage rendergraph-compiled-pass-info -ArtifactLabel rendergraph-compiled-pass-info-1080p-menu-YYYYMMDD-r1 -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Pass criteria:

- true `1920x1080` Windowed;
- analyzer `RenderGraph Compiled Pass Info=Pass`;
- focused compiled-pass-info lines for EASU/final or other current menu
  postprocess/upscale/final candidates;
- `RenderGraph GetTexture call #=0`;
- `CrashEventCount=0`;
- loader config and ClientSettings restored.

If the menu smoke passes and the signal answers a real question, a protected
`11111` gameplay proof may follow. Before gameplay, back up the protected save.
Use Computer Use only to click Continue; do not send movement/gameplay keys.
After cleanup, restore the save and require `ChangeCount=0`.

## Rejected Non-Goals

This stage must not become:

- an evaluate boundary;
- a ref-`CompiledPassInfo` execution-wrapper patch;
- a generated render-func patch;
- a native method-pointer detour;
- a replacement for the accepted diagnostic `GetTexture` tuple oracle.

If the next goal is actual execution-boundary proof, design a separate
`native-renderfunc-entry` no-op method-pointer probe first.
