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
- Timing follow-up `v6-user-rendering-1080p-timing-20260606-r3` reproduced the
  performance blocker while proving stable per-frame native evaluate CPU wall time is
  tiny. Baseline/candidate average FPS was `205.255 -> 86.761`, 1% low was
  `153.451 -> 67.061`, P95 frame time was `5.896 ms -> 13.642 ms`, and GPU
  utilization was `98.111% -> 40.889%`. The first DLSS frame-sequence create cost
  about `604.85 ms`, but the stable call at `sequenceSuccesses=12000` reported
  `bridgeTiming lastMs=0.092`, native `total=0.085 ms`, and native `evaluate=0.083 ms`.
  The candidate log had `18414` `RenderGraph GetTexture call` lines and no
  user-rendering failed/blocked/skipped lines. This narrows the blocker away from
  direct NGX evaluate CPU wall time and toward render-scale/HDRP path, hot
  RenderGraph hook overhead, or GPU submission/present behavior.
- Render-scale-only isolation `render-scale-only-1080p-20260606-r1` removed the
  v6 render-scale/HDRP dynamic-resolution intervention as the primary FPS-collapse
  suspect. With V Rising FSR Off at true `1920x1080` Windowed, baseline/candidate
  average FPS was `204.419 -> 205.410`, 1% low was `154.841 -> 140.222`, P95 frame
  time was `5.929 ms -> 6.188 ms`, and GPU utilization/power dropped as expected from
  lower internal workload (`98.222%/135.571 W -> 65.556%/95.183 W`). Candidate logs
  showed `GetCurrentScale=0.5` and `GetResolvedScale=(0.50, 0.50)` 31 times, with
  `0` `DLSS user rendering evaluate succeeded` lines and `0` `RenderGraph GetTexture
  call` lines. Cleanup restored release-safe config, left no game process, and
  restored the `11111` save to `ChangeCount=0`.
- No-evaluate isolation is now complete. The new `dlss-user-rendering-no-evaluate`
  stage accepts the same RenderGraph tuple but returns before creating/evaluating a
  native DLSS frame sequence. It reproduced the collapse without NGX evaluate:
  r1 `202.741 -> 96.867` FPS with `32111` GetTexture-call logs, r2 `200.115 ->
  102.505` FPS after suppressing generic GetTexture diagnostic logging/probe, and
  r3 `201.802 -> 111.842` FPS after reflection caches and accepted-tuple reuse. R4
  `194.424 -> 119.573` FPS after resource-name-first filtering before native
  pointer/owner reflection. Candidate GPU utilization stayed low around `34-41%`, and
  all runs logged `0` evaluate successes. Cleanup restored release-safe config and
  the `11111` save to `ChangeCount=0`. This makes the global
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix/placement the
  leading suspect, not direct NGX evaluate CPU time or render-scale-only control.
- Materialization-only isolation is a negative route. The new
  `dlss-user-rendering-materialization-no-evaluate` stage disabled the global
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix and tried to
  accept the SR tuple only from `BeginExecute` / `CreateTextureCallback`
  materialization. Run `materialization-only-no-evaluate-1080p-20260606-r1`
  patched the materialization hooks cleanly and confirmed GetTexture was skipped,
  but gameplay produced `0` `RenderGraph texture materialization #` logs, `0` SR
  input candidates, and `0` no-evaluate acceptances before the candidate was
  stopped. Cleanup restored release-safe config, left no V Rising process, and
  restored the protected `11111` save to `ChangeCount=0`.
- Cached-driver no-evaluate isolation passed and explains the performance blocker.
  The new default-off
  `Diagnostics.EnableDlssCachedTupleDriverProbe` and helper stage
  `dlss-user-rendering-cached-driver-no-evaluate` use `GetTexture` only until the
  first SR tuple is accepted, then fast-return the `GetTexture` postfix and drive
  the cached tuple from `DynamicResolutionHandler.Update(...)` through the existing
  render-scale-control probe. Run
  `cached-driver-no-evaluate-1080p-20260606-r1` used true `1920x1080` Windowed,
  V Rising `FsrQualityMode=Off`, release-safe native only, and the protected
  `11111` save. Baseline/candidate average FPS was `204.201 -> 198.079`, 1% low
  was `150.395 -> 123.506`, P95 was `5.963 ms -> 6.408 ms`, and GPU utilization
  dropped as expected from `98.111%` to `64.556%`. Logs showed `82` cached-driver
  invocations, `84` no-evaluate acceptances, `0` native evaluate successes/failures/
  blocks, and `0` broad `RenderGraph GetTexture call #` lines. Cleanup restored
  release-safe config/native/settings, left no game process, and restored the
  `11111` save to `ChangeCount=0`.
