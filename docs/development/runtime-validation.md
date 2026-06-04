# Runtime Validation Plan

This is the test progression for turning the scaffold into a usable DLSS mod.

## Stage 1: Loader Validation

Current local preflight:

- `C:\Software\VRising` is a readable V Rising `v1.1.13.0-r99712-b17` IL2CPP/HDRP build.
- The player assembly list includes HDRP, Core RP, `ProjectM`, `ProjectM.Camera`, and `UnityEngine.NVIDIAModule`.
- BepInExPack V Rising `1.733.2` has been staged into `C:\Software\VRising`.
- `VrisingDLSS.Plugin.dll` and `VrisingDLSS.Native.dll` have been copied into `C:\Software\VRising\BepInEx\plugins\VrisingDLSS`.
- A loader-stage config has been written to `C:\Software\VRising\BepInEx\config\dev.vrisingdlss.plugin.cfg`.
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

The config helper writes `BepInEx\config\dev.vrisingdlss.plugin.cfg` for a single diagnostic stage. The analyzer reads `BepInEx\LogOutput.log` and reports pass/fail/partial/missing evidence for stages 1-8A. The status helper combines preflight, config, log evidence, and the next recommended command.

## Stage 2: Hook Probe

Pass criteria:

- `EnableHookProbe=true`.
- Log shows loaded assembly count.
- Candidate HDRP types are found:
  - `CustomVignette`
  - `HDCamera`
  - `DynamicResolutionHandler`
  - `HDRenderPipeline`
- Candidate methods and signatures are logged.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Running read-only HDRP hook probe`.

## Stage 3: Read-Only Harmony Probe

Implemented as an optional diagnostic switch:

- Config key: `Diagnostics.EnableHarmonyCallProbe=false` by default.
- Uses reflection to call the Harmony runtime loaded by BepInEx, so the plugin does not add a compile-time Harmony dependency.
- Adds read-only prefixes to candidate HDRP methods and logs capped call counts plus argument summaries.
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

- The official `nvngx_dlss.dll` runtime from DLSS SDK `310.6.0` exposes D3D11 init/create/evaluate/release/shutdown and `NVSDK_NGX_D3D11_PopulateParameters_Impl`, but does not directly export `NVSDK_NGX_D3D11_GetCapabilityParameters`.
- The official sample links the NVIDIA SDK wrapper library for `GetCapabilityParameters` and parameter-map helpers. The source-only/release-safe build therefore reports `Blocked`.
- Re-running `dlss-init-query` with only a production `nvngx_dlss.dll` is expected to report `Blocked`, not `Pass`.
- A local MSVC SDK-wrapper research build passed Stage 6 with ProjectID init: `init=0x00000001`, `capability=0x00000001`, `available=1`, `needsUpdatedDriver=0`, `minDriver=470.0`, `featureInitResult=1`, `destroy=0x00000001`, `shutdown=0x00000001`.

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
- Runtime evidence is still missing. The previous all-low main-menu Stage 5C run found `_CameraDepthTexture`, but `_CameraMotionVectorsTexture` was `null`.
- The next runtime test should use a local/private gameplay scene before deciding whether a different HDRP hook point is required.

## Stage 8: First DLSS Evaluate

Not implemented yet.

Pass criteria:

- Depth, motion vectors, jitter, render size, and color buffers are frame-aligned.
- One DLSS evaluate path can be toggled on/off.
- Game does not black-screen or crash.
