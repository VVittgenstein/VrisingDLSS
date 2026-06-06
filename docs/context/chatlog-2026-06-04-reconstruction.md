# 2026-06-04 Chatlog Reconstruction

Source log: `docs/chatlog/chat-log-codex-2026-06-04-c2222419.md`

Reconstruction date: 2026-06-06

Parsing method:

- Parsed all `### N. Role - timestamp` headings from the Markdown export.
- Confirmed 3124 exported messages: 162 user messages, 2857 commentary messages, and 105 final answers.
- Read user instructions and final answers in chronological order.
- Re-read the 2026-06-05 20:32-20:57 commentary-only paired-test window because it contained important runtime/performance evidence without a final-answer closeout.
- Cross-checked the resulting terminal state against the current worktree, latest commit, pause-state document, and readiness script output.

Tool calls, tool outputs, hidden reasoning, and command traces were intentionally omitted from the chatlog export, so this reconstruction records durable project context and message-level evidence rather than raw terminal traces.

## Chunk 01 - Initial Intent, Research, PureDark Boundary

Message/time range: `1-34`, 2026-06-04 21:49:29 to 22:06:24 CST.

User instructions/follow-up/corrections:

- Read existing project chatlog and infer the real goal.
- Search broadly for compliance, usability, and technical route.
- Pull PureDark's public V Rising mod reference into `ref/` and identify what can be borrowed.
- Estimate time to a usable/distributable mod.

Technical decisions:

- The target is real DLSS Super Resolution for V Rising, not ReShade, sharpening, FSR masquerading as DLSS, or a generic fake upscaler.
- PureDark can only be used as a public reference for high-level concepts. Its code, binaries, ABI, private package contents, and package layout cannot be reused.
- Preferred initial route became a clean-room implementation: BepInEx IL2CPP plugin plus native D3D11/DLSS bridge.

Implemented changes:

- Created research documentation and `ref/` boundary notes.
- Stored PureDark public package/reference material under `ref/` for local research only.

Evidence:

- PureDark package contained `PerfMod.dll`, `PDPerfPlugin.dll`, `nvngx_dlss.dll`, and related native/runtime files.
- Research documented Thunderstore/BepInEx/NVIDIA/V Rising compliance constraints.

Failures/rejected routes:

- Rejected copying PureDark code, using PureDark native ABI, distributing PureDark binaries, or bundling Patreon/Discord/private material.
- Rejected packaging NVIDIA runtime files before a separate release/legal review.

Open blockers:

- No current V Rising runtime proof yet.
- No buildable plugin/native implementation yet.
- Unknown current HDRP/RenderGraph hook points.

Next step:

- Build a source-only clean-room scaffold and release-boundary gates.

## Chunk 02 - Clean-Room Scaffold, Local V Rising Static Preflight

Message/time range: `35-104`, 2026-06-04 22:06:25 to 22:32:01 CST.

User instructions/follow-up/corrections:

- Continue the search goal, but practically move toward implementation.
- The user supplied `C:\Software\VRising` as a learning/research install for testing.
- User allowed installing needed Python/software under `C:\Software`.

Technical decisions:

- Start with a diagnostic scaffold, not a playable DLSS mod.
- Keep diagnostics default-off and release-safe.
- Use V Rising metadata/static strings to confirm Unity/HDRP/IL2CPP feasibility before runtime probes.

Implemented changes:

- Added `README.md`, C# BepInEx plugin scaffold, native bridge placeholder, Thunderstore manifest template, release boundary script, build notes, install/troubleshooting docs, and runtime validation docs.
- Added static local install/preflight probes.
- Added hook target catalog, read-only hook probe, and default-off Harmony call probe.
- Added package generation scripts.

Evidence:

- `C:\Software\VRising` was identified as V Rising `v1.1.13.0-r99712-b17` on Unity `2022.3.58f1`.
- Static metadata showed HDRP/Core RP, `ProjectM`, `ProjectM.Camera`, `UnityEngine.NVIDIAModule`, `CustomVignette`, `HDCamera`, `DynamicResolutionHandler`, `_CameraDepthTexture`, and `_CameraMotionVectorsTexture`.
- No bundled `nvngx`, Streamline, XeSS, FSR2, or direct Unity DLSS runtime binaries were found in the game folder.
- Release boundary and package dry-run checks passed, but the package was diagnostic and incomplete.

