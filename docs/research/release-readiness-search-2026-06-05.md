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
9. Stage 8A is now specifically a RenderGraph resource-scope problem. Latest local evidence found `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer` handles, but Unity documentation confirms these handles must be used only inside a valid RenderGraph record+execute/read-write scope. The next technical route is a RenderGraph-scoped diagnostic pass or execution hook, not more ordinary method-prefix probing.

2026-06-05 continuation update:

- Rechecked Thunderstore's current BepInEx package-structure documentation. Required package metadata remains at the zip root, but BepInEx-loaded files should be staged under a recognized route such as `BepInEx/plugins`. The package script now emits `BepInEx/plugins/VrisingDLSS/...` instead of a generic root `VrisingDLSS/...` folder, so mod-manager and manual install paths align.
- Added a local Thunderstore package validator that checks root metadata, 256x256 PNG icon dimensions, manifest shape, the required BepInEx plugin payload entries, and absence of forbidden PureDark/NVIDIA/runtime binaries. The packaging script now runs this validator automatically.
- Added a GitHub Actions build/package workflow pinned to `windows-2022`/Visual Studio 2022. Current GitHub runner-image notices say `windows-latest` is moving to newer Windows/Visual Studio images in June 2026, so pinning avoids an avoidable native-build variable while the MVP is still stabilizing.
- Added a release-readiness status script that separates upload-shaped diagnostic package readiness from true DLSS MVP readiness. The script keeps Stage 8A and release DLSS enable/default config as explicit blocked gates instead of letting package validation be mistaken for product completion.
- Rechecked NVIDIA DLSS/RTX SDK, Stunlock, and Unity RenderGraph sources. No source changed the current route decision: keep a source-safe package without bundled NVIDIA runtime by default; do not rely on PureDark binaries or ABI; continue Stage 8A through a RenderGraph-scoped execution path.
- Rechecked Unity HDRP 14 DLSS/dynamic-resolution docs and the Unity 2022.3 Graphics source route. HDRP 14 supports DLSS on Windows x64 with DirectX 11, DirectX 12, and Vulkan, but it requires the NVIDIA package/module and per-HDRP-asset/per-camera enablement. Local V Rising metadata lists `UnityEngine.NVIDIAModule.dll`, but the local install does not contain a generated NVIDIA interop assembly or `NVUnityPlugin`/`nvngx` binary. The project therefore keeps the clean-room native NGX/D3D11 bridge as the primary path and now logs optional Unity NVIDIA module availability in the read-only hook probe.
- Added a read-only upscaler-state probe for V Rising's built-in FSR/upscale controls. A main-menu run observed `SetFSRParameters(1, true)` and `SetUpscaleFilter(EdgeAdaptiveScalingUpres, 0.59)`, confirming the HDRP upscaler route is active at runtime and useful as a landmark. It still does not replace the DLSS depth/motion-vector input requirement.
- Narrowed Stage 8A helper configuration after a main-menu run crashed with `coreclr.dll` `0xc00000fd` while broad Harmony call logging patched `DLSSPass.Render`. `dlss-evaluate-inputs` no longer enables broad call logging, and Harmony call probing now uses a conservative target list.
- Re-ran the narrowed Stage 8A helper in the main menu with broad Harmony call logging disabled. It ran through the diagnostic window without a Windows crash event, but produced only `Partial` evidence because no RenderGraph texture materialization or successful engine-owned `GetTexture` callback was observed there.
- Inspected Unity HDRP `DLSSPass` interop and confirmed its resource model contains `source`, `output`, `depth`, and `motionVectors`. A targeted runtime prefix on `DLSSPass.Render` was rejected after it crashed V Rising in `UnityPlayer.dll` with `0x80000003` before the prefix logged.
- Cross-checked Unity's 2022.3 HDRP `DLSSPass.cs` source against the local V Rising interop. The official source confirms the same source/output/depth/motion-vector grouping and shows that HDRP's NVIDIA path also depends on render size, final viewport, TAA jitter, reset state, and pre-exposure. The local metadata probe now records this as a static interop check.

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
  - A generic folder in the zip root is not the right normal-user target for a BepInEx plugin; use `BepInEx/plugins/VrisingDLSS/` in the Thunderstore zip.
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
- Unity Core RP TextureHandle docs: `https://docs.unity.cn/Packages/com.unity.render-pipelines.core%4017.0/api/UnityEngine.Experimental.Rendering.RenderGraphModule.TextureHandle.html`
  - `TextureHandle` is tied to one RenderGraph record+execute phase, may not represent an allocated texture, and should not be used outside RenderGraph execution.
