# VrisingDLSS

Clean-room work toward an unofficial, distributable DLSS Super Resolution mod for V Rising.

## Current Status

This repository is at the research and scaffold stage. It can build and package the current diagnostic scaffold, but it does not yet enable DLSS in game.

The MVP target is a free, non-commercial, clean-room V Rising DLSS Super Resolution mod that can be distributed through GitHub/source release and the V Rising mod ecosystem. See [MVP definition](docs/mvp.md).

The current implementation goal is a source-only, legally conservative package:

- Own C# BepInEx IL2CPP plugin.
- Own native D3D11/DLSS bridge.
- Read-only runtime diagnostics, native render-event smoke tests, D3D11 texture pointer probes, HDRP frame resource probes, optional user-supplied DLSS runtime load/release probe, optional guarded NGX init/query probe, optional SDK-wrapper DLSS feature create/release probe, and optional real-frame DLSS evaluate input probe before any DLSS evaluate path.
- No PureDark source or binaries in production code.
- No bundled `nvngx_dlss.dll` by default.
- Clear user-facing install, diagnostics, and risk documentation.
- No monetization path or paid-build dependency.

Latest local validation: the C# plugin and native bridge build successfully, the native export table includes the diagnostic probes through API version 7, the render-thread/D3D11/runtime probes pass locally, and a local SDK-wrapper research build passes Stage 6 DLSS init/capability query plus Stage 7 DLSS feature create/release. Stage 8A evaluate-input probing starts in the main menu and correctly reports blocked because source/output RTHandles and motion vectors are not present there; it still needs local/private gameplay evidence. Release-safe builds still do not link or bundle NVIDIA SDK/runtime files. The Thunderstore zip contains only this project's own binaries and metadata. See [local runtime staging](docs/development/local-runtime-staging-2026-06-05.md).

## What Is In Scope

- Windows client-side V Rising mod.
- BepInExPack V Rising 1.733.2 or later.
- DirectX 11 first.
- DLSS Super Resolution first.
- Local/private-world testing first.

## What Is Out Of Scope For The First Release

- DLSS Frame Generation.
- Official-server safety guarantees.
- PureDark compatibility.
- Shipping PureDark binaries.
- Shipping NVIDIA SDK/runtime files until the distribution review is complete.
- Proton/Steam Deck support.

## Documentation

- [Install guide](docs/install.md)
- [MVP definition](docs/mvp.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Runtime validation plan](docs/development/runtime-validation.md)
- [NGX/DLSS API notes](docs/development/ngx-api-notes.md)
- [Build notes](docs/development/build-notes.md)

## Reference Material

Third-party material lives under `ref/` for static research only. See [ref/README.md](ref/README.md).

## Research

See [docs/research/vrising-dlss-distributable-mod-research.md](docs/research/vrising-dlss-distributable-mod-research.md).

Latest release-readiness search snapshot: [docs/research/release-readiness-search-2026-06-05.md](docs/research/release-readiness-search-2026-06-05.md).

## Local Preflight

To inspect whether V Rising, BepInEx, and generated interop assemblies are available on the current machine:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1
```

For a specific local game folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\probe-vrising-render-metadata.ps1 -GamePath "C:\path\to\VRising"
```

To check that source/package trees do not contain forbidden third-party binaries:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-release-boundary.ps1
```

## Release Packaging

Current packages are diagnostic artifacts, not the MVP playable DLSS release.

The GitHub Actions workflow builds the plugin/native bridge on `windows-2022`, checks the release boundary, packages the Thunderstore zip, validates the zip layout, and uploads it as a workflow artifact. It does not create a public GitHub Release automatically.

For local packaging:

```powershell
dotnet build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
cmake -S src\VrisingDLSS.Native -B artifacts\native-build -A x64
cmake --build artifacts\native-build --config Release
powershell -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1
powershell -ExecutionPolicy Bypass -File scripts\validate-thunderstore-package.ps1
```

The packaging script runs the Thunderstore package validator automatically. The standalone validator is useful when checking an existing zip.

To write a one-stage diagnostic config and analyze a BepInEx log:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage d3d11
powershell -ExecutionPolicy Bypass -File scripts\analyze-bepinex-log.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\get-runtime-validation-status.ps1 -GamePath "C:\path\to\VRising"
```

To install the declared BepInExPack dependency into a local test folder without launching the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising" -DryRun
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising"
```

## Repository Layout

```text
src/
  VrisingDLSS.Plugin/   BepInEx IL2CPP plugin scaffold
  VrisingDLSS.Native/   Native bridge scaffold
package/
  thunderstore/         Package metadata template
docs/
  development/          Build and implementation plans
  legal/                Release boundary notes
scripts/                Local preflight and release-boundary checks
ref/                    Local reference material, not for redistribution
```

## Legal Boundary

This project is unofficial and is not affiliated with, endorsed by, or sponsored by Stunlock Studios, NVIDIA, or PureDark.

Do not add game files, PureDark files, Patreon/Discord files, or NVIDIA runtime DLLs to this repository unless a separate license review explicitly approves that exact file and release path.
