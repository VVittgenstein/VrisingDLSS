# RenderGraph RenderFunc Metadata Result - 2026-06-06

Status: menu proof passed. This is read-only metadata evidence, not an
execution-layer hook, not a generated render-function patch, and not a DLSS
evaluate boundary.

## Question

After `rendergraph-execute-delegate` patched safely but emitted no callback
lines, can the already-proven `CompileRenderGraph(int)` observation point read
focused pass `renderFunc` delegate metadata without calling or patching render
functions, resolving textures, touching command buffers, or evaluating DLSS?

## Implementation

Added default-off config and helper stage:

- Config key:
  `Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe=false`.
- Helper stage:
  `rendergraph-renderfunc-metadata`.
- Analyzer stage:
  `RenderGraph RenderFunc Metadata`.
- Package default:
  disabled in `package/thunderstore/VrisingDLSS.cfg`.

The probe reuses the safe `CompileRenderGraph(int)` postfix and only reads
focused pass `renderFunc` delegate metadata for:

- `Uber Post`.
- `Edge Adaptive Spatial Upsampling`.
- `Final Pass`.
- `Deep Learning Super Sampling` / `DLSS`, if present.

It does not call the delegate, patch the delegate target, patch generated render
functions, receive `RenderGraphContext`, resolve RenderGraph resources, call
`GetTexture`, touch native texture pointers, touch command buffers, or evaluate
DLSS.

## Commands

Build:

```powershell
C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
```

Dry-run config:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -OutputPath artifacts\tmp-rendergraph-renderfunc-metadata.cfg -Stage rendergraph-renderfunc-metadata -DryRun
```

Menu proof:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage rendergraph-renderfunc-metadata -ArtifactLabel rendergraph-renderfunc-metadata-1080p-menu-20260606-r3 -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

## Artifacts

- BepInEx log:
  `artifacts/runtime-logs/LogOutput-rendergraph-renderfunc-metadata-1080p-menu-20260606-r3.log`
- Analyzer:
  `artifacts/runtime-logs/Analysis-rendergraph-renderfunc-metadata-1080p-menu-20260606-r3.txt`
- Player log:
  `artifacts/runtime-logs/Player-rendergraph-renderfunc-metadata-1080p-menu-20260606-r3.log`
- ClientSettings backup:
  `artifacts/runtime-logs/ClientSettings-rendergraph-renderfunc-metadata-1080p-menu-20260606-r3.before.json`

Earlier attempts:

- `r1` produced no metadata lines because the new flag was missing from the
  `RenderGraphPassListPostfix` early-return guard. That was an implementation
  bug, not runtime evidence.
- `r2` passed and produced metadata lines, but the delegate `MethodInfo` summary
  did not yet include method names.
- `r3` is the accepted menu proof.

## Result

Run summary:

- `CrashEventCount=0`.
- `ExitedBeforeWindow=False`.
- `ClosedByScript=True`.
- `RestoredLoaderConfig=True`.
- `RestoredClientSettings=True`.
- `GameReportedWidth=1920`.
- `GameReportedHeight=1080`.
- `GameReportedFullScreenMode=Windowed`.

Analyzer summary:

- `Stage 4 Native Bridge=Pass`.
- `Stage 2B Upscaler State Probe=Pass`.
- `RenderGraph RenderFunc Metadata=Pass`.

Focused log counts:

- `RenderGraph pass render-func metadata #`: `248`.
- `RenderGraph pass render-func metadata renderFunc=not found`: `0`.
- metadata typed-read/logging failures: `0`.
- `RenderGraph GetTexture call #`: `0`.
- lines with readable `Name=`: `492`.

Unique focused methods:

| Pass | Method | Metadata token | Count |
| --- | --- | --- | --- |
| `Uber Post` | `<UberPass>b__1060_0` | `100664386` | `99` |
| `Edge Adaptive Spatial Upsampling` | `<EdgeAdaptiveSpatialUpsampling>b__1066_0` | `100664389` | `75` |
| `Final Pass` | `<FinalPass>b__1069_0` | `100664390` | `74` |

The repeated delegate metadata had stable `method_ptr`, `invoke_impl`, and
method-token identity during the menu run.

## Decision

Accept `rendergraph-renderfunc-metadata` as a proven menu-safe read-only metadata
probe in this local V Rising build.

This does not prove an execution-time hook and does not make generated
render-function patching safe. It does give a source-backed and runtime-backed
map from focused RenderGraph pass names and pass-data types to their generated
render function methods without invoking those methods.

Next action: run a protected `11111` gameplay proof for
`rendergraph-renderfunc-metadata` before relying on these method identities for a
later boundary decision. The gameplay proof must keep `GetTexture=0`, send no
movement keys, restore the save to `ChangeCount=0`, and treat any WER/coreclr/
IL2CPP crash as route failure. Do not patch generated render functions or
evaluate DLSS from this evidence alone.
