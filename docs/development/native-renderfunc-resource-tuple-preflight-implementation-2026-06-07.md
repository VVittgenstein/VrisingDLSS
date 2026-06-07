# Native RenderFunc Resource Tuple Preflight Implementation - 2026-06-07

Status: implemented and statically validated. No game launch in this pass.

## Question

After `native-renderfunc-resource-identity` proved that the raw native EASU
render-func `passDataPtr` matches the managed `EASUData` object in menu and
protected `11111` gameplay, can we add one more default-off dry preflight that
formats that matched pass data into a stable resource tuple metadata record:
input/output dimensions plus `source` / `destination` TextureHandle resource
identity?

## Implementation

Added config key:

`Diagnostics.EnableNativeRenderFuncResourceTupleProbe=false`

Helper stage:

`native-renderfunc-resource-tuple`

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableUpscalerStateProbe=true`
- `EnableHookProbe=false`

Runtime behavior:

- Reuses the proven focused EASU native render-func entry no-op detour.
- Reuses the argument preflight only for raw pointer samples.
- Reuses the resource-identity check to require native `passDataPtr` and managed
  `EASUData` pointer equality.
- Reads managed EASU pass-data fields from `CompileRenderGraph(int)` only:
  `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`, `source`, and
  `destination`.
- Emits `Native render-func resource tuple advanced:` only when:
  - the native callback has sampled at least one argument set;
  - `managedPassData == nativeLastPassData`;
  - input/output dimensions are present;
  - both focused TextureHandle resource identities are present.

Safety boundary:

- No native callback pointer dereference.
- No `RenderGraphResourceRegistry.GetTexture`.
- No texture/native-resource resolution.
- No `CommandBuffer` access.
- No generated render-func Harmony patch.
- No DLSS/NGX evaluate.

## Validation

Static validation commands passed:

```powershell
git diff --check
& C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -Stage native-renderfunc-resource-tuple -OutputPath artifacts\tmp-native-renderfunc-resource-tuple.cfg -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-thunderstore-package.ps1 -PackagePath dist\VrisingDLSS-0.1.0-thunderstore.zip
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath C:\Software\VRising -Stage loader
```

Dry-run config confirmed the intended stage flags:

- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`
- `EnableDLSS=false`
- `LaunchesGame=False`

Thunderstore package validation passed and the packaged default config keeps
`EnableNativeRenderFuncResourceTupleProbe = false`. The local test game config
was also restored to loader-safe defaults with
`EnableNativeRenderFuncResourceTupleProbe=false`, `EnableRenderGraphGetTextureProbe=true`,
`EnableHookProbe=true`, and `EnableDLSS=false`. No V Rising or
UnityCrashHandler process was running after validation.

## Next Runtime Test

Menu-only proof first, at true `1920x1080` Windowed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-tuple -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Pass signal: analyzer reports `Native RenderFunc Resource Tuple=Pass`, log
contains `Native render-func resource tuple advanced:`, tuple output includes
`input=...x...`, `output=...x...`, `source=...`, `destination=...`,
`passDataMatches=True`, and `tupleReady=True`.

Fail signal: startup crash, detour failure, pass-list logging failure,
`Native render-func resource tuple data=not found`, missing dimensions or
TextureHandle identities, any `GetTexture` steady-state discovery, or any
DLSS/NGX evaluate/probe pattern.

Cleanup after any runtime proof: close V Rising, restore loader-safe config,
confirm release-safe native DLL state, confirm no V Rising/UnityCrashHandler
process remains, and preserve logs/analysis before moving to protected gameplay.
