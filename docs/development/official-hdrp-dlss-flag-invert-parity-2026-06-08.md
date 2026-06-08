# Official HDRP DLSS Flag/Invert Parity - 2026-06-08

Status: implemented and non-runtime build-validated. Runtime performance still
requires a protected paired game run.

## Question

Can the current EASU `ctx.cmd` user-rendering candidate be moved one small step
closer to Unity HDRP's official `DLSSPass` without another blind game run?

The previous audit identified two small, source-backed mismatches:

- Candidate feature creation used `AutoExposure` only (`0x40`), while official
  HDRP uses `IsHDR | MVLowRes | DepthInverted | DoSharpening` (`0x2B` with the
  current NGX headers).
- Candidate NGX eval left the invert-axis fields at zero, while official HDRP
  submits invert X = `0`, invert Y = `1`.

## Implementation

The patch keeps the change deliberately narrow:

- Added `DLSS.UseOfficialHdrpFeatureFlags`, default `true`.
- Changed the normal evaluate/user-rendering flag resolver so the default
  feature flags are official-HDRP-like `0x2B`.
- Changed `DLSS.AutoExposure` default to `false` and documented it as a legacy
  fallback that is used only when `UseOfficialHdrpFeatureFlags=false`.
- Updated the diagnostic config writer and Thunderstore config template to emit
  `UseOfficialHdrpFeatureFlags=true` and `AutoExposure=false`.
- Updated the older `DlssFeatureCreateProbe` to use the same official-HDRP-like
  feature flags instead of hard-coded AutoExposure.
- Set NGX `InIndicatorInvertXAxis=0` and `InIndicatorInvertYAxis=1` for the
  SDK-wrapper frame-sequence, single-evaluate, and persistent-evaluate paths.
- Added `invertAxis=(0,1)` to the frame-sequence evaluate status line so the
  next runtime log can prove the submitted value directly.

This patch intentionally does not change reset/history lifecycle behavior and
does not move the output boundary away from EASU. Those remain separate
variables.

## Validation

Non-runtime validation passed:

- C# Release build:
  `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
- Native release-safe MSVC build:
  `C:\Software\VSBuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe --build artifacts\native-build-msvc --config Release`
- Native SDK-wrapper MSVC build:
  `C:\Software\VSBuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe --build artifacts\native-build-msvc-wrapper --config Release`
- Release readiness static check:
  `scripts\get-release-readiness-status.ps1`
  returned `DiagnosticPackageReady_MvpBlocked`; launch side effects `False`.
- Diagnostic config dry-run:
  `scripts\write-diagnostic-config.ps1 -Stage dlss-user-rendering -OutputPath artifacts\dryrun\official-hdrp-flags-config-check.cfg -DlssRuntimePath Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll -DryRun`
  emitted `UseOfficialHdrpFeatureFlags = true` and `AutoExposure = false`.
- `git diff --check` passed.

The initial native build attempts using plain `cmake` failed because the current
PowerShell PATH did not expose CMake. This was an environment lookup issue, not a
compile failure; rerunning with the absolute VS BuildTools CMake path passed.

## Next Runtime Guard

Do not call this MVP-ready. The next game run should be a named protected paired
test with this hypothesis:

> Official-HDRP-like feature flags (`0x2B`) plus invert-axis parity reduce the
> current user-rendering candidate's low-GPU-utilization performance regression
> without losing clean DLSS evaluate evidence.

Use the established `1920x1080` Windowed protected fixture first:

- V Rising `FsrQualityMode=Off`.
- Protected local/private `11111` save, restored to `ChangeCount=0`.
- Computer Use kept connected during performance capture and disconnected after
  cleanup.
- Capture wider system snapshots for baseline and candidate.
- Confirm candidate logs include `flags=0x0000002B`, `invertAxis=(0,1)`,
  `RenderGraph GetTexture call #=0`, clean user-rendering evaluate evidence, and
  no crash/access-violation/driver evidence.
