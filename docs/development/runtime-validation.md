# Runtime Validation Plan

This is the test progression for turning the scaffold into a usable DLSS mod.

## Stage 1: Loader Validation

Current local preflight:

- `C:\Software\VRising` is a readable V Rising `v1.1.13.0-r99712-b17` IL2CPP/HDRP build.
- The player assembly list includes HDRP, Core RP, `ProjectM`, `ProjectM.Camera`, and `UnityEngine.NVIDIAModule`.
- BepInExPack V Rising `1.733.2` has been staged into `C:\Software\VRising`.
- `VrisingDLSS.Plugin.dll` and `VrisingDLSS.Native.dll` have been copied into `C:\Software\VRising\BepInEx\plugins\VrisingDLSS`.
- A loader-stage config has been written to `C:\Software\VRising\BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg`.
- The game has been launched locally with BepInEx; `BepInEx\interop` has been generated.
- Stage 1, Stage 2, Stage 4, Stage 5A, Stage 5B, Stage 5C, and Stage 5D have direct local log evidence archived under `artifacts/runtime-logs`.
- Use only authorized/offline test installs. Do not use third-party package markers, cracked Steam files, or online-service bypasses as part of validation.

Pass criteria:

- BepInEx starts.
- `VrisingDLSS.Plugin.dll` loads.
- Config file is generated.
- No PureDark binary warning is present unless the user installed those files.

Evidence:

- `BepInEx/LogOutput.log`.

Optional local staging helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising"
```

The helpers copy BepInExPack and built VrisingDLSS files and do not launch the game.

Optional config/log helpers:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage loader
powershell -ExecutionPolicy Bypass -File scripts\analyze-bepinex-log.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\get-runtime-validation-status.ps1 -GamePath "C:\path\to\VRising"
```

The config helper writes `BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg` for a single diagnostic stage. The analyzer reads `BepInEx\LogOutput.log` by default and reports pass/fail/partial/missing evidence for stages 1-10A; pass `-LogPath` to analyze an archived diagnostic log after restoring the game folder to the safe loader config. The status helper combines preflight, config, log evidence, and the next recommended command.

## Stage 2: Hook Probe

Pass criteria:

- `EnableHookProbe=true`.
- Log shows loaded assembly count.
- Candidate HDRP types are found:
  - `CustomVignette`
  - `HDCamera`
  - `DynamicResolutionHandler`
  - `HDRenderPipeline`
- Optional HDRP DLSS/FSR/upscale and Unity NVIDIA module landmarks are logged when present. Missing optional NVIDIA module types are informational and do not fail the loader-stage probe.
- Candidate methods and signatures are logged.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Running read-only HDRP hook probe`.

## Stage 2B: Upscaler State Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableUpscalerStateProbe=false` by default.
- Patches ordinary HDRP/dynamic-resolution setter and setup methods such as `HDRenderPipeline.SetUpscaleFilter`, `HDRenderPipeline.SetFSRParameters`, `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler`, `DynamicResolutionHandler.SetDynamicResScaler`, and `HDCamera.RequestDynamicResolution` with read-only postfixes.
- Logs snapshots from `HDRenderPipeline.GetUpscaleFilter()`, `HDRenderPipeline.GetUpscaleRes()`, per-camera upscale filters, and the current existing `DynamicResolutionHandler` instance fields/properties when available.
- When HDRP calls the DLSS/dynamic-resolution setup path, argument summaries include camera `allowDynamicResolution`, `allowDeepLearningSuperSampling`, `cameraCanRenderDLSS`, DLSS quality/optimal-settings fields, and `GlobalDynamicResolutionSettings` fields such as `enableDLSS`, `DLSSPerfQualitySetting`, `upsampleFilter`, and `forcedPercentage`.
- Does not change the upscale filter, force FSR, inject RenderGraph passes, load DLSS, or evaluate DLSS.

Pass criteria:

- The initial snapshot logs without crashing.
- At least one relevant setter is patched when HDRP/Core RP exposes it.
- In a gameplay run, any FSR/upscale/DLSS setup calls are capped and include a current state snapshot.
- For the FSR Off MVP route, this stage should show whether HDRP/camera state is blocking dynamic resolution or DLSS before any render-scale mutation is attempted.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Upscaler state probe snapshot`.
- Optional call lines beginning with `Upscaler state probe call`.
- For render-scale route research, useful fields include `allowDynamicResolution`, `allowDeepLearningSuperSampling`, `cameraCanRenderDLSS`, `enableDLSS`, `DLSSUseOptimalSettings`, `upsampleFilter`, `forcedPercentage`, and `DynamicResolutionHandler.GetCurrentScale`.

## Stage 2C: Render-Scale Control Probe

Implemented as a guarded local/private diagnostic switch:

- Config key: `Diagnostics.EnableRenderScaleControlProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage render-scale-control`.
- The `dlss-user-rendering` helper also enables this probe so V Rising can stay at `FsrQualityMode=Off` while the mod requests the lower render resolution.
- Patches HDRP dynamic-resolution setup/update calls, requests `allowDynamicResolution=true`, and requests `RTHandles.SetHardwareDynamicResolutionState(true)`.
- Mutates `GlobalDynamicResolutionSettings` to `enabled=true`, `forceResolution=true`, `forcedPercentage=<DLSS quality percentage>`, and `upsampleFilter=TAAU`.
- Does not force Unity's internal DLSS pass, load NGX, create a DLSS feature, evaluate a frame, or use V Rising's FSR setting as the render-scale control.

Pass criteria:

- The probe patches at least one HDRP/Core RP setup/update method.
- Runtime logs include `Render-scale control prefix #` or `Render-scale control postfix #`.
- The changed settings include `forceResolution=true`, a `forcedPercentage` below `100` for Performance/Balanced/Quality modes, and no crash/black-screen during a local/private gameplay run.
- A follow-up `dlss-user-rendering` run with V Rising `FsrQualityMode=Off` accepts a render-input-smaller-than-output tuple.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Render-scale control patched`.
- `BepInEx/LogOutput.log` lines beginning with `Render-scale control prefix #` or `Render-scale control postfix #`.
- Stage 8E or `DLSS user rendering` evidence showing the accepted tuple after this probe is enabled.

Current Stage 2C status:

- `fsr-off-render-scale-1080p-v1-20260606` proved the hook can mutate HDRP dynamic-resolution settings under V Rising FSR Off in a `1920x1080` Windowed gameplay run: logs included `forceResolution=True` and `forcedPercentage=50`.
- The same run did not pass the MVP render-scale proof. The main DLSS candidate stayed same-sized: `color=1920x1080 output=1920x1080`, and the super-resolution input probe repeatedly reported `output was not larger than render input`.
- The blocker signature is that the gameplay camera still reported `allowDynamicResolution=False` and `IsDLSSEnabled=False`, while only non-primary intermediate resources such as `BloomMipDown_960x540` and `AO Packed data_960x540` showed 50 percent dimensions.
- Follow-up run `fsr-off-render-scale-1080p-hwdrs-v2-20260606` confirmed the targeted diagnostic but still failed the MVP tuple proof: `RTHandles.SetHardwareDynamicResolutionState=true` was logged 16 times with no request failures, `UnityEngine.Camera.allowDynamicResolution` writeback failed 20 capped times, and the main SR candidates stayed `color=1920x1080 output=1920x1080`.
- Handler-request run `fsr-off-render-scale-1080p-handler-request-v3-20260606` reached stable gameplay through Computer Use at `1920x1080` Windowed and cleaned up safely, but still failed the MVP tuple proof. Stage 8E did not accept a Super Resolution tuple, `CameraColor_960` count was `0`, `CameraColor_1920` count was `455`, and the gameplay camera stayed `actualWidth=1920,actualHeight=1080`. Auxiliary `960x540` resources appeared only for low/half-resolution effects such as LowResDepthBuffer, AO, bloom, and low-res transparent buffers. Because no `m_CurrentCameraRequest` readback appeared in that log, the follow-up patch directly invoked `DynamicResolutionHandler.SetCurrentCameraRequest(true)` from the `Update(...)` prefix.
- Direct handler-request run `fsr-off-render-scale-1080p-handler-request-v4-20260606` proved that direct invocation succeeds and the effective request is true (`before=True; invokedSetCurrentCameraRequest=True; fieldWritable=True; after=True`), but still failed the MVP tuple proof. Stage 8E did not accept a tuple, `CameraColor_960` count was `0`, `CameraColor_1920` count was `463`, and the gameplay camera remained `actualWidth=1920,actualHeight=1080`. The `11111` save was restored to `ChangeCount=0`.
- Software-fallback run `fsr-off-render-scale-1080p-software-fallback-v5-20260606` reached stable gameplay through Computer Use at `1920x1080` Windowed and cleaned up safely, but still failed the MVP tuple proof. It proved `ForceSoftwareFallback()`/fallback state was active (`HardwareDynamicResIsEnabled=False`, `SoftwareDynamicResIsEnabled=True` after handler enablement), while `GetCurrentScale=1` and `GetResolvedScale=(1.00, 1.00)` kept the main camera/resources full-size. `CameraColor_960` count was `0`, `CameraColor_1920` count was `752`, and the `11111` save was restored to `ChangeCount=0`.
- Post-update fraction run `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606` passed the FSR Off render-scale proof. The `DynamicResolutionHandler.Update(...)` postfix forced the active handler fraction/state to Performance scale; `GetCurrentScale=0.5`, `GetResolvedScale=(0.50, 0.50)`, and `SoftwareDynamicResIsEnabled=True` appeared repeatedly. `CameraColor_960` count was `504`, `CameraColor_1920` count was `0`, `HDCamera` switched to `actualWidth=960,actualHeight=540`, and Stage 8E accepted `CameraColor/CameraDepthStencil/Motion Vectors=960x540` with output `Edge Adaptive Spatial Upsampling=1920x1080`.
- The same v6 run passed the SDK-wrapper `DLSS.EnableDLSS=true` user-rendering smoke proof under V Rising FSR Off. `DLSS user rendering evaluate succeeded` reached `sequenceSuccesses=9000`, `sequenceCreates=1`, `render=960x540`, `target=1920x1080`, and `evaluateSuccesses=9000`; there were no user-rendering blocked/failed lines. Cleanup restored `ClientSettings.json`, loader config, the release-safe native DLL, and the `11111` save to `ChangeCount=0`.
- The first controlled v6 `dlss-user-rendering` visual/performance run,
  `v6-user-rendering-1080p-auto-visual-20260606-r2`, proved the route is visually
  captureable and reaches repeated SDK-wrapper evaluate success under V Rising FSR
  Off, but it failed the MVP performance gate. Baseline was `203.617` average FPS
  and `156.078` 1% low FPS; candidate was `80.242` average FPS and `58.688` 1% low
  FPS. Candidate P95 frame time worsened from `5.947 ms` to `14.775 ms`, while
  average GPU utilization dropped from `97.5%` to `43.444%`. Treat this as a
  render-thread/synchronization investigation, not a tuple/evaluate failure.
- Timing follow-up `v6-user-rendering-1080p-timing-20260606-r3` reproduced the same
  blocker while proving stable per-frame native evaluate CPU wall time is tiny.
  Baseline/candidate average FPS was `205.255 -> 86.761`, 1% low was
  `153.451 -> 67.061`, P95 frame time was `5.896 ms -> 13.642 ms`, and average GPU
  utilization was `98.111% -> 40.889%`. The first session create cost about
  `604.85 ms`, but a stable sample at `sequenceSuccesses=12000` reported bridge
  `lastMs=0.092`, native `total=0.085 ms`, and native `evaluate=0.083 ms`. This
  motivated a no-DLSS-evaluate `render-scale-control` comparison.
- Render-scale-only comparison `render-scale-only-1080p-20260606-r1` completed that
  isolation and did not reproduce the FPS collapse. Baseline/candidate average FPS was
  `204.419 -> 205.410`, 1% low was `154.841 -> 140.222`, P95 frame time was
  `5.929 ms -> 6.188 ms`, and GPU utilization/power dropped to
  `65.556%`/`95.183 W` from `98.222%`/`135.571 W`. Candidate logs proved
  `GetCurrentScale=0.5` / `GetResolvedScale=(0.50, 0.50)` while recording zero
  `DLSS user rendering evaluate succeeded` lines. Treat render-scale-only as cleared
  unless new evidence changes the fixture; the next blocker is inside
  `dlss-user-rendering` placement, hot RenderGraph discovery, or GPU
  submission/present behavior.
- Latest result summaries: `docs/development/handler-request-runtime-test-2026-06-06.md`,
  `docs/development/post-update-fraction-runtime-result-2026-06-06.md`, and
  `docs/development/v6-user-rendering-visual-test-2026-06-06.md`, plus
  `docs/development/v6-user-rendering-timing-test-2026-06-06.md` and
  `docs/development/render-scale-only-performance-test-2026-06-06.md`.
- Cached-driver no-evaluate isolation:
  `dlss-user-rendering-cached-driver-no-evaluate`. It is default-off via
  `Diagnostics.EnableDlssCachedTupleDriverProbe=false`, uses the existing
  `GetTexture` oracle only until one SR tuple is accepted, then drives the cached
  no-evaluate tuple from `DynamicResolutionHandler.Update(...)` while fast-skipping
  steady-state `GetTexture` postfix work. Runtime run
  `cached-driver-no-evaluate-1080p-20260606-r1` passed the performance isolation:
  baseline/candidate FPS was `204.201 -> 198.079`, P95 was
  `5.963 ms -> 6.408 ms`, GPU utilization/power dropped to
  `64.556%`/`86.590 W`, logs had `82` cached-driver invocations, `84`
  no-evaluate acceptances, `0` native evaluate attempts, and cleanup restored
  release-safe state and the protected `11111` save to `ChangeCount=0`.
