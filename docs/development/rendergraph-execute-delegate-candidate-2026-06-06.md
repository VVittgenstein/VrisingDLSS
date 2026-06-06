# RenderGraph Execute Delegate Candidate - 2026-06-06

Status: implemented as a default-off read-only diagnostic probe. Not
runtime-proven yet. Do not treat as a DLSS evaluate boundary.

## Question

After the pass-data gameplay proof, can we move one step closer to Unity HDRP's
official DLSS execution boundary without patching generated render functions,
`DLSSPass.Render`, `RenderGraph.PreRenderPassExecute`, global `GetTexture`, or
any command-buffer/evaluate path?

## Source Answer

Unity HDRP's official DLSS path is still:

`RenderPostProcess -> DoDLSSPasses -> DoDLSSPass -> "Deep Learning Super Sampling" RenderGraph pass -> DLSSPass.GetCameraResources -> DLSSPass.Render/ExecuteDLSS`.

Downloaded upstream source for this round is under
`ref/hdrp-rendergraph-boundary-2026-06-06`.

Key local reference lines:

- `HDRenderPipeline.PostProcess.cs:708` records `DoDLSSPasses(...)`.
- `HDRenderPipeline.PostProcess.cs:720` records `DoDLSSPass(...)`.
- `HDRenderPipeline.PostProcess.cs:724` adds the `Deep Learning Super Sampling`
  RenderGraph pass.
- `HDRenderPipeline.PostProcess.cs:737` writes the DLSS destination through
  `GetPostprocessUpsampledOutputHandle(...)`.
- `HDRenderPipeline.PostProcess.cs:754` calls
  `data.pass.Render(data.parameters, DLSSPass.GetCameraResources(data.resourceHandles), ctx.cmd)`.
- `RenderGraph.cs:1482-1484` executes
  `PreRenderPassExecute -> pass.Execute -> PostRenderPassExecute`.
- `RenderGraphPass.cs:11` exposes `GetExecuteDelegate<TPassData>()`.
- `RenderGraphPass.cs:138-143` shows `RenderGraphPass<TPassData>` owns
  `data` and `renderFunc`, then `Execute(ctx)` invokes the delegate with both.
- `RenderGraphResourceRegistry.cs:103` resolves actual textures only from valid
  handles, and `RenderGraphResourceRegistry.cs:445-466` places texture creation
  before pass execution.

This keeps the old conclusion intact: compile-time pass-data snapshots are safe
observation, but real resources and command buffers belong to pass execution.

## Local Interop / Reflection Proof

The local V Rising interop exposes the relevant generic wrapper shape.

Reflection helper:

```powershell
C:\Software\dotnet\dotnet.exe run --project artifacts\reflection-check\RenderGraphBoundaryReflection.csproj -- C:\Software\VRising\BepInEx
```

Result:

- `RenderGraphPass.GetExecuteDelegate<PassData>()` is a generic method
  definition with zero parameters.
- Closed methods can be constructed with `ContainsGenericParameters=false` for:
  - `HDRenderPipeline+DLSSData`
  - `HDRenderPipeline+UberPostPassData`
  - `HDRenderPipeline+EASUData`
  - `HDRenderPipeline+FinalPassData`
- `RenderGraphPass<TPassData>` exists as a generic type definition in
  `Unity.RenderPipelines.Core.Runtime.dll`.

`ilspycmd` also confirmed that generated interop has:

- `RenderGraphPass.GetExecuteDelegate<PassData>()`
- `RenderGraphPass<TPassData>.data`
- `RenderGraphPass<TPassData>.renderFunc`
- `RenderGraphPass<TPassData>.Execute(RenderGraphContext)`
- `HDRenderPipeline+DLSSData`
- generated HDRP methods for `DoDLSSPass`, EASU, and Final Pass.

## Candidate

Patch closed generic `RenderGraphPass.GetExecuteDelegate<TPassData>()`, not the
generated render func and not `RenderGraphPass<TPassData>.Execute(ctx)`.

Initial candidate set:

