# Troubleshooting

## Plugin Does Not Load

Check:

- V Rising is installed.
- BepInExPack V Rising 1.733.2 is installed.
- The first BepInEx run completed and generated `BepInEx/interop`.
- `VrisingDLSS.Plugin.dll` is under `BepInEx/plugins/VrisingDLSS/`.
- `BepInEx/LogOutput.log` exists.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect-vrising-install.ps1
```

To check what the local install helper would copy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath "C:\path\to\VRising" -DryRun
```

To check what the BepInExPack helper would copy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath "C:\path\to\VRising" -DryRun
```

To summarize the current BepInEx log:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\analyze-bepinex-log.ps1 -GamePath "C:\path\to\VRising"
powershell -ExecutionPolicy Bypass -File scripts\get-runtime-validation-status.ps1 -GamePath "C:\path\to\VRising"
```

## Native Bridge Does Not Load

Check:

- `VrisingDLSS.Native.dll` is next to `VrisingDLSS.Plugin.dll`.
- The native DLL is x64.
- The Visual C++ runtime needed by the native bridge is installed.

Enable `EnableNativeBridgeSmokeTest` in the generated config only for diagnostics.

## Render Thread Smoke Test Does Not Advance

`EnableRenderThreadSmokeTest` sends one Unity plugin event through `CommandBuffer.IssuePluginEvent`.

Check:

