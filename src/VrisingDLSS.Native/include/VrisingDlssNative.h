#pragma once

#ifdef VRISINGDLSS_NATIVE_EXPORTS
#define VRISINGDLSS_API __declspec(dllexport)
#else
#define VRISINGDLSS_API __declspec(dllimport)
#endif

extern "C"
{
    VRISINGDLSS_API int __cdecl VrisingDlss_GetBridgeApiVersion();
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetBridgeVersion();
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDiagnosticStatus();
    VRISINGDLSS_API void* __cdecl VrisingDlss_GetRenderEventFunc();
    VRISINGDLSS_API int __cdecl VrisingDlss_GetRenderEventCount();
    VRISINGDLSS_API int __cdecl VrisingDlss_GetLastRenderEventId();
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetRenderEventStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeD3D11Texture(void* nativeTexturePtr);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetD3D11ProbeStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssRuntime(const wchar_t* runtimePath);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssRuntimeProbeStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssInitQuery(
        void* nativeTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssInitQueryStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssFeatureCreate(
        void* nativeTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        unsigned int renderWidth,
        unsigned int renderHeight,
        unsigned int targetWidth,
        unsigned int targetHeight,
        int perfQualityValue,
        int featureFlags);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssFeatureCreateStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssEvaluateInputs(
        void* colorTexturePtr,
        void* outputTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssEvaluateInputStatus();
}
