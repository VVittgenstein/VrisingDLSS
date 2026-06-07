# Native RenderFunc Resource Resolve Menu Result - 2026-06-07

Status: passed at true `1920x1080` Windowed. This is menu-only proof.

## Question

After `native-renderfunc-resource-tuple` proved the focused EASU native
render-func tuple in menu and protected gameplay, can the separately guarded
resource-resolve preflight resolve the matched `source` / `destination`
`TextureHandle`s to RenderGraph `TextureResource` metadata without crossing into
`GetTexture`, native texture-pointer, command-buffer, or DLSS evaluate behavior?

## Test Contract

Hypothesis:

- The focused EASU pass-data/native callback identity will match again.
- `source` and `destination` will both resolve through
  `RenderGraphResourceRegistry.GetTextureResource(ResourceHandle&)`.
- `graphicsResource` may remain null at this observation point; that is a
  diagnostic finding, not failure.

Pass signal:

- Analyzer reports `Native RenderFunc Resource Resolve=Pass`.
- Log contains `Native render-func resource resolve advanced:`.
- Advanced/status lines show `passDataMatches=True`, `tupleReady=True`,
  `resourceReady=True`, and both handles report `textureResourceReady=True`.
- No `RenderGraph GetTexture call #`, native texture pointer validation, D3D11
  texture probe, command-buffer access, `ExecuteDLSS`, NGX, or actual DLSS
  evaluate path appears.

Fail signal:

- Startup crash, Windows crash event, detour failure, pass-list failure,
  `Native render-func resource resolve data=not found`, missing source /
  destination `TextureResource`, any broad `GetTexture` callback, any native
  texture/D3D11 validation, or any DLSS evaluate/probe execution.

Cleanup:

- Close V Rising after the diagnostic window.
- Restore loader-safe config, release-safe native DLL state, and ClientSettings.
- Confirm no V Rising or UnityCrashHandler process remains.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-resolve -DurationSeconds 75 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Run label:

`native-renderfunc-resource-resolve-20260607-134221`

Artifacts:

- `artifacts\runtime-logs\LogOutput-native-renderfunc-resource-resolve-20260607-134221.log`
- `artifacts\runtime-logs\Analysis-native-renderfunc-resource-resolve-20260607-134221.txt`
- `artifacts\runtime-logs\Player-native-renderfunc-resource-resolve-20260607-134221.log`
- `artifacts\runtime-logs\ClientSettings-native-renderfunc-resource-resolve-20260607-134221.before.json`

## Result

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
- `Native RenderFunc Resource Resolve=Pass`
- DLSS evaluate/input/output/write-back/user-rendering stages stayed `Missing`.
- `Stage 5B D3D11 Texture=Missing`, as expected for this no-native-texture
  preflight.

Key advanced line:

```text
Native render-func resource resolve advanced: compile=4; sampleCount=1; managedPassData=0x2562A3FF120; nativeLastPassData=0x2562A3FF120; passDataMatches=True; tupleReady=True; resourceReady=True; graphicsReady=False; pass="Edge Adaptive Spatial Upsampling"; tuple=input=1920x1080; output=1920x1080; source="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"; destination="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"; resolve=source=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78"; textureResourceReady=True; graphicsResourceReady=False; details="renderGraph.m_Resources.GetTextureResource returned UnityEngine.Experimental.Rendering.RenderGraphModule.TextureResource; graphicsResource=null"); destination=(handle="UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79"; textureResourceReady=True; graphicsResourceReady=False; details="renderGraph.m_Resources.GetTextureResource returned UnityEngine.Experimental.Rendering.RenderGraphModule.TextureResource; graphicsResource=null")
```

Focused counts:

- `Native render-func resource resolve advanced:`: `1`
- `Native render-func resource resolve status #`: `82`
- `resourceReady=True`: `80`
- `textureResourceReady=True`: `80`
- `graphicsReady=True`: `0`
- `graphicsReady=False`: `83`
- `RenderGraph GetTexture call #`: `0`
- `Native texture validation`: `0`
- `D3D11 texture probe`: `0`
- `ExecuteDLSS`: `0`
- `NGX`: `0`
- `Native render-func resource resolve data=not found`: `0`
- `RenderGraph pass-list logging failed`: `0`
- `failed`: `0`
- `Exception`: `0`

`DLSS evaluate` appeared only inside startup warning text that describes what
the preflight does not do; there was no `ExecuteDLSS`, NGX, DLSS runtime probe,
or DLSS evaluate stage pass.

## Interpretation

This proves the focused EASU native render-func identity can safely reach
RenderGraph `TextureResource` metadata for both matched handles from the
CompileRenderGraph observation path. It also proves the point is still not an
actual native texture availability boundary: both `graphicsResource` fields were
null, and `graphicsReady=True` never appeared.

The result supports the current boundary model:

- `GetTextureResource(...)` is safe/useful as metadata preflight.
- Actual resource availability remains tied to the engine-owned render-function
  scope, consistent with Unity RenderGraph documentation.
- Do not treat this as permission to call `GetTexture(...)`, read native texture
  pointers, touch `CommandBuffer`, or evaluate DLSS from this point.

## Next Step

Run the same default-off stage as a protected `11111` gameplay proof at
`1920x1080` Windowed, with the established save-restore/no-movement protocol:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath "C:\Software\VRising" -Stage native-renderfunc-resource-resolve -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

Pass criteria are the same as this menu proof plus protected gameplay cleanup:
stable gameplay evidence, no movement keys, save restore `ChangeCount=0`, no
crash, and no unsafe resource/evaluate patterns.