- `VrisingDLSS.Native.dll` is next to `VrisingDLSS.Plugin.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `2` or newer.
- The log contains `Running native render-thread smoke test`.
- The log can find Unity `CommandBuffer` and `Graphics` types.

If the callback count does not advance immediately, keep this test disabled for normal play and capture the surrounding `BepInEx/LogOutput.log` lines. The smoke test is diagnostic only and does not initialize DLSS.

## D3D11 Texture Probe Fails

`EnableD3D11TextureProbe` creates one temporary RenderTexture and passes its native pointer to the native bridge.

Check:

- The game is running on DirectX 11.
- `EnableNativeBridgeSmokeTest` logs bridge API version `3` or newer.
- `EnableRenderThreadSmokeTest` passes first.
- The log contains a non-zero temporary RenderTexture native pointer.

If the probe reports `QueryInterface(ID3D11Resource)` failure, the game may not be using D3D11 for that run or Unity returned a backend-specific texture pointer that this bridge version does not support.

## Frame Resource Probe Does Not Find Textures

`EnableFrameResourceProbe` patches candidate HDRP `CustomVignette.Render` methods and logs source/destination arguments plus global `_CameraDepthTexture` and `_CameraMotionVectorsTexture` native pointers.

Check:

- `EnableHarmonyCallProbe` confirms `CustomVignette.Render` is called.
- `EnableD3D11TextureProbe` passes first.
- The log contains `Frame resource probe patched`.
- The render method signature still exposes source/destination resources or RTHandle-like objects.

If source/destination pointers are found but depth or motion pointers are missing, the current injection point may be too early/late or V Rising may not have populated those global textures for that frame. Keep DLSS evaluate disabled until all required inputs are frame-aligned.

## DLSS Runtime Probe Fails

`EnableDlssRuntimeProbe` loads and immediately releases the configured `DLSS.DlssRuntimePath`.

Check:

- The path points to a user-supplied production `nvngx_dlss.dll`.
- The path is absolute, or relative to `BepInEx/plugins/VrisingDLSS/`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `4` or newer.
- The file is not from a PureDark package.

If the probe reports missing known NGX exports, leave DLSS disabled and try a production runtime from an approved NVIDIA distribution path. This probe does not initialize DLSS and does not prove the game can evaluate DLSS frames.

## DLSS Init/Query Probe Is Blocked Or Fails

`EnableDlssInitQueryProbe` creates one temporary RenderTexture and gets its D3D11 device. In the current source-only build, it then checks whether the configured production `nvngx_dlss.dll` exposes the helper exports needed for NGX capability query.

Check:

- `EnableD3D11TextureProbe` passes first.
- `EnableDlssRuntimeProbe` passes first.
- `DLSS.DlssApplicationId` is decimal or `0x`-prefixed hexadecimal.
- `EnableNativeBridgeSmokeTest` logs bridge API version `5` or newer.
- The runtime is a current production `nvngx_dlss.dll` from an approved NVIDIA distribution path.

If the log says `DLSS init/query probe blocked`, the current native build does not include the optional NVIDIA SDK wrapper path. Re-running the same release-safe diagnostic with only `nvngx_dlss.dll` is expected to produce the same blocked result. Use the local SDK-wrapper research build when validating full capability query.

If NGX init succeeds but `SuperSampling.Available=0`, the runtime/device/driver path is reachable but DLSS is unavailable for that machine or configuration. If init returns a failure result, keep DLSS disabled and preserve the full status line from `BepInEx/LogOutput.log`.

## DLSS Optimal-Settings Probe Is Blocked Or Fails

`EnableDlssOptimalSettingsProbe` creates one temporary RenderTexture to get a D3D11 device, then asks the optional SDK-wrapper native path for DLSS-recommended render dimensions for a 3840x2160 output target and the selected `DLSS.QualityMode`.

Check:

- `EnableD3D11TextureProbe` passes first.
- `EnableDlssRuntimeProbe` passes first.
- `EnableDlssInitQueryProbe` passes first in the same SDK-wrapper build route.
- `EnableNativeBridgeSmokeTest` logs bridge API version `12` or newer.
- The runtime is a current production `nvngx_dlss.dll` from an approved NVIDIA distribution path.

If the log says `DLSS optimal-settings probe blocked`, the current native bridge was built without the optional NVIDIA SDK wrapper path. If the query fails, preserve the full status line because it includes output size, quality mode, NGX result, cleanup results, and any returned render-size fields.

## DLSS Feature Create Probe Is Blocked Or Fails

`EnableDlssFeatureCreateProbe` creates one temporary RenderTexture to get a D3D11 device/context, then asks the optional SDK-wrapper native path to create and immediately release a DLSS SuperSampling feature.

Check:

- `EnableD3D11TextureProbe` passes first.
- `EnableDlssRuntimeProbe` passes first.
- `EnableDlssInitQueryProbe` passes first in the same SDK-wrapper build route.
- `EnableNativeBridgeSmokeTest` logs bridge API version `6` or newer.
- The runtime is a current production `nvngx_dlss.dll` from an approved NVIDIA distribution path.

If the log says `DLSS feature create probe blocked`, the current native bridge was built without the optional NVIDIA SDK wrapper path. If create succeeds but release, parameter destruction, or shutdown fails, keep DLSS disabled and preserve the full status line. This probe still does not evaluate a frame or prove image correctness.

## DLSS Evaluate Input Probe Is Blocked Or Fails

`EnableDlssEvaluateInputProbe` reuses the frame-resource hook to collect color/output/depth/motion native texture pointers and validate them in the native bridge. It does not load DLSS or evaluate a frame.

Check:

- `EnableFrameResourceProbe` can patch and call a frame-resource method.
- A local/private gameplay scene is running, not only the main menu.
- The log shows source/output-like frame arguments from `CustomVignette.Render`.
- `_CameraDepthTexture` and `_CameraMotionVectorsTexture` both produce non-zero native pointers.
- `EnableNativeBridgeSmokeTest` logs bridge API version `7` or newer.

If the log says `DLSS evaluate input probe blocked`, preserve the surrounding frame-resource lines. Missing motion vectors usually means the current scene/settings/hook point is not enough for DLSS evaluate yet. If the probe fails after all four pointers are present, the native status line should identify a D3D11 resource, device, or dimension mismatch.

## DLSS Super Resolution Input Probe Does Not Pass

`EnableDlssSuperResolutionInputProbe` uses the same passive RenderGraph `GetTexture` stream as Stage 8A, but it keeps searching until color/depth/motion render inputs are smaller than the output target. It does not load DLSS or evaluate a frame.

Check:

- `EnableDlssEvaluateInputProbe` can already pass through the passive RenderGraph route.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows candidate lines beginning with `DLSS super-resolution input probe candidate #`.
- If candidates say `output was not larger than render input`, keep the game running longer or use a scene/settings combination where HDRP dynamic resolution drops below the output resolution.
- A passing status should include `sameDevice=yes`, matching color/depth/motion dimensions, a larger output size, and `scale=`.

