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
- A narrower 2026-06-07 refresh is recorded in
  `docs/research/hdrp-dlss-official-boundary-narrow-refresh-2026-06-07.md`.
  It re-confirms that the exact official boundary is the `Deep Learning Super
  Sampling` RenderGraph render func calling
  `DLSSPass.GetCameraResources(data.resourceHandles)` immediately before
  `DLSSPass.Render(..., ctx.cmd)`. V Rising still has no proven safe Harmony
  equivalent: `DLSSPass.Render`, generated render funcs, ref-`CompiledPassInfo`
  executor wrappers, `GetExecuteDelegate<T>`, `RenderGraphPass<T>.Execute`,
  `RenderFunc<T>.Invoke`, `CreateTextureCallback`, and
  `DynamicResolutionHandler.Update` are rejected/no-signal/not equivalent for
  the next normal route. The only newly interesting source-backed branch is
  HDRP `CustomPostProcessVolumeComponent.Render(cmd, camera, source, destination)`:
  HDRP binds depth/normal/motion/source globally before calling it, so it may be a
  BepInEx-accessible command-buffer boundary if a mod can register a custom post
  process into V Rising's IL2CPP HDRP global settings and active volume stack.
  Treat that as a separate no-native/no-DLSS registration proof, not as an
  established DLSS evaluate boundary.
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
  Next step is now the separate default-off resource-identity menu proof, still
  no native-callback pointer dereference, command-buffer access, or DLSS
  evaluate.
- Narrow source/search refresh after the args proof is recorded in
  `docs/research/hdrp-dlss-pass-boundary-narrow-refresh-2026-06-06.md`.
  It reconfirms the official HDRP boundary as the `Deep Learning Super Sampling`
  RenderGraph render function: `DoDLSSPass -> DLSSPass.GetCameraResources ->
  DLSSPass.Render(ctx.cmd)`. V Rising interop exposes the DLSS pass structure
  and exact generated EASU render-func method, but not the complete Unity NVIDIA
  runtime stack. No new safe Harmony boundary was found. The next reversible
  step is the default-off resource-identity preflight implemented below.
- The `native-renderfunc-resource-identity` preflight is now implemented and
  statically validated; see
  `docs/development/native-renderfunc-resource-identity-preflight-implementation-2026-06-06.md`.
  Config key: `Diagnostics.EnableNativeRenderFuncResourceIdentityProbe=false`.
  Helper stage: `native-renderfunc-resource-identity`. It reuses the proven EASU
  native entry/args no-op detour, correlates the latest raw native `passDataPtr`
  with the managed EASU pass-data object observed from
  `CompileRenderGraph(int)`, and verifies focused managed `source` /
  `destination` TextureHandle identity. It still does not dereference native
  callback pointers, resolve textures, call `GetTexture`, touch command buffers,
  patch generated render funcs through Harmony, or evaluate DLSS. Static
  `git diff --check`, Release build, dry-run config, Thunderstore package
  build/validation, and process-safety check passed. Next proof is
  `scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-identity -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3`
  at true `1920x1080` Windowed menu-only.
- Menu runtime proof
  `native-renderfunc-resource-identity-1080p-menu-20260607-r1` passed at true
  `1920x1080` Windowed. Analyzer reported
  `Native RenderFunc Resource Identity=Pass`; first advanced line appeared at
  `compile=4` with `managedPassData=0x2840EC567E0`,
  `nativeLastPassData=0x2840EC567E0`, `passDataMatches=True`,
  `hasTextureIdentity=True`, and focused `source` / `destination`
  TextureHandles. Final sampled status reached `entryCount=3897`,
  `sampleCount=3897`, and all four raw pointer categories nonzero `3897/3897`.
  `RenderGraph GetTexture call #=0`; actual native/DLSS evaluate/probe patterns
  `0`; `CrashEventCount=0`. Cleanup restored loader config, release-safe native,
  ClientSettings, and no game process remained. See
  `docs/development/native-renderfunc-resource-identity-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-identity-gameplay-1080p-20260607-r1` also passed
  at true `1920x1080` Windowed. Computer Use selected the real Unity `VRising`
  window, clicked the Chinese Continue / `11111` area once at `(205, 354)` in a
  `1283x751` screenshot, and sent no movement/gameplay keys. Gameplay screenshot
  showed quest text, character, HUD, health bar, and action bar. Analyzer
  reported `Native RenderFunc Resource Identity=Pass`; first advanced line
  appeared at `compile=4` with `managedPassData=0x166A6073300`,
  `nativeLastPassData=0x166A6073300`, `passDataMatches=True`, and
  `hasTextureIdentity=True`; final entry/argument status reached
  `entryCount=1072`, `sampleCount=1072`, all four raw pointer categories nonzero
  `1072/1072`; `RenderGraph GetTexture call #=0`; actual native/DLSS
  evaluate/probe patterns `0`; `CrashEventCount=0`. Cleanup restored loader
  config, release-safe native, ClientSettings, no game process remained, and the
  protected save restored to `ChangeCount=0` after archiving one changed
  post-run state. See
  `docs/development/native-renderfunc-resource-identity-gameplay-result-2026-06-07.md`.
  Next engineering step: decide whether this proven managed EASU pass-data /
  TextureHandle identity can support a separate default-off official-boundary-
  adjacent resource preflight. Still no command-buffer access or DLSS evaluate
  without another explicit preflight.
- The `native-renderfunc-resource-tuple` dry preflight is now implemented and
  statically validated; see
  `docs/development/native-renderfunc-resource-tuple-preflight-implementation-2026-06-07.md`.
  Config key: `Diagnostics.EnableNativeRenderFuncResourceTupleProbe=false`.
  Helper stage: `native-renderfunc-resource-tuple`. It reuses the proven EASU
  entry/args/resource-identity path and formats the matched managed `EASUData`
  into tuple metadata: input/output dimensions plus focused `source` /
  `destination` TextureHandle resource identity. It still does not dereference
  native callback pointers, call `GetTexture`, resolve textures, touch command
  buffers, patch generated render funcs through Harmony, or evaluate DLSS.
  Static `git diff --check`, Release build, dry-run config validation,
  Thunderstore package validation, local loader config restore, and process
  safety checks passed. Menu runtime proof
  `native-renderfunc-resource-tuple-1080p-menu-20260607-r1` then passed at true
  `1920x1080` Windowed: analyzer
  `Native RenderFunc Resource Tuple=Pass`; first advanced line appeared at
  `compile=4` with `managedPassData=0x1149CC95420`,
  `nativeLastPassData=0x1149CC95420`, `passDataMatches=True`,
  `tupleReady=True`, and tuple metadata `input=1920x1080`,
  `output=1920x1080`, focused `source` TextureHandle identity, and focused
  `destination` TextureHandle identity. Final tuple status reached `#600` with
  `entryCount=597` and `sampleCount=597`; `RenderGraph GetTexture call #=0`;
  actual native/DLSS evaluate/probe patterns `0`; `CrashEventCount=0`; cleanup
  restored loader config, release-safe native, ClientSettings, and no game
  process remained. See
  `docs/development/native-renderfunc-resource-tuple-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-tuple-gameplay-1080p-20260607-r1` also passed at
  true `1920x1080` Windowed. Computer Use selected the real Unity `VRising`
  window, clicked the Chinese Continue / `11111` area once at `(205, 354)`, and
  sent no movement/gameplay keys. Gameplay screenshot showed quest text,
  character, health bar, and action bar. Analyzer reported
  `Native RenderFunc Resource Tuple=Pass`; first tuple advanced line appeared at
  `compile=4` with `managedPassData=0x2151E640D80`,
  `nativeLastPassData=0x2151E640D80`, `passDataMatches=True`, and
  `tupleReady=True`; final tuple status reached `#900` with `entryCount=897`
  and `sampleCount=897`; final args/entry reached `entryCount=1032` and
  `sampleCount=1032`; `RenderGraph GetTexture call #=0`; actual native/DLSS
  evaluate/probe patterns `0`; `CrashEventCount=0`; cleanup restored config,
  native DLL, ClientSettings, no game process remained, and the protected save
  restored to `ChangeCount=0`. See
  `docs/development/native-renderfunc-resource-tuple-gameplay-result-2026-06-07.md`.
  The first separately guarded resource-resolution preflight is now implemented
  as `native-renderfunc-resource-resolve`; see
  `docs/development/native-renderfunc-resource-resolve-preflight-implementation-2026-06-07.md`.
  Config key:
  `Diagnostics.EnableNativeRenderFuncResourceResolveProbe=false`. Helper stage:
  `native-renderfunc-resource-resolve`. It reuses the proven EASU
  entry/args/resource-identity/tuple path and resolves the matched `source` /
  `destination` TextureHandles through
  `RenderGraphResourceRegistry.GetTextureResource(ResourceHandle&)` only. It
  still does not call `GetTexture(TextureHandle&)`, read native texture
  pointers, use D3D11 probes, touch command buffers, patch generated render
  funcs through Harmony, or evaluate DLSS. Static Release build, PowerShell
  parser validation, `git diff --check`, dry config validation,
  Thunderstore package validation, and loader-safe config restore passed. The
  true `1920x1080` Windowed menu proof
  `native-renderfunc-resource-resolve-20260607-134221` passed:
  analyzer `Native RenderFunc Resource Resolve=Pass`, `CrashEventCount=0`,
  `resourceReady=True` count `80`, `textureResourceReady=True` count `80`,
  `graphicsReady=True` count `0`, `RenderGraph GetTexture call #=0`, native
  texture/D3D11/ExecuteDLSS/NGX patterns `0`, and cleanup restored loader config,
  native DLL, and ClientSettings with no game process left. This is
  `TextureResource` metadata proof only; both handles still had
  `graphicsResource=null`. See
  `docs/development/native-renderfunc-resource-resolve-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-resolve-gameplay-1080p-20260607-r1` then passed at
  true `1920x1080` Windowed. Computer Use clicked the Chinese Continue /
  `11111` area once at `(205, 354)` and sent no movement/gameplay keys. Gameplay
  screenshot showed quest text, character, minimap, health bar, and action bar.
  Analyzer `Native RenderFunc Resource Resolve=Pass`; first resolve advanced
  line had `passDataMatches=True`, `tupleReady=True`, `resourceReady=True`,
  `graphicsReady=False`, source/destination resource handles `78/79`, and both
  handles returned `TextureResource` with `graphicsResource=null`.
  `resourceReady=True` count `80`, `textureResourceReady=True` count `80`,
  `graphicsReady=True` count `0`, `RenderGraph GetTexture call #=0`, native
  texture/D3D11/ExecuteDLSS/NGX patterns `0`, `CrashEventCount=0`; cleanup
  restored loader config, native DLL, ClientSettings, no game process remained,
  and the protected save restored to `ChangeCount=0`. See
  `docs/development/native-renderfunc-resource-resolve-gameplay-result-2026-06-07.md`.
  This completes metadata-resolve menu+gameplay proof only. The next
  separately guarded preflight is now implemented as
  `native-renderfunc-resource-native-pointer`; see
  `docs/development/native-renderfunc-resource-native-pointer-preflight-implementation-2026-06-07.md`.
  Config key:
  `Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe=false`. It
  reuses the proven EASU entry/args/resource-identity/tuple path, arms the
  matched `source` / `destination` TextureHandle handles at the safe
  `CompileRenderGraph(int)` pass-list snapshot, and passively observes
  Unity-owned `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix
  returns only for those two handles. It reads `GetNativeTexturePtr()` only from
  the already-returned texture object and logs success only after both native
  pointers are nonzero. It still does not make direct `GetTexture` calls, patch
  generated render funcs through Harmony, use D3D11 validation, touch command
  buffers, or evaluate DLSS. Static Release build, PowerShell parser
  validation, `git diff --check`, dry config validation, package creation, and
  Thunderstore package validation passed. The first menu run
  `native-renderfunc-resource-native-pointer-20260607-142048` was stable but
  partial because GetTexture postfix installation still lived under the
  `DlssEvaluateInputProbeEnabled` branch. A narrow install-condition fix was
  applied, then the true `1920x1080` Windowed menu proof
  `native-renderfunc-resource-native-pointer-20260607-142357` passed:
  analyzer `Native RenderFunc Resource Native Pointer=Pass`,
  `CrashEventCount=0`, GetTexture postfix patched, EASU target armed at
  `compile=4`, source `nativePtr=0x22815E176A0`, destination
  `nativePtr=0x22815E194E0`, `RenderGraph GetTexture call #=0`, D3D11/NGX/DLSS
  evaluate patterns `0`, and cleanup restored loader config, native DLL, and
  ClientSettings with no game process left. See
  `docs/development/native-renderfunc-resource-native-pointer-runtime-result-2026-06-07.md`.
  Protected `11111` gameplay proof
  `native-renderfunc-resource-native-pointer-gameplay-1080p-20260607-r1` then
  passed at true `1920x1080` Windowed. Computer Use clicked the Chinese
  Continue / `11111` area once at `(205, 354)`, sent no movement/gameplay keys,
  recovered from one stale/crossed Codex screenshot without sending input,
  and captured gameplay with quest text, character, minimap, health bar, and
  action bar. Analyzer `Native RenderFunc Resource Native Pointer=Pass`; first
  native-pointer advanced line had source `nativePtr=0x1C09CF519A0`, destination
  `nativePtr=0x1C09D040620`, both at `1920x1080`, `targetCompile=4`, and
  `targetManagedPassData=0x1BF14614660`. `RenderGraph GetTexture call #=0`,
  D3D11/NGX/DLSS evaluate patterns `0`, `CrashEventCount=0`; cleanup restored
  config, native DLL, ClientSettings, no game process remained, and the
  protected save restored to `ChangeCount=0`. See
  `docs/development/native-renderfunc-resource-native-pointer-gameplay-result-2026-06-07.md`.
  This completes native texture-pointer menu+protected-gameplay proof only.
  The next engineering step must be a separately guarded preflight for the next
  official-boundary question; still no command-buffer access, D3D11 validation,
  or DLSS evaluate in the same step.
