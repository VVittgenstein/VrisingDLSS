# Local Build Validation - 2026-06-04

This records the local build/package state for the clean-room diagnostic scaffold. It does not mean DLSS is functional in game yet.

## Toolchain

- `.NET SDK`: `C:\Software\dotnet`, SDK `6.0.428`
- Native C++ toolchain used for this run: `C:\Software\w64devkit`
- `w64devkit` release: `2.8.0`
- GCC: `16.1.0`
- CMake: `4.3.2`
- Ninja: `1.13.2`
- MSVC validation compiler: `19.44.35227.0`
- Windows SDK selected by CMake/MSVC: `10.0.26100.0`

Visual Studio Build Tools is now available at `C:\Software\VSBuildTools` and has been used as a second native build validation path. The packaged native DLL still comes from the w64devkit build because its current dependency table is smaller for end users.

## Commands Run

```powershell
$env:DOTNET_ROOT = "C:\Software\dotnet"
$env:PATH = "C:\Software\dotnet;$env:PATH"
dotnet build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release --no-restore
```

Result:

- `src\VrisingDLSS.Plugin\bin\Release\net6.0\VrisingDLSS.Plugin.dll`
- 0 warnings
- 0 errors

```powershell
$env:PATH = "C:\Software\w64devkit\bin;$env:PATH"
cmake -S src\VrisingDLSS.Native -B artifacts\native-build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build artifacts\native-build --config Release
```

Result:

- `artifacts\native-build\Release\VrisingDLSS.Native.dll`
- Export table includes the expected `VrisingDlss_*` diagnostic exports:
  - `VrisingDlss_GetBridgeApiVersion`
  - `VrisingDlss_GetBridgeVersion`
  - `VrisingDlss_GetDiagnosticStatus`
  - `VrisingDlss_GetRenderEventFunc`
  - `VrisingDlss_GetRenderEventCount`
  - `VrisingDlss_GetLastRenderEventId`
  - `VrisingDlss_GetRenderEventStatus`
  - `VrisingDlss_ProbeD3D11Texture`
  - `VrisingDlss_GetD3D11ProbeStatus`
  - `VrisingDlss_ProbeDlssRuntime`
  - `VrisingDlss_GetDlssRuntimeProbeStatus`
  - `VrisingDlss_ProbeDlssInitQuery`
  - `VrisingDlss_GetDlssInitQueryStatus`
  - `VrisingDlss_ProbeDlssFeatureCreate`
  - `VrisingDlss_GetDlssFeatureCreateStatus`
  - `VrisingDlss_ProbeDlssEvaluateInputs`
  - `VrisingDlss_GetDlssEvaluateInputStatus`
  - `VrisingDlss_ProbeDlssEvaluate`
  - `VrisingDlss_GetDlssEvaluateStatus`

```powershell
$cmake = "C:\Software\w64devkit\bin\cmake.exe"
& $cmake -S src\VrisingDLSS.Native -B artifacts\native-build-msvc -G "Visual Studio 17 2022" -A x64
& $cmake --build artifacts\native-build-msvc --config Release
```

Result:

- `artifacts\native-build-msvc\Release\VrisingDLSS.Native.dll`
- MSVC build succeeded.
- MSVC export table includes the same `VrisingDlss_*` diagnostic exports.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-release-boundary.ps1
powershell -ExecutionPolicy Bypass -File scripts\package-thunderstore.ps1
```

Result:

- Release boundary check passed.
- Created `dist\VrisingDLSS-0.1.0-thunderstore.zip`.

## Package Contents

```text
CHANGELOG.md
ThirdPartyNotices.md
icon.png
manifest.json
README.md
VrisingDLSS\README-runtime.txt
VrisingDLSS\VrisingDLSS.Native.dll
VrisingDLSS\VrisingDLSS.Plugin.dll
```

The package does not include PureDark binaries, NVIDIA runtime DLLs, game files, or SDK files.

## Current Meaning

This is a distributable diagnostic scaffold package, not a playable DLSS mod. It can support the next runtime validation stages:

- BepInEx loader validation.
- Read-only HDRP hook probe.
- Optional Harmony call probe.
- Native render-thread event smoke test.
- D3D11 texture/device pointer probe.
- HDRP frame resource native texture pointer probe.
- User-supplied DLSS runtime load/release probe.
- User-supplied guarded DLSS init/query probe; full capability query still requires NVIDIA SDK wrapper integration.
- Optional SDK-wrapper DLSS feature create/release probe; release-safe builds are expected to report blocked.
- Real-frame DLSS evaluate input probe for color/output/depth/motion D3D11 resource validation.

First DLSS evaluate is still not implemented.