- Cached-driver real-evaluate follow-up:
  `dlss-user-rendering-cached-driver`. Commit `6ac5212` fully deferred first
  evaluate out of `RenderGraphResourceRegistry.GetTexture(...)`; runtime run
  `cached-driver-evaluate-deferred-1080p-20260606-r1` proved
  `GetTexture` evaluate success count `0`, output follow-up count `0`, and broad
  `RenderGraph GetTexture call #` count `0`, while cached-driver evaluate from
  `DynamicResolutionHandler.Update(...)` reached `sequenceSuccesses=600`. The
  candidate still crashed before Continue/gameplay capture with Windows Application
  Error `0xc0000005` in `nvwgf2umx.dll`. Treat
  `DynamicResolutionHandler.Update(...)` as a useful no-evaluate performance driver,
  not a safe real DLSS evaluate boundary. Next step: find a narrower official
  HDRP/RenderGraph upscale-pass-equivalent boundary with current-frame resources and
  command-buffer ordering.

## Stage 3: Read-Only Harmony Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableHarmonyCallProbe=false` by default.
- Uses reflection to call the Harmony runtime loaded by BepInEx, so the plugin does not add a compile-time Harmony dependency.
- Adds read-only prefixes to a conservative candidate list and logs capped call counts plus argument summaries.
- Does not patch `DLSSPass`, RenderGraph/DLSS pass methods, optional Unity NVIDIA module methods, or the expanded HookProbe catalog.
- Does not change return values.
- Does not call the native bridge or DLSS runtime.

Pass criteria:

- Harmony patches target confirmed methods.
- Patches log call counts.
- `CustomVignette.Render` logs source/destination-like argument summaries when Unity exposes width/height/format properties.
- Game renders normally.
- No DLSS/native evaluate call is made.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Harmony probe patched` and `Harmony probe call`.
- No black screen, crash, or persistent rendering change after disabling `EnableHarmonyCallProbe`.

Negative evidence:

- A Stage 8A main-menu run on 2026-06-05 crashed in `coreclr.dll` with `0xc00000fd` after the helper had enabled broad Harmony call logging and patched `DLSSPass.Render`, which logged hundreds of calls. The `dlss-evaluate-inputs` helper no longer enables `EnableHarmonyCallProbe`, and the call probe now uses its own conservative target list instead of the expanded HookProbe catalog.

## Stage 4: Native Bridge Smoke Test

Pass criteria:

- `EnableNativeBridgeSmokeTest=true`.
- Native bridge loads.
- API version, bridge version, and diagnostic status log successfully.

## Stage 5A: Native Render Event Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableRenderThreadSmokeTest=false` by default.
- Loads `VrisingDLSS.Native.dll`.
- Gets the native `UnityRenderingEvent` callback pointer from `VrisingDlss_GetRenderEventFunc`.
- First tries Unity render-event entry points when available.
- Falls back to a temporary Harmony patch on HDRP methods with a `CommandBuffer` argument. Current local success used `HDRenderPipeline.UpdateShaderVariablesGlobalCB(HDCamera, CommandBuffer)`.
- Records native callback count and last event id.
- Does not load DLSS.
- Does not query or use D3D11 device/context yet.

Pass criteria:

- `CommandBuffer.IssuePluginEvent` calls the native render event callback.
- Native bridge render event count advances.
- Last native render event id matches the smoke-test event id.
- No DLSS runtime is loaded.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Running native render-thread smoke test`.
- Log line: `Native render-thread smoke test event reached the native callback`.

## Stage 5B: D3D11 Texture/Device Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableD3D11TextureProbe=false` by default.
- Creates a temporary 64x64 Unity `RenderTexture`.
- Calls `RenderTexture.GetNativeTexturePtr()`.
- Passes that pointer to `VrisingDlss_ProbeD3D11Texture`.
- Native code attempts `QueryInterface(ID3D11Resource)`, reads texture dimensions/format for 2D resources, and asks the resource for its D3D11 device and immediate context.
- Does not use game color/depth/motion-vector textures yet.
- Does not load DLSS.

Pass criteria:

- A Unity render texture native pointer is passed to the native bridge.
- Native bridge confirms D3D11 resource/device/context acquisition.
- Log shows a non-zero temporary texture pointer.
- Native probe status reports texture dimension, DXGI format, width, and height.
- No DLSS runtime is loaded.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Running D3D11 texture pointer probe`.
- Log line beginning with `D3D11 texture pointer probe succeeded`.

## Stage 5C: HDRP Frame Resource Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableFrameResourceProbe=false` by default.
- Patches candidate frame-resource methods with read-only Harmony prefixes:
  - `CustomVignette.Render(CommandBuffer, HDCamera, RTHandle, RTHandle)`
  - `HDRenderPipeline.UpdateShaderVariablesGlobalCB(HDCamera, CommandBuffer)`
- Logs source/destination-like render arguments.
- Searches RTHandle/Texture-like objects for `GetNativeTexturePtr()`.
- Reads global `_CameraDepthTexture` and `_CameraMotionVectorsTexture`.
- Passes discovered native pointers to `VrisingDlss_ProbeD3D11Texture`.
- Does not change render state.
- Does not load DLSS.
- Does not evaluate DLSS.

Pass criteria:

- At least one frame-resource hook is patched and called.
- Source and destination frame resources produce non-zero native pointers when the hook provides them.
- Depth and motion vector textures are found at the target frame point, or the log proves which one is missing.
- Native D3D11 probe succeeds for every required resource that is found.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Frame resource probe patched`.
- `BepInEx/LogOutput.log` lines beginning with `Frame resource probe call`.
- Per-resource lines showing `nativePtr=0x...` and D3D11 probe status.

## Stage 5D: DLSS Runtime Load Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableDlssRuntimeProbe=false` by default.
- Runtime path key: `DLSS.DlssRuntimePath`.
- Resolves relative paths from the plugin directory.
- Requires the user to provide their own production `nvngx_dlss.dll` path.
- Calls the native bridge to load the runtime with `LoadLibraryW`, check for known DLSS D3D11 runtime exports, and release it immediately.
- Does not call `NVSDK_NGX_D3D11_Init`.
- Does not query DLSS support or quality modes.
- Does not evaluate DLSS.

Pass criteria:

- The configured runtime path exists.
- Native bridge logs API version `4` or newer.
- Native status reports the runtime was loaded and released.
- Known runtime exports such as `NVSDK_NGX_D3D11_Init`, `CreateFeature`, `EvaluateFeature`, `ReleaseFeature`, and `Shutdown1` are present.
- No DLSS context is created and no frame evaluation occurs.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Running DLSS runtime load probe`.
- Log line beginning with `DLSS runtime probe succeeded`.

## Stage 6: DLSS Init/Query Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableDlssInitQueryProbe=false` by default.
- Runtime path key: `DLSS.DlssRuntimePath`.
- Optional NGX application id key: `DLSS.DlssApplicationId`.
- Creates a temporary 64x64 Unity `RenderTexture`.
- Passes its native texture pointer to `VrisingDlss_ProbeDlssInitQuery`.
- Native code gets the D3D11 device from that temporary resource.
- Loads the user-supplied production `nvngx_dlss.dll`.
- In the current source-only build, checks whether the runtime exposes the helper exports needed for capability query.
- If those helper exports are missing, logs `DLSS init/query probe blocked` and exits before NGX init.
- An SDK-wrapper-backed research build calls `NVSDK_NGX_D3D11_Init` or `NVSDK_NGX_D3D11_Init_with_ProjectID`, queries DLSS SuperSampling capability parameters, destroys the parameter map, and immediately calls NGX shutdown.
- Does not create a DLSS feature.
- Does not use game color/depth/motion-vector textures.
- Does not evaluate DLSS.

Pass criteria:

- User-provided production `nvngx_dlss.dll` has already passed Stage 5D.
- The native build has an explicit NVIDIA SDK wrapper integration path.
- `NVSDK_NGX_D3D11_Init` succeeds against the acquired D3D11 device path.
- DLSS SuperSampling support is queried.
- Driver update requirement and minimum driver parameters are logged when available.
- Init/shutdown does not leak or crash.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Running DLSS init/query probe`.
- Log line beginning with `DLSS init/query probe succeeded`.
- Native status includes `available=`, `needsUpdatedDriver=`, `minDriver=`, `featureInitResult=`, `destroy=`, and `shutdown=`.

Current Stage 6 status:

- The official `nvngx_dlss.dll` runtime from DLSS SDK `310.6.0` exposes D3D11 init/create/evaluate/release/shutdown and `NVSDK_NGX_D3D11_PopulateParameters_Impl`, but does not directly export `NVSDK_NGX_D3D11_AllocateParameters`, `NVSDK_NGX_D3D11_GetCapabilityParameters`, `NVSDK_NGX_D3D11_DestroyParameters`, or the public `NVSDK_NGX_Parameter_Set*`/`Get*` accessors.
- The official sample links the NVIDIA SDK wrapper library for `GetCapabilityParameters` and parameter-map helpers. The source-only/release-safe build therefore reports `Blocked`; use `scripts/probe-ngx-runtime-exports.ps1` to repeat the export-surface check offline.
- Re-running `dlss-init-query` with only a production `nvngx_dlss.dll` is expected to report `Blocked`, not `Pass`.
- A local MSVC SDK-wrapper research build passed Stage 6 with ProjectID init: `init=0x00000001`, `capability=0x00000001`, `available=1`, `needsUpdatedDriver=0`, `minDriver=470.0`, `featureInitResult=1`, `destroy=0x00000001`, `shutdown=0x00000001`.

## Stage 6B: DLSS Optimal-Settings Probe

Implemented and game-runtime validated as an optional SDK-wrapper research diagnostic.

Scope:

- Config key: `Diagnostics.EnableDlssOptimalSettingsProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-optimal-settings`.
- Creates a temporary 64x64 Unity `RenderTexture` only to acquire the D3D11 device path.
- Queries DLSS optimal settings for a 3840x2160 output target and the selected `DLSS.QualityMode`.
- Does not create a DLSS feature.
- Does not use game color/depth/motion-vector textures.
- Does not evaluate DLSS.

Pass criteria:

- Stage 5D and Stage 6 have already passed in the same native integration route.
- The native build has the optional NVIDIA SDK wrapper integration path.
- `NGX_DLSS_GET_OPTIMAL_SETTINGS` succeeds.
- Native status reports non-zero `render=`, `dynamicMax=`, and `dynamicMin=` fields.
- Parameter destruction and NGX shutdown succeed.

Current Stage 6B status:

- C# and native bridge API version 12 are build-validated in both release-safe and SDK-wrapper native builds.
- Release-safe builds are expected to report blocked because the NVIDIA SDK wrapper path is not enabled or packaged by default.
- Local SDK-wrapper game-runtime validation passed in run `dlss-optimal-settings-20260606-115921`.
- The run used a `1920x1080` Windowed player shape via temporary `ClientSettings.json` changes and launch arguments, then restored the user's settings afterward.
- The optimal-settings query itself targeted `output=3840x2160` and returned `render=1920x1080`, `dynamicMax=3840x2160`, `dynamicMin=1920x1080`, and `sharpness=0.350`.
- Cleanup passed with `CrashEventCount=0`, `ClosedByScript=True`, `RestoredLoaderConfig=True`, `RestoredReleaseSafeNative=True`, and `RestoredClientSettings=True`.
- Protocol and evidence summary: `docs/development/dlss-optimal-settings-runtime-protocol-2026-06-06.md`.

## Stage 7: DLSS Feature Create/Release Probe

Implemented as an optional SDK-wrapper research diagnostic:

- Config key: `Diagnostics.EnableDlssFeatureCreateProbe=false` by default.
- Runtime path key: `DLSS.DlssRuntimePath`.
- Optional NGX application id key: `DLSS.DlssApplicationId`.
- Creates a temporary 64x64 Unity `RenderTexture` only to acquire the D3D11 device/context path.
- Uses the configured quality mode to choose a fixed diagnostic render size for a 1920x1080 target.
- Calls the SDK-wrapper-backed NGX path to create a DLSS SuperSampling feature, then releases it immediately.
- Does not use game color/depth/motion-vector textures.
- Does not evaluate DLSS.

Pass criteria:

- Stage 5D and Stage 6 have already passed in the same native integration route.
- The native build has the optional NVIDIA SDK wrapper integration path.
- `NGX_D3D11_CREATE_DLSS_EXT` succeeds for a temporary D3D11 device/context path.
- The created feature handle is released.
- Parameter destruction and NGX shutdown succeed.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Running DLSS feature create/release probe`.
- Log line beginning with `DLSS feature create probe succeeded`.
- Native status includes `render=`, `target=`, `perfQuality=`, `flags=`, `create=`, `feature=`, `release=`, `destroy=`, and `shutdown=`.

Current Stage 7 status:

- A local MSVC SDK-wrapper research build passed Stage 7 with ProjectID init: `render=1280x720`, `target=1920x1080`, `perfQuality=2`, `flags=0x00000040`, `create=0x00000001`, `feature=yes`, `release=0x00000001`, `destroy=0x00000001`, `shutdown=0x00000001`.
- Release-safe builds are expected to report blocked because the NVIDIA SDK wrapper path is not enabled or packaged by default.

## Stage 8A: DLSS Evaluate Input Probe

Implemented as an optional real-frame diagnostic:

