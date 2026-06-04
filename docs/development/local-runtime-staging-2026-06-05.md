# Local Runtime Staging - 2026-06-05

This records local staging progress for runtime validation. It does not mean DLSS evaluate works yet.

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
- Loader-stage config written to `C:\Software\VRising\BepInEx\config\dev.vrisingdlss.plugin.cfg`.
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
- Stage 4 native bridge: pass. Native bridge API version `7` is the current build-validated bridge API. Archived runtime logs through Stage 7 used API version `6`.
- Stage 5A render thread: pass. `HDRenderPipeline.UpdateShaderVariablesGlobalCB` issued `CommandBuffer.IssuePluginEvent`; native callback count advanced to `1`.
- Stage 5B D3D11 texture: pass. Temporary `RenderTexture` pointer was recognized as a D3D11 resource/device.
- Stage 5C frame resources: pass. All-low main-menu run reached `HDRenderPipeline.UpdateShaderVariablesGlobalCB`; `_CameraDepthTexture` was found and D3D11-probed. `_CameraMotionVectorsTexture` was `null` in that scene/settings.
- Stage 5D DLSS runtime load/release: pass with official NVIDIA DLSS `310.6.0.0` runtime extracted under `ref/` for local research. The runtime exposes D3D11 init/create/evaluate/release/shutdown exports and `PopulateParameters_Impl`, but not `GetCapabilityParameters`.
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
  - Current conclusion: Stage 8A is blocked by RenderGraph resource lifetime/scope. The next implementation step should hook or inject inside a declared RenderGraph pass/read scope, not keep adding ordinary method-prefix candidates.
- Local GPU/driver for Stage 6/7 pass: NVIDIA GeForce RTX 5060, driver `610.47`.

Archived logs:

- `artifacts/runtime-logs/LogOutput-first-interop-2026-06-05.log`
- `artifacts/runtime-logs/LogOutput-stage1-loader-2026-06-05.log`
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

No PureDark files were copied into the game plugin folder. The NVIDIA runtime was copied only into `ref/` for local research and was not added to the release package.

Next implementation gate:

- Prototype a RenderGraph-scoped diagnostic pass or hook an execution-time delegate where `CameraColor`, `CameraDepthStencil`, and `Motion Vectors` are valid declared resources.
- Keep using `dlss-evaluate-inputs` in a local/private gameplay scene after the RenderGraph-scope hook exists, because gameplay may expose a fuller camera/motion-vector frame than the main menu.
- Implement the smallest SDK-wrapper-backed DLSS evaluate probe only after Stage 8A proves frame resources are aligned and native D3D11 pointers are available in the same frame.
