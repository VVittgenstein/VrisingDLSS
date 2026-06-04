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

## Manual Install

1. Locate the game folder. For Steam, right-click V Rising, then Manage, then Browse local files.
2. Install BepInExPack V Rising 1.733.2 into the game folder.
3. Launch the game once and exit so BepInEx can generate `BepInEx/interop`.
4. Create `BepInEx/plugins/VrisingDLSS`.
5. Copy these build outputs into that folder:
   - `VrisingDLSS.Plugin.dll`
   - `VrisingDLSS.Native.dll`
6. Launch the game again.
7. Confirm the log contains `VrisingDLSS 0.1.0 loaded`.
8. Keep `Diagnostics.EnableHarmonyCallProbe=false` for the first run.
9. After the basic hook probe finds candidate methods, enable `Diagnostics.EnableHarmonyCallProbe=true` for one diagnostic run, then disable it again.
10. After the native bridge smoke test passes, enable `Diagnostics.EnableRenderThreadSmokeTest=true` for one diagnostic run, then disable it again.
11. After the render-thread smoke test passes, enable `Diagnostics.EnableD3D11TextureProbe=true` for one diagnostic run, then disable it again.
12. After the D3D11 probe passes, enable `Diagnostics.EnableFrameResourceProbe=true` for one diagnostic run, then disable it again.
13. After the frame resource probe finds usable D3D11 frame resources, optionally set `DLSS.DlssRuntimePath` to a user-supplied production `nvngx_dlss.dll`, enable `Diagnostics.EnableDlssRuntimeProbe=true` for one diagnostic run, then disable it again.
14. After the runtime load probe passes, optionally set `DLSS.DlssApplicationId`, enable `Diagnostics.EnableDlssInitQueryProbe=true` for one diagnostic run, then disable it again.
15. For local SDK-wrapper research builds only, after the init/query probe passes, enable `Diagnostics.EnableDlssFeatureCreateProbe=true` for one diagnostic run, then disable it again.
16. In a local/private gameplay scene, enable `Diagnostics.EnableDlssEvaluateInputProbe=true` for one diagnostic run to verify color/output/depth/motion native texture inputs before any DLSS evaluate work.

## Local Install Helper

After build outputs exist, you can copy the scaffold into an existing BepInEx install without launching the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising"
```

The helper only copies this project's own plugin/native DLLs and `README-runtime.txt` into `BepInEx\plugins\VrisingDLSS`. It does not install BepInEx, launch V Rising, modify game files, or copy any NVIDIA/PureDark files.

## BepInExPack Helper

For a local/offline test folder, install the declared BepInEx dependency without launching the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising"
```

The helper copies only the contents of the public `BepInExPack_V_Rising` payload into the game folder. It does not install VrisingDLSS, launch V Rising, or copy PureDark/NVIDIA runtime files.

## Diagnostic Config Helper

After BepInEx has generated a config folder, you can write a one-stage diagnostic config without launching the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage loader
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

Supported stages are `loader`, `native`, `render-thread`, `d3d11`, `frame-resource`, `dlss-runtime`, `dlss-init-query`, `dlss-feature-create`, and `dlss-evaluate-inputs`.

## Log Analyzer

After a diagnostic run, summarize the BepInEx log:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\analyze-bepinex-log.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\get-runtime-validation-status.ps1 -GamePath "C:\path\to\VRising"
```

The analyzer only reads `BepInEx\LogOutput.log`. The status script combines install preflight, current diagnostic config, log analysis, and a next recommended command. Neither script launches or modifies the game.

## DLSS Runtime

The source-only package intentionally does not include `nvngx_dlss.dll`.

The current diagnostic scaffold can optionally load and immediately release a user-supplied production `nvngx_dlss.dll` when `Diagnostics.EnableDlssRuntimeProbe=true` and `DLSS.DlssRuntimePath` points to that file. This is only a path/export probe.

The next diagnostic switch, `Diagnostics.EnableDlssInitQueryProbe=true`, currently uses a temporary RenderTexture D3D11 device to confirm the native path and then checks whether the loaded runtime exposes the helper exports needed for NGX capability query. Release-safe builds are expected to report `DLSS init/query probe blocked` with only a production `nvngx_dlss.dll`. Local SDK-wrapper research builds can run the full init/capability query, but they are not enabled or packaged by default.

For local SDK-wrapper research builds, `Diagnostics.EnableDlssFeatureCreateProbe=true` can create and immediately release a DLSS SuperSampling feature through the same temporary D3D11 device path. This still does not evaluate a frame.

`Diagnostics.EnableDlssEvaluateInputProbe=true` validates whether real color/output/depth/motion frame resources are present and D3D11-compatible in the same hook callback. This does not require a DLSS runtime and still does not evaluate a frame.

Do not copy PureDark package files into this mod folder.
