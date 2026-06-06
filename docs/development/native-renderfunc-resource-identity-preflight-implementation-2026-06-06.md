# Native RenderFunc Resource Identity Preflight Implementation - 2026-06-06

Status: implemented and statically validated. No game launch in this pass.

## Question

After the `native-renderfunc-args` menu and protected `11111` gameplay proofs,
can we add one more default-off preflight that correlates the raw native
RenderGraph render-func `passDataPtr` with the managed EASU pass data observed
from `CompileRenderGraph(int)`, without dereferencing native callback pointers,
resolving textures, touching command buffers, or evaluating DLSS?

## Implementation

Added a new diagnostic config key:

`Diagnostics.EnableNativeRenderFuncResourceIdentityProbe=false`

Helper stage:

`native-renderfunc-resource-identity`

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableUpscalerStateProbe=true`
- `EnableHookProbe=false`

Runtime behavior:

- Reuses the already proven focused EASU native render-func entry no-op detour.
- Samples only raw callback argument pointer values via the existing argument
  preflight counters.
- Reads managed EASU pass data from the safe `CompileRenderGraph(int)` snapshot,
  not from the native callback.
- Compares the managed IL2CPP object pointer with the latest raw
  `passDataPtr`.
- Confirms focused `source` and `destination` TextureHandle identity from the
  managed EASU pass data snapshot.
- Logs `Native render-func resource identity advanced:` only when the native raw
  `passDataPtr` matches the managed EASU pass-data object and focused texture
  identity is present.

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
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -Stage native-renderfunc-resource-identity -OutputPath artifacts\tmp-native-renderfunc-resource-identity.cfg -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1
```

Observed dry-run config had `EnableNativeRenderFuncResourceIdentityProbe=true`,
`EnableNativeRenderFuncArgumentProbe=true`,
`EnableNativeRenderFuncEntryProbe=true`, `EnableRenderGraphGetTextureProbe=false`,
`EnableHookProbe=false`, `EnableDLSS=false`, and `LaunchesGame=False`.

`scripts\package-thunderstore.ps1` reported release boundary check pass and
Thunderstore package validation pass for
`dist\VrisingDLSS-0.1.0-thunderstore.zip`.

The packaged default config keeps
`EnableNativeRenderFuncResourceIdentityProbe = false`.

No V Rising or Unity crash-handler process was running after validation.

## Next Runtime Test

Menu-only proof first, at true `1920x1080` Windowed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-identity -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Pass signal: analyzer reports `Native RenderFunc Resource Identity=Pass`, log
contains `Native render-func resource identity advanced:`, `GetTexture` remains
unused, no crash event is recorded, and no DLSS/NGX evaluate/probe call pattern
appears.

Fail signal: startup crash, detour failure, pass-list logging failure,
`Native render-func resource identity data=not found`, any `GetTexture`
steady-state discovery, or any DLSS/NGX evaluate/probe pattern.

Cleanup after any runtime proof: close V Rising, restore loader-safe config,
confirm release-safe native DLL state, confirm no V Rising/UnityCrashHandler
process remains, and preserve logs/analysis before moving to protected gameplay.
