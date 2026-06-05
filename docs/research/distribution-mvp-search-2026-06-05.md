# Distribution MVP Search - 2026-06-05

Goal: refresh external facts that affect a free, non-commercial, distributable V Rising DLSS Super Resolution mod.

This is an engineering and release-risk memo, not legal advice.

## Bottom Line

- Thunderstore remains the right mod-ecosystem package shape for a V Rising MVP, with `manifest.json`, `README.md`, and `icon.png` at the zip root and the BepInEx payload routed through `BepInEx/plugins/VrisingDLSS/`.
- `BepInEx-BepInExPack_V_Rising-1.733.2` is still the correct current V Rising Thunderstore dependency string.
- The public package must stay clean-room and source-safe: no V Rising game files, PureDark files, NVIDIA SDK files, NVIDIA runtime DLLs, Streamline DLLs, local wrapper DLLs, `ref/`, `artifacts/`, or `dist/`.
- NVIDIA's public DLSS repo now lists `DLSS 310.6.0 SDK` as the latest release, dated 2026-04-21. This matches the local research runtime family already tested.
- NVIDIA's DLSS integration guidance reinforces the current technical blockers: application ID, early post-processing placement, mip bias, accurate motion vectors, compatible jitter, exposure, user-selectable modes, camera reset, and cleanup.
- Unity HDRP documentation confirms that DLSS is a Windows x64 HDRP dynamic-resolution feature and that HDRP also has FSR 1.0 as a spatial upscaler. V Rising's built-in FSR route is useful as a render-scale/resource landmark, but it is not a DLSS substitute.
- Stunlock's current official posture remains conservative: no official V Rising mod tools, TOS/EULA restrictions around unauthorized mods/software, and no official-server safety guarantee. Public wording should say local/private-world first.
- PureDark's old `VRisingPerfMod` is useful only as historical evidence that the route is possible and that DLSS/FSR2/XeSS need depth/motion-vector inputs. Do not reuse its source, binary ABI, package layout, bundled DLL set, or monetization/support wording.

## Current Project Fit

Already aligned:

- Thunderstore manifest has the current BepInEx dependency.
- Package validator enforces root metadata, 256x256 icon, BepInEx plugin route, diagnostic wording, safe defaults, and absence of forbidden third-party binaries.
- `.gitignore` excludes local reference material, runtime logs, build outputs, chat logs, and DLSS/Streamline/PureDark binaries.
- Runtime evidence now goes beyond diagnostics: `dlss-user-rendering` with the local SDK-wrapper native DLL accepted a `1920x1080 -> 3840x2160` tuple and reached `sequenceSuccesses=11100` with no user-rendering blocked/failed/disabled lines or Windows crash event.

Still not MVP:

- No user-rendering screenshot or frame-pacing evidence has passed.
- Human visual review is still pending for the Stage 10A 4K gameplay comparison.
- Resize/reset, jitter/pre-exposure, render-scale control, mip bias, quality-mode mapping, runtime discovery, and fallback behavior still need validation.
- NVIDIA runtime bundling remains unresolved; the fallback package without bundled runtime must remain available.

## Compliance Findings

### Thunderstore

Thunderstore package docs say a valid package zip needs root `icon.png`, `README.md`, and `manifest.json`; `CHANGELOG.md` is optional. The manifest carries `name`, `description`, `version_number`, `dependencies`, and `website_url`, and dependency strings use `{team}-{package}-{version}`.

Thunderstore's BepInEx packaging docs say BepInEx games use recognized routes such as `BepInEx/plugins`, `BepInEx/core`, `BepInEx/patchers`, `BepInEx/monomod`, and `BepInEx/config`.

Thunderstore global rules require respecting copyright/licensing, avoiding game-file redistribution such as `Assembly-CSharp.dll` unless explicitly allowed, not reuploading others' assets/packages without permission, and avoiding obfuscated code or code that executes downloaded external code where possible.

Project implication:

- Keep the current package route and validator.
- Do not upload a package that depends on runtime downloads, hidden loaders, obfuscated code, or bundled third-party files.
- Keep README wording explicit that the current package is diagnostic until visual/performance validation passes.

### V Rising / Stunlock

Stunlock's March 26, 2026 dev update says no new V Rising content update is currently in development, balance/bug-fix patches may continue, and official mod tools were investigated but V Rising is not structured to support them at Stunlock's desired quality level.

Stunlock's V Rising TOS restricts unauthorized software designed to modify the Service, Game, or Game experience without express consent, and restricts commercial exploitation. The Steam EULA reserves game IP rights and says users must also comply with third-party terms.

Project implication:

- Keep the mod unofficial and non-commercial.
- Do not claim official support, endorsement, official-server safety, anti-cheat safety, or multiplayer-policy approval.
- Keep scope graphics-only: no gameplay rules, networking, saves, server protocol, matchmaking, DRM, or online-service changes.
- Recommend local/private-world testing first.

### NVIDIA DLSS / Runtime

NVIDIA's public DLSS repository is the public RTX DLSS SDK repo and lists `DLSS 310.6.0 SDK` as the latest release.

The current NVIDIA RTX SDK license shown in the DLSS repo includes NVIDIA GPU interoperability and cloud-service limitations for DLSS/NGX SDK use, and gives NVIDIA contact guidance if distribution terms are unsuitable. Older NGX programming guide material says NGX feature DLLs are distributed with an application, but the practical release decision for this mod still needs exact-file and notice review because this is an unofficial plugin to another commercial game.

NVIDIA's Streamline page says Streamline is a framework between the game and render API that abstracts SDK-specific calls. Its DLSS SR checklist calls out application ID, early post-processing placement, mip-map bias, accurate motion vectors, compatible jitter, exposure, selectable modes/dynamic-resolution support, production non-watermarked `nvngx_dlss.dll`, camera reset, and cleanup. The Streamline repository says binary artifacts are not in the GitHub repo and released software should use production builds and signed/original NVIDIA DLLs.

Project implication:

- Direct NGX/D3D11 remains the MVP route. Streamline adds interposer/plugin DLL distribution and signing/supply-chain work that is unnecessary for the first SR-only mod.
- Do not bundle `nvngx_dlss.dll` until a separate review covers exact source, exact version, notices, production/non-watermarked status, NVIDIA trademark wording, and any NVIDIA notification/contact questions.
- Use `PresetMode=Recommended` as a user-facing concept, but keep runtime parameter mapping gated until official DLSS SDK docs/tests prove the exact preset mapping in this bridge.

## Technical Findings

### Unity HDRP

Unity HDRP docs state DLSS support is for Windows x64 with DirectX 11, DirectX 12, or Vulkan. To use DLSS normally in a Unity HDRP project, the NVIDIA package must be enabled, dynamic resolution must be enabled in the HDRP Asset, DLSS must be enabled for cameras, and a quality mode must be set.

HDRP Asset docs list DLSS dynamic-resolution properties including quality modes, injection point, optimal settings, and sharpness. They also list HDRP FSR 1.0 as a spatial super-resolution upscale filter and `Use Mip Bias` as a dynamic-resolution detail setting.

HDRP motion-vector docs confirm motion vectors are per-pixel screen-space motion from one frame to the next, used by TAA and motion blur, and must be enabled in the HDRP Asset/Frame Settings. This reinforces that DLSS visual correctness depends on motion-vector quality, not just successful NGX evaluate calls.

Project implication:

- The existing V Rising FSR Performance route is a useful way to force a real SR tuple and find HDRP's low-res color/depth/motion/output resources.
- The next user-rendering test must capture visual output and frame pacing, because `sequenceSuccesses=11100` proves lifecycle viability but not image quality.
- Remaining engineering should focus on jitter/pre-exposure, mip bias, reset/resize, quality modes, and safe fallback.

