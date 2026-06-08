# V Rising HDRP DLSS m_DLSSPass Xref Audit - 2026-06-08

## Purpose

Answer the follow-up static question from
`docs/development/vrising-hdrp-dlss-route-static-audit-2026-06-08.md`:

- Is the official HDRP `m_DLSSPass` object created in V Rising?
- Does V Rising's local HDRP build activate the Unity NVIDIA/DLSS feature path?
- Should `hdrp-dlss-schedule-gate` be the next mainline runtime probe, or only a
  classifier?

No V Rising runtime was launched for this pass. No game files were modified.

Clean-room boundary: this document records local metadata/xref facts and
inferences for selecting runtime patch points. It must not be used to distribute
modified game files, decompiled game source, or game assets.

## Inputs

- Local game root: `C:\Software\VRising`
- BepInEx interop directory: `C:\Software\VRising\BepInEx\interop`
- Xref databases:
  - `MethodAddressToToken.db`
  - `MethodXrefScanCache.db`
- Local Il2CppDumper output:
  - `artifacts/il2cppdumper/vrising-v1.1.13.0-r99712-b17-20260607/script.json`
  - `ref/decompilation-vrising-2026-06-08/il2cpp-dumper/script.json`
- Upstream semantic comparison:
  - `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.cs`
  - `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipeline.PostProcess.cs`
  - `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/HDRenderPipelineAsset.cs`
- Local ignored helper temporarily extended:
  - `artifacts/tools/InteropXrefProbe/Program.cs`

Representative offline command:

```powershell
C:\Software\dotnet\dotnet.exe artifacts\tools\InteropXrefProbe\bin\Release\net6.0\InteropXrefProbe.dll C:\Software\VRising
```

The helper reads existing interop metadata/xref cache only. It does not launch
or patch the game.

## Upstream HDRP Expected Chain

UnityGraphics 2022.3 HDRP source uses this official shape:

```text
HDRenderPipeline.SetRenderingFeatures / HDRenderPipelineAsset.OnEnable
  -> HDRenderPipeline.SetupDLSSFeature(globalSettings)
     -> DLSSPass.SetupFeature(globalSettings)
     -> HDDynamicResolutionPlatformCapabilities.ActivateDLSS()

HDRenderPipeline.InitializePostProcess
  -> m_DLSSPass = DLSSPass.Create(m_GlobalSettings)

HDRenderPipeline.BeginPostProcessFrame
  -> m_DLSSPassEnabled = m_DLSSPass != null && camera.IsDLSSEnabled()
  -> m_DLSSPass.BeginFrame(camera)

HDRenderPipeline.RenderPostProcess
  -> DoDLSSPasses(...)
     -> DoDLSSPass(...)
        -> RenderGraph.AddRenderPass("Deep Learning Super Sampling")
        -> DLSSPass.CreateCameraResources(...)
        -> generated render func
        -> DLSSPass.Render(..., ctx.cmd)
```

This upstream source remains a semantic map. The local V Rising binary must be
checked independently.

## Address Anchors

From local `script.json`:

| Method | Address/RVA |
| --- | --- |
| `HDRenderPipeline.SetupDLSSFeature` | `0x963D340` |
| `DLSSPass.SetupFeature` | `0x17312A0` |
| `DLSSPass.Create` | `0x173F700` |
| `DLSSPass.CreateCameraResources` | `0x971DAD0` |
| `HDDynamicResolutionPlatformCapabilities.ActivateDLSS` | `0x987C720` |
| shared no-op-style DLSS body address from earlier audit | `0x171E170` |

## Evidence 1: SetupDLSSFeature Exists, But Does Not Xref The DLSS Activation Pair

Local xref summary:

- `HDRenderPipeline.SetupDLSSFeature`
  - token: `0x06000207`
  - address: `0x963D340`
  - `CallerCount=2`
  - refs/users:
    - `HDRenderPipeline.SetRenderingFeatures`
    - `HDRenderPipelineAsset.OnEnable`
  - xrefs/out count: `15`

Important negative evidence:

- No outgoing xref resolved to `DLSSPass.SetupFeature` (`0x17312A0`).
- No outgoing xref resolved to
  `HDDynamicResolutionPlatformCapabilities.ActivateDLSS` (`0x987C720`).
- The only resolved outgoing target of interest was `UnityEngine.Debug.LogError`;
  the remaining repeated unresolved targets look like common IL2CPP
  helper/class-init/string paths and were not resolved to local HDRP DLSS
  methods.

