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

The config helper writes `BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg` for a single diagnostic stage. The analyzer reads `BepInEx\LogOutput.log` and reports pass/fail/partial/missing evidence for stages 1-8A. The status helper combines preflight, config, log evidence, and the next recommended command.

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
- Patches ordinary HDRP/dynamic-resolution setter methods such as `HDRenderPipeline.SetUpscaleFilter`, `HDRenderPipeline.SetFSRParameters`, and `DynamicResolutionHandler.SetDynamicResScaler` with read-only postfixes.
- Logs snapshots from `HDRenderPipeline.GetUpscaleFilter()`, `HDRenderPipeline.GetUpscaleRes()`, and the current existing `DynamicResolutionHandler` instance fields/properties when available.
- Does not change the upscale filter, force FSR, inject RenderGraph passes, load DLSS, or evaluate DLSS.

Pass criteria:

- The initial snapshot logs without crashing.
- At least one relevant setter is patched when HDRP/Core RP exposes it.
- In a gameplay run, any FSR/upscale setter calls are capped and include a current state snapshot.

Evidence:

- `BepInEx/LogOutput.log` lines beginning with `Upscaler state probe snapshot`.
- Optional call lines beginning with `Upscaler state probe call`.

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
- Local static inspection confirms V Rising exposes HDRP FSR/upscale/DLSS landmarks, including `HDRenderPipeline.SetFSRParameters(float, bool)`, `GetUpscaleRes()`, `SetUpscaleFilter(DynamicResUpscaleFilter, float)`, `GetUpscaleFilter()`, `SetupDLSSForCameraDataAndDynamicResHandler(...)`, `GetPostprocessUpsampledOutputHandle(...)`, `DoDLSSPasses(...)`, `DoDLSSPass(...)`, and `DoTemporalAntialiasing(...)`. FSR1 is useful for locating the existing dynamic-resolution path, but it is not enough for DLSS because DLSS still needs aligned depth and motion-vector inputs.
- Current next route: keep Stage 8A's passive builder/resource discovery, `GetTexture` postfix, and the resource-materialization callback probe, but do not inject a new RenderGraph pass or patch compiler-generated render functions in normal diagnostics. Use Stage 2B to confirm V Rising's built-in dynamic-resolution/upscale state while continuing to use those symbols as landmarks.
- See `docs/research/stage8a-rendergraph-search-2026-06-05.md` for the official-source search that supports this route decision.

## Stage 8: First DLSS Evaluate

Not implemented yet.

Pass criteria:

- Depth, motion vectors, jitter, render size, and color buffers are frame-aligned.
- One DLSS evaluate path can be toggled on/off.
- Game does not black-screen or crash.
