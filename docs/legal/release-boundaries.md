# Release Boundaries

This project should remain source-only until a release review approves otherwise.

## Allowed In This Repository

- Original C# plugin source.
- Original C++ native bridge source.
- Build scripts and package metadata.
- Documentation and third-party notices.
- Links to official SDK download pages.
- Free, non-commercial release metadata and notices.

## Not Allowed Without Separate Review

- PureDark source copied into production code.
- PureDark `PDPerfPlugin.dll`, `PerfMod.dll`, Patreon files, Discord files, or authentication code.
- V Rising game DLLs, modified game files, or decompiled game source.
- NVIDIA `nvngx_dlss.dll`, Streamline DLLs, SDK binaries, or headers committed under the project MIT license.
- Local SDK-wrapper research binaries or intermediate native build outputs.
- Any file that implies endorsement by Stunlock Studios, NVIDIA, or PureDark.
- Paid-build links or membership-gated distribution requirements.
- Any runtime code path that downloads executable code or runtime DLLs from an external source at game launch.

## NVIDIA SDK/Runtime Review Gate

Before any package bundles `nvngx_dlss.dll`, NVIDIA SDK wrapper binaries, NVIDIA headers, or Streamline DLLs, the release review must confirm:

- The exact files come from an approved NVIDIA distribution path.
- The package has material functionality beyond the SDK/runtime files and does not distribute the SDK as a standalone product.
- NVIDIA files are not presented as covered by this project's MIT license.
- Required NVIDIA license notices and trademark/disclaimer language are included.
- The package does not imply NVIDIA sponsorship or endorsement.
- Any applicable NVIDIA notification, trademark-placement, OTA, support, or technical-quality obligations have been considered, including the RTX SDK supplement's notification requirement before commercial release of an application or plugin to a commercial application that incorporates or is based on DLSS/NGX SDKs.
- A fallback package without NVIDIA runtime files remains available.

## V Rising / Thunderstore Review Gate

Before any public package is described as playable, the release review must confirm:

- The package does not include V Rising game files, modified game files, decompiled game source, or generated interop DLLs.
- The package does not reupload another mod author's code, binaries, assets, or package contents without explicit redistribution permission.
- The package uses the BepInEx Thunderstore route `BepInEx/plugins/VrisingDLSS/` and declares the current V Rising BepInExPack dependency.
- The README does not claim that official/public server use is allowed or risk-free.
- The package is tested in a local/private environment and is not represented as a working DLSS gameplay release until the MVP visual/performance gates pass.
- The package is not obfuscated and does not execute downloaded code or hidden telemetry.

## User-Facing Disclaimer Requirements

Every public release should state:

- Unofficial project.
- Client-side graphics experiment.
- No gameplay, network, cheat, or server protocol changes are intended.
- Use on official/public servers is not guaranteed to be allowed and may be treated as an unauthorized third-party program.
- Local/private testing is recommended before any server use.
- Users are responsible for EULA and server-rule compliance.
- The package is free and non-commercial.

Pre-MVP diagnostic packages must also state that they do not enable DLSS yet and are not ready for public gameplay use.
