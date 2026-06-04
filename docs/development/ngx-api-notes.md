# NGX/DLSS API Notes

These notes summarize the public NVIDIA DLSS/NGX API surface used by the diagnostic probes. They are not a copy of the NVIDIA SDK headers, and the project does not vendor NVIDIA SDK files.

## Official References

- NVIDIA DLSS repository: `https://github.com/NVIDIA/DLSS`
- NGX D3D11 declarations: `https://raw.githubusercontent.com/NVIDIA/DLSS/main/include/nvsdk_ngx.h`
- NGX result and parameter names: `https://raw.githubusercontent.com/NVIDIA/DLSS/main/include/nvsdk_ngx_defs.h`
- NGX parameter accessors: `https://raw.githubusercontent.com/NVIDIA/DLSS/main/include/nvsdk_ngx_params.h`
- NVIDIA DLSS SDK license: `https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt`
- NVIDIA DLSS 4.5 preset guidance: `https://www.nvidia.com/en-us/geforce/news/dlss-4-5-dynamic-multi-frame-gen-6x-2nd-gen-transformer-super-res/`

As of the 2026-06-05 check, the public NVIDIA/DLSS repository lists `DLSS 310.6.0 SDK` as the latest release, dated 2026-04-21.

Local research copies:

- `ref/packages/NVIDIA-DLSS-310.6.0-ngx_dlss_demo_windows.zip`
- `ref/NVIDIA-DLSS-310.6.0/nvngx_dlss.dll`
- `ref/NVIDIA-DLSS-main/`

The local `nvngx_dlss.dll` research copy is file version `310.6.0.0`, signed by NVIDIA Corporation, with SHA256 `099B3E1E3AD3F226DE621FE570B26CC554CC775E2606BE23EB222D6245674070`.

## Diagnostic Probe Scope

The source-only/release-safe `VrisingDlss_ProbeDlssInitQuery` uses dynamic runtime lookup for:

- `NVSDK_NGX_D3D11_Init`
- `NVSDK_NGX_D3D11_GetCapabilityParameters`
- `NVSDK_NGX_D3D11_DestroyParameters`
- `NVSDK_NGX_D3D11_Shutdown1` or `NVSDK_NGX_D3D11_Shutdown`
- `NVSDK_NGX_Parameter_GetI` or `NVSDK_NGX_Parameter_GetUI`

If the runtime lacks the capability-query helper exports, the probe reports that NVIDIA SDK wrapper integration is required and exits before NGX init. This is the expected result with the local DLSS `310.6.0.0` production runtime.

The optional local SDK-wrapper research build links `nvsdk_ngx_s.lib` from a user-provided NVIDIA SDK root and reads these DLSS SuperSampling capability keys:

- `SuperSampling.Available`
- `SuperSampling.NeedsUpdatedDriver`
- `SuperSampling.MinDriverVersionMajor`
- `SuperSampling.MinDriverVersionMinor`
- `SuperSampling.FeatureInitResult`

The probe does not create a DLSS feature, does not allocate DLSS resources, and does not evaluate a frame.

The 2026-06-05 runtime test showed an important boundary:

- `nvngx_dlss.dll` directly exports D3D11 init/create/evaluate/release/shutdown functions and `NVSDK_NGX_D3D11_PopulateParameters_Impl`.
- The production runtime DLL does not directly export `NVSDK_NGX_D3D11_GetCapabilityParameters`.
- The official sample calls `GetCapabilityParameters` through NVIDIA's SDK wrapper library, not the bare runtime DLL surface alone.

Therefore Stage 6 and real DLSS feature creation require an explicit SDK wrapper integration decision. A release build must not silently bake NVIDIA SDK wrapper code into the native bridge without the same release review used for runtime redistribution.

The 2026-06-05 local SDK-wrapper research build passed Stage 6 using `NVSDK_NGX_D3D11_Init_with_ProjectID` when `DLSS.DlssApplicationId=0`. Evidence:

- Native build option: `VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER=ON`.
- Local SDK root: `ref/NVIDIA-DLSS-main/`.
- Runtime path: `ref/NVIDIA-DLSS-310.6.0/nvngx_dlss.dll`.
- Init route: `SDK wrapper ProjectID`.
- Result: `init=0x00000001`, `capability=0x00000001`, `available=1`, `needsUpdatedDriver=0`, `minDriver=470.0`, `featureInitResult=1`, `destroy=0x00000001`, `shutdown=0x00000001`.

This proves capability query can work locally without committing NVIDIA SDK headers/libs or bundling `nvngx_dlss.dll` into the release package.

## Preset Notes

The public `nvsdk_ngx_defs.h` header defines `NVSDK_NGX_DLSS_Hint_Render_Preset` values including:

- `Default`
- `J`
- `K`
- `L`
- `M`

The same header comments mark K as the default transformer preset for DLAA/Balanced/Quality modes, L as the default for Ultra Performance, and M as the default for Performance.

NVIDIA's DLSS 4.5 public guidance says the NVIDIA app's `Recommended` DLSS Super Resolution override maps Performance to Preset M, Ultra Performance to Preset L, and the remaining modes to Preset K.

Implementation rule for this project:

- Expose `PresetMode=Recommended` in the MVP config target.
- Do not hard-code explicit preset parameters until the exact NGX parameter names and accepted values are verified against the current SDK headers and runtime behavior.
- Treat `Recommended` as a project-level mapping if NGX direct integration does not expose a first-class `Recommended` value.

## Runtime Redistribution Review

The MVP product target prefers a convenience package with an official production `nvngx_dlss.dll`, but this must remain behind release review until the exact file, license notices, and package channel are approved.

Release review must confirm:

- The runtime is from an approved NVIDIA distribution path.
- The package includes NVIDIA notices/license text.
- The project license does not claim to cover NVIDIA runtime files.
- The package does not imply NVIDIA sponsorship or endorsement.
- A fallback package without NVIDIA runtime remains available if redistribution is not approved.
