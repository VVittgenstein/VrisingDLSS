# RenderGraph Execute-Delegate Menu Result - 2026-06-06

Status: partial / no-signal. Patch-stable in the main menu, but not a proven
execution-layer observation boundary. Do not proceed to protected gameplay proof
or evaluate work from this result.

## Question

Can the default-off `rendergraph-execute-delegate` stage safely patch closed
generic `RenderGraphPass.GetExecuteDelegate<TPassData>()` methods and observe
focused HDRP pass execution at `1920x1080 Windowed` without touching resources,
command buffers, native texture pointers, or DLSS evaluate?

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath C:\Software\VRising -Stage rendergraph-execute-delegate -ArtifactLabel rendergraph-execute-delegate-1080p-menu-20260606-r1 -DurationSeconds 120 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080
```

## Conditions

- Scope: main-menu / startup only. No gameplay entry and no protected save load.
- Duration: `120` seconds.
- Graphics: forced Direct3D11.
- Resolution: Player log reported `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Cleanup: script restored loader config and ClientSettings.

## Artifacts

- BepInEx log:
  `artifacts/runtime-logs/LogOutput-rendergraph-execute-delegate-1080p-menu-20260606-r1.log`
- Analyzer:
  `artifacts/runtime-logs/Analysis-rendergraph-execute-delegate-1080p-menu-20260606-r1.txt`
- Player log:
  `artifacts/runtime-logs/Player-rendergraph-execute-delegate-1080p-menu-20260606-r1.log`
- ClientSettings backup:
  `artifacts/runtime-logs/ClientSettings-rendergraph-execute-delegate-1080p-menu-20260606-r1.before.json`

## Result

Run summary:

- `CrashEventCount=0`.
- `ExitedBeforeWindow=False`.
- `ClosedByScript=True`.
- `RestoredLoaderConfig=True`.
- `RestoredClientSettings=True`.
- `GameReportedWidth=1920`.
- `GameReportedHeight=1080`.
- `GameReportedFullScreenMode=Windowed`.

Analyzer summary:

- `Stage 4 Native Bridge=Pass`.
- `Stage 2B Upscaler State Probe=Pass`.
- `RenderGraph Execute Delegate=Partial`.
- `RenderGraph Pass Data=Missing`.

Focused log counts:

- `RenderGraph execute-delegate probe patched 4 method(s)`.
- `RenderGraph execute-delegate #`: `0`.
- `RenderGraph execute-delegate data=not found`: `0`.
- `RenderGraph execute-delegate pass=not found`: `0`.
- `RenderGraph execute-delegate logging failed`: `0`.
- execute-delegate patch failures: `0`.
- `RenderGraph GetTexture call #`: `0`.
- `memberCount=`: `0`.

Patched methods reported:

- `DLSSData`.
- `UberPostPassData`.
- `EASUData`.
- `FinalPassData`.

## Decision

Accept this as patch-stability evidence only. The probe installed four closed
generic targets and ran for the full menu window with no crash and no `GetTexture`
activity, but it did not produce any focused execute-delegate callback lines.

This does not satisfy the menu proof gate. Do not run protected `11111` gameplay
for this stage unchanged, and do not use it as evidence for a DLSS evaluate
boundary.

Likely explanations to inspect before another runtime attempt:

- The IL2CPP execution path may not call through the managed interop
  `RenderGraphPass.GetExecuteDelegate<TPassData>()` wrapper even though the Unity
  C# source shows `RenderGraphPass<TPassData>.Execute(ctx)` calling it.
- The focused passes may not traverse this managed wrapper in the main menu.
- Harmony may patch the constructed wrapper method while the actual IL2CPP
  generic-shared call site uses a different body.

## Local Decompile Follow-Up

After the run, local `ilspycmd` inspection of
`C:\Software\VRising\BepInEx\interop\Unity.RenderPipelines.Core.Runtime.dll`
made the no-signal result more understandable:

- `RenderGraphPass.GetExecuteDelegate<PassData>()` is present as an Il2CppInterop
  wrapper that calls `IL2CPP.il2cpp_runtime_invoke(...)`.
- The generated wrapper reports `[CallerCount(0)]`.
- `RenderGraphPass<PassData>.Execute(RenderGraphContext)` is also an
  Il2CppInterop wrapper around native method token `100663663`; the generated C#
  wrapper does not contain the Unity source-level call to
  `GetExecuteDelegate<PassData>()`.
- Therefore the Unity C# source-level relation
  `Execute(ctx) -> GetExecuteDelegate<PassData>()(...)` is still conceptually
  correct for RenderGraph, but the V Rising IL2CPP runtime does not have to
  traverse the managed wrapper method that Harmony patched here.

This supports keeping the result as "patch-stable / no-signal" instead of a
crash rejection.

Next action: inspect local interop/decompiled IL2CPP generic execution shape and
look for a still read-only/no-evaluate boundary that can prove execution-layer
arrival without patching generated render funcs, `DLSSPass.Render`,
`PreRenderPassExecute`, `GetTexture`, or command-buffer paths. Do not rerun
`rendergraph-execute-delegate` unchanged.