- Cached-driver real-evaluate was implemented and rejected as a safe evaluate
  boundary; see
  [../development/cached-driver-evaluate-runtime-result-2026-06-06.md](../development/cached-driver-evaluate-runtime-result-2026-06-06.md).
  Run `cached-driver-evaluate-1080p-20260606-r1` first showed one
  accidental `RenderGraph GetTexture` evaluate plus 600 cached-driver successes
  before a candidate crash. Commit `6ac5212` then fully deferred first evaluate out
  of `GetTexture`: run `cached-driver-evaluate-deferred-1080p-20260606-r1` logged
  `1` cached tuple arm, `0` `RenderGraph GetTexture` evaluate successes, `0`
  output follow-up logs, `0` broad `RenderGraph GetTexture call #` lines, and
  cached-driver evaluate success through `sequenceSuccesses=600`. It still crashed
  before Continue/gameplay capture with Windows Application Error `0xc0000005` in
  `nvwgf2umx.dll`. Cleanup restored release-safe state and the protected `11111`
  save to `ChangeCount=0`. This proves `DynamicResolutionHandler.Update(...)` is
  good enough as a no-evaluate performance driver but not safe as the real DLSS
  evaluate submission boundary.
- External research downloaded on 2026-06-06 into
  `ref/dlss-performance-investigation-2026-06-06/` aligns with that conclusion:
  Unity RenderGraph expects actual resources to be used inside render pass execution
  after explicit read/write declarations; HDRP DLSS is tied to Dynamic Resolution and
  submits from a targeted `DLSSPass`; Streamline/NGX guidance centers on feature
  reuse, current-frame resource tagging/evaluate, and explicit resize/reset/lifecycle
  handling; OptiScaler-style injection generally reuses existing upscaler input paths
  instead of broad per-texture discovery.
- Narrow HDRP source/interop follow-up is recorded in
  `docs/research/hdrp-dlss-execution-boundary-2026-06-06.md`. Local Unity source and
  V Rising interop show the official boundary as
  `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super Sampling`
  RenderGraph pass execution -> `DLSSPass.GetCameraResources` ->
  `DLSSPass.Render/ExecuteDLSS`. V Rising exposes the HDRP symbols, but still does
  not show a complete built-in Unity NVIDIA DLSS runtime stack. After the
  `PreRenderPassExecute` rejection, there is no proven safe BepInEx/Harmony hook
  that is exactly equivalent to the official evaluate boundary. Avoid the
  ref-`CompiledPassInfo` RenderGraph executor wrapper family as the next normal
  route. `RenderGraph.OnPassAdded(RenderGraphPass)` was implemented as the
  default-off `rendergraph-pass-map` read-only stage and runtime-tested in
  main-menu plus gameplay. It patched safely and produced no WER crash, but emitted
  `0` pass-map lines, so it is rejected as useful pass-name evidence in the current
  V Rising runtime. The cached-driver no-evaluate result may still be used as
  diagnosis, but the real-evaluate follow-up rejects
  `DynamicResolutionHandler.Update(...)` as a production evaluate boundary. The
  next technical route should move back toward an official HDRP/RenderGraph
  upscale-pass-equivalent boundary with current-frame resources and command-buffer
  ordering comparable to `DoDLSSPass -> DLSSPass.Render/ExecuteDLSS`.