If Stage 8E passes but DLSS is still not visible, that is expected in the current scaffold. Stage 8E proves resource sizing only; visible write-back and image correctness are still separate MVP work.

## DLSS Super Resolution Evaluate Probe Is Blocked Or Fails

`EnableDlssSuperResolutionEvaluateProbe` waits for Stage 8E, then runs one guarded SDK-wrapper DLSS evaluate against the render-input-smaller-than-output tuple. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows `DLSS super-resolution evaluate probe candidate #`.
- A passing status should include `render=` smaller than `target=`, `create=0x00000001`, `evaluate=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.

If this stage passes but DLSS is still not visible, that is expected. Stage 8F proves the SR-sized NGX evaluate call, not the normal-user visible rendering path.

## DLSS Super Resolution Persistent Evaluate Probe Is Blocked Or Fails

`EnableDlssSuperResolutionPersistentEvaluateProbe` waits for Stage 8E, then runs a guarded SDK-wrapper persistent DLSS evaluate against the render-input-smaller-than-output tuple. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `10` or newer.
- The log shows `DLSS super-resolution persistent evaluate probe candidate #`.
- A passing status should include `render=` smaller than `target=`, `evaluateCount=`, matching `evaluateSuccesses=`, `create=0x00000001`, `evaluateLast=0x00000001`, `release=0x00000001`, `destroy=0x00000001`, and `shutdown=0x00000001`.

If this stage passes but DLSS is still not visible, that is expected. Stage 8G proves repeated evaluates on one DLSS feature for the SR-sized tuple, not the normal-user visible rendering path.

## DLSS Super Resolution Frame-Sequence Evaluate Probe Is Blocked Or Fails

`EnableDlssSuperResolutionFrameSequenceEvaluateProbe` waits for Stage 8E, then runs guarded SDK-wrapper DLSS evaluates across multiple RenderGraph callbacks while keeping one DLSS feature alive. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows `DLSS super-resolution frame-sequence evaluate probe candidate #`.
- A passing status should include `sequenceCreates=1`, `sequenceEvaluates=3`, `evaluateSuccesses=3`, `recreated=no` on later callbacks, `feature=yes`, `evaluateLast=0x00000001`, and a later `DLSS super-resolution frame-sequence shutdown succeeded` line with release/destroy/shutdown all `0x00000001`.

If this stage passes but DLSS is still not visible, that is expected. Stage 9A proves cross-callback feature reuse for the SR-sized tuple, not the normal-user visible rendering path.

## DLSS Visible Write-back Probe Is Blocked Or Fails

`EnableDlssVisibleWritebackProbe` waits for Stage 8E, then repeatedly evaluates DLSS into the selected Super Resolution output target across multiple RenderGraph callbacks. It is disabled by default and requires a local/private SDK-wrapper research build.

Check:

- Stage 8E passes first in the same run.
- `DLSS.DlssRuntimePath` points to a local research `nvngx_dlss.dll`.
- `EnableNativeBridgeSmokeTest` logs bridge API version `11` or newer.
- The log shows `DLSS visible write-back probe candidate #`.
- A passing status should include `sequenceEvaluates=30`, `evaluateSuccesses=30`, `feature=yes`, `evaluateLast=0x00000001`, `outputResourceName=Edge Adaptive Spatial Upsampling` when the known SR tuple is selected, and a later `DLSS visible write-back shutdown succeeded` line with release/destroy/shutdown all `0x00000001`.
- If `KeepDlssVisibleWritebackProbeRunning=true` is set for a visual comparison run, the success line should include `keepRunning=True` and the probe should keep evaluating after `sequenceSuccesses=30/30` until cleanup or the hold attempt limit.

If this stage passes but the image looks wrong, preserve screenshots and the archived BepInEx log. Stage 10A proves the guarded visible-path candidate ran; it does not by itself prove image correctness, jitter correctness, resize/reset behavior, or final normal-user fallback behavior.

## RenderGraph Pass-Map Probe

`EnableRenderGraphPassMapProbe` is disabled by default and is read-only. It patches
only `RenderGraph.OnPassAdded(RenderGraphPass)` and logs capped `RenderGraph pass map
#` lines with pass name, pass type, and a coarse category. It does not resolve
textures, does not call `GetTexture`, does not inject a pass, does not load DLSS, and
does not evaluate a frame.

