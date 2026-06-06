# Native RenderFunc Entry Preflight - 2026-06-06

Status: preflight passed. This is design evidence only; no native detour was
installed and no game runtime was launched by this preflight. A separate
default-off runtime probe was implemented afterward; see
`docs/development/native-renderfunc-entry-probe-implementation-2026-06-06.md`.

## Question

Before implementing a `native-renderfunc-entry` no-op probe, do we have enough
local evidence that:

- focused HDRP render-function delegate pointers are stable in V Rising gameplay;
- BepInEx/Il2CppInterop exposes a reversible native detour primitive;
- Il2Cpp method metadata exposes a native `MethodPointer` field comparable to
  what Harmony's IL2CPP backend patches?

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\get-native-renderfunc-entry-preflight.ps1 -DeepInspect -Json
```

The script does not start V Rising. It reads the latest archived
`rendergraph-renderfunc-metadata` log and optionally decompiles local BepInEx
core assemblies with `ilspycmd`.

## Input Evidence

Metadata log:

`artifacts/gameplay-automation/LogOutput-rendergraph-renderfunc-metadata-gameplay-1080p-20260606-r1.log`

This log came from the already validated protected `11111` gameplay proof:

- true `1920x1080` Windowed;
- `CrashEventCount=0`;
- `RenderGraph RenderFunc Metadata=Pass`;
- `RenderGraph GetTexture call #=0`;
- save restored with `ChangeCount=0`.

## Result

`Status=PreflightPass_DesignOnly`

Focused render-function metadata:

| Pass | Entries | Method | Token | method_ptr | method | Evidence |
| --- | ---: | --- | --- | --- | --- | --- |
| `Uber Post` | 76 | `<UberPass>b__1060_0` | `100664386` | `0x7FF8E91BC9F0` | `0x1AB58FFD7E8` | stable; `invoke_impl == method_ptr` |
| `Edge Adaptive Spatial Upsampling` | 75 | `<EdgeAdaptiveSpatialUpsampling>b__1066_0` | `100664389` | `0x7FF8E91BE1C0` | `0x1AB58FFD8F0` | stable; `invoke_impl == method_ptr` |
| `Final Pass` | 149 | `<FinalPass>b__1069_0` | `100664390` | `0x7FF8E91BE7F0` | `0x1AB58FFD948` | stable; `invoke_impl == method_ptr` |

The shared `method_code=0x1AC129F7560` across all three focused delegates is not
the target entry address. Treat `method_ptr` as the candidate native entry, not
`method_code`.

Deep local BepInEx/Il2CppInterop evidence:

- `MonoMod.RuntimeDetour.NativeDetour` has `IntPtr -> IntPtr` constructors.
- `Il2CppInterop.Runtime.Runtime.VersionSpecific.MethodInfo.NativeMethodInfoStructHandler_24_0`
  exposes `MethodPointer`.
- `Il2CppInterop.HarmonySupport.Il2CppDetourMethodPatcher` detours
  `originalNativeMethodInfo.MethodPointer` and stores `OriginalTrampoline`.

## Interpretation

This made the separate `native-renderfunc-entry` no-op probe technically
plausible, but not safe by itself. The remaining sharp edge is ABI/signature fidelity:
the replacement delegate must match the native render-function entry signature.
A wrong signature could crash before any managed log, which is exactly the kind
of failure already seen with rejected Harmony routes.

Therefore this preflight is not permission to evaluate DLSS or touch resources.
It only narrowed the implementation design.

## Minimum Safe Design For The Runtime Probe

The first runtime probe must be default-off and menu-first:

- config key should default to `false`;
- helper stage should set only this probe plus loader/native smoke if needed;
- target only one focused pass at first, preferably
  `Edge Adaptive Spatial Upsampling`;
- install no detour until the compile-time metadata has observed one stable
  `method_ptr` for the selected pass;
- use `NativeDetour`/Il2CppInterop method-pointer semantics, not Harmony patches
  on generated render functions;
- the detour body must only increment an atomic counter and immediately call the
  original trampoline;
- do not log from the render-function thread on every call; emit capped summaries
  from an already safe managed observation point;
- do not read pass data, `RenderGraphContext`, command buffers, textures, native
  pointers, or `GetTexture(...)`;
- do not load or evaluate DLSS;
- undo/dispose the detour on cleanup/shutdown when possible;
- first runtime proof is menu-only at true `1920x1080` Windowed.

Pass criteria for the first menu proof:

- no WER crash;
- true `1920x1080` Windowed;
- detour installed for exactly one focused pass pointer;
- entry counter increases;
- original render function still runs, inferred by continued focused
  compile/pass metadata and no black screen/crash;
- `RenderGraph GetTexture call #=0`;
- loader config and `ClientSettings.json` restored.

Fail criteria:

- multiple candidate pointers for the target pass;
- pointer is zero or equals `method_code`;
- any crash or black screen;
- no entry count after install;
- any attempt to resolve resources or evaluate DLSS;
- cleanup cannot restore release-safe state.

## Decision

Proceed only to the separately implemented `native-renderfunc-entry` no-op probe
and only for a menu-first proof. Do not patch generated HDRP render funcs
through Harmony, do not retry `DLSSPass.Render`, and do not use this as a
production evaluate boundary.
