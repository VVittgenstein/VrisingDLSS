# Cached Driver Real-Evaluate Runtime Result - 2026-06-06

Question:

Can the real SDK-wrapper `dlss-user-rendering` evaluate path use the
cached-tuple driver shape proven by `dlss-user-rendering-cached-driver-no-evaluate`
without the severe steady-state `GetTexture` overhead, while remaining stable enough
for a 1920x1080 Windowed FSR Off gameplay comparison?

Hypothesis:

If the earlier FPS collapse was primarily the hot global
`RenderGraphResourceRegistry.GetTexture(TextureHandle&)` postfix, then using
`GetTexture` only to discover the first accepted Super Resolution tuple and driving
real evaluate from `DynamicResolutionHandler.Update(...)` should keep performance
near the cached no-evaluate result. If it still fails, the remaining problem is
likely the real evaluate submission boundary, resource lifetime, synchronization,
or output write location rather than tuple discovery overhead.

## Implementation

Added helper stage `dlss-user-rendering-cached-driver`.

Initial implementation:

- `Diagnostics.EnableDlssCachedTupleDriverProbe=true`.
- `Diagnostics.EnableDlssUserRenderingNoEvaluateProbe=false`.
- `DLSS.EnableDLSS=true`.
- The first accepted tuple is cached from the existing `GetTexture` oracle.
- Steady-state attempts are driven from the render-scale-control
  `DynamicResolutionHandler.Update(...)` postfix.
- `trackOutputFollowup=false` for cached-driver evaluate, so the output follow-up
  probe does not keep the `GetTexture` path hot after success.

Follow-up fix:

- The first implementation still allowed one low-level
  `TryRunDlssUserRendering(...)` evaluate from the Super Resolution input success
  path before the cached driver took over.
- Commit `6ac5212` moved that first real evaluate out of `GetTexture` too:
  all cached-driver real-evaluate paths now cache/arm in `GetTexture` and return,
  then submit evaluate only from `DynamicResolutionHandler.Update(...)`.

Verification before runtime:

- Release build passed with `0` warnings and `0` errors.
- `write-diagnostic-config.ps1 -Stage dlss-user-rendering-cached-driver -DryRun`
  generated the expected SDK-wrapper cached-driver config.
- `run-vrising-visual-comparison.ps1 -CandidateStage
  dlss-user-rendering-cached-driver -DryRun` planned
  `CandidateRequiresSdkWrapper=True` and `WaitForUserRendering=True`.
- `package-thunderstore.ps1` passed after adding the stage.
- `get-release-readiness-status.ps1 -Json` remained
  `DiagnosticPackageReady_MvpBlocked`, as expected.

## Runtime R1: First Cached Real-Evaluate Attempt

Run label: `cached-driver-evaluate-1080p-20260606-r1`.

Conditions:

- True `1920x1080` Windowed.
- V Rising `FsrQualityMode=Off`.
- Paired baseline loader versus `dlss-user-rendering-cached-driver`.
- SDK-wrapper native and `nvngx_dlss.dll` from
  `ref/NVIDIA-DLSS-310.6.0/nvngx_dlss.dll`.
- Protected local/private `11111` save, backed up before launch and restored after.
- Computer Use clicked Continue for baseline only; candidate exited before ready.

Baseline:

- Capture succeeded at `1920x1080`.
- Average FPS `203.698`.
- 1% low FPS `154.148`.
- P95 frame time `5.975 ms`.
- Average GPU utilization/power `97.222%` / `137.222 W`.

Candidate:

- Exited before manual ready/capture/performance.
- Windows Application Error at `2026-06-06 18:11:40`.
- Exception `0xc0000005`; faulting module was reported as `unknown`.
- Candidate log still showed successful SDK-wrapper evaluate through the cached
  driver up to `sequenceSuccesses=600`.

Important flaw in R1:

- `DLSS user rendering evaluate succeeded from RenderGraph GetTexture`: `1`.
- `DLSS cached tuple driver armed from`: `0`.
- `DLSS user rendering evaluate succeeded from DynamicResolutionHandler.Update
  postfix cached tuple driver`: `6` logged milestones.