Use this before any further RenderGraph boundary experiment when you need pass-name
evidence for a narrower official-upscaler-equivalent route:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-pass-map -DurationSeconds 240 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

This is still a local/private diagnostic. A useful run should produce
`RenderGraph pass map #` lines for postprocess/upscale/final candidates without a
matching Windows crash event. It is not an evaluate/resource boundary by itself.

Current V Rising evidence: `rendergraph-pass-map-1080p-menu-20260606-r1` and
`rendergraph-pass-map-gameplay-1080p-20260606-r1` patched safely and did not crash,
but produced `0` pass-map lines. Do not rerun this stage unchanged for the current
game build; it is retained only as a default-off, low-risk probe for other Unity
runtime shapes.

## RenderGraph Pass-List Probe

`EnableRenderGraphPassListProbe` is disabled by default and is read-only. It
patches only `RenderGraph.CompileRenderGraph(int)` and logs capped
`RenderGraph pass-list compile #` / `RenderGraph pass-list entry #` lines from
`m_RenderPasses`. It does not resolve textures, does not call `GetTexture`, does
not inject a pass, does not load DLSS, and does not evaluate a frame.

Use this when `rendergraph-pass-map` produces no pass names and the next question
is whether compile-time `m_RenderPasses` can reveal postprocess/upscale/final pass
names before `ClearRenderPasses()`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-pass-list -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

A useful run should produce `RenderGraph pass-list compile #` lines and, ideally,
focused `entry #` lines with categories such as `upscale`, `postprocess`, `final`,
or `dlss`. Treat zero pass-list signal or any WER/IL2CPP/coreclr crash as a failed
route and preserve the archived log.

Current evidence: `rendergraph-pass-list-1080p-menu-20260606-r2` and
`rendergraph-pass-list-gameplay-1080p-20260606-r1` both patched cleanly at true
`1920x1080` Windowed with no WER crash. The gameplay proof used the protected
`11111` save, sent no movement keys, restored the save to `ChangeCount=0`, and
logged analyzer `RenderGraph Pass List=Pass`, `143` compile summary lines, `540`
entry lines, `0` `RenderGraph GetTexture call #` lines, and focused categories
including `upscale`, `postprocess`, `final`, and `temporal`. It repeatedly observed
`Uber Post -> Edge Adaptive Spatial Upsampling -> Final Pass`. Do not rerun this
stage unchanged; the next experiment should be a focused resource-declaration-only
snapshot for those passes.

## RenderGraph Pass-Declarations Probe

`EnableRenderGraphPassResourceDeclarationProbe` is disabled by default and is
read-only. It reuses the safe `CompileRenderGraph(int)` observation point and logs
capped `RenderGraph pass declaration #` lines for focused passes only. It summarizes
pass-local `colorBuffers`, `depthBuffer`, `resourceReadLists`, and
`resourceWriteLists` handle declarations.

It does not call `GetTexture`, does not call `GetTextureResource`, does not resolve
resource names, does not resolve native texture pointers, does not inject a pass,
does not load DLSS, and does not evaluate a frame.

Use it after pass-list proof when the next question is the declaration shape around
motion vectors, `Uber Post`, `Edge Adaptive Spatial Upsampling`, and `Final Pass`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-pass-declarations -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

A useful run should produce `RenderGraph pass declaration #` lines and `0` broad
`RenderGraph GetTexture call #` lines. Treat no declaration lines, any
`RenderGraph pass-list logging failed`, or any WER/IL2CPP/coreclr crash as a failed
route.

Current evidence: menu smoke `rendergraph-pass-declarations-1080p-menu-20260606-r1`
passed at true `1920x1080` Windowed with `297` declaration lines, `0` broad
GetTexture logs, and no WER crash. A later startup/window-only session also
emitted declaration signal (`399` lines, `0` broad GetTexture logs) and restored
the protected save with `ChangeCount=0`, but it did not enter gameplay. Protected
gameplay proof `rendergraph-pass-declarations-gameplay-1080p-20260606-r2` then
passed in the `11111` fixture with `529` declaration lines, `0` broad GetTexture
logs, no WER crash, no movement keys, and save restore `ChangeCount=0`. Do not
rerun this stage unchanged; use the pass-data snapshot probe for the next
read-only mapping step.

