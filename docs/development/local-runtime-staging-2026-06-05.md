# Local Runtime Staging - 2026-06-05

This records local staging progress for runtime validation. Stage 8B guarded DLSS evaluate, Stage 8C output follow-up, Stage 8D persistent repeated evaluate, Stage 8E Super Resolution input sizing, Stage 8F Super Resolution evaluate, Stage 8G Super Resolution persistent repeated evaluate, Stage 9A Super Resolution frame-sequence evaluate, and Stage 10A visible write-back candidate now have local proof. Normal-user DLSS rendering is not implemented yet.

## Inputs

- Game path: `C:\Software\VRising`
- V Rising version: `v1.1.13.0-r99712-b17 (202605251526)`
- Unity version: `2022.3.58f1`
- BepInExPack package: `BepInEx-BepInExPack_V_Rising-1.733.2`
- BepInExPack download URL: `https://thunderstore.io/package/download/BepInEx/BepInExPack_V_Rising/1.733.2/`

## Commands Run

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\Software\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\Software\VRising"
```

Result:

- 233 BepInExPack files copied.
- 0 existing files overwritten.
- Game was not launched.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\Software\VRising"
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\Software\VRising" -Stage loader
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1 -GamePath "C:\Software\VRising"
powershell -ExecutionPolicy Bypass -File scripts\get-runtime-validation-status.ps1 -GamePath "C:\Software\VRising"
```

Result:

- `VrisingDLSS.Plugin.dll` copied to `C:\Software\VRising\BepInEx\plugins\VrisingDLSS`.
- `VrisingDLSS.Native.dll` copied to `C:\Software\VRising\BepInEx\plugins\VrisingDLSS`.
- Loader-stage config written to `C:\Software\VRising\BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg`.
- `BepInExInstalled=True`.
- `PluginInstalled=True`.
- `ConfiguredStage=loader`.
- `InteropGenerated=False`.
- `LogExists=False`.
- Next recommendation: launch the staged local/offline test once, exit after BepInEx starts, then analyze `BepInEx\LogOutput.log`.

## Current State

The local test folder has been launched with BepInEx in a local/offline test environment. The game reached the main menu at all-low graphics settings during later diagnostic runs.

Current validated evidence:

- Stage 1 loader: pass. `VrisingDLSS 0.1.0 loaded.`
- Stage 2 hook probe: pass. `CustomVignette` was found in `ProjectM`; `HDRenderPipeline.UpdateShaderVariablesGlobalCB(HDCamera, CommandBuffer)` was found in HDRP.
- Stage 2B upscaler state probe: pass in a main-menu run. Initial HDRP upscale state was `GetUpscaleFilter=CatmullRom` and `GetUpscaleRes=100`. During startup V Rising called `HDRenderPipeline.SetFSRParameters(1, true)` and then `HDRenderPipeline.SetUpscaleFilter(EdgeAdaptiveScalingUpres, 0.59)`, after which the snapshot reported `GetUpscaleFilter=EdgeAdaptiveScalingUpres` and `GetUpscaleRes=58.999996`.
- Stage 4 native bridge: pass. Native bridge API version `11` is the current build-validated bridge API. Archived runtime logs through Stage 7 used API version `6`; Stage 8A pass evidence used API version `7`; Stage 8B/8C pass evidence used API version `8`; Stage 8D evidence initially used API version `9`; Stage 8E/8F/8G evidence used API version `10`.
- Stage 5A render thread: pass. `HDRenderPipeline.UpdateShaderVariablesGlobalCB` issued `CommandBuffer.IssuePluginEvent`; native callback count advanced to `1`.
- Stage 5B D3D11 texture: pass. Temporary `RenderTexture` pointer was recognized as a D3D11 resource/device.
- Stage 5C frame resources: pass. All-low main-menu run reached `HDRenderPipeline.UpdateShaderVariablesGlobalCB`; `_CameraDepthTexture` was found and D3D11-probed. `_CameraMotionVectorsTexture` was `null` in that scene/settings.
- Stage 5D DLSS runtime load/release: pass with official NVIDIA DLSS `310.6.0.0` runtime extracted under `ref/` for local research. The runtime exposes D3D11 init/create/evaluate/release/shutdown exports and `PopulateParameters_Impl`, but not the allocator/destroyer/capability-query/parameter-accessor exports needed for a source-only direct DLSS route.
- Stage 6 DLSS init/query:
  - Source-only/release-safe build reports `Blocked` when only the production `nvngx_dlss.dll` is available, because full capability query requires NVIDIA SDK wrapper integration.
  - Local MSVC SDK-wrapper research build passed with ProjectID init. Evidence: `init=0x00000001`, `capability=0x00000001`, `available=1`, `needsUpdatedDriver=0`, `minDriver=470.0`, `featureInitResult=1`, `destroy=0x00000001`, `shutdown=0x00000001`.