- `docs/research/dlss-theoretical-performance-model-2026-06-06.md` records the
  expected DLSS SR performance shape. For 1920x1080 Performance-mode constructive
  tests, the working model is 960x540 input to 1920x1080 output, or 25% pixel count.
  This is only a pixel-work upper bound, not an FPS promise. At 1080p, flat FPS with
  lower GPU utilization/power can be normal; severe FPS regression with low GPU
  utilization is a likely integration stall/hot-hook signal. Final product-value
  proof still needs a 4K/high-load/GPU-bound FSR Off baseline vs DLSS On matrix.
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
  success under V Rising FSR Off, but it fails the performance gate severely.
  Render-scale-only is no longer the primary suspect: r1 preserved average FPS around
  baseline while proving the 0.5 scale was active and no DLSS evaluate ran.
  No-evaluate isolation then reproduced the severe drop without NGX evaluate, even
  after logging suppression and tuple/reflection caching. Materialization-only
  discovery did not replace the global GetTexture route. Cached-driver
  no-evaluate then proved the steady-state `GetTexture` postfix was the primary
  performance poison, but cached-driver real-evaluate crashed in NVIDIA's D3D11
  user-mode driver even after all evaluate/output-follow-up work was deferred out of
  `GetTexture`. The next technical blocker is to find a real evaluate submission
  boundary with official HDRP/RenderGraph pass-like resource lifetime and
  command-buffer ordering, without repeating rejected ref-`CompiledPassInfo`
  executor patches. `RenderGraph.OnPassAdded` may help pass-name mapping, but it
  should not be treated as a texture/evaluate boundary.
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
   - the protected `1920x1080` Windowed `render-scale-control`/no-DLSS-evaluate
     comparison is now complete in `render-scale-only-1080p-20260606-r1`; it did not
     reproduce the severe FPS/GPU-utilization drop;
   - `dlss-user-rendering-no-evaluate` isolation is complete in
     `user-rendering-no-evaluate-1080p-20260606-r1/r2/r3/r4`; it reproduced the
     collapse without native DLSS evaluate, and caching/log suppression/resource-name
     filtering only partially helped;
   - `dlss-user-rendering-materialization-no-evaluate` isolation is complete in
     `materialization-only-no-evaluate-1080p-20260606-r1`; it cleanly disabled the
     global GetTexture probe but did not observe materialization SR candidates or
     accept a tuple;
   - `rendergraph-pass-boundary-1080p-20260606-r1` rejected the
     `RenderGraph.PreRenderPassExecute` Harmony boundary: it patched successfully,
     emitted `0` `RenderGraph pass boundary #` lines, then V Rising crashed during
     startup in `coreclr.dll` `0xc0000005` before Continue/gameplay. Cleanup
     restored loader config, ClientSettings, release-safe native state, and the
     protected `11111` save with `ChangeCount=0`;
   - `cached-driver-no-evaluate-1080p-20260606-r1` proved that moving
     no-evaluate steady-state work off `GetTexture` recovers performance, but
     `cached-driver-evaluate-deferred-1080p-20260606-r1` rejected
     `DynamicResolutionHandler.Update(...)` as a real DLSS evaluate boundary:
     `GetTexture` evaluate/output-follow-up were both `0`, cached-driver evaluate
     reached `sequenceSuccesses=600`, then V Rising crashed in `nvwgf2umx.dll`
     `0xc0000005` before Continue/capture;
   - next loop must not rerun `rendergraph-pass-boundary` or cached-driver
     real-evaluate unchanged. It should avoid Harmony patching ref-`CompiledPassInfo`
     RenderGraph executor wrappers, and instead search for a narrower official
     HDRP/RenderGraph upscaler-pass-equivalent boundary or supporting pass map.
     `rendergraph-pass-map` was runtime-tested and produced zero pass lines, so do
     not rerun it unchanged. Static inspection now points to a default-off
     `CompileRenderGraph(int)` postfix that snapshots `m_RenderPasses` names/types
     before `ClearRenderPasses()` as the next pass-list observation candidate;
   - use `docs/research/dlss-theoretical-performance-model-2026-06-06.md` to
     interpret performance: 1080p is a constructive correctness/stall test, while
     final DLSS value requires a GPU-bound 4K/high-load matrix;
   - after performance is no longer severely negative, resume visual correctness,
     resize/reset, fallback, and productionizing the guarded v6 render-scale
     intervention;
   - reserve 4K/native-output performance comparison for the later controlled final validation matrix.

## Current Repository Checkpoint

As of the read-only RenderGraph pass-map runtime result:

- Branch: `main`.
- Latest pushed checkpoint before this update: `b97b228 Record cached tuple evaluate boundary rejection`.
- The current working tree records the `fsr-off-render-scale-1080p-software-fallback-v5-20260606`
  failed fallback-only result, the `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606`
  tuple/evaluate pass, safe cleanup, save restoration, external DLSS mod practice
  research, the `v6-user-rendering-1080p-auto-visual-20260606-r2` blocked
  visual/performance result, the initial DLSS performance-placement investigation, and
  the `v6-user-rendering-1080p-timing-20260606-r3` timing result showing stable NGX
  evaluate CPU wall time is not the sustained performance blocker, plus the
  `render-scale-only-1080p-20260606-r1` isolation showing render-scale-only keeps
  average FPS near baseline, plus `dlss-user-rendering-no-evaluate` r1/r2/r3/r4
  evidence that the global RenderGraph `GetTexture` postfix remains too expensive for
  steady-state runtime placement. The latest r4 follow-up tested the narrowed
  `GetTexture` path where non-candidate resource names return before native
  pointer/owner reflection: candidate FPS improved to `119.573`, but the paired
  baseline was still `194.424` FPS and candidate GPU utilization remained low at
  `41.250%`. The working tree also records the source-backed theoretical DLSS SR
  performance model used to separate low-resolution constructive validation from the
  final GPU-bound performance matrix. This update additionally records the negative
  materialization-only no-evaluate route, the local/upstream HDRP DLSS execution
  boundary search, and the downloaded Unity Core RenderGraph reference files. This
  update also adds and runtime-rejects a default-off `rendergraph-pass-boundary`
  diagnostic stage: `PreRenderPassExecute` patching is now high-risk
  crash-recovery-only evidence, not the next normal route. The latest working tree
  additionally records the successful
  `cached-driver-no-evaluate-1080p-20260606-r1` gameplay isolation: no-evaluate
  performance recovered to `204.201 -> 198.079` FPS when steady-state `GetTexture`
  work was fast-skipped and the cached tuple was driven from
  `DynamicResolutionHandler.Update(...)`. The latest working tree also records
  `cached-driver-evaluate-1080p-20260606-r1` and
  `cached-driver-evaluate-deferred-1080p-20260606-r1`: the corrected real-evaluate
  path achieved `GetTexture evaluate=0`, `output follow-up=0`, and cached-driver
  `sequenceSuccesses=600`, but crashed in `nvwgf2umx.dll` before capture. This
  rejects `DynamicResolutionHandler.Update(...)` as the next real evaluate boundary
  and moves the investigation back toward a safe official HDRP upscaler-pass
  equivalent. This update adds and tests the default-off `rendergraph-pass-map`
  stage, which patches `RenderGraph.OnPassAdded(RenderGraphPass)` for read-only
  pass name/type/category logging, disables `GetTexture`, and does not resolve
  resources or evaluate DLSS. Build, dry-run, main-menu smoke, and gameplay smoke
  passed without a WER crash, but both runtime runs emitted `0` pass-map lines.
  The gameplay run restored the protected `11111` save with `ChangeCount=0`.
  `OnPassAdded` is therefore safe but not useful as the next evidence source in
  this runtime. Static follow-up found that V Rising interop exposes
  `RenderGraph.m_RenderPasses`, `GetCompiledPassInfos()`, `CompileRenderGraph(int)`,
  `ClearRenderPasses()`, and `RenderGraphPass.name/index`; the next candidate has
  now been implemented as the default-off `rendergraph-pass-list` stage. It patches
  only `CompileRenderGraph(int)`, logs pass names/categories from `m_RenderPasses`,
  disables `GetTexture`, and does not resolve resources or evaluate. The menu smoke
  `rendergraph-pass-list-1080p-menu-20260606-r2` passed at true `1920x1080`
  Windowed with `CrashEventCount=0`, analyzer `RenderGraph Pass List=Pass`, `90`
  compile lines, `357` entry lines, and repeated `Uber Post -> Edge Adaptive
  Spatial Upsampling -> Final Pass` entries. Gameplay proof
  `rendergraph-pass-list-gameplay-1080p-20260606-r1` also passed in the protected
  `11111` fixture with `CrashEventCount=0`, analyzer `RenderGraph Pass List=Pass`,
  `143` compile lines, `540` entry lines, `0` broad GetTexture logs, focused
  categories `upscale=16`, `postprocess=80`, `final=29`, `temporal=193`, and save
  restore `ChangeCount=0`. Do not rerun pass-list unchanged; the next route is a
  default-off resource-declaration-only snapshot for focused compile-time passes
  around motion vectors, `Uber Post`, `Edge Adaptive Spatial Upsampling`, and
  `Final Pass`. That candidate has now been implemented as
  `Diagnostics.EnableRenderGraphPassResourceDeclarationProbe=false` / stage
  `rendergraph-pass-declarations`; it reuses the safe `CompileRenderGraph(int)`
  postfix, logs pass-local handle declarations only, disables `GetTexture`, and
  does not resolve resources or evaluate. Menu smoke
  `rendergraph-pass-declarations-1080p-menu-20260606-r1` passed at true
  `1920x1080` Windowed with `CrashEventCount=0`, analyzer `RenderGraph Pass
  Declarations=Pass`, `297` declaration lines, `0` broad GetTexture logs, and
  focused declarations for motion vectors, `Uber Post`, `Edge Adaptive Spatial
  Upsampling`, and `Final Pass`. A later startup/window-only session with the
  gameplay label also emitted declaration signal (`399` declaration lines,
  `0` broad GetTexture logs, `CrashEventCount=0`) and restored the save with
  `ChangeCount=0`, but it did not click Continue or enter protected gameplay and
  must not be counted as the gameplay proof. Protected gameplay proof
  `rendergraph-pass-declarations-gameplay-1080p-20260606-r2` then passed in the
  `11111` fixture: Computer Use clicked Continue once and sent no movement keys,
  stable gameplay was captured, analyzer `RenderGraph Pass Declarations=Pass`,
  `529` declaration lines, `0` broad GetTexture logs, failures `0`,
  `CrashEventCount=0`, stop-session cleanup restored ClientSettings/config/native
  state, and save restore ended with `ChangeCount=0`. Do not rerun
  pass-declarations unchanged; inspect the declaration summaries before designing
  any new current-frame command-buffer/evaluate boundary. The narrow source/search follow-up is
  recorded in `docs/research/hdrp-dlss-rendergraph-safe-boundary-followup-2026-06-06.md`:
  the official HDRP DLSS boundary is the `Deep Learning Super Sampling`
  RenderGraph render function calling `DLSSPass.GetCameraResources` and then
  `DLSSPass.Render/ExecuteDLSS`; V Rising has no proven safe Harmony-equivalent
  evaluate boundary yet, so the current safe point remains compile-time
  pass/declaration observation. The latest focused pass-data analysis is recorded
  in `docs/development/rendergraph-pass-data-boundary-analysis-2026-06-06.md`.
  It parsed the protected r2 declaration log as `529` declaration rows, `43`
  complete `Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass` chains,
  `43/43` `Uber write == EASU read`, and `43/43` `EASU write == Final first read`.
  Local/upstream source plus interop pointed to the next minimal experiment,
  implemented as `Diagnostics.EnableRenderGraphPassDataSnapshotProbe=false` /
  stage `rendergraph-pass-data`. It reuses the safe `CompileRenderGraph(int)`
  postfix and reads only focused `UberPostPassData`, `EASUData`, `FinalPassData`,
  and DLSS pass-data scalar/TextureHandle summaries. It must remain read-only,
  avoid `GetTexture`, avoid native pointers, avoid command-buffer work, and only
  map pass data fields/dimensions to the already proven declaration chain. First
  menu smoke `rendergraph-pass-data-1080p-menu-20260606-r1` proved patch safety
  but found base `RenderGraphPass` wrappers do not expose `data` directly. The
  fixed typed Il2CppInterop route then passed
  `rendergraph-pass-data-1080p-menu-20260606-r3` at true `1920x1080` Windowed:
  `CrashEventCount=0`, analyzer `RenderGraph Pass Data=Pass`, `248` snapshot
  lines, `248` `memberCount=` lines, `0` `data=not found`, `0` typed-read
  failures, and `0` broad GetTexture logs. r3 mapped
  `Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass`; EASU reported
  `input=1920x1080 output=1920x1080`; Final reported
  `performUpsampling=True`, `dynamicResIsOn=True`, and
  `dynamicResFilter=EdgeAdaptiveScalingUpres`. Protected gameplay proof
  `rendergraph-pass-data-gameplay-1080p-20260606-r1` then passed in the `11111`
  fixture with Computer Use clicking Continue once and no movement keys:
  `CrashEventCount=0`, analyzer `RenderGraph Pass Data=Pass`, `321` snapshot
  lines, `321` `memberCount=` lines, `0` `data=not found`, `0` typed-read
  failures, `0` broad GetTexture logs, gameplay screenshot with HUD/character/
  minimap, cleanup restored config/ClientSettings/native state, and save restore
  `ChangeCount=0`. Its chain summary found `73` complete chains, `73/73`
  `Uber.destination == EASU.source`, and `73/73`
  `EASU.destination == Final.source`. See
  `docs/development/rendergraph-pass-data-gameplay-result-2026-06-06.md`. Do not
  jump directly to generated EASU/Final render-function patching. A narrow
  local/upstream-source follow-up is recorded in
  `docs/development/rendergraph-execute-delegate-candidate-2026-06-06.md`, with
  downloaded refs under `ref/hdrp-rendergraph-boundary-2026-06-06`. It confirms
  the next candidate is closed generic
  `RenderGraphPass.GetExecuteDelegate<TPassData>()` for `DLSSData`, `EASUData`,
  `FinalPassData`, and optionally `UberPostPassData`. Local reflection proved the
  closed methods can be constructed with `ContainsGenericParameters=False`, and
  ilspy confirmed `RenderGraphPass<TPassData>.Execute(ctx)` invokes that delegate.
  This candidate can prove the pass reached execution-layer code, but it has no
  `RenderGraphContext`, no command buffer, no texture resolution, and no DLSS
  evaluate authority. Implementation follow-up added the default-off
  `Diagnostics.EnableRenderGraphExecuteDelegateProbe=false` config key, helper
  stage `rendergraph-execute-delegate`, analyzer support, and package default.
  Build/package validation passed. Menu runtime follow-up
  `rendergraph-execute-delegate-1080p-menu-20260606-r1` then ran for 120 seconds
  at true `1920x1080` Windowed, patched all four closed generic methods, produced
  `CrashEventCount=0`, restored loader config and ClientSettings, and kept
  `RenderGraph GetTexture call #=0`, but produced `0` focused
  `RenderGraph execute-delegate #` lines. Analyzer reported
  `RenderGraph Execute Delegate=Partial`. Treat this as patch-stability evidence
  only, not menu proof. Do not run protected gameplay for this stage unchanged.
  Local decompile follow-up explains why this is plausible: the V Rising
  `RenderGraphPass<T>.Execute(RenderGraphContext)` interop method is a native
  `runtime_invoke` wrapper, and the patched `GetExecuteDelegate<TPassData>()`
  wrapper reports `CallerCount(0)`. Next inspect/design a new local
  interop/IL2CPP execution-path candidate; do not patch generated render funcs or
  `RenderGraphPass<T>.Execute` as the next normal route.
