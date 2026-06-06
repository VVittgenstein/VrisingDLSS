# Reference Materials

This directory contains third-party reference material collected for static research only.

## Contents

- `PureDark-VRisingPerfMod/` - shallow clone of PureDark's public GitHub repository:
  `https://github.com/PureDark/VRisingPerfMod`
- `packages/PureDark-VRisingPerfMod-1.1.0.zip` - public Thunderstore package downloaded from:
  `https://thunderstore.io/package/download/PureDark/VRisingPerfMod/1.1.0/`
- `packages/PureDark-VRisingPerfMod-1.1.0/` - extracted copy of that public package.
- `packages/BepInEx-BepInExPack_V_Rising-1.733.2.zip` - public Thunderstore dependency package downloaded from:
  `https://thunderstore.io/package/download/BepInEx/BepInExPack_V_Rising/1.733.2/`
- `packages/NVIDIA-DLSS-310.6.0-ngx_dlss_demo_windows.zip` - official NVIDIA/DLSS GitHub release asset downloaded from:
  `https://github.com/NVIDIA/DLSS/releases/download/v310.6.0/ngx_dlss_demo_windows.zip`
- `NVIDIA-DLSS-310.6.0/` - selected official NVIDIA DLSS `310.6.0` research files extracted from the demo zip, including a local-only `nvngx_dlss.dll` runtime copy and sample snippets.
- `NVIDIA-DLSS-main/` - shallow clone of the official NVIDIA/DLSS repository for SDK header/library reference.
- `UnityGraphics-2022.3/` - local copy of Unity's official Graphics repository
  2022.3 staging source, used for HDRP/CoreRP RenderGraph and DLSS boundary
  inspection. Key files include HDRP `HDRenderPipeline.PostProcess.cs`,
  `DLSSPass.cs`, CoreRP `RenderGraph.cs`, and
  `RenderGraphResourceRegistry.cs`.
- `NVIDIA-Streamline/ProgrammingGuideDLSS.md` - official Streamline DLSS guide
  snapshot used for the resource-tagging/current-frame evaluate boundary check.
- `OptiScaler/README.md` and `OptiScaler/OptiScaler.ini` - OptiScaler reference
  snapshots used only to understand how existing upscaler-input interception and
  resource tracking are framed by that project.
- `hdrp-rendergraph-boundary-2026-06-06/` - narrow local reference snapshot for
  the HDRP DLSS / RenderGraph execution-boundary audit, including Unity Graphics
  2022.3 source copies, Unity HDRP DLSS/Dynamic Resolution docs, Unity
  RenderGraph docs, BepInEx runtime patching docs, NVIDIA Streamline guides, and
  OptiScaler README/INI evidence.
- `dlss-performance-investigation-2026-06-06/` - local copies of official Unity
  HDRP/Dynamic Resolution/RenderGraph docs, NVIDIA Streamline/NGX references, and
  OptiScaler/forum research used to diagnose the "DLSS succeeds but FPS is worse /
  GPU utilization is low" path. It also includes NVIDIA DLSS official pages/blog
  posts used by the 2026-06-06 theoretical performance model:
  `nvidia-dlss-developer-page.html`, `nvidia-dlss-2-ai-rendering.html`,
  `nvidia-dlss-ue4-plugin-tips.html`, and `nvidia-dlss-faq-gpu-bound.html`.

## Rules

- Do not copy PureDark source code into production code unless explicit written permission or a clear license grant is obtained.
- Do not redistribute `PDPerfPlugin.dll`, `PerfMod.dll`, `nvngx_dlss.dll`, FSR2/XeSS DLLs, DirectX compiler DLLs, or any other binary from the reference package.
- Do not execute reference DLLs or scripts from this folder.
- Use this folder only to understand public technical facts: dependency shape, render integration points, data requirements, packaging layout, and historical compatibility risks.
- BepInExPack is a runtime test dependency, not part of the VrisingDLSS release package.
- NVIDIA SDK/runtime files in this folder are local research material only. Do not move them into `src/`, `package/`, or `dist/` unless a separate release review approves the exact file and distribution path.
