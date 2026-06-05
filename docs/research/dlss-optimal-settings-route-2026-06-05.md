# DLSS Optimal Settings Route - 2026-06-05

This note records the source-backed answer to the render-scale question: the MVP should not rely on V Rising's FSR setting, and the production path should eventually ask the DLSS integration layer for recommended render dimensions instead of treating fixed percentages as the final implementation.

## Primary Sources Checked

- NVIDIA Technical Blog, "Tips: Getting the Most out of the DLSS Unreal Engine 4 Plugin": `https://developer.nvidia.com/blog/?p=24048`
- NVIDIA Streamline DLSS programming guide: `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuideDLSS.md`
- NVIDIA Streamline general programming guide/security notes: `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
- NVIDIA Streamline repository/release notes: `https://github.com/NVIDIA-RTX/Streamline`
- Local NVIDIA DLSS SDK helper header: `ref/NVIDIA-DLSS-main/include/nvsdk_ngx_helpers.h`
- Local NVIDIA DLSS sample wrapper: `ref/NVIDIA-DLSS-310.6.0/sample-snippets/NGXWrapper.cpp`
- Local Unity Graphics 2022.3 HDRP DLSS pass source: `ref/UnityGraphics-2022.3/Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/DLSSPass.cs`

## Findings

NVIDIA's UE DLSS guidance gives useful default mode scales: Ultra Performance is about 33 percent per axis, Performance is 50 percent, Balanced is about 58 percent, and Quality is about 66 percent. For a 3840x2160 output target, Performance therefore maps to a 1920x1080 render target. This is a correct diagnostic target for 4K testing.

That same fixed-percentage table is not the best production contract. NVIDIA's Streamline DLSS guide tells the application to call `slDLSSGetOptimalSettings` with the selected mode and output size, then set the viewport to the returned render width and render height. It also says the returned settings include DLSS dynamic-resolution min/max source image sizes when supported.

The local NVIDIA DLSS SDK helper route exposes the same idea for the existing NGX-wrapper research path. `NGX_DLSS_GET_OPTIMAL_SETTINGS` reads `DLSSOptimalSettingsCallback` from the NGX capability parameter map, sets output width/height and perf-quality mode, invokes the callback, then returns optimal render size, dynamic min/max render size, and sharpness. The helper explicitly treats a missing callback as out-of-date or as evidence that the wrong parameter object was used, and recommends capability parameters rather than allocated parameters.

The local sample wrapper uses this helper in `NGXWrapper::QueryOptimalSettings(...)`. If NGX is not initialized or the query fails, the sample falls back to display-size render settings and sharpness 0. This is a useful implementation pattern: query first, fall back explicitly, and log why.

Unity HDRP also follows the optimal-settings model. In the 2022.3 HDRP `DLSSPass`, Unity calls `GetOptimalSettings(...)` for the final viewport and selected DLSS quality. When automatic settings are enabled, HDRP converts the returned min/max render sizes into dynamic-resolution percentages and activates the system dynamic-resolution scaler. This confirms that the right Unity-side abstraction is still dynamic resolution, not V Rising's FSR menu value.

## Current Project Decision

`RenderScaleControlProbe` may keep fixed percentages as a diagnostic fallback. The 4K Performance tuple should remain `1920x1080 -> 3840x2160` unless the runtime query returns a different recommendation.

The clean product route should be:

1. Keep V Rising `FsrQualityMode=Off` for the MVP comparison.
2. Use mod-owned dynamic-resolution control to create the lower render-size tuple.
3. Prefer an optimal-settings query when the native bridge can expose one safely.
4. Fall back to source-backed percentages only when the query is unavailable, and log the fallback reason.
5. Keep NVIDIA SDK headers/libs, NVIDIA runtime DLLs, Streamline binaries, and third-party mod files out of the default release package unless a separate distribution review approves them.

The current release-safe native bridge cannot query optimal settings from the bare production `nvngx_dlss.dll` alone, because the required NGX capability-parameter and parameter-accessor surface comes through the SDK wrapper route. Native bridge API version 12 adds an SDK-wrapper-only diagnostic export for this query, while release-safe builds report the route as blocked without changing the default package boundary.

## Next Implementation Implication

Before another game test, use the FSR-off render-scale protocol rather than a blind run. The immediate test question is not "does DLSS depend on FSR?" The source-backed answer is no. The immediate test question is whether the mod-owned HDRP dynamic-resolution control produces a Performance-sized render input and a full-size output target while the game FSR setting remains Off.
