# Build Notes

Local build validation was last run on 2026-06-04. See also:

- [local-build-validation-2026-06-04.md](local-build-validation-2026-06-04.md)

## Expected Tools

- .NET SDK 6 or newer.
- CMake 3.22 or newer.
- One native Windows C++ toolchain:
  - Visual Studio Build Tools 2022 with C++ workload, or
  - portable `w64devkit`/MinGW-w64 for the current diagnostic bridge.
- PowerShell 5 or newer.

Current local tool locations:

- `.NET SDK 6.0.428`: `C:\Software\dotnet`
- `w64devkit 2.8.0`: `C:\Software\w64devkit`

## Restore And Build Plugin

```powershell
$env:DOTNET_ROOT = "C:\Software\dotnet"
$env:PATH = "C:\Software\dotnet;$env:PATH"
dotnet restore src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj
dotnet build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release
```

## Build Native Bridge

With Visual Studio Build Tools:

```powershell
cmake -S src\VrisingDLSS.Native -B artifacts\native-build -A x64
cmake --build artifacts\native-build --config Release
```

With `w64devkit`:

```powershell
$env:PATH = "C:\Software\w64devkit\bin;$env:PATH"
cmake -S src\VrisingDLSS.Native -B artifacts\native-build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build artifacts\native-build --config Release
```

Expected native output:

```text
artifacts\native-build\Release\VrisingDLSS.Native.dll
```

## Optional NGX SDK Wrapper Research Build

The default native bridge build is release-safe and does not require NVIDIA SDK headers/libs.

For local research only, an MSVC build can link NVIDIA's SDK wrapper from a local SDK checkout under `ref/`:

```powershell
$env:PATH = "C:\Software\w64devkit\bin;$env:PATH"
cmake -S src\VrisingDLSS.Native `
  -B artifacts\native-build-msvc-wrapper `
  -G "Visual Studio 17 2022" `
  -A x64 `
  -DVRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=ON `
  -DVRISINGDLSS_NGX_SDK_ROOT="Z:/VrisingDLSS/ref/NVIDIA-DLSS-main"
cmake --build artifacts\native-build-msvc-wrapper --config Release
```

Expected wrapper output:

```text
artifacts\native-build-msvc-wrapper\Release\VrisingDLSS.Native.dll
```

This build links `nvsdk_ngx_s.lib` and uses `/MT` to match NVIDIA's static wrapper library. Do not use this output for a public package unless the NVIDIA SDK/runtime release review has approved the exact files, notices, and distribution path.

## Pre-Package Boundary Check

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-release-boundary.ps1
```

The check must pass before building a public package.

## Stage Thunderstore Package

After building the plugin and native bridge:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1
```

The package script also runs `scripts\validate-thunderstore-package.ps1`, which verifies the actual zip layout, Thunderstore metadata, 256x256 PNG icon, BepInEx plugin route, forbidden third-party/runtime binaries, diagnostic-package wording, and safe default config toggles.

To summarize release readiness without launching or modifying the game:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\get-release-readiness-status.ps1
```

Pass `-GamePath` to include local runtime evidence, and pass `-RequireMvpReady` only when the command should fail if any MVP gate is still missing or blocked.

For metadata-only dry runs before build outputs exist:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1 -AllowMissingBinaries
```

## GitHub Actions

The repository workflow uses `windows-2022` with Visual Studio 2022 to avoid runner-image churn while `windows-latest` transitions to newer Visual Studio images. The workflow builds the C# plugin, configures the native bridge with the Visual Studio 17 2022 x64 generator, builds the native DLL, checks release boundaries, packages the Thunderstore artifact, validates the zip, reports release readiness, and uploads the zip as an Actions artifact.

## Local Game Preflight

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1
```

If V Rising is installed in a non-Steam location:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1 -GamePath "C:\path\to\VRising"
```

To check render metadata and local upscaler runtime DLL candidates without modifying the game folder:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\probe-vrising-render-metadata.ps1 -GamePath "C:\path\to\VRising"
```