Failures/rejected routes:

- "Just enable built-in Unity DLSS" was not proven; local runtime/interops did not show an immediately usable NVIDIA DLSS package/binary path.
- Build verification was initially blocked by missing toolchain components.

Open blockers:

- Actual BepInEx runtime loading.
- Native bridge build.
- Runtime hook validation.
- Real DLSS runtime/init/evaluate.

Next step:

- Build the C# and native projects, install BepInEx, and start staged runtime validation.

## Chunk 03 - Build Closure, MVP Correction, Stage 6/Frame Resource Probes

Message/time range: `105-236`, 2026-06-04 22:32:02 to 23:58:22 CST.

User instructions/follow-up/corrections:

- User manually installed Visual Studio tooling.
- User told Codex an earlier chatlog was the wrong source and must be forgotten as an MVP authority.
- User clarified MVP: a free, distributable V Rising DLSS mod for GitHub and mod ecosystem, not for monetization.

Technical decisions:

- Explicitly exclude the wrong chatlog from MVP authority.
- Make `docs/mvp.md` the local source of truth for MVP scope.
- Add Stage 5/6 diagnostics before any real frame modification.

Implemented changes:

- Built C# and native scaffold with w64devkit and then MSVC.
- Generated a Thunderstore diagnostic zip containing only project-owned DLLs and metadata.
- Added native render-thread smoke test.
- Added DLSS runtime load/release probe.
- Added guarded NGX init/query probe using SDK-wrapper research builds.
- Added frame resource probe for color/depth/motion pointers.
- Pushed the initial clean-room repo to `VVittgenstein/VrisingDLSS`.

Evidence:

- `VrisingDLSS.Plugin.dll` and `VrisingDLSS.Native.dll` built successfully.
- MSVC route produced `artifacts/native-build-msvc/Release/VrisingDLSS.Native.dll`.
- Stage 6 was implemented as default-off and only query-oriented; no DLSS feature/evaluate yet.
- Package boundary checks confirmed no PureDark, NVIDIA, game DLL, `ref/`, `dist/`, or artifacts in the release payload.

Failures/rejected routes:

- Current public package remained a diagnostic scaffold, not a playable mod.
- NVIDIA runtime and SDK-wrapper files were intentionally not included in the public package.

Open blockers:

- Need BepInEx installation and generated interop.
- Need actual runtime logs.
- Need NGX feature create and evaluate.

Next step:

- Stage BepInExPack in `C:\Software\VRising`, run loader/runtime diagnostics, and start DLSS feature probes.

## Chunk 04 - Runtime Staging, Side Config, BepInEx and Early DLSS Evidence

Message/time range: `237-379`, 2026-06-04 23:58:23 to 2026-06-05 00:59:24 CST.

User instructions/follow-up/corrections:

- User provided permission to start the game if needed and supplied `VRising.exe`.
- User reported BepInEx console and main-menu status.
- User asked whether lowering graphics settings was acceptable.
- User asked Codex to read `side-chat-dlss-mvp-config-2026-06-05.md`.

Technical decisions:

- Low graphics settings are acceptable for diagnostics when they do not invalidate the target evidence.
- Fold side-chat MVP config into `docs/mvp.md`: target is a normal-user package, not only a diagnostic scaffold.
- Default release package stays safe until image/performance validation proves `EnableDLSS=true`.

Implemented changes:

- Installed BepInExPack V Rising `1.733.2`.
- Installed current diagnostic plugin into `C:\Software\VRising`.
- Added diagnostic config and log analysis scripts.
- Added staged config writer and BepInEx log analyzer.
- Added local runtime staging records.

Evidence:

- Game/BepInEx/plugin loaded.
- `HDRenderPipeline.UpdateShaderVariablesGlobalCB(HDCamera, CommandBuffer)` was a valid hook point.
- Unity `CommandBuffer.IssuePluginEvent` reached the native callback.
- Temporary Unity `RenderTexture` to native D3D11 resource/device path passed.
- `_CameraDepthTexture` appeared; `_CameraMotionVectorsTexture` was initially null.
- NVIDIA DLSS `310.6.0.0` runtime in `ref/` loaded/released and signature verified.

Failures/rejected routes:

- Direct capability parameter allocation from production `nvngx_dlss.dll` alone was not enough; SDK-wrapper/API support was needed for proper NGX parameter handling.

