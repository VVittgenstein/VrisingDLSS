# HDRP DLSS Schedule Audit Runtime Result - 2026-06-08

Status: pass as a read-only schedule audit; official HDRP DLSS pass was not
observed.

## Question

With `DLSS.EnableDLSS=false`, no native DLSS evaluate, no native render-func
detour, and broad `RenderGraph.GetTexture` disabled, does V Rising/HDRP schedule
Unity's official `"Deep Learning Super Sampling"` RenderGraph pass?

This was the first runtime follow-up after the official-HDRP flag/invert parity
candidate still failed performance with low GPU utilization.

## Runtime

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage hdrp-dlss-schedule-audit -DurationSeconds 75 -ArtifactLabel hdrp-dlss-schedule-audit-1080p-menu-20260608-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

This was a menu-only run. It did not click Continue and did not enter gameplay,
so it did not touch the protected save.

## Artifacts

- BepInEx log:
  `artifacts\runtime-logs\LogOutput-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.log`
- Generic analyzer:
  `artifacts\runtime-logs\Analysis-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.txt`
- Player log:
  `artifacts\runtime-logs\Player-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.log`
- Client settings backup:
  `artifacts\runtime-logs\ClientSettings-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.before.json`

Player log confirmed true `1920x1080` Windowed:

```text
SetResolution 1920, 1080, fullScreenMode Windowed
```

## Cleanup

Cleanup passed:

- `CrashEventCount=0`
- `ClosedByScript=True`
- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- No remaining `VRising` process after cleanup.
- Current game config is back to loader-safe defaults:
  `DLSS.EnableDLSS=false`, dangerous probes disabled, `EnableHookProbe=true`,
  and `EnableRenderGraphGetTextureProbe=true`.

## Analyzer Result

`scripts\analyze-hdrp-dlss-schedule-audit.ps1` returned
`NoOfficialDlssPassObserved` with no issues.

Key counts:

| Evidence | Count |
| --- | ---: |
| `RenderGraph pass-list compile #` | 93 |
| RenderGraph observation lines | 866 |
| Focused RenderGraph pass-list entries | 367 |
| `"Deep Learning Super Sampling"` pass | 0 |
| `category=dlss` | 0 |
| DLSS pass-data snapshots | 0 |
| DLSS resource declarations | 0 |
| DLSS render-func metadata | 0 |
| DLSS compiled-pass info | 0 |
| `DLSS destination` mentions | 0 |
| EASU mentions | 246 |
| Final Pass mentions | 299 |
| Upscaler-state snapshots | 1 |
| Upscaler-state calls | 162 |
| `HDCamera.IsDLSSEnabled=True` | 0 |
| `HDCamera.IsDLSSEnabled=False` | 155 |
| `GlobalDynamicResolutionSettings.enableDLSS=True` | 0 |
| `GlobalDynamicResolutionSettings.enableDLSS=False` | 7 |
| `allowDeepLearningSuperSampling=True` | 7 |
| `cameraCanRenderDLSS=True` | 0 |
| `cameraCanRenderDLSS=False` | 7 |
| Broad `RenderGraph GetTexture call #` | 0 |
| User-rendering candidate/evaluate pollution | 0 |
| Access-violation indicators | 0 |

## Important Runtime Evidence

The audit observed the regular HDRP upscaler path but not official DLSS:

- Compile #1 logged `passCount=80`, `enumerated=80`, `focusCount=6`.
- Motion-vector passes were present, e.g. `"Objects Motion Vectors Rendering"`
  and `"Camera Motion Vectors Rendering"`.
- EASU pass data existed, but at menu resolution it was not an SR-sized tuple:
  `inputWidth=1920`, `inputHeight=1080`, `outputWidth=1920`,
  `outputHeight=1080`.
- Final pass consumed the EASU destination:
  `source=Texture index=74`, `destination=Texture index=13`,
  `dynamicResFilter=EdgeAdaptiveScalingUpres`.
- EASU and Final Pass compiled-pass info showed both passes were not culled and
  had no graphics-fence sync requirement in this audit.

The upscaler-state logs explain the missing official DLSS pass:

- `allowDynamicResolution=True`
- `allowDeepLearningSuperSampling=True`
- `cameraCanRenderDLSS=False`
- `GlobalDynamicResolutionSettings.enabled=True`
- `GlobalDynamicResolutionSettings.enableDLSS=False`
- `DLSSInjectionPoint=BeforePost`
- `HDCamera.IsDLSSEnabled=False`
- `HDCamera.UpsampleSyncPoint=AfterPost`

## Source Correlation

The runtime state matches the local Unity HDRP source in
`ref\UnityGraphics-2022.3`:

- `HDCamera.IsDLSSEnabled()` returns
  `HDAdditionalCameraData.cameraCanRenderDLSS`.
- `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler(...)` sets
  `cameraCanRenderDLSS` only when all of the following are true:
  `cameraRequestedDynamicRes`, `HDDynamicResolutionPlatformCapabilities.DLSSDetected`,
  `allowDeepLearningSuperSampling`, HDRP asset
  `dynamicResolutionSettings.enableDLSS`, and HDRP asset
  `dynamicResolutionSettings.enabled`.

The audit proves the current safe settings do not reach the official
`DoDLSSPasses -> DoDLSSPass -> "Deep Learning Super Sampling"` branch because
`cameraCanRenderDLSS` remains false.

## Decision

Do not patch `DLSSPass.Render`; V Rising's local DLSS execution body is still
known to be no-op-style from the IL2CPP shell decompilation.

Do not rerun the same EASU `ctx.cmd` user-rendering candidate unchanged. The
next useful step is a source-guided gate design, not another visual/performance
loop:

1. Decide whether to add a new default-off, no-native, no-evaluate schedule-gate
   probe that deliberately sets only the official HDRP scheduling gates
   (`enableDLSS`, camera DLSS permission, dynamic-resolution request) and then
   observes whether the `"Deep Learning Super Sampling"` pass shell appears.
2. If that pass shell appears, inspect its `DLSSData`, resource declarations,
   output handle, and compiled-pass ordering without relying on
   `DLSSPass.Render`.
3. If it still does not appear, treat `HDDynamicResolutionPlatformCapabilities.DLSSDetected`
   or `m_DLSSPass` construction as the likely missing gate and keep the EASU
   boundary as the only proven visible-output route.
4. Any future state-changing schedule-gate probe must be menu-first, default
   off, release-safe, no native evaluate, and must restore loader config before
   another gameplay performance test.
