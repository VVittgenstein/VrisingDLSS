# Distribution Compliance Follow-up - 2026-06-05

This follow-up search focuses on whether a free, non-commercial V Rising DLSS mod can be distributed through the V Rising mod ecosystem without shipping files or claims that should stay out of the public package.

## Sources Checked

- Thunderstore global rules: `https://wiki.thunderstore.io/moderation/global-rules`
- Thunderstore package creation guide: `https://wiki.thunderstore.io/mods/creating-a-package`
- Thunderstore BepInEx package routing guide: `https://wiki.thunderstore.io/mods/packaging-your-mods`
- Thunderstore BepInExPack V Rising page: `https://new.thunderstore.io/c/v-rising/p/BepInEx/BepInExPack_V_Rising/`
- V Rising EULA: `https://store.steampowered.com/eula/1604030_eula_0`
- V Rising Terms of Service: `https://cdn.stunlock.com/legal/Terms_of_Service_VRising.pdf`
- NVIDIA RTX SDKs license: `https://developer.nvidia.com/gameworks/nvidia_rtx_sdks_license_12apr2021.pdf`
- Unity HDRP Camera DLSS documentation: `https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition%4017.0/manual/HDRP-Camera.html`

## Findings

Thunderstore publication is compatible with the current packaging route if the package keeps root `manifest.json`, `README.md`, `icon.png`, and uses the BepInEx route `BepInEx/plugins/VrisingDLSS/` for plugin payload files. The V Rising BepInExPack page continues to identify `BepInEx-BepInExPack_V_Rising-1.733.2` as the current dependency string, matching the repository manifest.

Thunderstore moderation rules make the release boundary non-negotiable: do not include V Rising game files, do not reupload other authors' assets or packages without permission, avoid obfuscated or externally downloaded code paths, and do not publish an untested or non-functional package as a working mod.

Stunlock's EULA/TOS create a user-risk boundary for public or official server use. The public package should describe this as an unofficial client-side graphics experiment, recommend local/private testing, avoid claims that official servers allow it, and state that users are responsible for EULA and server-rule compliance.

NVIDIA's RTX SDK license allows distribution only in the context of an application with material functionality beyond the SDK portions and prohibits standalone redistribution. This supports the current default package boundary: no `nvngx_dlss.dll`, no SDK headers, no Streamline DLLs, and no NVIDIA SDK-wrapper binaries in the public package unless a separate release review approves the exact files, notices, and trademark/disclaimer obligations.

Unity HDRP documentation reinforces the technical route already chosen: DLSS is gated by camera dynamic resolution and camera DLSS permission, and HDRP dynamic resolution is the render-scale mechanism. V Rising's FSR setting is useful as a diagnostic landmark but is not a DLSS dependency.

## Release Gate Updates

The package can be public as a diagnostic/scaffold package only while it says it is not ready for public gameplay use. A playable MVP release needs stronger evidence:

1. `DLSS.EnableDLSS=true` must pass runtime validation with V Rising `FsrQualityMode=Off`.
2. The mod must own render-scale control rather than relying on V Rising FSR.
3. Visual/performance evidence must show a useful normal-user result, not only a diagnostic tuple.
4. The package must stay free, non-commercial, unofficial, and source-backed.
5. Release artifacts must exclude game files, PureDark files, NVIDIA runtime/SDK files, SDK-wrapper research binaries, local logs, screenshots, and `ref/` material.