Open blockers:

- NGX init/query in game.
- Feature create/release.
- Motion vectors and same-frame input/output resource alignment.

Next step:

- Integrate the optional SDK-wrapper research path and probe feature create/evaluate.

## Chunk 05 - SDK Wrapper, Feature Create, Stage 8A Beginnings

Message/time range: `380-676`, 2026-06-05 00:59:29 to 02:28:04 CST.

User instructions/follow-up/corrections:

- User opened the GitHub repository and authorized use of Git.
- User emphasized moving from search to MVP execution.

Technical decisions:

- Use optional `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=ON` only for local research builds.
- Keep default release-safe build free of NVIDIA SDK/runtime linkage.
- Treat Stage 8A evaluate-input validation as mandatory before any actual frame evaluate.

Implemented changes:

- Added optional SDK-wrapper native build path.
- Stage 6 NGX init/capability query passed in local V Rising.
- Added Stage 7 DLSS feature create/release probe.
- Added Stage 8A evaluate-input probe for same-device D3D11 `color/output/depth/motion`.
- Added RenderGraph hook discovery and resource-name logging.
- Added documentation and status helpers.

Evidence:

- Stage 6 returned success values for init/capability/query/shutdown in SDK-wrapper research build.
- Stage 7 feature create/release passed.
- Stage 8A main-menu run patched hooks but initially lacked source/output and motion vectors.
- RenderGraph showed `CameraColor`, `CameraDepthStencil`, `Motion Vectors`, and `NormalBuffer` handles.

Failures/rejected routes:

- Main-menu-only CustomVignette route did not provide required source/output RTHandles.
- Prefix-time `TextureHandle` access was unsafe or too early.

Open blockers:

- Need valid resource scope during RenderGraph execution.
- Need all four resources in the same frame/device.

Next step:

- Find an engine-owned RenderGraph materialization point or safe execution-stage route.

## Chunk 06 - RenderGraph Research, Package/CI/Readiness Gates

Message/time range: `677-962`, 2026-06-05 02:28:05 to 03:53:55 CST.

User instructions/follow-up/corrections:

- Continue direct MVP execution.

Technical decisions:

- Stage 8A is a RenderGraph resource-scope problem, not just a missing-resource problem.
- Prefer engine-owned resource materialization over ordinary Harmony prefixes.
- Make packaging and readiness verifiable in CI.

Implemented changes:

- Added RenderGraph builder declaration probe.
- Added and later constrained/disabled experimental RenderGraph diagnostic pass route.
- Moved package payload to `BepInEx/plugins/VrisingDLSS/`.
- Added Thunderstore package validator.
- Consolidated GitHub Actions package workflow.
- Added release readiness script distinguishing `DiagnosticPackageReady` from `MvpReady`.

Evidence:

- GitHub Actions on `windows-2022` built and validated the package.
- Thunderstore zip root metadata and routed plugin payload were validated.
- Readiness correctly reported `DiagnosticPackageReady_MvpBlocked`.

Failures/rejected routes:

- `TextureHandle` implicit-conversion hook produced IL2CPP trampoline errors.
- `RenderGraphPass<T>.Execute` open generic could not be patched with the current Harmony route.
- Injected diagnostic RenderGraph pass configured but was later found risky in gameplay.

Open blockers:

- Stage 8A gameplay validation.
- Real resource materialization in valid RenderGraph scope.

Next step:

- Use gameplay runs and safer engine-owned callbacks to prove Stage 8A.

## Chunk 07 - Gameplay Crashes, FSR/Upscaler Evidence, Stage 8A Pass

Message/time range: `963-1503`, 2026-06-05 08:30:04 to 11:48:49 CST.

User instructions/follow-up/corrections:

- User offered to enter the game for tests.
- User reported the game disappearing/crashing.
- User asked whether built-in V Rising FSR helps.
- User asked for current status and when to start the game.

Technical decisions:

- The injected diagnostic RenderGraph pass and compiler-generated render-function patching are too risky for the ordinary Stage 8A route.
- FSR1/dynamic-resolution/upscale path is useful as a map of HDRP upscaling, but not a DLSS replacement.
- `DLSSPass` is useful as a resource-shape map, but direct `DLSSPass.Render` patching is rejected.
- Accepted Stage 8A route is passive aggregation from engine-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)`.

Implemented changes:

- Gated high-risk RenderGraph diagnostic pass and existing HDRP render-function probes behind explicit default-off switches.
- Added upscaler state probe.
- Added static interop probes for FSR/upscale/DLSSPass resource shapes.
- Added isolated `DLSSPass.GetViewResources` / `GetCameraResources` helper probe.
- Added scripted V Rising diagnostic runner.
- Stage 8A finally passed through engine-owned `GetTexture` aggregation.

Evidence:

- Gameplay crash evidence: `VRising.exe` crashed in `coreclr.dll`/`UnityPlayer.dll` for several unsafe hook routes before useful logs.
- Runtime upscaler logs showed `SetFSRParameters(1, true)`, `SetUpscaleFilter(EdgeAdaptiveScalingUpres, 0.59)`, and `GetUpscaleRes=58.999996`.
- Stage 8A passed with `CameraColor`, `Apply Exposure Destination`, `CameraDepthStencil`, and `Motion Vectors` as same-device D3D11 textures at `720x480`.

Failures/rejected routes:

- Declared diagnostic RenderGraph pass injection for normal Stage 8A.
- Broad compiler-generated HDRP render-function patching.
- Direct `DLSSPass.Render` Harmony prefix.
- Direct `GetTexture(TextureHandle&)` from prefixes.

Open blockers:

- Actual DLSS evaluate against accepted resources.
- Super Resolution-sized tuple where input is smaller than output.

Next step:

- Build guarded evaluate probes on the accepted Stage 8A resource stream.

## Chunk 08 - Stage 8B through 9A: DLSS Evaluate Works Diagnostically

Message/time range: `1504-1867`, 2026-06-05 11:48:50 to 14:13:31 CST.

User instructions/follow-up/corrections:

- No new direction; continue MVP execution.

Technical decisions:

- Progress from input validation to guarded evaluate, output follow-up, persistent feature reuse, SR-sized tuple validation, and frame-sequence validation.
- Keep all deep DLSS probes default-off and restore release-safe native DLL after tests.

Implemented changes:

- Added Stage 8B guarded DLSS evaluate.
- Added Stage 8C output follow-up.
- Added Stage 8D persistent repeated evaluate.
- Added Stage 8E Super Resolution input-size diagnostic.
- Added Stage 8F Super Resolution evaluate diagnostic.
- Added Stage 8G Super Resolution persistent evaluate.
- Added Stage 9A frame-sequence evaluate.

Evidence:

- Stage 8B/8C/8D passed in local V Rising.
- Stage 8E found SR tuple `426x284 -> 720x480`.
- Stage 8F successfully evaluated that SR tuple.
- Stage 8G and Stage 9A showed one feature could persist across repeated immediate evaluates and repeated RenderGraph callbacks.
- No Windows crash events in the successful scripted runs.

Failures/rejected routes:

- None newly rejected in this chunk, but all earlier high-risk routes remained disabled.

Open blockers:

- Visible write-back path.
- Image correctness, resize/reset/fallback, and normal-user path.

Next step:

- Evaluate into selected visible output target and validate screenshots/performance.

## Chunk 09 - Stage 10A, Visual Capture, Baseline Metrics, Measurement Gates

Message/time range: `1868-2249`, 2026-06-05 14:13:32 to 17:05:41 CST.

User instructions/follow-up/corrections:

- User coordinated manual gameplay entry and asked for FPS/CPU/GPU capture.
- User clarified 4K/window scaling confusion.

Technical decisions:

- Stage 10A visible write-back remains diagnostic and cannot satisfy MVP by itself.
- Screenshots must avoid false `PrintWindow` captures and use fallback screen copy.
- Performance/visual gates must be explicit and persisted.
- Production `nvngx_dlss.dll` alone does not expose all SDK-wrapper parameter-management APIs.

Implemented changes:

- Added Stage 10A visible-path write-back diagnostic.
- Added screenshot capture helpers and image comparison helpers.
- Added PresentMon/CPU/GPU/VRAM/power capture script.
- Added visual comparison helper with manual-ready support.
- Added visual validation status and review artifact tooling.
- Added `probe-ngx-runtime-exports.ps1`.

Evidence:

- Stage 10A reached `sequenceEvaluates=30` and `evaluateSuccesses=30` into `Edge Adaptive Spatial Upsampling`.
- Output remained D3D11-accessible afterward.
- Main-menu screenshot smoke showed no obvious change for static UI.
- A 4K high-settings baseline sample measured about `74.861 FPS`, `55.49` 1% low, GPU 100%, VRAM about 6865 MB, GPU power about 125 W.
- `PrintWindow` false frames were detected and fallback behavior was added.

Failures/rejected routes:

- Using production `nvngx_dlss.dll` without SDK wrapper was not sufficient for full parameter management.
- False screenshots from `PrintWindow` were rejected as visual evidence.

Open blockers:

- Gameplay image correctness.
- Normal-user `DLSS.EnableDLSS=true` path.
- Performance benefit over correct baseline.
- Legal/acceptable runtime strategy.

Next step:

- Build and test a normal-user `dlss-user-rendering` candidate and paired gameplay comparisons.

## Chunk 10 - Transition Tests, User-Rendering Candidate, Readiness Tightening

Message/time range: `2250-2697`, 2026-06-05 17:05:42 to 19:56:08 CST.

User instructions/follow-up/corrections:

- User asked for actual game testing if needed.
- User emphasized persistent local records for MVP goal, original wording, and test records.
- User questioned whether observed resolution was due to Windows scaling.
- User noted that there was not an obvious FPS increase.
- User asked about default settings and FSR Performance.

Technical decisions:

- FSR Performance can be a transition diagnostic to force a `1920x1080 -> 3840x2160` tuple, but it is not the final MVP route.
- MVP visual gate must require normal-user `dlss-user-rendering` evidence, not Stage 10A proof-loop evidence.
- Readiness must aggregate archived runtime evidence, not only the latest overwritten `LogOutput.log`.

Implemented changes:

- Added experimental `DLSS.EnableDLSS=true` user-rendering candidate.
- Added SDK-wrapper support to diagnostic runner.
- Added visual comparison support for `dlss-user-rendering`.
- Added temporary FSR-mode switching/restoration around visual validation runs.
- Added readiness item for user-rendering candidate and archived evidence aggregation.
- Added distribution MVP research snapshot and updated measurement plan.

Evidence:

- Stage 10A FSR Performance transition comparison: baseline about `159.851 FPS`, candidate about `45.982 FPS`; candidate had valid 4K screenshot and `sequenceSuccesses=30/30`, but hold-mode overhead made it non-product performance evidence.
- SDK-wrapper user-rendering smoke with FSR Performance accepted `1920x1080 -> 3840x2160`, reached `sequenceSuccesses=11100`, and had no blocked/failed/disabled lines or Windows crash events.
- Release readiness still reported `DiagnosticPackageReady_MvpBlocked`.

Failures/rejected routes:

- Stage 10A comparison cannot satisfy MVP visual gate.
- Any route that treats FSR Performance as final DLSS product behavior is rejected.

Open blockers:

- Normal-user visual/performance comparison.
- FSR Off candidate that produces its own low-resolution input.
- Human review file for image correctness.

Next step:

- Run paired `dlss-user-rendering` gameplay visual/performance comparison and fix performance regressions.

## Chunk 11 - Paired Run Regression, Throttle Fix, FSR/DLSS Correction

Message/time range: `2698-2882`, 2026-06-05 19:56:09 to 20:57:41 CST.

User instructions/follow-up/corrections:

- User asked what to do next and then started a paired test.
- User asked why DLSS did not increase FPS.
- User correctly insisted the real comparison should be FSR Off baseline versus DLSS On candidate.
- User corrected the framing that DLSS should not depend on FSR or another upscaler to lower resolution.

Technical decisions:

- Performance regression must be a hard readiness blocker.
- A RenderGraph callback is not the same as a displayed frame.
- `DLSS.EnableDLSS=true` should evaluate at most once per Unity frame until a better render-pass integration is proven.
- Final product-value comparison must be V Rising `FsrQualityMode=Off` on both baseline and candidate, with the mod controlling render scale/dynamic resolution.

Implemented changes:

- Added visible-window preflight to the visual helper.
- Added per-Unity-frame throttle for user-rendering evaluate, with wall-clock fallback.
- Added performance regression thresholds to visual readiness.
- Updated measurement docs and local working memory.
- Submitted/pushed a correction clarifying final FSR Off testing.

Evidence:

- Baseline in the paired run: about `157.6 FPS`, GPU about `78.6%`, true `3840x2160` capture.
- Candidate: about `44.3 FPS`, GPU near 100%.
- Logs showed about `24600` DLSS user-rendering evaluate calls for `1324` presented frames, roughly `18.6` evaluates per frame.
- This explained the FPS collapse as an integration/frequency bug, not a valid DLSS product result.

Failures/rejected routes:

- Rejected treating the pre-throttle user-rendering candidate as MVP performance evidence.
- Rejected any final gate that allows a severe FPS regression to pass on visual review alone.
- Rejected FSR Performance as final MVP dependency.

Open blockers:

- Need mod-owned render-scale/dynamic-resolution route under FSR Off.
- Need retest after one-evaluate-per-frame throttle.
- Need correct FSR Off baseline versus DLSS On candidate evidence.

Next step:

- Research/implement FSR-independent render-scale control and/or DLSS optimal-settings route.

## Chunk 12 - Render-Scale Route, Compliance Tightening, Optimal Settings, Pause

Message/time range: `2883-3124`, 2026-06-05 20:57:41 to 22:37:09 CST.

User instructions/follow-up/corrections:

- User asked Codex to search authoritative sources about DLSS/FSR/render scale.
- User reiterated two principles: persist logs/search/research/MVP definitions, and do not blind-test.
- User asked to stop after the current round and mark the goal paused.
- User requested exporting the conversation log with `pm-log`.

Technical decisions:

- DLSS Super Resolution does not depend on FSR. It depends on the engine rendering a lower-resolution input and providing depth, motion vectors, history, jitter/exposure/reset, and a higher-resolution output.
- Performance mode for 4K should correspond to about 50% per-axis input, so `3840x2160 -> 1920x1080` is a correct diagnostic target.
- Long-term implementation should query optimal settings from DLSS/Streamline-style APIs instead of hardcoding ratios.
- Release boundaries must be stricter: no game files, PureDark files, NVIDIA runtime/SDK files, SDK-wrapper research binaries, or unsupported official-server claims.

Implemented changes:

- Added `dlss-render-scale-route-2026-06-05.md`.
- Added render-scale control probe for FSR Off testing.
- Added `distribution-compliance-followup-2026-06-05.md`.
- Added/updated `operating-principles.md`, `measurement-plan.md`, and render-scale defaults.
- Added `dlss-optimal-settings-route-2026-06-05.md`.
- Added `dlss-optimal-settings` native/C# diagnostic export and script stage.
- Added `fsr-off-render-scale-test-protocol-2026-06-05.md`.
- Added `pause-state-2026-06-05.md`.
- Exported the chat log.

Evidence:

- Official sources referenced in project docs included NVIDIA UE DLSS blog, NVIDIA DLSS SDK blog, NVIDIA Streamline DLSS programming guide, Unity HDRP DLSS/dynamic-resolution docs, Thunderstore docs, V Rising EULA/TOS, and NVIDIA SDK license materials.
- Local interop confirmed `DynamicResolutionHandler`, `SetupDLSSForCameraDataAndDynamicResHandler`, `DoDLSSPasses`, `DLSSPass`, FSR/upscale symbols, and no built-in `nvngx_dlss.dll`.
- Build checks passed for the optimal-settings export path; release-safe build reports blocked and SDK-wrapper research build can expose the route.
- Current readiness remained `DiagnosticPackageReady_MvpBlocked`.

Failures/rejected routes:

- Rejected relying on FSR Performance as an MVP gate.
- Rejected claiming playable MVP readiness.
- Rejected calling the system goal complete when the user asked for pause.

Open blockers:

- `dlss-optimal-settings` needs actual game-runtime validation.
- FSR Off render-scale control needs runtime proof.
- Normal-user `dlss-user-rendering` needs visual/performance proof with V Rising FSR Off.
- Runtime distribution strategy still needs legal/technical proof for a drag-in user package.
- Automation into gameplay was not yet explored in the 2026-06-04 run.

Next step:

- Resume from `docs/development/pause-state-2026-06-05.md`: dry-run `dlss-optimal-settings`, then follow `fsr-off-render-scale-test-protocol-2026-06-05.md`.
- Under the new goal, run Phase 1 first: systematically explore automatic entry into V Rising gameplay before accepting semi-automatic testing.