- 2026-06-07 continuation: implemented the first separately guarded HDRP
  CustomPostProcess boundary preflight as `custom-postprocess-registration`;
  see
  `docs/development/custom-postprocess-registration-preflight-implementation-2026-06-07.md`.
  Config key:
  `Diagnostics.EnableCustomPostProcessRegistrationProbe=false`. It registers an
  injected `CustomPostProcessVolumeComponent` implementing HDRP
  `IPostProcessComponent`, appends its type string to
  `HDRenderPipelineGlobalSettings.afterPostProcessCustomPostProcesses`, calls
  `RefreshPostProcessTypes()`, and does not create a custom `Volume` or call
  `VolumeProfile.Add(Type)`. `IsActive()` returns `false`, so this is a
  global-settings registration proof only. It does not enter `Render(...)`,
  issue command-buffer work, resolve RenderGraph resources, read native texture
  pointers, use D3D11 validation, or evaluate DLSS. Static Release build,
  dry-run config validation, release-boundary check, Thunderstore package
  creation/validation, standalone package validation, and `git diff --check`
  passed before the first commit. Runtime menu follow-up
  `custom-postprocess-registration-1080p-menu-20260607-r1` was stable but
  failed because the first implementation tried to add the injected component
  to a `VolumeProfile`, which threw `NullReferenceException` from
  `UnityEngine.Rendering.VolumeComponent.OnEnable`. The narrowed
  global-settings-only follow-up
  `custom-postprocess-registration-1080p-menu-20260607-r2` passed at true
  `1920x1080` Windowed: analyzer
  `HDRP Custom PostProcess Registration=Pass`,
  `addedToGlobalSettings=True`, `volumeCreated=False`, `renderActive=False`,
  `CrashEventCount=0`, no NullReference in BepInEx or Player logs,
  `RenderGraph GetTexture call #=0`, D3D11/NGX/DLSS evaluate patterns `0`,
  cleanup restored loader config, release-safe native, and ClientSettings, and
  no game process remained. See
  `docs/development/custom-postprocess-registration-menu-result-2026-06-07.md`.
  Any active volume mount/render/copy proof must be a separate default-off
  stage with its own launch contract and must first address the
  `VolumeComponent.OnEnable` failure or avoid that instantiation path.
- Narrow source/search follow-up after the custom-postprocess registration proof
  is recorded in
  `docs/research/hdrp-dlss-official-boundary-narrow-followup-2026-06-07.md`.
  It reconfirms that official HDRP DLSS obtains live resources and submits
  evaluate only inside the `Deep Learning Super Sampling` RenderGraph render
  func: `DLSSPass.GetCameraResources(data.resourceHandles)` immediately before
  `DLSSPass.Render(..., ctx.cmd)`. OptiScaler-style proxying is not a new
  boundary for V Rising because it assumes the game already reaches an
  upscaler API input. The relevant local precedent is only the boundary shape in
  PureDark's V Rising PerfMod: an existing custom post-process `CustomVignette`
  render postfix receives `cmd`, `source`, and `destination`, then reads global
  depth/motion textures and issues a native plugin event. This is evidence for a
  possible HDRP post-process execution boundary, not permission to reuse
  PureDark source, binaries, ABI, package layout, or wording. Next safe work is
  still a default-off injected/custom postprocess `VolumeComponent` creation and
  no-native/no-DLSS render-entry proof before any resource pointer or evaluate
  experiment.
- 2026-06-07 continuation: implemented the separately guarded
  `custom-postprocess-render-entry` preflight; see
  `docs/development/custom-postprocess-render-entry-preflight-implementation-2026-06-07.md`.
  New config key:
  `Diagnostics.EnableCustomPostProcessRenderEntryProbe=false`. The stage mounts
  a hidden global layer-0 `Volume` with a hidden `VolumeProfile`, adds an
  injected `RenderEntryComponent` using the IL2CPP type handle, initializes the
  injected component's `parameterList` in its constructor and after
  `VolumeProfile.Add(...)` if that call returns, returns `IsActive() == true`,
  and in `Render(cmd, camera, source, destination)` only calls
  `HDUtils.BlitCameraTexture(cmd, source, destination)` plus sparse logging.
  It disables `EnableRenderGraphGetTextureProbe`, disables `EnableHookProbe`,
  keeps `EnableDLSS=false`, does not load/use the native bridge, does not read
  native texture pointers, and does not evaluate DLSS. Static Release build,
  dry-run/written helper config, release-boundary check, Thunderstore package
  creation/validation, standalone package validation, and `git diff --check`
  passed before runtime. Runtime follow-up is recorded in
  `docs/development/custom-postprocess-render-entry-menu-result-2026-06-07.md`.
  Run `custom-postprocess-render-entry-1080p-menu-20260607-r1` crashed before
  the diagnostic window with WER `0xc00000fd` in `KERNELBASE.dll`; the likely
  cause was the injected `OnEnable()` override calling `base.OnEnable()` through
  a generated IL2CPP wrapper that still used virtual dispatch. The override was
  removed. Run `custom-postprocess-render-entry-1080p-menu-20260607-r2` then
  stayed stable at true `1920x1080` Windowed (`CrashEventCount=0`,
  `ExitedBeforeWindow=False`, `ClosedByScript=True`, cleanup restored config,
  release-safe native, and ClientSettings), but analyzer reported
  `HDRP Custom PostProcess Render Entry=Fail`: `VolumeProfile.Add(...)` still
  threw `NullReferenceException` from
  `UnityEngine.Rendering.VolumeComponent.OnEnable()`. There was no
  `volume mounted` line and no `Render #` line; `RenderGraph GetTexture`,
  D3D11/NGX/DLSS/evaluate patterns were `0`. Do not rerun this stage unchanged
  as the next normal route; `VolumeProfile.Add(...)` is rejected for injected
  component mounting. Next work should avoid `VolumeProfile.Add(...)` (for
  example by investigating `VolumeManager` / `VolumeStack` default-component
  extension) or move to another official-boundary-equivalent route.
- 2026-06-07 IL2CPP/HDRP decompilation follow-up is recorded in
  `docs/development/vrising-il2cpp-hdrp-postprocess-decompilation-2026-06-07.md`.
  Local BepInEx/Cpp2IL interop wrappers and xref caches were inspected without
  copying decompiled game bodies into the repository. The game exposes concrete
  ProjectM HDRP custom postprocess types including `CustomVignette`,
  `LineOfSightVision`, `LineOfSight`, `BatFormFog`, `DarkForeground`, and
  `ProjectM.ContestAreaEffect`; their concrete `Render(CommandBuffer, HDCamera,
  RTHandle, RTHandle)` methods call normal postprocess operations such as
  `Material.Set*`, `RTHandle.op_Implicit`, and `HDUtils.DrawFullScreen`, proving
  they are real existing HDRP postprocess render boundaries. Their direct
  caller refs are empty, consistent with HDRP virtual/custom-postprocess pass
  dispatch, so do not assume patching only
  `CustomPostProcessVolumeComponent.Render` will catch the overrides. Local HDRP
  xref order shows `RenderPostProcess` reaches `DoDLSSPasses` at five sites,
  calls `CustomPostProcessPass` for before-TAA, before-postprocess,
  after-postprocess-blurs, and after-postprocess lists, and reaches
  `FinalPass`. `DoDLSSPass` xrefs include `RenderGraph.AddRenderPass`,
  `ReadTexture`, `GetPostprocessOutputHandle`, `AddResourceWrite`,
  `DLSSPass.CreateCameraResources`, and `SetRenderFunc`, reinforcing that the
  official DLSS path is a narrow RenderGraph pass boundary rather than broad
  `GetTexture` discovery. Next minimal route should be a default-off,
  no-native/no-DLSS `hdrp-postprocess-boundary-probe` over
  `RenderPostProcess`, `DoDLSSPasses`, `DoDLSSPass`, `CustomPostProcessPass`,
  and the concrete ProjectM custom postprocess `Render(...)` methods.
- The default-off no-native `hdrp-postprocess-boundary` preflight is now
  implemented and statically validated; see
  `docs/development/hdrp-postprocess-boundary-preflight-implementation-2026-06-07.md`.
  Config key: `Diagnostics.EnableHdrpPostProcessBoundaryProbe=false`. Helper
  stage: `hdrp-postprocess-boundary`. The first implementation installed sparse
  Harmony prefixes on `HDRenderPipeline.RenderPostProcess`, `DoDLSSPasses`,
  `DoDLSSPass`, `CustomPostProcessPass`, and the concrete ProjectM custom
  postprocess `Render(...)` methods identified by local IL2CPP/xref analysis.
  It only logs boundary hits; it does not create a Volume, call `GetTexture`,
  resolve resources, read native texture pointers, issue command-buffer work,
  load the native bridge, initialize NGX, or evaluate DLSS. Static Release
  build, PowerShell parser validation, dry-run config validation,
  release-boundary check, and `git diff --check` passed. Menu runtime r1
  `hdrp-postprocess-boundary-1080p-menu-20260607-r1` patched all 10 initial
  target methods but crashed before any `call #` line with WER `0xc0000005` in
  `coreclr.dll`; no `GetTexture`, D3D11/NGX/DLSS/evaluate lines appeared. The
  prefix was narrowed from `__instance`/`__args` logging to `__originalMethod`
  only, but r2 `hdrp-postprocess-boundary-1080p-menu-20260607-r2` still
  reproduced the same coreclr crash after patching all 10 targets and before
  any `call #`. Decision: reject unchanged all-target direct Harmony patching
  for this probe. Keep official `HDRenderPipeline.RenderPostProcess ->
  DoDLSSPasses -> DoDLSSPass` as static xref/source evidence only for now. The
  active implementation is narrowed to the six ProjectM concrete custom
  postprocess `Render(...)` overrides only. Menu runtime r3
  `hdrp-postprocess-boundary-1080p-menu-20260607-r3` was stable at true
  `1920x1080` Windowed: `CrashEventCount=0`, `ExitedBeforeWindow=False`,
  `ClosedByScript=True`, patched ProjectM methods `6`, `HDRP postprocess
  boundary probe call #=0`, `RenderGraph GetTexture call #=0`,
  D3D11/NGX/DLSS/evaluate patterns `0`, and cleanup restored loader config,
  release-safe native, and `ClientSettings.json` with no V Rising process left.
  The result is a stable partial: ProjectM-only patching is safe in the menu,
  but the menu did not invoke those renders. See
  `docs/development/hdrp-postprocess-boundary-menu-result-2026-06-07.md`.
  Protected gameplay proof
  `hdrp-postprocess-boundary-gameplay-1080p-20260607-r1` then passed in the
  `11111` fixture at true `1920x1080` Windowed. Computer Use selected the real
  `VRising` Unity window, clicked the known Chinese Continue / `11111` entry
  once at `(205,354)`, waited about `45` seconds, and sent no keyboard or
  movement input. Gameplay screenshot showed HUD, quest text, character,
  health/action bar, and minimap. Analyzer reported
  `HDRP PostProcess Boundary=Pass`; the log patched `6` ProjectM concrete
  `Render(...)` overrides and recorded `29` sampled call lines from
  `DarkForeground.Render(CommandBuffer cmd, HDCamera camera, RTHandle source,
  RTHandle destination) -> Void`, with the highest sampled call number `6300`.
  `RenderGraph GetTexture call #`, D3D11, NGX, DLSS/evaluate, prefix failure,
  patch failure, exception, and error counts were all `0`.
  `CrashEventCount=0`; cleanup restored loader config, ClientSettings, and the
  release-safe native DLL; no V Rising process remained. Gameplay entry added
  one autosave before restore, the changed state was archived, and the
  protected `11111` save was restored with `ChangeCount=0`. See
  `docs/development/hdrp-postprocess-boundary-gameplay-result-2026-06-07.md`.
  Decision: promote `DarkForeground.Render(...)` to a gameplay-proven
  BepInEx/Harmony-accessible HDRP custom postprocess command-buffer boundary.
  Next step should be a separate default-off no-native resource-argument
  snapshot from this boundary, not direct DLSS evaluate and not broad
  steady-state `GetTexture` discovery.
- The separate default-off no-native `hdrp-postprocess-render-args` probe is
  now implemented and protected-gameplay validated; see
  `docs/development/hdrp-postprocess-render-args-preflight-implementation-2026-06-07.md`
  and
  `docs/development/hdrp-postprocess-render-args-gameplay-result-2026-06-07.md`.
  Config key: `Diagnostics.EnableHdrpPostProcessRenderArgsProbe=false`.
  Helper stage: `hdrp-postprocess-render-args`. It patches only
  `DarkForeground.Render(CommandBuffer, HDCamera, RTHandle, RTHandle)` and
  logs sparse managed `cmd/camera/source/destination` snapshots; it does not
  call `GetTexture`, read native texture pointers, do command-buffer work, load
  NGX, or evaluate DLSS. Static Release build, PowerShell parser validation,
  dry-run config, `git diff --check`, release-boundary check, Thunderstore
  package creation, and package validation passed. Protected gameplay proof
  `hdrp-postprocess-render-args-gameplay-1080p-20260607-r1` passed in the
  `11111` fixture at true `1920x1080` Windowed. Computer Use selected the real
  `VRising` Unity window, clicked the Chinese Continue / `11111` entry once at
  `(205,354)`, waited about `45` seconds, and sent no keyboard/movement input.
  Analyzer reported `HDRP PostProcess Render Args=Pass`; the log patched `1`
  method and recorded `9` snapshots. Counts for `RenderGraph GetTexture`,
  D3D11, NGX, DLSS/evaluate, prefix failure, and patch failure were all `0`.
  Cleanup reported `CrashEventCount=0`, restored loader config,
  ClientSettings, and release-safe native DLL, and left no V Rising process.
  Gameplay entry added one save difference before restore; the changed state
  was archived and the protected save was restored with `ChangeCount=0`. The
  first snapshot showed `camera.actualWidth=1920`,
  `camera.actualHeight=1080`, `camera.allowDynamicResolution=False`,
  `source=CameraColor` / `CameraColor_1920x1080_B10G11R11_UFloatPack32_Tex2DArray`,
  and `destination=CustomPostProcesDestination` /
  `CustomPostProcesDestination_1920x1080_B10G11R11_UFloatPack32_Tex2DArray_dynamic`.
  Decision: keep this as a clean source-driven boundary, but do not treat it as
  a DLSS Super Resolution tuple yet because current evidence is full-res
  `1920x1080 -> 1920x1080`. Next separate guard should prove whether the same
  boundary can observe dynamic-resolution render input state before any native
  pointer or DLSS evaluate step.
