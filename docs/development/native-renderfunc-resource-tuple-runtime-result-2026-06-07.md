# Native RenderFunc Resource Tuple Runtime Result - 2026-06-07

Status: menu-only runtime proof passed. Protected gameplay proof also passed
later; see
`docs/development/native-renderfunc-resource-tuple-gameplay-result-2026-06-07.md`.

## Question

In a true `1920x1080` Windowed menu run, can the default-off
`native-renderfunc-resource-tuple` preflight format the proven EASU native
render-func `passDataPtr` / managed `EASUData` match into tuple metadata
without touching `GetTexture`, actual texture resolution, command buffers, or
DLSS/NGX evaluate?

## Test Contract

- Stage: `native-renderfunc-resource-tuple`
- Artifact label: `native-renderfunc-resource-tuple-1080p-menu-20260607-r1`
- Scope: menu-only; no gameplay/save entry and no input automation.
- Resolution/window mode: `1920x1080` Windowed.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-tuple -DurationSeconds 75 -ArtifactLabel native-renderfunc-resource-tuple-1080p-menu-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Pass signals:

- analyzer reports `Native RenderFunc Resource Tuple=Pass`;
- log contains `Native render-func resource tuple advanced:`;
- `passDataMatches=True` and `tupleReady=True`;
- tuple output includes input/output dimensions plus `source` and
  `destination` TextureHandle resource identity;
- no `RenderGraph GetTexture call #`;
- no actual DLSS/NGX evaluate or DLSS probe/native-call pattern;
- no crash event.

## Result

Passed.

The run reached true `1920x1080` Windowed:

- `GameReportedWidth=1920`
- `GameReportedHeight=1080`
- `GameReportedFullScreenMode=Windowed`
- `GameReportedSetResolutionLine=SetResolution 1920, 1080, fullScreenMode Windowed`

Analyzer result:

`Native RenderFunc Resource Tuple=Pass`

Key positive evidence:

- First tuple advanced line appeared at `compile=4`.
- `managedPassData=0x1149CC95420`
- `nativeLastPassData=0x1149CC95420`
- `passDataMatches=True`
- `tupleReady=True`
- `pass="Edge Adaptive Spatial Upsampling"`
- tuple metadata:
  `input=1920x1080`,
  `output=1920x1080`,
  `source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"`,
  `destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"`.
- Final tuple status reached `#600` with `entryCount=597`,
  `sampleCount=597`, `passDataMatches=True`, and `tupleReady=True`.

Negative evidence:

- `CrashEventCount=0`
- `RenderGraph GetTexture call #=0`
- `DLSS user rendering evaluate succeeded=0`
- `DLSS super-resolution evaluate succeeded=0`
- `DLSS frame-sequence evaluate succeeded=0`
- `DLSS runtime probe succeeded=0`
- `Native render-func entry probe failed=0`
- `Native render-func resource tuple data=not found=0`

## Artifacts

- `artifacts/runtime-logs/LogOutput-native-renderfunc-resource-tuple-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/Analysis-native-renderfunc-resource-tuple-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/Player-native-renderfunc-resource-tuple-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/ClientSettings-native-renderfunc-resource-tuple-1080p-menu-20260607-r1.before.json`

## Cleanup

The diagnostic script closed V Rising after the diagnostic window and restored
the release-safe local state:

- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- no `VRising` or `UnityCrashHandler64` process remained.

Local config after cleanup returned to loader-safe defaults:

- `EnableNativeRenderFuncEntryProbe=false`
- `EnableNativeRenderFuncArgumentProbe=false`
- `EnableNativeRenderFuncResourceIdentityProbe=false`
- `EnableNativeRenderFuncResourceTupleProbe=false`
- `EnableRenderGraphGetTextureProbe=true`
- `EnableHookProbe=true`
- `EnableDLSS=false`

## Interpretation

This proves menu-only tuple metadata availability at the focused native EASU
render-func boundary. The protected `11111` gameplay proof has now also passed.
Continue from
`docs/development/native-renderfunc-resource-tuple-gameplay-result-2026-06-07.md`.