- Implementation and menu-runtime follow-up added
  `Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe=false` and helper
  stage `rendergraph-renderfunc-metadata`. It reuses the safe
  `CompileRenderGraph(int)` postfix to read focused pass `renderFunc` delegate
  metadata only: no delegate call, no generated render-func patch, no
  `RenderGraphContext`, no resource/native texture resolution, no command buffer,
  and no DLSS evaluate. The accepted menu proof
  `rendergraph-renderfunc-metadata-1080p-menu-20260606-r3` passed at true
  `1920x1080` Windowed with `CrashEventCount=0`, analyzer
  `RenderGraph RenderFunc Metadata=Pass`, `248` metadata lines, `0`
  `renderFunc=not found`, `0` metadata failures, `0` broad GetTexture logs, and
  cleanup restored loader config and ClientSettings. It mapped `Uber Post` to
  `<UberPass>b__1060_0` (`100664386`), `Edge Adaptive Spatial Upsampling` to
  `<EdgeAdaptiveSpatialUpsampling>b__1066_0` (`100664389`), and `Final Pass` to
  `<FinalPass>b__1069_0` (`100664390`). Protected gameplay proof
  `rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1` then passed in
  the `11111` fixture: Computer Use clicked Continue once and sent no movement
  keys, Player log reported `SetResolution 1920, 1080, fullScreenMode Windowed`,
  stable gameplay was captured, analyzer `RenderGraph RenderFunc Metadata=Pass`,
  `300` metadata lines, `0` `renderFunc=not found`, `0` metadata failures, `0`
  broad GetTexture logs, `CrashEventCount=0`, cleanup restored config/settings,
  and save restore ended with `ChangeCount=0`. This is gameplay-safe metadata
  evidence, not an execution/evaluate boundary. Do not rerun this stage
  unchanged; next action is local source/interop design for a safer equivalent to
  the official HDRP execution boundary.