- Config key: `Diagnostics.EnableDlssEvaluateInputProbe=false` by default.
- Reuses the Stage 5C frame-resource Harmony patch.
- Collects the first two texture-like native pointers from the frame hook as color/output candidates.
- When Stage 8A is enabled, also discovers and patches loaded non-abstract `Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` methods in HDRP and ProjectM assemblies.
- Also discovers selected HDRP RenderGraph methods that carry `RenderGraph` plus `TextureHandle` parameters, including post-process, motion-vector, final-blit, and custom-post-process paths.
- For RenderGraph callbacks, records resource handle index/type and checks `GetTextureResource(ResourceHandle&)` state. It does not call `GetTexture(TextureHandle&)` from a method prefix, because invalid-scope calls can produce IL2CPP trampoline errors even when caught.
- Patches non-generic `RenderGraphBuilder` texture declaration methods (`UseColorBuffer`, `UseDepthBuffer`, `ReadTexture`, `WriteTexture`, `ReadWriteTexture`) to observe the resources HDRP declares for each pass. This path uses `GetRenderGraphResourceName(ResourceHandle&)` for names only; it does not materialize textures.
- When local V Rising interop assemblies are available at build time, compiles a high-risk diagnostic RenderGraph pass path that uses `AddRenderPass`/`SetRenderFunc`, declares `CameraColor`, `CameraDepthStencil`, and `Motion Vectors`, and attempts native input validation inside the render function. This path is gated by `Diagnostics.EnableRenderGraphDiagnosticPass=false` by default.
- Patches `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` with a read-only postfix to detect any engine-owned, valid-scope texture materialization and probe the returned `RTHandle`.
- When `Diagnostics.EnableResourceMaterializationProbe=true`, patches `RenderGraphResourceRegistry.BeginExecute(int)` and `CreateTextureCallback(RenderGraphContext, IRenderGraphResource)` to observe engine-owned `TextureResource.graphicsResource` materialization after Unity reports successful texture creation. This is enabled by the `dlss-evaluate-inputs` helper stage and is still diagnostic only.
- Can patch selected existing HDRP render functions with a read-only postfix only when the high-risk `Diagnostics.EnableExistingRenderFuncProbe=true` switch is explicitly enabled. This rejected route does not inject a RenderGraph pass. It observes pass data from known post-process/upscale callbacks such as `DoDLSSPass`, `DoTemporalAntialiasing`, `UberPass`, `FinalPass`, and `DoCustomPostProcess`, recursively reads `TextureHandle` fields including nested `resourceHandles`, and resolves them only while the current RenderGraph registry is available.
- Can patch `DLSSPass.GetViewResources` and `DLSSPass.GetCameraResources` only when the high-risk `Diagnostics.EnableDlssPassResourceProbe=true` switch is explicitly enabled. This does not patch the rejected `DLSSPass.Render` method. It logs returned `Texture` pointers and can feed the native evaluate-input validator only when `Diagnostics.EnableDlssEvaluateInputProbe=true` is also enabled.
- Reads global `_CameraDepthTexture` and `_CameraMotionVectorsTexture` as depth/motion candidates.
- Passes color/output/depth/motion native pointers to `VrisingDlss_ProbeDlssEvaluateInputs`.
- Native code validates D3D11 Texture2D resources, non-zero dimensions, same D3D11 device, and frame-aligned color/depth/motion dimensions.
- Does not load DLSS.
- Does not create a DLSS feature.
- Does not evaluate DLSS.

Pass criteria:

- A frame hook exposes source/output resources in the same callback.
- Depth and motion-vector global textures are present in that same callback.
- Native input validation succeeds for all four resources.
- The log records the color/output/depth/motion pointer set and the native texture descriptions.

Evidence:

- `BepInEx/LogOutput.log` line beginning with `DLSS evaluate input probe enabled`.
- Log line beginning with `DLSS evaluate input probe succeeded`.
- Native status includes `color=`, `output=`, `depth=`, `motion=`, and `sameDevice=yes`.

Current Stage 8A status:

- Implemented and build-validated.
- Main-menu runtime evidence is `Blocked`: `CustomVignette.Render` plus nine extended `Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` candidates were patched but not observed as called; `HDRenderPipeline.UpdateShaderVariablesGlobalCB` was called but only exposed HDCamera/CommandBuffer, not source/output RTHandles. `_CameraDepthTexture` appeared as a D3D11 texture, while `_CameraMotionVectorsTexture` remained `null`.
- RenderGraph main-menu evidence is also `Blocked`, but more informative: `RenderCameraMotionVectors`, `DoCustomPostProcess`, and `ResolveMotionVector` were called and exposed handles for `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer`. The resource registry recognized those names, but `GetTexture(TextureHandle&)` threw because the texture was not yet created or was already released at the Harmony prefix point. No native texture pointer was available from these method-prefix hooks.
- A direct prefix call to `GetTexture(TextureHandle&)` was rejected as an unsafe diagnostic route because it produced IL2CPP trampoline error logs. The current code avoids that direct call and instead listens for engine-owned successful `GetTexture` calls through a postfix.
- The `GetTexture` postfix patched successfully in a 45-second main-menu run without IL2CPP trampoline errors, but no successful `RenderGraph GetTexture call` was observed in that window.
- The RenderGraph builder declaration probe patched five methods and cleanly observed named declarations in a 45-second main-menu run, including `UseColorBuffer(CameraColor)`, `ReadTexture(CameraColor)`, `ReadTexture(CameraDepthStencil)`, `UseColorBuffer(Motion Vectors)`, `ReadTexture(Motion Vectors)`, and `ReadTexture(NormalBuffer)`. This proves the target resources are present and named in the graph, but still does not provide native texture pointers.
- A `RenderGraph.PreRenderPassExecute` postfix probe patches cleanly, but it was not observed as called in a 45-second main-menu run. This suggests that main-menu RenderGraph execution does not traverse that managed interop wrapper.
- A `RenderGraphPass<T>.Execute(RenderGraphContext)` open-generic prefix probe was tested and rejected: Harmony refused to patch the open generic method because `Type.ContainsGenericParameters` is true.
- A `TextureHandle` implicit-conversion postfix probe was tested and rejected: patching the conversion methods produced repeated IL2CPP trampoline `NullReferenceException` logs in the main menu. The source code no longer patches those conversions.
- A local-interop diagnostic RenderGraph pass injected successfully with `hasRenderFunc=True` and `allowPassCulling=False` in main-menu runs, but its render function was not observed as called there.
- A local/private gameplay run on 2026-06-05 configured and injected the diagnostic pass twice, then V Rising crashed with a Windows `APPCRASH` in `coreclr.dll` (`0xc0000005`) before any diagnostic-pass render-function log. This route is now high-risk and disabled by default behind `Diagnostics.EnableRenderGraphDiagnosticPass=false`.
- A main-menu run on 2026-06-05 patched 10 compiler-generated existing HDRP render functions, including `DoTemporalAntialiasing`, `DoCustomPostProcess`, `UberPass`, and `FinalPass`, then V Rising crashed with Windows `APPCRASH` in `coreclr.dll` (`0xc0000005`) before any `Existing HDRP render-func scope` log. Re-running reproduced the same fault bucket. This route is now high-risk and disabled by default behind `Diagnostics.EnableExistingRenderFuncProbe=false`.
- A later Stage 8A main-menu run crashed with Windows `APPCRASH` in `coreclr.dll` (`0xc00000fd`) after broad Harmony call logging patched `DLSSPass.Render` and logged hundreds of calls. This was a diagnostic helper composition problem, not DLSS evaluate. The Stage 8A helper no longer enables broad Harmony call logging.
- A follow-up Stage 8A main-menu run with `EnableHarmonyCallProbe=false` ran for the diagnostic window without a Windows crash event. It reached `Partial`: the safe materialization patches installed, but no `RenderGraph texture materialization #` or successful `RenderGraph GetTexture` callback was observed in the main-menu window.
- Static interop inspection shows `DLSSPass.ViewResourceHandles` carries `source`, `output`, `depth`, `motionVectors`, and `biasColorMask` handles, and `DLSSPass.CameraResources.resources` exposes corresponding `Texture` fields. This confirms Unity HDRP's native DLSS pass structure contains the exact resource categories needed for first evaluate.
- A targeted Harmony prefix on `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)` was tested and rejected. V Rising crashed in `UnityPlayer.dll` with `0x80000003` after the method was patched and before any prefix call logged, so this IL2CPP method should not be used as the next runtime hook point.
- A separate `Diagnostics.EnableDlssPassResourceProbe=false` route is now implemented for deliberate research on the safer-looking DLSSPass helper methods `GetViewResources` and `GetCameraResources`. This route is not enabled by the ordinary `dlss-evaluate-inputs` helper.
- A main-menu run on 2026-06-05 with only the isolated DLSSPass helper route enabled patched `GetViewResources` and `GetCameraResources`, ran for the diagnostic window, and produced no matching Windows crash event. It did not observe any `DLSSPass resource helper #` callback before shutdown, so the route has initial patch-stability evidence only, not resource or Stage 8A input evidence.
- A scripted `dlss-evaluate-inputs` gameplay-attempt run on 2026-06-05 exited after about 13 seconds with Windows `APPCRASH` in `coreclr.dll` (`0xc0000005`). Before the crash it again observed RenderGraph declarations for `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer`, but no materialized native texture pointer. Because the log stopped after ordinary HDRP/RenderGraph prefix probes, ordinary `dlss-evaluate-inputs` now skips those broad prefix probes by default.
- A follow-up scripted run also exited early with the same `coreclr.dll` `0xc0000005` bucket after only the RenderGraph builder declaration, execution-scope, GetTexture postfix, and materialization probes were enabled. The log stopped at builder declaration #40 and did not show materialization/GetTexture callbacks, so ordinary `dlss-evaluate-inputs` now also skips builder declaration and execution-scope prefix/postfix probes by default.
- A later scripted `dlss-evaluate-inputs` run on 2026-06-05 limited ordinary Stage 8A to registry-level `BeginExecute(int)`, `CreateTextureCallback(RenderGraphContext, IRenderGraphResource)`, and the passive `GetTexture(TextureHandle&)` postfix. It ran for the full 75-second diagnostic window with no matching Windows crash event. The log reported `DLSS evaluate input probe succeeded from RenderGraph GetTexture` with same-device D3D11 resources: `CameraColor`, `Apply Exposure Destination`, `CameraDepthStencil`, and `Motion Vectors`, all at `720x480`.
- Local static inspection confirms V Rising exposes HDRP FSR/upscale/DLSS landmarks, including `HDRenderPipeline.SetFSRParameters(float, bool)`, `GetUpscaleRes()`, `SetUpscaleFilter(DynamicResUpscaleFilter, float)`, `GetUpscaleFilter()`, `SetupDLSSForCameraDataAndDynamicResHandler(...)`, `GetPostprocessUpsampledOutputHandle(...)`, `DoDLSSPasses(...)`, `DoDLSSPass(...)`, and `DoTemporalAntialiasing(...)`. FSR1 is useful for locating the existing dynamic-resolution path, but it is not enough for DLSS because DLSS still needs aligned depth and motion-vector inputs.
- Materialization-only no-evaluate gameplay follow-up on 2026-06-06 rejected `CreateTextureCallback` as a sufficient replacement boundary for the global `GetTexture` postfix. `materialization-only-no-evaluate-1080p-20260606-r1` disabled `EnableRenderGraphGetTextureProbe`, enabled resource materialization and no-evaluate tuple acceptance, and confirmed the GetTexture postfix was skipped. The materialization hooks patched cleanly, but gameplay produced `0` `RenderGraph texture materialization #` logs, `0` SR input candidates, and `0` no-evaluate acceptances from materialization before the candidate was stopped. Cleanup restored release-safe config and restored the protected `11111` save with `ChangeCount=0`.
- Narrow source inspection on 2026-06-06 located the official HDRP DLSS boundary: `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling` RenderGraph pass execution -> `DLSSPass.GetCameraResources` -> `DLSSPass.Render/ExecuteDLSS`. V Rising interop exposes these symbols, but local metadata/runtime scan still does not show the complete Unity NVIDIA runtime stack. See `docs/research/hdrp-dlss-execution-boundary-2026-06-06.md`.
- Implementation follow-up on 2026-06-06 added `Diagnostics.EnableRenderGraphPassBoundaryProbe=false` and helper stage `rendergraph-pass-boundary`. It patches only `RenderGraph.PreRenderPassExecute(...)`, accepts both the V Rising 3-argument interop shape and Unity Core 2022.3's 2-argument source shape, logs capped pass metadata, and returns before texture/resource resolution when no evaluate-input probe is enabled.
- Runtime follow-up on 2026-06-06 rejected the `PreRenderPassExecute` Harmony boundary for normal diagnostics. `rendergraph-pass-boundary-1080p-20260606-r1` patched `PreRenderPassExecute(CompiledPassInfo&, RenderGraphPass, RenderGraphContext)` successfully, but emitted `0` `RenderGraph pass boundary #` lines and V Rising crashed before gameplay/Continue with Windows Application Error `coreclr.dll` `0xc0000005`. Cleanup restored loader config, ClientSettings, release-safe native state, and the protected `11111` save with `ChangeCount=0`.
- Implementation follow-up after cached-driver real-evaluate rejection added `Diagnostics.EnableRenderGraphPassMapProbe=false` and helper stage `rendergraph-pass-map`. It patches only `RenderGraph.OnPassAdded(RenderGraphPass)`, logs capped pass names/types/categories, disables `GetTexture`, and does not resolve resources or evaluate DLSS. Build and dry-run validation passed. A 2026-06-06 main-menu smoke and gameplay smoke both patched cleanly and produced no WER crash, but emitted `0` `RenderGraph pass map #` lines; the gameplay run was true `1920x1080` Windowed and restored the protected `11111` save with `ChangeCount=0`. This rejects `OnPassAdded` as a useful pass-name probe in the current V Rising runtime.
- Implementation and runtime follow-up added `Diagnostics.EnableRenderGraphPassListProbe=false` and helper stage `rendergraph-pass-list`. It patches only `RenderGraph.CompileRenderGraph(int)` with a postfix, snapshots `m_RenderPasses` names/types/categories before `ClearRenderPasses()`, disables `GetTexture`, and does not resolve resources or evaluate DLSS. Menu smoke `rendergraph-pass-list-1080p-menu-20260606-r2` passed at true `1920x1080` Windowed with `CrashEventCount=0`, analyzer `RenderGraph Pass List=Pass`, compile lines `90`, entry lines `357`, failures `0`, and focused categories `upscale=16`, `postprocess=19`, `final=28`, `temporal=72`, `dlss=0`. The protected `11111` gameplay proof `rendergraph-pass-list-gameplay-1080p-20260606-r1` also passed: `CrashEventCount=0`, analyzer `RenderGraph Pass List=Pass`, compile lines `143`, entry lines `540`, failures `0`, `RenderGraph GetTexture call #=0`, and focused categories `upscale=16`, `postprocess=80`, `final=29`, `temporal=193`, `dlss=0`. It repeatedly observed `Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass`; cleanup restored settings/config/native state and the save restored to `ChangeCount=0`. See `docs/development/rendergraph-pass-list-runtime-result-2026-06-06.md`.
- Implementation follow-up added `Diagnostics.EnableRenderGraphPassResourceDeclarationProbe=false` and helper stage `rendergraph-pass-declarations`. It reuses the safe `CompileRenderGraph(int)` postfix but logs only focused pass-local `colorBuffers`, `depthBuffer`, `resourceReadLists`, and `resourceWriteLists` handle declarations. It disables `GetTexture` and does not resolve names, textures, native pointers, or evaluate DLSS. Menu smoke `rendergraph-pass-declarations-1080p-menu-20260606-r1` passed at true `1920x1080` Windowed with `CrashEventCount=0`, analyzer `RenderGraph Pass Declarations=Pass`, `297` declaration lines, `0` broad GetTexture logs, and focused declarations for motion vectors, `Uber Post`, `Edge Adaptive Spatial Upsampling`, and `Final Pass`. A later startup/window-only session with the gameplay label also emitted declaration signal (`399` lines, `0` broad GetTexture logs, `CrashEventCount=0`) and restored the save with `ChangeCount=0`, but it did not enter protected gameplay and must not be counted as gameplay proof. Protected gameplay proof `rendergraph-pass-declarations-gameplay-1080p-20260606-r2` then passed in the `11111` fixture: Computer Use clicked Continue once and sent no movement keys, gameplay screenshots showed stable HUD/character/minimap, analyzer `RenderGraph Pass Declarations=Pass`, `529` declaration lines, `0` broad GetTexture logs, failures `0`, `CrashEventCount=0`, cleanup restored config/ClientSettings/native state, and save restore ended with `ChangeCount=0`. See `docs/development/rendergraph-pass-declarations-plan-2026-06-06.md`.
- Focused declaration analysis after the r2 gameplay proof parsed `529` declaration rows and found `43` complete `Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass` chains. All `43` complete chains satisfied `Uber write == EASU read`, and all `43` satisfied `EASU write == Final first read`; the dominant chain was `Uber 78 -> EASU 78 -> 79 -> Final 79` with `42` occurrences. Local/upstream source plus V Rising interop confirm that `EASUData`, `FinalPassData`, and `UberPostPassData` fields are the next safest thing to inspect from the already-proven `CompileRenderGraph(int)` observation point. See `docs/development/rendergraph-pass-data-boundary-analysis-2026-06-06.md`.
- Implementation follow-up added `Diagnostics.EnableRenderGraphPassDataSnapshotProbe=false` and helper stage `rendergraph-pass-data`. It reuses the safe `CompileRenderGraph(int)` postfix but logs only focused `UberPostPassData`, `EASUData`, `FinalPassData`, and DLSS pass-data scalar/TextureHandle summaries. It disables `GetTexture` and does not resolve names, textures, native pointers, command buffers, generated render functions, or evaluate DLSS. The first menu smoke `rendergraph-pass-data-1080p-menu-20260606-r1` proved patch safety but showed base `RenderGraphPass` wrappers do not expose `data` directly. The fixed typed Il2CppInterop route then passed `rendergraph-pass-data-1080p-menu-20260606-r3` at true `1920x1080` Windowed: `CrashEventCount=0`, analyzer `RenderGraph Pass Data=Pass`, `248` snapshot lines, `248` `memberCount=` lines, `0` `data=not found`, `0` typed-read failures, and `0` broad GetTexture logs. r3 observed `Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass`, with Uber `1920x1080`, EASU `input=1920x1080 output=1920x1080`, and Final `performUpsampling=True dynamicResIsOn=True dynamicResFilter=EdgeAdaptiveScalingUpres`. Protected gameplay proof `rendergraph-pass-data-gameplay-1080p-20260606-r1` then passed in the `11111` fixture: Computer Use clicked Continue once and sent no movement keys, the gameplay screenshot showed stable HUD/character/minimap, analyzer `RenderGraph Pass Data=Pass`, `321` snapshot lines, `321` `memberCount=` lines, `0` `data=not found`, `0` typed-read failures, `0` broad GetTexture logs, failures `0`, `CrashEventCount=0`, cleanup restored config/ClientSettings/native state, and save restore ended with `ChangeCount=0`. The gameplay chain summary found `73` complete chains; `73/73` matched `Uber.destination == EASU.source`, and `73/73` matched `EASU.destination == Final.source`. See `docs/development/rendergraph-pass-data-gameplay-result-2026-06-06.md`.
- Current next route: keep the accepted Stage 8A `GetTexture` postfix as a diagnostic tuple oracle only, not the production steady-state path. Stage 8B guarded SDK-wrapper DLSS evaluate, Stage 8C output follow-up, Stage 8D persistent repeated evaluate, Stage 8E Super Resolution input sizing, Stage 8F Super Resolution evaluate, Stage 8G Super Resolution persistent repeated evaluate, Stage 9A Super Resolution frame-sequence evaluate, and Stage 10A visible write-back candidate now have local runtime proof while `DLSS.EnableDLSS=false` remains the package default. `DLSS.EnableDLSS=true` now drives an experimental one-evaluate-per-Unity-frame candidate through that same route, but cached-driver real-evaluate crashed in `nvwgf2umx.dll` even after `GetTexture` evaluate/output-follow-up reached zero. Narrow source/search follow-up confirms the official HDRP DLSS boundary is `DoDLSSPass -> Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`; V Rising has no proven safe Harmony-equivalent evaluate boundary yet. Do not rerun `rendergraph-pass-boundary`, `rendergraph-pass-map`, cached-driver real-evaluate, pass-list smoke, pass-declarations, pass-data menu smoke, pass-data gameplay proof, `rendergraph-execute-delegate` menu proof, or `rendergraph-renderfunc-metadata` menu/gameplay proof unchanged. The `rendergraph-execute-delegate` stage patched closed `GetExecuteDelegate<TPassData>()` methods safely in a true `1920x1080` Windowed menu run, with no crash and `GetTexture=0`, but emitted `0` focused execute-delegate lines, so it is patch-stability evidence only. The follow-up `rendergraph-renderfunc-metadata` stage passed menu proof at true `1920x1080` Windowed with `248` metadata lines, then protected `11111` gameplay proof with `300` metadata lines, `0` `renderFunc=not found`, `0` metadata failures, `0` GetTexture logs, no crash, no movement keys, and save restore `ChangeCount=0`. It mapped `Uber Post`/EASU/`Final Pass` to `<UberPass>b__1060_0`, `<EdgeAdaptiveSpatialUpsampling>b__1066_0`, and `<FinalPass>b__1069_0`. This is metadata evidence only; next work is local source/interop design for a safer equivalent to the official HDRP execution boundary, not patching generated render funcs from this evidence.
- 2026-06-06 narrow boundary audit:
  `docs/research/hdrp-rendergraph-harmony-boundary-audit-2026-06-06.md`.
  Local Unity source, V Rising interop decompile, and targeted network checks now
  answer the reduced question directly: official HDRP gets resources and submits
  evaluate inside the `Deep Learning Super Sampling` RenderGraph render function
  through `DLSSPass.GetCameraResources(...)` and `DLSSPass.Render(..., ctx.cmd)`.
  Unity docs/source confirm actual RenderGraph resources are available only in
  render pass execution code, and local interop shows
  `RenderGraphPass<T>.Execute`, `RenderFunc<T>.Invoke`, and
  `DLSSPass.GetCameraResources` managed wrappers are `CallerCount(0)`
  `il2cpp_runtime_invoke` wrappers in this build. Therefore there is still no
  proven safe BepInEx/Harmony-equivalent boundary for the official DLSS window.
  Keep `CompileRenderGraph(int)` probes as read-only map evidence only. The next
  implementation should either add a low-risk compiled-pass-info snapshot from
  the same safe compile postfix, or first design a separate
  `native-renderfunc-entry` no-op method-pointer probe. Do not treat native
  method-pointer detouring as ordinary Harmony patching.
