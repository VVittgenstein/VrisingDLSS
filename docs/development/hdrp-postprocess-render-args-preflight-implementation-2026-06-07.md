# HDRP PostProcess Render Args Preflight Implementation - 2026-06-07

## Purpose

After the protected gameplay proof promoted
`DarkForeground.Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` to a
gameplay-proven HDRP custom postprocess boundary, the next narrow question was:
can the mod observe the managed argument shape at that boundary without
reopening the high-frequency `RenderGraphResourceRegistry.GetTexture` route or
touching native/DLSS code?

## Implementation

Added a default-off diagnostic:

```ini
[Diagnostics]
EnableHdrpPostProcessRenderArgsProbe = false
```

Helper stage:

```powershell
scripts\run-vrising-diagnostic.ps1 -Stage hdrp-postprocess-render-args
scripts\start-vrising-automation-session.ps1 -Stage hdrp-postprocess-render-args
```

Main code path:

- `src/VrisingDLSS.Plugin/HdrpPostProcessRenderArgsProbe.cs`
- `src/VrisingDLSS.Plugin/ModConfig.cs`
- `src/VrisingDLSS.Plugin/Plugin.cs`

The probe:

- patches only `DarkForeground.Render(CommandBuffer, HDCamera, RTHandle,
  RTHandle)`;
- logs sparse snapshots for calls `1-5`, `10`, `30`, `100`, and `300`;
- reflects managed `CommandBuffer`, `HDCamera`, `source`, and `destination`
  shapes;
- summarizes RTHandle and RenderTexture names, dimensions, formats, dimensions,
  and MSAA fields;
- does not call `GetTexture`, `GetNativeTexturePtr`, D3D11 validation, NGX
  initialization, DLSS evaluate, or command-buffer operations.

## Script Integration

Updated:

- `scripts/write-diagnostic-config.ps1`
- `scripts/run-vrising-diagnostic.ps1`
- `scripts/start-vrising-automation-session.ps1`
- `scripts/analyze-bepinex-log.ps1`
- `scripts/get-runtime-validation-status.ps1`
- `scripts/get-release-readiness-status.ps1`
- `scripts/get-visual-validation-status.ps1`
- `scripts/validate-thunderstore-package.ps1`
- `package/thunderstore/VrisingDLSS.cfg`

Analyzer stage:

```text
HDRP PostProcess Render Args
```

Pass evidence:

```text
HDRP postprocess render args snapshot #
```

## Static Validation

Passed:

- `C:\Software\dotnet\dotnet.exe build src\VrisingDLSS.Plugin\VrisingDLSS.Plugin.csproj -c Release`
- PowerShell parser validation for `scripts\*.ps1`
- `scripts\write-diagnostic-config.ps1 -Stage hdrp-postprocess-render-args -DryRun`
- `git diff --check`
- `scripts\check-release-boundary.ps1`
- `scripts\package-thunderstore.ps1`
- `scripts\validate-thunderstore-package.ps1 -PackagePath dist\VrisingDLSS-0.1.0-thunderstore.zip`

Dry-run config confirmed:

- `EnableHdrpPostProcessRenderArgsProbe=true`
- `EnableRenderGraphGetTextureProbe=false`
- `EnableHookProbe=false`
- `EnableDLSS=false`

## Runtime Proof

See
`docs/development/hdrp-postprocess-render-args-gameplay-result-2026-06-07.md`.

The first protected `11111` gameplay proof passed at true `1920x1080`
Windowed and logged managed RTHandle/RenderTexture summaries without any
`GetTexture`, D3D11, NGX, or DLSS evaluate evidence.

## Decision

Keep this probe as the next source-driven observation point. It proves the
ProjectM custom postprocess boundary can expose managed source/destination
resources in gameplay without the previous hot `GetTexture` discovery loop.

Important limitation: the current proof observed full-resolution
`1920x1080 -> 1920x1080` postprocess ping-pong resources. It is not yet a DLSS
Super Resolution tuple. Future work should separately prove whether the same
boundary can see dynamic-resolution render inputs, then only after that add a
new guard for native pointer/DLSS work.
