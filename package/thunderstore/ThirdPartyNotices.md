# Third Party Notices

VrisingDLSS is an unofficial clean-room diagnostic scaffold for V Rising.

## Not Included

This package does not include:

- PureDark source code or binaries.
- NVIDIA DLSS runtime files such as `nvngx_dlss.dll`.
- NVIDIA Streamline files.
- V Rising game files.
- Decompiled or modified game assemblies.

## Runtime Dependency

This package declares a Thunderstore dependency on:

- `BepInEx-BepInExPack_V_Rising-1.733.2`

BepInEx is installed by the mod manager or by the user from its own package. It is not bundled in this package.

## Own Binaries

The following binaries are built from this repository:

- `VrisingDLSS.Plugin.dll`
- `VrisingDLSS.Native.dll`

## NVIDIA DLSS Runtime

DLSS runtime redistribution has not been approved for this package. Current diagnostic builds may load a user-supplied runtime path for validation and release it. Guarded NGX init/query diagnostics may report that NVIDIA SDK wrapper integration is required before capability query can run. Users must follow the project README and applicable NVIDIA terms for any required runtime files unless a separate release review approves bundling a specific production runtime.

## Trademarks

V Rising is a trademark of Stunlock Studios. NVIDIA and DLSS are trademarks or registered trademarks of NVIDIA Corporation. PureDark is referenced only as historical modding context. This project is not affiliated with, endorsed by, or sponsored by Stunlock Studios, NVIDIA, PureDark, or Thunderstore.
