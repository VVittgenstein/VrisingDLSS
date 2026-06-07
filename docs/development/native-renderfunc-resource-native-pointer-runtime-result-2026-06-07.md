# Native RenderFunc Resource Native-Pointer Menu Result - 2026-06-07

Status: passed at true `1920x1080` Windowed. This is menu-only proof.

## Question

After `native-renderfunc-resource-resolve` proved the focused EASU
`source` / `destination` handles resolve only to `TextureResource` metadata at
the safe `CompileRenderGraph(int)` observation point, can a separately guarded
preflight passively observe Unity-owned `GetTexture(TextureHandle&)` returns
for those same handles and read non-zero native texture pointers without
touching command buffers, D3D11 validation, or DLSS evaluate?

## Test Contract

Hypothesis:

- The focused EASU pass-data/native callback identity will match again.
- The native-pointer stage will independently patch
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)`.
- `GetTexture` postfix handling will return immediately unless the handle
  matches the armed EASU `source` or `destination`.
- The stage will observe both handles as `RTHandle` results with non-zero
  `GetNativeTexturePtr()` values.

Pass signal:

- Analyzer reports `Native RenderFunc Resource Native Pointer=Pass`.
- Log contains `Frame resource RenderGraph GetTexture postfix patched:`.
- Log contains `Native render-func resource native-pointer advanced:`.
- The advanced line shows non-zero `nativePtr=0x...` for both `source` and
  `destination`.
- No broad `RenderGraph GetTexture call #`, D3D11 probe, command-buffer access,
  `ExecuteDLSS`, NGX, or DLSS evaluate path appears.

Fail signal:

- Startup crash, Windows crash event, GetTexture postfix patch failure, detour
  failure, pass-list failure, `data=not found`, no advanced line after target
  armed, any D3D11/native validation, or any DLSS evaluate/probe execution.

Cleanup:

- Close V Rising after the diagnostic window.
- Restore loader-safe config, release-safe native DLL state, and ClientSettings.
- Confirm no V Rising or UnityCrashHandler process remains.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-native-pointer -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

## Pre-Fix Partial Run

Run label:

`native-renderfunc-resource-native-pointer-20260607-142048`

This first run completed without a crash, restored cleanup state, and armed the
EASU native-pointer target. It did not reach `advanced` because the stage still
installed only one method:

```text
Frame resource probe total patched 1 method(s).
Native render-func resource native-pointer target armed: compile=4; ...
```

There was no `Frame resource RenderGraph GetTexture postfix patched:` line.
Root cause: the GetTexture postfix patch request was inside the
`DlssEvaluateInputProbeEnabled` branch. The native-pointer stage intentionally
keeps `EnableDlssEvaluateInputProbe=false`, so the postfix branch was skipped.

Fix:

