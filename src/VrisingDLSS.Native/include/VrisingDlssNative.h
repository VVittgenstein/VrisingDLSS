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
    VRISINGDLSS_API int __cdecl VrisingDlss_SetRenderEventTexturePayload(
        void* sourceTexturePtr,
        void* destinationTexturePtr,
        int eventId,
        int sequence);
    VRISINGDLSS_API int __cdecl VrisingDlss_GetRenderEventTexturePayloadConsumedCount();
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetRenderEventTexturePayloadStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_SetRenderEventFrameDescriptorPayload(
        void* sourceTexturePtr,
        void* destinationTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr,
        int inputWidth,
        int inputHeight,
        int outputWidth,
        int outputHeight,
        int hdrpFrame,
        int easuSourceFrame,
        int easuDestinationFrame,
        int eventId,
        int sequence);
    VRISINGDLSS_API int __cdecl VrisingDlss_SetRenderEventFrameDescriptorD3D11ValidationPayload(
        void* sourceTexturePtr,
        void* destinationTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr,
        int inputWidth,
        int inputHeight,
        int outputWidth,
        int outputHeight,
        int hdrpFrame,
        int easuSourceFrame,
        int easuDestinationFrame,
        int eventId,
        int sequence);
    VRISINGDLSS_API int __cdecl VrisingDlss_GetRenderEventFrameDescriptorPayloadConsumedCount();
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetRenderEventFrameDescriptorPayloadStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_SetRenderEventDlssFeatureCreatePayload(
        void* sourceTexturePtr,
        void* destinationTexturePtr,
        int eventId,
        int sequence,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        int perfQualityValue,
        int featureFlags);
    VRISINGDLSS_API int __cdecl VrisingDlss_GetRenderEventDlssFeatureCreateConsumedCount();
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetRenderEventDlssFeatureCreateStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeD3D11Texture(void* nativeTexturePtr);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetD3D11ProbeStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeD3D11TexturePair(void* sourceTexturePtr, void* destinationTexturePtr);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetD3D11TexturePairProbeStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssRuntime(const wchar_t* runtimePath);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssRuntimeProbeStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssInitQuery(
        void* nativeTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssInitQueryStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssOptimalSettings(
        void* nativeTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        unsigned int outputWidth,
        unsigned int outputHeight,
        int perfQualityValue);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssOptimalSettingsStatus();
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
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssSuperResolutionInputs(
        void* colorTexturePtr,
        void* outputTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssSuperResolutionInputStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssEvaluate(
        void* colorTexturePtr,
        void* outputTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssEvaluateStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_ProbeDlssPersistentEvaluate(
        void* colorTexturePtr,
        void* outputTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset,
        int evaluateCount);
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssPersistentEvaluateStatus();
    VRISINGDLSS_API int __cdecl VrisingDlss_EvaluateDlssFrameSequence(
        void* colorTexturePtr,
        void* outputTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset);
    VRISINGDLSS_API int __cdecl VrisingDlss_ShutdownDlssFrameSequence();
    VRISINGDLSS_API const char* __cdecl VrisingDlss_GetDlssFrameSequenceStatus();
}