Evidence level: strong xref evidence for callers, strong negative evidence for
the activation pair when combined with `ActivateDLSS` having zero callers.

Inference: V Rising's compiled `SetupDLSSFeature` path is present as a method,
but the local binary does not appear to execute the upstream
`DLSSPass.SetupFeature -> ActivateDLSS` activation chain.

## Evidence 2: ActivateDLSS Has Zero Callers

Local xref summary:

- `HDDynamicResolutionPlatformCapabilities.ActivateDLSS`
  - token: `0x06001F91`
  - address: `0x987C720`
  - `CallerCount=0`
  - refs/users: none

Evidence level: strong.

Inference: `HDDynamicResolutionPlatformCapabilities.DLSSDetected` is unlikely to
become true through the official Unity HDRP/NVIDIA activation path in this V
Rising build.

## Evidence 3: DLSSPass.SetupFeature/Create Xrefs Are Not The Official HDRP Chain

`DLSSPass.SetupFeature`:

- address: `0x17312A0`
- `CallerCount=3`
- refs/users resolved to:
  - `ProjectM.ClientAdminConsoleCommandSystem._OnCreateConsoleCommands_b__4_23`
  - `ProjectM.ClientAdminConsoleCommandSystem._OnCreateConsoleCommands_b__4_24`
  - `ProjectM.ServerConsoleCommandSystem._OnCreateConsoleCommands_b__1_2`
- No `HDRenderPipeline.SetupDLSSFeature` caller was reported.

`DLSSPass.Create`:

- address: `0x173F700`
- `CallerCount=9`
- refs/users resolved to unrelated ProjectM baker/UI/entity methods such as
  `CastleHeartAuthoring+Baker.Bake`, `VBloodDuelInstanceAuthoring+Baker.Bake`,
  `DuelInstanceAuthoring+Baker.Bake`, and `Unity.Entities` add-component
  helpers.
- No `HDRenderPipeline.InitializePostProcess` caller was reported.

Evidence level: mixed.

Interpretation: these caller lists look like address reuse, scan noise, or
method-body sharing rather than useful HDRP DLSS initialization evidence. They
must not be treated as proof that the official DLSS feature is active. The
important negative is that the expected HDRP callers are absent.

## Evidence 4: Initialize/BeginFrame/Cleanup Do Not Show The Official m_DLSSPass Chain

Local xref summary:

- `HDRenderPipeline.InitializePostProcess`
  - token: `0x06000287`
  - `CallerCount=1`
  - caller: `HDRenderPipeline..ctor`
  - xrefs/out count: `167`
  - no resolved outgoing xref to `DLSSPass.Create` (`0x173F700`)
- `HDRenderPipeline.BeginPostProcessFrame`
  - token: `0x0600028C`
  - `CallerCount=1`
  - caller: `HDRenderPipeline.ExecuteRenderRequest`
  - xrefs/out include postprocess, exposure, TAAU/path-tracing, EASU/final-pass,
    and `HDCamera.IsDLSSEnabled` evidence
  - no clear resolved outgoing xref to `DLSSPass.BeginFrame`
- `HDRenderPipeline.CleanupPostProcess`
  - token: `0x0600028A`
  - caller: `HDRenderPipeline.Dispose`
  - xrefs/out include material/RTHandle/buffer cleanup
  - no useful DLSS cleanup evidence

Earlier local audit already found `DLSSPass.Render`, `DLSSPass.BeginFrame`,
`DLSSPass.SetupDRSScaling`, and `.ctor` all mapping to the shared no-op-style
address `0x171E170`, with bogus unrelated xref ranges.

Evidence level: strong for absence of the expected `InitializePostProcess ->
DLSSPass.Create` xref; strong for the no-op-style execution bodies.

Inference: the field `m_DLSSPass` exists in local metadata, but local evidence
does not show the normal upstream assignment/use lifecycle. It is likely null,
inert, or backed by a stripped/stubbed implementation.

## Evidence 5: DoDLSSPasses / DoDLSSPass Shell Still Exists And Is Useful

Local xref summary:

- `HDRenderPipeline.DoDLSSPasses`
  - token: `0x06000298`
  - `CallerCount=5`
  - all refs/users come from `HDRenderPipeline.RenderPostProcess`
  - xrefs/out include:
    - `get_currentAsset`
    - `DoDLSSColorMaskPass`
    - `DoDLSSPass`
    - `SetCurrentResolutionGroup`