- Follow-up combined stage `hdrp-postprocess-render-args-render-scale` is now
  implemented and gameplay-validated; see
  `docs/development/hdrp-postprocess-render-args-render-scale-gameplay-result-2026-06-07.md`.
  The stage enables only `EnableHdrpPostProcessRenderArgsProbe=true` and
  `EnableRenderScaleControlProbe=true` while leaving `GetTexture`, D3D11, NGX,
  DLSS evaluate, broad hook scan, and native bridge work disabled. With V Rising
  `FsrQualityMode=Off`, true `1920x1080` Windowed, and the protected `11111`
  fixture, analyzer reported both `Stage 2C Render-Scale Control Probe=Pass`
  and `HDRP PostProcess Render Args=Pass`. The log recorded `9`
  `DarkForeground.Render(...)` argument snapshots, `557` render-scale
  prefix/postfix lines, `31` `GetCurrentScale=0.5` lines, and `31`
  `GetResolvedScale=(0.50, 0.50)` lines. The first snapshot showed
  `camera.actualWidth=960`, `camera.actualHeight=540`,
  `camera.pixelWidth=1920`, `camera.pixelHeight=1080`,
  `source=CameraColor_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic`, and
  `destination=CustomPostProcesDestination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic`.
  Counts for `RenderGraph GetTexture`, D3D11, NGX, DLSS/evaluate, prefix
  failure, and patch failure were all `0`. Cleanup passed with
  `CrashEventCount=0`, no V Rising process left, loader/config/native restored,
  and protected save restore `ChangeCount=0`. Passive
  `capture-vrising-window.ps1` produced a valid 1920x1080 gameplay screenshot
  because Computer Use captured the wrong Codex window after loading despite
  reacquiring the `VRising` handle. Decision: this boundary can provide
  low-resolution render-space color under mod-owned dynamic resolution, but it
  does not by itself provide a full-size DLSS output target because both source
  and destination were `960x540`, not `960x540 -> 1920x1080`. Next guard should
  locate a full-size output target in the same frame/lifecycle or prove a safe
  handoff to the existing full-size EASU/output RenderGraph resource path.
- Follow-up script-only stage `native-renderfunc-resource-tuple-render-scale`
  is implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-resource-tuple-render-scale-gameplay-result-2026-06-07.md`.
  The stage combines the previously proven focused EASU native render-func
  tuple path with `RenderScaleControlProbe`, while leaving broad
  `RenderGraph.GetTexture`, D3D11 validation, NGX/DLSS evaluate, command-buffer
  work, and broad hook scan disabled. With V Rising `FsrQualityMode=Off`, true
  `1920x1080` Windowed, and the protected `11111` fixture, analyzer reported
  `Native RenderFunc Resource Tuple=Pass` and
  `Stage 2C Render-Scale Control Probe=Pass`. The first tuple advanced line at
  `compile=4` matched native and managed EASU pass data
  (`passDataMatches=True`, `tupleReady=True`) and reported
  `tuple=input=960x540; output=1920x1080`; the final sampled status reached
  `#8400` with the same shape. Counts: `tuple=input=960x540;
  output=1920x1080` `109`, `1920x1080 -> 1920x1080` `0`, `960x540 ->
  960x540` `0`, `GetCurrentScale=0.5` `31`, `GetResolvedScale=(0.50, 0.50)`
  `31`, `RenderGraph GetTexture` `0`, D3D11/NGX/DLSS/evaluate patterns `0`,
  failure/access-violation patterns `0`, `CrashEventCount=0`. Cleanup restored
  loader config, ClientSettings, release-safe native state, left no V Rising
  process, and restored the protected save with `ChangeCount=0`. This is now
  the preferred official-boundary-adjacent locator for SR sizing: next work
  should focus on a separate EASU source/destination resource-resolution or
  native-pointer guard, not another broad `GetTexture` route or immediate DLSS
  evaluate.
- Follow-up script-only stage `native-renderfunc-resource-resolve-render-scale`
  is implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-resource-resolve-render-scale-gameplay-result-2026-06-07.md`.
  The stage combines the focused EASU `TextureResource` metadata resolve path
  with `RenderScaleControlProbe`, while leaving broad `GetTexture`, actual
  native texture pointer reads, D3D11 validation, NGX/DLSS evaluate,
  command-buffer work, and broad hook scan disabled. With V Rising
  `FsrQualityMode=Off`, true `1920x1080` Windowed, and the protected `11111`
  fixture, analyzer reported `Native RenderFunc Resource Resolve=Pass` and
  `Stage 2C Render-Scale Control Probe=Pass`. The first resolve advanced line
  at `compile=4` matched native and managed EASU pass data and reported
  `tuple=input=960x540; output=1920x1080`, `resourceReady=True`,
  `textureResourceReady=True`, and `graphicsReady=False`; final status reached
  `#8100` with the same shape. Counts: `tuple=input=960x540;
  output=1920x1080` `216`, same-size tuple `0`, `resourceReady=True` `104`,
  `textureResourceReady=True` `104`, `graphicsReady=True` `0`,
  `GetCurrentScale=0.5` `31`, `GetResolvedScale=(0.50, 0.50)` `31`,
  `RenderGraph GetTexture` `0`, actual native texture pointer read patterns
  `0`, D3D11/NGX/DLSS/evaluate patterns `0`, resolve failure/access-violation
  patterns `0`, `CrashEventCount=0`. Cleanup restored loader config,
  ClientSettings, release-safe native state, left no V Rising process, and
  restored the protected save with `ChangeCount=0`. This proves metadata
  resolution for the proven SR-sized EASU handles; next work should be a
  separately guarded focused EASU native-pointer observation under render
  scale, still without command-buffer work, D3D11 validation, or DLSS evaluate
  in the same step.
- Follow-up script-only stage
  `native-renderfunc-resource-native-pointer-render-scale` is implemented and
  protected-gameplay validated; see
  `docs/development/native-renderfunc-resource-native-pointer-render-scale-gameplay-result-2026-06-07.md`.
  The stage combines focused EASU native-pointer observation with
  `RenderScaleControlProbe`, while leaving broad `RenderGraph.GetTexture`
  logging, D3D11 validation, NGX/DLSS evaluate, command-buffer work, broad hook
  scan, and real DLSS disabled. With V Rising `FsrQualityMode=Off`, true
  `1920x1080` Windowed, and the protected `11111` fixture, analyzer reported
  `Native RenderFunc Resource Native Pointer=Pass` and
  `Stage 2C Render-Scale Control Probe=Pass`. The advanced line at
  `targetCompile=4` showed EASU `tuple=input=960x540; output=1920x1080`;
  source handle `76` returned non-zero `nativePtr=0x21EA3F0B420` for
  `RTHandle name=Uber Post Destination` / Unity texture
  `Apply Exposure Destination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic`;
  destination handle `77` returned non-zero `nativePtr=0x21EA3F111A0` for
  `RTHandle name=Edge Adaptive Spatial Upsampling` / Unity texture
  `Edge Adaptive Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32_Tex2DArray`.
  Counts: target armed `1`, advanced `1`, native-pointer status lines `4`,
  `tuple=input=960x540; output=1920x1080` `229`, same-size tuple `0`,
  `GetCurrentScale=0.5` `31`, `GetResolvedScale=(0.50, 0.50)` `31`, broad
  `RenderGraph GetTexture call #` `0`, D3D11/NGX/DLSS/evaluate runtime lines
  `0`, source/destination zero-pointer patterns `0`, failure/access-violation
  patterns `0`, `CrashEventCount=0`. Cleanup restored loader config,
  ClientSettings, release-safe native state, left no V Rising process, and
  restored the protected save with `ChangeCount=0`. This is the strongest
  current official-boundary-adjacent resource proof: under mod-owned render
  scale, the EASU pass has both a low-resolution source native texture pointer
  and a full-resolution output native texture pointer. It still does not prove
  command-buffer ordering, D3D11 device compatibility, NGX lifecycle, or DLSS
  output correctness. The next route should be source/decompilation-guided:
  inspect local IL2CPP/HDRP code around `HDRenderPipeline.EASUData`, the EASU
  render func, `DoDLSSPasses`, `DoDLSSPass`, and
  `DLSSPass.Render/ExecuteDLSS` before adding any D3D11/device/dimension or
  command-buffer guard.
- Source/decompilation-guided investigation has started; see
  `docs/research/vrising-il2cpp-hdrp-decompilation-kickoff-2026-06-07.md`.
  Local ILSpy over V Rising's BepInEx interop confirms the concrete IL2CPP
  symbols and tokens that match the current runtime evidence:
  `HDRenderPipeline.RenderPostProcess` token `100663789`,
  `DoDLSSPasses` `100663792`, `DoDLSSPass` `100663793`,
  `EdgeAdaptiveSpatialUpsampling` `100663869`, `FinalPass` `100663870`,
  `_DoDLSSPass_b__969_0(DLSSData, RenderGraphContext)` `100664365`,
  `_EdgeAdaptiveSpatialUpsampling_b__1066_0(EASUData, RenderGraphContext)`
  `100664389`, and `_FinalPass_b__1069_0` `100664390`. `DLSSPass` also
  exposes `GetViewResources`, `CreateCameraResources`, `GetCameraResources`,
  `SetupFeature`, `BeginFrame`, `SetupDRSScaling`, and `Render(...)` tokens.
  Upstream HDRP 2022.3 source aligns with those names: EASU reads the current
  postprocess source and writes `GetPostprocessUpsampledOutputHandle(...,
  "Edge Adaptive Spatial Upsampling")`; official DLSS reads
  source/depth/motion vectors, writes `GetPostprocessUpsampledOutputHandle(...,
  "DLSS destination")`, then calls
  `DLSSPass.GetCameraResources(data.resourceHandles)` immediately before
  `DLSSPass.Render(..., ctx.cmd)`. Do not commit or package full generated
  interop decompilation output; keep it local under `ref/` and commit only
  derived notes. The conservative next guard is focused D3D11/device/dimension
  validation for the proven EASU native pointers before any command-buffer or
  DLSS evaluate experiment.
- Follow-up stage `native-renderfunc-resource-d3d11-render-scale` is
  implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-resource-d3d11-render-scale-gameplay-result-2026-06-07.md`.
  The stage reuses the proven EASU native-pointer target and validates only the
  focused source/destination D3D11 texture pair/device/dimensions while keeping
  broad `RenderGraph.GetTexture`, command-buffer access, NGX, DLSS runtime, and
  DLSS evaluate disabled. With V Rising `FsrQualityMode=Off`, true
  `1920x1080` Windowed, and the protected `11111` fixture, analyzer reported
  `Native RenderFunc Resource D3D11=Pass`, `Native RenderFunc Resource Native
  Pointer=Pass`, `Native RenderFunc Resource Tuple=Pass`, `Stage 2C
  Render-Scale Control Probe=Pass`, and `Native bridge API version: 13`.
  The single D3D11 advanced line showed source handle `76` native pointer
  `0x1A4A4B2DD20`, Unity texture `Apply Exposure
  Destination_960x540_B10G11R11_UFloatPack32_Tex2DArray_dynamic`, destination
  handle `77` native pointer `0x1A4A4B30660`, Unity texture `Edge Adaptive
  Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32_Tex2DArray`,
  `tuple=input=960x540; output=1920x1080`, and native status `sameDevice=yes;
  source=960x540 fmt=26 mips=1 array=1; destination=1920x1080 fmt=26 mips=1
  array=1; scale=(2.000x,2.000x)`. Counts: D3D11 advanced `1`, D3D11 failures
  `0`, native-pointer advanced `1`, low-to-full tuple `268`, same-size tuple
  `0`, gameplay camera `actualWidth=960,actualHeight=540` `486`,
  `GetCurrentScale=0.5` `31`, `GetResolvedScale=(0.50, 0.50)` `31`, broad
  `RenderGraph GetTexture call #` `0`, `ExecuteDLSS` `0`, `NGX` / `nvngx` `0`,
  DLSS evaluate success patterns `0`, `CrashEventCount=0`. Cleanup restored
  loader config, ClientSettings, release-safe native state, left no V Rising
  process, and restored the protected save with `ChangeCount=0`. This proves
  same-device D3D11 resource compatibility for the official-boundary-adjacent
  EASU source/output pair, but still does not prove command-buffer timing,
  NGX feature lifecycle, resize/reset handling, visual correctness, or
  performance. The next guard should move source/decompilation-guided toward an
  equivalent of `DoDLSSPass -> DLSSPass.GetCameraResources ->
  DLSSPass.Render(..., ctx.cmd)`, with command-buffer access tested separately
  before any real DLSS evaluate.
