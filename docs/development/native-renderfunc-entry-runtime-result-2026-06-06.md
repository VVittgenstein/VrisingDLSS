# Native RenderFunc Entry Runtime Result - 2026-06-06

Status: menu runtime proof passed.

## Question

Can the default-off `native-renderfunc-entry` no-op probe safely install a native
detour on the focused EASU RenderGraph render-function entry in V Rising, count
entries, and immediately call the original trampoline without crashing or
touching RenderGraph resources?

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage native-renderfunc-entry -DurationSeconds 75 -ArtifactLabel native-renderfunc-entry-1080p-menu-20260606-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

No gameplay input was sent. The test remained menu-only.

## Runtime Shape

- Game path: `C:\Software\VRising`
- Stage: `native-renderfunc-entry`
- Window: true `1920x1080` Windowed
- Graphics API: D3D11
- Duration: `75` seconds
- Crash event count: `0`
- Exited before window: `False`
- Closed by script: `True`
- Restored loader config: `True`
- Restored release-safe native DLL: `True`
- Restored client settings: `True`

Player log evidence:

- `Forcing GfxDevice: Direct3D 11`
- `graphicsDeviceType: Direct3D11`
- `SetResolution 1920, 1080, fullScreenMode Windowed`

## Artifacts

- `artifacts/runtime-logs/LogOutput-native-renderfunc-entry-1080p-menu-20260606-r1.log`
- `artifacts/runtime-logs/Analysis-native-renderfunc-entry-1080p-menu-20260606-r1.txt`
- `artifacts/runtime-logs/Player-native-renderfunc-entry-1080p-menu-20260606-r1.log`
- `artifacts/runtime-logs/ClientSettings-native-renderfunc-entry-1080p-menu-20260606-r1.before.json`

No WER artifact was produced because `CrashEventCount=0`.

## Analyzer Result

`Native RenderFunc Entry=Pass`

Evidence line:

```text
Native render-func entry count advanced: entryCount=1; pass="Edge Adaptive Spatial Upsampling"; candidatePointer=0x7FF8973EE1C0
```

## Log Summary

- Candidate observed lines: `82`
- Status lines: `92`
- Detour installed lines: `1`
- Count advanced lines: `1`
- Probe failed lines: `0`
- `RenderGraph GetTexture call #` lines: `0`
- Crash-like lines: `0`

Install sequence:

- compile `1`: EASU `method_ptr=0x7FF8973EE1C0`, observations `1`
- compile `2`: same pointer, observations `2`
- compile `3`: same pointer, observations `3`, detour installed
- compile `4`: `entryCount=1`, count advanced

The runtime metadata summary printed `methodName=unknown`, unlike the richer
renderfunc-metadata preflight logs. This does not invalidate the proof because
the runtime target was constrained by pass name/category and stable `method_ptr`,
then confirmed by native entry counter advancement.

## Interpretation

This proves the Il2CppInterop native detour ABI used by the no-op probe is safe
enough for a menu RenderGraph EASU render-function entry in this V Rising build.
It does not prove gameplay safety, resource access safety, DLSS evaluate safety,
or image correctness.

The probe still does not resolve resources, read pass data, touch command
buffers, call `GetTexture`, load DLSS, or evaluate DLSS.

## Next Step

Run the same default-off no-op probe in the protected `11111` gameplay fixture
at true `1920x1080` Windowed. The gameplay proof must use the save-protection
protocol, avoid movement/gameplay keys except the explicit UI navigation needed
to enter the fixture, and restore release-safe config/native/settings afterward.
