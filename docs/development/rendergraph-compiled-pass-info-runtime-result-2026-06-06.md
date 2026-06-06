# RenderGraph Compiled Pass Info Runtime Result - 2026-06-06

Status: menu proof passed at true `1920x1080` Windowed.

## Question

Can the safe `RenderGraph.CompileRenderGraph(int)` postfix read compiled pass
state for focused HDRP postprocess/upscale/final passes without touching the
real RenderGraph execution boundary?

## Fix

The first menu run failed safely because the probe tried to read
`RenderGraph.m_CompiledPassInfos` directly. V Rising's generated Core RP interop
for Unity `2022.3.58f1` exposes the active array as:

`RenderGraph.m_CurrentCompiledGraph.compiledPassInfos`

The probe now reads that chain first, while keeping direct/default compiled
graph fallbacks for source-shape drift. It still does not call
`GetCompiledPassInfos()`, `GetTexture(...)`, render functions, command buffers,
or DLSS evaluate.

## Runtime Protocol

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage rendergraph-compiled-pass-info -ArtifactLabel rendergraph-compiled-pass-info-1080p-menu-20260606-r2 -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Artifacts:

- `artifacts/runtime-logs/LogOutput-rendergraph-compiled-pass-info-1080p-menu-20260606-r2.log`
- `artifacts/runtime-logs/Analysis-rendergraph-compiled-pass-info-1080p-menu-20260606-r2.txt`
- `artifacts/runtime-logs/Player-rendergraph-compiled-pass-info-1080p-menu-20260606-r2.log`
- no WER artifact

## Result

- `CrashEventCount=0`
- `ClosedByScript=True`
- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- `GameReportedWidth=1920`
- `GameReportedHeight=1080`
- `GameReportedFullScreenMode=Windowed`
- analyzer `RenderGraph Compiled Pass Info=Pass`
- `RenderGraph compiled-pass-info #` count: `299`
- `RenderGraph compiled-pass-info compile #` count: `102`
- `compiledPassInfos=not found` count: `0`
- `RenderGraph GetTexture call #` count: `0`
- `compiled-pass-info logging failed` count: `0`
- `Unhandled exception` count: `0`

The compile summaries report:

`source=m_CurrentCompiledGraph.compiledPassInfos; compiledCount=80; enumerated=80; focusCount=6`

Focused menu pass state included:

- `Uber Post`: `culled=False`, `refCount=1`, create total `1`, release total `2`
- `Edge Adaptive Spatial Upsampling`: `culled=False`, `refCount=1`, create total `1`, release total `1`
- `Final Pass`: `culled=False`, `hasSideEffect=True`, `refCount=0`, create total `0`, release total `1`

## Interpretation

This proves a stable read-only compiled-pass snapshot at the already accepted
`CompileRenderGraph(int)` observation point. It strengthens the pass map and
resource-lifetime picture, but it is still not an evaluate boundary:

- no `RenderGraphContext`
- no `CommandBuffer`
- no actual `Texture` resources
- no `GetTexture(...)`
- no render function invocation
- no DLSS evaluate

The official source-backed execution answer is still:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`

V Rising still has no proven safe Harmony-equivalent patch point inside that
window. Do not rerun `rendergraph-compiled-pass-info` unchanged except after a
Unity/V Rising update or probe regression.

## Next Step

Use the compiled-pass-info proof as map evidence. The next technical branch is
not another broad search or another unchanged runtime proof; it is either:

- design a separate `native-renderfunc-entry` no-op method-pointer probe as a new
  risk class, or
- identify a strictly safer pass-owned boundary near EASU/final/DLSS resource
  resolution that does not patch generated render funcs, `DLSSPass.Render`,
  `RenderFunc<T>.Invoke`, or `RenderGraphPass<T>.Execute`.
