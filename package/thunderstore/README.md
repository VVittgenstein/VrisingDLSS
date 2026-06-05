# VrisingDLSS

Unofficial clean-room DLSS Super Resolution mod scaffold for V Rising.

This package template is not ready for public gameplay use yet. The current source includes an experimental `DLSS.EnableDLSS=true` rendering candidate, but it has not passed MVP image-quality/performance validation.

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
- Optionally logs read-only HDRP FSR/upscale and dynamic-resolution state snapshots.
- Optionally logs read-only Harmony call counts for a conservative set of candidate HDRP methods.
- Optionally sends one native render-thread smoke-test event.
- Optionally probes a temporary RenderTexture native pointer as a D3D11 resource.
- Optionally probes candidate HDRP frame resources for source/destination/depth/motion native texture pointers.
- Optionally probes loading and releasing a user-supplied DLSS runtime path.
- Optionally runs a guarded NGX init/query diagnostic; current source-only builds are expected to report blocked until NVIDIA SDK wrapper integration exists.
- Optionally runs an SDK-wrapper DLSS feature create/release diagnostic in local research builds; release-safe builds are expected to report blocked.
- Optionally validates real-frame color/output/depth/motion D3D11 inputs for the future DLSS evaluate path.
- Optionally validates a Super Resolution-sized real-frame tuple where color/depth/motion render inputs are smaller than the selected output target.
- Optionally runs a guarded Super Resolution-sized DLSS evaluate diagnostic in local SDK-wrapper research builds; release-safe builds are expected to report blocked and the packaged config keeps this disabled.
- Optionally runs a guarded Super Resolution-sized persistent DLSS evaluate diagnostic in local SDK-wrapper research builds; release-safe builds are expected to report blocked and the packaged config keeps this disabled.
- Optionally runs a guarded Super Resolution-sized frame-sequence DLSS evaluate diagnostic in local SDK-wrapper research builds; release-safe builds are expected to report blocked and the packaged config keeps this disabled.
- Optionally runs a guarded visible-path write-back candidate diagnostic in local SDK-wrapper research builds, including a local-only hold mode for screenshot timing; release-safe builds are expected to report blocked and the packaged config keeps this disabled.
- Optionally runs a guarded one-shot DLSS evaluate diagnostic in local SDK-wrapper research builds; release-safe builds are expected to report blocked and the packaged config keeps this disabled.
- Optionally logs Stage 8C output follow-up after a successful guarded evaluate by checking whether the selected output resource/pointer remains D3D11-accessible in later RenderGraph texture callbacks.
- Optionally runs a Stage 8D persistent-feature repeated-evaluate diagnostic in local SDK-wrapper research builds; release-safe builds are expected to report blocked and the packaged config keeps this disabled.
- Includes a mod-folder configuration file at `BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg`.
- Exposes the planned DLSS/Advanced configuration keys. `DLSS.EnableDLSS=true` starts an experimental one-evaluate-per-frame candidate when a compatible native bridge/runtime is available; release-safe builds still fall back safely when that path is blocked.
- Keeps the high-risk injected RenderGraph diagnostic pass disabled by default after it caused a gameplay crash during Stage 8A research.
- Stages the plugin payload under `BepInEx/plugins/VrisingDLSS/` inside the package zip.
- Source repository includes helper scripts for BepInExPack staging, one-stage diagnostic config generation, BepInEx log analysis, and next-step status reporting.
- Does not yet provide validated normal-user DLSS rendering.
