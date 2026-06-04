# Local Preflight Result - 2026-06-04

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1
```

Observed result:

- Steam install path found: `C:\Software\Steam`
- Steam libraries found: `C:\Software\Steam`
- V Rising appmanifest `appmanifest_1604030.acf`: not found
- V Rising game path: not found
- BepInEx installed: false
- BepInEx interop generated: false

Implication:

The current machine is not ready for runtime hook validation because V Rising is not installed in the detected Steam libraries. The next runtime milestone needs either a V Rising install or an explicit `-GamePath` passed to `scripts/inspect-vrising-install.ps1`.

Release boundary check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-release-boundary.ps1
```

Observed result:

- Passed.
- No forbidden release files were found.

## Explicit Test Path: `C:\Software\VRising`

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1 -GamePath "C:\Software\VRising"
```

Observed result:

- Game path exists: `C:\Software\VRising`
- Game version: `VRising: v1.1.13.0-r99712-b17 (202605251526)`
- Unity player: `2022.3.58f1 (ed7f6eacb62e)`, file version `2022.3.58.15564654`
- `GameAssembly.dll`: present
- IL2CPP metadata: `C:\Software\VRising\VRising_Data\il2cpp_data\Metadata\global-metadata.dat`
- `ScriptingAssemblies.json`: present, 185 assemblies
- Player assemblies present:
  - `Unity.RenderPipelines.HighDefinition.Runtime.dll`
  - `Unity.RenderPipelines.HighDefinition.Config.Runtime.dll`
  - `Unity.RenderPipelines.Core.Runtime.dll`
  - `UnityEngine.CoreModule.dll`
  - `UnityEngine.NVIDIAModule.dll`
  - `ProjectM.dll`
  - `ProjectM.Camera.dll`
  - `ProjectM.Hybrid.Performance.dll`
  - `Stunlock.Core.dll`
- BepInEx installed: false
- BepInEx interop generated: false

Render metadata command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\probe-vrising-render-metadata.ps1 -GamePath "C:\Software\VRising"
```

Observed result:

- Hook/resource terms present:
  - `CustomVignette`
  - `DynamicResolutionHandler`
  - `HDRenderPipeline`
  - `HDCamera`
  - `SkyManager`
  - `_CameraDepthTexture`
  - `_CameraMotionVectorsTexture`
- Upscaler/AA terms present:
  - `AMD FSR 1.0`
  - `AMD FidelityFX Super Resolution 1.0`
  - `Antialiasing Mode: TAA`
  - `DLSS`
  - `Deep Learning Super Sampling`
  - `DLSS Color Mask`
  - `DLSS destination`
- Direct Unity/NVIDIA runtime terms absent:
  - `DLSSContext`
  - `DLSSCommandInitializationData`
  - `DLSSTextureTable`
  - `DLSSQuality`
  - `NVUnityPlugin`
  - `NGX`
  - `nvsdk_ngx`
- Runtime DLL candidates: none found for `nvngx`, `nvsdk`, `ngx`, `dlss`, `streamline`, `sl.*`, `xess`, `fsr2`, or `ffx`.

Implication:

- The current game build still exposes the important HDRP/render-resource names that a clean-room DLSS path needs to probe.
- The local game folder is not ready for runtime BepInEx validation until BepInExPack V Rising is installed and the game has been launched once to generate `BepInEx\interop`.
- Static evidence does not support a simple "enable Unity built-in DLSS" route. `UnityEngine.NVIDIAModule` is listed, but the expected DLSS/NGX runtime symbols and runtime DLLs are not present.
- This path includes third-party package markers such as `steam_settings` and `steam_api64.xdg`; treat it as static research/test input only. Do not use it for distribution evidence, online-server safety claims, or any DRM/network bypass work.