- Implementation follow-up added
  `Diagnostics.EnableRenderGraphCompiledPassInfoProbe=false` and helper stage
  `rendergraph-compiled-pass-info`. It reuses only the safe
  `CompileRenderGraph(int)` postfix and reads focused `CompiledPassInfo`
  culling/sync/refCount/resource lifetime counts from
  `m_CurrentCompiledGraph.compiledPassInfos`.
  It does not resolve textures, call `GetTexture`, inspect native pointers,
  touch command buffers, call render funcs, or evaluate DLSS. Build and dry-run
  config validation passed. Menu runtime
  `rendergraph-compiled-pass-info-1080p-menu-20260606-r2` also passed at true
  `1920x1080` Windowed with analyzer `RenderGraph Compiled Pass Info=Pass`,
  `299` focused compiled-pass-info lines, `compiledPassInfos=not found=0`,
  `RenderGraph GetTexture call #=0`, `CrashEventCount=0`, and restored
  loader/native/settings. The focused menu chain showed `Uber Post`,
  `Edge Adaptive Spatial Upsampling`, and `Final Pass` all `culled=False`.
  Treat this as read-only map evidence only, not an evaluate boundary.
- Native render-func entry preflight was added as
  `scripts\get-native-renderfunc-entry-preflight.ps1`. It does not start V
  Rising or install a detour. With `-DeepInspect`, it parsed the protected
  gameplay renderfunc-metadata proof and returned
  `Status=PreflightPass_DesignOnly`: Uber/EASU/Final method pointers were stable,
  `invoke_impl == method_ptr`, `NativeDetour(IntPtr, IntPtr)` exists locally,
  Il2Cpp method metadata exposes `MethodPointer`, and Harmony's IL2CPP backend
  detours that MethodPointer while preserving `OriginalTrampoline`. This made a
  separate `native-renderfunc-entry` no-op probe technically plausible, but the
  preflight itself does not prove ABI safety, install a hook, resolve resources,
  touch command buffers, or evaluate DLSS. See
  `docs/development/native-renderfunc-entry-preflight-2026-06-06.md`.
- Implementation follow-up added
  `Diagnostics.EnableNativeRenderFuncEntryProbe=false` and helper stage
  `native-renderfunc-entry`. It reuses `CompileRenderGraph(int)` only to observe
  the EASU `method_ptr`, waits for three stable observations, installs an
  Il2CppInterop native detour, increments a counter, and immediately calls the
  original trampoline. Static build and dry-run config validation passed.
  Menu runtime proof
  `native-renderfunc-entry-1080p-menu-20260606-r1` also passed at true
  `1920x1080` Windowed with analyzer `Native RenderFunc Entry=Pass`,
  `CrashEventCount=0`, `RenderGraph GetTexture call #=0`, one detour install,
  and counter advancement on the next compile. This proves menu ABI safety only,
  not gameplay/resource/evaluate safety. See
  `docs/development/native-renderfunc-entry-probe-implementation-2026-06-06.md`.
  Runtime result:
  `docs/development/native-renderfunc-entry-runtime-result-2026-06-06.md`.
- Protected `11111` gameplay proof
  `native-renderfunc-entry-gameplay-1080p-20260606-r1` passed at true
  `1920x1080` Windowed. Computer Use clicked the known Continue / `11111` entry
  once and sent no movement keys. Analyzer reported
  `Native RenderFunc Entry=Pass`; the log had one detour install, counter
  advancement, final `entryCount=776`, `RenderGraph GetTexture call #=0`,
  `probe failed=0`, and `CrashEventCount=0`. Cleanup restored
  ClientSettings/config/native state, closed all V Rising processes, archived
  the autosave rotation, and restored the protected save to `ChangeCount=0`.
  This remains execution-entry ABI proof only, not resource/command-buffer/DLSS
  evaluate proof. See
  `docs/development/native-renderfunc-entry-gameplay-result-2026-06-06.md`.
- Native render-func argument preflight is now implemented as a separate
  default-off stage: `Diagnostics.EnableNativeRenderFuncArgumentProbe=false`,
  helper stage `native-renderfunc-args`. It reuses the already proven EASU entry
  detour, samples only raw callback argument pointers (`thisPtr`, `passDataPtr`,
  `renderGraphContextPtr`, `methodInfoPtr`) with atomic counters/last-pointer
  snapshots, then calls the original trampoline. It does not dereference
  pointers, resolve textures, call `GetTexture`, touch command buffers, or
  evaluate DLSS. Static build, dry-run config validation, package validation,
  release boundary check, and status scripts passed. Menu runtime proof
  `native-renderfunc-args-1080p-menu-20260606-r1` passed at true `1920x1080`
  Windowed with analyzer `Native RenderFunc Args=Pass`, `CrashEventCount=0`,
  `RenderGraph GetTexture call #=0`, final `entryCount=778`, final
  `sampleCount=778`, and all four raw pointer categories nonzero `778/778`.
  Actual DLSS evaluate/probe/native-call patterns were absent. Cleanup restored
  loader config, release-safe native, and ClientSettings. This is menu
  argument-shape evidence only; protected gameplay proof is recorded below. See
  `docs/development/native-renderfunc-args-preflight-implementation-2026-06-06.md`.
  Runtime result:
  `docs/development/native-renderfunc-args-runtime-result-2026-06-06.md`.
- Protected `11111` gameplay proof
  `native-renderfunc-args-gameplay-1080p-20260606-r1` passed at true
  `1920x1080` Windowed. Computer Use clicked the known Continue / `11111` entry
  once and sent no movement/gameplay keys. Analyzer reported
  `Native RenderFunc Args=Pass`; final status reached `entryCount=841`,
  `sampleCount=841`, and all four raw pointer categories nonzero `841/841`;
  `RenderGraph GetTexture call #=0`; `probe failed=0`; actual NGX/DLSS
  evaluate/probe/native-call patterns `0`; `CrashEventCount=0`. Cleanup restored
  ClientSettings/config/native state, closed all V Rising processes, archived one
  autosave rotation, and restored the protected save to `ChangeCount=0`. This
  proves gameplay argument-shape safety only, not pointer dereference, resource
  identity, command-buffer, or DLSS evaluate safety. See
  `docs/development/native-renderfunc-args-gameplay-result-2026-06-06.md`.
  Next route is now the separate default-off resource-identity menu proof, still
  menu-first and still no command-buffer access or DLSS evaluate.
