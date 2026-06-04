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
- Stage 4 native bridge: pass. Native bridge API version `5` loaded.
- Stage 5A render thread: pass. `HDRenderPipeline.UpdateShaderVariablesGlobalCB` issued `CommandBuffer.IssuePluginEvent`; native callback count advanced to `1`.
- Stage 5B D3D11 texture: pass. Temporary `RenderTexture` pointer was recognized as a D3D11 resource/device.
- Stage 5C frame resources: pass. All-low main-menu run reached `HDRenderPipeline.UpdateShaderVariablesGlobalCB`; `_CameraDepthTexture` was found and D3D11-probed. `_CameraMotionVectorsTexture` was `null` in that scene/settings.
- Stage 5D DLSS runtime load/release: pass with official NVIDIA DLSS `310.6.0.0` runtime extracted under `ref/` for local research. The runtime exposes D3D11 init/create/evaluate/release/shutdown exports and `PopulateParameters_Impl`, but not `GetCapabilityParameters`.
- Stage 6 DLSS init/query:
  - Source-only/release-safe build reports `Blocked` when only the production `nvngx_dlss.dll` is available, because full capability query requires NVIDIA SDK wrapper integration.
  - Local MSVC SDK-wrapper research build passed with ProjectID init. Evidence: `init=0x00000001`, `capability=0x00000001`, `available=1`, `needsUpdatedDriver=0`, `minDriver=470.0`, `featureInitResult=1`, `destroy=0x00000001`, `shutdown=0x00000001`.
- Local GPU/driver for Stage 6 pass: NVIDIA GeForce RTX 5060, driver `610.47`.

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

No PureDark files were copied into the game plugin folder. The NVIDIA runtime was copied only into `ref/` for local research and was not added to the release package.

Next implementation gate:

- Implement the smallest SDK-wrapper-backed DLSS feature create/release probe before evaluate.
- Find a reliable motion-vector source. `_CameraMotionVectorsTexture` was `null` in the all-low main-menu run, so another hook point, scene, or graphics setting may be required.
