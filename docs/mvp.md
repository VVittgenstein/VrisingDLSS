# MVP Definition

This file is the source of truth for the current MVP target.

## Goal

Build a free, non-commercial, distributable V Rising DLSS Super Resolution mod that can be published as a source repository and as a V Rising mod package.

The MVP user experience target is a normal-user package: drag the mod package into the V Rising install or install it through the V Rising mod ecosystem, launch the game, and get DLSS Super Resolution with conservative documented defaults.

## MVP Must Have

- A clean-room BepInEx IL2CPP plugin.
- A clean-room native D3D11/DLSS bridge.
- A Thunderstore-compatible package layout.
- Thunderstore package root metadata plus BepInEx-routed payload: `BepInEx/plugins/VrisingDLSS/`.
- No PureDark source, PureDark binaries, private membership files, or compatibility dependency on PureDark.
- A mod-folder configuration file, intended path: `BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg`.
- Configuration changes are applied on game restart; no in-game menu or hot config reload is required for MVP.
- Documented DLSS options for normal users and advanced users.
- A primary release path that attempts to bundle an official NVIDIA DLSS Super Resolution runtime only after a separate release review approves the exact file, license notices, and distribution path.
- A fallback source-safe package path that does not bundle the NVIDIA runtime and explains how users supply it from an approved source.
- Clear install, troubleshooting, and third-party notice documents.
- Diagnostic logs that explain why DLSS is unavailable instead of crashing or silently failing.

## MVP Default Configuration Target

Current diagnostic builds keep rendering-changing behavior disabled until the DLSS path is proven. The diagnostic package exposes the MVP configuration surface but uses `EnableDLSS=false` until Stage 8A and first evaluate are implemented.

The release MVP target defaults are:

```ini
[DLSS]
EnableDLSS = true
QualityMode = Performance
PresetMode = Recommended
Sharpness = 0
DlssRuntimePath = nvngx_dlss.dll
AutoExposure = true

[Advanced]
RenderScaleOverride = 0
MipBiasOverride = Auto
ResetOnCameraCut = true
LogLevel = Info
ShowOverlay = true
```

`QualityMode` should expose at least `DLAA`, `Quality`, `Balanced`, `Performance`, and `UltraPerformance`.

`PresetMode` should expose `Recommended` plus explicit preset controls only after the NGX/SDK parameter mapping is verified from official NVIDIA documentation and runtime tests. The current intended values are `Recommended`, `PresetK`, `PresetM`, `PresetL`, and `Auto`.

## MVP Done Means

- The package can be installed by a normal V Rising mod user through the V Rising mod ecosystem or manual install.
- DLSS Super Resolution can be enabled and disabled in a local/private-world test.
- If required runtime files are bundled, the release includes NVIDIA notices/license text, avoids implying NVIDIA sponsorship or endorsement, and makes clear that the NVIDIA runtime is not covered by the project's open-source license.
- If required runtime files are not bundled, the README explains how the user supplies them from an approved source.
- The mod does not modify game networking, gameplay rules, server protocol, saves, DRM, or online services.
- Release boundary checks pass before packaging.

## Current MVP Gate

The current blocker is Stage 8A frame input access. DLSS runtime load, SDK-wrapper init/query, and feature create/release have local proof, but first evaluate still requires color/output/depth/motion resources as valid native D3D11 textures in the same frame.

Latest local evidence shows HDRP RenderGraph methods expose `TextureHandle` entries named `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer`, but ordinary Harmony prefixes see those handles outside a valid RenderGraph resource read scope.

The current diagnostic build therefore avoids calling `GetTexture(TextureHandle&)` from method prefixes and instead listens for engine-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` calls with a read-only postfix. A `TextureHandle` implicit-conversion hook was tested and rejected because it produced IL2CPP trampoline errors. A declared diagnostic RenderGraph pass also proved too risky: it injected in gameplay and then V Rising crashed in `coreclr.dll` before the pass render function logged. That path remains disabled behind `Diagnostics.EnableRenderGraphDiagnosticPass=false`. Patching compiler-generated existing HDRP render functions also reproduced the same `coreclr.dll` access-violation crash before any render-function scope log, so it is disabled behind `Diagnostics.EnableExistingRenderFuncProbe=false`.

The next concrete MVP step is still to follow V Rising's existing HDRP dynamic-resolution/upscale path, but not by broad Harmony patching of compiler-generated render delegates. V Rising's built-in HDRP dynamic-resolution/upscale symbols, including FSR and DLSS-related entries, remain useful as landmarks for low-resolution color, output, depth, motion vectors, and render-scale state. FSR1 itself is not a DLSS substitute because DLSS Super Resolution still requires valid depth and motion-vector inputs.

## Current Non-Goals

- Monetization.
- Patreon, Discord, or paid build distribution.
- DLSS Frame Generation.
- Public/official server safety guarantees.
- Proton or Steam Deck support.
- Copying or maintaining PureDark's implementation.

## Source Rule

Do not use prior chat logs as design authority for this MVP. Use the current repository, current user instructions, this MVP definition, official public documentation, and direct test evidence.

The 2026-06-05 side conversation about MVP configuration has been folded into this file. Treat this file as the decision record, not the chat log archive.