- Narrow source/search refresh
  `docs/research/hdrp-dlss-pass-boundary-narrow-refresh-2026-06-06.md`
  reconfirmed the same official HDRP boundary:
  `DoDLSSPass -> Deep Learning Super Sampling render func ->
  DLSSPass.GetCameraResources -> DLSSPass.Render(ctx.cmd)`. V Rising exposes the
  DLSS pass structure and exact generated EASU render-func method, but local
  metadata still lacks the complete Unity NVIDIA runtime stack. No new safe
  Harmony-equivalent boundary was found; continue with resource identity only,
  not `GetTexture`, command buffers, or evaluate.
- Native render-func resource identity preflight is now implemented as a
  separate default-off stage:
  `Diagnostics.EnableNativeRenderFuncResourceIdentityProbe=false`, helper stage
  `native-renderfunc-resource-identity`. It reuses the proven focused EASU
  entry/args no-op detour, correlates the latest raw native `passDataPtr` with
  the managed EASU pass-data object observed from `CompileRenderGraph(int)`, and
  verifies focused managed `source` / `destination` TextureHandle identity. It
  still does not dereference native callback pointers, resolve textures, call
  `GetTexture`, touch command buffers, patch generated render funcs through
  Harmony, or evaluate DLSS. Static `git diff --check`, Release build, dry-run
  config, Thunderstore package build/validation, and process-safety check
  passed. See
  `docs/development/native-renderfunc-resource-identity-preflight-implementation-2026-06-06.md`.
  Menu runtime proof
  `native-renderfunc-resource-identity-1080p-menu-20260607-r1` passed at true
  `1920x1080` Windowed. Analyzer reported
  `Native RenderFunc Resource Identity=Pass`; the first advanced line appeared
  at `compile=4` with `managedPassData=0x2840EC567E0`,
  `nativeLastPassData=0x2840EC567E0`, `passDataMatches=True`,
  `hasTextureIdentity=True`, and focused `source` / `destination`
  TextureHandles. Final sampled status reached `entryCount=3897`,
  `sampleCount=3897`, and all four raw pointer categories nonzero `3897/3897`.
  `RenderGraph GetTexture call #=0`; actual native/DLSS evaluate/probe patterns
  `0`; `CrashEventCount=0`. Cleanup restored loader config, release-safe native,
  ClientSettings, and no game process remained. See
  `docs/development/native-renderfunc-resource-identity-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-identity-gameplay-1080p-20260607-r1` also passed
  at true `1920x1080` Windowed. Computer Use clicked the Chinese Continue /
  `11111` area once at `(205, 354)` and sent no movement/gameplay keys. Gameplay
  screenshot showed quest text, character, HUD, health bar, and action bar.
  Analyzer reported `Native RenderFunc Resource Identity=Pass`; first advanced
  line appeared at `compile=4` with `managedPassData=0x166A6073300`,
  `nativeLastPassData=0x166A6073300`, `passDataMatches=True`, and
  `hasTextureIdentity=True`; final entry/argument status reached
  `entryCount=1072`, `sampleCount=1072`, all four raw pointer categories nonzero
  `1072/1072`; `RenderGraph GetTexture call #=0`; actual native/DLSS
  evaluate/probe patterns `0`; `CrashEventCount=0`. Cleanup restored config,
  native DLL, ClientSettings, no game process remained, and the protected save
  restored to `ChangeCount=0`. See
  `docs/development/native-renderfunc-resource-identity-gameplay-result-2026-06-07.md`.
  Next route is a separate default-off official-boundary-adjacent resource
  preflight decision, not command-buffer access or DLSS evaluate.
- Native render-func resource tuple dry preflight is now implemented as a
  separate default-off stage:
  `Diagnostics.EnableNativeRenderFuncResourceTupleProbe=false`, helper stage
  `native-renderfunc-resource-tuple`. It reuses the proven focused EASU
  entry/args/resource-identity path and formats the matched managed `EASUData`
  into tuple metadata: input/output dimensions plus focused `source` /
  `destination` TextureHandle resource identity. It still does not dereference
  native callback pointers, call `GetTexture`, resolve textures, touch command
  buffers, patch generated render funcs through Harmony, or evaluate DLSS.
  Static `git diff --check`, Release build, dry-run config validation,
  Thunderstore package validation, local loader config restore, and process
  safety checks passed. See
  `docs/development/native-renderfunc-resource-tuple-preflight-implementation-2026-06-07.md`.
  Menu runtime proof `native-renderfunc-resource-tuple-1080p-menu-20260607-r1`
  passed at true `1920x1080` Windowed. Analyzer reported
  `Native RenderFunc Resource Tuple=Pass`; first advanced line appeared at
  `compile=4` with `managedPassData=0x1149CC95420`,
  `nativeLastPassData=0x1149CC95420`, `passDataMatches=True`, and
  `tupleReady=True`; tuple metadata included `input=1920x1080`,
  `output=1920x1080`, focused `source` TextureHandle identity, and focused
  `destination` TextureHandle identity. Final tuple status reached `#600` with
  `entryCount=597` and `sampleCount=597`; `RenderGraph GetTexture call #=0`;
  actual native/DLSS evaluate/probe patterns `0`; `CrashEventCount=0`. Cleanup
  restored loader config, release-safe native, ClientSettings, and no game
  process remained. See
  `docs/development/native-renderfunc-resource-tuple-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1` also passed at
  true `1920x1080` Windowed. Computer Use clicked the Chinese Continue /
  `11111` area once at `(205, 354)` and sent no movement/gameplay keys.
  Gameplay screenshot showed quest text, character, health bar, and action bar.
  Analyzer reported `Native RenderFunc Resource Tuple=Pass`; first tuple
  advanced line appeared at `compile=4` with
  `managedPassData=0x2151E640D80`, `nativeLastPassData=0x2151E640D80`,
  `passDataMatches=True`, and `tupleReady=True`; final tuple status reached
  `#900` with `entryCount=897` and `sampleCount=897`; final argument status
  reached `entryCount=1032`, `sampleCount=1032`, all four raw pointer
  categories nonzero `1032/1032`; `RenderGraph GetTexture call #=0`; actual
  native/DLSS evaluate/probe patterns `0`; `CrashEventCount=0`. Cleanup
  restored config, native DLL, ClientSettings, no game process remained, and the
  protected save restored to `ChangeCount=0`. See
  `docs/development/native-renderfunc-resource-tuple-gameplay-result-2026-06-07.md`.
  The first separately guarded resource-resolution preflight is now implemented
  as `native-renderfunc-resource-resolve`; see
  `docs/development/native-renderfunc-resource-resolve-preflight-implementation-2026-06-07.md`.
  Config key:
  `Diagnostics.EnableNativeRenderFuncResourceResolveProbe=false`. Helper stage:
  `native-renderfunc-resource-resolve`. It reuses the proven EASU
  entry/args/resource-identity/tuple path and resolves the matched `source` /
  `destination` TextureHandles through
  `RenderGraphResourceRegistry.GetTextureResource(ResourceHandle&)` only. It
  still does not call `GetTexture(TextureHandle&)`, read native texture
  pointers, use D3D11 probes, touch command buffers, patch generated render
  funcs through Harmony, or evaluate DLSS. Static Release build, PowerShell
  parser validation, `git diff --check`, dry config validation,
  Thunderstore package validation, and loader-safe config restore passed. The
  true `1920x1080` Windowed menu proof
  `native-renderfunc-resource-resolve-20260607-134221` passed:
  analyzer `Native RenderFunc Resource Resolve=Pass`, `CrashEventCount=0`,
  `resourceReady=True` count `80`, `textureResourceReady=True` count `80`,
  `graphicsReady=True` count `0`, `RenderGraph GetTexture call #=0`, native
  texture/D3D11/ExecuteDLSS/NGX patterns `0`, and cleanup restored loader config,
  native DLL, and ClientSettings with no game process left. This is
  `TextureResource` metadata proof only; both handles still had
  `graphicsResource=null`. See
  `docs/development/native-renderfunc-resource-resolve-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1` then passed at
  true `1920x1080` Windowed. Computer Use clicked the Chinese Continue /
  `11111` area once at `(205, 354)` and sent no movement/gameplay keys. Gameplay
  screenshot showed quest text, character, minimap, health bar, and action bar.
  Analyzer `Native RenderFunc Resource Resolve=Pass`; first resolve advanced
  line had `passDataMatches=True`, `tupleReady=True`, `resourceReady=True`,
  `graphicsReady=False`, source/destination resource handles `78/79`, and both
  handles returned `TextureResource` with `graphicsResource=null`.
  `resourceReady=True` count `80`, `textureResourceReady=True` count `80`,
  `graphicsReady=True` count `0`, `RenderGraph GetTexture call #=0`, native
  texture/D3D11/ExecuteDLSS/NGX patterns `0`, `CrashEventCount=0`; cleanup
  restored loader config, native DLL, ClientSettings, no game process remained,
  and the protected save restored to `ChangeCount=0`. See
  `docs/development/native-renderfunc-resource-resolve-gameplay-result-2026-06-07.md`.
  This completes metadata-resolve menu+gameplay proof only. The next
  separately guarded preflight is now implemented as
  `native-renderfunc-resource-native-pointer`; see
  `docs/development/native-renderfunc-resource-native-pointer-preflight-implementation-2026-06-07.md`.
  Config key:
  `Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe=false`. It
  reuses the proven EASU entry/args/resource-identity/tuple path, arms the
  matched `source` / `destination` TextureHandle handles at the safe
  `CompileRenderGraph(int)` pass-list snapshot, and passively observes
  Unity-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix
  returns only for those two handles. It reads `GetNativeTexturePtr()` only from
  the already-returned texture object and logs success only after both native
  pointers are nonzero. It still does not make direct `GetTexture` calls, patch
  generated render funcs through Harmony, use D3D11 validation, touch command
  buffers, or evaluate DLSS. Static Release build, PowerShell parser
  validation, `git diff --check`, dry config validation, package creation, and
  Thunderstore package validation passed. The first menu run
  `native-renderfunc-resource-native-pointer-20260607-142048` was stable but
  partial because GetTexture postfix installation still lived under the
  `DlssEvaluateInputProbeEnabled` branch. A narrow install-condition fix was
  applied, then the true `1920x1080` Windowed menu proof
  `native-renderfunc-resource-native-pointer-20260607-142357` passed:
  analyzer `Native RenderFunc Resource Native Pointer=Pass`,
  `CrashEventCount=0`, GetTexture postfix patched, EASU target armed at
  `compile=4`, source `nativePtr=0x22815E176A0`, destination
  `nativePtr=0x22815E194E0`, `RenderGraph GetTexture call #=0`, D3D11/NGX/DLSS
  evaluate patterns `0`, and cleanup restored loader config, native DLL, and
  ClientSettings with no game process left. See
  `docs/development/native-renderfunc-resource-native-pointer-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1` then
  passed at true `1920x1080` Windowed. Computer Use clicked the Chinese
  Continue / `11111` area once at `(205, 354)`, sent no movement/gameplay keys,
  recovered from one stale/crossed Codex screenshot without sending input,
  and captured gameplay with quest text, character, minimap, health bar, and
  action bar. Analyzer `Native RenderFunc Resource Native Pointer=Pass`; first
  native-pointer advanced line had source `nativePtr=0x1C09CF519A0`, destination
  `nativePtr=0x1C09D040620`, both at `1920x1080`, `targetCompile=4`, and
  `targetManagedPassData=0x1BF14614660`. `RenderGraph GetTexture call #=0`,
  D3D11/NGX/DLSS evaluate patterns `0`, `CrashEventCount=0`; cleanup restored
  config, native DLL, ClientSettings, no game process remained, and the
  protected save restored to `ChangeCount=0`. See
  `docs/development/native-renderfunc-resource-native-pointer-gameplay-result-2026-06-07.md`.
  This completes native texture-pointer menu+protected-gameplay proof only.
  The next engineering step must be a separately guarded preflight for the next
  official-boundary question; still no command-buffer access, D3D11 validation,
  or DLSS evaluate in the same step.
- See `docs/research/stage8a-rendergraph-search-2026-06-05.md` for the official-source search that supports this route decision.

## Stage 8B: First Guarded DLSS Evaluate Diagnostic

Implemented and locally game-runtime validated with the SDK-wrapper research native build.

Scope:

- Config key: `Diagnostics.EnableDlssEvaluateProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-evaluate`.
- Reuses Stage 8A's accepted frame-resource tuple instead of installing new hook routes.
- Calls `VrisingDlss_ProbeDlssEvaluate` only after `VrisingDlss_ProbeDlssEvaluateInputs` succeeds.
- Release-safe native builds report blocked because `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=OFF` by default.
- Local SDK-wrapper research builds create a DLSS SuperSampling feature from the discovered color/output dimensions, run one `NGX_D3D11_EVALUATE_DLSS_EXT` call with jitter `(0,0)`, motion-vector scale `(1,1)`, pre-exposure/exposure-scale `1`, then release/destroy/shutdown.
- This is still diagnostic-only. It does not make `DLSS.EnableDLSS=true` a normal-user rendering path.

Pass criteria:

- Stage 8A passes in the same run.
- The native status line reports `create=0x00000001`, `evaluate=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
- Game does not black-screen or crash.

Current Stage 8B status:

- Implemented in C# and native bridge API version 11.
- Release-safe w64devkit native build passes.
- Local MSVC SDK-wrapper native build passes.
- Runtime validation against V Rising passed on 2026-06-05 in a 90-second scripted `dlss-evaluate` run with no matching Windows crash event.
- Evidence: `DLSS evaluate probe completed via SDK wrapper ProjectID; appId=0; init=0x00000001; capability=0x00000001; available=1(result=0x00000001); render=720x480; target=720x480; perfQuality=0; flags=0x00000040; jitter=(0.0000,0.0000); mvScale=(1.0000,1.0000); sharpness=0.0000; reset=1; create=0x00000001; feature=yes; evaluate=0x00000001; release=0x00000001; destroy=0x00000001; shutdown=0x00000001`.
- This is still diagnostic-only. It does not make `DLSS.EnableDLSS=true` a normal-user rendering path, and it does not by itself prove image correctness.

## Stage 8C: DLSS Output Follow-up

Implemented and locally game-runtime validated.

Scope:

- Runs after a successful Stage 8B evaluate.
- Records the selected output resource name and native D3D11 pointer.
- Watches later engine-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` callbacks for either the same resource name or the same native pointer.
- Re-probes the observed output pointer with the native D3D11 texture probe.
- Does not change the game image and does not require a normal-user `DLSS.EnableDLSS` path.