- Follow-up stage `native-renderfunc-context-render-scale` is implemented and
  protected-gameplay validated; see
  `docs/development/native-renderfunc-context-render-scale-gameplay-result-2026-06-07.md`.
  The stage reuses the focused EASU entry/argument/resource tuple proof, wraps
  only the raw EASU `RenderGraphContext` pointer, and reads `ctx.cmd` identity.
  It does not issue command-buffer work, resolve textures through broad
  `GetTexture`, validate D3D11 resources, load NGX, or evaluate DLSS. With V
  Rising `FsrQualityMode=Off`, true `1920x1080` Windowed, and mod-owned render
  scale, analyzer reported `Native RenderFunc Context=Pass`, `Stage 2C
  Render-Scale Control Probe=Pass`, `Native RenderFunc Resource Tuple=Pass`,
  and `Native bridge API version: 13`. The advanced context line showed
  `sampleCount=1`, `nonzeroContext=1`, `wrapSuccess=1`, `cmdNonNull=1`,
  `cmdPointerNonZero=1`, `wrapFailures=0`, `lastCmd=0x204BEF85EC0`, and
  `cmd="UnityEngine.Rendering.CommandBuffer name="` for `Edge Adaptive Spatial
  Upsampling`. The final sampled status reached `entryCount=6699`,
  `sampleCount=6699`, `cmdPointerNonZero=6699`, and `wrapFailures=0`. Counts:
  context advanced `1`, context status `141`, broad `RenderGraph GetTexture
  call #` `0`, native-pointer `0`, D3D11 `0`, `ExecuteDLSS` `0`, `NGX` `0`,
  `DLSS user rendering` `0`, entry/detour failures `0`, crash patterns `0`.
  Cleanup restored loader config, ClientSettings, release-safe native state,
  left no V Rising process, and restored the protected save with
  `ChangeCount=0`. This proves a live `RenderGraphContext.cmd` identity is
  safely reachable at the source-guided EASU boundary, but still does not prove
  command-buffer work/plugin-event ordering, NGX feature lifecycle, DLSS
  evaluate, resize/reset handling, visual correctness, or performance. The next
  guard should be a separate no-op command-buffer/plugin-event timing proof at
  this same boundary, still without DLSS evaluate.
- Follow-up stage `native-renderfunc-commandbuffer-event-render-scale` is
  implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-event-render-scale-gameplay-result-2026-06-07.md`.
  The stage reuses the focused EASU entry/context/tuple proof, issues one
  native no-op plugin event through the live `RenderGraphContext.cmd`, and
  verifies that the native render-event callback count advances to
  `lastEventId=260607`. It does not pass texture resources through the event,
  validate D3D11 resources, load NGX, evaluate DLSS, or write visible output.
  Menu smoke passed first with `Native RenderFunc CommandBuffer Event=Pass`,
  event count `0 -> 1`, `issueFailures=0`, broad `RenderGraph.GetTexture` `0`,
  native-pointer/D3D11/NGX/DLSS/evaluate patterns `0`, and
  `CrashEventCount=0`. Protected gameplay proof then passed with V Rising
  `FsrQualityMode=Off`, true `1920x1080` Windowed, and the protected `11111`
  fixture. Analyzer reported `Stage 2C Render-Scale Control Probe=Pass`,
  `Native RenderFunc Context=Pass`, `Native RenderFunc CommandBuffer
  Event=Pass`, `Native RenderFunc Resource Tuple=Pass`, and native bridge API
  version `13`. Key evidence preserved the EASU
  `tuple=input=960x540; output=1920x1080`, read
  `lastCmd=0x243BCB10E40`, issued `eventId=260607`, and reached final status
  `callbackReached=True`, `issueAttempts=1`, `issueSuccesses=1`,
  `issueFailures=0`, `currentCount=1`, `lastEventId=260607`. Counts:
  command-buffer event advanced `1`, status lines `142`, broad
  `RenderGraph.GetTexture` `0`, native-pointer/D3D11/NGX/DLSS/evaluate
  patterns `0`, native entry/detour failures `0`, crash patterns `0`.
  Cleanup restored loader config, ClientSettings, release-safe native state,
  left no V Rising process, and restored the protected save with
  `ChangeCount=0`. This proves command-buffer/plugin-event timing at the
  official-boundary-adjacent EASU execution window, but still does not prove
  texture payload handoff, NGX lifecycle, DLSS evaluate, resize/reset behavior,
  visible correctness, or performance. The next route should use local
  IL2CPP/HDRP decompilation/static xrefs as the primary map, then add a
  separately gated native callback payload/lifecycle proof at this same
  boundary.
- Follow-up stage `native-renderfunc-commandbuffer-payload-render-scale` is
  implemented and menu plus protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-payload-render-scale-gameplay-result-2026-06-07.md`.
  Native bridge API version is now `14`. The stage uses the focused EASU
  source/destination native texture pointer observations as a short-lived
  native pending payload, then consumes that payload from one `ctx.cmd` plugin
  event with `eventId=260608`. It keeps broad `RenderGraph.GetTexture`
  diagnostic logging, the separate D3D11 pair probe, NGX, DLSS evaluate,
  user-rendering, and visible write-back disabled. Menu smoke passed first:
  `Native RenderFunc CommandBuffer Payload=Pass`, payload set `1`, event issue
  `1`, consumed `1`, same-device `source=960x540` and
  `destination=1920x1080`, payload failures `0`, broad GetTexture `0`,
  `ExecuteDLSS`/`nvngx`/user-rendering `0`, and `CrashEventCount=0`.
  Protected gameplay proof then passed with V Rising `FsrQualityMode=Off`, true
  `1920x1080` Windowed, and the protected `11111` fixture. Computer Use clicked
  Continue once and sent no keyboard/movement input. Analyzer reported
  `Stage 2C Render-Scale Control Probe=Pass`, `Native RenderFunc
  Context=Pass`, `Native RenderFunc CommandBuffer Payload=Pass`, `Native
  RenderFunc Resource Tuple=Pass`, and `Native RenderFunc Resource Native
  Pointer=Pass`. Key evidence preserved the EASU
  `tuple=input=960x540; output=1920x1080`, set pending payload pointers
  `sourcePtr=000002CC1D734C20` and `destinationPtr=000002CC1D7385E0`, then
  consumed them from native callback status `sameDevice=yes; source=960x540
  fmt=26; destination=1920x1080 fmt=26; scale=(2.000x,2.000x)`. Counts:
  payload advanced `1`, payload set advanced `1`, payload status lines `121`,
  payload set/event/consume failures `0`, broad `RenderGraph.GetTexture` `0`,
  separate native D3D11 pair probe `0`, `ExecuteDLSS` `0`, `nvngx` `0`,
  `DLSS user rendering` `0`, crash/access-violation patterns `0`.
  Cleanup restored loader config, ClientSettings, release-safe native state,
  left no V Rising process, and restored the protected save with
  `ChangeCount=0`. This links resource pointer identity with command-buffer
  callback timing at the official-boundary-adjacent EASU window. It still does
  not prove depth/motion-vector payload, NGX feature lifecycle, DLSS evaluate,
  resize/reset behavior, visual correctness, or performance. The next route
  should stay source/decompilation-guided: either find/verify depth and motion
  vector payloads at an equivalent official boundary, or add a local
  SDK-wrapper-only DLSS frame-sequence lifecycle preflight at this exact
  callback boundary before any visible write-back.
- Follow-up stage `native-renderfunc-commandbuffer-dlss-create-render-scale` is
  implemented and menu plus protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-dlss-create-render-scale-gameplay-result-2026-06-07.md`.
  Native bridge API version is now `15`. The stage uses the focused EASU
  source/destination native texture payload and consumes it from one `ctx.cmd`
  plugin event with `eventId=260609`, then creates and immediately
  releases/destroys/shuts down one NGX DLSS feature through the SDK-wrapper
  path. It still does not evaluate DLSS or write visible output. Menu smoke
  passed with `Native RenderFunc CommandBuffer DLSS Feature Create=Pass`,
  `create=0x00000001`, `feature=yes`, `release=0x00000001`,
  `destroy=0x00000001`, `shutdown=0x00000001`, `ExecuteDLSS` `0`, user
  rendering `0`, visible write-back `0`, and no crash patterns. Protected
  gameplay proof then passed with V Rising `FsrQualityMode=Off`, true
  `1920x1080` Windowed, mod-owned render scale, and the protected `11111`
  fixture. Computer Use clicked Continue once and sent no movement keys.
  Analyzer reported `Stage 2C Render-Scale Control Probe=Pass`, `Native
  RenderFunc Context=Pass`, `Native RenderFunc CommandBuffer DLSS Feature
  Create=Pass`, `Native RenderFunc Resource Tuple=Pass`, and `Native RenderFunc
  Resource Native Pointer=Pass`. Key evidence preserved `actualWidth=960`,
  `actualHeight=540`, `GetCurrentScale=0.5`, `GetResolvedScale=(0.50, 0.50)`,
  `sameDevice=yes`, `source=960x540 fmt=26`, `destination=1920x1080 fmt=26`,
  `scale=(2.000x,2.000x)`, `create=0x00000001`, `feature=yes`,
  `release=0x00000001`, `destroy=0x00000001`, and
  `shutdown=0x00000001`. Counts: feature-create advanced `1`, set advanced
  `1`, consumed-status lines `111`, broad `RenderGraph.GetTexture` `0`,
  `ExecuteDLSS` `0`, `DLSS user rendering` `0`, visible write-back `0`, and
  crash/exception/access-violation patterns `0`. Cleanup restored
  config/native/ClientSettings, left no game process, and restored the
  protected save with `ChangeCount=0`. The next route remains
  source/decompilation-guided: either add depth/motion-vector payloads at an
  equivalent official boundary or design a bounded no-write evaluate preflight;
  do not return to broad `GetTexture` discovery or direct `DLSSPass.Render`
  patching.
- Follow-up stage `hdrp-postprocess-render-args-global-textures-render-scale`
  is implemented and protected-gameplay validated; see
  `docs/development/hdrp-postprocess-render-args-global-textures-render-scale-gameplay-result-2026-06-07.md`.
  It adds default-off
  `Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe=false`. The
  probe still patches only
  `DarkForeground.Render(CommandBuffer, HDCamera, RTHandle, RTHandle)`, but when
  enabled it reads `Shader.GetGlobalTexture("_CameraDepthTexture")` and
  `Shader.GetGlobalTexture("_CameraMotionVectorsTexture")` plus native pointers.
  It does not use RenderGraph `GetTexture`, D3D11 validation, command-buffer
  plugin events, NGX, DLSS evaluate, or visible write-back. Protected gameplay
  proof passed with V Rising `FsrQualityMode=Off`, true `1920x1080` Windowed,
  mod-owned render scale, and the protected `11111` fixture. Computer Use
  clicked Continue once and sent no movement keys. Analyzer reported `Stage 2C
  Render-Scale Control Probe=Pass`, `HDRP PostProcess Render Args=Pass`, and
  `HDRP PostProcess Render Args Global Textures=Pass`. Key evidence:
  `camera.actualWidth=960`, `actualHeight=540`, source
  `CameraColor_960x540`, destination `CustomPostProcesDestination_960x540`,
  `_CameraMotionVectorsTexture=Motion Vectors_960x540` with native pointer, and
  depth stabilizing to `CameraDepthStencil_960x540` with native pointer.
  Counts: snapshots `9`, global advanced `1`, depth null `0`, motion null `0`,
  broad `RenderGraph.GetTexture` `0`, D3D11 `0`, NGX `0`, actual DLSS
  evaluate/writeback `0`, crash/access-violation patterns `0`. Cleanup restored
  config/native/ClientSettings, left no game process, and restored the
  protected save with `ChangeCount=0`. This solves the low-resolution
  color/depth/motion visibility question at a gameplay-proven HDRP/ProjectM
  boundary, but output at that boundary remains `960x540`; the next guard should
  correlate this input side with the already proven EASU/native render-func
  `1920x1080` output side before no-write evaluate or visible-output work.
- Follow-up stage `hdrp-easu-input-output-correlation-render-scale` is now
  implemented and protected-gameplay validated; see
  `docs/development/hdrp-easu-input-output-correlation-preflight-implementation-2026-06-07.md`.
  It adds a shared correlation state between `HdrpPostProcessRenderArgsProbe`
  and `FrameResourceProbe`. HDRP records the latest `DarkForeground.Render`
  input snapshot only after global depth and motion native pointers are both
  non-zero; EASU records the focused source/destination native-pointer
  observation when both pointers are available. The pass line is
  `HDRP/EASU input-output correlation advanced:` and requires HDRP camera/color
  to match the EASU input dimensions, HDRP depth/motion to contain the same
  input dimensions, the EASU tuple to upscale to a larger output, and HDRP/EASU
  `Time.frameCount` deltas to stay within five frames. The stage enables
  render-scale control plus focused EASU native-pointer observation, but keeps
  D3D11 validation, command-buffer plugin events, NGX feature lifecycle, DLSS
  evaluate, user rendering, and visible write-back disabled.
- Runtime iteration `hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r1`
  was Partial: stale EASU frame `4` could not correlate with first HDRP frame
  `5281`. `r2` initially looked like a pass but manual evidence review caught a
  false-positive: stale EASU tuple handles had later resolved to `CoC/Bloom`
  `60x34` resources. The analyzer and code were tightened so pass requires
  actual EASU source observation matching input dimensions and actual EASU
  destination observation matching output dimensions, and the focused EASU
  target may re-arm on later compiles while correlation is pending.
- Protected gameplay proof `hdrp-easu-input-output-correlation-render-scale-gameplay-1080p-20260607-r3`
  passed; see
  `docs/development/hdrp-easu-input-output-correlation-render-scale-gameplay-result-2026-06-07.md`.
  Key evidence: `hdrpFrame=3005`, `easuSourceFrame=3005`,
  `easuDestinationFrame=3005`, frame deltas `0`, HDRP
  `CameraColor_960x540`, `CameraDepthStencil_960x540`, `Motion Vectors_960x540`,
  EASU source `TAA Destination_960x540`, EASU destination
  `Edge Adaptive Spatial Upsampling_1920x1080`, tuple
  `input=960x540; output=1920x1080`, D3D11 pair `0`, command-buffer event/payload
  `0`, NGX `0`, `ExecuteDLSS` `0`, visible write-back `0`,
  `CrashEventCount=0`, and save restore `ChangeCount=0`. Next guard: build a
  no-evaluate native payload descriptor carrying EASU color/output plus HDRP
  depth/motion pointers toward the already-proven EASU `ctx.cmd` boundary, still
  without combining D3D11 validation, NGX lifecycle, or DLSS evaluate.
- Follow-up stage `native-renderfunc-commandbuffer-frame-descriptor-render-scale`
  is now implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-frame-descriptor-render-scale-preflight-implementation-2026-06-07.md`
  and
  `docs/development/native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-result-2026-06-07.md`.
  It adds default-off
  `Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe=false`.
  The stage reuses the source/decompilation-guided HDRP/EASU correlation,
  carries EASU source/output plus HDRP depth/motion native pointers through one
  focused EASU `RenderGraphContext.cmd` plugin event, and records descriptor
  metadata only. Native bridge API version is now `16`. Protected gameplay proof
  `native-renderfunc-commandbuffer-frame-descriptor-render-scale-gameplay-1080p-20260607-r1`
  passed at true `1920x1080` Windowed with V Rising `FsrQualityMode=Off`,
  mod-owned render scale, and the protected `11111` fixture. Computer Use
  clicked Continue once and sent no movement keys. Analyzer reported `Native
  RenderFunc CommandBuffer Frame Descriptor=Pass`, `HDRP/EASU Input Output
  Correlation=Pass`, `HDRP PostProcess Render Args Global Textures=Pass`,
  `Native RenderFunc Context=Pass`, `Native RenderFunc Resource Tuple=Pass`,
  and `Native RenderFunc Resource Native Pointer=Pass`. Key evidence preserved
  same-frame `hdrpFrame=4110`, `easuSourceFrame=4110`,
  `easuDestinationFrame=4110`, descriptor source/destination/depth/motion
  pointers, `input=960x540`, `output=1920x1080`, `eventId=260610`,
  `consumed=1`, `validation=D3D11-not-queried`, `ngx=not-loaded`, and
  `evaluate=not-run`. Counts: descriptor advanced `1`, descriptor set advanced
  `1`, D3D11 pair advanced/failed `0`, broad `RenderGraph.GetTexture` `0`,
  `ExecuteDLSS` `0`, `DLSS user rendering` `0`, actual visible write-back `0`,
  crash/access-violation `0`, and save restore `ChangeCount=0`. The next guard
  should be separate D3D11/SR input validation for this four-resource descriptor
  or a bounded no-write evaluate preflight at the same callback, not a return to
  broad steady-state `GetTexture` discovery.
