# V Rising DLSS Distributable Mod Research

Date: 2026-06-05

Purpose: establish the current compliance, usability, and technical route for a free, non-commercial, clean-room V Rising DLSS Super Resolution mod that can eventually be distributed through GitHub and the V Rising/Thunderstore mod ecosystem.

This is an engineering and release-risk memo, not legal advice.

## Current Decision

The release-safe route remains:

1. Ship only original `VrisingDLSS.Plugin.dll`, original `VrisingDLSS.Native.dll`, package metadata, documentation, and notices.
2. Depend on `BepInEx-BepInExPack_V_Rising-1.733.2` through Thunderstore.
3. Do not ship PureDark files, game files, NVIDIA runtime DLLs, Streamline DLLs, NVIDIA SDK headers/libs, or SDK-wrapper binaries until a separate release review approves the exact files and wording.
4. Keep the first playable public target to DLSS Super Resolution on Windows/D3D11, local/private gameplay first.
5. Treat public/official server use as not guaranteed and keep the package explicitly unofficial, graphics-only, free, and non-commercial.

The current repository is already aligned with that route for a diagnostic package. It is not a playable DLSS MVP yet because `DLSS.EnableDLSS=true` does not change visible rendering. Stage 10A guarded visible-path write-back validation has passed locally; the next engineering step is screenshot/visual image-correctness validation.

## Source Findings

### V Rising policy and ecosystem

- V Rising's Steam EULA warns against unauthorized third-party programs, including mods, and says detected unauthorized third-party programs can lead to official-server access termination. Source: https://store.steampowered.com/eula/1604030_eula_0
- Stunlock's Terms of Service similarly restrict unauthorized software designed to modify the service, a game, or a game experience, and restrict commercial exploitation without consent. Source: https://cdn.stunlock.com/legal/Terms_of_Service_VRising.pdf
- The V Rising Mod Wiki reports a community position that mods should not give PvP advantages and should not be used on official servers. It also says client-side mods may be server-sensitive and major game updates can break mods. Source: https://wiki.vrisingmods.com/community/faq.html
- V Rising mod development is a BepInEx/IL2CPP workflow: BepInEx generates `BepInEx/interop/` wrappers that mod code references. Source: https://wiki.vrisingmods.com/dev/how-mods-work.html

Release implication: the README and Thunderstore package should continue to say unofficial, client-side graphics experiment, local/private testing recommended, no gameplay/network/protocol/server changes intended, and no official-server permission guarantee.

### Thunderstore and BepInEx distribution

- Thunderstore manifest fields include `name`, `description`, `version_number`, `dependencies`, and `website_url`; dependencies are package strings in `{team}-{package}-{version}` format. Source: https://wiki.thunderstore.io/mods/creating-a-package
- Thunderstore packaging requires `manifest.json`, `icon.png`, and `README.md` at the zip root. Source: https://wiki.thunderstore.io/mods/packaging-your-mods
- The current V Rising BepInExPack dependency string shown by Thunderstore is `BepInEx-BepInExPack_V_Rising-1.733.2`. Source: https://new.thunderstore.io/c/v-rising/p/BepInEx/BepInExPack_V_Rising/versions
- The V Rising Mod Wiki says Thunderstore upload should include an icon, readme, manifest, and strongly recommends a changelog. Source: https://wiki.vrisingmods.com/dev/upload_to_thunderstore.html

Release implication: the current `package/thunderstore/manifest.json` dependency is correct, and the existing packaging/validation scripts should remain strict about root metadata and BepInEx plugin placement.

### NVIDIA DLSS and runtime distribution