- Unity Core RP 14.1 RenderGraphBuilder docs: `https://docs.unity.cn/cn/Packages-cn/com.unity.render-pipelines.core%4014.1/api/UnityEngine.Rendering.RenderGraphModule.RenderGraphBuilder.html`
  - Documents Unity 2022-era `ReadTexture`, `ReadWriteTexture`, `UseColorBuffer`, `UseDepthBuffer`, and `SetRenderFunc` APIs.
- Unity HDRP 14 DLSS docs: `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/deep-learning-super-sampling-in-hdrp.html`
  - Documents HDRP-native DLSS support on Windows x64 for DirectX 11, DirectX 12, and Vulkan.
  - Requires adding/enabling the NVIDIA package, enabling DLSS in the HDRP Asset, enabling dynamic resolution and DLSS per camera, and setting a DLSS quality mode.
- Unity HDRP 14 dynamic-resolution docs: `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4014.0/manual/Dynamic-Resolution.html`
  - Dynamic resolution lowers the main render target resolution and upscales to the back buffer at the end of the frame.
  - HDRP's upscale filter list includes DLSS, FSR1, TAA Upscale, CAS, and Catmull-Rom, with FSR1 documented as a spatial upscaler.
- Unity 2022.3 HDRP `DLSSPass.cs` source: `https://raw.githubusercontent.com/Unity-Technologies/Graphics/2022.3/staging/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`
  - `ViewResourceHandles` groups source/output/depth/motion-vector resources.
  - The NVIDIA render path submits source, depth, motion vectors, optional bias color mask, and output with jitter, reset, render-size, and viewport state.
- Unity 2022.3 NVIDIA module scripting API: `https://docs.unity3d.com/2022.3/Documentation/ScriptReference/UnityEngine.NVIDIAModule.html`
  - Documents the Unity NVIDIA module, plugin loading, DLSS context/resource structures, and feature availability APIs.
- Unity RenderGraph texture-use manual: `https://docs.unity.cn/6000.0/Documentation/Manual/urp/render-graph-read-write-texture.html`
  - Documents declaring texture inputs/outputs during graph recording and using handles in `SetRenderFunc`.
- Stage 8A focused search note: `docs/research/stage8a-rendergraph-search-2026-06-05.md`
  - Consolidates latest runtime evidence and official RenderGraph route decision.

## Current Project Fit

Already aligned:

- GitHub repository has a source-only snapshot on `main`.
- `.gitignore` excludes `ref/`, `dist/`, `artifacts/`, chat logs, build outputs, NVIDIA runtime DLLs, and PureDark binaries.
- The Thunderstore manifest uses `BepInEx-BepInExPack_V_Rising-1.733.2`.
- The package template has root metadata and a 256x256 PNG icon.
- The package script now stages plugin files under `BepInEx/plugins/VrisingDLSS/` in the zip, matching Thunderstore's BepInEx package routing guidance.
- The mod-folder config file target `BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg` is now implemented in the plugin, local install helper, diagnostic config helper, status helper, and Thunderstore package.
- `scripts/validate-thunderstore-package.ps1` verifies the actual zip layout, diagnostic-package wording, safe default config toggles, and release-safe contents before a package is treated as upload-shaped.
- `.github/workflows/build-package.yml` now builds the plugin/native bridge, runs release-boundary and package validation, and uploads the Thunderstore zip as an artifact.
- `scripts/get-release-readiness-status.ps1` reports whether the current state is merely diagnostic-package-ready or truly MVP-ready.
- Local diagnostics prove plugin load, HDRP hook discovery, render-thread callback, D3D11 native texture/device access, and production DLSS runtime load/release.
- Stage 6 now reports the SDK-wrapper gate honestly instead of treating the production runtime's missing helper exports as an ordinary runtime failure.
- A local SDK-wrapper research build has passed Stage 6 DLSS capability query and Stage 7 DLSS feature create/release.
- Stage 8A DLSS evaluate-input probing is implemented to validate real color/output/depth/motion D3D11 resources before calling evaluate. A main-menu run starts the probe but blocks because source/output RTHandles are not exposed there and `_CameraMotionVectorsTexture` remains `null`.
- Later Stage 8A RenderGraph runs found the expected texture handles by name. The builder-declaration probe observes `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer` declarations without materializing textures. Ordinary prefixes still do not run inside a valid resource scope, so the current probe avoids direct prefix `GetTexture` calls and passively hooks engine-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` calls.
- The loader-stage hook probe now also catalogs HDRP DLSS/FSR/upscale methods and optional Unity NVIDIA module types, so future runtime logs can distinguish "built-in Unity DLSS unavailable/stripped" from "native bridge route still blocked on frame resources."
- Stage 2B upscaler-state probing now has main-menu proof that V Rising sets HDRP's FSR/upscale state at runtime: `CatmullRom`/`100` changed to `EdgeAdaptiveScalingUpres`/`58.999996` after `SetFSRParameters` and `SetUpscaleFilter`.
- Stage 8A helper configs now avoid broad Harmony call logging by default; this keeps the safer resource-materialization route distinct from the rejected high-frequency `DLSSPass.Render` call-count route.
- The narrowed Stage 8A helper has main-menu stability evidence, but still needs gameplay-scene or later-resource-scope evidence before first evaluate can be implemented.
- `DLSSPass` is useful as a resource-shape map, but direct Harmony patching of `DLSSPass.Render` is now rejected for the current V Rising IL2CPP build.

Still missing for MVP:

- Real DLSS evaluate path with game frame resources.
- Runtime Stage 8A evidence from an actual local/private gameplay scene. `_CameraMotionVectorsTexture` was `null` in the all-low main-menu test, and the observed main-menu callback did not expose source/output RTHandles.
- Persistent DLSS feature lifecycle around actual color/depth/motion-vector resources.
- Render-scale control, mip-map bias handling, camera reset, resize handling, quality modes, overlay, and safe fallback.
- Release review for any package that bundles `nvngx_dlss.dll`.

## Route Decision

Primary route for MVP:

1. Keep using BepInEx IL2CPP and Harmony/reflective probes.
2. Keep using the optional local NVIDIA SDK root CMake path for SDK-wrapper research builds.
3. Keep NVIDIA SDK headers/libs out of the public repository unless a separate review approves the exact files and notices.
4. Implement the first DLSS evaluate probe only after Stage 8A proves frame resources are aligned.
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

Fast path, if a RenderGraph execution callback or injected pass can be added cleanly:

- First SDK-wrapper-backed capability query and DLSS create/release: validated locally on 2026-06-05.
- First DLSS evaluate-input pass: 1-2 weeks.
- First DLSS evaluate visible image: 2-4 weeks.
- Private-world playable alpha: 4-6 weeks.
- Public Thunderstore/GitHub MVP release: 6-9 weeks.

Harder path, if RenderGraph pass injection is blocked or motion vectors are not valid in gameplay:

- First visible DLSS image: 4-8 weeks.
- Private-world playable alpha: 8-12 weeks.
- Public MVP release: 10-14+ weeks.

Unknown/legal path:

- Bundling `nvngx_dlss.dll` may add unbounded release delay if NVIDIA license/notification/trademark questions require explicit written clarification. The safe plan is to ship a fallback package that does not bundle the runtime, and treat a convenience package as separately reviewed.

## Next Engineering Steps

1. Keep the optional `VRISINGDLSS_NGX_SDK_ROOT` / SDK-wrapper CMake path off by default for release-safe builds.
2. Use the upscaler-state probe during gameplay tests to confirm V Rising's active HDRP upscaler filter, render fraction, and dynamic-resolution state.
3. Continue the safer RenderGraph resource materialization route instead of injecting a new pass or patching compiler-generated render functions.
4. Use the current `GetTexture` postfix as a passive detector while testing gameplay. Keep rejected high-risk routes disabled unless intentionally reproducing crash evidence.
5. Run `dlss-evaluate-inputs` in an actual local/private gameplay scene after a safe resource-scope path exists, not just in the main menu.
6. After Stage 8A proves frame resources are aligned, implement the smallest evaluate path with DLSS disabled by default until image correctness is verified.