- `GetExecuteDelegate<HDRenderPipeline.DLSSData>()`
- `GetExecuteDelegate<HDRenderPipeline.EASUData>()`
- `GetExecuteDelegate<HDRenderPipeline.FinalPassData>()`
- optional: `GetExecuteDelegate<HDRenderPipeline.UberPostPassData>()`

Why this is the current best next candidate:

- Unity source shows `RenderGraphPass<TPassData>.Execute(ctx)` calls
  `GetExecuteDelegate<TPassData>()` immediately before invoking the render func.
- The method has no `RenderGraphContext` argument and therefore cannot touch
  command buffers directly.
- A postfix/prefix can read `__instance` and typed pass data similarly to the
  already-proven pass-data snapshot route.
- It proves the target pass has reached the execution layer, which compile-time
  snapshots cannot prove.

What it does not prove:

- It does not provide `RenderGraphContext`.
- It does not provide the live command buffer.
- It does not prove texture resource state or native texture pointers.
- It is not an evaluate boundary and must not submit DLSS.
- `DLSSData` may never fire in the current game because the Unity NVIDIA runtime
  stack still appears absent and HDRP's DLSS pass is not active.

## Risk

This is still a closed-generic Harmony/IL2CPP runtime patch. That is safer than
the rejected generated render-function family, but not automatically safe.

Avoid for the first probe:

- `DLSSPass.Render(...)`
- generated `_DoDLSSPass_b__969_0`, `_EdgeAdaptiveSpatialUpsampling...`,
  `_FinalPass...`
- `RenderGraph.PreRenderPassExecute(...)`
- `RenderGraphPass<TPassData>.Execute(ctx)`
- `RenderGraphResourceRegistry.GetTexture(...)`
- native texture pointers
- command-buffer work
- real DLSS evaluate

## Implementation Status

Implemented on 2026-06-06 as the next narrow boundary proof:

- Config key: `Diagnostics.EnableRenderGraphExecuteDelegateProbe=false`.
- Helper stage: `rendergraph-execute-delegate`.
- Analyzer stage: `RenderGraph Execute Delegate`.
- Package default: disabled in `package/thunderstore/VrisingDLSS.cfg`.
- Build/package validation passed after implementation.

The implementation patches only closed generic
`RenderGraphPass.GetExecuteDelegate<TPassData>()` methods for `DLSSData`,
`UberPostPassData`, `EASUData`, and `FinalPassData`. It uses a postfix, records
the pass name/category/type, reads focused pass-data summaries, caps logs, and
does not alter or wrap the returned delegate.

No runtime proof has been collected yet. The next validation must be menu-only
at `1920x1080 Windowed`; gameplay validation can only follow after a clean menu
proof.

## Probe Protocol

This route is implemented, but still needs runtime proof before it can guide the
next boundary decision.

- Config key: `Diagnostics.EnableRenderGraphExecuteDelegateProbe=false`.
- Helper stage: `rendergraph-execute-delegate`.
- First runtime scope: menu-only, `1920x1080 Windowed`.
- Gameplay scope only after menu proof is clean; use protected `11111`
  backup/restore and no movement keys.
- Log capped lines such as:
  `RenderGraph execute-delegate #N: ... pass="Edge Adaptive Spatial Upsampling"; dataType=EASUData; memberCount=...`
- Use typed `TryCast<RenderGraphPass<TPassData>>()` and read scalar/handle
  summaries only.
- Fail if patching throws, typed cast fails repeatedly, the stage logs no focused
  execute-delegate lines, `GetTexture` appears, or any crash event appears.
- Analyzer must require at least one focused execution-layer line for pass.

## Decision

The narrow search did find a better next boundary candidate:

`RenderGraphPass.GetExecuteDelegate<TPassData>()` closed over `DLSSData`,
`EASUData`, `FinalPassData`, and optionally `UberPostPassData`.

This is not ready for evaluate, but it is the cleanest next read-only proof:
one step later than `CompileRenderGraph(int)` pass-data snapshots, one step
earlier than generated render-func invocation, and still outside resource
resolution/native/DLSS work.
