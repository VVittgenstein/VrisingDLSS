# V Rising HDRP/DLSS Static Route Audit - 2026-06-08

Status: completed local/static pass. No V Rising runtime launch was performed,
and no game files were modified.

## Scope And Boundary

This audit turns the scattered local decompilation/xref/asset evidence into a
repeatable check for the current V Rising install.

Allowed evidence:

- type names, method names, method addresses/RVAs, signatures, field offsets,
  pass/resource layouts, string markers, xref summaries, and serialized asset
  values;
- local artifact paths and commands needed to reproduce the check.

Not allowed in public mod artifacts:

- modified game files;
- copied decompiled game method bodies or assets;
- redistributed game, Unity, NVIDIA, or Streamline binaries unless a separate
  release/legal review explicitly approves exact files and notices.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\inspect-vrising-hdrp-dlss-static-route.ps1 -GamePath C:\Software\VRising -Json
```

The local JSON artifact from this run is:

```text
artifacts/research/vrising-hdrp-dlss-static-route-audit-20260608.json
```

The script reports `LaunchesGame=false` and `ModifiesGameFiles=false`.

## Result Summary

| Check | Result |
| --- | --- |
| Audit status | `Pass` |
| HDRP route anchors present | `9/9` |
| DLSSPass methods present | `9/9` |
| `DLSSPass.BeginFrame/SetupDRSScaling/Render/.ctor` share address | `true`, `0x171E170` |
| Distinct DLSSPass helper address count | `5` |
| Active HDRP asset | `HDRP DefaultSettings` |
| Active asset `enableDLSS` | `0` |
| Active asset DLSS injection point | `BeforePost` |
| Active asset upsample filter | `EdgeAdaptiveScalingUpres` |
| `SetupDLSSFeature -> DLSSPass.SetupFeature` xref | `false` |
| `InitializePostProcess -> DLSSPass.Create` xref | `false` |
| `DoDLSSPass` declares RenderGraph boundary shape | `true` |
| `HDDynamicResolutionPlatformCapabilities.ActivateDLSS` caller count | `0` |
| Focused ProjectM DLSS/NGX/Streamline hits | `0` |
| Upscaler runtime files outside our mod/config | `0` |

## Evidence

Evidence: V Rising local IL2CPP metadata contains the official HDRP
postprocess/upscale route shell:

- `HDRenderPipeline.SetupDLSSFeature`
- `SetupDLSSForCameraDataAndDynamicResHandler`
- `InitializePostProcess`
- `GetPostprocessUpsampledOutputHandle`
- `RenderPostProcess`
- `DoDLSSPasses`
- `DoDLSSPass`
- `EdgeAdaptiveSpatialUpsampling`
- `FinalPass`

Evidence: the official DLSS pass/resource strings are present:

- `Deep Learning Super Sampling`
- `DLSS destination`
- `DLSS Color Mask`
- `Edge Adaptive Spatial Upsampling`

Evidence: `DLSSPass` resource helpers are present with distinct addresses:

- `GetViewResources`
- `CreateCameraResources`
- `GetCameraResources`
- `SetupFeature`
- `Create`

Evidence: the methods that should perform built-in NVIDIA work all share the
same local address `0x171E170`:

- `DLSSPass.BeginFrame`
- `DLSSPass.SetupDRSScaling`
- `DLSSPass.Render`
- `DLSSPass..ctor`

Evidence: serialized asset unpack shows the active Unity
`GraphicsSettings.m_CustomRenderPipeline` points at `HDRP DefaultSettings`;
that asset has RenderGraph enabled, dynamic resolution enabled, DLSS disabled,
and EASU/FSR selected as the upscaler.

Evidence: local xref cache does not show the upstream activation/object
lifecycle connected:

- `SetupDLSSFeature` does not call `DLSSPass.SetupFeature`.
- `SetupDLSSFeature` does not call `ActivateDLSS`.
- `InitializePostProcess` does not call `DLSSPass.Create`.
- `ActivateDLSS` has caller count `0`.

Evidence: local ProjectM graphics metadata contains a real FSR/dynamic
resolution layer (`SetFSRQuality`, `TurnOnFSR`, `TurnOffFSR`,
`GetDynResForQualityMode`), while the focused ProjectM DLSS/NGX/Streamline
search has `0` hits.

Evidence: focused filesystem search under the game directory found no
DLSS/NGX/Streamline upscaler runtime files outside our own mod/config files.

## Inference

Inference: V Rising did not remove the official HDRP postprocess route shell.
The upstream Unity HDRP source remains a good semantic map for pass order,
resource relationships, and DLSS parameter shape.

Inference: the built-in HDRP NVIDIA DLSS implementation is not directly usable
in this V Rising build. The local evidence points to a present pass shell and
resource contract, but an absent/inert activation and execution chain.

Inference: the best patch target is not "turn on `m_DLSSPass`" and not a broad
steady-state `RenderGraphResourceRegistry.GetTexture` hook. The smallest
plausible runtime boundary is an official-equivalent engine-owned
postprocess/upscale boundary that can bind:

- source color/output placement from the engine-owned EASU/Final chain;
- depth and motion-vector resources from HDRP postprocess/global resource
  correlation;
- command-buffer submission timing close to the official `DoDLSSPass` contract.

## Decision

Use `DoDLSSPass` as the clean-room resource-order contract, not as a callable
implementation. Keep `m_DLSSPass` activation, direct `DLSSPass.Render` patching,
new mod-owned RenderGraph pass injection, and broad GetTexture discovery
rejected as normal mainline routes.

The next runtime work, when Computer Use/gameplay testing resumes, should still
be the no-native/no-evaluate `hdrp-dlss-contract-bind-render-scale` proof. A
deeper static follow-up can inspect native bodies in Ghidra/IDA by RVA, but only
record branch/resource summaries and never publish copied method bodies.
