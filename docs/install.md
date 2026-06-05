# Install Guide

Current status: scaffold only. This project does not enable DLSS yet.

Use this guide once build outputs exist.

## Thunderstore / Mod Manager

1. Install Thunderstore Mod Manager or r2modman.
2. Create/select a V Rising profile.
3. Install `BepInEx-BepInExPack_V_Rising-1.733.2`.
4. Install the VrisingDLSS package zip once it is available.
5. Launch the game once with mods enabled.
6. Check `BepInEx/LogOutput.log`.

The package zip keeps Thunderstore metadata at the root and places the plugin payload under `BepInEx/plugins/VrisingDLSS/` so mod managers install it into the same folder used by the manual path.

## Manual Install

1. Locate the game folder. For Steam, right-click V Rising, then Manage, then Browse local files.
2. Install BepInExPack V Rising 1.733.2 into the game folder.
3. Launch the game once and exit so BepInEx can generate `BepInEx/interop`.
4. Create `BepInEx/plugins/VrisingDLSS`.
5. Copy these build outputs into that folder:
   - `VrisingDLSS.Plugin.dll`
   - `VrisingDLSS.Native.dll`
6. Copy or generate `VrisingDLSS.cfg` in the same folder.
7. Launch the game again.
8. Confirm the log contains `VrisingDLSS 0.1.0 loaded`.
9. Keep `Diagnostics.EnableHarmonyCallProbe=false` for the first run.
10. After the basic hook probe finds candidate methods, enable `Diagnostics.EnableHarmonyCallProbe=true` for one diagnostic run, then disable it again.
11. Optionally enable `Diagnostics.EnableUpscalerStateProbe=true` for one diagnostic run to log current HDRP FSR/upscale and dynamic-resolution state, then disable it again.
12. After the native bridge smoke test passes, enable `Diagnostics.EnableRenderThreadSmokeTest=true` for one diagnostic run, then disable it again.
13. After the render-thread smoke test passes, enable `Diagnostics.EnableD3D11TextureProbe=true` for one diagnostic run, then disable it again.
14. After the D3D11 probe passes, enable `Diagnostics.EnableFrameResourceProbe=true` for one diagnostic run, then disable it again.
15. After the frame resource probe finds usable D3D11 frame resources, optionally set `DLSS.DlssRuntimePath` to a user-supplied production `nvngx_dlss.dll`, enable `Diagnostics.EnableDlssRuntimeProbe=true` for one diagnostic run, then disable it again.
16. After the runtime load probe passes, optionally set `DLSS.DlssApplicationId`, enable `Diagnostics.EnableDlssInitQueryProbe=true` for one diagnostic run, then disable it again.
17. For local SDK-wrapper research builds only, after the init/query probe passes, enable `Diagnostics.EnableDlssFeatureCreateProbe=true` for one diagnostic run, then disable it again.
18. In a local/private gameplay scene, enable `Diagnostics.EnableDlssEvaluateInputProbe=true` for one diagnostic run to verify color/output/depth/motion native texture inputs before any DLSS evaluate work.

## Local Install Helper

After build outputs exist, you can copy the scaffold into an existing BepInEx install without launching the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising"
```

The helper only copies this project's own plugin/native DLLs, `VrisingDLSS.cfg`, and `README-runtime.txt` into `BepInEx\plugins\VrisingDLSS`. It does not install BepInEx, launch V Rising, modify game files, or copy any NVIDIA/PureDark files.

## BepInExPack Helper

For a local/offline test folder, install the declared BepInEx dependency without launching the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising"
```

The helper copies only the contents of the public `BepInExPack_V_Rising` payload into the game folder. It does not install VrisingDLSS, launch V Rising, or copy PureDark/NVIDIA runtime files.

## Diagnostic Config Helper

After the mod folder exists, you can write a one-stage diagnostic config without launching the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage loader
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage harmony-call
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage upscaler-state
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage d3d11
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage frame-resource
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage dlss-evaluate-inputs
```

For DLSS runtime diagnostics:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage dlss-runtime -DlssRuntimePath "C:\path\to\nvngx_dlss.dll"
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage dlss-init-query -DlssRuntimePath "C:\path\to\nvngx_dlss.dll" -DlssApplicationId "0"
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage dlss-feature-create -DlssRuntimePath "C:\path\to\nvngx_dlss.dll" -DlssApplicationId "0"
```

Supported stages are `loader`, `native`, `harmony-call`, `render-thread`, `d3d11`, `frame-resource`, `upscaler-state`, `dlss-runtime`, `dlss-init-query`, `dlss-feature-create`, `dlss-evaluate-inputs`, `dlss-evaluate`, and `dlsspass-resource`.

## Diagnostic Run Helper

