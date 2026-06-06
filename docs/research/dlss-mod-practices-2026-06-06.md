# DLSS Mod Practice Survey - 2026-06-06

Status: initial survey after the first successful V Rising FSR Off
`960x540 -> 1920x1080` DLSS user-rendering proof.

## Why This Matters Now

The v6 runtime proof shows V Rising can be driven into the same basic shape that
other upscaler replacement tools expect: a lower-resolution temporal render input,
motion/depth resources, a larger output target, and repeated successful DLSS evaluate
calls.

That changes the next risk from "can DLSS run at all?" to "can this become a clean,
safe, distributable mod?"

## Official Sources Checked

- NVIDIA Streamline overview:
  `https://developer.nvidia.com/rtx/streamline`
- NVIDIA Streamline GitHub / programming guide:
  `https://github.com/NVIDIA-RTX/Streamline`
  `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
- Unity HDRP Dynamic Resolution docs:
  `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4013.0/manual/Dynamic-Resolution.html`
- NVIDIA RTX SDK license:
  `https://developer.nvidia.com/gameworks/nvidia_rtx_sdks_license_12apr2021.pdf`
- BepInEx overview:
  `https://bepinex.org/`
- BepInExPack V Rising on Thunderstore:
  `https://new.thunderstore.io/c/v-rising/p/BepInEx/BepInExPack_V_Rising/`
- V Rising Mod Wiki manual install guide:
  `https://wiki.vrisingmods.com/user/Mod_Install.html`

## Existing Mod / Tool Patterns Checked

- OptiScaler:
  `https://github.com/optiscaler/OptiScaler`
- DLSSTweaks usage references:
  `https://github.com/emoose/DLSSTweaks`
  `https://forums.hardwarezone.com.sg/threads/dlsstweaks-customize-pre-upscale-resolution-dlss-type-dlss-version-force-dlaa-for-any-game-that-supports-dlss.6950858/`

These are references for install UX, configuration, logging, and failure modes only.
Do not copy code, binaries, signatures, reverse-engineered ABI details, or patches
from third-party mods into this clean-room project.

## Useful Findings

- Unity HDRP's documented DLSS path is tied to Dynamic Resolution. HDRP requires
  Dynamic Resolution to be enabled, per-camera Allow Dynamic Resolution, and a scaler
  via `DynamicResolutionHandler.SetDynamicResScaler(...)`. The v6 result matches this
  architecture: when the active handler's runtime fraction is 0.5, `HDCamera` and
  `CameraColor` become `960x540`.
- Streamline is officially positioned as a cross-IHV integration layer, but its normal
  model assumes early integration with the application's graphics API/device path and
  signed module validation. This makes Streamline a possible later route, not a cheap
  drop-in replacement for the current direct NGX/D3D11 bridge.
- Streamline security guidance is relevant even if the current route stays direct
  NGX/D3D11: shipping should validate trusted runtime/module sources and avoid
  unsigned development DLLs in release builds.
- Streamline's GitHub repository does not include all binary artifacts. The project
  states that binary artifacts and DLSS feature DLLs must be obtained from release
  packages, and recommends production builds plus NVIDIA-signed DLLs for shipping.
- NVIDIA's RTX SDK license allows distribution only under specific conditions, and
  explicitly forbids distributing SDK portions as a standalone product. This does not
  automatically prove the mod may bundle `nvngx_dlss.dll`; runtime packaging remains
  a release blocker until the exact permissible route is verified.
- OptiScaler and DLSSTweaks mostly operate on games that already expose a DLSS/FSR/XeSS
  temporal upscaler path. Their relevance is install/config practice, not core
  V Rising integration. Common patterns include copying a small set of files into the
  game folder, using an INI/config tool, supporting DLL override paths, warning users
  about fake sites/scam builds, and documenting anti-cheat/file-integrity caveats.
- BepInEx remains the right mod-loading surface for this project. The current
  V Rising ecosystem expects BepInExPack, mod DLLs under `BepInEx/plugins/`, readable
  install/dependency notes, and predictable config/log locations. This fits the
  current `BepInEx/plugins/VrisingDLSS/` package route; any future move to
  `BepInEx/config/` should be an explicit compatibility decision.

## Implications For VrisingDLSS

- The direct NGX/D3D11 route remains valid for the playable MVP prototype because v6
  produced repeated successful DLSS user-rendering evaluates.
- The render-scale intervention should be promoted out of "probe thinking" into a
  guarded runtime feature only after visual correctness, resize/reset, fallback, and
  performance checks.
- The mod should expose a clear BepInEx config surface for quality mode, enable/disable,
  runtime path / runtime acquisition mode, logging level, and safe fallback.
- The release package must not require users to manually fetch an arbitrary DLL. But
  before bundling any NVIDIA binary, verify the license path. Possible routes to
  investigate:
  - bundle only if the NVIDIA SDK/runtime license permits this mod's distribution model;
  - install/download from an official NVIDIA source at setup time with checksum/signature
    verification;
  - use a driver/NGX system location if there is an official supported lookup path;
  - document an unsupported research-only runtime path separately from release builds.
- Release docs should include source authenticity warnings, because public DLSS mod
  tooling has fake-site/scam-copy failure modes.
- The public package should continue to be explicit about what is local research-only:
  SDK-wrapper native builds, NVIDIA runtime DLL copies in `ref/`, and Computer Use
  automation are not release artifacts.

## Next Research Items

1. Read the exact NVIDIA DLSS/NGX/Streamline redistributable terms and decide whether
   a free Thunderstore/GitHub mod can bundle required runtime DLLs.
2. Inspect Streamline release packaging and signatures to understand whether it offers
   a cleaner redistribution story than direct `nvngx_dlss.dll`.
3. Review Thunderstore/V Rising package expectations for native DLLs, dependencies,
   config defaults, and user install instructions.
4. Compare OptiScaler/DLSSTweaks configuration UX for ideas only: INI structure,
   DLL override field, logging, authenticity warnings, and safe fallback messaging.