- `DLSS evaluate output follow-up`: `12`.
- `RenderGraph GetTexture call #`: `0`.

Interpretation:

R1 was not a clean cached-driver evaluate result because the first evaluate still
occurred inside the `GetTexture` discovery path. That explained the output follow-up
activity and required the follow-up fix in commit `6ac5212`.

Cleanup:

- Helper restored loader config, ClientSettings, FSR mode, and release-safe native
  state.
- Save restore archived the changed save and restored the protected `11111` backup.
- After-restore save comparison reported `ChangeCount=0`.

## Runtime R2: First Evaluate Fully Deferred Out Of GetTexture

Run label: `cached-driver-evaluate-deferred-1080p-20260606-r1`.

Conditions:

- Same true `1920x1080` Windowed / V Rising FSR Off / SDK-wrapper DLSS runtime setup.
- Same protected `11111` save protocol.
- Baseline completed normally.
- Candidate exited before Continue/gameplay, so no candidate screenshot or
  performance sample exists.

Baseline:

- Capture succeeded at `1920x1080`.
- Average FPS `206.633`.
- 1% low FPS `156.428`.
- P95 frame time `5.843 ms`.
- Average GPU utilization/power `98.444%` / `143.054 W`.

Candidate:

- Exited before manual ready/capture/performance.
- Windows Application Error at `2026-06-06 18:19:03`.
- Exception `0xc0000005`.
- Faulting module:
  `C:\WINDOWS\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_c8bc842500fab35b\nvwgf2umx.dll`.
- Fault offset `0x00000000001e5ccf`.

Candidate log proof:

- `DLSS cached tuple driver diagnostic enabled`: `1`.
- `DLSS user rendering accepted tuple cached from`: `1`.
- `DLSS cached tuple driver armed from`: `1`.
- `DLSS user rendering evaluate succeeded from RenderGraph GetTexture`: `0`.
- `DLSS evaluate output follow-up`: `0`.
- `RenderGraph GetTexture call #`: `0`.
- `DLSS cached tuple driver invoked from`: `5` logged milestones.
- `DLSS user rendering evaluate succeeded from DynamicResolutionHandler.Update
  postfix cached tuple driver`: `7` logged milestones.
- No evaluate failed/blocked/skipped lines were logged.
- The sequence reached `sequenceSuccesses=600`, `sequenceEvaluates=600`, and
  `evaluateSuccesses=600`.
- After the first create/reset cost, stable native timing was about
  `evaluate=0.080-0.083 ms`, `total=0.085-0.089 ms`.

Cleanup:

- Helper restored loader config, ClientSettings, FSR mode, and release-safe native
  state.
- Save restore archived the changed save and restored the protected `11111` backup.
- Before restore there were `3` manifest differences from startup/game entry state;
  after restore `ChangeCount=0`.
- No V Rising process remained after cleanup.

## Conclusion

The cached driver real-evaluate stage proved the narrow implementation goal but
rejected the boundary for production use:

- The corrected path fully removed real evaluate and output follow-up from the
  `GetTexture` callback.
- It successfully submitted repeated DLSS SR evaluates from
  `DynamicResolutionHandler.Update(...)` using the cached `960x540 -> 1920x1080`
  tuple.
- It still crashed in NVIDIA's D3D11 user-mode driver before the candidate reached
  the manual-ready gameplay capture.

Therefore the next blocker is no longer the steady-state `GetTexture` hot hook. It
is the real evaluate submission boundary and resource lifetime/synchronization
around the cached tuple. `DynamicResolutionHandler.Update(...)` is acceptable as a
no-evaluate performance driver, but it is not proven safe as a real DLSS evaluate
boundary. The next route should move back toward an official HDRP/RenderGraph
upscale-pass-equivalent execution window, or another boundary that supplies
current-frame resources and command-buffer ordering comparable to HDRP's own
`DoDLSSPass -> DLSSPass.Render/ExecuteDLSS` path.
