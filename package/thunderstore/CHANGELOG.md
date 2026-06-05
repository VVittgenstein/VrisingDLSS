# Changelog

## 0.1.0

- Initial clean-room scaffold.
- Added read-only discovery for HDRP DLSS/FSR/upscale route landmarks and optional Unity NVIDIA module APIs.
- Added optional read-only FSR/upscale state snapshots for HDRP dynamic-resolution route diagnosis.
- Added read-only HDRP hook probe.
- Added optional read-only Harmony call probe with a conservative target list.
- Added native bridge smoke-test interface.
- Added native render-thread smoke-test interface.
- Added D3D11 texture pointer probe interface.
- Added HDRP frame resource probe for source/destination/depth/motion native texture pointers.
- Added user-supplied DLSS runtime load/release probe interface.
- Added guarded user-supplied DLSS init/query probe interface; full capability query requires NVIDIA SDK wrapper integration.
- Added optional local SDK-wrapper research build path; not enabled or packaged by default.
- Added optional local SDK-wrapper DLSS feature create/release probe interface; not enabled or packaged by default.
- Added real-frame DLSS evaluate input probe interface; validates color/output/depth/motion D3D11 resources before any evaluate call.
- Added Stage 8E Super Resolution input-size probe; validates render inputs smaller than output without evaluating DLSS.
- Added Stage 8F Super Resolution evaluate diagnostic; local SDK-wrapper research builds can evaluate the discovered SR-sized tuple.
- Added guarded one-shot DLSS evaluate diagnostic interface for local SDK-wrapper research builds; release-safe builds report blocked and package defaults keep it disabled.
- Added Stage 8C output follow-up logging after guarded evaluate to track whether the selected output resource/pointer remains D3D11-accessible in later RenderGraph callbacks.
- Added Stage 8D persistent-feature repeated-evaluate diagnostic; local SDK-wrapper research builds can create one feature, evaluate repeatedly, then release/shutdown.
- Added BepInExPack staging helper for local/offline tests.
- Added source-side diagnostic config, log analysis, and runtime status helpers.
- Kept Stage 8A helper configs from enabling broad Harmony call logging by default.
- Added local install helper and third-party notices.
- Added Thunderstore package validation for diagnostic-package wording and safe default config toggles.
- No normal-user DLSS rendering path yet.
