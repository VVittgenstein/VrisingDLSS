# Release Readiness Search - 2026-06-05

Goal: assess the current compliance, usability, and technical route for a free, non-commercial, distributable V Rising DLSS Super Resolution mod.

This is engineering research, not legal advice.

## Search Conclusions

1. The project should continue as a clean-room BepInEx IL2CPP plugin plus a clean-room native D3D11/NGX bridge. This remains the smallest viable path for DLSS Super Resolution in V Rising.
2. The public GitHub repository should contain only first-party source, scripts, package metadata, documentation, and notices. Local research material under `ref/`, build outputs under `artifacts/` and `dist/`, chat logs, PureDark files, NVIDIA SDK copies, and NVIDIA runtime DLLs should stay out of Git.
3. Thunderstore is still a good mod-ecosystem target, but the current package must be labeled as diagnostic until DLSS evaluate works. The MVP release package must include root `manifest.json`, `README.md`, `icon.png`, and preferably `CHANGELOG.md` and `ThirdPartyNotices.md`.
4. Current V Rising mod ecosystem dependency remains `BepInEx-BepInExPack_V_Rising-1.733.2`. The current project dependency string is still correct.
5. NVIDIA's current public DLSS SDK release is `DLSS 310.6.0 SDK`, released on 2026-04-21. This matches the local research runtime already tested.
6. NVIDIA SDK/runtime redistribution is not a simple "just ship nvngx_dlss.dll" decision. The SDK license allows object-code distribution when incorporated into a materially functional application, but it also forbids standalone SDK distribution, implied NVIDIA sponsorship, and making SDK parts subject to open-source license terms. NVIDIA's RTX SDK supplement also says DLSS/NGX integrations in applications, including plugins to commercial applications, have notification/trademark/stability obligations. The fallback package without bundled NVIDIA runtime must stay available.
7. Stunlock's current official posture is conservative for mods: no official V Rising modding tools are planned, and the EULA restricts unauthorized third-party programs, mods, add-ons, and interference with online/network play. The public README must keep saying local/private-world testing first and no official-server safety guarantee.
8. Streamline remains a second-phase route. For the first DLSS SR MVP, direct NGX/D3D11 is still preferable because Streamline adds `sl.interposer.dll`, `sl.common.dll`, feature DLL packaging, interposer/device lifecycle constraints, and signature-validation work.

## Sources Checked

- NVIDIA DLSS repository: `https://github.com/NVIDIA/DLSS`
  - Public repo for NVIDIA RTX DLSS SDK.
  - The repo lists `DLSS 310.6.0 SDK` as the latest release, dated 2026-04-21.
- NVIDIA DLSS 310.6.0 release: `https://github.com/NVIDIA/DLSS/releases/tag/v310.6.0`
  - Release notes mention DLSS Frame Generation 5x/6x modes, UI recomposition support, and bug/stability improvements.
- NVIDIA RTX SDK license: `https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt`
  - Allows installing/using the SDK, modifying sample source, and distributing SDK materials in object-code form when incorporated into a software application.
  - Requires material application functionality beyond included SDK portions.
  - Prohibits distributing the SDK as a standalone product, implying NVIDIA sponsorship/endorsement without agreement, bypassing SDK limitations, and causing SDK portions to become subject to open-source license terms.
- NVIDIA RTX SDK supplement PDF: `https://developer.nvidia.com/gameworks/nvidia_rtx_sdks_license_12apr2021.pdf`
  - Covers DLSS SDK and NGX SDK use.
  - States DLSS/NGX are for NVIDIA GPU systems.
  - Requires notification before commercial release of an application, including a plug-in to a commercial application, that incorporates or is based on DLSS/NGX SDK.
  - Requires addressing material technical issues in public DLSS integrations and includes NVIDIA trademark placement/review terms.
- NVIDIA Streamline programming guide: `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
  - Streamline integration can involve interposing D3D/DXGI/Vulkan APIs.
  - Streamline distribution requires `sl.interposer.dll` and `sl.common.dll`; DLSS/NIS additionally require `sl.dlss.dll`, `nvngx_dlss.dll`, and `sl.nis.dll`.
  - NVIDIA recommends validating signatures on Streamline modules and using production signed binaries for release.
- Thunderstore package docs: `https://wiki.thunderstore.io/mods/creating-a-package`
  - Required zip-root files: `icon.png`, `README.md`, `manifest.json`; `CHANGELOG.md` optional.
  - Icon must be a 256x256 PNG.
  - Manifest is UTF-8 JSON with package name, description, version, dependencies, and website URL.
- Thunderstore packaging docs: `https://wiki.thunderstore.io/mods/packaging-your-mods`
  - For BepInEx games, package folder names influence final install location; `BepInEx/plugins` is a recognized route.
- Thunderstore BepInExPack V Rising: `https://new.thunderstore.io/c/v-rising/p/BepInEx/BepInExPack_V_Rising/versions`
  - Current dependency string: `BepInEx-BepInExPack_V_Rising-1.733.2`.
  - Version `1.733.2` was uploaded on 2025-05-17.
- V Rising EULA: `https://store.steampowered.com/eula/1604030_eula_1`
  - Restricts unauthorized third-party programs, mods, add-ons, and interference with online or network play.
  - Also restricts unauthorized copying, distribution, modification, reverse engineering, and derivative works.