## RenderGraph Pass-Data Snapshot Probe

`EnableRenderGraphPassDataSnapshotProbe` is disabled by default and is read-only.
It reuses the safe `CompileRenderGraph(int)` observation point and logs capped
`RenderGraph pass-data snapshot #` lines for focused `Uber Post`,
`Edge Adaptive Spatial Upsampling`, `Final Pass`, and DLSS pass-data shapes.

It reads only pass-data scalar fields and `TextureHandle.handle` summaries. It
does not call `GetTexture`, does not call `GetTextureResource`, does not resolve
resource names, does not resolve native texture pointers, does not patch generated
render functions, does not touch command buffers, does not load DLSS, and does not
evaluate a frame.

Use it after declaration proof when the next question is whether pass-data fields
match the declaration chain:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-pass-data -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

A useful run should produce `RenderGraph pass-data snapshot #` lines with
`memberCount=`, `EASUData.source/destination`, EASU input/output dimensions, and
`FinalPassData.source/destination`, while keeping `RenderGraph GetTexture call #`
at `0`. Treat no `memberCount=` lines, any `data=not found`, any
`RenderGraph pass-list logging failed`, or any WER/IL2CPP/coreclr crash as a
failed route.

Current evidence: menu smoke `rendergraph-pass-data-1080p-menu-20260606-r3`
passed at true `1920x1080` Windowed with `248` pass-data snapshot lines, `248`
`memberCount=` lines, `0` `data=not found`, `0` typed-read failures, `0`
GetTexture logs, and no WER crash. Protected gameplay proof
`rendergraph-pass-data-gameplay-1080p-20260606-r1` then passed in the `11111`
fixture with `321` snapshot lines, `321` `memberCount=` lines, `0`
`data=not found`, `0` typed-read failures, `0` broad GetTexture logs, no WER
crash, no movement keys, and save restore `ChangeCount=0`. The gameplay summary
found `73` complete chains; `73/73` matched
`Uber.destination == EASU.source` and `73/73` matched
`EASU.destination == Final.source`. All complete gameplay chains reported Uber
`1920x1080`, EASU `input=1920x1080 output=1920x1080`, and Final
`performUpsampling=True`, `dynamicResIsOn=True`, and
`dynamicResFilter=EdgeAdaptiveScalingUpres`.

## RenderGraph RenderFunc Metadata Probe

`EnableRenderGraphPassRenderFuncMetadataProbe` is disabled by default and is
read-only. It reuses the safe `CompileRenderGraph(int)` observation point and
logs focused pass `renderFunc` delegate metadata. It does not call the delegate,
does not patch generated render functions, does not receive `RenderGraphContext`,
does not resolve resources or native texture pointers, and does not evaluate
DLSS.

Use it after pass-data proof when the next question is which generated render
function methods the focused pass chain points to:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-renderfunc-metadata -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Current evidence: menu proof
`rendergraph-renderfunc-metadata-1080p-menu-20260606-r3` passed at true
`1920x1080` Windowed with `CrashEventCount=0`, analyzer
`RenderGraph RenderFunc Metadata=Pass`, `248` metadata lines, `0`
`renderFunc=not found`, `0` metadata failures, `0` broad GetTexture logs, and
restored settings. It mapped `Uber Post` to `<UberPass>b__1060_0`, `Edge
Adaptive Spatial Upsampling` to `<EdgeAdaptiveSpatialUpsampling>b__1066_0`, and
`Final Pass` to `<FinalPass>b__1069_0`.

Protected gameplay proof
`rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1` then passed in the
`11111` fixture with one Computer Use Continue click, no movement keys,
`1920x1080` Windowed gameplay, analyzer `RenderGraph RenderFunc Metadata=Pass`,
`300` metadata lines, `0` `renderFunc=not found`, `0` metadata failures, `0`
broad GetTexture logs, no WER crash, cleanup restore, and save restore
`ChangeCount=0`.