- Narrow source/interop/web follow-up is recorded in
  `docs/research/hdrp-rendergraph-harmony-boundary-audit-2026-06-06.md`.
  Official Unity HDRP obtains resources and submits DLSS inside the
  `Deep Learning Super Sampling` RenderGraph render function:
  `DoDLSSPass -> DLSSPass.GetCameraResources -> DLSSPass.Render(ctx.cmd)`.
  Unity RenderGraph docs/source confirm actual resources are available in pass
  execution code, while local V Rising interop decompile shows
  `RenderGraphPass<T>.Execute(...)`, `RenderFunc<T>.Invoke(...)`, and
  `DLSSPass.GetCameraResources(...)` managed wrappers report `CallerCount(0)`
  and use `IL2CPP.il2cpp_runtime_invoke(...)`. This explains why the
  execute-delegate probe was stable but silent. There is no currently proven
  safe BepInEx/Harmony-equivalent boundary for the official DLSS window. Keep
  `CompileRenderGraph(int)` as a read-only map only. Do not patch generated
  render funcs, `DLSSPass.Render`, ref-`CompiledPassInfo` executor wrappers, or
  `RenderFunc<T>.Invoke`/`RenderGraphPass<T>.Execute` as the next normal route.
  If more map state is needed, add only a default-off compiled-pass-info snapshot
  from `CompileRenderGraph(int)`. If approaching the real execution boundary,
  first design a separate `native-renderfunc-entry` no-op method-pointer probe;
  this is a new risk class, not ordinary Harmony patching.
