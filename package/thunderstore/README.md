# VrisingDLSS

Unofficial clean-room DLSS Super Resolution mod scaffold for V Rising.

This package template is not ready for public gameplay use yet. The current source does not enable DLSS.

## Important

- This project is not affiliated with Stunlock Studios, NVIDIA, or PureDark.
- This package must not include PureDark binaries.
- This package must not include `nvngx_dlss.dll` until the distribution review approves a specific release path.
- Test only in local/private environments until compatibility and server-policy risks are understood.
- See `ThirdPartyNotices.md` for packaging and runtime dependency boundaries.

## Dependency

- `BepInEx-BepInExPack_V_Rising-1.733.2`

## Current Functionality

- Loads a clean-room BepInEx plugin scaffold.
- Optionally loads a native bridge smoke-test DLL if built and configured.
- Logs a read-only HDRP hook probe, including HDRP DLSS/FSR/upscale landmarks and optional Unity NVIDIA module availability.
- Optionally logs read-only Harmony call counts for candidate HDRP methods.
- Optionally sends one native render-thread smoke-test event.
- Optionally probes a temporary RenderTexture native pointer as a D3D11 resource.
- Optionally probes candidate HDRP frame resources for source/destination/depth/motion native texture pointers.
- Optionally probes loading and releasing a user-supplied DLSS runtime path.
- Optionally runs a guarded NGX init/query diagnostic; current source-only builds are expected to report blocked until NVIDIA SDK wrapper integration exists.
- Optionally runs an SDK-wrapper DLSS feature create/release diagnostic in local research builds; release-safe builds are expected to report blocked.
- Optionally validates real-frame color/output/depth/motion D3D11 inputs for the future DLSS evaluate path.
- Includes a mod-folder configuration file at `BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg`.
- Exposes the planned DLSS/Advanced configuration keys, but `DLSS.EnableDLSS=true` only logs a warning in this diagnostic package and does not change rendering yet.
- Keeps the high-risk injected RenderGraph diagnostic pass disabled by default after it caused a gameplay crash during Stage 8A research.
- Stages the plugin payload under `BepInEx/plugins/VrisingDLSS/` inside the package zip.
- Source repository includes helper scripts for BepInExPack staging, one-stage diagnostic config generation, BepInEx log analysis, and next-step status reporting.
- Does not evaluate DLSS yet.