### PureDark Reference

PureDark's Thunderstore page still presents `VRisingPerfMod` as a DLSS/FSR2/XeSS performance mod for V Rising and says TAA should be disabled. It depends on the old `BepInEx-BepInExPack_V_Rising-1.0.0`, is three years old, and publicly describes a package with third-party runtime pieces.

The V Rising Mod Wiki licensing page says mods in that community are expected to be open source, need a license file, and that without a license default copyright applies.

Project implication:

- Keep PureDark material in `ref/` only.
- Borrow only high-level public ideas: temporal upscalers need color, depth, motion vectors, jitter/reset, render/output sizes, quality modes, and sharpness/mip-bias handling.
- Do not copy code, ABI names, binaries, bundled runtime choices, hotkey UX, package layout, or support/Patreon wording.

## Updated Time Estimate

Starting from the current local evidence:

- Private local proof that `DLSS.EnableDLSS=true` can visibly render correctly: likely 1-3 focused test sessions if the current output target is actually visible in the final image.
- Private playable alpha for this machine: likely 3-10 engineering days after visual correctness is confirmed, mostly for frame pacing, resize/reset, quality modes, fallback, and config polish.
- Public Thunderstore/GitHub beta without bundled NVIDIA runtime: likely 2-5 weeks if user-rendering visual/performance evidence is good.
- Public package with bundled `nvngx_dlss.dll`: unknown; treat as a separate legal/distribution review and keep a no-runtime package path regardless.

## Sources Checked

- Thunderstore package creation: https://wiki.thunderstore.io/mods/creating-a-package
- Thunderstore BepInEx packaging routes: https://wiki.thunderstore.io/mods/packaging-your-mods
- Thunderstore global rules: https://wiki.thunderstore.io/moderation/global-rules
- Thunderstore V Rising BepInExPack versions: https://new.thunderstore.io/c/v-rising/p/BepInEx/BepInExPack_V_Rising/versions
- V Rising Mod Wiki manual BepInEx install: https://wiki.vrisingmods.com/user/bepinex_install.html
- V Rising Mod Wiki FAQ: https://wiki.vrisingmods.com/community/faq.html
- V Rising Mod Wiki licensing: https://wiki.vrisingmods.com/dev/licensing.html
- V Rising Mod Wiki upload guide: https://wiki.vrisingmods.com/dev/upload_to_thunderstore.html
- Stunlock Dev Update #32: https://blog.stunlock.com/dev-update-32-the-next-era/
- V Rising Steam EULA: https://store.steampowered.com/eula/1604030_eula_1
- V Rising Terms of Service: https://cdn.stunlock.com/legal/Terms_of_Service_VRising.pdf
- NVIDIA DLSS repository: https://github.com/NVIDIA/DLSS
- NVIDIA DLSS license: https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt
- NVIDIA NGX programming guide: https://docs.nvidia.com/ngx/latest/programming-guide/
- NVIDIA Streamline overview: https://developer.nvidia.com/rtx/streamline
- NVIDIA Streamline/DLSS get-started checklist: https://developer.nvidia.com/rtx/streamline/get-started
- NVIDIA Streamline repository: https://github.com/NVIDIA-RTX/Streamline
- NVIDIA DLSS 4.5 news: https://www.nvidia.com/en-us/geforce/news/dlss-4-5-super-resolution-available-now/
- Unity HDRP DLSS docs: https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4012.0/manual/deep-learning-super-sampling-in-hdrp.html
- Unity HDRP Asset docs: https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4015.0/manual/HDRP-Asset
- Unity HDRP motion-vector docs: https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%407.2/manual/Motion-Vectors.html
- Unity dynamic-resolution manual: https://docs.unity3d.com/ja/2022.2/Manual/DynamicResolution.html
- PureDark `VRisingPerfMod` Thunderstore page: https://thunderstore.io/c/v-rising/p/PureDark/VRisingPerfMod/