- Narrow search refresh is recorded in
  `docs/research/hdrp-rendergraph-boundary-refresh-2026-06-06.md`. It added
  local snapshots of Unity HDRP DLSS, Unity HDRP Dynamic Resolution, and BepInEx
  runtime patching docs under `ref/hdrp-rendergraph-boundary-2026-06-06/`. The
  refresh did not find a new safe Harmony boundary. The official source answer
  remains `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> Deep Learning Super
  Sampling render func -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`;
  the read-only `rendergraph-compiled-pass-info` menu proof is now complete, so
  the next practical branch is a separately designed `native-renderfunc-entry`
  no-op method-pointer probe or an equally safe pass-owned boundary.
- Implementation follow-up added the default-off
  `Diagnostics.EnableRenderGraphCompiledPassInfoProbe=false` and helper stage
  `rendergraph-compiled-pass-info`. It reuses the proven
  `CompileRenderGraph(int)` postfix, reads
  `m_CurrentCompiledGraph.compiledPassInfos`, handles Unity `DynamicArray<T>` by
  `size` plus `m_Array`, and logs only focused `CompiledPassInfo`
  culling/sync/refCount/resource-create/release counts. It does not resolve
  textures, call `GetTexture`, inspect native pointers, touch command buffers,
  call render funcs, or evaluate DLSS. First menu runtime
  `rendergraph-compiled-pass-info-1080p-menu-20260606-r2` passed at true
  `1920x1080` Windowed with `CrashEventCount=0`, analyzer
  `RenderGraph Compiled Pass Info=Pass`, `299` focused compiled-pass-info
  lines, `compiledPassInfos=not found=0`, `GetTexture=0`, and restored
  loader/native/settings. It captured `Uber Post`, `Edge Adaptive Spatial
  Upsampling`, and `Final Pass` as `culled=False` map evidence. This is still
  not an evaluate boundary; do not rerun unchanged except after regression or a
  Unity/V Rising update. See
  `docs/development/rendergraph-compiled-pass-info-runtime-result-2026-06-06.md`.
- Readiness status: `DiagnosticPackageReady_MvpBlocked`.
- Diagnostic package path: `dist/VrisingDLSS-0.1.0-thunderstore.zip`.
- Native render-func entry preflight is recorded in
  `docs/development/native-renderfunc-entry-preflight-2026-06-06.md` and
  implemented as `scripts/get-native-renderfunc-entry-preflight.ps1`. It does
  not launch V Rising or install a detour. It parsed the protected gameplay
  renderfunc-metadata proof and found stable focused entries:
  `Uber Post` `<UberPass>b__1060_0` token `100664386`
  `method_ptr=0x7FF8E91BC9F0`, EASU
  `<EdgeAdaptiveSpatialUpsampling>b__1066_0` token `100664389`
  `method_ptr=0x7FF8E91BE1C0`, and `Final Pass`
  `<FinalPass>b__1069_0` token `100664390`
  `method_ptr=0x7FF8E91BE7F0`; all had `invoke_impl == method_ptr`. Deep
  inspection confirmed local `NativeDetour(IntPtr, IntPtr)`,
  Il2Cpp `MethodPointer`, and Harmony IL2CPP backend MethodPointer detour /
  `OriginalTrampoline` evidence. This remains design evidence only.
- The separate default-off `native-renderfunc-entry` no-op probe is now
  implemented and statically validated; see
  `docs/development/native-renderfunc-entry-probe-implementation-2026-06-06.md`.
  Config key: `Diagnostics.EnableNativeRenderFuncEntryProbe=false`. Helper
  stage: `native-renderfunc-entry`. It observes only the EASU `method_ptr` from
  `CompileRenderGraph(int)`, waits for three stable observations, installs an
  Il2CppInterop native detour, increments one counter, and immediately calls the
  original trampoline. Menu runtime proof
  `native-renderfunc-entry-1080p-menu-20260606-r1` passed at true `1920x1080`
  Windowed: analyzer `Native RenderFunc Entry=Pass`, `CrashEventCount=0`,
  `RenderGraph GetTexture call #=0`, one install, and counter advancement from
  compile 4 onward. This was menu ABI proof only, still with no
  resources/command buffers/DLSS evaluate. See
  `docs/development/native-renderfunc-entry-runtime-result-2026-06-06.md`.
