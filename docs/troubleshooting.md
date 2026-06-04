# Troubleshooting

## Plugin Does Not Load

Check:

- V Rising is installed.
- BepInExPack V Rising 1.733.2 is installed.
- The first BepInEx run completed and generated `BepInEx/interop`.
- `VrisingDLSS.Plugin.dll` is under `BepInEx/plugins/VrisingDLSS/`.
- `BepInEx/LogOutput.log` exists.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1
```

To check what the local install helper would copy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising" -DryRun
```

To check what the BepInExPack helper would copy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising" -DryRun
```

To summarize the current BepInEx log:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\analyze-bepinex-log.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\get-runtime-validation-status.ps1 -GamePath "C:\path\to\VRising"
```

## Native Bridge Does Not Load

Check:

- `VrisingDLSS.Native.dll` is next to `VrisingDLSS.Plugin.dll`.
- The native DLL is x64.
- The Visual C++ runtime needed by the native bridge is installed.

Enable `EnableNativeBridgeSmokeTest` in the generated config only for diagnostics.

## Render Thread Smoke Test Does Not Advance

`EnableRenderThreadSmokeTest` sends one Unity plugin event through `CommandBuffer.IssuePluginEvent`.

Check:

- `VrisingDLSS.Native.dll` is next to `VrisingDLSS.Plugin.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `2` or newer.
- The log contains `Running native render-thread smoke test`.
- The log can find Unity `CommandBuffer` and `Graphics` types.

If the callback count does not advance immediately, keep this test disabled for normal play and capture the surrounding `BepInEx/LogOutput.log` lines. The smoke test is diagnostic only and does not initialize DLSS.

## D3D11 Texture Probe Fails

`EnableD3D11TextureProbe` creates one temporary RenderTexture and passes its native pointer to the native bridge.

Check:

- The game is running on DirectX 11.
- `EnableNativeBridgeSmokeTest` logs bridge API version `3` or newer.
- `EnableRenderThreadSmokeTest` passes first.
- The log contains a non-zero temporary RenderTexture native pointer.

If the probe reports `QueryInterface(ID3D11Resource)` failure, the game may not be using D3D11 for that run or Unity returned a backend-specific texture pointer that this bridge version does not support.

## Frame Resource Probe Does Not Find Textures

`EnableFrameResourceProbe` patches candidate HDRP `CustomVignette.Render` methods and logs source/destination arguments plus global `_CameraDepthTexture` and `_CameraMotionVectorsTexture` native pointers.

Check:

- `EnableHarmonyCallProbe` confirms `CustomVignette.Render` is called.
- `EnableD3D11TextureProbe` passes first.
- The log contains `Frame resource probe patched`.
- The render method signature still exposes source/destination resources or RTHandle-like objects.

If source/destination pointers are found but depth or motion pointers are missing, the current injection point may be too early/late or V Rising may not have populated those global textures for that frame. Keep DLSS evaluate disabled until all required inputs are frame-aligned.

## DLSS Runtime Probe Fails

`EnableDlssRuntimeProbe` loads and immediately releases the configured `DLSS.DlssRuntimePath`.

Check:

- The path points to a user-supplied production `nvngx_dlss.dll`.
- The path is absolute, or relative to `BepInEx/plugins/VrisingDLSS/`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `4` or newer.
- The file is not from a PureDark package.

If the probe reports missing known NGX exports, leave DLSS disabled and try a production runtime from an approved NVIDIA distribution path. This probe does not initialize DLSS and does not prove the game can evaluate DLSS frames.

## DLSS Init/Query Probe Is Blocked Or Fails

`EnableDlssInitQueryProbe` creates one temporary RenderTexture and gets its D3D11 device. In the current source-only build, it then checks whether the configured production `nvngx_dlss.dll` exposes the helper exports needed for NGX capability query.

Check:

- `EnableD3D11TextureProbe` passes first.
- `EnableDlssRuntimeProbe` passes first.
- `DLSS.DlssApplicationId` is decimal or `0x`-prefixed hexadecimal.
- `EnableNativeBridgeSmokeTest` logs bridge API version `5` or newer.
- The runtime is a current production `nvngx_dlss.dll` from an approved NVIDIA distribution path.

If the log says `DLSS init/query probe blocked`, the current native build does not include the optional NVIDIA SDK wrapper path. Re-running the same release-safe diagnostic with only `nvngx_dlss.dll` is expected to produce the same blocked result. Use the local SDK-wrapper research build when validating full capability query.

If NGX init succeeds but `SuperSampling.Available=0`, the runtime/device/driver path is reachable but DLSS is unavailable for that machine or configuration. If init returns a failure result, keep DLSS disabled and preserve the full status line from `BepInEx/LogOutput.log`.

## DLSS Feature Create Probe Is Blocked Or Fails

`EnableDlssFeatureCreateProbe` creates one temporary RenderTexture to get a D3D11 device/context, then asks the optional SDK-wrapper native path to create and immediately release a DLSS SuperSampling feature.

Check:

- `EnableD3D11TextureProbe` passes first.
- `EnableDlssRuntimeProbe` passes first.
- `EnableDlssInitQueryProbe` passes first in the same SDK-wrapper build route.
- `EnableNativeBridgeSmokeTest` logs bridge API version `6` or newer.
- The runtime is a current production `nvngx_dlss.dll` from an approved NVIDIA distribution path.

If the log says `DLSS feature create probe blocked`, the current native bridge was built without the optional NVIDIA SDK wrapper path. If create succeeds but release, parameter destruction, or shutdown fails, keep DLSS disabled and preserve the full status line. This probe still does not evaluate a frame or prove image correctness.

## DLSS Evaluate Input Probe Is Blocked Or Fails

`EnableDlssEvaluateInputProbe` reuses the frame-resource hook to collect color/output/depth/motion native texture pointers and validate them in the native bridge. It does not load DLSS or evaluate a frame.

Check:

- `EnableFrameResourceProbe` can patch and call a frame-resource method.
- A local/private gameplay scene is running, not only the main menu.
- The log shows source/output-like frame arguments from `CustomVignette.Render`.
- `_CameraDepthTexture` and `_CameraMotionVectorsTexture` both produce non-zero native pointers.
- `EnableNativeBridgeSmokeTest` logs bridge API version `7` or newer.

If the log says `DLSS evaluate input probe blocked`, preserve the surrounding frame-resource lines. Missing motion vectors usually means the current scene/settings/hook point is not enough for DLSS evaluate yet. If the probe fails after all four pointers are present, the native status line should identify a D3D11 resource, device, or dimension mismatch.

## Hook Targets Are Missing

If the hook probe logs missing `CustomVignette`, `HDCamera`, or `HDRenderPipeline`, the current game/HDRP version likely differs from the 2022 PureDark-era assumptions.

Next steps:

- Inspect `BepInEx/interop` for HDRP assembly names.
- Search for similar type names under `Unity.RenderPipelines.HighDefinition.Runtime.dll`.
- Keep the first runtime test read-only until target methods are confirmed.

## Harmony Call Probe Does Not Patch

`EnableHarmonyCallProbe` is disabled by default. Only enable it after the basic hook probe has found candidate methods.

Check:

- BepInEx is installed and started successfully.
- The log contains Harmony or HarmonyX runtime assemblies.
- The hook probe found the target methods before the Harmony call probe ran.

If the log says the Harmony runtime shape was not recognized, leave `EnableHarmonyCallProbe=false` and capture the loaded assembly list from `BepInEx/LogOutput.log`.

## Do Not Mix With PureDark Files

Remove these if they are next to this plugin:

- `PDPerfPlugin.dll`
- `PerfMod.dll`
- PureDark package folders

This clean-room project does not use them.

## Thunderstore Package Fails Boundary Check

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-release-boundary.ps1
```

The package must not include third-party runtime DLLs unless a release review explicitly approves them.