For repeatable local diagnostics, use the run helper. It installs the current build unless `-SkipInstall` is passed, writes one diagnostic config, launches V Rising for a fixed window, archives the BepInEx log plus matching Windows Application Error events, then restores the loader config.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage dlsspass-resource -DurationSeconds 90
```

For a gameplay-scene Stage 8A test, use a longer window and enter a local/private world while the helper is running:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage dlss-evaluate-inputs -DurationSeconds 240
```

## Log Analyzer

After a diagnostic run, summarize the BepInEx log:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\analyze-bepinex-log.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\get-runtime-validation-status.ps1 -GamePath "C:\path\to\VRising"
```

The analyzer only reads `BepInEx\LogOutput.log`. The status script combines install preflight, current diagnostic config, log analysis, and a next recommended command. Neither script launches or modifies the game.

## DLSS Runtime

The source-only package intentionally does not include `nvngx_dlss.dll`.

`VrisingDLSS.cfg` exposes the planned MVP DLSS and advanced configuration keys, including `DLSS.EnableDLSS`, `DLSS.QualityMode`, `DLSS.PresetMode`, `Advanced.RenderScaleOverride`, and `Advanced.MipBiasOverride`. In the current diagnostic package, `DLSS.EnableDLSS=true` only logs a warning and leaves native rendering unchanged.

Keep `Diagnostics.EnableRenderGraphDiagnosticPass=false` and `Diagnostics.EnableExistingRenderFuncProbe=false` unless you are intentionally reproducing a crash-recovery research run. Both routes caused V Rising `coreclr.dll` access violations during Stage 8A testing.

The current diagnostic scaffold can optionally load and immediately release a user-supplied production `nvngx_dlss.dll` when `Diagnostics.EnableDlssRuntimeProbe=true` and `DLSS.DlssRuntimePath` points to that file. This is only a path/export probe.

The next diagnostic switch, `Diagnostics.EnableDlssInitQueryProbe=true`, currently uses a temporary RenderTexture D3D11 device to confirm the native path and then checks whether the loaded runtime exposes the helper exports needed for NGX capability query. Release-safe builds are expected to report `DLSS init/query probe blocked` with only a production `nvngx_dlss.dll`. Local SDK-wrapper research builds can run the full init/capability query, but they are not enabled or packaged by default.

For local SDK-wrapper research builds, `Diagnostics.EnableDlssFeatureCreateProbe=true` can create and immediately release a DLSS SuperSampling feature through the same temporary D3D11 device path. This still does not evaluate a frame.

`Diagnostics.EnableDlssEvaluateInputProbe=true` validates whether real color/output/depth/motion frame resources are present and D3D11-compatible in the same hook callback. This does not require a DLSS runtime and still does not evaluate a frame. The `dlss-evaluate-inputs` helper also enables `Diagnostics.EnableResourceMaterializationProbe=true` and `Diagnostics.EnableUpscalerStateProbe=true`, but leaves `Diagnostics.EnableHarmonyCallProbe=false` so broad call logging does not interfere with Stage 8A. The ordinary diagnostic does not patch compiler-generated HDRP render functions; that rejected route is gated separately by `Diagnostics.EnableExistingRenderFuncProbe=false`.

`Diagnostics.EnableDlssEvaluateProbe=true` is the Stage 8B local research switch. It reuses a successful Stage 8A tuple, then asks a local SDK-wrapper native build to create a DLSS feature, call one guarded D3D11 DLSS evaluate, and release/shutdown immediately. After a successful evaluate, the plugin also performs Stage 8C output follow-up by watching later engine-owned `GetTexture` callbacks for the selected output resource/pointer and re-probing it as D3D11. Release-safe builds report blocked. Use `scripts\run-vrising-diagnostic.ps1 -Stage dlss-evaluate` only in local/private testing with `DLSS.DlssRuntimePath` set; this is still not the normal-user `DLSS.EnableDLSS` path.

`Diagnostics.EnableDlssPassResourceProbe=true` is a separate research switch for the HDRP DLSSPass resource-helper route. It patches `DLSSPass.GetViewResources` and `DLSSPass.GetCameraResources`, not `DLSSPass.Render`, and logs source/output/depth/motion-vector texture pointers when those helpers return real `Texture` objects. Use `scripts\write-diagnostic-config.ps1 -Stage dlsspass-resource` for this isolated test; it is not enabled by the ordinary `dlss-evaluate-inputs` helper.

`Diagnostics.EnableUpscalerStateProbe=true` logs read-only HDRP FSR/upscale and dynamic-resolution state snapshots. It helps confirm whether V Rising's built-in FSR/upscale route is active, but it does not change the upscale filter and does not replace the DLSS depth/motion-vector requirement.

Do not copy PureDark package files into this mod folder.