- Stage 7 DLSS feature create/release:
  - Local MSVC SDK-wrapper research build created and released a DLSS SuperSampling feature without evaluating a frame. Evidence: `render=1280x720`, `target=1920x1080`, `perfQuality=2`, `flags=0x00000040`, `create=0x00000001`, `feature=yes`, `release=0x00000001`, `destroy=0x00000001`, `shutdown=0x00000001`.
- Stage 8A DLSS evaluate inputs:
  - Main-menu runtime test started and was correctly classified as `Blocked`. The frame-resource hook patched `CustomVignette.Render` and `HDRenderPipeline.UpdateShaderVariablesGlobalCB`, but only `UpdateShaderVariablesGlobalCB(HDCamera, CommandBuffer)` was called in the observed main-menu run. That callback exposed an HDCamera exposure texture and a CommandBuffer, not two source/output render targets. `_CameraDepthTexture` appeared as a 720x720 D3D11 texture after the first callback; `_CameraMotionVectorsTexture` remained `null`.
  - The extended Stage 8A hook scanner found and patched nine additional `Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` candidates in the main-menu run: `VisualLineOfSightDebug`, `LineOfSightVision`, `BatFormFog`, `DarkForeground`, `LineOfSight`, `ProjectM.ContestAreaEffect`, HDRP `CustomPostProcessVolumeComponent`, `Compositor.AlphaInjection`, and `Compositor.ChromaKeying`. None of those candidates were observed as called before the main-menu run was stopped.
  - The RenderGraph scanner found and patched five HDRP candidate methods: `RenderCameraMotionVectors`, `BlitFinalCameraTexture`, `ResolveMotionVector`, `RenderPostProcess`, and `DoCustomPostProcess`.
  - Main-menu RenderGraph callbacks observed `RenderCameraMotionVectors`, `DoCustomPostProcess`, and `ResolveMotionVector`. The exposed `TextureHandle` names include `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer`.
  - `RenderGraph.m_Resources.GetTexture(TextureHandle&)` recognized those resources but threw because the texture was already released or not yet created at the Harmony prefix point. `GetTextureResource(ResourceHandle&)` returned a `TextureResource`, but no native `RTHandle`/`Texture` pointer was available from the prefix.
  - A follow-up change stopped calling `GetTexture(TextureHandle&)` from method prefixes and instead patches `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` with a read-only postfix. The postfix patched cleanly in a 45-second main-menu run, and no IL2CPP trampoline errors were produced after the direct prefix call was removed.
  - No successful `RenderGraph GetTexture call` was observed during that final main-menu window, so the postfix should next be tested in a local/private gameplay scene or at a RenderGraph execution delegate point.
  - A follow-up builder-declaration probe patched five `RenderGraphBuilder` methods: `UseColorBuffer`, `UseDepthBuffer`, `ReadTexture`, `WriteTexture`, and `ReadWriteTexture`.
  - The builder-declaration probe cleanly resolved resource names with `GetRenderGraphResourceName(ResourceHandle&)` in a 45-second main-menu run. Evidence includes `UseColorBuffer(CameraColor)`, `ReadTexture(CameraColor)`, `ReadTexture(CameraDepthStencil)`, `UseColorBuffer(Motion Vectors)`, `ReadTexture(Motion Vectors)`, and `ReadTexture(NormalBuffer)`.
  - This confirms the target resources are declared in HDRP RenderGraph passes; it still does not expose native texture pointers, so the next code path must execute inside a declared RenderGraph pass or execution delegate.
  - A `RenderGraph.PreRenderPassExecute` postfix probe patched cleanly, but no execution-scope calls were observed in two 45-second main-menu runs. This route may still be worth retesting in gameplay, but the main menu does not appear to traverse that managed wrapper.
  - A `RenderGraphPass<T>.Execute(RenderGraphContext)` open-generic prefix probe failed at patch time with `Type.ContainsGenericParameters`/late-bound generic field errors. That route should not be retried without a closed generic pass type.
  - A `TextureHandle` implicit-conversion postfix probe patched four conversion operators, but it immediately produced repeated IL2CPP trampoline `NullReferenceException` logs in the main menu. That probe was removed from source and should remain rejected unless a safer conversion-specific approach is proven.
  - A local-interop diagnostic RenderGraph pass using `AddRenderPass`/`SetRenderFunc` now injects and configures successfully. Evidence: `RenderGraph diagnostic pass configured ... hasRenderFunc=True; allowPassCulling=False`.
  - The diagnostic pass can be injected from `DoCustomPostProcess` arguments and from aggregated `RenderGraphBuilder` declarations once `CameraColor`, `CameraDepthStencil`, and `Motion Vectors` have all been observed in the same graph.
  - In repeated main-menu runs, the diagnostic pass is declared and configured but the render function is not observed as called. At that point, the diagnostic-pass route still needed a local/private gameplay-scene run or another known-executing graph path; main-menu evidence from that route was not sufficient.
  - A local/private gameplay run on 2026-06-05 configured/injected that diagnostic pass twice and then crashed `VRising.exe` in `coreclr.dll` with `0xc0000005` before the diagnostic render function logged. Evidence was archived from BepInEx and Windows Error Reporting. The diagnostic pass injection route is now considered high-risk and is disabled by default behind `Diagnostics.EnableRenderGraphDiagnosticPass=false`.
  - A later main-menu Stage 8A helper run with broad Harmony call logging enabled crashed `VRising.exe` in `coreclr.dll` with `0xc00000fd` after `DLSSPass.Render` logged hundreds of calls. Evidence was archived from BepInEx and Windows Error Reporting. This narrowed the helper configuration: `dlss-evaluate-inputs` no longer enables `Diagnostics.EnableHarmonyCallProbe`, and Harmony call probing now uses a conservative target list instead of the expanded HookProbe catalog.
  - A follow-up main-menu Stage 8A run with broad Harmony call logging disabled ran for the diagnostic window without a Windows crash event. It reached `Partial`: all safe RenderGraph materialization patches installed, but no `RenderGraph texture materialization #` or successful `RenderGraph GetTexture` callback was observed in the main-menu window.
  - Static inspection of `DLSSPass` found `ViewResourceHandles.source/output/depth/motionVectors/biasColorMask` and matching `CameraResources.resources` `Texture` fields. A targeted Harmony prefix on `DLSSPass.Render(Parameters, CameraResources, CommandBuffer)` was then tested and rejected: V Rising crashed in `UnityPlayer.dll` with `0x80000003` after patching and before any prefix call logged.
  - A separate main-menu run with `Diagnostics.EnableDlssPassResourceProbe=true` patched only `DLSSPass.GetViewResources` and `DLSSPass.GetCameraResources`, not `DLSSPass.Render`. The run stayed up for the diagnostic window and had no matching Windows Application Error event, but no `DLSSPass resource helper #` callback was observed before shutdown. This is patch-stability evidence for the helper route only; it is not Stage 8A resource-input evidence yet.
  - The default `dlss-evaluate-inputs` helper was then narrowed to registry-level `RenderGraphResourceRegistry.BeginExecute(int)`, `CreateTextureCallback(RenderGraphContext, IRenderGraphResource)`, the passive `GetTexture(TextureHandle&)` postfix, and upscaler/native D3D11 validation. It no longer enables ordinary frame-resource prefixes, RenderGraph builder declaration probes, execution-scope probes, broad Harmony call logging, diagnostic pass injection, or generated render-function patching.
  - A 75-second scripted local run completed without a matching Windows crash event after this narrowing.
  - After `GetTexture` candidate aggregation was added and broad `Final` output matching was removed, Stage 8A passed. Evidence: `DLSS evaluate input probe RenderGraph GetTexture candidate #1: color=CameraColor; output=Apply Exposure Destination; depth=CameraDepthStencil; motion=Motion Vectors`, followed by `DLSS evaluate input probe succeeded from RenderGraph GetTexture` with `sameDevice=yes` and `720x480` for color, output, depth, and motion.
