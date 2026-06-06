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
- SDK-wrapper research route has passed NGX init/query, DLSS optimal-settings query, and feature create/release in local V Rising.
- Stage 6B `dlss-optimal-settings` passed in local run `dlss-optimal-settings-20260606-115921` using a `1920x1080` Windowed player shape. The query target was `output=3840x2160` and returned `render=1920x1080`, `dynamicMax=3840x2160`, `dynamicMin=1920x1080`, and `sharpness=0.350`; cleanup restored loader config, release-safe native DLL, and the user's `ClientSettings.json`.
- Stage 8A passed with engine-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` aggregation.
- Stage 8B/8C/8D passed guarded evaluate, output follow-up, and persistent repeated evaluate.
- Stage 8E/8F/8G proved a real SR tuple and NGX evaluate against it.
- Stage 9A proved one feature can persist across repeated RenderGraph callbacks.
- Stage 10A proved guarded visible-path diagnostic write-back to the selected SR output target.
- `dlss-user-rendering` exists as an experimental one-evaluate-per-Unity-frame candidate. The v6 FSR Off constructive run proved it can use a mod-owned `960x540 -> 1920x1080` tuple with repeated SDK-wrapper evaluate success, but it still needs visual/performance, resize/reset, fallback, and release-boundary validation.
- First FSR Off render-scale gameplay proof `fsr-off-render-scale-1080p-v1-20260606` reached gameplay automatically at `1920x1080` Windowed with SDK-wrapper native setup and safe cleanup, but failed the MVP tuple proof. Render-scale control changed HDRP settings to `forceResolution=True` and `forcedPercentage=50`, yet the main candidate stayed `color=1920x1080 output=1920x1080`; the gameplay camera still reported `allowDynamicResolution=False` and `IsDLSSEnabled=False`.
- Follow-up static metadata inspection found public interop entry points for `UnityEngine.Camera.set_allowDynamicResolution` and `UnityEngine.Rendering.RTHandles.SetHardwareDynamicResolutionState(bool)`. `RenderScaleControlProbe` now treats reflected writes as successful only when the post-write readback matches, logs capped `Render-scale control member write did not stick` warnings, and requests `RTHandles.SetHardwareDynamicResolutionState(true)` from the guarded render-scale diagnostic path.
- Follow-up gameplay run `fsr-off-render-scale-1080p-hwdrs-v2-20260606` reached stable gameplay at `1920x1080` Windowed and sharpened the blocker: `RTHandles.SetHardwareDynamicResolutionState=true` logged 16 times with no request failure, but `UnityEngine.Camera.allowDynamicResolution` writeback failed 20 capped times (`before=False; expected=True; after=False`) and main SR candidates still stayed `color=1920x1080 output=1920x1080`. The run cleaned up safely and restored the `11111` save to `ChangeCount=0`.
- Handler-request gameplay run `fsr-off-render-scale-1080p-handler-request-v3-20260606` reached stable `11111` gameplay at `1920x1080` Windowed with Computer Use and cleaned up safely. It failed the MVP tuple proof: Stage 8E did not accept a Super Resolution tuple, `CameraColor_960` count was `0`, `CameraColor_1920` count was `455`, and the gameplay camera stayed `actualWidth=1920,actualHeight=1080`. The log did contain auxiliary `960x540` low/half-resolution resources such as `LowResDepthBuffer`, AO, bloom, and low-res transparent buffers, but these were not a usable color/depth/motion/output tuple. Because that run did not log handler readback, the follow-up patch directly invoked `DynamicResolutionHandler.SetCurrentCameraRequest(true)` from the observed `Update(...)` route.
- Direct handler-request gameplay run `fsr-off-render-scale-1080p-handler-request-v4-20260606` proved the active handler request is not the remaining blocker. It logged `before=True; invokedSetCurrentCameraRequest=True; fieldWritable=True; after=True`, but Stage 8E still did not accept a tuple, `CameraColor_960` count was `0`, `CameraColor_1920` count was `463`, and the gameplay camera stayed `actualWidth=1920,actualHeight=1080`. Cleanup passed and the `11111` save was restored to `ChangeCount=0`.
- Software-fallback gameplay run `fsr-off-render-scale-1080p-software-fallback-v5-20260606` reached stable `11111` gameplay at `1920x1080` Windowed and cleaned up safely, but still failed the tuple proof. It proved fallback state could be forced while `GetCurrentScale=1` and `GetResolvedScale=(1.00, 1.00)` kept the main gameplay targets full-size. The `11111` save was restored to `ChangeCount=0`.
- Post-update fraction gameplay run `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606` passed the FSR Off render-scale proof. The `DynamicResolutionHandler.Update(...)` postfix forced the active handler to the Performance fraction; logs repeatedly showed `m_CurrentFraction=0.5`, `GetCurrentScale=0.5`, `GetResolvedScale=(0.50, 0.50)`, and `SoftwareDynamicResIsEnabled=True`. Stage 8E accepted `CameraColor/CameraDepthStencil/Motion Vectors=960x540` with output `Edge Adaptive Spatial Upsampling=1920x1080`.
- The same v6 run passed the local SDK-wrapper `dlss-user-rendering` smoke proof under V Rising FSR Off: `DLSS user rendering evaluate succeeded` reached `sequenceSuccesses=9000`, `sequenceCreates=1`, `render=960x540`, `target=1920x1080`, and `evaluateSuccesses=9000`, with no blocked/failed user-rendering lines. Cleanup restored `ClientSettings.json`, loader config, the release-safe native DLL, no remaining game process, and the `11111` save to `ChangeCount=0`.
- The first controlled v6 `dlss-user-rendering` visual/performance comparison,
  `v6-user-rendering-1080p-auto-visual-20260606-r2`, reached the same FSR Off
  `960x540 -> 1920x1080` evaluate route and produced valid baseline/candidate
  gameplay screenshots at true `1920x1080` Windowed. It is blocked on performance:
  average FPS regressed `203.617 -> 80.242`, 1% low regressed `156.078 -> 58.688`,
  P95 frame time worsened `5.947 ms -> 14.775 ms`, and average GPU utilization
  dropped `97.5% -> 43.444%`. This suggests a render-thread/synchronization or
  evaluate-placement problem, not a missing DLSS tuple.
- Phase 1 no-DLSS automation proof has partial-control history: `scripts/run-vrising-automation-proof.ps1` can launch V Rising, detect the real `UnityWndClass` window instead of the BepInEx console, capture a nonblank screenshot, archive logs, restore settings/config, and leave no V Rising process. Earlier run `automation-proof-1920-window-v5-20260606` reported `Status=Partial` because it used `FullScreenWindow`; this was later solved for the session harness by temporarily adding `GraphicSettings.WindowMode=3`.
- Phase 1 direct-entry search found no supported client command-line auto-continue/direct-connect route in current official Stunlock launch options or local evidence. Local `ServerHistory.json` and interop strings strongly support the in-game `Continue`/direct-connect UI route instead.
- The target local/private game for Continue automation is likely `Name=11111`: this is present in `ServerHistory.json`, and the user recalled the local game was named with many `1` characters and should be continuable directly.
- Phase 1 harmless input proof passed in `automation-proof-harmless-input-escape-v3-20260606`: one `Escape` key was sent to the selected `UnityWndClass` window with `InputSendInputCount=2`, after-input screenshot was nonblank, no crash event was recorded, settings/config were restored, and no V Rising process remained. Computer Use is also available for subsequent multi-step UI navigation.
- Phase 1 observation-only Computer Use session passed in `automation-session-continue-computeruse-20260606`: the session harness launched V Rising and left it ready; Computer Use selected the real `VRising` game window rather than the BepInEx console; the main menu screenshot showed the Chinese Continue entry with save name `11111`; the stop script then restored settings/config, archived logs, recorded `CrashEventCount=0`, and left no V Rising process.
- Product boundary: Computer Use is only a local Codex-side automation/testing tool for entering and observing gameplay during validation. It has no relationship to the DLSS mod implementation, is not a mod feature or runtime dependency, and must not be included in release packages.
- Phase 1 automatic gameplay entry is now proven for the known local/private `11111` fixture. `automation-windowmode3-1080p-v1-20260606` proved the preferred `1920x1080` Windowed launch shape by temporarily writing `GraphicSettings.WindowMode=3`; `automation-continue-click-windowed-v1-20260606` then clicked Continue once through Computer Use and reached stable gameplay with character/HUD. Player/server logs confirmed local server startup, save load, and character `Helen` connection. Cleanup passed with no crash or remaining process.
- Gameplay entry rotates autosaves. The `11111` save was backed up before the proof, the changed post-proof state was archived, and the save was restored from backup with `SaveCompareAfterRestore-automation-continue-click-windowed-v1-20260606.json` reporting `Status=Restored` and `ChangeCount=0`. Future automated gameplay/runtime tests against this fixture must back up and restore or explicitly retain save changes.
- `fsr-off-render-scale-1080p-v1-20260606` also backed up the `11111` save before entering gameplay. After an accidental human `W` input during the run, the changed save state was archived and the save was restored from the pre-run backup with `SaveCompareAfterRestore-fsr-off-render-scale-1080p-v1-20260606.json` reporting `Status=Restored` and `ChangeCount=0`.

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

- Phase 1 gameplay entry route A is achieved for the local `11111` fixture: future runtime tests should default to the session harness plus Computer Use automated Continue flow.
- True `1920x1080` windowed control is solved for the harness by temporarily adding `GraphicSettings.WindowMode=3`; the user's original `ClientSettings.json` is restored afterward.
- Client command-line direct entry is unproven and currently weak; do not spend the next runtime loop on blind command-line guesses.
- If full automation fails, the semi-automatic human-Codex-game protocol still needs a durable, explicit artifact.
- `dlss-optimal-settings` actual game-runtime validation is complete for the local SDK-wrapper research route; use it only as an optional pre-game API sanity check.
- FSR Off render-scale control has one passing constructive proof: v6 forced the active dynamic-resolution handler fraction to `0.5`, produced the expected `960x540 -> 1920x1080` tuple, and ran repeated SDK-wrapper `dlss-user-rendering` evaluates under V Rising FSR Off. Earlier v1-v5 failures remain useful negative evidence and should not be repeated unchanged.
- Normal-user `dlss-user-rendering` now has gameplay screenshots and repeated evaluate
  success under V Rising FSR Off, but it fails the performance gate severely. The next
  technical blocker is to use the added C#/native timing fields to identify whether
  synchronous NGX evaluate from `RenderGraph GetTexture` is stalling the render thread
  and to move evaluation toward a proper render/upscale pass if confirmed.
- Gameplay image-correctness still needs a human review only after the severe
  performance regression is fixed; do not write a passing human review for the r2
  artifact.
- Output selection, jitter, exposure/pre-exposure, mip bias, resize/reset, fallback, and cleanup remain incomplete for playable MVP.
- Runtime distribution strategy remains unresolved for a drag-in user package that should not require users to manually fetch an arbitrary DLL.
- Real-world E2E from a clean or near-clean `C:\Software\VRising` install is not complete.
- Settings matrix and final GPU-bound performance matrix are not complete.

## Immediate Next Actions

Follow the new goal order:

1. Phase 0 is durably reconstructed in this directory.
2. Phase 1 automatic gameplay entry is proven for the local/private `11111` fixture; do not restart blind launch-option exploration unless new evidence appears.
3. Use [../development/gameplay-automation-proof-protocol-2026-06-06.md](../development/gameplay-automation-proof-protocol-2026-06-06.md) as the current proof-of-control protocol. The Phase 1 gameplay-entry default is now the `1920x1080` Windowed start/stop session harness plus Computer Use Continue flow for local `Name=11111`.
   Computer Use-specific operating notes are in [../development/computer-use-vrising-automation-notes-2026-06-06.md](../development/computer-use-vrising-automation-notes-2026-06-06.md), and the Continue protocol is in [../development/gameplay-continue-ui-navigation-protocol-2026-06-06.md](../development/gameplay-continue-ui-navigation-protocol-2026-06-06.md).
4. Before every automated gameplay/runtime test against `11111`, back up the save and compare/restore afterward unless retaining the changed save is explicitly intended.
5. Resume the technical path from `docs/development/post-update-fraction-runtime-result-2026-06-06.md`:
   - `dlss-optimal-settings` actual runtime validation is passed;
   - the FSR Off `1920x1080` constructive tuple/evaluate proof is passed in v6;
   - `docs/development/v6-user-rendering-visual-test-2026-06-06.md` records the first
     `1920x1080` Windowed visual/performance result: screenshots and evaluate passed,
     performance blocked;
   - do not repeat `fsr-off-render-scale-1080p-v1-20260606`, `fsr-off-render-scale-1080p-hwdrs-v2-20260606`, `fsr-off-render-scale-1080p-handler-request-v3-20260606`, `fsr-off-render-scale-1080p-handler-request-v4-20260606`, or `fsr-off-render-scale-1080p-software-fallback-v5-20260606` unchanged;
   - next loop should run the same protected `1920x1080` Windowed
     `dlss-user-rendering` comparison with the new timing fields and decide whether
     the call must move out of the passive `RenderGraph GetTexture`
     resource-discovery postfix;
   - after performance is no longer severely negative, resume visual correctness,
     resize/reset, fallback, and productionizing the guarded v6 render-scale
     intervention;
   - reserve 4K/native-output performance comparison for the later controlled final validation matrix.

## Current Repository Checkpoint

As of the v6 user-rendering visual/performance follow-up:

- Branch: `main`.
- Latest pushed checkpoint before this update: `5d4125d Prove FSR-off post-update render scale`.
- The current working tree records the `fsr-off-render-scale-1080p-software-fallback-v5-20260606`
  failed fallback-only result, the `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606`
  tuple/evaluate pass, safe cleanup, save restoration, external DLSS mod practice
  research, the `v6-user-rendering-1080p-auto-visual-20260606-r2` blocked
  visual/performance result, the initial DLSS performance-placement investigation, and
  bounded C#/native timing instrumentation for the next user-rendering run.
- Readiness status: `DiagnosticPackageReady_MvpBlocked`.
- Diagnostic package path: `dist/VrisingDLSS-0.1.0-thunderstore.zip`.