- NVIDIA's public DLSS repository is the public repo for the RTX DLSS SDK. Source: https://github.com/NVIDIA/DLSS
- NVIDIA's RTX SDK supplement says DLSS/NGX SDK applications are for systems with NVIDIA GPUs, requires notification before commercial release of an application or plugin to a commercial application that incorporates or is based on the DLSS/NGX SDK, and says NVIDIA can disable problematic DLSS integrations as a last resort if public releases cause material stability/performance/image-quality issues. Source: https://developer.nvidia.com/gameworks/nvidia_rtx_sdks_license_12apr2021.pdf
- NVIDIA's Streamline integration checklist says DLSS SR should be integrated close to the start of post-processing, needs mip-map bias, accurate motion vectors, compatible jitter, exposure handling, user-selectable modes, camera reset flags, NGX cleanup, and primary-upscale-only output. It also says production, non-watermarked `nvngx_dlss.dll` should be packaged in release builds. Source: https://developer.nvidia.com/rtx/streamline/get-started
- Streamline's programming guide adds another distribution burden: `sl.interposer.dll` and `sl.common.dll` are mandatory, `sl.dlss.dll` and `nvngx_dlss.dll` are needed when DLSS is used, and integration can involve DXGI/D3D interception or manual hooking. Source: https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md
- Streamline's repository says binary artifacts are not in the GitHub repo and only production builds should be used for released software. Source: https://github.com/NVIDIA-RTX/Streamline

Release implication: a source-only/no-runtime package is the safest public path for now. Bundling `nvngx_dlss.dll` or Streamline binaries needs a separate approval pass covering source, exact file version, production/non-watermarked status, notices, trademark language, and NVIDIA notification/contact uncertainty.

### Unity HDRP and DLSS technical requirements

- Unity HDRP natively supports DLSS through dynamic resolution and camera settings. Source: https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4016.0/manual/deep-learning-super-sampling-in-hdrp.html
- Unity's DLSS technical blog describes DLSS inputs as a low-resolution image, motion vectors, and a high-resolution previous frame, with post-processing and UI/HUD applied after the DLSS output. Source: https://developer.nvidia.com/blog/nvidia-dlss-natively-supported-in-unity-2021-2/
- HDRP documentation also calls out mip-bias correction for DLSS. Source: https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4016.0/manual/deep-learning-super-sampling-in-hdrp.html

Technical implication: the project should keep using V Rising's existing HDRP dynamic-resolution/upscale landmarks as resource landmarks, but it must validate jitter, exposure, mip bias, camera reset, output placement, and post-DLSS UI/post-processing order before calling the MVP playable.

### PureDark reference review

Local reference material:

- `ref/PureDark-VRisingPerfMod/`
- `ref/packages/PureDark-VRisingPerfMod-1.1.0.zip`
- `ref/packages/PureDark-VRisingPerfMod-1.1.0/`

Public/package facts:

- Thunderstore lists PureDark's `VRisingPerfMod` as a 3-year-old mod, dependency string `PureDark-VRisingPerfMod-1.1.0`, with a readme claiming DLSS/FSR2/XeSS support and "MUST DISABLE TAA". Source: https://thunderstore.io/c/v-rising/p/PureDark/VRisingPerfMod/
- The package manifest depends on old `BepInEx-BepInExPack_V_Rising-1.0.0`.
- The package contains `PerfMod.dll`, `PDPerfPlugin.dll`, `nvngx_dlss.dll`, FSR2, XeSS, DirectX compiler binaries, and related DLLs.
- The local GitHub checkout does not contain a `LICENSE` file. Under normal copyright rules, that means we should not reuse the source code or binary ABI as production material.

Useful public technical facts, not copied implementation:

- DLSS-like upscalers need color, depth, motion vectors, jitter, render/output sizes, reset handling, mip bias, and sharpness/mode controls.
- Unity `CommandBuffer.IssuePluginEvent` is a plausible managed/native bridge pattern.
- V Rising historically had an HDRP/custom-post-process route, but the old `CustomVignette` approach is not automatically current or release-safe.
- The package's BepInEx dependency and bundled runtime set are stale relative to today's BepInExPack `1.733.2` ecosystem.

Do not reuse:

- PureDark C# source, native DLLs, exported ABI/function names as a compatibility target, package layout, Patreon/Discord materials, or bundled third-party DLLs.
- Any PureDark-specific monetization/support wording. This project is free and non-commercial.

## MVP Distribution Requirements

### Release-safe package

The diagnostic/playable package should contain only:

- `manifest.json`
- `README.md`
- `CHANGELOG.md`
- `icon.png`
- `ThirdPartyNotices.md`
- `BepInEx/plugins/VrisingDLSS/VrisingDLSS.Plugin.dll`
- `BepInEx/plugins/VrisingDLSS/VrisingDLSS.Native.dll`
- `BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg`

It should not contain:

- `ref/`
- `dist/`
- `artifacts/`
- V Rising game files or interop assemblies
- PureDark files
- NVIDIA runtime DLLs or SDK binaries
- Streamline DLLs
- local SDK-wrapper research builds

### User experience for the first playable build

The first playable build should expose:

- `DLSS.EnableDLSS`
- quality mode
- runtime path status
- RTX/DLSS support status
- render size and target size
- image/output resource status
- fallback reason
- log verbosity
- optional diagnostic overlay

Failure behavior must be quiet and reversible:

- If runtime/GPU/support/resource validation fails, leave native rendering unchanged.
- If resize/reset happens, either recreate DLSS state safely or disable with a clear log reason.
- If image-correctness checks fail during development, keep the package diagnostic-only.

## Technical Route

Prefer direct NGX/DLSS SR over Streamline for the MVP.

Reasoning:

- Current validated runtime path is D3D11/NGX-oriented.
- Stage 8A through Stage 9A already prove same-device D3D11 resources, SR-sized input/output dimensions, successful NGX evaluate, persistent feature reuse, and cross-RenderGraph-callback feature reuse.
- Stage 10A proves a guarded visible-path write-back candidate can repeatedly evaluate into the selected SR output target 30 times before clean shutdown, but it still needs screenshot/visual image-correctness validation.
- Streamline would add interposer/common/plugin DLL distribution and swapchain/present integration complexity that is not needed for DLSS Super Resolution only.

Current validated evidence:

- Stage 8E accepted `CameraColor`, `CameraDepthStencil`, and `Motion Vectors` at `426x284` with `Edge Adaptive Spatial Upsampling` at `720x480`.
- Stage 8F successfully evaluated that SR tuple.
- Stage 8G kept one feature alive for repeated immediate evaluates.
- Stage 9A kept one feature alive across multiple RenderGraph callbacks.

Next route:

1. Validate that Stage 10A output appears in the visible game image without black screen, stale frame, ghosting beyond expected DLSS behavior, or post-process breakage.
2. Capture/preserve screenshots or visual comparison evidence for DLSS off versus the Stage 10A candidate.
3. Add resize/reset/state recreation.
4. Add quality-mode/render-scale and mip-bias handling.
5. Add fallback and user-facing status.
6. Run private/local gameplay QA before any public playable package.

Rejected or high-risk routes:

- Injecting a new RenderGraph pass into gameplay: crashed during Stage 8A research.
- Patching compiler-generated HDRP render functions broadly: crashed during Stage 8A research.
- Targeting old PureDark `CustomVignette` code directly: stale, unlicensed, and not proven safe on current V Rising/BepInExPack.
- Shipping Streamline for MVP: too much distribution and present-path complexity for first SR-only release.

## Time Estimate From Current State

Because Stage 8A through Stage 10A are already proven locally, the remaining time is mostly visible image-correctness validation, normal-user integration, and QA, not basic DLSS viability.

Best-case estimates:

- First visible local DLSS output: 2-5 focused engineering days if the current `Edge Adaptive Spatial Upsampling` target can be safely written/reused.
- Private playable alpha: 1-3 weeks, including resize/reset, quality-mode, fallback, and basic image checks.
- Public Thunderstore playable beta without bundled NVIDIA runtime: 2-5 weeks, assuming no severe image-correctness regression.
- Public package with bundled NVIDIA runtime: unknown until NVIDIA/runtime distribution review is resolved; add at least 1-4 weeks for review, notices, exact binary selection, and wording, and treat it as potentially not approved.

High-risk stretch factors:

- Output write-back appears successful in logs but not in the actual visible image.
- Jitter/exposure/motion-vector conventions are wrong, causing ghosting/flicker.
- Resize/camera reset leaks or crashes NGX state.
- V Rising patch changes HDRP/RenderGraph resource names or call timing.
- Public server policy concerns require stronger disclaimers or narrower support scope.
