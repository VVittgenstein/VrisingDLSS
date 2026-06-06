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

## DLSS Optimal-Settings Probe Is Blocked Or Fails

`EnableDlssOptimalSettingsProbe` creates one temporary RenderTexture to get a D3D11 device, then asks the optional SDK-wrapper native path for DLSS-recommended render dimensions for a 3840x2160 output target and the selected `DLSS.QualityMode`.

Check:

- `EnableD3D11TextureProbe` passes first.
- `EnableDlssRuntimeProbe` passes first.
- `EnableDlssInitQueryProbe` passes first in the same SDK-wrapper build route.
- `EnableNativeBridgeSmokeTest` logs bridge API version `12` or newer.
- The runtime is a current production `nvngx_dlss.dll` from an approved NVIDIA distribution path.

If the log says `DLSS optimal-settings probe blocked`, the current native bridge was built without the optional NVIDIA SDK wrapper path. If the query fails, preserve the full status line because it includes output size, quality mode, NGX result, cleanup results, and any returned render-size fields.

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

## DLSS Super Resolution Input Probe Does Not Pass

`EnableDlssSuperResolutionInputProbe` uses the same passive RenderGraph `GetTexture` stream as Stage 8A, but it keeps searching until color/depth/motion render inputs are smaller than the output target. It does not load DLSS or evaluate a frame.

Check:

- `EnableDlssEvaluateInputProbe` can already pass through the passive RenderGraph route.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows candidate lines beginning with `DLSS super-resolution input probe candidate #`.
- If candidates say `output was not larger than render input`, keep the game running longer or use a scene/settings combination where HDRP dynamic resolution drops below the output resolution.
- A passing status should include `sameDevice=yes`, matching color/depth/motion dimensions, a larger output size, and `scale=`.

If Stage 8E passes but DLSS is still not visible, that is expected in the current scaffold. Stage 8E proves resource sizing only; visible write-back and image correctness are still separate MVP work.

## DLSS Super Resolution Evaluate Probe Is Blocked Or Fails

`EnableDlssSuperResolutionEvaluateProbe` waits for Stage 8E, then runs one guarded SDK-wrapper DLSS evaluate against the render-input-smaller-than-output tuple. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows `DLSS super-resolution evaluate probe candidate #`.
- A passing status should include `render=` smaller than `target=`, `create=0x00000001`, `evaluate=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.

If this stage passes but DLSS is still not visible, that is expected. Stage 8F proves the SR-sized NGX evaluate call, not the normal-user visible rendering path.

## DLSS Super Resolution Persistent Evaluate Probe Is Blocked Or Fails

`EnableDlssSuperResolutionPersistentEvaluateProbe` waits for Stage 8E, then runs a guarded SDK-wrapper persistent DLSS evaluate against the render-input-smaller-than-output tuple. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `10` or newer.
- The log shows `DLSS super-resolution persistent evaluate probe candidate #`.
- A passing status should include `render=` smaller than `target=`, `evaluateCount=`, matching `evaluateSuccesses=`, `create=0x00000001`, `evaluateLast=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.

If this stage passes but DLSS is still not visible, that is expected. Stage 8G proves repeated evaluates on one DLSS feature for the SR-sized tuple, not the normal-user visible rendering path.

## DLSS Super Resolution Frame-Sequence Evaluate Probe Is Blocked Or Fails

`EnableDlssSuperResolutionFrameSequenceEvaluateProbe` waits for Stage 8E, then runs guarded SDK-wrapper DLSS evaluates across multiple RenderGraph callbacks while keeping one DLSS feature alive. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows `DLSS super-resolution frame-sequence evaluate probe candidate #`.
- A passing status should include `sequenceCreates=1`, `sequenceEvaluates=3`, `evaluateSuccesses=3`, `recreated=no` on later callbacks, `feature=yes`, `evaluateLast=0x00000001`, and a later `DLSS super-resolution frame-sequence shutdown succeeded` line with release/destroy/shutdown all `0x00000001`.

If this stage passes but DLSS is still not visible, that is expected. Stage 9A proves cross-callback feature reuse for the SR-sized tuple, not the normal-user visible rendering path.

## DLSS Visible Write-back Probe Is Blocked Or Fails

`EnableDlssVisibleWritebackProbe` waits for Stage 8E, then repeatedly evaluates DLSS into the selected Super Resolution output target across multiple RenderGraph callbacks. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows `DLSS visible write-back probe candidate #`.
- A passing status should include `sequenceEvaluates=30`, `evaluateSuccesses=30`, `feature=yes`, `evaluateLast=0x00000001`, `outputResourceName=Edge Adaptive Spatial Upsampling` when the known SR tuple is selected, and a later `DLSS visible write-back shutdown succeeded` line with release/destroy/shutdown all `0x00000001`.
- If `KeepDlssVisibleWritebackProbeRunning=true` is set for a visual comparison run, the success line should include `keepRunning=True` and the probe should keep evaluating after `sequenceSuccesses=30/30` until cleanup or the hold attempt limit.

If this stage passes but the image looks wrong, preserve screenshots and the archived BepInEx log. Stage 10A proves the guarded visible-path candidate ran; it does not by itself prove image correctness, jitter correctness, resize/reset behavior, or final normal-user fallback behavior.

## RenderGraph Pass-Boundary Probe

`EnableRenderGraphPassBoundaryProbe` is disabled by default and is high-risk research-only. It patches only `RenderGraph.PreRenderPassExecute(...)` and logs capped pass metadata: pass name, pass type, a coarse category, and safe `CompiledPassInfo` fields. In the standalone helper stage it does not resolve textures, does not call `GetTexture`, does not load DLSS, and does not evaluate a frame.

The first 2026-06-06 runtime proof rejected this boundary for normal diagnostics: the method patched successfully, no `RenderGraph pass boundary #` lines were emitted, and V Rising crashed during startup with Windows Application Error `coreclr.dll` `0xc0000005` before gameplay/Continue. Do not use this stage except for deliberate crash-recovery research:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-pass-boundary -DurationSeconds 240 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

For any deliberate rerun, back up and restore the protected `11111` save. A useful run would need `RenderGraph pass boundary #` lines for upscaler/final/postprocess candidates without a matching Windows crash event, but the current evidence says this route is unsafe in V Rising's IL2CPP build.

## DLSSPass Resource Helper Probe

`EnableDlssPassResourceProbe` is disabled by default. It patches only `DLSSPass.GetViewResources` and `DLSSPass.GetCameraResources`, then logs any returned source/output/depth/motion-vector `Texture` native pointers. It does not patch `DLSSPass.Render`, does not load DLSS, and does not evaluate a frame.

Use this only as a deliberate short local/private test:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage dlsspass-resource
```

If the game closes immediately after patching these helper methods, leave `EnableDlssPassResourceProbe=false` and keep using the safer RenderGraph materialization route. If the log shows all four resource-helper pointers, preserve those lines before trying any run that also enables `EnableDlssEvaluateInputProbe`.

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

Do not combine `EnableHarmonyCallProbe=true` with Stage 8A diagnostics. The `dlss-evaluate-inputs` helper intentionally leaves it disabled because broad Harmony call logging previously patched `DLSSPass.Render` and crashed V Rising in `coreclr.dll` with `0xc00000fd`. Use `write-diagnostic-config.ps1 -Stage harmony-call` as a separate short run only.

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