Pass criteria:

- Stage 8B passes in the same run.
- At least one later `GetTexture` callback observes the selected output resource name or native pointer.
- The observed pointer remains D3D11-accessible.
- Game does not black-screen or crash.

Current Stage 8C status:

- Runtime validation against V Rising passed on 2026-06-05 in the same 90-second scripted `dlss-evaluate` run.
- Evidence: `DLSS evaluate output follow-up #1: call=152; deltaCalls=1; resourceName=Apply Exposure Destination; expectedResourceName=Apply Exposure Destination; sameResourceName=True; samePointer=True; nativePtr=...; D3D11 texture probe succeeded`.
- Follow-up lines later observed the same native pointer under downstream post-process names, including `Prepped Motion Vectors` and `Uber Post Destination`, with D3D11 probe success. This is useful output-chain evidence, but it still needs image-correctness validation before a public MVP release.

## Stage 8D: Persistent DLSS Evaluate Diagnostic

Implemented and locally game-runtime validated.

Scope:

- Config key: `Diagnostics.EnableDlssPersistentEvaluateProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-persistent-evaluate`.
- Reuses Stage 8A's accepted frame-resource tuple.
- Creates one DLSS feature, runs multiple evaluate calls against that feature, then releases/destroys/shuts down.
- Release-safe native builds report blocked because `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=OFF` by default.
- This is still diagnostic-only. It does not make `DLSS.EnableDLSS=true` a normal-user rendering path.

Pass criteria:

- Stage 8A passes in the same run.
- The native status line reports `evaluateSuccesses` equal to `evaluateCount`.
- Native create/release/destroy/shutdown all return success.
- Game does not black-screen or crash.

Current Stage 8D status:

- Runtime validation against V Rising passed on 2026-06-05 in a 90-second scripted `dlss-persistent-evaluate` run with no matching Windows crash event.
- Evidence: `DLSS persistent evaluate probe completed via SDK wrapper ProjectID; appId=0; init=0x00000001; capability=0x00000001; available=1(result=0x00000001); render=720x480; target=720x480; perfQuality=0; flags=0x00000040; jitter=(0.0000,0.0000); mvScale=(1.0000,1.0000); sharpness=0.0000; reset=1; evaluateCount=3; evaluateSuccesses=3; create=0x00000001; feature=yes; evaluateLast=0x00000001; release=0x00000001; destroy=0x00000001; shutdown=0x00000001`.
- This proves the local SDK-wrapper path can keep a DLSS feature alive across repeated evaluate calls. The remaining MVP risk is writing the evaluated output into the visible rendering path with correct jitter, pre-exposure, render scale, resize/reset, and fallback behavior.

## Stage 8E: DLSS Super Resolution Input-Size Probe

Implemented and locally game-runtime validated.

Scope:

- Config key: `Diagnostics.EnableDlssSuperResolutionInputProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-inputs`.
- Reuses the passive Stage 8A RenderGraph `GetTexture(TextureHandle&)` candidate stream.
- Continues watching after Stage 8A succeeds, then accepts only tuples where color/depth/motion render inputs are smaller than the selected output target.
- Does not load DLSS, create a feature, evaluate a frame, or make `DLSS.EnableDLSS=true` a normal-user rendering path.
- The `dlss-evaluate` and `dlss-persistent-evaluate` helper stages also enable this probe so one local run can preserve evaluate and Super Resolution sizing evidence together.

Pass criteria:

- Color, depth, and motion-vector inputs are D3D11 Texture2D resources on the same device.
- Color/depth/motion dimensions match each other.
- The output target is larger than the color input in both width and height.
- Game does not black-screen or crash.

Current Stage 8E status:

- Runtime validation against V Rising passed on 2026-06-05 in a 105-second scripted `dlss-persistent-evaluate` run with no matching Windows crash event.
- Evidence: `DLSS super-resolution input probe succeeded; sameDevice=yes; color=426x284 fmt=26 mips=1 array=1; output=720x480 fmt=26 mips=1 array=1; depth=426x284 fmt=19 mips=1 array=1; motion=426x284 fmt=33 mips=1 array=1; scale=(1.690x,1.690x)`.
- The accepted output resource was `Edge Adaptive Spatial Upsampling`, which matches V Rising/HDRP's existing dynamic-resolution upscale route. This is sizing and resource evidence only; visible DLSS write-back and image correctness remain unimplemented.

## Stage 8F: DLSS Super Resolution Evaluate Diagnostic

Implemented and locally game-runtime validated with the SDK-wrapper research native build.

Scope:

- Config key: `Diagnostics.EnableDlssSuperResolutionEvaluateProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-evaluate`.
- Waits for Stage 8E to accept a render-input-smaller-than-output tuple.
- Calls the existing guarded SDK-wrapper `VrisingDlss_ProbeDlssEvaluate` path against that SR tuple.
- Records the selected output resource/pointer and reuses Stage 8C output follow-up to confirm it remains D3D11-accessible after evaluate.
- Release-safe native builds report blocked because `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=OFF` by default.
- This is still diagnostic-only. It does not make `DLSS.EnableDLSS=true` a normal-user rendering path.

Pass criteria:

- Stage 8E passes in the same run.
- The native status line reports `render` smaller than `target`.
- Native create/evaluate/release/destroy/shutdown all return success.
- The selected output remains D3D11-accessible in follow-up `GetTexture` callbacks.
- Game does not black-screen or crash.

Current Stage 8F status:

- Runtime validation against V Rising passed on 2026-06-05 in a 125-second scripted `dlss-persistent-evaluate` run with no matching Windows crash event.
- Evidence: `DLSS super-resolution evaluate probe succeeded from RenderGraph GetTexture: DLSS evaluate probe completed via SDK wrapper ProjectID; appId=0; init=0x00000001; capability=0x00000001; available=1(result=0x00000001); render=426x284; target=720x480; perfQuality=0; flags=0x00000040; jitter=(0.0000,0.0000); mvScale=(1.0000,1.0000); sharpness=0.0000; reset=1; create=0x00000001; feature=yes; evaluate=0x00000001; release=0x00000001; destroy=0x00000001; shutdown=0x00000001`.
- Follow-up evidence observed `Edge Adaptive Spatial Upsampling` with the same native pointer after the evaluate callback and D3D11 probe success. This proves a guarded SR-sized NGX evaluate can run, but visible write-back/image correctness still require the normal-user rendering path.

## Stage 8G: DLSS Super Resolution Persistent Evaluate Diagnostic

Implemented and locally game-runtime validated with the SDK-wrapper research native build.

Scope:

- Config key: `Diagnostics.EnableDlssSuperResolutionPersistentEvaluateProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-persistent-evaluate`.
- Waits for Stage 8E to accept a render-input-smaller-than-output tuple.
- Calls the existing guarded SDK-wrapper `VrisingDlss_ProbeDlssPersistentEvaluate` path against that SR tuple.
- Creates one DLSS feature, runs multiple evaluate calls against that feature, then releases/destroys/shuts down.
- Records the selected output resource/pointer and reuses Stage 8C output follow-up to confirm it remains D3D11-accessible after repeated evaluate.
- Release-safe native builds report blocked because `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=OFF` by default.
- This is still diagnostic-only. It does not make `DLSS.EnableDLSS=true` a normal-user rendering path.

Pass criteria:

- Stage 8E passes in the same run.
- The native status line reports `render` smaller than `target`.
- The native status line reports `evaluateSuccesses` equal to `evaluateCount`.
- Native create/release/destroy/shutdown all return success.
- The selected output remains D3D11-accessible in follow-up `GetTexture` callbacks.
- Game does not black-screen or crash.

Current Stage 8G status:

- Runtime validation against V Rising passed on 2026-06-05 in a 130-second scripted `dlss-persistent-evaluate` run with no matching Windows crash event.
- Evidence: `DLSS super-resolution persistent evaluate probe succeeded from RenderGraph GetTexture: DLSS persistent evaluate probe completed via SDK wrapper ProjectID; appId=0; init=0x00000001; capability=0x00000001; available=1(result=0x00000001); render=426x284; target=720x480; perfQuality=0; flags=0x00000040; jitter=(0.0000,0.0000); mvScale=(1.0000,1.0000); sharpness=0.0000; reset=1; evaluateCount=3; evaluateSuccesses=3; create=0x00000001; feature=yes; evaluateLast=0x00000001; release=0x00000001; destroy=0x00000001; shutdown=0x00000001`.
- Follow-up evidence observed `Edge Adaptive Spatial Upsampling` with the same native pointer after repeated evaluate and D3D11 probe success. This proves one DLSS feature can persist across repeated evaluates on the real SR-sized tuple, but visible write-back/image correctness still require the normal-user rendering path.

## Stage 9A: DLSS Super Resolution Frame-Sequence Evaluate Diagnostic

Implemented and locally game-runtime validated with the SDK-wrapper research native build.

Scope:

- Config key: `Diagnostics.EnableDlssSuperResolutionFrameSequenceEvaluateProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-super-resolution-frame-sequence`.
- Waits for Stage 8E to accept a render-input-smaller-than-output tuple.
- Calls the stateful SDK-wrapper `VrisingDlss_EvaluateDlssFrameSequence` path against that SR tuple.
- Creates one DLSS feature on the first accepted callback, then reuses it across later RenderGraph callbacks until the target success count is reached.
- Calls `VrisingDlss_ShutdownDlssFrameSequence` after the diagnostic target is reached.
- Records the selected output resource/pointer and reuses Stage 8C output follow-up to confirm it remains D3D11-accessible after cross-callback evaluate.
- Release-safe native builds report blocked because `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=OFF` by default.
- This is still diagnostic-only. It does not make `DLSS.EnableDLSS=true` a normal-user rendering path.

Pass criteria:

- Stage 8E passes in the same run.
- The first sequence status reports `recreated=yes`, `sequenceCreates=1`, and `sequenceEvaluates=1`.
- Later sequence statuses report `recreated=no` while `sequenceEvaluates` advances.
- The native status reaches `sequenceEvaluates=3` and `evaluateSuccesses=3`.
- Shutdown reports `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
- The selected output remains D3D11-accessible in follow-up `GetTexture` callbacks.
- Game does not black-screen or crash.

Current Stage 9A status:

- Runtime validation against V Rising passed on 2026-06-05 in a 170-second scripted `dlss-super-resolution-frame-sequence` run with no matching Windows crash event.
- Runtime validation also passed in a later 190-second scripted `dlss-persistent-evaluate` full-chain run on 2026-06-05, with Stage 8A through Stage 9A passing in one archived log.
- Evidence: first callback `recreated=yes`, `sequenceCreates=1`, `sequenceEvaluates=1`, `evaluateSuccesses=1`, `render=426x284`, `target=720x480`, `feature=yes`, and `evaluateLast=0x00000001`.
- Evidence: later callbacks reported `recreated=no`, then reached `sequenceEvaluates=3` and `evaluateSuccesses=3`.
- Evidence: shutdown succeeded with `hadSession=yes`, `sequenceCreates=1`, `sequenceEvaluates=3`, `evaluateSuccesses=3`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
- Follow-up evidence observed `Edge Adaptive Spatial Upsampling` with the same native pointer after the frame-sequence evaluate and D3D11 probe success. This proves one DLSS feature can survive across multiple RenderGraph callbacks for the real SR-sized tuple, but visible write-back/image correctness still require the normal-user rendering path.

## Stage 10A: DLSS Visible Write-back Candidate Diagnostic

Implemented and locally game-runtime validated with the SDK-wrapper research native build.

Scope:

- Config key: `Diagnostics.EnableDlssVisibleWritebackProbe=false` by default.
- Helper stage: `scripts\run-vrising-diagnostic.ps1 -Stage dlss-visible-writeback`.
- Waits for Stage 8E to accept a render-input-smaller-than-output tuple.
- Uses the stateful SDK-wrapper `VrisingDlss_EvaluateDlssFrameSequence` path against that SR tuple.
- Repeatedly evaluates into the selected output target, currently `Edge Adaptive Spatial Upsampling` when the known SR tuple is accepted, across multiple RenderGraph callbacks.
- Runs for a higher target count than Stage 9A, then calls `VrisingDlss_ShutdownDlssFrameSequence`.
- Records the selected output resource/pointer and reuses Stage 8C output follow-up to confirm it remains D3D11-accessible.
- Release-safe native builds report blocked because `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=OFF` by default.
- This is still diagnostic-only. It does not make `DLSS.EnableDLSS=true` a normal-user rendering path, and it does not by itself prove visual image correctness.

Pass criteria:

- Stage 8E passes in the same run.
- The native status reports `render` smaller than `target`.
- The sequence reaches `sequenceEvaluates=30` and `evaluateSuccesses=30` without recreating every callback.
- Shutdown reports `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
- The selected output remains D3D11-accessible in follow-up `GetTexture` callbacks.
- Game does not black-screen or crash.

Current Stage 10A status:

- Runtime validation against V Rising passed on 2026-06-05 in a 220-second scripted `dlss-visible-writeback` run with no matching Windows crash event.
- Evidence: Stage 8E accepted `CameraColor`, `CameraDepthStencil`, and `Motion Vectors` at `426x284` with `Edge Adaptive Spatial Upsampling` at `720x480`, all on the same D3D11 device.
- Evidence: first visible-path callback created the sequence with `recreated=yes`, `sequenceCreates=1`, `sequenceEvaluates=1`, `evaluateSuccesses=1`, `render=426x284`, `target=720x480`, `feature=yes`, and `evaluateLast=0x00000001`.
- Evidence: later callbacks reported `recreated=no`, then reached `sequenceEvaluates=30` and `evaluateSuccesses=30`.
- Evidence: shutdown succeeded with `hadSession=yes`, `sequenceCreates=1`, `sequenceEvaluates=30`, `evaluateSuccesses=30`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
- Follow-up evidence observed `Edge Adaptive Spatial Upsampling` with the same native pointer after the visible write-back candidate and D3D11 probe success. This proves the guarded visible-path candidate can repeatedly evaluate into the selected SR output target. A later 4K Stage 10A gameplay comparison produced valid baseline/candidate screenshots, but the MVP visual gate remains blocked on a normal-user `dlss-user-rendering` gameplay visual/performance comparison plus matching human review.