Do not patch those generated methods or use this as evaluate-boundary evidence.
Do not rerun this stage unchanged; use it only as a pass-name/method-identity map
for a later source-backed execution-boundary design.

## RenderGraph Compiled Pass Info Probe

`EnableRenderGraphCompiledPassInfoProbe` is disabled by default and is
read-only. It reuses the safe `CompileRenderGraph(int)` observation point and
logs focused `CompiledPassInfo` state for postprocess/upscale/final candidates:
culling flags, side-effect/ref-count/sync state, and resource create/release
list counts.

It does not resolve resources, does not call `GetTexture`, does not inspect
native texture pointers, does not touch command buffers, does not patch render
functions, and does not evaluate DLSS.

Use it only when the next question is whether the focused pass chain survives
compile/culling and where its resource lifetime lists sit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-compiled-pass-info -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

Current status: menu runtime-validated. Run
`rendergraph-compiled-pass-info-1080p-menu-20260606-r2` passed at true
`1920x1080` Windowed with analyzer `RenderGraph Compiled Pass Info=Pass`,
`299` focused compiled-pass-info lines, `compiledPassInfos=not found=0`,
`RenderGraph GetTexture call #=0`, and `CrashEventCount=0`. The probe reads
`m_CurrentCompiledGraph.compiledPassInfos` in this V Rising build. Do not rerun
this stage unchanged unless a Unity/V Rising update or code regression changes
the RenderGraph map.

## Native RenderFunc Entry Preflight

`scripts\get-native-renderfunc-entry-preflight.ps1` is a static/log preflight
for the `native-renderfunc-entry` no-op probe. It does not start
V Rising, install a native detour, resolve RenderGraph resources, touch command
buffers, or evaluate DLSS.