- Stage 8B DLSS evaluate:
  - A 90-second scripted `dlss-evaluate` run on 2026-06-05 completed without a matching Windows crash event. The script closed V Rising after the diagnostic window and restored the loader config.
  - Evidence: `DLSS evaluate probe succeeded from RenderGraph GetTexture`, with SDK-wrapper ProjectID init/capability success, `render=720x480`, `target=720x480`, `perfQuality=0`, `flags=0x00000040`, `create=0x00000001`, `evaluate=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
  - This was one guarded evaluate call against the accepted real-frame resource tuple. It does not prove image correctness or normal-user DLSS rendering.
- Stage 8C DLSS output follow-up:
  - A follow-up build records the selected output resource name/native pointer after Stage 8B success and watches later engine-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` callbacks.
  - The same 2026-06-05 scripted run passed Stage 8C. Evidence: `DLSS evaluate output follow-up #1` observed `Apply Exposure Destination` again one `GetTexture` call later with `sameResourceName=True`, `samePointer=True`, and D3D11 probe success.
  - Later follow-up lines observed the same native pointer under downstream post-process resource names including `Prepped Motion Vectors` and `Uber Post Destination`, also with D3D11 probe success. This suggests the selected output participates in the post-process resource chain, but screenshot/image-correctness validation is still required.
