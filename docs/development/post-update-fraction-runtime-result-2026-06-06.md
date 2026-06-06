# Post-Update Fraction Runtime Result - 2026-06-06

Status: completed. V5 was a useful failed fallback diagnostic; v6 passed the
FSR Off `1920x1080` Windowed constructive tuple proof and the SDK-wrapper
`dlss-user-rendering` smoke proof.

## Question

With V Rising `FsrQualityMode=Off`, `DLSS.EnableDLSS=true`, SDK-wrapper local
runtime enabled, and the `11111` save entered at `1920x1080` Windowed, is
`DynamicResolutionHandler.m_CurrentFraction` the remaining field preventing HDRP
from allocating the main gameplay camera at `960x540`?

## V5 Result

Run label: `fsr-off-render-scale-1080p-software-fallback-v5-20260606`.

V5 forced `DynamicResolutionHandler.ForceSoftwareFallback()` and proved that the
fallback flag alone is not enough:

- `Render-scale control software fallback diagnostic`: `12`
- `SoftwareDynamicResIsEnabled=True`: `9`
- `HardwareDynamicResIsEnabled=False`: `12`
- `GetCurrentScale=1`: `12`
- `GetResolvedScale=(1.00, 1.00)`: `12`
- `CameraColor_960`: `0`
- `CameraColor_1920`: `752`
- `LowResDepthBuffer_960`: `114`
- `DLSS super-resolution input probe succeeded`: `0`
- `actualWidth=960`: `0`
- `actualWidth=1920`: `456`

Interpretation: software fallback was active, but the effective dynamic-resolution
fraction still stayed `1.0`. The remaining blocker was the handler's runtime
fraction/state, not another camera request or hardware dynamic-resolution toggle.

Cleanup passed. The `11111` save changed during gameplay entry, was archived, and
was restored from the pre-run backup with
`SaveCompareAfterRestore-fsr-off-render-scale-1080p-software-fallback-v5-20260606.json`
reporting `CompareStatus=Restored` and `ChangeCount=0`.

Operational pitfall: an initial restore script attempt used a wildcard with
`Copy-Item -LiteralPath`, leaving the active save directory empty before the final
comparison. The directory was immediately cleared and restored again by enumerating
each backup child path explicitly. The final comparison is the authoritative save
state and reports `ChangeCount=0`.

## V6 Code Change

After V5, `RenderScaleControlProbe` was tightened for the observed
`DynamicResolutionHandler.Update(...)` route:

- Log budget for software fallback diagnostics increased from `12` to `32`.
- Diagnostics now include `phase`, target fraction, selected private fields before
  and after mutation, and software/hardware/current/resolved scale readbacks.
- The `Update(...)` postfix now writes the active handler state directly:
  `m_Enabled=true`, `m_UseMipBias=true`, `m_CurrentCameraRequest=true`,
  `m_ForcingRes=true`, `m_ForceSoftwareFallback=true`,
  `m_MinScreenFraction=0.5`, `m_MaxScreenFraction=1`, and
  `m_CurrentFraction=0.5` for Performance-mode diagnostics.

This remains a guarded diagnostic/runtime-candidate bridge, not a release-ready
production abstraction.

## V6 Result

Run label: `fsr-off-render-scale-1080p-post-update-fraction-v6-20260606`.

Artifacts:

- `artifacts/gameplay-automation/Session-fsr-off-render-scale-1080p-post-update-fraction-v6-20260606.json`
- `artifacts/gameplay-automation/LogOutput-fsr-off-render-scale-1080p-post-update-fraction-v6-20260606.log`
- `artifacts/gameplay-automation/Analysis-fsr-off-render-scale-1080p-post-update-fraction-v6-20260606.txt`
- `artifacts/gameplay-automation/Cleanup-fsr-off-render-scale-1080p-post-update-fraction-v6-20260606.json`
- `artifacts/gameplay-automation/SaveCompareAfterRestore-fsr-off-render-scale-1080p-post-update-fraction-v6-20260606.json`

Automation and cleanup passed:

- Start session reached `Status=Ready` with `Stage=dlss-user-rendering`,
  SDK-wrapper native, local `nvngx_dlss.dll`, `SetClientResolution=true`,
  `SetClientWindowMode=true`, `ClientWindowMode=3`, and screenshot size
  `1920x1080`.
- Computer Use selected the real `VRising` window, clicked Continue once at the
  known `11111` menu entry, observed loading after about 20 seconds, and observed
  stable gameplay with HUD/character after about 65 seconds.
- No movement or gameplay keys were sent by automation.
- Stop session reported `Status=Pass`, `CrashEventCount=0`,
  `RestoredClientSettings=true`, `RestoredLoaderConfig=true`,
  `RestoredReleaseSafeNative=true`, and `RemainingVRisingProcessCount=0`.
- The `11111` save changed during gameplay entry, was archived, and was restored
  from the pre-run backup with `CompareStatus=Restored` and `ChangeCount=0`.

Runtime proof counts:

- `Render-scale control software fallback diagnostic`: `32`
- `phase=postfix`: `16`
- `fractionForcedInPostfix=True`: `16`
- `m_CurrentFraction=0.5`: `31`
- `GetCurrentScale=0.5`: `31`
- `GetResolvedScale=(0.50, 0.50)`: `31`
- `SoftwareDynamicResIsEnabled=True`: `31`
- `CameraColor_960`: `504`
- `CameraColor_1920`: `0`
- `DLSS super-resolution input probe succeeded`: `1`
- `output was not larger than render input`: `2` early candidates only
- `DLSS user rendering evaluate succeeded`: `35` log lines, with the last line
  reporting `sequenceSuccesses=9000`, `sequenceCreates=1`, `render=960x540`,
  `target=1920x1080`, and `evaluateSuccesses=9000`
- `DLSS user rendering blocked`: `0`
- `DLSS user rendering failed`: `0`
- `actualWidth=960`: `364`
- `actualWidth=1920`: `0`

Key evidence:

- The accepted Super Resolution tuple was
  `CameraColor=960x540`, `CameraDepthStencil=960x540`,
  `Motion Vectors=960x540`, and `Edge Adaptive Spatial Upsampling=1920x1080`,
  all on the same D3D11 device, for scale `(2.000x, 2.000x)`.
- `HDCamera` observations switched to `actualWidth=960,actualHeight=540` while
  the final viewport stayed `1920x1080`.
- `DLSS user rendering evaluate succeeded` reached a persistent one-feature
  path with `sequenceCreates=1`, `recreated=no`, and successful SDK-wrapper
  evaluate calls.

## Current Meaning

V6 is the first local proof that the mod can keep V Rising FSR Off, control HDRP's
effective render scale itself, expose the expected `960x540 -> 1920x1080`
Super Resolution tuple, and run the `dlss-user-rendering` candidate repeatedly
against that tuple.

This does not finish the playable MVP. The remaining gate is visual correctness,
performance value, resize/reset behavior, safe fallback, productionizing the
render-scale intervention, and a clean DLSS runtime distribution strategy.
