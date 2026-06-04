# Phase 0 Scaffold

This phase turns the research into a clean-room project shape without implementing DLSS yet.

## Current Deliverables

- BepInEx IL2CPP plugin scaffold in `src/VrisingDLSS.Plugin`.
- Native bridge scaffold in `src/VrisingDLSS.Native`.
- Read-only HDRP hook probe in `src/VrisingDLSS.Plugin`.
- Optional read-only Harmony call probe in `src/VrisingDLSS.Plugin`.
- Optional native render-event smoke test in `src/VrisingDLSS.Plugin` and `src/VrisingDLSS.Native`.
- Optional temporary RenderTexture-to-D3D11 resource probe in `src/VrisingDLSS.Plugin` and `src/VrisingDLSS.Native`.
- Optional HDRP frame resource native texture pointer probe in `src/VrisingDLSS.Plugin`.
- Optional user-supplied DLSS runtime load/release probe in `src/VrisingDLSS.Plugin` and `src/VrisingDLSS.Native`.
- Optional guarded DLSS init/query probe in `src/VrisingDLSS.Plugin` and `src/VrisingDLSS.Native`; full capability query is blocked until NVIDIA SDK wrapper integration exists.
- Thunderstore metadata template in `package/thunderstore`.
- Thunderstore packaging script in `scripts/package-thunderstore.ps1`.
- Distribution boundary documents.

## Build Requirements

The current machine does not have `dotnet`, `cmake`, or MSVC `cl` on PATH, so the scaffold has not been compiled here.

Expected tooling:

- .NET SDK 6 or newer.
- Visual Studio Build Tools 2022 with C++ workload.
- CMake 3.22 or newer.
- Current V Rising install with BepInExPack V Rising installed for runtime testing.

## Next Technical Validation

1. Build `VrisingDLSS.Plugin.dll`.
2. Build `VrisingDLSS.Native.dll`.
3. Install BepInExPack V Rising 1.733.2.
4. Place both DLLs under `VRising/BepInEx/plugins/VrisingDLSS/`.
5. Enable `EnableNativeBridgeSmokeTest` in config.
6. Keep `EnableHookProbe` enabled for the first run.
7. Confirm `BepInEx/LogOutput.log` shows plugin load, hook probe results, and native bridge diagnostics.
8. For a second diagnostic run only, enable `EnableHarmonyCallProbe` and confirm candidate HDRP methods are called.
9. For a third diagnostic run only, enable `EnableRenderThreadSmokeTest` and confirm the native render event callback count advances.
10. For a fourth diagnostic run only, enable `EnableD3D11TextureProbe` and confirm a temporary RenderTexture is recognized as a D3D11 resource.
11. For a fifth diagnostic run only, enable `EnableFrameResourceProbe` and confirm source/destination/depth/motion resources can be found at the HDRP hook point.
12. For a sixth diagnostic run only, set `DLSS.DlssRuntimePath`, enable `EnableDlssRuntimeProbe`, and confirm the user-supplied runtime loads and releases without initializing DLSS.
13. For a seventh diagnostic run only, set `DLSS.DlssApplicationId`, enable `EnableDlssInitQueryProbe`, and confirm the probe either reports the expected SDK-wrapper block or, in a wrapper-backed research build, NGX D3D11 init/capability/shutdown works without creating a DLSS feature.

## Clean-room Rule

Do not copy PureDark code, depend on PureDark ABI, or include PureDark package contents in `src` or `package`.

It is acceptable to mention known third-party file names in diagnostics or documentation when the purpose is to warn users not to redistribute or load them.