## Visual Validation Helpers

Added local-only helpers for the next validation step:

- `scripts\capture-vrising-window.ps1` captures the current V Rising client window to `artifacts\visual-validation`.
- `scripts\inspect-vrising-visibility.ps1` performs a lightweight read-only preflight that reports whether the `VRising` process is missing, process-only, or likely exposing a visible game window before a coordinated capture.
- `scripts\compare-image-artifacts.ps1` compares two captured PNGs and writes a bounded summary with dimensions, sampled RGB/luma deltas, near-black/near-white ratios, and hashes.
- `scripts\get-visual-validation-status.ps1` reads paired comparisons and reports whether they are strong enough for the requested visual gate. It requires gameplay-resolution captures, candidate DLSS evidence log, baseline/candidate performance summaries, and a matching human review JSON before returning `Pass`. It recognizes both Stage 10A `baseline-vs-stage10a` comparisons and normal-user `baseline-vs-user-rendering` comparisons; use `-RequiredCandidateStage dlss-user-rendering` for release readiness.
- `scripts\write-visual-review.ps1` generates that human review JSON from a comparison artifact, binding the review to the exact baseline/candidate image SHA-256 values.
- `docs\development\measurement-plan.md` records the source-backed measurement rules and review-file template.

These helpers launch no game process and write only ignored local artifacts. They are intended to catch gross visual regressions such as black frames, capture failures, or obvious write-back problems. They are not by themselves proof of DLSS image quality or final user-facing rendering correctness.

Current visual smoke status:

- Baseline loader capture on 2026-06-05 used the `UnityWndClass` V Rising window at `480x320`, minimized one BepInEx console window, fell back from `PrintWindow` to `ScreenCopy`, and produced a nonblank/nonwhite PNG.
- Stage 10A `dlss-visible-writeback` capture on 2026-06-05 used the same `UnityWndClass` route and produced a nonblank/nonwhite PNG while the Stage 10A log reached `sequenceSuccesses=30/30`.
- Baseline-vs-Stage-10A static main-menu comparison matched dimensions (`480x320`) and had `MeanAbsRgbDelta=0`, `MaxAbsRgbDelta=0`, and identical SHA-256 hashes for that screen state.
- This is a visual smoke test only. It proves the screenshot path and confirms no gross main-menu visual failure during the guarded visible write-back diagnostic. It does not yet prove gameplay image correctness, DLSS quality, resize/reset behavior, or the normal-user `DLSS.EnableDLSS=true` rendering path.

## Gameplay Visual Comparison Helper

Added `scripts\run-vrising-visual-comparison.ps1` as the repeatable local/private gameplay validation harness for the next MVP gate.

Scope:

- Runs a baseline loader-stage capture, a Stage 10A `dlss-visible-writeback` capture, or both.
- Launches V Rising visibly and gives the tester either a fixed window or a manual ready-file trigger to enter the same local/private gameplay scene before capture.
- Uses `scripts\capture-vrising-window.ps1` for each capture, then uses `scripts\compare-image-artifacts.ps1` for paired baseline/candidate summaries.
- Archives each run's BepInEx log and matching Windows Application Error events.
- Restores the release-safe native DLL and loader config after each run, including after the SDK-wrapper Stage 10A candidate.
- Writes only ignored local artifacts under `artifacts\runtime-logs` and `artifacts\visual-validation`.
- Records a lightweight `VisibilityPreflightStatus` immediately before each screenshot so failed runs can distinguish "game process/window not visible to Codex" from rendering or capture failures.
- Stage 10A candidate visual runs default to `KeepDlssVisibleWritebackProbeRunning=true` and `WaitForStage10A=true`, so screenshots wait for the `sequenceSuccesses=30/30` milestone while the visible write-back candidate keeps evaluating until cleanup. Normal-user candidate visual runs can use `-CandidateStage dlss-user-rendering`; screenshots wait for a successful user-rendering evaluate when `WaitForUserRendering=true`.
- Performance capture is enabled by default when `C:\Software\PresentMon\PresentMon-2.4.1-x64.exe` is available. Each baseline/candidate run writes PresentMon frame CSV, CPU/GPU metrics CSV, and a readable FPS/CPU/GPU summary under `artifacts\fps-validation`.
- `-AttachExistingBaseline` can attach to a V Rising process that the tester already launched for the baseline run. This is read-only before capture and is useful when the tester has already entered the target scene manually.
- For the preferred constructive shape, use `-SetClientResolution
  -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080`. The helper
  temporarily writes `ClientSettings.json`, launches with matching screen arguments,
  and restores the original settings during cleanup.

Example dry run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-visual-comparison.ps1 -GamePath "C:\Software\VRising" -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll" -DryRun
```

Example paired gameplay run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-visual-comparison.ps1 -GamePath "C:\Software\VRising" -DurationSeconds 240 -CaptureAtSeconds 170 -CapturePerformance:$true -WaitForStage10A:$true -KeepCandidateWritebackRunning:$true -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll"
```

Example manual-ready paired gameplay run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-visual-comparison.ps1 -GamePath "C:\Software\VRising" -CandidateStage dlss-user-rendering -FsrMode Off -ManualCapture -ReadyFile "Z:\VrisingDLSS\artifacts\visual-validation\ready.txt" -ReadyTimeoutSeconds 900 -CaptureAtSeconds 150 -CapturePerformance:$true -WaitForUserRendering:$true -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll" -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Use `-FsrMode Performance` only for explicitly labeled transition diagnostics. Those runs can prove the DLSS evaluate path against an HDRP Super Resolution tuple, but they cannot satisfy the MVP product-value comparison because V Rising's built-in FSR is participating in the render-scale change.

When `-ManualCapture` is used, the tester enters the matching local/private scene and then creates the ready file. Capture waits for the ready file and will not fire before `-CaptureAtSeconds`, which keeps the candidate from being captured before its evidence line and scene warm-up are ready.

Example attached baseline run after the tester has already launched the game and entered the target scene:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-visual-comparison.ps1 -GamePath "C:\Software\VRising" -Mode BaselineOnly -AttachExistingBaseline -CaptureAtSeconds 5 -CapturePerformance:$true -PerformanceSeconds 30
```

Create the ready file from another PowerShell session, or let Codex create it after the tester says the scene is ready:

```powershell
New-Item -ItemType File -Force -Path "Z:\VrisingDLSS\artifacts\visual-validation\ready.txt"
```

For tester-coordinated runs, check visibility before creating the ready file:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-visibility.ps1 -GamePath "C:\Software\VRising" -Json
```

If `Status` is not `VisibleGameWindow`, do not capture yet; fix focus/process visibility first so the screenshot and PresentMon sample bind to the actual game.

This helper still does not make the mod MVP-ready. Stage 10A runs are controlled diagnostic evidence for the visible write-back candidate; the MVP visual/performance gate now requires a normal-user `dlss-user-rendering` paired gameplay comparison.

