# Native RenderFunc Resource Identity Runtime Result - 2026-06-07

Status: menu-only runtime proof passed. Protected gameplay proof also passed
later; see
`docs/development/native-renderfunc-resource-identity-gameplay-result-2026-06-07.md`.

## Question

In a true `1920x1080` Windowed menu run, can the default-off
`native-renderfunc-resource-identity` preflight correlate the raw native EASU
render-func `passDataPtr` with the managed `EASUData` object observed from
`CompileRenderGraph(int)`, while keeping `GetTexture`, command-buffer access,
and DLSS evaluate untouched?

## Test Contract

- Stage: `native-renderfunc-resource-identity`
- Artifact label: `native-renderfunc-resource-identity-1080p-menu-20260607-r1`
- Scope: menu-only; no gameplay/save entry and no input automation.
- Resolution/window mode: `1920x1080` Windowed.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-resource-identity -DurationSeconds 75 -ArtifactLabel native-renderfunc-resource-identity-1080p-menu-20260607-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Pass signals:

- analyzer reports `Native RenderFunc Resource Identity=Pass`;
- log contains `Native render-func resource identity advanced:`;
- `passDataMatches=True` and `hasTextureIdentity=True`;
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

`Native RenderFunc Resource Identity=Pass`

Key positive evidence:

- First advanced line appeared at `compile=4`.
- `managedPassData=0x2840EC567E0`
- `nativeLastPassData=0x2840EC567E0`
- `passDataMatches=True`
- `hasTextureIdentity=True`
- `pass="Edge Adaptive Spatial Upsampling"`
- focused members included `source:texture` and `destination:texture`
  ResourceHandles.
- Final sampled status reached `entryCount=3897`, `sampleCount=3897`, and
  all four raw callback argument categories were nonzero `3897/3897`.

Negative evidence:

- `CrashEventCount=0`
- `RenderGraph GetTexture call #=0`
- actual native/DLSS evaluate call patterns: `0`
- actual DLSS probe/native-call patterns: `0`
- `probe failed`, `data=not found`, or logging failure patterns: `0`
- crash/exception/access-violation/fatal patterns: `0`

The generic text search for `DLSS .*evaluate` matched only the plugin's startup
warning text (`no DLSS evaluate` / diagnostic disclaimer), not an actual
evaluate path.

## Artifacts

- `artifacts/runtime-logs/LogOutput-native-renderfunc-resource-identity-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/Analysis-native-renderfunc-resource-identity-1080p-menu-20260607-r1.txt`
- `artifacts/runtime-logs/Player-native-renderfunc-resource-identity-1080p-menu-20260607-r1.log`
- `artifacts/runtime-logs/ClientSettings-native-renderfunc-resource-identity-1080p-menu-20260607-r1.before.json`

## Cleanup

The diagnostic script closed V Rising after the diagnostic window and restored
the release-safe local state:

- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- local config returned to:
  `EnableNativeRenderFuncEntryProbe=false`,
  `EnableNativeRenderFuncArgumentProbe=false`,
  `EnableNativeRenderFuncResourceIdentityProbe=false`,
  `EnableRenderGraphGetTextureProbe=true`,
  `EnableHookProbe=true`, and `EnableDLSS=false`.
- no `VRising` or `UnityCrashHandler64` process remained.

## Interpretation

This proves menu-only resource-identity correlation for the focused native EASU
render-func boundary. It does not prove protected gameplay safety, command
buffer availability, actual texture/resource resolution, or DLSS evaluate safety.

The protected `11111` gameplay proof has now passed. Continue from
`docs/development/native-renderfunc-resource-identity-gameplay-result-2026-06-07.md`.