- Protected `11111` gameplay proof
  `native-renderfunc-entry-gameplay-1080p-20260606-r1` passed at true
  `1920x1080` Windowed. Computer Use clicked Continue once and sent no movement
  keys. Analyzer `Native RenderFunc Entry=Pass`; final native status reached
  `entryCount=776`, `observations=778`, candidate pointer
  `0x7FF8973EE1C0`; `RenderGraph GetTexture call #=0`; `probe failed=0`;
  `CrashEventCount=0`. Cleanup restored config, ClientSettings, release-safe
  native state, no game process remained, and the protected save restored to
  `ChangeCount=0`. This proves gameplay ABI safety only. Next step is a
  separately default-off native-entry argument preflight, menu-first, still no
  pointer dereference, command-buffer access, or DLSS evaluate. See
  `docs/development/native-renderfunc-entry-gameplay-result-2026-06-06.md`.
- Narrow post-entry source/search audit is recorded in
  `docs/research/hdrp-dlss-official-boundary-native-entry-audit-2026-06-06.md`.
  It keeps local/upstream source primary and network search narrow. The official
  HDRP boundary remains `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass ->
  Deep Learning Super Sampling render func -> DLSSPass.GetCameraResources ->
  DLSSPass.Render(ctx.cmd)`. `CreateTextureCallback`, global `GetTexture`,
  `DynamicResolutionHandler.Update`, managed RenderGraph wrappers, and
  `DLSSPass.Render` Harmony patching remain rejected/non-production boundaries.
  After the native-entry menu/gameplay proofs, the best current direction is a
  separate default-off native-entry argument preflight: sample raw arguments
  only, no dereference in callback, no command buffer, no resources, no DLSS,
  menu-first, protected gameplay only after menu proof.
- The `native-renderfunc-args` preflight is now implemented and statically
  validated; see
  `docs/development/native-renderfunc-args-preflight-implementation-2026-06-06.md`.
  Config key: `Diagnostics.EnableNativeRenderFuncArgumentProbe=false`. Helper
  stage: `native-renderfunc-args`. It reuses the EASU entry detour, samples only
  raw callback argument pointer values (`thisPtr`, `passDataPtr`,
  `renderGraphContextPtr`, `methodInfoPtr`) with atomic counters/last-pointer
  snapshots, and immediately calls the original trampoline. Build, dry-run
  config validation, package validation, release boundary check, and status
  scripts passed. Menu runtime proof
  `native-renderfunc-args-1080p-menu-20260606-r1` also passed at true
  `1920x1080` Windowed: analyzer `Native RenderFunc Args=Pass`,
  `CrashEventCount=0`, `RenderGraph GetTexture call #=0`, one detour install,
  `entryCount=778`, `sampleCount=778`, and all four raw callback argument
  pointer categories nonzero `778/778`. No actual DLSS evaluate/probe/native-call
  patterns were present. Cleanup restored loader config, release-safe native,
  ClientSettings, and no game process remained. This proves menu argument-shape
  safety only, not resource identity, command-buffer access, gameplay safety, or
  DLSS evaluate safety. See
  `docs/development/native-renderfunc-args-runtime-result-2026-06-06.md`.
- Protected `11111` gameplay proof
  `native-renderfunc-args-gameplay-1080p-20260606-r1` also passed at true
  `1920x1080` Windowed. Computer Use selected the real `VRising` Unity window,
  clicked the known Chinese Continue / `11111` entry once at `(205, 354)` in
  the current `1283x751` Computer Use screenshot, and sent no movement/gameplay
  keys. Analyzer `Native RenderFunc Args=Pass`; final status reached
  `entryCount=841`, `sampleCount=841`, and all four raw callback argument
  pointer categories nonzero `841/841`; `RenderGraph GetTexture call #=0`;
  `probe failed=0`; actual NGX/DLSS evaluate/probe/native-call patterns `0`;
  `CrashEventCount=0`. Gameplay screenshot captured HUD/character/minimap.
  Cleanup restored loader config, release-safe native, ClientSettings, no game
  process remained, and the protected save restored to `ChangeCount=0` after one
  autosave rotation was archived. See
  `docs/development/native-renderfunc-args-gameplay-result-2026-06-06.md`.
  Next step: design a separate default-off resource-identity preflight from the
  raw argument evidence, still no native-callback pointer dereference,
  command-buffer access, or DLSS evaluate.
