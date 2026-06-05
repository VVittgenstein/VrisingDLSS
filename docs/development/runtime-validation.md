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

- The official `nvngx_dlss.dll` runtime from DLSS SDK `310.6.0` exposes D3D11 init/create/evaluate/release/shutdown and `NVSDK_NGX_D3D11_PopulateParameters_Impl`, but does not directly export `NVSDK_NGX_D3D11_AllocateParameters`, `NVSDK_NGX_D3D11_GetCapabilityParameters`, `NVSDK_NGX_D3D11_DestroyParameters`, or the public `NVSDK_NGX_Parameter_Set*`/`Get*` accessors.
- The official sample links the NVIDIA SDK wrapper library for `GetCapabilityParameters` and parameter-map helpers. The source-only/release-safe build therefore reports `Blocked`; use `scripts/probe-ngx-runtime-exports.ps1` to repeat the export-surface check offline.
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
- A scripted `dlss-evaluate-inputs` gameplay-attempt run on 2026-06-05 exited after about 13 seconds with Windows `APPCRASH` in `coreclr.dll` (`0xc0000005`). Before the crash it again observed RenderGraph declarations for `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer`, but no materialized native texture pointer. Because the log stopped after ordinary HDRP/RenderGraph prefix probes, ordinary `dlss-evaluate-inputs` now skips those broad prefix probes by default.
- A follow-up scripted run also exited early with the same `coreclr.dll` `0xc0000005` bucket after only the RenderGraph builder declaration, execution-scope, GetTexture postfix, and materialization probes were enabled. The log stopped at builder declaration #40 and did not show materialization/GetTexture callbacks, so ordinary `dlss-evaluate-inputs` now also skips builder declaration and execution-scope prefix/postfix probes by default.
- A later scripted `dlss-evaluate-inputs` run on 2026-06-05 limited ordinary Stage 8A to registry-level `BeginExecute(int)`, `CreateTextureCallback(RenderGraphContext, IRenderGraphResource)`, and the passive `GetTexture(TextureHandle&)` postfix. It ran for the full 75-second diagnostic window with no matching Windows crash event. The log reported `DLSS evaluate input probe succeeded from RenderGraph GetTexture` with same-device D3D11 resources: `CameraColor`, `Apply Exposure Destination`, `CameraDepthStencil`, and `Motion Vectors`, all at `720x480`.
- Local static inspection confirms V Rising exposes HDRP FSR/upscale/DLSS landmarks, including `HDRenderPipeline.SetFSRParameters(float, bool)`, `GetUpscaleRes()`, `SetUpscaleFilter(DynamicResUpscaleFilter, float)`, `GetUpscaleFilter()`, `SetupDLSSForCameraDataAndDynamicResHandler(...)`, `GetPostprocessUpsampledOutputHandle(...)`, `DoDLSSPasses(...)`, `DoDLSSPass(...)`, and `DoTemporalAntialiasing(...)`. FSR1 is useful for locating the existing dynamic-resolution path, but it is not enough for DLSS because DLSS still needs aligned depth and motion-vector inputs.
- Current next route: keep the accepted Stage 8A path limited to the `GetTexture` postfix plus resource-materialization callback probe by default. Stage 8B guarded SDK-wrapper DLSS evaluate, Stage 8C output follow-up, Stage 8D persistent repeated evaluate, Stage 8E Super Resolution input sizing, Stage 8F Super Resolution evaluate, Stage 8G Super Resolution persistent repeated evaluate, Stage 9A Super Resolution frame-sequence evaluate, and Stage 10A visible write-back candidate now have local runtime proof while `DLSS.EnableDLSS=false` remains the package default. The next work is screenshot/visual comparison, image-correctness validation, resize/reset, fallback behavior, and then a normal-user rendering path. Do not inject a new RenderGraph pass, patch compiler-generated render functions, patch ordinary HDRP render-resource prefix targets, or patch RenderGraph builder declaration methods in normal diagnostics.
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
- Follow-up evidence observed `Edge Adaptive Spatial Upsampling` with the same native pointer after the visible write-back candidate and D3D11 probe success. This proves the guarded visible-path candidate can repeatedly evaluate into the selected SR output target, but screenshot/visual comparison is still required before normal-user `DLSS.EnableDLSS` integration.

## Visual Validation Helpers

Added local-only helpers for the next validation step:

- `scripts\capture-vrising-window.ps1` captures the current V Rising client window to `artifacts\visual-validation`.
- `scripts\compare-image-artifacts.ps1` compares two captured PNGs and writes a bounded summary with dimensions, sampled RGB/luma deltas, near-black/near-white ratios, and hashes.
- `scripts\get-visual-validation-status.ps1` reads the latest paired comparison and reports whether it is strong enough for the MVP visual gate. It requires gameplay-resolution captures, Stage 10A log evidence, baseline/candidate performance summaries, and a matching human review JSON before returning `Pass`.
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
- Candidate visual runs default to `KeepDlssVisibleWritebackProbeRunning=true` and `WaitForStage10A=true`, so screenshots wait for the `sequenceSuccesses=30/30` milestone while the visible write-back candidate keeps evaluating until cleanup.
- Performance capture is enabled by default when `C:\Software\PresentMon\PresentMon-2.4.1-x64.exe` is available. Each baseline/candidate run writes PresentMon frame CSV, CPU/GPU metrics CSV, and a readable FPS/CPU/GPU summary under `artifacts\fps-validation`.
- `-AttachExistingBaseline` can attach to a V Rising process that the tester already launched for the baseline run. This is read-only before capture and is useful when the tester has already entered the target scene manually.

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
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-visual-comparison.ps1 -GamePath "C:\Software\VRising" -ManualCapture -ReadyFile "Z:\VrisingDLSS\artifacts\visual-validation\ready.txt" -ReadyTimeoutSeconds 900 -CaptureAtSeconds 150 -CapturePerformance:$true -WaitForStage10A:$true -KeepCandidateWritebackRunning:$true -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll"
```

When `-ManualCapture` is used, the tester enters the matching local/private scene and then creates the ready file. Capture waits for the ready file and will not fire before `-CaptureAtSeconds`, which keeps the Stage 10A candidate from being captured too early.

Example attached baseline run after the tester has already launched the game and entered the target scene:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-visual-comparison.ps1 -GamePath "C:\Software\VRising" -Mode BaselineOnly -AttachExistingBaseline -CaptureAtSeconds 5 -CapturePerformance:$true -PerformanceSeconds 30
```

Create the ready file from another PowerShell session, or let Codex create it after the tester says the scene is ready:

```powershell
New-Item -ItemType File -Force -Path "Z:\VrisingDLSS\artifacts\visual-validation\ready.txt"
```

This helper still does not make the mod MVP-ready. It is the controlled evidence path for deciding whether Stage 10A is actually visible and image-correct in gameplay before building a normal-user `DLSS.EnableDLSS=true` route.

After a paired run, inspect readiness with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\get-visual-validation-status.ps1
```

The current readiness gate intentionally treats the existing `480x320` main-menu smoke comparisons as `Blocked`, not `Pass`, because they are harness smoke evidence rather than gameplay image-correctness evidence.

Current helper smoke status:

- A `BaselineOnly` smoke run on 2026-06-05 launched V Rising, captured the `UnityWndClass` game window through the helper, archived the BepInEx log, reported no matching Windows crash event, closed the game, and restored the release-safe native DLL plus loader config.
- A `CandidateOnly` smoke run on 2026-06-05 copied the local SDK-wrapper native DLL, launched Stage 10A `dlss-visible-writeback`, reached `sequenceSuccesses=30/30`, captured the `UnityWndClass` game window, reported no matching Windows crash event, closed the game, and restored the release-safe native DLL plus loader config.
- The helper smoke PNGs matched dimensions (`480x320`) and had `MeanAbsRgbDelta=0`, `MaxAbsRgbDelta=0`, and identical SHA-256 hashes for the static main-menu state. This remains a harness smoke test, not gameplay image-correctness proof.
- A manual-ready `BaselineOnly` smoke run on 2026-06-05 used a ready file to trigger capture, captured successfully after the ready marker appeared, reported child script exit code `0`, archived logs, closed the game, reported no matching Windows crash event, and restored the release-safe native DLL plus loader config.
- A later `CandidateOnly` smoke run on 2026-06-05 used `WaitForStage10A=true` and hold mode. The helper waited until the BepInEx log contained `sequenceSuccesses=30/30`, captured while `keepRunning=True`, archived logs, reported no matching Windows crash event, closed the game, and restored the release-safe native DLL plus loader config.
- A 4K high-settings baseline performance sample on 2026-06-05 captured 30 seconds of PresentMon data and CPU/GPU metrics, reporting `AverageFps=74.861`, `OnePercentLowFps=55.49`, `AverageProcessCpuPercent=3.496`, `AverageGpuUtilPercent=100`, and `AverageGpuMemoryUsedMb=6864.667`. Its initial visual screenshot was rejected as a `PrintWindow` near-binary black/white false frame, and the capture helper now falls back to `ScreenCopy` for that pattern.
- A DPI-aware 4K high-settings manual-ready baseline on 2026-06-05 captured the physical `3840x2160` V Rising client window with `DpiAwareness=PerMonitorV2`, `AverageFps=75.189`, `OnePercentLowFps=68.712`, `P95FrameMs=14.107`, `AverageGpuUtilPercent=100`, and `AverageGpuMemoryUsedMb=6988.714`.
- The paired Stage 10A candidate for that same native-4K setting did not reach the visible write-back milestone before cleanup. The BepInEx log repeatedly reported `DLSS super-resolution input probe not accepted: output was not larger than render input; color=3840x2160 output=3840x2160`. This is a negative-control result: with V Rising's built-in `FsrQualityMode=Off`, the game rendered natively at 4K, so there was no Super Resolution tuple for DLSS to upscale.