After a paired run, inspect readiness with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\get-visual-validation-status.ps1 -RequiredCandidateStage dlss-user-rendering
```

The current readiness gate intentionally treats the existing Stage 10A and `480x320` main-menu smoke comparisons as insufficient for MVP, because they are diagnostic or harness smoke evidence rather than normal-user `DLSS.EnableDLSS=true` gameplay image-correctness evidence.

Current helper smoke status:

- A `BaselineOnly` smoke run on 2026-06-05 launched V Rising, captured the `UnityWndClass` game window through the helper, archived the BepInEx log, reported no matching Windows crash event, closed the game, and restored the release-safe native DLL plus loader config.
- A `CandidateOnly` smoke run on 2026-06-05 copied the local SDK-wrapper native DLL, launched Stage 10A `dlss-visible-writeback`, reached `sequenceSuccesses=30/30`, captured the `UnityWndClass` game window, reported no matching Windows crash event, closed the game, and restored the release-safe native DLL plus loader config.
- The helper smoke PNGs matched dimensions (`480x320`) and had `MeanAbsRgbDelta=0`, `MaxAbsRgbDelta=0`, and identical SHA-256 hashes for the static main-menu state. This remains a harness smoke test, not gameplay image-correctness proof.
- A manual-ready `BaselineOnly` smoke run on 2026-06-05 used a ready file to trigger capture, captured successfully after the ready marker appeared, reported child script exit code `0`, archived logs, closed the game, reported no matching Windows crash event, and restored the release-safe native DLL plus loader config.
- A later `CandidateOnly` smoke run on 2026-06-05 used `WaitForStage10A=true` and hold mode. The helper waited until the BepInEx log contained `sequenceSuccesses=30/30`, captured while `keepRunning=True`, archived logs, reported no matching Windows crash event, closed the game, and restored the release-safe native DLL plus loader config.
- A 4K high-settings baseline performance sample on 2026-06-05 captured 30 seconds of PresentMon data and CPU/GPU metrics, reporting `AverageFps=74.861`, `OnePercentLowFps=55.49`, `AverageProcessCpuPercent=3.496`, `AverageGpuUtilPercent=100`, and `AverageGpuMemoryUsedMb=6864.667`. Its initial visual screenshot was rejected as a `PrintWindow` near-binary black/white false frame, and the capture helper now falls back to `ScreenCopy` for that pattern.
- A DPI-aware 4K high-settings manual-ready baseline on 2026-06-05 captured the physical `3840x2160` V Rising client window with `DpiAwareness=PerMonitorV2`, `AverageFps=75.189`, `OnePercentLowFps=68.712`, `P95FrameMs=14.107`, `AverageGpuUtilPercent=100`, and `AverageGpuMemoryUsedMb=6988.714`.
- The paired Stage 10A candidate for that same native-4K setting did not reach the visible write-back milestone before cleanup. The BepInEx log repeatedly reported `DLSS super-resolution input probe not accepted: output was not larger than render input; color=3840x2160 output=3840x2160`. This is a negative-control result: with V Rising's built-in `FsrQualityMode=Off`, the game rendered natively at 4K, so there was no Super Resolution tuple for DLSS to upscale.
- A follow-up manual-ready paired run temporarily set V Rising's built-in `FsrQualityMode=Performance` to force an upscale route, then restored the setting afterward. The baseline capture was a physical `3840x2160` gameplay screenshot with `AverageFps=159.851`, `OnePercentLowFps=131.246`, `P95FrameMs=7.168`, `AverageGpuUtilPercent=76.5`, and `AverageProcessCpuPercent=6.162`.
- The matching Stage 10A candidate accepted a `1920x1080 -> 3840x2160` Super Resolution tuple, reached `sequenceSuccesses=30/30`, and produced a valid physical `3840x2160` gameplay screenshot. The baseline-vs-candidate comparison reported `MeanAbsRgbDelta=0.66`, `ChangedRatioGt10=0.006402`, and matching dimensions.
- Candidate performance in that diagnostic hold-mode run was `AverageFps=45.982`, `OnePercentLowFps=29.982`, `P95FrameMs=29.648`, `AverageGpuUtilPercent=100`, and `AverageProcessCpuPercent=3.356`. Treat this as diagnostic overhead from repeated visible write-back proof, not as normal-user DLSS performance. The next rendering step is a persistent user path with one DLSS evaluate per frame and explicit resize/settings cleanup.
- The first `dlss-user-rendering` release-safe smoke run on 2026-06-05 proved `DLSS.EnableDLSS=true` installs the crash-safe RenderGraph route and starts the user-rendering candidate. With V Rising's built-in FSR Off, the run had no crash event and restored loader config, but no Super Resolution tuple was accepted because `CameraColor` and output were both `3840x2160`.
- A follow-up `dlss-user-rendering` release-safe smoke run temporarily set V Rising's built-in `FsrQualityMode=Performance`, accepted a `1920x1080 -> 3840x2160` tuple, attempted the user-rendering evaluate once, received the expected release-safe native response `blocked: native bridge was built without NVIDIA SDK wrapper integration`, disabled the candidate for the session, reported no matching Windows crash event, restored loader config, and restored `FsrQualityMode=Off`.
- The v6 `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606` run passed this route under V Rising `FsrQualityMode=Off`: the mod-owned dynamic-resolution handler intervention produced `CameraColor/Depth/Motion=960x540`, output `1920x1080`, and repeated SDK-wrapper `DLSS user rendering evaluate succeeded` lines with `sequenceCreates=1`.
- The first 1080p Windowed v6 visual/performance comparison,
  `v6-user-rendering-1080p-auto-visual-20260606-r2`, then produced valid baseline and
  candidate gameplay captures at `1920x1080`, waited for user-rendering evaluate
  success, and compared matching screenshots. It failed readiness because candidate
  performance regressed severely: average FPS `203.617 -> 80.242`, 1% low FPS
  `156.078 -> 58.688`, P95 frame time `5.947 ms -> 14.775 ms`, and average GPU
  utilization `97.5% -> 43.444%`.
- The timing follow-up `v6-user-rendering-1080p-timing-20260606-r3` then proved
  `DLSS user rendering evaluate succeeded` is not enough and also showed the stable
  native evaluate CPU call is not the sustained 11 ms frame-time source. The next
  rendering step is to isolate the v6 render-scale/HDRP path without DLSS evaluate.
- The render-scale-only comparison `render-scale-only-1080p-20260606-r1` completed
  that isolation: active `0.5` scale without DLSS evaluate kept average FPS near
  baseline. The next rendering step is to isolate the `dlss-user-rendering` hot
  RenderGraph discovery hook from native evaluate/writeback, or move evaluation into a
  real render/upscale pass boundary.
- The protected gameplay proof
  `native-renderfunc-resource-d3d11-render-scale-gameplay-1080p-20260607-r1`
  moved the boundary search closer to official HDRP DLSS execution. With V Rising
  `FsrQualityMode=Off`, true `1920x1080` Windowed, and mod-owned render scale, the
  focused EASU source/destination native pointers validated as same-device D3D11
  textures: `source=960x540`, `destination=1920x1080`, `fmt=26`, and
  `scale=(2.000x,2.000x)`. The run kept broad `RenderGraph.GetTexture`,
  command-buffer access, NGX, and DLSS evaluate disabled; cleanup restored loader
  config/native/ClientSettings and the protected save with `ChangeCount=0`. The next
  rendering step should be source/decompilation-guided command-buffer boundary
  validation near `DoDLSSPass -> DLSSPass.GetCameraResources ->
  DLSSPass.Render(..., ctx.cmd)`, not another broad resource-discovery hook.
- The protected gameplay proof
  `native-renderfunc-context-render-scale-gameplay-1080p-20260607-r1` then
  validated the next source-guided boundary guard. With V Rising
  `FsrQualityMode=Off`, true `1920x1080` Windowed, and mod-owned render scale,
  the focused EASU native render-func callback safely wrapped the raw
  `RenderGraphContext` pointer and read a live `ctx.cmd` identity. Evidence:
  `Native RenderFunc Context=Pass`, `Native render-func context advanced:
  sampleCount=1; nonzeroContext=1; wrapSuccess=1; cmdNonNull=1;
  cmdPointerNonZero=1; wrapFailures=0`, and final context status
  `entryCount=6699`, `sampleCount=6699`, `cmdPointerNonZero=6699`,
  `wrapFailures=0`. The same run preserved the EASU
  `tuple=input=960x540; output=1920x1080`, kept broad
  `RenderGraph.GetTexture`, native-pointer/D3D11 probes, NGX, DLSS evaluate,
  and user-rendering disabled, reported `CrashEventCount=0`, restored
  config/native/ClientSettings, left no game process, and restored the
  protected save with `ChangeCount=0`. The next guard should be a separate
  no-op command-buffer/plugin-event timing proof at this same boundary; still
  do not combine DLSS evaluate in the same step.
- The protected gameplay proof
  `native-renderfunc-commandbuffer-event-render-scale-gameplay-1080p-20260607-r1`
  validated that separate timing guard. With V Rising `FsrQualityMode=Off`, true
  `1920x1080` Windowed, and mod-owned render scale, the focused EASU native
  render-func callback issued exactly one native no-op plugin event through the
  live `RenderGraphContext.cmd`. Analyzer reported `Native RenderFunc
  CommandBuffer Event=Pass`, `Native RenderFunc Context=Pass`, `Native
  RenderFunc Resource Tuple=Pass`, `Stage 2C Render-Scale Control Probe=Pass`,
  and native bridge API version `13`. Evidence preserved the EASU
  `tuple=input=960x540; output=1920x1080`, read
  `lastCmd=0x243BCB10E40`, and logged `Native render-func command-buffer event
  advanced: issueAttempts=1; issueSuccesses=1; issueFailures=0; beforeCount=0;
  currentCount=1; lastEventId=260607`. Final sampled status reached
  `callbackReached=True`. The run kept broad `RenderGraph.GetTexture`,
  native-pointer/D3D11 probes, NGX, DLSS evaluate, and user-rendering disabled;
  reported `CrashEventCount=0`; restored config/native/ClientSettings; left no
  game process; and restored the protected save with `ChangeCount=0`. The next
  guard should be driven by local IL2CPP/HDRP decompilation/static xrefs and
  prove a minimal native callback payload/lifecycle at this same boundary,
  still without DLSS evaluate or visible write-back.
- The protected gameplay proof
  `native-renderfunc-commandbuffer-payload-render-scale-gameplay-1080p-20260607-r1`
  validated that payload/lifecycle guard. Native bridge API version is now
  `14`. With V Rising `FsrQualityMode=Off`, true `1920x1080` Windowed, and
  mod-owned render scale, the focused EASU source/output native texture
  pointers were set as a native pending payload and consumed from one
  command-buffer-issued plugin event with `eventId=260608`. Analyzer reported
  `Native RenderFunc CommandBuffer Payload=Pass`, `Native RenderFunc
  Context=Pass`, `Native RenderFunc Resource Native Pointer=Pass`, `Native
  RenderFunc Resource Tuple=Pass`, and `Stage 2C Render-Scale Control
  Probe=Pass`. Evidence preserved `tuple=input=960x540; output=1920x1080`,
  `issueSuccesses=1`, `consumed=1`, `lastEventId=260608`, `sameDevice=yes`,
  `source=960x540 fmt=26`, `destination=1920x1080 fmt=26`, and
  `scale=(2.000x,2.000x)`. The run kept broad `RenderGraph.GetTexture`, the
  separate native D3D11 pair probe, NGX, DLSS evaluate, and user-rendering
  disabled; reported `CrashEventCount=0`; restored config/native/ClientSettings;
  left no game process; and restored the protected save with `ChangeCount=0`.
  The next runtime guard should remain source/decompilation-guided and either
  find depth/motion-vector payloads at an equivalent official boundary or add a
  local SDK-wrapper-only DLSS frame-sequence lifecycle preflight at this exact
  callback boundary before any visible write-back.
- The menu and protected gameplay proof
  `native-renderfunc-commandbuffer-dlss-create-render-scale-1080p-gameplay-20260607-r1`
  validated that SDK-wrapper-only NGX feature lifecycle guard. Native bridge API
  version is now `15`. With V Rising `FsrQualityMode=Off`, true `1920x1080`
  Windowed, and mod-owned render scale, the focused EASU source/output native
  texture pointers were set as a native pending payload and consumed from one
  command-buffer-issued plugin event with `eventId=260609`; the native callback
  then created and immediately released/destroyed/shut down one NGX DLSS
  feature. Menu smoke passed first with `Native RenderFunc CommandBuffer DLSS
  Feature Create=Pass`, `create=0x00000001`, `feature=yes`,
  `release=0x00000001`, `destroy=0x00000001`, `shutdown=0x00000001`, no
  `ExecuteDLSS`, no user rendering, no visible write-back, and
  `CrashEventCount=0`. Protected gameplay proof then passed after Computer Use
  clicked Continue once and sent no movement keys. Analyzer reported `Stage 2C
  Render-Scale Control Probe=Pass`, `Native RenderFunc Context=Pass`, `Native
  RenderFunc CommandBuffer DLSS Feature Create=Pass`, `Native RenderFunc
  Resource Tuple=Pass`, and `Native RenderFunc Resource Native Pointer=Pass`.
  Key evidence preserved `actualWidth=960`, `actualHeight=540`,
  `GetCurrentScale=0.5`, `GetResolvedScale=(0.50, 0.50)`,
  `sameDevice=yes`, `source=960x540 fmt=26`, `destination=1920x1080 fmt=26`,
  `scale=(2.000x,2.000x)`, and feature status `init=0x00000001`,
  `capability=0x00000001`, `available=1`, `create=0x00000001`,
  `feature=yes`, `release=0x00000001`, `destroy=0x00000001`,
  `shutdown=0x00000001`. Counts: feature-create advanced `1`,
  feature-create set advanced `1`, consumed-status lines `111`, create
  failures `0`, SDK-wrapper-blocked lines `0`, broad `RenderGraph.GetTexture`
  `0`, `ExecuteDLSS` `0`, `DLSS user rendering` `0`, visible write-back `0`,
  and crash/exception/access-violation patterns `0`. Cleanup restored
  config/native/ClientSettings, left no game process, and restored the
  protected save with `ChangeCount=0`. This proves NGX feature create/release
  can ride the source-guided EASU command-buffer callback boundary, but still
  does not prove depth/motion-vector payload, DLSS evaluate, resize/reset
  behavior, visual correctness, legal runtime distribution, or performance.
- The protected gameplay proof
  `hdrp-postprocess-render-args-global-textures-render-scale-gameplay-1080p-20260607-r1`
  validated the low-resolution input side at the ProjectM/HDRP custom
  postprocess boundary. The new default-off
  `Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe=false` switch
  patches only `DarkForeground.Render(CommandBuffer, HDCamera, RTHandle,
  RTHandle)` and reads `Shader.GetGlobalTexture("_CameraDepthTexture")` plus
  `Shader.GetGlobalTexture("_CameraMotionVectorsTexture")` native pointers; it
  does not call RenderGraph `GetTexture`, issue command-buffer work, run D3D11
  validation, initialize NGX, evaluate DLSS, or write visible output. With V
  Rising `FsrQualityMode=Off`, true `1920x1080` Windowed, and mod-owned render
  scale, analyzer reported `Stage 2C Render-Scale Control Probe=Pass`,
  `HDRP PostProcess Render Args=Pass`, and `HDRP PostProcess Render Args Global
  Textures=Pass`. Evidence: `camera.actualWidth=960`, `actualHeight=540`,
  `CameraColor_960x540`, `CustomPostProcesDestination_960x540`,
  `_CameraMotionVectorsTexture=Motion Vectors_960x540` with native pointer, and
  depth stabilizing to `CameraDepthStencil_960x540` with native pointer. Broad
  `RenderGraph.GetTexture`, D3D11, NGX, DLSS evaluate/writeback, crash, and
  access-violation counts were zero. Cleanup restored config/native/
  ClientSettings, left no game process, and restored the protected save with
  `ChangeCount=0`. This solves the depth/motion visibility question for the
  low-resolution input side, but the custom-postprocess destination remains
  `960x540`; the next guard should correlate this boundary with the already
  proven EASU/native render-func `1920x1080` output boundary before any
  no-write evaluate or visible-output work.
- Follow-up stage `hdrp-easu-input-output-correlation-render-scale` is
  implemented as a default-off source-guided correlation preflight and
  protected-gameplay validated; see
  `docs/development/hdrp-easu-input-output-correlation-preflight-implementation-2026-06-07.md`.
  It combines the gameplay-proven `DarkForeground.Render(...)` global
  depth/motion snapshot with the focused EASU source/output native-pointer
  observation under mod-owned render scale. The stage intentionally keeps D3D11
  validation, command-buffer plugin events, NGX feature lifecycle, DLSS
  evaluate, user rendering, and visible write-back disabled. Static validation
  passed: all PowerShell scripts parsed, C# Release build succeeded with `0`
  warnings/errors, and dry-run config showed only the intended toggles. Runtime
  iteration `r1` correctly rejected stale EASU frame `4` versus HDRP frame
  `5281`; `r2` exposed a false-positive hazard where stale EASU tuple handles
  later resolved to `60x34` bloom/CoC resources, so pass criteria were tightened
  to require actual EASU source/destination observation dimensions. Protected
  gameplay proof `r3` passed at true `1920x1080` Windowed with V Rising
  `FsrQualityMode=Off`: analyzer reported `HDRP/EASU Input Output
  Correlation=Pass`, `HDRP PostProcess Render Args Global Textures=Pass`,
  `Native RenderFunc Resource Native Pointer=Pass`, and `Stage 2C Render-Scale
  Control Probe=Pass`. Key evidence preserved `hdrpFrame=3005`,
  `easuSourceFrame=3005`, `easuDestinationFrame=3005`, frame deltas `0`, HDRP
  color/depth/motion at `960x540`, EASU source `TAA Destination_960x540`, EASU
  destination `Edge Adaptive Spatial Upsampling_1920x1080`, and tuple
  `input=960x540; output=1920x1080`. Counts: correlation advanced `1`, broad
  `RenderGraph.GetTexture` `0`, D3D11 pair advanced/failed `0`, command-buffer
  event/payload advanced `0`, NGX `0`, `ExecuteDLSS` `0`, visible write-back
  `0`, crash/access-violation `0`, and save restore `ChangeCount=0`. See
  `docs/development/hdrp-easu-input-output-correlation-render-scale-gameplay-result-2026-06-07.md`.
- Follow-up stage `native-renderfunc-commandbuffer-frame-descriptor-render-scale`
  is implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-frame-descriptor-render-scale-preflight-implementation-2026-06-07.md`
  and
  `docs/development/native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-result-2026-06-07.md`.
  It carries the correlated EASU source/output pointers plus HDRP depth/motion
  pointers through one focused EASU `ctx.cmd` plugin event as a no-evaluate
  native frame descriptor. Native bridge API version is now `16`. Protected
  gameplay proof
  `native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1`
  passed at true `1920x1080` Windowed with V Rising `FsrQualityMode=Off` and
  mod-owned render scale. Analyzer reported `Native RenderFunc CommandBuffer
  Frame Descriptor=Pass`, `HDRP/EASU Input Output Correlation=Pass`, `HDRP
  PostProcess Render Args Global Textures=Pass`, `Native RenderFunc
  Context=Pass`, `Native RenderFunc Resource Tuple=Pass`, and `Native
  RenderFunc Resource Native Pointer=Pass`. Key evidence preserved
  `hdrpFrame=4110`, `easuSourceFrame=4110`, `easuDestinationFrame=4110`, frame
  deltas `0`, descriptor pointers for source/destination/depth/motion,
  `input=960x540`, `output=1920x1080`, `eventId=260610`, `consumed=1`,
  `validation=D3D11-not-queried`, `ngx=not-loaded`, and `evaluate=not-run`.
  Counts: descriptor advanced `1`, descriptor set advanced `1`,
  D3D11 pair advanced/failed `0`, broad `RenderGraph.GetTexture` `0`,
  `ExecuteDLSS` `0`, `DLSS user rendering` `0`, actual visible write-back `0`,
  crash/access-violation `0`, and save restore `ChangeCount=0`. This proves the
  four-pointer descriptor can be transported at the official-boundary-adjacent
  EASU command-buffer callback. It still does not prove D3D11 compatibility for
  all four resources, DLSS evaluate, resize/reset behavior, visual correctness,
  legal runtime distribution, or performance.
- Current route decision: DLSS itself does not depend on FSR. The final MVP validation must keep V Rising `FsrQualityMode=Off` for baseline and candidate, while the mod controls render scale/upscale through HDRP dynamic-resolution/DLSS-path integration. The next gate is no longer tuple existence; it is visual correctness, performance, resize/reset, fallback behavior, and release-boundary validation.