- V Rising Terms of Service: `https://cdn.stunlock.com/legal/Terms_of_Service_VRising.pdf`
  - Requires agreement to the TOS, Privacy Policy, and game EULA to use the service.
- Stunlock Dev Update #32: `https://blog.stunlock.com/dev-update-32-the-next-era/`
  - Posted 2026-03-26.
  - Says no new V Rising content update is currently being developed; balance and bug-fix patches may continue.
  - Says official modding support was investigated but V Rising is not structured to provide mod tools at the standard Stunlock would want.
- V Rising Mod Wiki - upload to Thunderstore: `https://wiki.vrisingmods.com/dev/upload_to_thunderstore.html`
  - Community process expects a tested V Rising mod zip with icon, README, manifest, and preferably changelog.
- V Rising Mod Wiki - licensing: `https://wiki.vrisingmods.com/dev/licensing.html`
  - Community expectation is open-source mods with a public repository and a license.
  - Manifest dependencies should accurately list dependencies.
  - V Rising mods are not exempt from copyright law.
- V Rising Mod Wiki - how mods work: `https://wiki.vrisingmods.com/dev/how-mods-work.html`
  - V Rising mods use BepInEx, IL2CPP interop wrappers, and DOTS/ECS.
  - BepInEx loads DLLs in `BepInEx/plugins/` and calls `Load()`.
  - Client mods can change UI or visuals but should not change game rules.

## Current Project Fit

Already aligned:

- GitHub repository has a source-only snapshot on `main`.
- `.gitignore` excludes `ref/`, `dist/`, `artifacts/`, chat logs, build outputs, NVIDIA runtime DLLs, and PureDark binaries.
- The Thunderstore manifest uses `BepInEx-BepInExPack_V_Rising-1.733.2`.
- The package template has root metadata and a 256x256 PNG icon.
- Local diagnostics prove plugin load, HDRP hook discovery, render-thread callback, D3D11 native texture/device access, and production DLSS runtime load/release.
- Stage 6 now reports the SDK-wrapper gate honestly instead of treating the production runtime's missing helper exports as an ordinary runtime failure.
- A local SDK-wrapper research build has passed Stage 6 DLSS capability query and Stage 7 DLSS feature create/release.

Still missing for MVP:

- Real DLSS evaluate path with game frame resources.
- A reliable in-frame motion-vector source. `_CameraMotionVectorsTexture` was `null` in the all-low main-menu test.
- Persistent DLSS feature lifecycle around actual color/depth/motion-vector resources.
- Render-scale control, mip-map bias handling, camera reset, resize handling, quality modes, overlay, and safe fallback.
- A normal-user install path and config location under `BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg`.
- Release review for any package that bundles `nvngx_dlss.dll`.

## Route Decision

Primary route for MVP:

1. Keep using BepInEx IL2CPP and Harmony/reflective probes.
2. Keep using the optional local NVIDIA SDK root CMake path for SDK-wrapper research builds.
3. Keep NVIDIA SDK headers/libs out of the public repository unless a separate review approves the exact files and notices.
4. Implement the first DLSS evaluate probe only after frame resources are aligned.
5. Test motion vectors in an actual gameplay scene before assuming the main-menu all-low result is final.
6. Use Thunderstore as the mod-manager package shape, but do not publicly upload until DLSS evaluate is proven and the README accurately describes the package.

Avoid for MVP:

- Streamline as the first path, because its interposer and DLL distribution surface is larger.
- DLSS Frame Generation.
- Public/official-server support claims.
- Bundling NVIDIA runtime without release review.
- Any PureDark code, ABI, binary, or private material.

## Updated Time Estimate

This estimate starts from the current 2026-06-05 evidence, not from an empty repository.

Fast path, if SDK-wrapper linking is straightforward and motion vectors appear in gameplay:

- First SDK-wrapper-backed capability query and DLSS create/release: validated locally on 2026-06-05.
- First DLSS evaluate visible image: 1-3 weeks.
- Private-world playable alpha: 3-5 weeks.
- Public Thunderstore/GitHub MVP release: 5-8 weeks.

Harder path, if motion vectors require a different HDRP hook point or custom generation:

- First visible DLSS image: 3-6 weeks.
- Private-world playable alpha: 6-9 weeks.
- Public MVP release: 8-12+ weeks.

Unknown/legal path:

- Bundling `nvngx_dlss.dll` may add unbounded release delay if NVIDIA license/notification/trademark questions require explicit written clarification. The safe plan is to ship a fallback package that does not bundle the runtime, and treat a convenience package as separately reviewed.

## Next Engineering Steps

1. Keep the optional `VRISINGDLSS_NGX_SDK_ROOT` / SDK-wrapper CMake path off by default for release-safe builds.
2. Use the local MSVC SDK-wrapper research build for Stage 7 create/release evidence. The first ProjectID create/release pass was validated on 2026-06-05.
3. Test frame-resource probing in an actual local/private gameplay scene, not just main menu.
4. If motion vectors remain missing, patch additional HDRP camera/update points and inspect `HDCamera` frame history/motion-vector fields.
5. After frame resources are proven, implement the smallest evaluate path with DLSS disabled by default until image correctness is verified.