- Follow-up stage
  `native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale` is now
  implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-preflight-implementation-2026-06-07.md`
  and
  `docs/development/native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-result-2026-06-07.md`.
  It adds default-off
  `Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe=false`.
  Native bridge API version is now `17`. The stage reuses the source-guided
  HDRP/EASU correlation, carries EASU source/output plus HDRP depth/motion
  native pointers through one focused EASU `RenderGraphContext.cmd` plugin
  event with `eventId=260611`, and validates only D3D11 resource/device/
  dimension shape. Protected gameplay proof
  `native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale-gameplay-1080p-20260607-r1`
  passed at true `1920x1080` Windowed with V Rising `FsrQualityMode=Off`,
  mod-owned render scale, and the protected `11111` fixture. Computer Use
  clicked Continue once and sent no movement keys. Analyzer reported `Native
  RenderFunc CommandBuffer Frame Descriptor D3D11=Pass`, `HDRP/EASU Input
  Output Correlation=Pass`, `HDRP PostProcess Render Args Global Textures=Pass`,
  `Native RenderFunc Context=Pass`, `Native RenderFunc Resource Tuple=Pass`,
  and `Native RenderFunc Resource Native Pointer=Pass`. Key evidence preserved
  same-frame `hdrpFrame=3675`, `easuSourceFrame=3675`,
  `easuDestinationFrame=3675`, `input=960x540`, `output=1920x1080`,
  `validation=D3D11-succeeded`, `sameDevice=yes`, source/depth/motion at
  `960x540`, destination at `1920x1080`, `scale=(2.000x,2.000x)`,
  `ngx=not-loaded`, and `evaluate=not-run`. Counts: D3D11 descriptor advanced
  `1`, set advanced `1`, consumed-status lines `22`, D3D11 validation failures
  `0`, `ExecuteDLSS` `0`, `DLSS user rendering` `0`, actual visible write-back
  `0`, crash/access-violation `0`, and save restore `ChangeCount=0`. The next
  guard should be a bounded SDK-wrapper-only no-write DLSS frame-sequence
  evaluate at the same callback boundary; keep visible write-back and broad
  `RenderGraph.GetTexture` disabled.
- Follow-up stage
  `native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale` is now
  implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-preflight-implementation-2026-06-07.md`
  and
  `docs/development/native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-result-2026-06-07.md`.
  It adds default-off
  `Diagnostics.EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe=false`
  and native bridge API version `18`. The stage reuses the source-guided
  HDRP/EASU descriptor, issues one focused EASU `ctx.cmd` event with
  `eventId=260612`, creates a native scratch output from the visible EASU
  destination descriptor, evaluates DLSS into scratch, and immediately shuts
  down. Protected gameplay proof
  `native-renderfunc-commandbuffer-dlss-scratch-evaluate-render-scale-gameplay-1080p-20260607-r1`
  passed at true `1920x1080` Windowed with V Rising `FsrQualityMode=Off`,
  SDK-wrapper native, and the protected `11111` fixture. Computer Use clicked
  Continue once and sent no movement keys. Key evidence: `consumed=1`,
  `sequenceCreates=1`, `sequenceEvaluates=1`, `evaluateSuccesses=1`,
  `input=960x540`, `output=1920x1080`, `validation=D3D11-succeeded`,
  `sameDevice=yes`, source/depth/motion at `960x540`, visible destination at
  `1920x1080`, `scratchOutput=yes`, `visibleOutput=no`, `evaluateResult=1`,
  `shutdownResult=1`, `evaluateLast=0x00000001`, `create=0x00000001`,
  `feature=yes`, `release/destroy/shutdown=0x00000001`, actual evaluate timing
  about `0.446ms`, no `DLSS user rendering`, no actual visible write-back, no
  `ExecuteDLSS`, no crash/access-violation, and save restore `ChangeCount=0`.
  The repeated status lines were status re-logging, not repeated evaluate. The
  next guard should prove persistent scratch feature reuse at this same
  boundary before any visible write-back or normal-user rendering change.
- Follow-up stage
  `native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale`
  is now implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-preflight-implementation-2026-06-07.md`
  and
  `docs/development/native-renderfunc-commandbuffer-dlss-persistent-scratch-evaluate-render-scale-gameplay-result-2026-06-07.md`.
  It adds default-off
  `Diagnostics.EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe=false`
  and native bridge API version `19`. The stage reuses the same source-guided
  HDRP/EASU descriptor and focused EASU `ctx.cmd` callback, but keeps one
  SDK-wrapper DLSS frame sequence alive until three native scratch-output
  evaluates succeed, then releases/destroys/shuts down. First protected gameplay
  iteration `r1` was Partial at `sequenceEvaluates=2` because the managed EASU
  target stopped refreshing before the target count and RenderGraph handle
  indexes were later reused; the code now keeps target refresh active while
  persistent set/issue successes are below the target count. Protected gameplay
  proof `r2` passed at true `1920x1080` Windowed with V Rising
  `FsrQualityMode=Off`, SDK-wrapper native, and the protected `11111` fixture.
  Computer Use clicked Continue once and sent no movement keys. Key evidence:
  `eventId=260613`, `setSuccesses=3`, `issueSuccesses=3`, `consumed=3`,
  `sequenceCreates=1`, `sequenceEvaluates=3`, `evaluateSuccesses=3`,
  `input=960x540`, `output=1920x1080`, `validation=D3D11-succeeded`,
  `sameDevice=yes`, source/depth/motion at `960x540`, visible destination at
  `1920x1080`, `scratchOutput=yes`, `visibleOutput=no`, `persistent=yes`,
  `targetSuccesses=3`, `evaluateResult=1`, `shutdownResult=1`,
  `shutdown=completed`, `evaluateLast=0x00000001`, and
  `release/destroy/shutdown=0x00000001`. Negative counts: persistent scratch
  failures `0`, `visibleOutput=yes` `0`, `DLSS visible write-back` `0`,
  `ExecuteDLSS` `0`, `DLSS user rendering evaluate` `0`,
  `RenderGraph GetTexture call #` `0`, crash/access-violation `0`, and save
  restore `ChangeCount=0`. The final evaluate timing was steady-state small
  (`prepare=0.003ms`, `evaluate=0.228ms`, `total=0.232ms`), supporting the
  hypothesis that earlier bad performance is more likely from hot hooks,
  discovery, synchronization, or visible-path integration than from DLSS
  evaluate cost itself. The next guard can move to a separately gated visible
  write-back timing/quality proof at this boundary or continue source/
  decompilation-guided search for a cleaner official DLSS-pass-equivalent
  boundary.
- Follow-up stage
  `native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale` is now
  implemented and protected-gameplay validated; see
  `docs/development/native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-preflight-implementation-2026-06-07.md`
  and
  `docs/development/native-renderfunc-commandbuffer-dlss-visible-writeback-render-scale-gameplay-result-2026-06-07.md`.
  It adds default-off
  `Diagnostics.EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe=false`
  and native bridge API version `20`. It deliberately remains separate from old
  Stage 10A/global `EnableDlssVisibleWritebackProbe`: old visible write-back,
  normal-user rendering, `EnableDLSS`, `RenderGraph.GetTexture`, and hook probe
  stay disabled for this guard. Protected gameplay proof `r1` passed at true
  `1920x1080` Windowed with V Rising `FsrQualityMode=Off`, SDK-wrapper native,
  and the protected `11111` fixture. Key evidence: `eventId=260614`,
  `setSuccesses=3`, `issueSuccesses=3`, `consumed=3`, `sequenceCreates=1`,
  `sequenceEvaluates=3`, `evaluateSuccesses=3`, `input=960x540`,
  `output=1920x1080`, `validation=D3D11-succeeded`, `sameDevice=yes`,
  `scratchOutput=no`, `visibleOutput=yes`, `persistent=yes`,
  `targetSuccesses=3`, `evaluateResult=1`, `shutdownResult=1`,
  `shutdown=completed`, and `release/destroy/shutdown=0x00000001`. Negative
  counts: visible write-back failures `0`, blocked `0`, old Stage 10A visible
  write-back probe `0`, user-rendering evaluate `0`, `RenderGraph GetTexture
  call #` `0`, crash events `0`, and save restore `ChangeCount=0`. This is the
  first source-guided visible-output proof at the EASU `ctx.cmd` boundary; the
  next work should be visual/performance or a normal-user candidate that
  preserves this placement and bounded resource discovery.
- Follow-up normal-user candidate work started on 2026-06-07: `DLSS.EnableDLSS`
  is being rewired toward the source-guided native EASU `ctx.cmd`
  command-buffer route instead of the old hot global `RenderGraph.GetTexture`
  user-rendering path. The helper stage `dlss-user-rendering` now keeps
  `EnableRenderGraphGetTextureProbe=false`, `EnableHookProbe=false`, enables
  HDRP postprocess/global texture args plus render-scale control, and uses a new
  native event id `260615` for sustained user rendering. Static C# build and
  dry-run config validation passed before gameplay validation.
- The first protected 1080p Windowed start attempt for this candidate,
  `native-commandbuffer-user-rendering-1080p-20260607-r1`, failed before any
  visible Unity game window or BepInEx artifact log. Visibility saw only a
  `ConsoleWindowClass` BepInEx window titled with `选择 ...`, consistent with
  Windows console selection/QuickEdit pausing startup. Treat this as automation
  startup noise, not DLSS/render-path evidence. The failed-start cleanup
  restored loader config, ClientSettings, release-safe native state, and left no
  V Rising process; protected-save restore/check reported final
  `ChangeCount=0`.
- Automation mitigation is implemented in
  `scripts/start-vrising-automation-session.ps1` and
  `scripts/stop-vrising-automation-session.ps1`: session startup backs up
  `BepInEx\config\BepInEx.cfg`, temporarily disables the BepInEx console, keeps
  disk logging enabled with instant flushing, and cleanup restores the backup.
  See `docs/development/computer-use-vrising-automation-notes-2026-06-06.md`.
