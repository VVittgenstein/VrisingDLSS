# Current Durable Context

Rebuilt from:

- `docs/chatlog/chat-log-codex-2026-06-04-c2222419.md`
- `docs/chatlog/chat-log-codex-2026-06-05-110887f1.md`
- Current repository state and readiness output on 2026-06-06

## Current Goal

Build a playable MVP of a V Rising DLSS Super Resolution mod:

- Free and non-commercial.
- Clean-room.
- Distributable through GitHub and the V Rising/Thunderstore mod ecosystem.
- Real install/run behavior, not only research reports or dev-only DLL swaps.
- Eventually installable by dragging/installing the mod package and changing documented custom settings.

## Goal Source Context

The 2026-06-05 goal-shaping conversation clarified why this reconstruction exists:

- The previous long run had context degradation.
- The old goal started as a search task but became implementation.
- The first step must be rebuilding the 2026-06-04 long chatlog in durable local files.
- Search, source reading, upstream investigation, and route exploration are first-class work.
- Every implementation/test loop should be small, reversible, and evidence-backed.
- Automation into gameplay must be systematically explored before accepting semi-automatic gameplay testing.
- If automation fails after all reasonable routes, the semi-automatic human-Codex-game protocol must be explicit and durable.

## User Principles To Preserve

- Do not redefine success to fit current progress.
- Do not blind-test.
- Before each runtime/game/native/DLSS test, state the question, hypothesis, expected evidence, pass/fail signal, and cleanup path.
- Each round should usually contain only 1-4 minimal reversible actions.
- Bad results are useful and must be persisted as evidence, rejected routes, blocker updates, or protocol changes.
- Search/investigation/source reading are encouraged when route details are uncertain.
- Do not preselect one technical route. Investigate Unity HDRP built-in DLSS, direct NGX/D3D11, Streamline, OptiScaler-like bridges, HDRP dynamic resolution/upscale paths, existing V Rising/Unity/BepInEx precedents, and runtime distribution options.
- Constructive tests default to windowed `1920x1080` for speed and repeatability.
- Real-world E2E tests must cover realistic user install/run behavior and meaningful resolution/DLSS settings.
- Final performance validation must be GPU-bound and controlled: FSR Off baseline versus DLSS On candidate in the same scene/settings, with average FPS, 1% low, P95/P99 frame time, GPU utilization, power, and VRAM.
- Low resolution, FPS caps, or VSync may hide DLSS benefit and cannot be final performance proof.
- A correct DLSS integration should improve FPS under appropriate GPU-bound conditions.

## Canonical Product Decisions

- Current public package remains diagnostic until normal-user visual/performance evidence proves MVP readiness.
- The final product-value comparison is:
  - Baseline: V Rising `FsrQualityMode=Off`, native output, `DLSS.EnableDLSS=false`.
  - Candidate: V Rising `FsrQualityMode=Off`, `DLSS.EnableDLSS=true`, mod-owned render-scale/dynamic-resolution control, DLSS output.
- Built-in V Rising FSR Performance is allowed only as a transition diagnostic for exposing `input < output` tuples.
- The mod must not require users to manually download random DLLs as the final MVP UX. A legal, real-user-acceptable DLSS runtime strategy remains required.
- No PureDark source, binaries, ABI, package layout, private files, or wording.
- No V Rising game files, NVIDIA SDK/runtime files, Streamline DLLs, or SDK-wrapper research binaries in the default public package unless a separate release review approves exact files/notices/obligations.
- BepInExPack V Rising `1.733.2` remains the current package dependency.
- Package payload route is `BepInEx/plugins/VrisingDLSS/`.

## Proven Technical State