Use it only after a valid `rendergraph-renderfunc-metadata` proof exists:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\get-native-renderfunc-entry-preflight.ps1 -DeepInspect -Json
```

Current status: `PreflightPass_DesignOnly`. The protected gameplay metadata log
showed stable focused `method_ptr` values for `Uber Post`, `Edge Adaptive
Spatial Upsampling`, and `Final Pass`, and deep inspection confirmed local
`NativeDetour(IntPtr, IntPtr)`, Il2Cpp `MethodPointer`, and Harmony IL2CPP
MethodPointer detour/`OriginalTrampoline` evidence. This is not runtime hook
proof.

`Diagnostics.EnableNativeRenderFuncEntryProbe` is now implemented separately and
defaults to `false`. The helper stage is `native-renderfunc-entry`; it targets
only the EASU render-function `method_ptr`, waits for three stable observations,
installs an Il2CppInterop native detour, increments one counter, and immediately
calls the original trampoline. Menu runtime proof passed at true `1920x1080`
Windowed with `Native RenderFunc Entry=Pass`, no crash, no `GetTexture`, and
counter advancement. Protected `11111` gameplay proof also passed with final
`entryCount=776`, no crash, no `GetTexture`, and save restore `ChangeCount=0`.
This is still not resource/command-buffer/evaluate proof. See
`docs/development/native-renderfunc-entry-probe-implementation-2026-06-06.md`.
Runtime result:
`docs/development/native-renderfunc-entry-runtime-result-2026-06-06.md`.
Gameplay result:
`docs/development/native-renderfunc-entry-gameplay-result-2026-06-06.md`.

`Diagnostics.EnableNativeRenderFuncArgumentProbe` is implemented separately and
defaults to `false`. The helper stage is `native-renderfunc-args`; it reuses the
focused EASU entry detour only to sample raw callback argument pointer values
(`thisPtr`, `passDataPtr`, `renderGraphContextPtr`, `methodInfoPtr`) with atomic
counters and last-pointer snapshots. It does not dereference pointers, resolve
textures, call `GetTexture`, touch command buffers, or evaluate DLSS. The first
runtime proof is menu-only at true `1920x1080` Windowed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-args -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Expected analyzer line: `Native RenderFunc Args=Pass`. Treat this as argument
shape evidence only; it is not resource, command-buffer, or evaluate proof.
Menu runtime proof `native-renderfunc-args-1080p-menu-20260606-r1` passed; see
`docs/development/native-renderfunc-args-runtime-result-2026-06-06.md`.
Protected `11111` gameplay proof
`native-renderfunc-args-gameplay-1080p-20260606-r1` also passed with no movement
keys and save restore `ChangeCount=0`; see
`docs/development/native-renderfunc-args-gameplay-result-2026-06-06.md`.
The next step is a separate default-off resource-identity follow-up, not a rerun
of the same args stage.

`Diagnostics.EnableNativeRenderFuncResourceIdentityProbe` is implemented
separately and defaults to `false`. The helper stage is
`native-renderfunc-resource-identity`; it reuses the focused EASU entry/args
detour only to correlate the latest raw native `passDataPtr` with the managed
EASU pass-data object observed from `CompileRenderGraph(int)` and focused
managed `source` / `destination` TextureHandle identity. It does not dereference
native callback pointers, resolve textures, call `GetTexture`, touch command
buffers, patch generated render funcs through Harmony, or evaluate DLSS. The
first runtime proof must be menu-only at true `1920x1080` Windowed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-identity -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Expected analyzer line: `Native RenderFunc Resource Identity=Pass`. Treat this
as resource-identity correlation evidence only; it is still not command-buffer
or evaluate proof.

Menu runtime proof
`native-renderfunc-resource-identity-1080p-menu-20260607-r1` passed at true
`1920x1080` Windowed; see
`docs/development/native-renderfunc-resource-identity-runtime-result-2026-06-07.md`.
Protected `11111` gameplay proof
`native-renderfunc-resource-identity-gameplay-1080p-20260607-r1` also passed
with no movement keys and save restore `ChangeCount=0`; see
`docs/development/native-renderfunc-resource-identity-gameplay-result-2026-06-07.md`.
This remains resource-identity proof only; do not treat it as command-buffer,
texture-resolution, or DLSS evaluate proof.

`Diagnostics.EnableNativeRenderFuncResourceTupleProbe` is implemented separately
and defaults to `false`. The helper stage is `native-renderfunc-resource-tuple`;
it reuses the focused EASU entry/args/resource-identity path and formats the
matched managed `EASUData` into tuple metadata: input/output dimensions plus
focused `source` / `destination` TextureHandle resource identity. It does not
dereference native callback pointers, resolve textures, call `GetTexture`, touch
command buffers, patch generated render funcs through Harmony, or evaluate DLSS.
Menu runtime proof passed at true `1920x1080` Windowed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-tuple -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Analyzer line: `Native RenderFunc Resource Tuple=Pass`. Evidence:
`passDataMatches=True`, `tupleReady=True`, `input=1920x1080`,
`output=1920x1080`, focused `source` / `destination` TextureHandles,
`RenderGraph GetTexture call #=0`, actual DLSS/NGX evaluate/probe `0`, and
`CrashEventCount=0`. See
`docs/development/native-renderfunc-resource-tuple-runtime-result-2026-06-07.md`.

Protected `11111` gameplay proof also passed with the same safety boundary:
Computer Use clicked Continue once at `(205, 354)`, sent no movement keys,
observed gameplay HUD/character/action bar, analyzer reported
`Native RenderFunc Resource Tuple=Pass`, `GetTexture=0`, actual DLSS/NGX
evaluate/probe `0`, `CrashEventCount=0`, and save restore `ChangeCount=0`. See
`docs/development/native-renderfunc-resource-tuple-gameplay-result-2026-06-07.md`.

Treat this as tuple metadata proof only; it is still not actual texture/resource
resolution, command-buffer, or evaluate proof. The next engineering step is a
separately guarded resource-resolution preflight, default-off and menu-first.

## RenderGraph Execute-Delegate Probe

`EnableRenderGraphExecuteDelegateProbe` is disabled by default and is read-only.
It patches only closed generic `RenderGraphPass.GetExecuteDelegate<TPassData>()`
methods for focused HDRP pass data (`DLSSData`, `UberPostPassData`, `EASUData`,
and `FinalPassData`).

It records whether focused passes reach the execution-layer delegate lookup, plus
pass metadata and pass-data scalar/TextureHandle summaries. It does not call the
returned delegate, does not wrap render functions, does not receive
`RenderGraphContext`, does not touch command buffers, does not resolve resources
or native texture pointers, and does not evaluate DLSS.