- `FrameResourceProbe.Install(...)` now independently patches
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` when
  `NativeRenderFuncResourceNativePointerProbeEnabled=true` and
  `DlssEvaluateInputProbeEnabled=false`.
- The stage still keeps `EnableRenderGraphGetTextureProbe=false`, so the old
  broad GetTexture candidate/D3D11/evaluate path remains disabled.

## Passing Run

Run label:

`native-renderfunc-resource-native-pointer-20260607-142357`

Artifacts:

- `artifacts\runtime-logs\LogOutput-native-renderfunc-resource-native-pointer-20260607-142357.log`
- `artifacts\runtime-logs\Analysis-native-renderfunc-resource-native-pointer-20260607-142357.txt`
- `artifacts\runtime-logs\Player-native-renderfunc-resource-native-pointer-20260607-142357.log`
- `artifacts\runtime-logs\ClientSettings-native-renderfunc-resource-native-pointer-20260607-142357.before.json`

The scripted menu run completed and was closed by the script:

- `CrashEventCount=0`
- `ExitedBeforeWindow=False`
- `ClosedByScript=True`
- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- `GameReportedWidth=1920`
- `GameReportedHeight=1080`
- `GameReportedFullScreenMode=Windowed`
- `GameReportedSetResolutionLine=SetResolution 1920, 1080, fullScreenMode Windowed`

Analyzer result:

- `Stage 1 Loader=Pass`
- `Stage 4 Native Bridge=Pass`
- `Native RenderFunc Entry=Pass`
- `Native RenderFunc Args=Pass`
- `Native RenderFunc Resource Identity=Pass`
- `Native RenderFunc Resource Tuple=Pass`
- `Native RenderFunc Resource Native Pointer=Pass`
- DLSS evaluate/input/output/write-back/user-rendering stages stayed `Missing`.
- `Stage 5B D3D11 Texture=Missing`, as expected for this no-D3D11 preflight.

Key positive evidence:

```text
Frame resource RenderGraph GetTexture postfix patched: UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphResourceRegistry.GetTexture(TextureHandle& handle) -> RTHandle
```

```text
Native render-func resource native-pointer advanced: source=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"; nativePtr=0x22815E176A0; nativeOwner=UnityEngine.Texture name=Apply Exposure Destination_1920x1080_B10G11R11_UFloatPack32_Tex2DArray_dynamic width=1920 height=1080 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Uber Post Destination rtHandleProperties=UnityEngine.Rendering.RTHandleProperties; frame=4); destination=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"; nativePtr=0x22815E194E0; nativeOwner=UnityEngine.Texture name=Edge Adaptive Spatial Upsampling_1920x1080_B10G11R11_UFloatPack32_Tex2DArray width=1920 height=1080 graphicsFormat=B10G11R11_UFloatPack32 dimension=Tex2DArray; result=UnityEngine.Rendering.RTHandle name=Edge Adaptive Spatial Upsampling rtHandleProperties=UnityEngine.Rendering.RTHandleProperties; frame=4); targetCompile=4; targetManagedPassData=0x2268F0CAA80; tuple=input=1920x1080; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"
```

Focused counts:

- `Frame resource RenderGraph GetTexture postfix patched:`: `1`
- `Native render-func resource native-pointer target armed:`: `1`
- `Native render-func resource native-pointer status #`: `4`
- `Native render-func resource native-pointer advanced:`: `1`
- `RenderGraph GetTexture call #`: `0`
- `D3D11 probe`: `0`
- `D3D11 texture probe`: `0`
- `ExecuteDLSS`: `0`
- `NGX`: `0`
- `DLSS user rendering evaluate succeeded`: `0`
- `DLSS super-resolution evaluate succeeded`: `0`
- `DLSS frame-sequence evaluate succeeded`: `0`
- `Native render-func resource native-pointer data=not found`: `0`
- `RenderGraph pass-list logging failed`: `0`
- `Exception`: `0`

Local config after cleanup returned to loader-safe defaults for this route:

- `EnableNativeRenderFuncResourceNativePointerProbe=false`
- `EnableD3D11TextureProbe=false`
- `EnableDLSS=false`

## Interpretation

This proves that, at the official HDRP DLSS-adjacent native render-func
boundary, the focused EASU `source` and `destination` handles can be connected
to actual native texture pointers during Unity-owned `GetTexture(...)` scope.
It also confirms the safety distinction that matters for the next step:

- `CompileRenderGraph(int)` can identify and arm the exact EASU handles.
- Actual pointer availability appears only in Unity-owned
  `RenderGraphResourceRegistry.GetTexture(TextureHandle&)` execution.
- This pass still does not prove command-buffer availability or DLSS evaluate
  safety.

Do not combine command-buffer access or DLSS evaluate with this proof. The next
step must be a separately guarded preflight.

## Gameplay Follow-Up

Protected `11111` gameplay proof has now passed:

`docs/development/native-renderfunc-resource-native-pointer-gameplay-result-2026-06-07.md`

The next engineering step must be a separately guarded preflight for the next
official-boundary question. Do not combine command-buffer access, D3D11
validation, or DLSS evaluate with this proof.