- C# plugin and native bridge build locally and in GitHub Actions.
- Thunderstore package validation and release-boundary checks pass for the diagnostic package.
- Runtime probes through API version 12 are build-validated.
- SDK-wrapper research route has passed NGX init/query and feature create/release in local V Rising.
- Stage 8A passed with engine-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` aggregation.
- Stage 8B/8C/8D passed guarded evaluate, output follow-up, and persistent repeated evaluate.
- Stage 8E/8F/8G proved a real SR tuple and NGX evaluate against it.
- Stage 9A proved one feature can persist across repeated RenderGraph callbacks.
- Stage 10A proved guarded visible-path diagnostic write-back to the selected SR output target.
- `dlss-user-rendering` exists as an experimental one-evaluate-per-Unity-frame candidate, but it still needs the correct FSR Off render-scale proof and visual/performance validation.
- Phase 1 no-DLSS automation proof has partial control evidence: `scripts/run-vrising-automation-proof.ps1` can launch V Rising, detect the real `UnityWndClass` window instead of the BepInEx console, capture a nonblank screenshot, archive logs, restore settings/config, and leave no V Rising process. The latest local run `automation-proof-1920-window-v5-20260606` reported `Status=Partial`, `AutomationControlReady=true`, `GameResolutionMatchesRequested=true`, and `GameReportedFullScreenMode=FullScreenWindow`; screenshot capture still saw a `3840x2160` client area, so true `1920x1080` windowed mode is not proven.
- Phase 1 direct-entry search found no supported client command-line auto-continue/direct-connect route in current official Stunlock launch options or local evidence. Local `ServerHistory.json` and interop strings strongly support the in-game `Continue`/direct-connect UI route instead.
- The target local/private game for Continue automation is likely `Name=11111`: this is present in `ServerHistory.json`, and the user recalled the local game was named with many `1` characters and should be continuable directly.
- Phase 1 harmless input proof passed in `automation-proof-harmless-input-escape-v3-20260606`: one `Escape` key was sent to the selected `UnityWndClass` window with `InputSendInputCount=2`, after-input screenshot was nonblank, no crash event was recorded, settings/config were restored, and no V Rising process remained. Computer Use is also available for subsequent multi-step UI navigation.
- Phase 1 observation-only Computer Use session passed in `automation-session-continue-computeruse-20260606`: the session harness launched V Rising and left it ready; Computer Use selected the real `VRising` game window rather than the BepInEx console; the main menu screenshot showed the Chinese Continue entry with save name `11111`; the stop script then restored settings/config, archived logs, recorded `CrashEventCount=0`, and left no V Rising process.
- Product boundary: Computer Use is only a local Codex-side automation/testing tool for entering and observing gameplay during validation. It has no relationship to the DLSS mod implementation, is not a mod feature or runtime dependency, and must not be included in release packages.

## Rejected Or Dangerous Routes

- PureDark code/binary/ABI reuse.
- Treating chat logs themselves as design authority without current-state verification.
- Treating the diagnostic package as the playable MVP.
- Treating Stage 10A proof-loop comparison as the MVP visual/performance gate.
- Treating V Rising FSR Performance as the final DLSS route.
- Injected diagnostic RenderGraph pass as normal Stage 8A route; it crashed in gameplay.
- Broad compiler-generated HDRP render-function patching; it crashed before useful scope logs.
- Direct prefix-time `GetTexture(TextureHandle&)`; unsafe outside valid RenderGraph resource scope.
- `TextureHandle` implicit conversion patching; produced IL2CPP trampoline errors.
- Direct `DLSSPass.Render` Harmony prefix; crashed in `UnityPlayer.dll`.
- `RenderGraphPass<T>.Execute` open-generic Harmony patch; not patchable with current route.
- Production `nvngx_dlss.dll` alone without SDK-wrapper parameter APIs as a complete native integration route.
- Visual screenshots captured as false `PrintWindow` frames.
- Readiness gates that ignore severe FPS regressions.

## Current Blockers

- Phase 1 is not done: automatic entry into V Rising gameplay has not been completed. The current strongest route is a bounded Computer Use activation of the visible Continue/`11111` entry.
- True `1920x1080` windowed control is not solved on this machine because Unity/V Rising is using `FullScreenWindow` even when `Player.log` reports `SetResolution 1920, 1080`.
- Client command-line direct entry is unproven and currently weak; do not spend the next runtime loop on blind command-line guesses.
- If full automation fails, the semi-automatic human-Codex-game protocol still needs a durable, explicit artifact.
- `dlss-optimal-settings` needs actual game-runtime validation.
- FSR Off render-scale control needs runtime proof.
- Normal-user `dlss-user-rendering` needs gameplay image-correctness and performance proof with V Rising FSR Off.
- Output selection, jitter, exposure/pre-exposure, mip bias, resize/reset, fallback, and cleanup remain incomplete for playable MVP.
- Runtime distribution strategy remains unresolved for a drag-in user package that should not require users to manually fetch an arbitrary DLL.
- Real-world E2E from a clean or near-clean `C:\Software\VRising` install is not complete.
- Settings matrix and final GPU-bound performance matrix are not complete.

## Immediate Next Actions

Follow the new goal order:

1. Phase 0 is now durably reconstructed in this directory.
2. Phase 1 should explore automatic entry into V Rising gameplay before more DLSS runtime tests:
   - launch parameters or config/save direct-entry options;
   - window automation;
   - keyboard/mouse automation;
   - image recognition or screenshot-driven state detection;
   - log/config/status detection;
   - fixed local/private test scene setup.
   First-pass local route inventory is in [../development/gameplay-automation-exploration-2026-06-06.md](../development/gameplay-automation-exploration-2026-06-06.md).
3. Use [../development/gameplay-automation-proof-protocol-2026-06-06.md](../development/gameplay-automation-proof-protocol-2026-06-06.md) as the current proof-of-control protocol. The next Phase 1 implementation step is a no-DLSS `Continue` UI-navigation proof toward the local `Name=11111` flow, using the start/stop session harness plus Computer Use for menu navigation.
   Computer Use-specific operating notes are in [../development/computer-use-vrising-automation-notes-2026-06-06.md](../development/computer-use-vrising-automation-notes-2026-06-06.md), and the Continue protocol is in [../development/gameplay-continue-ui-navigation-protocol-2026-06-06.md](../development/gameplay-continue-ui-navigation-protocol-2026-06-06.md).
4. Persist the automation exploration results and either:
   - make automatic gameplay entry the default runtime-test path; or
   - document why all reasonable automation routes failed and continue with a durable semi-automatic protocol.
5. After Phase 1, resume the technical path from `docs/development/pause-state-2026-06-05.md`:
   - dry-run `dlss-optimal-settings`;
   - run only with a written test protocol;
   - continue with `fsr-off-render-scale-test-protocol-2026-06-05.md`.

## Current Repository Checkpoint

As of the Phase 1 Computer Use observation update:

- Branch: `main`.
- Latest pushed checkpoint before this update: `907abe7 Prove harmless game-window input`.
- This checkpoint adds the start/stop automation session harness, a
  Computer Use observation proof for the Continue / `11111` menu target, and the
  next Continue activation protocol.
- Readiness status: `DiagnosticPackageReady_MvpBlocked`.
- Diagnostic package path: `dist/VrisingDLSS-0.1.0-thunderstore.zip`.
