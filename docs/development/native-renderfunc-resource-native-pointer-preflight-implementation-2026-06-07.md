# Native RenderFunc Resource Native-Pointer Preflight Implementation - 2026-06-07

Status: implemented, statically validated, and menu/protected-gameplay
validated.

## Question

After `native-renderfunc-resource-resolve` proved that the focused EASU
`source` / `destination` handles resolve to `TextureResource` metadata while
`graphicsResource` remains null at the `CompileRenderGraph(int)` observation
point, can we add one more default-off preflight that asks only whether those
same handles ever receive actual native texture pointers during Unity-owned
`GetTexture(TextureHandle&)` calls?

## Implementation

Added config key:

`Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe=false`

Helper stage:

`native-renderfunc-resource-native-pointer`

The stage enables:

- `EnableNativeBridgeSmokeTest=true`
- `EnableNativeRenderFuncEntryProbe=true`
- `EnableNativeRenderFuncArgumentProbe=true`
- `EnableNativeRenderFuncResourceIdentityProbe=true`
- `EnableNativeRenderFuncResourceTupleProbe=true`
- `EnableNativeRenderFuncResourceNativePointerProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableUpscalerStateProbe=true`
- `EnableHookProbe=false`
- `EnableDLSS=false`

Runtime behavior:

- Reuses the proven focused EASU native render-func entry no-op detour.
- Requires the same native `passDataPtr == managed EASUData` match as the prior
  identity/tuple/resolve proofs.
- Arms a target from the matched EASU `source` and `destination`
  `TextureHandle.handle` summaries during the safe `CompileRenderGraph(int)`
  pass-list snapshot.
- Patches `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` only because
  this preflight needs to observe Unity-owned valid-scope conversions.
- In the `GetTexture` postfix, returns immediately unless the observed handle
  matches the armed EASU `source` or `destination`.
- Reads `GetNativeTexturePtr()` only from the already-returned `__result`.
- Logs `Native render-func resource native-pointer advanced:` only after both
  `source` and `destination` return non-zero native texture pointers.
- Fast-skips after the first dual-pointer proof.

Safety boundary:

- No direct or prefix-time `GetTexture(...)` calls.
- No generated HDRP render-func Harmony patch.
- No `DLSSPass.Render(...)` patch.
- No `RenderGraph.PreRenderPassExecute(...)` / `ExecuteCompiledPass(...)`
  wrapper patch.
- No broad GetTexture resource-name candidate path.
- No `D3D11TextureProbe` / native bridge texture validation.
- No command-buffer access.
- No NGX/DLSS evaluate.

## Expected Runtime Interpretation

Pass:

- Analyzer reports `Native RenderFunc Resource Native Pointer=Pass`.
- Log contains `Native render-func resource native-pointer advanced:`.
- The advanced line shows both `source` and `destination` with non-zero
  `nativePtr=0x...`.
- There are no `RenderGraph GetTexture call #`, D3D11 probe, `ExecuteDLSS`, or
  NGX/evaluate lines.

Blocked or partial:

- `target armed` appears but no `advanced` line: the EASU tuple is known, but
  Unity did not later call `GetTexture(...)` for either or both handles during
  the diagnostic window.
- `status` lines report `result=null` or `nativePtr=not found`: the handle was
  observed, but the returned object did not expose a native pointer at this
  stage.

Even a pass is not a production evaluate boundary. It only proves actual native
texture-pointer availability during engine-owned resource conversion. Any
command-buffer or DLSS evaluate step still needs a separate default-off preflight
with its own hypothesis and cleanup plan.

## Next Runtime Test

Menu-only proof at true `1920x1080` Windowed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-native-pointer -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Menu proof has now passed; see
`docs/development/native-renderfunc-resource-native-pointer-runtime-result-2026-06-07.md`.
Protected `11111` gameplay proof has now passed; see
`docs/development/native-renderfunc-resource-native-pointer-gameplay-result-2026-06-07.md`.
Protected `11111` gameplay proof combined with mod-owned render scale has now
also passed; see
`docs/development/native-renderfunc-resource-native-pointer-render-scale-gameplay-result-2026-06-07.md`.
Do not add command-buffer access, D3D11 validation, or DLSS evaluate to this
stage.

## Validation

Local validation completed without launching V Rising:

- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
  passed with `0` warnings and `0` errors.
- PowerShell parser validation passed for the changed helper/readiness/package
  scripts.
- `git diff --check` passed.
- `scripts\write-diagnostic-config.ps1 -Stage native-renderfunc-resource-native-pointer -DryRun`
  reported `LaunchesGame : False` and produced the expected safe config:
  `EnableNativeRenderFuncResourceNativePointerProbe=true`,
  `EnableRenderGraphGetTextureProbe=false`, `EnableHookProbe=false`, and
  `EnableDLSS=false`.
- `scripts\package-thunderstore.ps1` passed release-boundary and Thunderstore
  validation and recreated `dist\VrisingDLSS-0.1.0-thunderstore.zip`.
- `scripts\validate-thunderstore-package.ps1 -PackagePath dist\VrisingDLSS-0.1.0-thunderstore.zip`
  passed, including the packaged default
  `EnableNativeRenderFuncResourceNativePointerProbe = false`.

Runtime validation:

- The first menu proof,
  `native-renderfunc-resource-native-pointer-20260607-142048`, was stable but
  partial: it armed the EASU target but did not install GetTexture postfix
  because the patch request still lived under `DlssEvaluateInputProbeEnabled`.
- A narrow install-condition fix moved native-pointer GetTexture postfix
  installation outside that branch while preserving
  `EnableRenderGraphGetTextureProbe=false`.
- The second menu proof,
  `native-renderfunc-resource-native-pointer-20260607-142357`, passed at true
  `1920x1080` Windowed with `CrashEventCount=0`,
  `Frame resource RenderGraph GetTexture postfix patched:`, and
  `Native render-func resource native-pointer advanced:` showing non-zero
  source/destination native pointers.
- The protected `11111` gameplay proof,
  `native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1`,
  also passed at true `1920x1080` Windowed. Computer Use clicked the known
  Continue / `11111` entry once, sent no movement/gameplay keys, observed
  gameplay, analyzer reported `Native RenderFunc Resource Native Pointer=Pass`,
  cleanup restored config/native/settings, and save restore ended with
  `ChangeCount=0`.
- The combined protected `11111` gameplay proof,
  `native-renderfunc-resource-native-pointer-render-scale-gameplay-1080p-20260607-r1`,
  passed with V Rising `FsrQualityMode=Off` and mod-owned render scale. The
  advanced line showed EASU `tuple=input=960x540; output=1920x1080`, non-zero
  source pointer `0x21EA3F0B420` for `Uber Post Destination` /
  `Apply Exposure Destination_960x540...`, and non-zero destination pointer
  `0x21EA3F111A0` for `Edge Adaptive Spatial Upsampling_1920x1080...`.
  Cleanup restored config/native/settings and the protected save to
  `ChangeCount=0`.