Use it after the pass-data gameplay proof when the next question is whether the
same focused pass chain reaches execution-layer code:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-execute-delegate -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

The first runtime validation was menu-only at `1920x1080 Windowed`. It patched
four closed generic methods and ran for the full diagnostic window with
`CrashEventCount=0`, restored settings, and `RenderGraph GetTexture call #=0`,
but emitted zero focused `RenderGraph execute-delegate #` lines. Treat that as
patch-stability evidence only. Do not rerun this stage unchanged, and do not
attempt protected `11111` gameplay proof unless a later implementation first
produces focused menu execute-delegate lines with `memberCount=`.

## RenderGraph Pass-Boundary Probe

`EnableRenderGraphPassBoundaryProbe` is disabled by default and is high-risk research-only. It patches only `RenderGraph.PreRenderPassExecute(...)` and logs capped pass metadata: pass name, pass type, a coarse category, and safe `CompiledPassInfo` fields. In the standalone helper stage it does not resolve textures, does not call `GetTexture`, does not load DLSS, and does not evaluate a frame.

The first 2026-06-06 runtime proof rejected this boundary for normal diagnostics: the method patched successfully, no `RenderGraph pass boundary #` lines were emitted, and V Rising crashed during startup with Windows Application Error `coreclr.dll` `0xc0000005` before gameplay/Continue. Do not use this stage except for deliberate crash-recovery research:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\path\to\VRising" -Stage rendergraph-pass-boundary -DurationSeconds 240 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

For any deliberate rerun, back up and restore the protected `11111` save. A useful run would need `RenderGraph pass boundary #` lines for upscaler/final/postprocess candidates without a matching Windows crash event, but the current evidence says this route is unsafe in V Rising's IL2CPP build.

## DLSSPass Resource Helper Probe

`EnableDlssPassResourceProbe` is disabled by default. It patches only `DLSSPass.GetViewResources` and `DLSSPass.GetCameraResources`, then logs any returned source/output/depth/motion-vector `Texture` native pointers. It does not patch `DLSSPass.Render`, does not load DLSS, and does not evaluate a frame.

Use this only as a deliberate short local/private test:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath "C:\path\to\VRising" -Stage dlsspass-resource
```

If the game closes immediately after patching these helper methods, leave `EnableDlssPassResourceProbe=false` and keep using the safer RenderGraph materialization route. If the log shows all four resource-helper pointers, preserve those lines before trying any run that also enables `EnableDlssEvaluateInputProbe`.

## Hook Targets Are Missing

If the hook probe logs missing `CustomVignette`, `HDCamera`, or `HDRenderPipeline`, the current game/HDRP version likely differs from the 2022 PureDark-era assumptions.

Next steps:

- Inspect `BepInEx/interop` for HDRP assembly names.
- Search for similar type names under `Unity.RenderPipelines.HighDefinition.Runtime.dll`.
- Keep the first runtime test read-only until target methods are confirmed.

## Harmony Call Probe Does Not Patch

`EnableHarmonyCallProbe` is disabled by default. Only enable it after the basic hook probe has found candidate methods.

Check:

- BepInEx is installed and started successfully.
- The log contains Harmony or HarmonyX runtime assemblies.
- The hook probe found the target methods before the Harmony call probe ran.

If the log says the Harmony runtime shape was not recognized, leave `EnableHarmonyCallProbe=false` and capture the loaded assembly list from `BepInEx/LogOutput.log`.

Do not combine `EnableHarmonyCallProbe=true` with Stage 8A diagnostics. The `dlss-evaluate-inputs` helper intentionally leaves it disabled because broad Harmony call logging previously patched `DLSSPass.Render` and crashed V Rising in `coreclr.dll` with `0xc00000fd`. Use `write-diagnostic-config.ps1 -Stage harmony-call` as a separate short run only.

## Do Not Mix With PureDark Files

Remove these if they are next to this plugin:

- `PDPerfPlugin.dll`
- `PerfMod.dll`
- PureDark package folders

This clean-room project does not use them.

## Thunderstore Package Fails Boundary Check

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check-release-boundary.ps1
```

The package must not include third-party runtime DLLs unless a release review explicitly approves them.