- `HDRenderPipeline.DoDLSSPass`
  - token: `0x06000299`
  - `CallerCount=1`
  - caller: `DoDLSSPasses`
  - xrefs/out include:
    - `RenderGraph.AddRenderPass`
    - exposure texture / GPU texel readback helpers
    - `RenderGraphBuilder.ReadTexture`
    - postprocess output handle/resource write helpers
    - `DLSSPass.CreateCameraResources` (`0x971DAD0`)
    - render-func construction
    - `RenderGraphBuilder.SetRenderFunc`

`DLSSPass.GetViewResources` and `DLSSPass.CreateCameraResources` have real
xrefs from the generated `DoDLSSPass` render function / `DoDLSSPass` path.

Evidence level: strong.

Inference: V Rising retains the official HDRP DLSS RenderGraph scheduling shell
and resource contract, even though the NVIDIA feature activation and DLSS
execution object appear absent/inert.

## Evidence 6: No Local NVIDIA Runtime Files Found

Focused filesystem search under `C:\Software\VRising` found no files whose names
matched `nvngx`, `nvidia`, or `NVIDIA`. A focused BepInEx interop search also
found no NVIDIA-named interop assembly.

Evidence level: moderate. This is filesystem evidence, not a full proof of all
embedded metadata.

Inference: this supports the earlier route audit: V Rising may retain metadata
and HDRP strings for the Unity NVIDIA module path, but the practical local
runtime/module files needed by upstream HDRP DLSS are not present as normal
game files.

## Answers To The Target Questions

### Is V Rising's route consistent with Unity HDRP source?

Partially.

The postprocess scheduling shell is consistent enough to use as a semantic
contract: `RenderPostProcess -> DoDLSSPasses -> DoDLSSPass` exists, and the
local `DoDLSSPass` records official-like RenderGraph/resource relationships.

The feature activation/object lifecycle is not consistent: local xrefs do not
show `SetupDLSSFeature -> DLSSPass.SetupFeature -> ActivateDLSS`, do not show
`InitializePostProcess -> DLSSPass.Create`, and do not show a useful
`BeginFrame/SetupDRSScaling/Render` execution body.

### Does m_DLSSPass exist, and when is it initialized?

The field exists. Static evidence does not show the normal official assignment.
Best current interpretation: `m_DLSSPass` is likely null or inert in the normal
V Rising runtime.

`hdrp-dlss-schedule-gate` can still classify this in a menu-only runtime log,
but static evidence says it should not be the main performance-fix route.

### Does DLSSDetected become true through official HDRP?

No local static evidence says yes. `ActivateDLSS` has `CallerCount=0`, and
`SetupDLSSFeature` does not xref the activation pair.

### Is the current EASU ctx.cmd candidate at the official equivalent stage?

No. It is a proven visible-output boundary, but the official semantic boundary
is a separate `DoDLSSPass` RenderGraph pass with source/output/depth/motion/bias
resources and a pass-owned render function.

The EASU boundary can still be useful, but the performance regression with low
GPU utilization should be treated as a boundary/lifecycle/resource-order problem
until proven otherwise.

## Decision

Do not spend the next mainline iteration trying to "turn on" the built-in
`DLSSPass` object. The object path appears absent or inert.

Do not patch `DLSSPass.Render` directly as the normal route. Prior runtime
history includes crashes, and static evidence points to a stripped/no-op-style
method body.

Keep `hdrp-dlss-schedule-gate` as a default-off menu-only classifier for
`m_DLSSPass`/gate state, not as the likely performance fix.

Mainline direction:

1. Treat official `DoDLSSPass` as the resource-order and scheduling contract.
2. Design a no-native/no-evaluate proof that reaches an official-equivalent
   RenderGraph/pass boundary with explicit source/output/depth/motion resource
   declarations.
3. Prove that boundary is cheap and does not use broad per-frame texture
   discovery.
4. Only then reintroduce NGX/DLSS evaluate.

## Next Static Work

Before another gameplay or native evaluate test, inspect whether a managed
BepInEx plugin can safely create or influence a narrow RenderGraph pass near
`DoDLSSPass`/EASU/FinalPass without relying on private `DLSSPass.Render`:

- Can `RenderGraph.AddRenderPass<TPassData>` and
  `RenderGraphBuilder.SetRenderFunc<TPassData>` be called safely from IL2CPP
  plugin code for a mod-owned pass-data type?
- If not, can an existing postprocess pass boundary expose the necessary
  resource handles without broad `GetTexture` and without write hazards?
- What is the smallest no-native proof that can show official-like resource
  declaration, stable pass timing, and no CPU/GPU stall before adding NGX?