- Stage 8D DLSS persistent evaluate:
  - A 105-second scripted `dlss-persistent-evaluate` run on 2026-06-05 completed without a matching Windows crash event. The script closed V Rising after the diagnostic window and restored the loader config.
  - The run also preserved Stage 8A/8B/8C/8E pass evidence in the same log.
  - Evidence: `DLSS persistent evaluate probe succeeded from RenderGraph GetTexture`, with SDK-wrapper ProjectID init/capability success, `render=720x480`, `target=720x480`, `perfQuality=0`, `flags=0x00000040`, `evaluateCount=3`, `evaluateSuccesses=3`, `create=0x00000001`, `feature=yes`, `evaluateLast=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
  - This proves one DLSS feature can survive repeated evaluate calls before release/shutdown. It still does not prove visible output/image correctness.
- Stage 8E DLSS Super Resolution inputs:
  - The same 105-second scripted `dlss-persistent-evaluate` run on 2026-06-05 completed without a matching Windows crash event and passed the new input-size gate.
  - The probe first rejected same-size tuples such as `720x480 -> 720x480`, then later accepted an SR-sized tuple from the passive RenderGraph `GetTexture` stream.
  - Evidence: `DLSS super-resolution input probe succeeded from RenderGraph GetTexture`, with `color=426x284`, `output=720x480`, `depth=426x284`, `motion=426x284`, `sameDevice=yes`, and `scale=(1.690x,1.690x)`.
  - The accepted output resource was `Edge Adaptive Spatial Upsampling`, confirming the existing HDRP/FSR dynamic-resolution output is useful as a DLSS Super Resolution target landmark. This still does not prove visible DLSS write-back.
- Stage 8F DLSS Super Resolution evaluate:
  - A 125-second scripted `dlss-persistent-evaluate` run on 2026-06-05 completed without a matching Windows crash event and passed the new SR evaluate gate.
  - Evidence: `DLSS super-resolution evaluate probe succeeded from RenderGraph GetTexture`, with SDK-wrapper ProjectID init/capability success, `render=426x284`, `target=720x480`, `perfQuality=0`, `flags=0x00000040`, `create=0x00000001`, `feature=yes`, `evaluate=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
  - Follow-up evidence observed the same `Edge Adaptive Spatial Upsampling` output pointer as D3D11-accessible after evaluate.
  - This proves NGX accepts the real SR-sized tuple. It still does not prove visible output/image correctness.
