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

Current packages keep rendering-changing behavior disabled by default while the DLSS path is proven. The package exposes the MVP configuration surface and now has an experimental `EnableDLSS=true` candidate, but the default remains `EnableDLSS=false` until image-correctness, performance, resize/reset, and release-boundary checks prove the path is ready for normal users.

The release MVP target defaults are:

```ini
[DLSS]
EnableDLSS = true
QualityMode = Performance
PresetMode = Recommended
Sharpness = 0
DlssRuntimePath = nvngx_dlss.dll
UseOfficialHdrpFeatureFlags = true
AutoExposure = false

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

The current blocker is image-correctness, performance, resize/reset, fallback behavior, productionizing render-scale control, runtime distribution, and release-boundary validation for the normal-user path. Runtime distribution is now tracked as an explicit MVP readiness gate in `docs/development/dlss-runtime-distribution-gate-2026-06-08.md`; until an approved runtime distribution record exists, the package remains diagnostic/source-safe rather than a drag-in playable MVP. The older Stage 8/9/10 diagnostic ladder remains useful evidence, but it is no longer the best description of the active candidate: broad `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` discovery is now rejected for steady-state user rendering because it caused severe FPS collapse.

The current normal-user candidate is source-guided by Unity HDRP and V Rising IL2CPP metadata. `DLSS.EnableDLSS=true` uses the focused HDRP EASU render-func boundary, carries EASU source/output plus HDRP depth/motion through `RenderGraphContext.cmd` plugin events, keeps broad `RenderGraph.GetTexture` disabled, and evaluates DLSS into the visible EASU output with one persistent frame sequence.

Protected gameplay run `native-commandbuffer-user-rendering-1080p-20260607-r3` passed at true `1920x1080` Windowed with V Rising `FsrQualityMode=Off` and the protected local save fixture. Key evidence: `eventId=260615`, `setSuccesses=124`, `issueSuccesses=124`, `consumed=124`, `sequenceCreates=1`, `sequenceEvaluates=124`, `evaluateSuccesses=124`, `input=960x540`, `output=1920x1080`, `validation=D3D11-succeeded`, `sameDevice=yes`, `scratchOutput=no`, `visibleOutput=yes`, `persistent=yes`, `RenderGraph GetTexture call #=0`, no crash, and final save restore `ChangeCount=0`.

The MVP visual gate is still blocked on a fresh normal-user `dlss-user-rendering` gameplay visual/performance comparison plus matching human image-quality review. The stale v6 visual/performance artifacts used the old GetTexture/driven route and failed performance; they cannot decide the current source-guided command-buffer candidate. The next validation must run `scripts\run-vrising-visual-comparison.ps1 -CandidateStage dlss-user-rendering -FsrMode Off -ProtectSave -SaveName 11111` in the stable local gameplay fixture, capture paired screenshots and FPS/GPU metrics, restore the protected save with final `ChangeCount=0`, then add a matching review file. Stage 10A comparison evidence remains diagnostic and cannot satisfy that release gate.

The final product-value comparison is native 4K with V Rising `FsrQualityMode=Off` and `DLSS.EnableDLSS=false` versus the same scene/output settings with V Rising `FsrQualityMode=Off` and `DLSS.EnableDLSS=true`. The mod, not V Rising's FSR setting, must control the lower render resolution used by DLSS.

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