- Normal-user source-guided native command-buffer DLSS candidate passed
  protected gameplay on 2026-06-07; see
  `docs/development/native-commandbuffer-user-rendering-1080p-gameplay-result-2026-06-07.md`.
  The `r2` run was not a route failure: it reached `consumed=3029`,
  `lastEventId=260615`, `setFailures=0`, `issueFailures=0`, and
  `consumeFailures=0`, but managed logging kept seeing the next frame's pending
  payload because the native status string was overwritten after each consume.
  The fix added a separate native
  `VrisingDlss_GetRenderEventFrameDescriptorPayloadLastConsumedStatus()`
  export, changed user-rendering success detection to
  `consumed > 0 && lastEventId == 260615`, and throttled early
  `HDRP/EASU descriptor not ready` waiting logs. Protected gameplay run
  `native-commandbuffer-user-rendering-1080p-20260607-r3` passed at true
  `1920x1080` Windowed with V Rising `FsrQualityMode=Off`, SDK-wrapper native,
  and protected save restore. Analyzer reported `Native RenderFunc CommandBuffer
  DLSS User Rendering=Pass` and `DLSS User Rendering Candidate=Pass`. Key
  evidence: `eventId=260615`, `setSuccesses=124`, `issueSuccesses=124`,
  `consumed=124`, `sequenceCreates=1`, `sequenceEvaluates=124`,
  `evaluateSuccesses=124`, `input=960x540`, `output=1920x1080`,
  `validation=D3D11-succeeded`, `sameDevice=yes`, `scratchOutput=no`,
  `visibleOutput=yes`, `persistent=yes`, `evaluateResult=1`, and native timing
  `evaluate=0.092ms`, `total=0.096ms`. Negative counts:
  `RenderGraph GetTexture call #` `0`, visible write-back failures `0`,
  payload consume failures `0`, access violations `0`, `nvwgf2umx` `0`, crash
  events `0`, and final save `ChangeCount=0`. `shutdown=pending` is expected
  because normal user rendering keeps the DLSS frame sequence alive until
  cleanup.
- Build note: C# Release, MSVC release-safe native, and MSVC SDK-wrapper native
  all built successfully after the `lastConsumedStatus` change. The existing
  `artifacts\native-build` CMake/Ninja directory is tied to a local w64devkit
  configuration that currently fails with missing `cc1plus`; use
  `artifacts\native-build-msvc` for release-safe builds and
  `artifacts\native-build-msvc-wrapper` for SDK-wrapper builds. The default
  `artifacts\native-build\Release\VrisingDLSS.Native.dll` and the game plugin
  release-safe native were refreshed from the MSVC release-safe DLL so
  automation cleanup restores the current safe native.
- Source-guided route checkpoint on 2026-06-08: the useful "source" map is now
  enough for the current DLSS boundary without full proprietary V Rising source.
  Unity HDRP 2022.3 source supplies the official
  `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> DLSSPass.Render(...,
  ctx.cmd)` method-body map, V Rising IL2CPP metadata/interop proves the actual
  local symbols and generated EASU render-func identity, and the r3 protected
  gameplay proof proves the normal-user `DLSS.EnableDLSS=true` candidate can
  use the source-aligned EASU `ctx.cmd` route with `RenderGraph.GetTexture=0`.
  A fresh read-only probe still shows no complete built-in Unity NVIDIA runtime
  stack in the game. Do not spend the next loop on broad decompilation; use
  source-guided decompilation only for narrow questions such as
  history/reset/jitter/pre-exposure/lifecycle differences if the visual or
  performance gate fails. See
  `docs/research/source-guided-boundary-check-2026-06-08.md`.
- Harness checkpoint on 2026-06-08: `scripts\run-vrising-visual-comparison.ps1`
  now supports `-ProtectSave -SaveDir <local-save-dir>`. When enabled, the
  helper backs up the local/private save before any launch, archives the
  changed after-run state by default, closes any remaining V Rising process
  before restore, restores from the backup, and reports save evidence including
  `SaveRestoreAttempted`, `SaveRestored`, `SaveBeforeRestoreChangeCount`, and
  `SaveAfterRestoreChangeCount`. If protected-save restore fails, the helper
  emits its result object and exits nonzero. The next source-guided
  `dlss-user-rendering` paired visual/performance validation should use this
  built-in protection rather than relying on an external manual restore step.
- The same visual comparison helper now mirrors the automation session's
  BepInEx console mitigation: before launching paired visual runs it backs up
  `BepInEx\config\BepInEx.cfg`, disables `Logging.Console`, enables disk log
  flushing, then restores the backup during cleanup. A BepInEx config restore
  failure also makes the helper exit nonzero after printing the result.
- Protected paired visual/performance attempt
  `source-guided-user-rendering-1080p-20260608-r1` is partial, not MVP evidence.
  The helper used `-ProtectSave`, temporary BepInEx console mitigation,
  `FsrQualityMode=Off`, true `1920x1080` Windowed, and Computer Use clicked
  Continue once for baseline and once for candidate with no movement keys.
  Baseline screenshot/performance passed (`AverageFps=156.105`,
  `OnePercentLowFps=90.552`, `P95FrameMs=9.209`, GPU util `81.4%`). Candidate
  screenshot and DLSS evidence passed: `DLSS User Rendering Candidate=Pass`,
  `eventId=260615`, `setSuccesses=12`, `consumed=12`,
  `sequenceCreates=1`, `sequenceEvaluates=12`, `evaluateSuccesses=12`,
  `input=960x540`, `output=1920x1080`, `RenderGraph GetTexture call #=0`, no
  crash/driver/access-violation evidence. Image comparison matched `1920x1080`
  with `MeanAbsRgbDelta=2.0072` and `ChangedRatioGt10=0.026254`. Candidate
  PresentMon FPS capture failed because no candidate CSV was created, so this
  run cannot decide the performance gate; only system metrics were recorded
  (`AverageGpuUtilPercent=33.0`, `AverageGpuPowerW=62.24`). Cleanup passed:
  no V Rising process remained and protected save restore ended with
  `ChangeCount=0`. See
  `docs/development/source-guided-user-rendering-visual-performance-2026-06-08.md`.
- Harness follow-up after that partial run: `scripts\capture-vrising-fps.ps1`
  now emits a structured summary for PresentMon failure cases instead of
  throwing before writing performance evidence. Failure statuses include
  `PresentMonCsvMissing`, `PresentMonFailed`,
  `PresentMonInvocationFailed`, and `PresentMonNoUsableFrames`; successful
  captures now write `Status=Pass`. `scripts\get-visual-validation-status.ps1`
  now blocks when a performance summary has a non-`Pass` status or is missing
  required FPS metrics (`AverageFps`, `OnePercentLowFps`, `P95FrameMs`), so a
  metrics-only failure artifact cannot accidentally satisfy the MVP gate. A
  fake PresentMon non-runtime test covered `PresentMonCsvMissing`, and a
  temporary readiness check confirmed the visual gate stays `Blocked`.
- Candidate-only performance rerun
  `candidate-user-rendering-perf-1080p-20260608-r1` then proved the harness can
  capture the source-guided `dlss-user-rendering` candidate FPS after the
  structured PresentMon fix. Runtime shape was true `1920x1080` Windowed,
  V Rising `FsrQualityMode=Off`, protected local save, and Computer Use clicked
  Continue once with no movement keys. `DLSS User Rendering Candidate=Pass` and
  `Native RenderFunc CommandBuffer DLSS User Rendering=Pass`; the FPS summary
  wrote `Status=Pass`, `AverageFps=136.322`, `OnePercentLowFps=105.096`,
  `P95FrameMs=8.624`, `P99FrameMs=9.515`,
  `AverageGpuUtilPercent=53.111`, and `AverageGpuPowerW=85.199`. Screenshot was
  nonblank `1920x1080` with SHA-256
  `057A21D3365DA16E6BC5D27ED5474A9A74BFA37BD71CE16D557AAA0DD93ADD8B`.
  Cleanup passed: no crash/WER, no remaining V Rising process,
  release-safe state restored, BepInEx/client settings restored, FSR restored
  Off, and protected save restore ended `CompareStatus=Restored` with final
  `ChangeCount=0`. This candidate-only run is not MVP performance evidence:
  cross-run comparison against the earlier paired baseline would be about
  `-12.67%` average FPS, `+16.06%` 1% low, and `-6.35%` P95 frame time, but a
  same-run paired baseline/candidate comparison and human visual review are
  still required.
- Next direction after the candidate-only rerun: the current EASU `ctx.cmd`
  route is stable enough to measure and avoids the old hot
  `RenderGraph.GetTexture` path, so more blind runtime loops are lower value
  than a narrow source/decompilation pass. Use local Unity HDRP source plus V
  Rising IL2CPP metadata/decompilation to compare official
  `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> DLSSPass.Render(...,
  ctx.cmd)` behavior with the current EASU `ctx.cmd` candidate. Focus only on
  concrete differences that could affect quality/performance: jitter,
  motion-vector scale, reset/history state, pre-exposure, sharpness,
  camera/resource history, resize/reset lifecycle, feature reuse, resource
  declarations, synchronization/present behavior, and whether any
  BepInEx/Harmony-safe equivalent to `DoDLSSPass`/`DLSSPass.Render` is reachable
  without broad steady-state resource discovery. Keep decompiled game evidence
  local and summarized; do not copy proprietary method bodies or game assets
  into the public package.
- First narrow source/decompilation-guided patch after that rerun is implemented
  and build-validated; see
  `docs/development/source-guided-dlss-parameter-alignment-2026-06-08.md`.
  Unity HDRP source and V Rising IL2CPP interop showed that official
  `DLSSPass` supplies per-frame jitter, motion-vector scale, pre-exposure, and
  camera reset/history state, while the current command-buffer frame-sequence
  route still used debug defaults (`jitter=(0,0)`, `mvScale=(1,1)`,
  `preExposure=1.0`, config-only reset). Native bridge API version is now `21`.
  `HdrpPostProcessRenderArgsProbe` reads `HDCamera.taaJitter`,
  `GpuExposureValue()`, and `resetPostProcessingHistory`; the HDRP/EASU
  descriptor now carries `jitter=(-taaJitter.xy)`,
  `mvScale=(-inputWidth,-inputHeight)`, clamped `preExposure`, and camera reset
  into native command-buffer scratch/persistent/visible/user-rendering payloads.
  The native SDK-wrapper frame-sequence evaluate now sets NGX `InPreExposure`
  from the payload and logs `jitter`, `mvScale`, and `preExposure`. Non-runtime
  verification passed: C# Release, release-safe native, SDK-wrapper native, and
  visual readiness remained `Blocked`.
- API 21 candidate-only runtime guard
  `api21-user-rendering-1080p-20260608-r4` passed after that patch. The helper
  used true `1920x1080` Windowed, V Rising `FsrQualityMode=Off`, SDK-wrapper
  native, explicit local research `nvngx_dlss.dll`, the protected `11111`
  fixture, and Computer Use clicked Continue once with no movement/gameplay
  keys. Analysis reported `Native bridge API version: 21`,
  `HDRP PostProcess Render Args=Pass`, `HDRP/EASU Input Output Correlation=Pass`,
  `Native RenderFunc CommandBuffer DLSS User Rendering=Pass`, and
  `DLSS User Rendering Candidate=Pass`. Logs showed `dlssFrameParams=` 11 times,
  `dlssEvaluateParams=` once, and native `jitter/mvScale/preExposure` status 59
  times; the accepted descriptor included
  `jitter=(0.0375,0.0833),mvScale=(-960,-540),preExposure=1,resetHistory=False`,
  and native evaluate statuses carried matching non-default jitter and
  `mvScale=(-960.0000,-540.0000)`. FPS capture passed with
  `AverageFps=131.241`, `OnePercentLowFps=99.398`, `P95FrameMs=9.037`,
  `P99FrameMs=10.061`, `AverageGpuUtilPercent=52`, and
  `AverageGpuPowerW=85.836`; screenshot SHA-256 was
  `18FC7DEF8DF0B3BBC58CFEAD98ED1F0CD1BC9742BBAACE0A9B30639C7C2141AB`.
  Negative evidence: `RenderGraph GetTexture call #=0`, explicit
  user-rendering failed/blocked/skipped lines `0`, access violation /
  `0xc0000005` / `nvwgf2umx` evidence `0`, crash events `0`, no remaining
  V Rising process, release-safe state restored, and protected save final
  `ChangeCount=0`. This proves the API 21 parameter path reaches real gameplay
  NGX evaluate; it is still not MVP performance evidence because it is
  candidate-only and short. The next guard should be a same-run protected
  baseline-vs-candidate visual/performance comparison plus human visual review.
  Feature-create flags, AutoExposure vs supplied pre-exposure, bias color mask,
  and resize/reset behavior remain separate source-backed questions.
- API 21 same-run paired visual/performance rerun
  `api21-paired-user-rendering-1080p-20260608-r1` then converted the
  candidate-only proof into current readiness evidence. The run used true
  `1920x1080` Windowed, V Rising `FsrQualityMode=Off`, protected `11111` save,
  SDK-wrapper native/runtime only for the candidate, and Computer Use clicked
  Continue once per run with no movement/gameplay keys. It also added system
  snapshots under `artifacts/system-snapshots/` and disconnected Computer Use
  after game cleanup. Baseline returned to the expected high-performance range:
  `AverageFps=199.704`, `OnePercentLowFps=150.016`, `P95FrameMs=6.061`,
  `AverageGpuUtilPercent=97.75`, `AverageGpuPowerW=138.106`,
  `AverageGpuTemperatureC=86.875`. Candidate passed technical DLSS evidence but
  failed performance: `AverageFps=126.358`, `OnePercentLowFps=99.225`,
  `P95FrameMs=9.088`, `P99FrameMs=10.078`,
  `AverageGpuUtilPercent=51`, `AverageGpuPowerW=86.064`,
  `AverageGpuTemperatureC=75`. Readiness now blocks on
  `AverageFpsDeltaPercent=-36.727`, `OnePercentLowFpsDeltaPercent=-33.857`,
  `P95FrameMsDeltaPercent=49.942`, plus missing human visual review. Image
  comparison stayed close (`MeanAbsRgbDelta=1.8288`,
  `ChangedRatioGt10=0.021332`, both `1920x1080`). Candidate log counts remained
  clean: API 21 present, `dlssFrameParams=11`, `dlssEvaluateParams=1`,
  native `jitter/mvScale/preExposure=66`, `RenderGraph GetTexture call #=0`,
  explicit user-rendering failures `0`, crash/access-violation evidence `0`.
  Cleanup passed with no remaining V Rising process, release-safe state
  restored, FSR restored Off, and protected save final `ChangeCount=0`.
  Therefore API 21 fixed a parameter correctness gap but did not fix the core
  performance blocker. The next aligned route is comprehensive
  source/decompilation comparison of official HDRP `DLSSPass` versus the
  current EASU `ctx.cmd` candidate, not another blind runtime loop.