- Stage 8G DLSS Super Resolution persistent evaluate:
  - A 130-second scripted `dlss-persistent-evaluate` run on 2026-06-05 completed without a matching Windows crash event and passed the new SR persistent evaluate gate.
  - Evidence: `DLSS super-resolution persistent evaluate probe succeeded from RenderGraph GetTexture`, with SDK-wrapper ProjectID init/capability success, `render=426x284`, `target=720x480`, `perfQuality=0`, `flags=0x00000040`, `evaluateCount=3`, `evaluateSuccesses=3`, `create=0x00000001`, `feature=yes`, `evaluateLast=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
  - Follow-up evidence observed the same `Edge Adaptive Spatial Upsampling` output pointer as D3D11-accessible for 12 follow-up logs after repeated evaluate.
  - This proves one DLSS feature can persist across repeated evaluates on the real SR-sized tuple. It still does not prove visible output/image correctness.
- Stage 9A DLSS Super Resolution frame-sequence evaluate:
  - A 170-second scripted `dlss-super-resolution-frame-sequence` run on 2026-06-05 completed without a matching Windows crash event and passed the new frame-sequence gate.
  - A later 190-second scripted `dlss-persistent-evaluate` full-chain run on 2026-06-05 also completed without a matching Windows crash event and passed Stage 8A through Stage 9A in one archived log.
  - Evidence: first callback created the sequence with `recreated=yes`, `sequenceCreates=1`, `sequenceEvaluates=1`, `evaluateSuccesses=1`, `render=426x284`, `target=720x480`, `feature=yes`, and `evaluateLast=0x00000001`.
  - Later callbacks reused the feature with `recreated=no`, then reached `sequenceEvaluates=3` and `evaluateSuccesses=3`.
  - Shutdown succeeded with `hadSession=yes`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.
  - Follow-up evidence observed the same `Edge Adaptive Spatial Upsampling` output pointer as D3D11-accessible for 12 follow-up logs after the frame-sequence evaluate.
  - This proves one DLSS feature can persist across multiple RenderGraph callbacks on the real SR-sized tuple. It still does not prove visible output/image correctness.
- Stage 10A DLSS visible write-back candidate:
  - Implemented as `Diagnostics.EnableDlssVisibleWritebackProbe=false` by default and helper stage `dlss-visible-writeback`.
  - A 220-second scripted `dlss-visible-writeback` run on 2026-06-05 completed without a matching Windows crash event and passed the new visible write-back candidate gate.
  - Evidence: Stage 8E accepted `CameraColor`, `CameraDepthStencil`, and `Motion Vectors` at `426x284` with `Edge Adaptive Spatial Upsampling` at `720x480`.
  - Evidence: Stage 10A evaluated into `Edge Adaptive Spatial Upsampling` across RenderGraph callbacks, reached `sequenceEvaluates=30` and `evaluateSuccesses=30`, and shut down with release/destroy/shutdown all `0x00000001`.
  - Follow-up evidence observed the same `Edge Adaptive Spatial Upsampling` output pointer as D3D11-accessible for 12 follow-up logs after the visible write-back candidate.
  - This proves the guarded visible-path candidate can repeatedly evaluate into the selected SR output target. It still does not prove screenshot/visual image correctness, resize/reset behavior, or final normal-user enable/disable behavior.
  - A later 4K FSR Performance gameplay comparison reached Stage 10A on a `1920x1080 -> 3840x2160` tuple and captured a valid candidate screenshot, but hold-mode candidate performance dropped to `AverageFps=45.982` versus a baseline `AverageFps=159.851`. This is diagnostic overhead, not a normal-user DLSS performance result.
- Local GPU/driver for Stage 6/7 pass: NVIDIA GeForce RTX 5060, driver `610.47`.

Archived logs:

- `artifacts/runtime-logs/LogOutput-first-interop-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage1-loader-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage2b-upscaler-state-main-menu-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage4-native-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage5a-render-thread-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage5b-d3d11-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage5c-frame-resource-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage5d-dlss-runtime-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage6-sdk-wrapper-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage6-sdk-wrapper-projectid-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage7-dlss-feature-create-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage8a-dlss-evaluate-inputs-main-menu-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage8a-extended-frame-resource-main-menu-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-texturehandle-main-menu-2026-06-05-020700.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-registry-attempt-main-menu-2026-06-05-021102.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-resource-state-main-menu-2026-06-05-021255.log`
- `artifacts/runtime-logs/LogOutput-stage8a-gettexture-postfix-unsafe-prefix-call-2026-06-05-021707.log`
- `artifacts/runtime-logs/LogOutput-stage8a-gettexture-postfix-main-menu-2026-06-05-021840.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-builder-declarations-main-menu-2026-06-05-023132.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-builder-resource-names-main-menu-2026-06-05-023434.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-execution-scope-main-menu-2026-06-05-024534.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-execution-scope-observed-main-menu-2026-06-05-024714.log`
- `artifacts/runtime-logs/LogOutput-stage8a-texturehandle-conversion-unsafe-main-menu-2026-06-05-024955.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-generic-pass-execute-open-generic-main-menu-2026-06-05-025629.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-injected-main-menu-2026-06-05-030515.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-rooted-main-menu-2026-06-05-030659.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-readwrite-main-menu-2026-06-05-030845.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-declared-readwrite-main-menu-2026-06-05-031103.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-has-renderfunc-main-menu-2026-06-05-031250.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-builder-aggregate-main-menu-2026-06-05-031812.log`
- `artifacts/runtime-logs/LogOutput-stage8a-rendergraph-diagnostic-pass-crash-gameplay-2026-06-05-083418.log`
- `artifacts/runtime-logs/WER-stage8a-rendergraph-diagnostic-pass-crash-gameplay-2026-06-05-083423.wer`
- `artifacts/runtime-logs/LogOutput-stage8a-safe-materialization-broad-harmony-crash-2026-06-05.log`
- `artifacts/runtime-logs/WER-stage8a-safe-materialization-broad-harmony-crash-2026-06-05.wer`
- `artifacts/runtime-logs/LogOutput-stage8a-safe-materialization-main-menu-no-harmony-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-dlsspass-render-targeted-patch-crash-2026-06-05.log`
- `artifacts/runtime-logs/WER-dlsspass-render-targeted-patch-crash-2026-06-05.wer`
- `artifacts/runtime-logs/LogOutput-dlsspass-resource-mainmenu-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-dlss-evaluate-inputs-20260605-113722.log`
- `artifacts/runtime-logs/Analysis-dlss-evaluate-inputs-20260605-113722.txt`
- `artifacts/runtime-logs/LogOutput-dlss-evaluate-20260605-121132.log`
- `artifacts/runtime-logs/Analysis-dlss-evaluate-20260605-121132.txt`
- `artifacts/runtime-logs/LogOutput-dlss-evaluate-20260605-121942.log`
- `artifacts/runtime-logs/Analysis-dlss-evaluate-20260605-121942.txt`
- `artifacts/runtime-logs/LogOutput-dlss-persistent-evaluate-20260605-123925.log`
- `artifacts/runtime-logs/Analysis-dlss-persistent-evaluate-20260605-123925.txt`
- `artifacts/runtime-logs/LogOutput-dlss-persistent-evaluate-20260605-125921.log`
- `artifacts/runtime-logs/Analysis-dlss-persistent-evaluate-20260605-125921.txt`
- `artifacts/runtime-logs/LogOutput-dlss-persistent-evaluate-20260605-131548.log`
- `artifacts/runtime-logs/Analysis-dlss-persistent-evaluate-20260605-131548.txt`
- `artifacts/runtime-logs/LogOutput-dlss-persistent-evaluate-20260605-133102.log`
- `artifacts/runtime-logs/Analysis-dlss-persistent-evaluate-20260605-133102.txt`
- `artifacts/runtime-logs/LogOutput-dlss-super-resolution-frame-sequence-20260605-135122.log`
- `artifacts/runtime-logs/Analysis-dlss-super-resolution-frame-sequence-20260605-135122.txt`
- `artifacts/runtime-logs/LogOutput-dlss-persistent-evaluate-20260605-140300.log`
- `artifacts/runtime-logs/Analysis-dlss-persistent-evaluate-20260605-140300.txt`
- `artifacts/runtime-logs/LogOutput-dlss-visible-writeback-20260605-143407.log`
- `artifacts/runtime-logs/Analysis-dlss-visible-writeback-20260605-143407.txt`

No PureDark files were copied into the game plugin folder. The NVIDIA runtime was copied only into `ref/` for local research and was not added to the release package.

Next implementation gate:

- Keep ordinary `dlss-evaluate-inputs` diagnostics safe by leaving `Diagnostics.EnableRenderGraphDiagnosticPass=false`, `Diagnostics.EnableExistingRenderFuncProbe=false`, `Diagnostics.EnableFrameResourceProbe=false`, and `Diagnostics.EnableHarmonyCallProbe=false`.
- Keep Stage 8B/8C/8D/8E/8F/8G/9A/10A as guarded diagnostics while `DLSS.EnableDLSS=false` remains the package default.
- Implement a guarded normal-user rendering path only after choosing a safe output/writeback strategy from the accepted passive `GetTexture` evidence.
- Validate image correctness, render-scale behavior, jitter/pre-exposure, resize/reset behavior, and fallback behavior in a local/private gameplay scene before any public MVP release.
