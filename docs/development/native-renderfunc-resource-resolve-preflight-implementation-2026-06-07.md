# Native RenderFunc Resource Resolve Preflight Implementation - 2026-06-07

Status: implemented and statically validated. No game launch in this pass.

## Question

After `native-renderfunc-resource-tuple` proved menu and protected `11111`
gameplay tuple metadata at the focused native EASU render-func boundary, can we
add one more default-off preflight that uses that proven tuple as a locator and
asks RenderGraph's registry for the matching `source` / `destination`
`TextureResource` metadata?

## Implementation

Added config key:

`Diagnostics.EnableNativeRenderFuncResourceResolveProbe=false`

Helper stage:

`native-renderfunc-resource-resolve`

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceResolveProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableUpscalerStateProbe=true`
- `EnableHookProbe=false`
- `EnableDLSS=false`

Runtime behavior:

- Reuses the proven focused EASU native render-func entry no-op detour.
- Requires the same native `passDataPtr == managed EASUData` match as the
  resource-identity and tuple proofs.
- Reads `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`, `source`,
  and `destination` directly from the matched managed `EASUData`.
- Resolves only `source` and `destination` through
  `RenderGraphResourceRegistry.GetTextureResource(ResourceHandle&)`.
- Logs whether each handle returned a `TextureResource` and whether its
  `graphicsResource` field/property was non-null.
- Emits `Native render-func resource resolve advanced:` only when both handles
  return a `TextureResource`.

Safety boundary:

- No native callback pointer dereference.
- No `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` call or global
  `GetTexture` postfix.
- No native texture pointer reads.
- No D3D11 probe/native bridge texture validation.
- No `CommandBuffer` access.
- No generated render-func Harmony patch.
- No DLSS/NGX evaluate.

## Narrow Source/Search Evidence

Local/upstream source remains the primary evidence:

- Local Unity Graphics 2022.3:
  `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.high-definition\Runtime\RenderPipeline\HDRenderPipeline.PostProcess.cs`
- Local Unity Graphics 2022.3:
  `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.high-definition\Runtime\RenderPipeline\RenderPass\DLSSPass.cs`
- Local Unity Graphics 2022.3:
  `ref\UnityGraphics-2022.3\Packages\com.unity.render-pipelines.core\Runtime\RenderGraph\RenderGraphResourceRegistry.cs`

Findings:

- Official HDRP DLSS is scheduled by
  `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass`.
- `DoDLSSPass` records a RenderGraph pass named
  `Deep Learning Super Sampling`, declares source/output/depth/motion-vector
  handles, writes the output via
  `GetPostprocessUpsampledOutputHandle(..., "DLSS destination")`, and submits
  inside `builder.SetRenderFunc(...)` through
  `DLSSPass.GetCameraResources(...) -> DLSSPass.Render(..., ctx.cmd)`.
- Unity RenderGraph docs say handle-to-actual-resource conversion is valid inside
  the rendering function and can throw outside that scope because the graph may
  not have allocated the resource yet.
- `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` calls
  `GetTextureResource(ResourceHandle&)`, then reads `graphicsResource` and throws
  if the resource is not created/imported. This is why this preflight only asks
  for `TextureResource` metadata and records whether `graphicsResource` is null.
- `CreateTextureCallback(...)` is tied to pooled resource creation/clear work,
  not to the DLSS evaluate boundary; prior local materialization-only gameplay
  already failed to produce a useful steady-state tuple boundary.
- OptiScaler's own README describes a middleware model that intercepts existing
  upscaler calls and redirects inputs to another backend. Its config has resource
  tagging switches for depth/velocity/HUDless inputs, but that model assumes an
  existing upscaler API call path. It does not expose a Unity HDRP RenderGraph
  pass boundary we can safely patch from BepInEx/Harmony.

Useful web references checked in this narrow refresh:

- Unity Graphics 2022.3 `HDRenderPipeline.PostProcess.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
- Unity Graphics 2022.3 `DLSSPass.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
- Unity Graphics 2022.3 `RenderGraphResourceRegistry.cs`:
  `https://github.com/Unity-Technologies/Graphics/blob/2022.3/staging/Packages/com.unity.render-pipelines.core/Runtime/RenderGraph/RenderGraphResourceRegistry.cs`
- Unity RenderGraph writing guide:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4011.0/manual/render-graph-writing-a-render-pipeline.html`
- OptiScaler README/config:
  `https://github.com/optiscaler/OptiScaler`
  `https://github.com/optiscaler/OptiScaler/blob/master/OptiScaler.ini`

Current boundary conclusion:

The official boundary is still
`DoDLSSPass -> Deep Learning Super Sampling render func ->
DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`. V Rising has no
proven safe Harmony-equivalent of that exact render-func/command-buffer boundary
yet. The next safe BepInEx-adjacent step is therefore this metadata-only
`TextureResource` resolve preflight from the already-proven EASU pass-data/native
entry identity boundary, not a generated render-func patch and not a direct
`GetTexture(...)` call.

## Validation

Static validation commands passed:

```powershell
& C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
git diff --check
```

PowerShell parser validation passed for:

- `scripts\write-diagnostic-config.ps1`
- `scripts\run-vrising-diagnostic.ps1`
- `scripts\start-vrising-automation-session.ps1`
- `scripts\analyze-bepinex-log.ps1`
- `scripts\get-runtime-validation-status.ps1`
- `scripts\get-release-readiness-status.ps1`
- `scripts\get-visual-validation-status.ps1`
- `scripts\validate-thunderstore-package.ps1`

Dry config validation wrote
`artifacts\tmp-native-renderfunc-resource-resolve.cfg` without launching the
game. It confirmed:

- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceResolveProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`
- `EnableDLSS=false`
- `LaunchesGame=False`

Package and release-boundary validation passed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-thunderstore-package.ps1 -PackagePath dist\VrisingDLSS-0.1.0-thunderstore.zip
```

The package default config keeps
`Diagnostics.EnableNativeRenderFuncResourceResolveProbe=false`.

The local V Rising config was restored to loader-safe state with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\Software\VRising" -Stage loader
```

## Next Runtime Test

Menu-only proof first, at true `1920x1080` Windowed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-resolve -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Pass signal: analyzer reports `Native RenderFunc Resource Resolve=Pass`, log
contains `Native render-func resource resolve advanced:`, tuple output includes
`passDataMatches=True`, `tupleReady=True`, and both `source` / `destination`
report `textureResourceReady=True`.

Important interpretation: `graphicsResourceReady=False` would be a valid
diagnostic finding, not an implementation failure by itself. This stage proves
only RenderGraph `TextureResource` metadata resolution, not actual native
texture-pointer availability.

Fail signal: startup crash, detour failure, pass-list logging failure,
`Native render-func resource resolve data=not found`, missing tuple fields,
missing `TextureResource` for either focused handle, any `RenderGraph GetTexture
call #`, any native texture pointer/D3D11 probe line, or any DLSS/NGX
evaluate/probe pattern.

Cleanup after any runtime proof: close V Rising, restore loader-safe config,
confirm release-safe native DLL state, confirm no V Rising/UnityCrashHandler
process remains, and preserve logs/analysis before moving to protected gameplay.