- Official HDRP DLSSPass vs EASU candidate audit is now recorded in
  `docs/development/official-dlsspass-vs-easu-candidate-audit-2026-06-08.md`.
  Main findings: active user-rendering carries jitter/mvScale/preExposure/reset
  into the command-buffer payload, but it still differs from official HDRP in
  feature flags (`0x40` AutoExposure-only vs official-HDRP-like `0x2B`),
  NGX invert-axis eval fields (current Y=0 vs official Y=1), reset semantics
  (current native sequence applies reset only on first evaluate), and output
  boundary (EASU visible destination vs official `"DLSS destination"`). V Rising
  IL2CPP interops confirm the relevant HDRP DLSS symbols/tokens are present but
  do not prove a game-specific replacement body. Next runtime work should follow
  a small source-backed patch, most likely official feature flags plus invert-Y
  parity first, with reset/lifecycle parity next or included if the patch stays
  tiny.
- Official feature-flag/invert-axis parity patch is now implemented and
  non-runtime build-validated; see
  `docs/development/official-hdrp-dlss-flag-invert-parity-2026-06-08.md`.
  New default config key: `DLSS.UseOfficialHdrpFeatureFlags=true`; in that mode
  feature flags resolve to official-HDRP-like `0x2B`
  (`IsHDR | MVLowRes | DepthInverted | DoSharpening`) and `AutoExposure` is not
  added. `DLSS.AutoExposure` now defaults `false` and is only a legacy fallback
  when official flags are disabled. Native SDK-wrapper eval paths now set
  `InIndicatorInvertXAxis=0`, `InIndicatorInvertYAxis=1`, and frame-sequence
  status logs `invertAxis=(0,1)`. C# Release, release-safe native, SDK-wrapper
  native, release readiness static check, diagnostic config dry-run, and
  `git diff --check` passed. Next runtime guard: protected same-run 1080p
  baseline/candidate test expecting candidate logs to show `flags=0x0000002B`
  and `invertAxis=(0,1)`, while measuring whether low GPU utilization/FPS
  regression improves. Reset/lifecycle and official output-boundary parity
  remain separate follow-up variables.
- User follow-up after the paired run emphasized that baseline drift should be
  measured more broadly. `scripts\capture-vrising-fps.ps1` now captures
  before/after system snapshots by default via the new
  `scripts\capture-system-snapshot.ps1`. Snapshots include top CPU/memory
  processes, target V Rising process row, CPU/memory summary, and NVIDIA GPU
  driver/P-state/utilization/memory/power/temperature/clocks plus available GPU
  process rows. This is meant to distinguish save-state issues from environment
  or measurement drift when a protected save restore ends with `ChangeCount=0`.
- Fresh local/private V Rising IL2CPP decompilation on 2026-06-08 is recorded in
  `docs/development/vrising-il2cpp-hdrp-dlss-shell-decompilation-2026-06-08.md`.
  Il2CppDumper succeeded against metadata/IL2CPP version `31` and wrote outputs
  under `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/`; Cpp2IL
  `2022.0.7` was rejected because it only supports older metadata. The main
  finding is that V Rising contains the HDRP DLSS pass shell, pass strings,
  resource structs, helper methods, and generated `DoDLSSPass` render func, but
  `DLSSPass.Render`, `DLSSPass.BeginFrame`, and
  `DLSSPass.SetupDRSScaling` all map to the same no-op-style address
  (`24240496` / `RVA 0x171E170`). Therefore the official Unity HDRP path remains
  a semantic map, not a built-in NVIDIA implementation that can simply be
  enabled. The current EASU `ctx.cmd` route stays the only proven visible-output
  boundary; any closer official-equivalent boundary must replace/augment the
  missing execution body and start with a no-DLSS/no-native proof.
- Official-HDRP-like feature flag and invert-axis parity was protected-runtime
  tested in `official-flags-paired-user-rendering-1080p-20260608-r2`; see
  `docs/development/official-hdrp-dlss-flag-invert-paired-result-2026-06-08.md`.
  The run used true `1920x1080` Windowed, V Rising FSR Off, protected `11111`
  save, Computer Use Continue clicks only, SDK-wrapper native/runtime for the
  candidate, and automatic before/after system snapshots. The candidate log
  proved `flags=0x0000002B`, `invertAxis=(0,1)`, `DLSS user rendering evaluate
  succeeded`, `input=960x540 output=1920x1080`, `RenderGraph GetTexture=0`, no
  crash/driver evidence, and cleanup restored release-safe state plus protected
  save `ChangeCount=0`. Performance still failed badly: average FPS
  `202.794 -> 128.745`, 1% low `151.105 -> 97.431`, P95 `6.004 ms ->
  9.251 ms`, GPU util `97.143% -> 54.643%`, power `136.757 W -> 90.929 W`.
  Therefore official flags/invert parity is kept for correctness but rejected
  as the FPS fix. Do not rerun the same EASU `ctx.cmd` candidate shape
  unchanged; next work should target boundary/lifecycle/resource-order or
  synchronization differences versus official HDRP.
- A no-runtime preflight for the next boundary step is now implemented and
  recorded in
  `docs/development/hdrp-dlss-schedule-audit-preflight-2026-06-08.md`. New
  diagnostic stage `hdrp-dlss-schedule-audit` keeps `DLSS.EnableDLSS=false`,
  disables broad `RenderGraph.GetTexture`, disables HookProbe, and enables only
  read-only RenderGraph compile-list/resource-declaration/pass-data/render-func
  metadata/compiled-info plus `UpscalerStateProbe`. The paired analyzer
  `scripts\analyze-hdrp-dlss-schedule-audit.ps1` classifies logs as
  `OfficialDlssPassObserved`, `NoOfficialDlssPassObserved`, `Fail`, or
  `Incomplete` and explicitly treats user-rendering evaluate, native DLSS
  user-rendering, broad GetTexture calls, or crash indicators as audit
  pollution/failure. The next runtime action should run this stage at true
  `1920x1080` Windowed before any state-changing attempt to force official HDRP
  DLSS scheduling.
- The read-only schedule audit has now been runtime-tested in
  `hdrp-dlss-schedule-audit-1080p-menu-20260608-r1`; see
  `docs/development/hdrp-dlss-schedule-audit-runtime-result-2026-06-08.md`.
  It was a menu-only `1920x1080` Windowed run, did not enter gameplay, and
  cleaned up with `CrashEventCount=0`, no remaining V Rising process,
  release-safe native/config restored, and ClientSettings restored. Analyzer
  status was `NoOfficialDlssPassObserved` with no issues: `93` RenderGraph
  compile snapshots, `866` RenderGraph observation lines, EASU mentions `246`,
  Final Pass mentions `299`, but `"Deep Learning Super Sampling"` pass,
  `category=dlss`, DLSS pass data/declarations/render-func metadata,
  `DLSS destination`, broad GetTexture calls, user-rendering/evaluate evidence,
  and access-violation indicators were all `0`. The key gate signature was
  `allowDeepLearningSuperSampling=True` but `cameraCanRenderDLSS=False`,
  `GlobalDynamicResolutionSettings.enableDLSS=False`,
  `HDCamera.IsDLSSEnabled=False`, and `UpsampleSyncPoint=AfterPost`. Local
  Unity HDRP source confirms `IsDLSSEnabled()` returns `cameraCanRenderDLSS`,
  and `SetupDLSSForCameraDataAndDynamicResHandler` only sets it true when the
  camera requested dynamic resolution, DLSS is detected, camera DLSS is allowed,
  HDRP asset `enableDLSS` is true, and HDRP dynamic resolution is enabled. Next
  aligned step is a menu-first, default-off, no-native schedule-gate design that
  observes whether the official pass shell appears when those gates are
  deliberately set, without patching `DLSSPass.Render`.
- The schedule-gate design is now implemented and non-runtime validated; see
  `docs/development/hdrp-dlss-schedule-gate-preflight-2026-06-08.md`. New
  config key: `Diagnostics.EnableHdrpDlssScheduleGateProbe=false`. New stage:
  `hdrp-dlss-schedule-gate`. The stage keeps `DLSS.EnableDLSS=false`, leaves
  all native/evaluate/user-rendering probes off, disables broad
  `RenderGraph.GetTexture`, and combines a focused
  `HDRenderPipeline.SetupDLSSForCameraDataAndDynamicResHandler`
  gate-mutating probe with existing
  RenderGraph pass-list/resource-declaration/pass-data/render-func
  metadata/compiled-info and `UpscalerStateProbe` logging. The probe mutates
  only HDRP scheduling gates (`allowDynamicResolution`,
  `allowDeepLearningSuperSampling`, `cameraRequestedDynamicRes`,
  HDRP asset/out DRS `enabled=true`, `enableDLSS=true`,
  `DLSSInjectionPoint=BeforePost`, Performance `50%`, etc.) and, in postfix,
  forces
  `cameraCanRenderDLSS=true` if official setup still leaves it false. It logs
  `DLSSDetected`, `m_DLSSPass`, `m_DLSSPassEnabled`, camera fields, out DRS,
  and asset DRS state so a later runtime result can distinguish camera gate
  failure from a missing `DLSSPass` object/module. Build passed with 0 warnings
  and dry-runs for `write-diagnostic-config.ps1` and
  `run-vrising-diagnostic.ps1` accepted the new stage with
  `LaunchesGame=False`. If this classification tool is run later, use a
  menu-only true `1920x1080` Windowed
  `scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage
  hdrp-dlss-schedule-gate -DurationSeconds 75 -SetClientResolution
  -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080`, do not
  click Continue or enter gameplay, then analyze with
  `scripts\analyze-hdrp-dlss-schedule-audit.ps1`.
- Systematic local static route audit is now recorded in
  `docs/development/vrising-hdrp-dlss-route-static-audit-2026-06-08.md`.
  No V Rising runtime was launched for this pass. The audit aligned local
  Il2CppDumper output, BepInEx/interop wrapper evidence, UnityGraphics 2022.3
  HDRP source, and prior runtime logs. Main finding: V Rising contains the
  official HDRP DLSS route shell (`SetupDLSSForCameraDataAndDynamicResHandler`,
  `GetPostprocessUpsampledOutputHandle`, `RenderPostProcess`,
  `DoDLSSPasses`, `DoDLSSPass`, generated `DLSSData` render func, pass
  strings, and resource structs), but the built-in DLSS execution body remains
  unusable as-is because `DLSSPass.Render`, `BeginFrame`, `SetupDRSScaling`,
  and `.ctor` all map to the same no-op-style stub RVA `0x171E170`. V Rising
  also has real FSR/dynamic-resolution control through
  `ProjectM.GraphicsSettingsManager` and `FSRQualityMode`, but no local
  evidence yet shows a game-specific DLSS replacement layer. Therefore
  schedule-gate is now classified as a later menu-only `m_DLSSPass`/gate
  diagnostic, not the immediate performance-fix runtime. The mainline next
  step is deeper static/local route work: prove `m_DLSSPass` creation/module
  state where possible and design a no-native official-equivalent RenderGraph
  pass boundary with explicit source/output/depth/motion resource declarations
  before introducing NGX evaluate again.
- Follow-up `m_DLSSPass`/feature xref audit is now recorded in
  `docs/development/vrising-hdrp-dlss-m-dlsspass-xref-audit-2026-06-08.md`.
  No V Rising runtime was launched. Local xrefs show
  `HDRenderPipeline.SetupDLSSFeature` exists and is called by
  `SetRenderingFeatures` / `HDRenderPipelineAsset.OnEnable`, but it does not
  xref `DLSSPass.SetupFeature` (`0x17312A0`) or
  `HDDynamicResolutionPlatformCapabilities.ActivateDLSS` (`0x987C720`), and
  `ActivateDLSS` has `CallerCount=0`. `InitializePostProcess` likewise has no
  resolved xref to `DLSSPass.Create` (`0x173F700`), while `DoDLSSPasses` /
  `DoDLSSPass` still record the official RenderGraph shell and resource
  contract. Current decision: stop treating `m_DLSSPass` activation as the
  likely fix; keep `hdrp-dlss-schedule-gate` only as a later menu classifier,
  and make the mainline next step a no-native official-equivalent RenderGraph
  boundary proof that is cheap before any NGX evaluate is reintroduced.
- Official-equivalent RenderGraph boundary feasibility is now recorded in
  `docs/development/official-equivalent-rendergraph-boundary-feasibility-2026-06-08.md`.
  No V Rising runtime was launched. The old `RenderGraphDiagnosticPass`
  evidence answers the generic managed-pass question: `AddRenderPass` /
  `SetRenderFunc` can configure a mod-owned pass with `hasRenderFunc=True`, but
  the 2026-06-05 protected gameplay attempt crashed `VRising.exe` in
  `coreclr.dll` (`c0000005`) before any diagnostic render-func log, so new
  mod-owned pass injection remains rejected for the normal route. The
  `hdrp-dlss-schedule-audit` analyzer now extracts existing EASU/FinalPass
  chain evidence: on the archived 2026-06-08 menu audit it reports
  `EasuPassDataSnapshots=75`, `EasuRenderFuncMetadata=75`,
  `EasuCompiledPassInfo=36`, `EasuFinalSourceChains=73`,
  `FinalPassDataSnapshots=87`, `MotionVectorPassMentions=233`, and
  `DeepLearningSuperSamplingPass=0`. Current decision: next proof should compare
  the engine-owned EASU->Final chain against the official DLSS resource contract
  and keep using the already-proven EASU `ctx.cmd` descriptor boundary for
  bounded no-native/no-evaluate or no-write work, not camera-gate probing or new
  pass injection.
- Official DLSS contract vs EASU chain analysis is now recorded in
  `docs/development/official-dlss-contract-vs-easu-chain-analysis-2026-06-08.md`.
  No V Rising runtime was launched. `scripts/analyze-hdrp-dlss-schedule-audit.ps1`
  now parses `Uber Post`, `Edge Adaptive Spatial Upsampling`, and `Final Pass`
  pass-data together, reports `CompleteUberEasuFinalChains`,
  `CompleteSuperResolutionChains`, EASU declaration read/write shape, and a
  `Contract` verdict. On the archived menu audit it reports
  `Contract.Status=EasuChainObservedButContractIncomplete`,
  `CompleteUberEasuFinalChains=73`, `CompleteSuperResolutionChains=0`,
  `EasuSingleReadSingleWriteDeclarations=44`, `EasuMultiReadDeclarations=0`,
  and `EasuNonZeroDepthAttachmentDeclarations=0`. Current decision: the
  engine-owned EASU boundary is a usable four-resource descriptor carrier only
  when combined with separate HDRP depth/motion correlation evidence; EASU
  pass declaration alone is not official-equivalent. Next proof should bind the
  HDRP depth/motion correlation to the observed `Uber->EASU->Final` chain in one
  no-native/no-evaluate run or produce a bounded no-write cost proof before any
  visible DLSS write-back is retried.
- HDRP DLSS contract-bind render-scale preflight is now recorded in
  `docs/development/hdrp-dlss-contract-bind-render-scale-preflight-2026-06-08.md`.
  No V Rising runtime was launched. New stage:
  `hdrp-dlss-contract-bind-render-scale`. It combines read-only RenderGraph
  pass-list/declaration/pass-data/render-func/compiled-info probes with
  `HdrpPostProcessRenderArgsGlobalTextureProbe`, render-scale control, and
  upscaler-state while keeping `DLSS.EnableDLSS=false`,
  `RenderGraph.GetTexture=false`, native render-func detours off, command-buffer
  plugin events off, NGX/DLSS runtime/evaluate off, schedule-gate off, and
  mod-owned RenderGraph pass injection off. The schedule-audit analyzer now
  parses HDRP postprocess source/depth/motion snapshots and can report
  `Contract.Status=EasuSuperResolutionChainWithHdrpDepthMotionObservedButContractIncomplete`
  only when a same log contains an SR-sized `Uber->EASU->Final` chain plus HDRP
  input/depth/motion dimensions matching EASU input. Dry-runs for
  `write-diagnostic-config.ps1` and `run-vrising-diagnostic.ps1` accepted the
  new stage with `LaunchesGame=False`. Old user-rendering logs that contain
  evaluate evidence remain analyzer `Fail`, preventing polluted logs from being
  mistaken for contract-bind proof. Next runtime step, if resumed, is a protected
  gameplay run of this stage at true `1920x1080` Windowed with V Rising FSR Off,
  followed by `analyze-hdrp-dlss-schedule-audit.ps1`; do not pass SDK-wrapper
  native or DLSS runtime for this stage.
- Systematic local decompilation investigation is now recorded in
  `docs/development/vrising-systematic-local-decompilation-investigation-2026-06-08.md`.
  No V Rising runtime was launched and no game files were modified. The pass
  rechecked local Il2CppDumper output, BepInEx interop/xref cache, UnityGraphics
  2022.3 source, and asset strings. Evidence: V Rising contains the official
  HDRP postprocess route shell (`RenderPostProcess`, `DoDLSSPasses`,
  `DoDLSSPass`, `GetPostprocessUpsampledOutputHandle`, EASU, FinalPass);
  xrefs show `DoDLSSPasses` has five callers from `RenderPostProcess` and
  `DoDLSSPass` calls `AddRenderPass`, `ReadTexture`,
  `DLSSPass.CreateCameraResources`, `RenderFunc<T>.ctor`, and `SetRenderFunc`.
  Counter-evidence: `DLSSPass.BeginFrame`, `SetupDRSScaling`, `Render`, and
  `.ctor` all share `0x171E170`, `ActivateDLSS` has no useful caller path, and
  `InitializePostProcess -> DLSSPass.Create` is not resolved. V Rising's
  `ProjectM.GraphicsSettingsManager` and `FSRQualityMode` confirm a real
  game-side FSR/TAAU/dynamic-resolution control layer, but no local evidence
  shows a game-specific DLSS replacement layer. The earlier asset-string-only
  limitation is superseded by the follow-up UnityPy/type-tree HDRP asset unpack
  and repeatable static audit, which now provide serialized HDRP asset gate
  values without launching the game.
  Durable decision: treat official `DoDLSSPass` as the semantic resource-order
  contract, not as a callable implementation; do not patch `DLSSPass.Render` or
  force `m_DLSSPass` as the fix. Mainline remains contract-bind evidence, then
  bounded no-write cost proof, then NGX evaluate only if the boundary is cheap.
- Repeatable static route audit is now recorded in
  `docs/development/vrising-hdrp-dlss-static-route-audit-2026-06-08.md`, with
  local JSON at
  `artifacts/research/vrising-hdrp-dlss-static-route-audit-20260608.json`.
  It ran read-only (`LaunchesGame=false`, `ModifiesGameFiles=false`) and
  reported: HDRP route anchors `9/9`, DLSSPass methods `9/9`,
  `DLSSPass.BeginFrame/SetupDRSScaling/Render/.ctor` sharing `0x171E170`,
  active asset `HDRP DefaultSettings` with `enableDLSS=0` and
  `upsampleFilter=EdgeAdaptiveScalingUpres`,
  `SetupDLSSFeature -> DLSSPass.SetupFeature=False`,
  `InitializePostProcess -> DLSSPass.Create=False`,
  `DoDLSSPassDeclaresRenderGraphBoundary=True`,
  `ActivateDLSSCallerCount=0`, ProjectM DLSS/NGX/Streamline hits `0`, and
  upscaler runtime files outside our mod/config `0`. This mechanically
  reinforces the route decision: use `DoDLSSPass` as clean-room semantic
  contract, not as a callable V Rising DLSS implementation.
- HDRP asset unpack follow-up is now recorded in
  `docs/development/vrising-hdrp-asset-unpack-followup-2026-06-08.md`.
  No V Rising runtime was launched and no game files were modified. UnityPy
  `1.25.0` and TypeTreeGeneratorAPI `0.0.10` were installed into
  `C:\Software\Python314` and used read-only with local Il2CppDumper `DummyDll`
  type trees after direct IL2CPP type-tree loading failed against the local
  metadata v31/GameAssembly pair. The Unity `GraphicsSettings` object in
  `globalgamemanagers` points `m_CustomRenderPipeline` to path id `9008`,
  `HDRP DefaultSettings`. That active `HDRenderPipelineAsset` parses with
  `m_UseRenderGraph=1`, `dynamicResolutionSettings.enabled=1`,
  `enableDLSS=0`, `DLSSInjectionPoint=0` (`BeforePost`), `dynResType=1`
  (`Hardware`), and `upsampleFilter=4` (`EdgeAdaptiveScalingUpres` / FSR 1.0
  EASU). `HDRP_Low` and `HDRP_Medium` also have `enableDLSS=0`, and their
  dynamic-resolution setting is disabled. `HDRenderPipelineGlobalSettings`
  structured parsing remains incomplete, but its object/header and embedded
  custom postprocess strings confirm V Rising registers types such as
  `CustomVignette`, `DarkForeground`, `BatFormFog`, and
  `ProjectM.ContestAreaEffect`. This promotes the asset evidence from raw
  strings to serialized active-asset values and further explains why official
  HDRP DLSS is not scheduled normally.
- The HDRP asset unpack is now repeatable with
  `scripts\inspect-vrising-hdrp-assets.ps1 -GamePath C:\Software\VRising -Json`.
  The script launches no game process, modifies no game files, and reports
  `Status=Pass`, `LaunchesGame=false`, `ModifiesGameFiles=false`,
  `ActiveAssetName=HDRP DefaultSettings`, `UseRenderGraph=1`, `EnableDLSS=0`,
  and `UpsampleFilterName=EdgeAdaptiveScalingUpres` on the current local install.
- `scripts\get-release-readiness-status.ps1 -GamePath C:\Software\VRising -Json`
  now includes that HDRP asset unpack as an `Evidence` readiness item. Local
  success reports the active HDRP asset, RenderGraph/dynamic-resolution gates,
  `EnableDLSS=0`, `DLSSInjectionPoint=BeforePost`, and `UpsampleFilter=EASU`;
  missing local Python/type-tree tooling is a `Blocked` evidence item, not a
  diagnostic package hard failure.
- Automation session protected-save support was added after the contract-bind
  preflight. `scripts/start-vrising-automation-session.ps1` now accepts
  `-ProtectSave -SaveDir <local-save-dir>` and records `SaveBackupDir`,
  `SaveBackupZipPath`, `SaveBackupManifestPath`, `RestoresProtectedSave`, and
  `ArchiveChangedSave` in the session JSON. It now also accepts
  `-ProtectSave -SaveName 11111`, resolves the local CloudSaves fixture through
  `find-vrising-save-fixture.ps1 -RequireOne`, and records
  `SaveFixtureResolved`, `SaveFixtureStatus`, `SaveFixtureMatchCount`, and
  `SaveFixtureSaveId` in dry-run and real session results. On failed starts it
  attempts to restore immediately after closing V Rising. `scripts/stop-vrising-automation-session.ps1`
  now restores protected saves after scoped V Rising processes are closed and
  reports `SaveRestoreAttempted`, `SaveRestored`,
  `SaveBeforeRestoreChangeCount`, `SaveAfterRestoreChangeCount`, and
  `SaveCompareStatus`; protected-save restore failure makes cleanup fail. The
  next `hdrp-dlss-contract-bind-render-scale` gameplay run should use this
  built-in protection, preferably as `-ProtectSave -SaveName 11111`, instead of
  a separate manual protect/restore pair.
- A resumed attempt to run the protected
  `hdrp-dlss-contract-bind-render-scale` gameplay proof on 2026-06-08 was
  deferred before launch because Computer Use returned
  `Windows computer-use client is closed`. No V Rising process was started, no
  game config was written, and the protected save was not touched. The current
  mainline is unchanged: once Computer Use is available, run the protected
  `hdrp-dlss-contract-bind-render-scale` session at true `1920x1080` Windowed,
  click Continue/`11111` once, send no movement keys, stop through
  `stop-vrising-automation-session.ps1`, require `SaveAfterRestoreChangeCount=0`,
  and analyze the BepInEx log with
  `scripts/analyze-hdrp-dlss-schedule-audit.ps1`.
- Because Computer Use remained closed on the next continuation, the
  no-runtime "inspect" half of the same next step was advanced instead:
  `scripts\test-hdrp-dlss-contract-bind-stage.ps1` now asserts the
  `hdrp-dlss-contract-bind-render-scale` dry-run switch matrix. Local guard
  evidence passed with `LaunchesGame=false`, `ModifiesGameFiles=false`,
  `RequiredTrueCount=10`, `RequiredFalseCount=50`, `CheckCount=62`,
  `DiagnosticDryRun.UseSdkWrapperNative=false`,
  `DiagnosticDryRun.RestoresReleaseSafeNative=false`, and
  `ClientWindowMode=3`. With the current local save directory supplied, the
  session dry-run also preserved `ProtectSave=true` and
  `RestoresProtectedSave=true`. `get-release-readiness-status.ps1` now includes
  this guard as an `Evidence` readiness item. The GitHub Actions package
  workflow now runs the config-only guard before packaging with `-RequirePass`,
  so `Fail` or `Blocked` guard results fail CI; the Automation readiness check
  requires that enforcing CI step to remain present.
- `scripts\find-vrising-save-fixture.ps1 -SaveName 11111 -RequireOne -Json`
  now resolves the current local/private Continue fixture without launching
  V Rising or modifying save files. On this machine it reports `Status=Pass`,
  `MatchCount=1`, `AutoSaveCount=8`, `HasServerGameSettings=true`, and
  `Usable=true`. `get-release-readiness-status.ps1 -GamePath C:\Software\VRising`
  now includes this as an `Evidence` item and passes `SaveName=11111` into the
  contract-bind guard, so the readiness evidence includes
  `SessionDryRunLaunchesGame=False`, `ProtectSave=True`, and
  `RestoresProtectedSave=True`, plus session fixture resolution fields.
- `scripts/get-runtime-validation-status.ps1` was updated after that deferral
  so a safe live `loader` config/log no longer sends the next-action advice
  back to the old hook-probe ladder when the repository already contains the
  2026-06-08 contract-bind, contract-analysis, and systematic-decompilation
  evidence documents. With the current local game install it now reports
  `ConfiguredStage=loader`, `LaunchesGame=False`, and recommends the protected
  `hdrp-dlss-contract-bind-render-scale` gameplay proof while still preserving
  the actual live-log stage results.
- The same runtime status script now supports `-Json`, matching the release
  readiness script's machine-readable mode. This keeps future automation from
  depending on fragile PowerShell formatting when checking
  `ConfiguredStage=loader`, `LaunchesGame=False`, and whether the current
  recommendation still points to the protected contract-bind proof.
