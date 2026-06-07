#define VRISINGDLSS_NATIVE_EXPORTS
#include "VrisingDlssNative.h"

#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>

#if defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
#include <nvsdk_ngx.h>
#include <nvsdk_ngx_helpers.h>
#endif

#if defined(_WIN32)
#define VRISINGDLSS_RENDER_EVENT_CALL __stdcall
#else
#define VRISINGDLSS_RENDER_EVENT_CALL
#endif

namespace
{
    struct RenderEventTexturePayload
    {
        IUnknown* source = nullptr;
        IUnknown* destination = nullptr;
        void* sourcePointer = nullptr;
        void* destinationPointer = nullptr;
        int eventId = 0;
        int sequence = 0;
    };

    struct RenderEventFrameDescriptorPayload
    {
        IUnknown* source = nullptr;
        IUnknown* destination = nullptr;
        IUnknown* depth = nullptr;
        IUnknown* motion = nullptr;
        void* sourcePointer = nullptr;
        void* destinationPointer = nullptr;
        void* depthPointer = nullptr;
        void* motionPointer = nullptr;
        int inputWidth = 0;
        int inputHeight = 0;
        int outputWidth = 0;
        int outputHeight = 0;
        int hdrpFrame = -1;
        int easuSourceFrame = -1;
        int easuDestinationFrame = -1;
        int eventId = 0;
        int sequence = 0;
    };

    struct RenderEventDlssFeatureCreatePayload
    {
        RenderEventTexturePayload textures;
        std::wstring runtimePath;
        std::wstring applicationDataPath;
        unsigned long long applicationId = 0;
        int perfQualityValue = 0;
        int featureFlags = 0;
    };

    std::atomic<int> g_renderEventCount{0};
    std::atomic<int> g_lastRenderEventId{-1};
    std::atomic<int> g_renderEventTexturePayloadSetAttempts{0};
    std::atomic<int> g_renderEventTexturePayloadSetSuccesses{0};
    std::atomic<int> g_renderEventTexturePayloadSetFailures{0};
    std::atomic<int> g_renderEventTexturePayloadConsumedCount{0};
    std::atomic<int> g_renderEventTexturePayloadConsumedFailures{0};
    std::atomic<int> g_renderEventTexturePayloadLastSequence{0};
    std::atomic<int> g_renderEventTexturePayloadLastEventId{-1};
    std::mutex g_renderEventTexturePayloadMutex;
    RenderEventTexturePayload g_renderEventTexturePayload;
    char g_renderEventTexturePayloadStatus[1536] = "render event texture payload probe has not run";
    std::atomic<int> g_renderEventFrameDescriptorPayloadSetAttempts{0};
    std::atomic<int> g_renderEventFrameDescriptorPayloadSetSuccesses{0};
    std::atomic<int> g_renderEventFrameDescriptorPayloadSetFailures{0};
    std::atomic<int> g_renderEventFrameDescriptorPayloadConsumedCount{0};
    std::atomic<int> g_renderEventFrameDescriptorPayloadConsumedFailures{0};
    std::atomic<int> g_renderEventFrameDescriptorPayloadLastSequence{0};
    std::atomic<int> g_renderEventFrameDescriptorPayloadLastEventId{-1};
    std::mutex g_renderEventFrameDescriptorPayloadMutex;
    RenderEventFrameDescriptorPayload g_renderEventFrameDescriptorPayload;
    char g_renderEventFrameDescriptorPayloadStatus[2400] = "render event frame descriptor payload probe has not run";
    std::atomic<int> g_renderEventDlssFeatureCreatePayloadSetAttempts{0};
    std::atomic<int> g_renderEventDlssFeatureCreatePayloadSetSuccesses{0};
    std::atomic<int> g_renderEventDlssFeatureCreatePayloadSetFailures{0};
    std::atomic<int> g_renderEventDlssFeatureCreatePayloadConsumedCount{0};
    std::atomic<int> g_renderEventDlssFeatureCreatePayloadConsumedFailures{0};
    std::atomic<int> g_renderEventDlssFeatureCreatePayloadLastSequence{0};
    std::atomic<int> g_renderEventDlssFeatureCreatePayloadLastEventId{-1};
    std::mutex g_renderEventDlssFeatureCreatePayloadMutex;
    RenderEventDlssFeatureCreatePayload g_renderEventDlssFeatureCreatePayload;
    char g_renderEventDlssFeatureCreatePayloadStatus[2400] = "render event DLSS feature-create payload probe has not run";
    std::mutex g_probeStatusMutex;
    char g_d3d11ProbeStatus[512] = "D3D11 texture probe has not run";
    char g_d3d11TexturePairProbeStatus[1024] = "D3D11 texture pair probe has not run";
    char g_dlssRuntimeProbeStatus[1536] = "DLSS runtime probe has not run";
    char g_dlssInitQueryStatus[1024] = "DLSS init/query probe has not run";
    char g_dlssOptimalSettingsStatus[1536] = "DLSS optimal-settings probe has not run";
    char g_dlssFeatureCreateStatus[1024] = "DLSS feature create probe has not run";
    char g_dlssEvaluateInputStatus[1536] = "DLSS evaluate input probe has not run";
    char g_dlssSuperResolutionInputStatus[1536] = "DLSS super-resolution input probe has not run";
    char g_dlssEvaluateStatus[2048] = "DLSS evaluate probe has not run";
    char g_dlssPersistentEvaluateStatus[2048] = "DLSS persistent evaluate probe has not run";
    char g_dlssFrameSequenceStatus[2400] = "DLSS frame-sequence evaluate probe has not run";
    constexpr unsigned int kNgxResultSuccess = 0x00000001;
    constexpr unsigned int kNgxVersionApi = 0x00000015;

    using NgxResult = unsigned int;
    using NgxD3D11InitFunc = NgxResult(__cdecl*)(
        unsigned long long applicationId,
        const wchar_t* applicationDataPath,
        ID3D11Device* device,
        const void* featureInfo,
        unsigned int sdkVersion);
    using NgxD3D11GetCapabilityParametersFunc = NgxResult(__cdecl*)(void** outParameters);
    using NgxD3D11DestroyParametersFunc = NgxResult(__cdecl*)(void* parameters);
    using NgxD3D11Shutdown1Func = NgxResult(__cdecl*)(ID3D11Device* device);
    using NgxD3D11ShutdownFunc = NgxResult(__cdecl*)();
    using NgxParameterGetIntFunc = NgxResult(__cdecl*)(void* parameters, const char* name, int* outValue);
    using NgxParameterGetUIntFunc = NgxResult(__cdecl*)(void* parameters, const char* name, unsigned int* outValue);

    void TryConsumeRenderEventTexturePayload(int eventId);
    void TryConsumeRenderEventFrameDescriptorPayload(int eventId);
    void TryConsumeRenderEventDlssFeatureCreatePayload(int eventId);
#if defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
    int ProbeDlssFeatureCreateWithSdkWrapper(
        ID3D11Device* device,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        unsigned int renderWidth,
        unsigned int renderHeight,
        unsigned int targetWidth,
        unsigned int targetHeight,
        int perfQualityValue,
        int featureFlags);
#endif

    void VRISINGDLSS_RENDER_EVENT_CALL OnRenderEvent(int eventId)
    {
        g_lastRenderEventId.store(eventId);
        g_renderEventCount.fetch_add(1);
        TryConsumeRenderEventTexturePayload(eventId);
        TryConsumeRenderEventFrameDescriptorPayload(eventId);
        TryConsumeRenderEventDlssFeatureCreatePayload(eventId);
    }

    void SetD3D11ProbeStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_d3d11ProbeStatus, sizeof(g_d3d11ProbeStatus), "%s", message);
    }

    void SetD3D11TexturePairProbeStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_d3d11TexturePairProbeStatus, sizeof(g_d3d11TexturePairProbeStatus), "%s", message);
    }

    void SetDlssRuntimeProbeStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssRuntimeProbeStatus, sizeof(g_dlssRuntimeProbeStatus), "%s", message);
    }

    void SetDlssInitQueryStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssInitQueryStatus, sizeof(g_dlssInitQueryStatus), "%s", message);
    }

    void SetDlssOptimalSettingsStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssOptimalSettingsStatus, sizeof(g_dlssOptimalSettingsStatus), "%s", message);
    }

    void SetDlssFeatureCreateStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssFeatureCreateStatus, sizeof(g_dlssFeatureCreateStatus), "%s", message);
    }

    void SetDlssEvaluateInputStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssEvaluateInputStatus, sizeof(g_dlssEvaluateInputStatus), "%s", message);
    }

    void SetDlssSuperResolutionInputStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssSuperResolutionInputStatus, sizeof(g_dlssSuperResolutionInputStatus), "%s", message);
    }

    void SetDlssEvaluateStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssEvaluateStatus, sizeof(g_dlssEvaluateStatus), "%s", message);
    }

    void SetDlssPersistentEvaluateStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssPersistentEvaluateStatus, sizeof(g_dlssPersistentEvaluateStatus), "%s", message);
    }

    void SetDlssFrameSequenceStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssFrameSequenceStatus, sizeof(g_dlssFrameSequenceStatus), "%s", message);
    }

    double ElapsedMilliseconds(const LARGE_INTEGER& start, const LARGE_INTEGER& end, const LARGE_INTEGER& frequency)
    {
        if (frequency.QuadPart <= 0)
        {
            return 0.0;
        }

        return static_cast<double>(end.QuadPart - start.QuadPart) * 1000.0 / static_cast<double>(frequency.QuadPart);
    }

    struct EvaluateTextureInfo
    {
        const char* label = "";
        HRESULT queryResult = E_FAIL;
        D3D11_RESOURCE_DIMENSION dimension = D3D11_RESOURCE_DIMENSION_UNKNOWN;
        DXGI_FORMAT format = DXGI_FORMAT_UNKNOWN;
        UINT width = 0;
        UINT height = 0;
        UINT mipLevels = 0;
        UINT arraySize = 0;
        ID3D11Device* device = nullptr;
    };

    void ReleaseEvaluateTextureInfo(EvaluateTextureInfo* info)
    {
        if (info != nullptr && info->device != nullptr)
        {
            info->device->Release();
            info->device = nullptr;
        }
    }

    bool TryDescribeEvaluateTexture(
        const char* label,
        void* nativeTexturePtr,
        EvaluateTextureInfo* outInfo,
        char* error,
        size_t errorSize)
    {
        if (outInfo == nullptr || error == nullptr || errorSize == 0)
        {
            return false;
        }

        *outInfo = {};
        outInfo->label = label;

        if (nativeTexturePtr == nullptr)
        {
            std::snprintf(error, errorSize, "%s pointer was null", label);
            return false;
        }

        ID3D11Resource* resource = nullptr;
        outInfo->queryResult = static_cast<IUnknown*>(nativeTexturePtr)->QueryInterface(
            __uuidof(ID3D11Resource),
            reinterpret_cast<void**>(&resource));
        if (FAILED(outInfo->queryResult) || resource == nullptr)
        {
            std::snprintf(
                error,
                errorSize,
                "%s QueryInterface(ID3D11Resource) returned hr=0x%08X",
                label,
                static_cast<unsigned int>(outInfo->queryResult));
            return false;
        }

        resource->GetType(&outInfo->dimension);
        if (outInfo->dimension != D3D11_RESOURCE_DIMENSION_TEXTURE2D)
        {
            std::snprintf(
                error,
                errorSize,
                "%s resource dimension was %u instead of Texture2D",
                label,
                static_cast<unsigned int>(outInfo->dimension));
            resource->Release();
            return false;
        }

        resource->GetDevice(&outInfo->device);
        if (outInfo->device == nullptr)
        {
            std::snprintf(error, errorSize, "%s resource did not return a D3D11 device", label);
            resource->Release();
            return false;
        }

        ID3D11Texture2D* texture2D = nullptr;
        HRESULT textureResult = resource->QueryInterface(
            __uuidof(ID3D11Texture2D),
            reinterpret_cast<void**>(&texture2D));
        if (FAILED(textureResult) || texture2D == nullptr)
        {
            std::snprintf(
                error,
                errorSize,
                "%s QueryInterface(ID3D11Texture2D) returned hr=0x%08X",
                label,
                static_cast<unsigned int>(textureResult));
            resource->Release();
            return false;
        }

        D3D11_TEXTURE2D_DESC desc{};
        texture2D->GetDesc(&desc);
        outInfo->format = desc.Format;
        outInfo->width = desc.Width;
        outInfo->height = desc.Height;
        outInfo->mipLevels = desc.MipLevels;
        outInfo->arraySize = desc.ArraySize;

        texture2D->Release();
        resource->Release();

        if (outInfo->width == 0 || outInfo->height == 0)
        {
            std::snprintf(error, errorSize, "%s texture dimensions were zero", label);
            return false;
        }

        return true;
    }

    bool EvaluateInputDimensionsMatch(const EvaluateTextureInfo& reference, const EvaluateTextureInfo& candidate)
    {
        return reference.width == candidate.width && reference.height == candidate.height;
    }

    void ReleaseRenderEventTexturePayload(RenderEventTexturePayload* payload)
    {
        if (payload == nullptr)
        {
            return;
        }

        if (payload->source != nullptr)
        {
            payload->source->Release();
            payload->source = nullptr;
        }

        if (payload->destination != nullptr)
        {
            payload->destination->Release();
            payload->destination = nullptr;
        }

        payload->sourcePointer = nullptr;
        payload->destinationPointer = nullptr;
        payload->eventId = 0;
        payload->sequence = 0;
    }

    void ReleaseRenderEventFrameDescriptorPayload(RenderEventFrameDescriptorPayload* payload)
    {
        if (payload == nullptr)
        {
            return;
        }

        if (payload->source != nullptr)
        {
            payload->source->Release();
            payload->source = nullptr;
        }

        if (payload->destination != nullptr)
        {
            payload->destination->Release();
            payload->destination = nullptr;
        }

        if (payload->depth != nullptr)
        {
            payload->depth->Release();
            payload->depth = nullptr;
        }

        if (payload->motion != nullptr)
        {
            payload->motion->Release();
            payload->motion = nullptr;
        }

        payload->sourcePointer = nullptr;
        payload->destinationPointer = nullptr;
        payload->depthPointer = nullptr;
        payload->motionPointer = nullptr;
        payload->inputWidth = 0;
        payload->inputHeight = 0;
        payload->outputWidth = 0;
        payload->outputHeight = 0;
        payload->hdrpFrame = -1;
        payload->easuSourceFrame = -1;
        payload->easuDestinationFrame = -1;
        payload->eventId = 0;
        payload->sequence = 0;
    }

    void ReleaseRenderEventDlssFeatureCreatePayload(RenderEventDlssFeatureCreatePayload* payload)
    {
        if (payload == nullptr)
        {
            return;
        }

        ReleaseRenderEventTexturePayload(&payload->textures);
        payload->runtimePath.clear();
        payload->applicationDataPath.clear();
        payload->applicationId = 0;
        payload->perfQualityValue = 0;
        payload->featureFlags = 0;
    }

    void SetRenderEventTexturePayloadFailureStatus(const char* label, const char* detail, int eventId, int sequence)
    {
        std::lock_guard<std::mutex> lock(g_renderEventTexturePayloadMutex);
        std::snprintf(
            g_renderEventTexturePayloadStatus,
            sizeof(g_renderEventTexturePayloadStatus),
            "render event texture payload %s failed: %s; setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d",
            label,
            detail,
            g_renderEventTexturePayloadSetAttempts.load(),
            g_renderEventTexturePayloadSetSuccesses.load(),
            g_renderEventTexturePayloadSetFailures.load(),
            g_renderEventTexturePayloadConsumedCount.load(),
            g_renderEventTexturePayloadConsumedFailures.load(),
            eventId,
            sequence);
    }

    void SetRenderEventFrameDescriptorPayloadFailureStatus(const char* label, const char* detail, int eventId, int sequence)
    {
        std::lock_guard<std::mutex> lock(g_renderEventFrameDescriptorPayloadMutex);
        std::snprintf(
            g_renderEventFrameDescriptorPayloadStatus,
            sizeof(g_renderEventFrameDescriptorPayloadStatus),
            "render event frame descriptor payload %s failed: %s; setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d",
            label,
            detail,
            g_renderEventFrameDescriptorPayloadSetAttempts.load(),
            g_renderEventFrameDescriptorPayloadSetSuccesses.load(),
            g_renderEventFrameDescriptorPayloadSetFailures.load(),
            g_renderEventFrameDescriptorPayloadConsumedCount.load(),
            g_renderEventFrameDescriptorPayloadConsumedFailures.load(),
            eventId,
            sequence);
    }

    void SetRenderEventDlssFeatureCreatePayloadFailureStatus(const char* label, const char* detail, int eventId, int sequence)
    {
        std::lock_guard<std::mutex> lock(g_renderEventDlssFeatureCreatePayloadMutex);
        std::snprintf(
            g_renderEventDlssFeatureCreatePayloadStatus,
            sizeof(g_renderEventDlssFeatureCreatePayloadStatus),
            "render event DLSS feature-create payload %s failed: %s; setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d",
            label,
            detail,
            g_renderEventDlssFeatureCreatePayloadSetAttempts.load(),
            g_renderEventDlssFeatureCreatePayloadSetSuccesses.load(),
            g_renderEventDlssFeatureCreatePayloadSetFailures.load(),
            g_renderEventDlssFeatureCreatePayloadConsumedCount.load(),
            g_renderEventDlssFeatureCreatePayloadConsumedFailures.load(),
            eventId,
            sequence);
    }

    void TryConsumeRenderEventTexturePayload(int eventId)
    {
        RenderEventTexturePayload payload{};
        {
            std::lock_guard<std::mutex> lock(g_renderEventTexturePayloadMutex);
            if (g_renderEventTexturePayload.source == nullptr
                || g_renderEventTexturePayload.destination == nullptr
                || g_renderEventTexturePayload.eventId != eventId)
            {
                return;
            }

            payload = g_renderEventTexturePayload;
            g_renderEventTexturePayload = {};
        }

        EvaluateTextureInfo source{};
        EvaluateTextureInfo destination{};
        char error[384] = {};
        bool success = TryDescribeEvaluateTexture(
            "source",
            payload.sourcePointer,
            &source,
            error,
            sizeof(error));
        if (success)
        {
            success = TryDescribeEvaluateTexture(
                "destination",
                payload.destinationPointer,
                &destination,
                error,
                sizeof(error));
        }

        if (!success)
        {
            g_renderEventTexturePayloadConsumedFailures.fetch_add(1);
            SetRenderEventTexturePayloadFailureStatus("consume", error, eventId, payload.sequence);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            ReleaseRenderEventTexturePayload(&payload);
            return;
        }

        if (source.device != destination.device)
        {
            g_renderEventTexturePayloadConsumedFailures.fetch_add(1);
            SetRenderEventTexturePayloadFailureStatus(
                "consume",
                "source and destination were not on the same D3D11 device",
                eventId,
                payload.sequence);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            ReleaseRenderEventTexturePayload(&payload);
            return;
        }

        if (!(destination.width > source.width && destination.height > source.height))
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "destination was not larger than source; source=%ux%u destination=%ux%u",
                source.width,
                source.height,
                destination.width,
                destination.height);
            g_renderEventTexturePayloadConsumedFailures.fetch_add(1);
            SetRenderEventTexturePayloadFailureStatus("consume", message, eventId, payload.sequence);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            ReleaseRenderEventTexturePayload(&payload);
            return;
        }

        const double widthScale = static_cast<double>(destination.width) / static_cast<double>(source.width);
        const double heightScale = static_cast<double>(destination.height) / static_cast<double>(source.height);
        const int consumed = g_renderEventTexturePayloadConsumedCount.fetch_add(1) + 1;
        g_renderEventTexturePayloadLastSequence.store(payload.sequence);
        g_renderEventTexturePayloadLastEventId.store(eventId);
        {
            std::lock_guard<std::mutex> lock(g_renderEventTexturePayloadMutex);
            std::snprintf(
                g_renderEventTexturePayloadStatus,
                sizeof(g_renderEventTexturePayloadStatus),
                "render event texture payload consumed: setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d; sourcePtr=%p; destinationPtr=%p; sameDevice=yes; source=%ux%u fmt=%u mips=%u array=%u; destination=%ux%u fmt=%u mips=%u array=%u; scale=(%.3fx,%.3fx)",
                g_renderEventTexturePayloadSetAttempts.load(),
                g_renderEventTexturePayloadSetSuccesses.load(),
                g_renderEventTexturePayloadSetFailures.load(),
                consumed,
                g_renderEventTexturePayloadConsumedFailures.load(),
                eventId,
                payload.sequence,
                payload.sourcePointer,
                payload.destinationPointer,
                source.width,
                source.height,
                static_cast<unsigned int>(source.format),
                source.mipLevels,
                source.arraySize,
                destination.width,
                destination.height,
                static_cast<unsigned int>(destination.format),
                destination.mipLevels,
                destination.arraySize,
                widthScale,
                heightScale);
        }

        ReleaseEvaluateTextureInfo(&source);
        ReleaseEvaluateTextureInfo(&destination);
        ReleaseRenderEventTexturePayload(&payload);
    }

    void TryConsumeRenderEventFrameDescriptorPayload(int eventId)
    {
        RenderEventFrameDescriptorPayload payload{};
        {
            std::lock_guard<std::mutex> lock(g_renderEventFrameDescriptorPayloadMutex);
            if (g_renderEventFrameDescriptorPayload.source == nullptr
                || g_renderEventFrameDescriptorPayload.destination == nullptr
                || g_renderEventFrameDescriptorPayload.depth == nullptr
                || g_renderEventFrameDescriptorPayload.motion == nullptr
                || g_renderEventFrameDescriptorPayload.eventId != eventId)
            {
                return;
            }

            payload = g_renderEventFrameDescriptorPayload;
            g_renderEventFrameDescriptorPayload = {};
        }

        if (payload.inputWidth <= 0
            || payload.inputHeight <= 0
            || payload.outputWidth <= 0
            || payload.outputHeight <= 0)
        {
            g_renderEventFrameDescriptorPayloadConsumedFailures.fetch_add(1);
            SetRenderEventFrameDescriptorPayloadFailureStatus("consume", "descriptor dimensions were not positive", eventId, payload.sequence);
            ReleaseRenderEventFrameDescriptorPayload(&payload);
            return;
        }

        if (!(payload.outputWidth > payload.inputWidth && payload.outputHeight > payload.inputHeight))
        {
            g_renderEventFrameDescriptorPayloadConsumedFailures.fetch_add(1);
            SetRenderEventFrameDescriptorPayloadFailureStatus("consume", "descriptor output was not larger than input", eventId, payload.sequence);
            ReleaseRenderEventFrameDescriptorPayload(&payload);
            return;
        }

        const int sourceDelta = payload.easuSourceFrame - payload.hdrpFrame;
        const int destinationDelta = payload.easuDestinationFrame - payload.hdrpFrame;
        const int consumed = g_renderEventFrameDescriptorPayloadConsumedCount.fetch_add(1) + 1;
        g_renderEventFrameDescriptorPayloadLastSequence.store(payload.sequence);
        g_renderEventFrameDescriptorPayloadLastEventId.store(eventId);
        {
            std::lock_guard<std::mutex> lock(g_renderEventFrameDescriptorPayloadMutex);
            std::snprintf(
                g_renderEventFrameDescriptorPayloadStatus,
                sizeof(g_renderEventFrameDescriptorPayloadStatus),
                "render event frame descriptor payload consumed: setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d; sourcePtr=%p; destinationPtr=%p; depthPtr=%p; motionPtr=%p; input=%dx%d; output=%dx%d; hdrpFrame=%d; easuSourceFrame=%d; easuDestinationFrame=%d; sourceFrameDelta=%d; destinationFrameDelta=%d; validation=D3D11-not-queried; ngx=not-loaded; evaluate=not-run",
                g_renderEventFrameDescriptorPayloadSetAttempts.load(),
                g_renderEventFrameDescriptorPayloadSetSuccesses.load(),
                g_renderEventFrameDescriptorPayloadSetFailures.load(),
                consumed,
                g_renderEventFrameDescriptorPayloadConsumedFailures.load(),
                eventId,
                payload.sequence,
                payload.sourcePointer,
                payload.destinationPointer,
                payload.depthPointer,
                payload.motionPointer,
                payload.inputWidth,
                payload.inputHeight,
                payload.outputWidth,
                payload.outputHeight,
                payload.hdrpFrame,
                payload.easuSourceFrame,
                payload.easuDestinationFrame,
                sourceDelta,
                destinationDelta);
        }

        ReleaseRenderEventFrameDescriptorPayload(&payload);
    }

    void TryConsumeRenderEventDlssFeatureCreatePayload(int eventId)
    {
        RenderEventDlssFeatureCreatePayload payload{};
        {
            std::lock_guard<std::mutex> lock(g_renderEventDlssFeatureCreatePayloadMutex);
            if (g_renderEventDlssFeatureCreatePayload.textures.source == nullptr
                || g_renderEventDlssFeatureCreatePayload.textures.destination == nullptr
                || g_renderEventDlssFeatureCreatePayload.textures.eventId != eventId)
            {
                return;
            }

            payload = g_renderEventDlssFeatureCreatePayload;
            g_renderEventDlssFeatureCreatePayload = {};
        }

        EvaluateTextureInfo source{};
        EvaluateTextureInfo destination{};
        char error[384] = {};
        bool success = TryDescribeEvaluateTexture(
            "source",
            payload.textures.sourcePointer,
            &source,
            error,
            sizeof(error));
        if (success)
        {
            success = TryDescribeEvaluateTexture(
                "destination",
                payload.textures.destinationPointer,
                &destination,
                error,
                sizeof(error));
        }

        if (!success)
        {
            g_renderEventDlssFeatureCreatePayloadConsumedFailures.fetch_add(1);
            SetRenderEventDlssFeatureCreatePayloadFailureStatus("consume", error, eventId, payload.textures.sequence);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            ReleaseRenderEventDlssFeatureCreatePayload(&payload);
            return;
        }

        if (source.device != destination.device)
        {
            g_renderEventDlssFeatureCreatePayloadConsumedFailures.fetch_add(1);
            SetRenderEventDlssFeatureCreatePayloadFailureStatus(
                "consume",
                "source and destination were not on the same D3D11 device",
                eventId,
                payload.textures.sequence);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            ReleaseRenderEventDlssFeatureCreatePayload(&payload);
            return;
        }

        if (!(destination.width > source.width && destination.height > source.height))
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "destination was not larger than source; source=%ux%u destination=%ux%u",
                source.width,
                source.height,
                destination.width,
                destination.height);
            g_renderEventDlssFeatureCreatePayloadConsumedFailures.fetch_add(1);
            SetRenderEventDlssFeatureCreatePayloadFailureStatus("consume", message, eventId, payload.textures.sequence);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            ReleaseRenderEventDlssFeatureCreatePayload(&payload);
            return;
        }

        char featureStatus[1024] = {};
        int createSucceeded = 0;
#if !defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        std::snprintf(
            featureStatus,
            sizeof(featureStatus),
            "DLSS feature create probe blocked: native bridge was built without NVIDIA SDK wrapper integration");
#else
        createSucceeded = ProbeDlssFeatureCreateWithSdkWrapper(
            source.device,
            payload.runtimePath.c_str(),
            payload.applicationDataPath.empty() ? L"." : payload.applicationDataPath.c_str(),
            payload.applicationId,
            source.width,
            source.height,
            destination.width,
            destination.height,
            payload.perfQualityValue,
            payload.featureFlags);
        {
            std::lock_guard<std::mutex> lock(g_probeStatusMutex);
            std::snprintf(featureStatus, sizeof(featureStatus), "%s", g_dlssFeatureCreateStatus);
        }
#endif

        if (createSucceeded != 1)
        {
            g_renderEventDlssFeatureCreatePayloadConsumedFailures.fetch_add(1);
            SetRenderEventDlssFeatureCreatePayloadFailureStatus("create", featureStatus, eventId, payload.textures.sequence);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            ReleaseRenderEventDlssFeatureCreatePayload(&payload);
            return;
        }

        const double widthScale = static_cast<double>(destination.width) / static_cast<double>(source.width);
        const double heightScale = static_cast<double>(destination.height) / static_cast<double>(source.height);
        const int consumed = g_renderEventDlssFeatureCreatePayloadConsumedCount.fetch_add(1) + 1;
        g_renderEventDlssFeatureCreatePayloadLastSequence.store(payload.textures.sequence);
        g_renderEventDlssFeatureCreatePayloadLastEventId.store(eventId);
        {
            std::lock_guard<std::mutex> lock(g_renderEventDlssFeatureCreatePayloadMutex);
            std::snprintf(
                g_renderEventDlssFeatureCreatePayloadStatus,
                sizeof(g_renderEventDlssFeatureCreatePayloadStatus),
                "render event DLSS feature-create payload consumed: setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d; sourcePtr=%p; destinationPtr=%p; sameDevice=yes; source=%ux%u fmt=%u mips=%u array=%u; destination=%ux%u fmt=%u mips=%u array=%u; scale=(%.3fx,%.3fx); appId=%llu; perfQuality=%d; flags=0x%08X; featureStatus=\"%s\"",
                g_renderEventDlssFeatureCreatePayloadSetAttempts.load(),
                g_renderEventDlssFeatureCreatePayloadSetSuccesses.load(),
                g_renderEventDlssFeatureCreatePayloadSetFailures.load(),
                consumed,
                g_renderEventDlssFeatureCreatePayloadConsumedFailures.load(),
                eventId,
                payload.textures.sequence,
                payload.textures.sourcePointer,
                payload.textures.destinationPointer,
                source.width,
                source.height,
                static_cast<unsigned int>(source.format),
                source.mipLevels,
                source.arraySize,
                destination.width,
                destination.height,
                static_cast<unsigned int>(destination.format),
                destination.mipLevels,
                destination.arraySize,
                widthScale,
                heightScale,
                payload.applicationId,
                payload.perfQualityValue,
                static_cast<unsigned int>(payload.featureFlags),
                featureStatus);
        }

        ReleaseEvaluateTextureInfo(&source);
        ReleaseEvaluateTextureInfo(&destination);
        ReleaseRenderEventDlssFeatureCreatePayload(&payload);
    }

    bool TryQueryD3D11Resource(
        const char* label,
        void* nativeTexturePtr,
        ID3D11Resource** outResource,
        char* error,
        size_t errorSize)
    {
        if (outResource == nullptr || error == nullptr || errorSize == 0)
        {
            return false;
        }

        *outResource = nullptr;
        if (nativeTexturePtr == nullptr)
        {
            std::snprintf(error, errorSize, "%s pointer was null", label);
            return false;
        }

        HRESULT result = static_cast<IUnknown*>(nativeTexturePtr)->QueryInterface(
            __uuidof(ID3D11Resource),
            reinterpret_cast<void**>(outResource));
        if (FAILED(result) || *outResource == nullptr)
        {
            std::snprintf(
                error,
                errorSize,
                "%s QueryInterface(ID3D11Resource) returned hr=0x%08X",
                label,
                static_cast<unsigned int>(result));
            return false;
        }

        return true;
    }

    template <typename T>
    T GetNgxExport(HMODULE module, const char* name)
    {
        return reinterpret_cast<T>(GetProcAddress(module, name));
    }

    bool TryGetNgxIntParameter(
        void* parameters,
        const char* name,
        NgxParameterGetIntFunc getInt,
        NgxParameterGetUIntFunc getUInt,
        int* outValue,
        NgxResult* outResult)
    {
        if (outValue == nullptr || outResult == nullptr)
        {
            return false;
        }

        if (getInt != nullptr)
        {
            int value = 0;
            NgxResult result = getInt(parameters, name, &value);
            if (result == kNgxResultSuccess)
            {
                *outValue = value;
                *outResult = result;
                return true;
            }

            *outResult = result;
        }

        if (getUInt != nullptr)
        {
            unsigned int value = 0;
            NgxResult result = getUInt(parameters, name, &value);
            if (result == kNgxResultSuccess)
            {
                *outValue = static_cast<int>(value);
                *outResult = result;
                return true;
            }

            *outResult = result;
        }

        return false;
    }

    std::wstring GetParentDirectory(const wchar_t* path)
    {
        if (path == nullptr || path[0] == L'\0')
        {
            return L"";
        }

        std::wstring value(path);
        const size_t separator = value.find_last_of(L"\\/");
        if (separator == std::wstring::npos)
        {
            return L".";
        }

        return value.substr(0, separator);
    }

    void SetDlssInitQueryCompletedStatus(
        const char* route,
        unsigned long long applicationId,
        NgxResult initResult,
        NgxResult capabilityResult,
        int available,
        NgxResult availableResult,
        int needsUpdatedDriver,
        NgxResult needsDriverResult,
        int minDriverMajor,
        int minDriverMinor,
        NgxResult minMajorResult,
        NgxResult minMinorResult,
        int featureInitResult,
        NgxResult featureInitResultStatus,
        NgxResult destroyResult,
        NgxResult shutdownResult)
    {
        char message[832];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS init/query probe completed via %s; appId=%llu; init=0x%08X; capability=0x%08X; available=%d(result=0x%08X); needsUpdatedDriver=%d(result=0x%08X); minDriver=%d.%d(results=0x%08X/0x%08X); featureInitResult=%d(result=0x%08X); destroy=0x%08X; shutdown=0x%08X",
            route,
            applicationId,
            initResult,
            capabilityResult,
            available,
            availableResult,
            needsUpdatedDriver,
            needsDriverResult,
            minDriverMajor,
            minDriverMinor,
            minMajorResult,
            minMinorResult,
            featureInitResult,
            featureInitResultStatus,
            destroyResult,
            shutdownResult);

        SetDlssInitQueryStatus(message);
    }

#if defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
    NVSDK_NGX_Result InitializeNgxD3D11WithSdkWrapper(
        ID3D11Device* device,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        NVSDK_NGX_FeatureCommonInfo* outFeatureInfo,
        std::wstring* outRuntimeDirectory,
        const char** outInitRoute)
    {
        if (outRuntimeDirectory == nullptr || outFeatureInfo == nullptr || outInitRoute == nullptr)
        {
            return NVSDK_NGX_Result_FAIL_InvalidParameter;
        }

        *outRuntimeDirectory = GetParentDirectory(runtimePath);
        const wchar_t* featurePaths[] = { outRuntimeDirectory->c_str() };

        *outFeatureInfo = {};
        if (!outRuntimeDirectory->empty())
        {
            outFeatureInfo->PathListInfo.Path = featurePaths;
            outFeatureInfo->PathListInfo.Length = 1;
        }

        const NVSDK_NGX_FeatureCommonInfo* featureInfoPointer = outRuntimeDirectory->empty() ? nullptr : outFeatureInfo;
        *outInitRoute = "SDK wrapper AppID";
        if (applicationId == 0)
        {
            *outInitRoute = "SDK wrapper ProjectID";
            return NVSDK_NGX_D3D11_Init_with_ProjectID(
                "0b8c67f3-3b8b-4e79-a062-5be2e52f39a7",
                NVSDK_NGX_ENGINE_TYPE_UNITY,
                "Unity 2022.3",
                applicationDataPath,
                device,
                featureInfoPointer,
                NVSDK_NGX_Version_API);
        }

        return NVSDK_NGX_D3D11_Init(
            applicationId,
            applicationDataPath,
            device,
            featureInfoPointer,
            NVSDK_NGX_Version_API);
    }

    bool TryGetNgxIntParameterFromSdkWrapper(
        NVSDK_NGX_Parameter* parameters,
        const char* name,
        int* outValue,
        NgxResult* outResult)
    {
        if (parameters == nullptr || outValue == nullptr || outResult == nullptr)
        {
            return false;
        }

        int intValue = 0;
        NVSDK_NGX_Result intResult = NVSDK_NGX_Parameter_GetI(parameters, name, &intValue);
        if (intResult == NVSDK_NGX_Result_Success)
        {
            *outValue = intValue;
            *outResult = static_cast<NgxResult>(intResult);
            return true;
        }

        *outResult = static_cast<NgxResult>(intResult);

        unsigned int uintValue = 0;
        NVSDK_NGX_Result uintResult = NVSDK_NGX_Parameter_GetUI(parameters, name, &uintValue);
        if (uintResult == NVSDK_NGX_Result_Success)
        {
            *outValue = static_cast<int>(uintValue);
            *outResult = static_cast<NgxResult>(uintResult);
            return true;
        }

        *outResult = static_cast<NgxResult>(uintResult);
        return false;
    }

    struct DlssFrameSequenceState
    {
        bool active = false;
        ID3D11Device* device = nullptr;
        ID3D11DeviceContext* context = nullptr;
        NVSDK_NGX_Parameter* parameters = nullptr;
        NVSDK_NGX_Handle* feature = nullptr;
        UINT renderWidth = 0;
        UINT renderHeight = 0;
        UINT targetWidth = 0;
        UINT targetHeight = 0;
        int perfQualityValue = 0;
        int featureFlags = 0;
        unsigned long long applicationId = 0;
        std::wstring runtimePath;
        std::wstring applicationDataPath;
        const char* initRoute = "";
        NVSDK_NGX_Result initResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result capabilityResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result createResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        int available = -1;
        NgxResult availableResult = 0;
        int createCount = 0;
        int evaluateCount = 0;
        int evaluateSuccesses = 0;
        NVSDK_NGX_Result lastEvaluateResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
    };

    struct DlssFrameSequenceShutdownResult
    {
        bool hadSession = false;
        int createCount = 0;
        int evaluateCount = 0;
        int evaluateSuccesses = 0;
        NVSDK_NGX_Result releaseResult = NVSDK_NGX_Result_Success;
        NVSDK_NGX_Result destroyResult = NVSDK_NGX_Result_Success;
        NVSDK_NGX_Result shutdownResult = NVSDK_NGX_Result_Success;
    };

    std::mutex g_dlssFrameSequenceMutex;
    DlssFrameSequenceState g_dlssFrameSequence;

    DlssFrameSequenceShutdownResult ShutdownDlssFrameSequenceLocked()
    {
        DlssFrameSequenceShutdownResult result{};
        result.hadSession = g_dlssFrameSequence.active
            || g_dlssFrameSequence.feature != nullptr
            || g_dlssFrameSequence.parameters != nullptr
            || g_dlssFrameSequence.device != nullptr
            || g_dlssFrameSequence.context != nullptr;
        result.createCount = g_dlssFrameSequence.createCount;
        result.evaluateCount = g_dlssFrameSequence.evaluateCount;
        result.evaluateSuccesses = g_dlssFrameSequence.evaluateSuccesses;

        if (g_dlssFrameSequence.feature != nullptr)
        {
            result.releaseResult = NVSDK_NGX_D3D11_ReleaseFeature(g_dlssFrameSequence.feature);
            g_dlssFrameSequence.feature = nullptr;
        }

        if (g_dlssFrameSequence.parameters != nullptr)
        {
            result.destroyResult = NVSDK_NGX_D3D11_DestroyParameters(g_dlssFrameSequence.parameters);
            g_dlssFrameSequence.parameters = nullptr;
        }

        if (g_dlssFrameSequence.active && g_dlssFrameSequence.device != nullptr)
        {
            result.shutdownResult = NVSDK_NGX_D3D11_Shutdown1(g_dlssFrameSequence.device);
        }

        if (g_dlssFrameSequence.context != nullptr)
        {
            g_dlssFrameSequence.context->Release();
            g_dlssFrameSequence.context = nullptr;
        }

        if (g_dlssFrameSequence.device != nullptr)
        {
            g_dlssFrameSequence.device->Release();
            g_dlssFrameSequence.device = nullptr;
        }

        g_dlssFrameSequence = DlssFrameSequenceState{};
        return result;
    }

    bool DlssFrameSequenceNeedsRecreate(
        const EvaluateTextureInfo& color,
        const EvaluateTextureInfo& output,
        const std::wstring& runtimePath,
        const std::wstring& applicationDataPath,
        unsigned long long applicationId,
        int perfQualityValue,
        int featureFlags)
    {
        return !g_dlssFrameSequence.active
            || g_dlssFrameSequence.device != color.device
            || g_dlssFrameSequence.renderWidth != color.width
            || g_dlssFrameSequence.renderHeight != color.height
            || g_dlssFrameSequence.targetWidth != output.width
            || g_dlssFrameSequence.targetHeight != output.height
            || g_dlssFrameSequence.perfQualityValue != perfQualityValue
            || g_dlssFrameSequence.featureFlags != featureFlags
            || g_dlssFrameSequence.applicationId != applicationId
            || g_dlssFrameSequence.runtimePath != runtimePath
            || g_dlssFrameSequence.applicationDataPath != applicationDataPath;
    }

    int EvaluateDlssFrameSequenceWithSdkWrapper(
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
        int reset)
    {
        EvaluateTextureInfo color{};
        EvaluateTextureInfo output{};
        EvaluateTextureInfo depth{};
        EvaluateTextureInfo motion{};
        char error[384] = {};
        LARGE_INTEGER timingFrequency{};
        LARGE_INTEGER timingStart{};
        LARGE_INTEGER timingDescribeEnd{};
        LARGE_INTEGER timingQueryEnd{};
        LARGE_INTEGER timingEvaluateStart{};
        LARGE_INTEGER timingEvaluateEnd{};
        QueryPerformanceFrequency(&timingFrequency);
        QueryPerformanceCounter(&timingStart);

        if (!TryDescribeEvaluateTexture("color", colorTexturePtr, &color, error, sizeof(error))
            || !TryDescribeEvaluateTexture("output", outputTexturePtr, &output, error, sizeof(error))
            || !TryDescribeEvaluateTexture("depth", depthTexturePtr, &depth, error, sizeof(error))
            || !TryDescribeEvaluateTexture("motion", motionTexturePtr, &motion, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS frame-sequence evaluate probe failed: %s", error);
            SetDlssFrameSequenceStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }
        QueryPerformanceCounter(&timingDescribeEnd);

        const bool sameDevice = color.device == output.device
            && color.device == depth.device
            && color.device == motion.device;
        const bool depthMatchesColor = EvaluateInputDimensionsMatch(color, depth);
        const bool motionMatchesColor = EvaluateInputDimensionsMatch(color, motion);
        if (!sameDevice || !depthMatchesColor || !motionMatchesColor)
        {
            char message[640];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS frame-sequence evaluate probe failed: invalid input tuple; sameDevice=%s; color=%ux%u output=%ux%u depth=%ux%u motion=%ux%u",
                sameDevice ? "yes" : "no",
                color.width,
                color.height,
                output.width,
                output.height,
                depth.width,
                depth.height,
                motion.width,
                motion.height);
            SetDlssFrameSequenceStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }
        timingEvaluateStart = timingDescribeEnd;
        timingEvaluateEnd = timingDescribeEnd;

        ID3D11Resource* colorResource = nullptr;
        ID3D11Resource* outputResource = nullptr;
        ID3D11Resource* depthResource = nullptr;
        ID3D11Resource* motionResource = nullptr;
        if (!TryQueryD3D11Resource("color", colorTexturePtr, &colorResource, error, sizeof(error))
            || !TryQueryD3D11Resource("output", outputTexturePtr, &outputResource, error, sizeof(error))
            || !TryQueryD3D11Resource("depth", depthTexturePtr, &depthResource, error, sizeof(error))
            || !TryQueryD3D11Resource("motion", motionTexturePtr, &motionResource, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS frame-sequence evaluate probe failed: %s", error);
            SetDlssFrameSequenceStatus(message);
            if (colorResource != nullptr) { colorResource->Release(); }
            if (outputResource != nullptr) { outputResource->Release(); }
            if (depthResource != nullptr) { depthResource->Release(); }
            if (motionResource != nullptr) { motionResource->Release(); }
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }
        QueryPerformanceCounter(&timingQueryEnd);
        timingEvaluateStart = timingQueryEnd;
        timingEvaluateEnd = timingQueryEnd;

        const std::wstring runtimePathValue = runtimePath != nullptr ? runtimePath : L"";
        const std::wstring applicationDataPathValue = applicationDataPath != nullptr ? applicationDataPath : L".";
        NVSDK_NGX_Result evaluateResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        int appliedReset = 0;
        bool recreated = false;
        bool createFailed = false;

        {
            std::lock_guard<std::mutex> lock(g_dlssFrameSequenceMutex);
            if (DlssFrameSequenceNeedsRecreate(
                color,
                output,
                runtimePathValue,
                applicationDataPathValue,
                applicationId,
                perfQualityValue,
                featureFlags))
            {
                ShutdownDlssFrameSequenceLocked();
                recreated = true;

                ID3D11DeviceContext* context = nullptr;
                color.device->GetImmediateContext(&context);
                if (context == nullptr)
                {
                    SetDlssFrameSequenceStatus("DLSS frame-sequence evaluate probe failed: D3D11 device did not return an immediate context");
                    createFailed = true;
                }
                else
                {
                    NVSDK_NGX_FeatureCommonInfo featureInfo{};
                    std::wstring runtimeDirectory;
                    const char* initRoute = "";
                    NVSDK_NGX_Result initResult = InitializeNgxD3D11WithSdkWrapper(
                        color.device,
                        runtimePath,
                        applicationDataPathValue.c_str(),
                        applicationId,
                        &featureInfo,
                        &runtimeDirectory,
                        &initRoute);

                    NVSDK_NGX_Parameter* parameters = nullptr;
                    NVSDK_NGX_Result capabilityResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
                    NVSDK_NGX_Result createResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
                    int available = -1;
                    NgxResult availableResult = 0;

                    if (initResult == NVSDK_NGX_Result_Success)
                    {
                        capabilityResult = NVSDK_NGX_D3D11_GetCapabilityParameters(&parameters);
                        if (capabilityResult == NVSDK_NGX_Result_Success && parameters != nullptr)
                        {
                            TryGetNgxIntParameterFromSdkWrapper(
                                parameters,
                                NVSDK_NGX_Parameter_SuperSampling_Available,
                                &available,
                                &availableResult);

                            if (available == 1)
                            {
                                NVSDK_NGX_DLSS_Create_Params createParams{};
                                createParams.Feature.InWidth = color.width;
                                createParams.Feature.InHeight = color.height;
                                createParams.Feature.InTargetWidth = output.width;
                                createParams.Feature.InTargetHeight = output.height;
                                createParams.Feature.InPerfQualityValue = static_cast<NVSDK_NGX_PerfQuality_Value>(perfQualityValue);
                                createParams.InFeatureCreateFlags = featureFlags;
                                createParams.InEnableOutputSubrects = false;
                                createResult = NGX_D3D11_CREATE_DLSS_EXT(context, &g_dlssFrameSequence.feature, parameters, &createParams);
                            }
                        }
                    }

                    if (initResult == NVSDK_NGX_Result_Success
                        && capabilityResult == NVSDK_NGX_Result_Success
                        && available == 1
                        && createResult == NVSDK_NGX_Result_Success
                        && g_dlssFrameSequence.feature != nullptr)
                    {
                        g_dlssFrameSequence.active = true;
                        color.device->AddRef();
                        g_dlssFrameSequence.device = color.device;
                        g_dlssFrameSequence.context = context;
                        context = nullptr;
                        g_dlssFrameSequence.parameters = parameters;
                        parameters = nullptr;
                        g_dlssFrameSequence.renderWidth = color.width;
                        g_dlssFrameSequence.renderHeight = color.height;
                        g_dlssFrameSequence.targetWidth = output.width;
                        g_dlssFrameSequence.targetHeight = output.height;
                        g_dlssFrameSequence.perfQualityValue = perfQualityValue;
                        g_dlssFrameSequence.featureFlags = featureFlags;
                        g_dlssFrameSequence.applicationId = applicationId;
                        g_dlssFrameSequence.runtimePath = runtimePathValue;
                        g_dlssFrameSequence.applicationDataPath = applicationDataPathValue;
                        g_dlssFrameSequence.initRoute = initRoute;
                        g_dlssFrameSequence.initResult = initResult;
                        g_dlssFrameSequence.capabilityResult = capabilityResult;
                        g_dlssFrameSequence.createResult = createResult;
                        g_dlssFrameSequence.available = available;
                        g_dlssFrameSequence.availableResult = availableResult;
                        g_dlssFrameSequence.createCount = 1;
                    }
                    else
                    {
                        char message[1200];
                        std::snprintf(
                            message,
                            sizeof(message),
                            "DLSS frame-sequence evaluate probe failed to create session via %s; appId=%llu; init=0x%08X; capability=0x%08X; available=%d(result=0x%08X); render=%ux%u; target=%ux%u; perfQuality=%d; flags=0x%08X; create=0x%08X; feature=%s",
                            initRoute,
                            applicationId,
                            static_cast<NgxResult>(initResult),
                            static_cast<NgxResult>(capabilityResult),
                            available,
                            availableResult,
                            color.width,
                            color.height,
                            output.width,
                            output.height,
                            perfQualityValue,
                            static_cast<unsigned int>(featureFlags),
                            static_cast<NgxResult>(createResult),
                            g_dlssFrameSequence.feature != nullptr ? "yes" : "no");
                        SetDlssFrameSequenceStatus(message);
                        createFailed = true;
                    }

                    if (createFailed)
                    {
                        if (g_dlssFrameSequence.feature != nullptr)
                        {
                            NVSDK_NGX_D3D11_ReleaseFeature(g_dlssFrameSequence.feature);
                            g_dlssFrameSequence.feature = nullptr;
                        }

                        if (parameters != nullptr)
                        {
                            NVSDK_NGX_D3D11_DestroyParameters(parameters);
                        }

                        if (initResult == NVSDK_NGX_Result_Success)
                        {
                            NVSDK_NGX_D3D11_Shutdown1(color.device);
                        }
                    }

                    if (context != nullptr)
                    {
                        context->Release();
                    }
                }
            }

            if (!createFailed && g_dlssFrameSequence.active && g_dlssFrameSequence.feature != nullptr && g_dlssFrameSequence.parameters != nullptr)
            {
                appliedReset = g_dlssFrameSequence.evaluateCount == 0 ? reset : 0;
                NVSDK_NGX_D3D11_DLSS_Eval_Params evalParams{};
                evalParams.Feature.pInColor = colorResource;
                evalParams.Feature.pInOutput = outputResource;
                evalParams.Feature.InSharpness = sharpness;
                evalParams.pInDepth = depthResource;
                evalParams.pInMotionVectors = motionResource;
                evalParams.InJitterOffsetX = jitterOffsetX;
                evalParams.InJitterOffsetY = jitterOffsetY;
                evalParams.InRenderSubrectDimensions.Width = color.width;
                evalParams.InRenderSubrectDimensions.Height = color.height;
                evalParams.InReset = appliedReset;
                evalParams.InMVScaleX = motionVectorScaleX == 0.0f ? 1.0f : motionVectorScaleX;
                evalParams.InMVScaleY = motionVectorScaleY == 0.0f ? 1.0f : motionVectorScaleY;
                evalParams.InPreExposure = 1.0f;
                evalParams.InExposureScale = 1.0f;
                QueryPerformanceCounter(&timingEvaluateStart);
                evaluateResult = NGX_D3D11_EVALUATE_DLSS_EXT(
                    g_dlssFrameSequence.context,
                    g_dlssFrameSequence.feature,
                    g_dlssFrameSequence.parameters,
                    &evalParams);
                QueryPerformanceCounter(&timingEvaluateEnd);
                g_dlssFrameSequence.evaluateCount++;
                g_dlssFrameSequence.lastEvaluateResult = evaluateResult;
                if (evaluateResult == NVSDK_NGX_Result_Success)
                {
                    g_dlssFrameSequence.evaluateSuccesses++;
                }

                char message[1800];
                std::snprintf(
                    message,
                    sizeof(message),
                    "DLSS frame-sequence evaluate probe completed via %s; appId=%llu; recreated=%s; init=0x%08X; capability=0x%08X; available=%d(result=0x%08X); render=%ux%u; target=%ux%u; perfQuality=%d; flags=0x%08X; jitter=(%.4f,%.4f); mvScale=(%.4f,%.4f); sharpness=%.4f; requestedReset=%d; appliedReset=%d; sequenceCreates=%d; sequenceEvaluates=%d; evaluateSuccesses=%d; create=0x%08X; feature=%s; evaluateLast=0x%08X; nativeTimingMs=(describe=%.3f,query=%.3f,prepare=%.3f,evaluate=%.3f,total=%.3f)",
                    g_dlssFrameSequence.initRoute,
                    g_dlssFrameSequence.applicationId,
                    recreated ? "yes" : "no",
                    static_cast<NgxResult>(g_dlssFrameSequence.initResult),
                    static_cast<NgxResult>(g_dlssFrameSequence.capabilityResult),
                    g_dlssFrameSequence.available,
                    g_dlssFrameSequence.availableResult,
                    g_dlssFrameSequence.renderWidth,
                    g_dlssFrameSequence.renderHeight,
                    g_dlssFrameSequence.targetWidth,
                    g_dlssFrameSequence.targetHeight,
                    g_dlssFrameSequence.perfQualityValue,
                    static_cast<unsigned int>(g_dlssFrameSequence.featureFlags),
                    jitterOffsetX,
                    jitterOffsetY,
                    motionVectorScaleX == 0.0f ? 1.0f : motionVectorScaleX,
                    motionVectorScaleY == 0.0f ? 1.0f : motionVectorScaleY,
                    sharpness,
                    reset,
                    appliedReset,
                    g_dlssFrameSequence.createCount,
                    g_dlssFrameSequence.evaluateCount,
                    g_dlssFrameSequence.evaluateSuccesses,
                    static_cast<NgxResult>(g_dlssFrameSequence.createResult),
                    g_dlssFrameSequence.feature != nullptr ? "yes" : "no",
                    static_cast<NgxResult>(g_dlssFrameSequence.lastEvaluateResult),
                    ElapsedMilliseconds(timingStart, timingDescribeEnd, timingFrequency),
                    ElapsedMilliseconds(timingDescribeEnd, timingQueryEnd, timingFrequency),
                    ElapsedMilliseconds(timingQueryEnd, timingEvaluateStart, timingFrequency),
                    ElapsedMilliseconds(timingEvaluateStart, timingEvaluateEnd, timingFrequency),
                    ElapsedMilliseconds(timingStart, timingEvaluateEnd, timingFrequency));
                SetDlssFrameSequenceStatus(message);
            }
        }

        colorResource->Release();
        outputResource->Release();
        depthResource->Release();
        motionResource->Release();
        ReleaseEvaluateTextureInfo(&color);
        ReleaseEvaluateTextureInfo(&output);
        ReleaseEvaluateTextureInfo(&depth);
        ReleaseEvaluateTextureInfo(&motion);

        return !createFailed && evaluateResult == NVSDK_NGX_Result_Success ? 1 : 0;
    }

    int ShutdownDlssFrameSequenceWithSdkWrapper()
    {
        std::lock_guard<std::mutex> lock(g_dlssFrameSequenceMutex);
        DlssFrameSequenceShutdownResult result = ShutdownDlssFrameSequenceLocked();
        char message[640];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS frame-sequence shutdown completed; hadSession=%s; sequenceCreates=%d; sequenceEvaluates=%d; evaluateSuccesses=%d; release=0x%08X; destroy=0x%08X; shutdown=0x%08X",
            result.hadSession ? "yes" : "no",
            result.createCount,
            result.evaluateCount,
            result.evaluateSuccesses,
            static_cast<NgxResult>(result.releaseResult),
            static_cast<NgxResult>(result.destroyResult),
            static_cast<NgxResult>(result.shutdownResult));
        SetDlssFrameSequenceStatus(message);

        return result.releaseResult == NVSDK_NGX_Result_Success
            && result.destroyResult == NVSDK_NGX_Result_Success
            && result.shutdownResult == NVSDK_NGX_Result_Success
            ? 1
            : 0;
    }

    int ProbeDlssInitQueryWithSdkWrapper(
        ID3D11Device* device,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId)
    {
        NVSDK_NGX_FeatureCommonInfo featureInfo{};
        std::wstring runtimeDirectory;
        const char* initRoute = "";
        NVSDK_NGX_Result initResult = InitializeNgxD3D11WithSdkWrapper(
            device,
            runtimePath,
            applicationDataPath,
            applicationId,
            &featureInfo,
            &runtimeDirectory,
            &initRoute);

        if (initResult != NVSDK_NGX_Result_Success)
        {
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS init/query probe failed: %s init returned 0x%08X; applicationId=%llu; runtimeDir=%ls",
                initRoute,
                static_cast<NgxResult>(initResult),
                applicationId,
                runtimeDirectory.c_str());
            SetDlssInitQueryStatus(message);
            return 0;
        }

        NVSDK_NGX_Parameter* parameters = nullptr;
        NVSDK_NGX_Result capabilityResult = NVSDK_NGX_D3D11_GetCapabilityParameters(&parameters);
        if (capabilityResult != NVSDK_NGX_Result_Success || parameters == nullptr)
        {
            NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS init/query probe failed: SDK-wrapper GetCapabilityParameters returned 0x%08X; shutdown=0x%08X",
                static_cast<NgxResult>(capabilityResult),
                static_cast<NgxResult>(shutdownResult));
            SetDlssInitQueryStatus(message);
            return 0;
        }

        int available = -1;
        int needsUpdatedDriver = -1;
        int minDriverMajor = -1;
        int minDriverMinor = -1;
        int featureInitResult = -1;
        NgxResult availableResult = 0;
        NgxResult needsDriverResult = 0;
        NgxResult minMajorResult = 0;
        NgxResult minMinorResult = 0;
        NgxResult featureInitResultStatus = 0;

        TryGetNgxIntParameterFromSdkWrapper(parameters, NVSDK_NGX_Parameter_SuperSampling_Available, &available, &availableResult);
        TryGetNgxIntParameterFromSdkWrapper(parameters, NVSDK_NGX_Parameter_SuperSampling_NeedsUpdatedDriver, &needsUpdatedDriver, &needsDriverResult);
        TryGetNgxIntParameterFromSdkWrapper(parameters, NVSDK_NGX_Parameter_SuperSampling_MinDriverVersionMajor, &minDriverMajor, &minMajorResult);
        TryGetNgxIntParameterFromSdkWrapper(parameters, NVSDK_NGX_Parameter_SuperSampling_MinDriverVersionMinor, &minDriverMinor, &minMinorResult);
        TryGetNgxIntParameterFromSdkWrapper(parameters, NVSDK_NGX_Parameter_SuperSampling_FeatureInitResult, &featureInitResult, &featureInitResultStatus);

        NVSDK_NGX_Result destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
        NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);

        SetDlssInitQueryCompletedStatus(
            initRoute,
            applicationId,
            static_cast<NgxResult>(initResult),
            static_cast<NgxResult>(capabilityResult),
            available,
            availableResult,
            needsUpdatedDriver,
            needsDriverResult,
            minDriverMajor,
            minDriverMinor,
            minMajorResult,
            minMinorResult,
            featureInitResult,
            featureInitResultStatus,
            static_cast<NgxResult>(destroyResult),
            static_cast<NgxResult>(shutdownResult));

        return destroyResult == NVSDK_NGX_Result_Success && shutdownResult == NVSDK_NGX_Result_Success ? 1 : 0;
    }

    int ProbeDlssOptimalSettingsWithSdkWrapper(
        ID3D11Device* device,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        unsigned int outputWidth,
        unsigned int outputHeight,
        int perfQualityValue)
    {
        NVSDK_NGX_FeatureCommonInfo featureInfo{};
        std::wstring runtimeDirectory;
        const char* initRoute = "";
        NVSDK_NGX_Result initResult = InitializeNgxD3D11WithSdkWrapper(
            device,
            runtimePath,
            applicationDataPath,
            applicationId,
            &featureInfo,
            &runtimeDirectory,
            &initRoute);

        if (initResult != NVSDK_NGX_Result_Success)
        {
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS optimal-settings probe failed: %s init returned 0x%08X; applicationId=%llu; runtimeDir=%ls",
                initRoute,
                static_cast<NgxResult>(initResult),
                applicationId,
                runtimeDirectory.c_str());
            SetDlssOptimalSettingsStatus(message);
            return 0;
        }

        NVSDK_NGX_Parameter* parameters = nullptr;
        NVSDK_NGX_Result capabilityResult = NVSDK_NGX_D3D11_GetCapabilityParameters(&parameters);
        if (capabilityResult != NVSDK_NGX_Result_Success || parameters == nullptr)
        {
            NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS optimal-settings probe failed: GetCapabilityParameters returned 0x%08X; shutdown=0x%08X",
                static_cast<NgxResult>(capabilityResult),
                static_cast<NgxResult>(shutdownResult));
            SetDlssOptimalSettingsStatus(message);
            return 0;
        }

        int available = -1;
        NgxResult availableResult = 0;
        bool hasAvailable = TryGetNgxIntParameterFromSdkWrapper(parameters, NVSDK_NGX_Parameter_SuperSampling_Available, &available, &availableResult);
        if (!hasAvailable || available != 1)
        {
            NVSDK_NGX_Result destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
            NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);
            char message[512];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS optimal-settings probe failed: SuperSampling.Available=%d(result=0x%08X); destroy=0x%08X; shutdown=0x%08X",
                available,
                availableResult,
                static_cast<NgxResult>(destroyResult),
                static_cast<NgxResult>(shutdownResult));
            SetDlssOptimalSettingsStatus(message);
            return 0;
        }

        unsigned int optimalWidth = 0;
        unsigned int optimalHeight = 0;
        unsigned int maxWidth = 0;
        unsigned int maxHeight = 0;
        unsigned int minWidth = 0;
        unsigned int minHeight = 0;
        float sharpness = 0.0f;
        NVSDK_NGX_Result optimalResult = NGX_DLSS_GET_OPTIMAL_SETTINGS(
            parameters,
            outputWidth,
            outputHeight,
            static_cast<NVSDK_NGX_PerfQuality_Value>(perfQualityValue),
            &optimalWidth,
            &optimalHeight,
            &maxWidth,
            &maxHeight,
            &minWidth,
            &minHeight,
            &sharpness);

        NVSDK_NGX_Result destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
        NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);

        char message[1024];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS optimal-settings probe completed via %s; appId=%llu; init=0x%08X; capability=0x%08X; available=%d(result=0x%08X); output=%ux%u; perfQuality=%d; optimal=0x%08X; render=%ux%u; dynamicMax=%ux%u; dynamicMin=%ux%u; sharpness=%.3f; destroy=0x%08X; shutdown=0x%08X",
            initRoute,
            applicationId,
            static_cast<NgxResult>(initResult),
            static_cast<NgxResult>(capabilityResult),
            available,
            availableResult,
            outputWidth,
            outputHeight,
            perfQualityValue,
            static_cast<NgxResult>(optimalResult),
            optimalWidth,
            optimalHeight,
            maxWidth,
            maxHeight,
            minWidth,
            minHeight,
            static_cast<double>(sharpness),
            static_cast<NgxResult>(destroyResult),
            static_cast<NgxResult>(shutdownResult));
        SetDlssOptimalSettingsStatus(message);

        return optimalResult == NVSDK_NGX_Result_Success
            && optimalWidth > 0
            && optimalHeight > 0
            && destroyResult == NVSDK_NGX_Result_Success
            && shutdownResult == NVSDK_NGX_Result_Success
            ? 1
            : 0;
    }

    int ProbeDlssFeatureCreateWithSdkWrapper(
        ID3D11Device* device,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        unsigned int renderWidth,
        unsigned int renderHeight,
        unsigned int targetWidth,
        unsigned int targetHeight,
        int perfQualityValue,
        int featureFlags)
    {
        NVSDK_NGX_FeatureCommonInfo featureInfo{};
        std::wstring runtimeDirectory;
        const char* initRoute = "";
        NVSDK_NGX_Result initResult = InitializeNgxD3D11WithSdkWrapper(
            device,
            runtimePath,
            applicationDataPath,
            applicationId,
            &featureInfo,
            &runtimeDirectory,
            &initRoute);

        if (initResult != NVSDK_NGX_Result_Success)
        {
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS feature create probe failed: %s init returned 0x%08X; applicationId=%llu; runtimeDir=%ls",
                initRoute,
                static_cast<NgxResult>(initResult),
                applicationId,
                runtimeDirectory.c_str());
            SetDlssFeatureCreateStatus(message);
            return 0;
        }

        NVSDK_NGX_Parameter* parameters = nullptr;
        NVSDK_NGX_Result capabilityResult = NVSDK_NGX_D3D11_GetCapabilityParameters(&parameters);
        if (capabilityResult != NVSDK_NGX_Result_Success || parameters == nullptr)
        {
            NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS feature create probe failed: GetCapabilityParameters returned 0x%08X; shutdown=0x%08X",
                static_cast<NgxResult>(capabilityResult),
                static_cast<NgxResult>(shutdownResult));
            SetDlssFeatureCreateStatus(message);
            return 0;
        }

        int available = -1;
        NgxResult availableResult = 0;
        bool hasAvailable = TryGetNgxIntParameterFromSdkWrapper(parameters, NVSDK_NGX_Parameter_SuperSampling_Available, &available, &availableResult);
        if (!hasAvailable || available != 1)
        {
            NVSDK_NGX_Result destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
            NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);
            char message[512];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS feature create probe failed: SuperSampling.Available=%d(result=0x%08X); destroy=0x%08X; shutdown=0x%08X",
                available,
                availableResult,
                static_cast<NgxResult>(destroyResult),
                static_cast<NgxResult>(shutdownResult));
            SetDlssFeatureCreateStatus(message);
            return 0;
        }

        ID3D11DeviceContext* context = nullptr;
        device->GetImmediateContext(&context);
        if (context == nullptr)
        {
            NVSDK_NGX_Result destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
            NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS feature create probe failed: D3D11 device did not return an immediate context; destroy=0x%08X; shutdown=0x%08X",
                static_cast<NgxResult>(destroyResult),
                static_cast<NgxResult>(shutdownResult));
            SetDlssFeatureCreateStatus(message);
            return 0;
        }

        NVSDK_NGX_DLSS_Create_Params createParams{};
        createParams.Feature.InWidth = renderWidth;
        createParams.Feature.InHeight = renderHeight;
        createParams.Feature.InTargetWidth = targetWidth;
        createParams.Feature.InTargetHeight = targetHeight;
        createParams.Feature.InPerfQualityValue = static_cast<NVSDK_NGX_PerfQuality_Value>(perfQualityValue);
        createParams.InFeatureCreateFlags = featureFlags;
        createParams.InEnableOutputSubrects = false;

        NVSDK_NGX_Handle* feature = nullptr;
        NVSDK_NGX_Result createResult = NGX_D3D11_CREATE_DLSS_EXT(context, &feature, parameters, &createParams);
        NVSDK_NGX_Result releaseResult = NVSDK_NGX_Result_Success;
        if (feature != nullptr)
        {
            releaseResult = NVSDK_NGX_D3D11_ReleaseFeature(feature);
        }

        context->Release();

        NVSDK_NGX_Result destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
        NVSDK_NGX_Result shutdownResult = NVSDK_NGX_D3D11_Shutdown1(device);

        char message[896];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS feature create probe completed via %s; appId=%llu; init=0x%08X; capability=0x%08X; available=%d(result=0x%08X); render=%ux%u; target=%ux%u; perfQuality=%d; flags=0x%08X; create=0x%08X; feature=%s; release=0x%08X; destroy=0x%08X; shutdown=0x%08X",
            initRoute,
            applicationId,
            static_cast<NgxResult>(initResult),
            static_cast<NgxResult>(capabilityResult),
            available,
            availableResult,
            renderWidth,
            renderHeight,
            targetWidth,
            targetHeight,
            perfQualityValue,
            static_cast<unsigned int>(featureFlags),
            static_cast<NgxResult>(createResult),
            feature != nullptr ? "yes" : "no",
            static_cast<NgxResult>(releaseResult),
            static_cast<NgxResult>(destroyResult),
            static_cast<NgxResult>(shutdownResult));
        SetDlssFeatureCreateStatus(message);

        return createResult == NVSDK_NGX_Result_Success
            && feature != nullptr
            && releaseResult == NVSDK_NGX_Result_Success
            && destroyResult == NVSDK_NGX_Result_Success
            && shutdownResult == NVSDK_NGX_Result_Success
            ? 1
            : 0;
    }

    int ProbeDlssEvaluateWithSdkWrapper(
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
        int reset)
    {
        EvaluateTextureInfo color{};
        EvaluateTextureInfo output{};
        EvaluateTextureInfo depth{};
        EvaluateTextureInfo motion{};
        char error[384] = {};

        if (!TryDescribeEvaluateTexture("color", colorTexturePtr, &color, error, sizeof(error))
            || !TryDescribeEvaluateTexture("output", outputTexturePtr, &output, error, sizeof(error))
            || !TryDescribeEvaluateTexture("depth", depthTexturePtr, &depth, error, sizeof(error))
            || !TryDescribeEvaluateTexture("motion", motionTexturePtr, &motion, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS evaluate probe failed: %s", error);
            SetDlssEvaluateStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const bool sameDevice = color.device == output.device
            && color.device == depth.device
            && color.device == motion.device;
        const bool depthMatchesColor = EvaluateInputDimensionsMatch(color, depth);
        const bool motionMatchesColor = EvaluateInputDimensionsMatch(color, motion);
        if (!sameDevice || !depthMatchesColor || !motionMatchesColor)
        {
            char message[640];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS evaluate probe failed: invalid input tuple; sameDevice=%s; color=%ux%u output=%ux%u depth=%ux%u motion=%ux%u",
                sameDevice ? "yes" : "no",
                color.width,
                color.height,
                output.width,
                output.height,
                depth.width,
                depth.height,
                motion.width,
                motion.height);
            SetDlssEvaluateStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        ID3D11Resource* colorResource = nullptr;
        ID3D11Resource* outputResource = nullptr;
        ID3D11Resource* depthResource = nullptr;
        ID3D11Resource* motionResource = nullptr;
        ID3D11DeviceContext* context = nullptr;
        NVSDK_NGX_Parameter* parameters = nullptr;
        NVSDK_NGX_Handle* feature = nullptr;
        NVSDK_NGX_Result initResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result capabilityResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result createResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result evaluateResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result releaseResult = NVSDK_NGX_Result_Success;
        NVSDK_NGX_Result destroyResult = NVSDK_NGX_Result_Success;
        NVSDK_NGX_Result shutdownResult = NVSDK_NGX_Result_Success;
        int available = -1;
        NgxResult availableResult = 0;

        if (!TryQueryD3D11Resource("color", colorTexturePtr, &colorResource, error, sizeof(error))
            || !TryQueryD3D11Resource("output", outputTexturePtr, &outputResource, error, sizeof(error))
            || !TryQueryD3D11Resource("depth", depthTexturePtr, &depthResource, error, sizeof(error))
            || !TryQueryD3D11Resource("motion", motionTexturePtr, &motionResource, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS evaluate probe failed: %s", error);
            SetDlssEvaluateStatus(message);
            if (colorResource != nullptr) { colorResource->Release(); }
            if (outputResource != nullptr) { outputResource->Release(); }
            if (depthResource != nullptr) { depthResource->Release(); }
            if (motionResource != nullptr) { motionResource->Release(); }
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        color.device->GetImmediateContext(&context);
        if (context == nullptr)
        {
            SetDlssEvaluateStatus("DLSS evaluate probe failed: D3D11 device did not return an immediate context");
            colorResource->Release();
            outputResource->Release();
            depthResource->Release();
            motionResource->Release();
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        NVSDK_NGX_FeatureCommonInfo featureInfo{};
        std::wstring runtimeDirectory;
        const char* initRoute = "";
        initResult = InitializeNgxD3D11WithSdkWrapper(
            color.device,
            runtimePath,
            applicationDataPath,
            applicationId,
            &featureInfo,
            &runtimeDirectory,
            &initRoute);

        if (initResult == NVSDK_NGX_Result_Success)
        {
            capabilityResult = NVSDK_NGX_D3D11_GetCapabilityParameters(&parameters);
            if (capabilityResult == NVSDK_NGX_Result_Success && parameters != nullptr)
            {
                TryGetNgxIntParameterFromSdkWrapper(
                    parameters,
                    NVSDK_NGX_Parameter_SuperSampling_Available,
                    &available,
                    &availableResult);

                if (available == 1)
                {
                    NVSDK_NGX_DLSS_Create_Params createParams{};
                    createParams.Feature.InWidth = color.width;
                    createParams.Feature.InHeight = color.height;
                    createParams.Feature.InTargetWidth = output.width;
                    createParams.Feature.InTargetHeight = output.height;
                    createParams.Feature.InPerfQualityValue = static_cast<NVSDK_NGX_PerfQuality_Value>(perfQualityValue);
                    createParams.InFeatureCreateFlags = featureFlags;
                    createParams.InEnableOutputSubrects = false;
                    createResult = NGX_D3D11_CREATE_DLSS_EXT(context, &feature, parameters, &createParams);

                    if (createResult == NVSDK_NGX_Result_Success && feature != nullptr)
                    {
                        NVSDK_NGX_D3D11_DLSS_Eval_Params evalParams{};
                        evalParams.Feature.pInColor = colorResource;
                        evalParams.Feature.pInOutput = outputResource;
                        evalParams.Feature.InSharpness = sharpness;
                        evalParams.pInDepth = depthResource;
                        evalParams.pInMotionVectors = motionResource;
                        evalParams.InJitterOffsetX = jitterOffsetX;
                        evalParams.InJitterOffsetY = jitterOffsetY;
                        evalParams.InRenderSubrectDimensions.Width = color.width;
                        evalParams.InRenderSubrectDimensions.Height = color.height;
                        evalParams.InReset = reset;
                        evalParams.InMVScaleX = motionVectorScaleX == 0.0f ? 1.0f : motionVectorScaleX;
                        evalParams.InMVScaleY = motionVectorScaleY == 0.0f ? 1.0f : motionVectorScaleY;
                        evalParams.InPreExposure = 1.0f;
                        evalParams.InExposureScale = 1.0f;
                        evaluateResult = NGX_D3D11_EVALUATE_DLSS_EXT(context, feature, parameters, &evalParams);
                    }
                }
            }
        }

        if (feature != nullptr)
        {
            releaseResult = NVSDK_NGX_D3D11_ReleaseFeature(feature);
        }

        if (parameters != nullptr)
        {
            destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
        }

        if (initResult == NVSDK_NGX_Result_Success)
        {
            shutdownResult = NVSDK_NGX_D3D11_Shutdown1(color.device);
        }

        char message[1600];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS evaluate probe completed via %s; appId=%llu; init=0x%08X; capability=0x%08X; available=%d(result=0x%08X); render=%ux%u; target=%ux%u; perfQuality=%d; flags=0x%08X; jitter=(%.4f,%.4f); mvScale=(%.4f,%.4f); sharpness=%.4f; reset=%d; create=0x%08X; feature=%s; evaluate=0x%08X; release=0x%08X; destroy=0x%08X; shutdown=0x%08X",
            initRoute,
            applicationId,
            static_cast<NgxResult>(initResult),
            static_cast<NgxResult>(capabilityResult),
            available,
            availableResult,
            color.width,
            color.height,
            output.width,
            output.height,
            perfQualityValue,
            static_cast<unsigned int>(featureFlags),
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX == 0.0f ? 1.0f : motionVectorScaleX,
            motionVectorScaleY == 0.0f ? 1.0f : motionVectorScaleY,
            sharpness,
            reset,
            static_cast<NgxResult>(createResult),
            feature != nullptr ? "yes" : "no",
            static_cast<NgxResult>(evaluateResult),
            static_cast<NgxResult>(releaseResult),
            static_cast<NgxResult>(destroyResult),
            static_cast<NgxResult>(shutdownResult));
        SetDlssEvaluateStatus(message);

        context->Release();
        colorResource->Release();
        outputResource->Release();
        depthResource->Release();
        motionResource->Release();
        ReleaseEvaluateTextureInfo(&color);
        ReleaseEvaluateTextureInfo(&output);
        ReleaseEvaluateTextureInfo(&depth);
        ReleaseEvaluateTextureInfo(&motion);

        return initResult == NVSDK_NGX_Result_Success
            && capabilityResult == NVSDK_NGX_Result_Success
            && available == 1
            && createResult == NVSDK_NGX_Result_Success
            && feature != nullptr
            && evaluateResult == NVSDK_NGX_Result_Success
            && releaseResult == NVSDK_NGX_Result_Success
            && destroyResult == NVSDK_NGX_Result_Success
            && shutdownResult == NVSDK_NGX_Result_Success
            ? 1
            : 0;
    }

    int ProbeDlssPersistentEvaluateWithSdkWrapper(
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
        int evaluateCount)
    {
        EvaluateTextureInfo color{};
        EvaluateTextureInfo output{};
        EvaluateTextureInfo depth{};
        EvaluateTextureInfo motion{};
        char error[384] = {};

        if (!TryDescribeEvaluateTexture("color", colorTexturePtr, &color, error, sizeof(error))
            || !TryDescribeEvaluateTexture("output", outputTexturePtr, &output, error, sizeof(error))
            || !TryDescribeEvaluateTexture("depth", depthTexturePtr, &depth, error, sizeof(error))
            || !TryDescribeEvaluateTexture("motion", motionTexturePtr, &motion, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS persistent evaluate probe failed: %s", error);
            SetDlssPersistentEvaluateStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const bool sameDevice = color.device == output.device
            && color.device == depth.device
            && color.device == motion.device;
        const bool depthMatchesColor = EvaluateInputDimensionsMatch(color, depth);
        const bool motionMatchesColor = EvaluateInputDimensionsMatch(color, motion);
        if (!sameDevice || !depthMatchesColor || !motionMatchesColor)
        {
            char message[640];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS persistent evaluate probe failed: invalid input tuple; sameDevice=%s; color=%ux%u output=%ux%u depth=%ux%u motion=%ux%u",
                sameDevice ? "yes" : "no",
                color.width,
                color.height,
                output.width,
                output.height,
                depth.width,
                depth.height,
                motion.width,
                motion.height);
            SetDlssPersistentEvaluateStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        ID3D11Resource* colorResource = nullptr;
        ID3D11Resource* outputResource = nullptr;
        ID3D11Resource* depthResource = nullptr;
        ID3D11Resource* motionResource = nullptr;
        ID3D11DeviceContext* context = nullptr;
        NVSDK_NGX_Parameter* parameters = nullptr;
        NVSDK_NGX_Handle* feature = nullptr;
        NVSDK_NGX_Result initResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result capabilityResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result createResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result evaluateResult = NVSDK_NGX_Result_FAIL_FeatureNotSupported;
        NVSDK_NGX_Result releaseResult = NVSDK_NGX_Result_Success;
        NVSDK_NGX_Result destroyResult = NVSDK_NGX_Result_Success;
        NVSDK_NGX_Result shutdownResult = NVSDK_NGX_Result_Success;
        int available = -1;
        NgxResult availableResult = 0;
        int evaluateSuccesses = 0;
        const int safeEvaluateCount = evaluateCount <= 0 ? 2 : evaluateCount > 8 ? 8 : evaluateCount;

        if (!TryQueryD3D11Resource("color", colorTexturePtr, &colorResource, error, sizeof(error))
            || !TryQueryD3D11Resource("output", outputTexturePtr, &outputResource, error, sizeof(error))
            || !TryQueryD3D11Resource("depth", depthTexturePtr, &depthResource, error, sizeof(error))
            || !TryQueryD3D11Resource("motion", motionTexturePtr, &motionResource, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS persistent evaluate probe failed: %s", error);
            SetDlssPersistentEvaluateStatus(message);
            if (colorResource != nullptr) { colorResource->Release(); }
            if (outputResource != nullptr) { outputResource->Release(); }
            if (depthResource != nullptr) { depthResource->Release(); }
            if (motionResource != nullptr) { motionResource->Release(); }
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        color.device->GetImmediateContext(&context);
        if (context == nullptr)
        {
            SetDlssPersistentEvaluateStatus("DLSS persistent evaluate probe failed: D3D11 device did not return an immediate context");
            colorResource->Release();
            outputResource->Release();
            depthResource->Release();
            motionResource->Release();
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        NVSDK_NGX_FeatureCommonInfo featureInfo{};
        std::wstring runtimeDirectory;
        const char* initRoute = "";
        initResult = InitializeNgxD3D11WithSdkWrapper(
            color.device,
            runtimePath,
            applicationDataPath,
            applicationId,
            &featureInfo,
            &runtimeDirectory,
            &initRoute);

        if (initResult == NVSDK_NGX_Result_Success)
        {
            capabilityResult = NVSDK_NGX_D3D11_GetCapabilityParameters(&parameters);
            if (capabilityResult == NVSDK_NGX_Result_Success && parameters != nullptr)
            {
                TryGetNgxIntParameterFromSdkWrapper(
                    parameters,
                    NVSDK_NGX_Parameter_SuperSampling_Available,
                    &available,
                    &availableResult);

                if (available == 1)
                {
                    NVSDK_NGX_DLSS_Create_Params createParams{};
                    createParams.Feature.InWidth = color.width;
                    createParams.Feature.InHeight = color.height;
                    createParams.Feature.InTargetWidth = output.width;
                    createParams.Feature.InTargetHeight = output.height;
                    createParams.Feature.InPerfQualityValue = static_cast<NVSDK_NGX_PerfQuality_Value>(perfQualityValue);
                    createParams.InFeatureCreateFlags = featureFlags;
                    createParams.InEnableOutputSubrects = false;
                    createResult = NGX_D3D11_CREATE_DLSS_EXT(context, &feature, parameters, &createParams);

                    if (createResult == NVSDK_NGX_Result_Success && feature != nullptr)
                    {
                        for (int index = 0; index < safeEvaluateCount; ++index)
                        {
                            NVSDK_NGX_D3D11_DLSS_Eval_Params evalParams{};
                            evalParams.Feature.pInColor = colorResource;
                            evalParams.Feature.pInOutput = outputResource;
                            evalParams.Feature.InSharpness = sharpness;
                            evalParams.pInDepth = depthResource;
                            evalParams.pInMotionVectors = motionResource;
                            evalParams.InJitterOffsetX = jitterOffsetX;
                            evalParams.InJitterOffsetY = jitterOffsetY;
                            evalParams.InRenderSubrectDimensions.Width = color.width;
                            evalParams.InRenderSubrectDimensions.Height = color.height;
                            evalParams.InReset = index == 0 ? reset : 0;
                            evalParams.InMVScaleX = motionVectorScaleX == 0.0f ? 1.0f : motionVectorScaleX;
                            evalParams.InMVScaleY = motionVectorScaleY == 0.0f ? 1.0f : motionVectorScaleY;
                            evalParams.InPreExposure = 1.0f;
                            evalParams.InExposureScale = 1.0f;
                            evaluateResult = NGX_D3D11_EVALUATE_DLSS_EXT(context, feature, parameters, &evalParams);
                            if (evaluateResult != NVSDK_NGX_Result_Success)
                            {
                                break;
                            }

                            ++evaluateSuccesses;
                        }
                    }
                }
            }
        }

        if (feature != nullptr)
        {
            releaseResult = NVSDK_NGX_D3D11_ReleaseFeature(feature);
        }

        if (parameters != nullptr)
        {
            destroyResult = NVSDK_NGX_D3D11_DestroyParameters(parameters);
        }

        if (initResult == NVSDK_NGX_Result_Success)
        {
            shutdownResult = NVSDK_NGX_D3D11_Shutdown1(color.device);
        }

        char message[1800];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS persistent evaluate probe completed via %s; appId=%llu; init=0x%08X; capability=0x%08X; available=%d(result=0x%08X); render=%ux%u; target=%ux%u; perfQuality=%d; flags=0x%08X; jitter=(%.4f,%.4f); mvScale=(%.4f,%.4f); sharpness=%.4f; reset=%d; evaluateCount=%d; evaluateSuccesses=%d; create=0x%08X; feature=%s; evaluateLast=0x%08X; release=0x%08X; destroy=0x%08X; shutdown=0x%08X",
            initRoute,
            applicationId,
            static_cast<NgxResult>(initResult),
            static_cast<NgxResult>(capabilityResult),
            available,
            availableResult,
            color.width,
            color.height,
            output.width,
            output.height,
            perfQualityValue,
            static_cast<unsigned int>(featureFlags),
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX == 0.0f ? 1.0f : motionVectorScaleX,
            motionVectorScaleY == 0.0f ? 1.0f : motionVectorScaleY,
            sharpness,
            reset,
            safeEvaluateCount,
            evaluateSuccesses,
            static_cast<NgxResult>(createResult),
            feature != nullptr ? "yes" : "no",
            static_cast<NgxResult>(evaluateResult),
            static_cast<NgxResult>(releaseResult),
            static_cast<NgxResult>(destroyResult),
            static_cast<NgxResult>(shutdownResult));
        SetDlssPersistentEvaluateStatus(message);

        context->Release();
        colorResource->Release();
        outputResource->Release();
        depthResource->Release();
        motionResource->Release();
        ReleaseEvaluateTextureInfo(&color);
        ReleaseEvaluateTextureInfo(&output);
        ReleaseEvaluateTextureInfo(&depth);
        ReleaseEvaluateTextureInfo(&motion);

        return initResult == NVSDK_NGX_Result_Success
            && capabilityResult == NVSDK_NGX_Result_Success
            && available == 1
            && createResult == NVSDK_NGX_Result_Success
            && feature != nullptr
            && evaluateSuccesses == safeEvaluateCount
            && releaseResult == NVSDK_NGX_Result_Success
            && destroyResult == NVSDK_NGX_Result_Success
            && shutdownResult == NVSDK_NGX_Result_Success
            ? 1
            : 0;
    }
#endif

    void SetD3D11ProbeStatusFormatted(
        HRESULT hr,
        D3D11_RESOURCE_DIMENSION dimension,
        DXGI_FORMAT format,
        UINT width,
        UINT height,
        UINT mipLevels,
        UINT arraySize)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(
            g_d3d11ProbeStatus,
            sizeof(g_d3d11ProbeStatus),
            "D3D11 texture probe succeeded; hr=0x%08X; dimension=%u; format=%u; width=%u; height=%u; mipLevels=%u; arraySize=%u",
            static_cast<unsigned int>(hr),
            static_cast<unsigned int>(dimension),
            static_cast<unsigned int>(format),
            width,
            height,
            mipLevels,
            arraySize);
    }
}

extern "C"
{
    int __cdecl VrisingDlss_GetBridgeApiVersion()
    {
        return 16;
    }

    const char* __cdecl VrisingDlss_GetBridgeVersion()
    {
        return "0.1.0";
    }

    const char* __cdecl VrisingDlss_GetDiagnosticStatus()
    {
        return "native bridge scaffold loaded; DLSS is not initialized";
    }

    void* __cdecl VrisingDlss_GetRenderEventFunc()
    {
        return reinterpret_cast<void*>(&OnRenderEvent);
    }

    int __cdecl VrisingDlss_GetRenderEventCount()
    {
        return g_renderEventCount.load();
    }

    int __cdecl VrisingDlss_GetLastRenderEventId()
    {
        return g_lastRenderEventId.load();
    }

    const char* __cdecl VrisingDlss_GetRenderEventStatus()
    {
        static char status[128];
        std::snprintf(
            status,
            sizeof(status),
            "render event count=%d; last event id=%d; D3D11 device is not queried yet",
            g_renderEventCount.load(),
            g_lastRenderEventId.load());

        return status;
    }

    int __cdecl VrisingDlss_SetRenderEventTexturePayload(
        void* sourceTexturePtr,
        void* destinationTexturePtr,
        int eventId,
        int sequence)
    {
        g_renderEventTexturePayloadSetAttempts.fetch_add(1);
        if (sourceTexturePtr == nullptr || destinationTexturePtr == nullptr)
        {
            g_renderEventTexturePayloadSetFailures.fetch_add(1);
            SetRenderEventTexturePayloadFailureStatus("set", "source or destination pointer was null", eventId, sequence);
            return 0;
        }

        if (sourceTexturePtr == destinationTexturePtr)
        {
            g_renderEventTexturePayloadSetFailures.fetch_add(1);
            SetRenderEventTexturePayloadFailureStatus("set", "source and destination pointers were identical", eventId, sequence);
            return 0;
        }

        IUnknown* source = static_cast<IUnknown*>(sourceTexturePtr);
        IUnknown* destination = static_cast<IUnknown*>(destinationTexturePtr);
        source->AddRef();
        destination->AddRef();

        {
            std::lock_guard<std::mutex> lock(g_renderEventTexturePayloadMutex);
            ReleaseRenderEventTexturePayload(&g_renderEventTexturePayload);
            g_renderEventTexturePayload.source = source;
            g_renderEventTexturePayload.destination = destination;
            g_renderEventTexturePayload.sourcePointer = sourceTexturePtr;
            g_renderEventTexturePayload.destinationPointer = destinationTexturePtr;
            g_renderEventTexturePayload.eventId = eventId;
            g_renderEventTexturePayload.sequence = sequence;
            std::snprintf(
                g_renderEventTexturePayloadStatus,
                sizeof(g_renderEventTexturePayloadStatus),
                "render event texture payload pending: setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d; sourcePtr=%p; destinationPtr=%p",
                g_renderEventTexturePayloadSetAttempts.load(),
                g_renderEventTexturePayloadSetSuccesses.load() + 1,
                g_renderEventTexturePayloadSetFailures.load(),
                g_renderEventTexturePayloadConsumedCount.load(),
                g_renderEventTexturePayloadConsumedFailures.load(),
                eventId,
                sequence,
                sourceTexturePtr,
                destinationTexturePtr);
        }

        g_renderEventTexturePayloadSetSuccesses.fetch_add(1);
        return 1;
    }

    int __cdecl VrisingDlss_GetRenderEventTexturePayloadConsumedCount()
    {
        return g_renderEventTexturePayloadConsumedCount.load();
    }

    const char* __cdecl VrisingDlss_GetRenderEventTexturePayloadStatus()
    {
        std::lock_guard<std::mutex> lock(g_renderEventTexturePayloadMutex);
        return g_renderEventTexturePayloadStatus;
    }

    int __cdecl VrisingDlss_SetRenderEventFrameDescriptorPayload(
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
        int sequence)
    {
        g_renderEventFrameDescriptorPayloadSetAttempts.fetch_add(1);
        if (sourceTexturePtr == nullptr
            || destinationTexturePtr == nullptr
            || depthTexturePtr == nullptr
            || motionTexturePtr == nullptr)
        {
            g_renderEventFrameDescriptorPayloadSetFailures.fetch_add(1);
            SetRenderEventFrameDescriptorPayloadFailureStatus("set", "one or more frame descriptor pointers were null", eventId, sequence);
            return 0;
        }

        if (sourceTexturePtr == destinationTexturePtr)
        {
            g_renderEventFrameDescriptorPayloadSetFailures.fetch_add(1);
            SetRenderEventFrameDescriptorPayloadFailureStatus("set", "source and destination pointers were identical", eventId, sequence);
            return 0;
        }

        if (inputWidth <= 0
            || inputHeight <= 0
            || outputWidth <= 0
            || outputHeight <= 0
            || !(outputWidth > inputWidth && outputHeight > inputHeight))
        {
            g_renderEventFrameDescriptorPayloadSetFailures.fetch_add(1);
            SetRenderEventFrameDescriptorPayloadFailureStatus("set", "frame descriptor dimensions were invalid", eventId, sequence);
            return 0;
        }

        IUnknown* source = static_cast<IUnknown*>(sourceTexturePtr);
        IUnknown* destination = static_cast<IUnknown*>(destinationTexturePtr);
        IUnknown* depth = static_cast<IUnknown*>(depthTexturePtr);
        IUnknown* motion = static_cast<IUnknown*>(motionTexturePtr);
        source->AddRef();
        destination->AddRef();
        depth->AddRef();
        motion->AddRef();

        {
            std::lock_guard<std::mutex> lock(g_renderEventFrameDescriptorPayloadMutex);
            ReleaseRenderEventFrameDescriptorPayload(&g_renderEventFrameDescriptorPayload);
            g_renderEventFrameDescriptorPayload.source = source;
            g_renderEventFrameDescriptorPayload.destination = destination;
            g_renderEventFrameDescriptorPayload.depth = depth;
            g_renderEventFrameDescriptorPayload.motion = motion;
            g_renderEventFrameDescriptorPayload.sourcePointer = sourceTexturePtr;
            g_renderEventFrameDescriptorPayload.destinationPointer = destinationTexturePtr;
            g_renderEventFrameDescriptorPayload.depthPointer = depthTexturePtr;
            g_renderEventFrameDescriptorPayload.motionPointer = motionTexturePtr;
            g_renderEventFrameDescriptorPayload.inputWidth = inputWidth;
            g_renderEventFrameDescriptorPayload.inputHeight = inputHeight;
            g_renderEventFrameDescriptorPayload.outputWidth = outputWidth;
            g_renderEventFrameDescriptorPayload.outputHeight = outputHeight;
            g_renderEventFrameDescriptorPayload.hdrpFrame = hdrpFrame;
            g_renderEventFrameDescriptorPayload.easuSourceFrame = easuSourceFrame;
            g_renderEventFrameDescriptorPayload.easuDestinationFrame = easuDestinationFrame;
            g_renderEventFrameDescriptorPayload.eventId = eventId;
            g_renderEventFrameDescriptorPayload.sequence = sequence;
            std::snprintf(
                g_renderEventFrameDescriptorPayloadStatus,
                sizeof(g_renderEventFrameDescriptorPayloadStatus),
                "render event frame descriptor payload pending: setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d; sourcePtr=%p; destinationPtr=%p; depthPtr=%p; motionPtr=%p; input=%dx%d; output=%dx%d; hdrpFrame=%d; easuSourceFrame=%d; easuDestinationFrame=%d; validation=D3D11-not-queried; ngx=not-loaded; evaluate=not-run",
                g_renderEventFrameDescriptorPayloadSetAttempts.load(),
                g_renderEventFrameDescriptorPayloadSetSuccesses.load() + 1,
                g_renderEventFrameDescriptorPayloadSetFailures.load(),
                g_renderEventFrameDescriptorPayloadConsumedCount.load(),
                g_renderEventFrameDescriptorPayloadConsumedFailures.load(),
                eventId,
                sequence,
                sourceTexturePtr,
                destinationTexturePtr,
                depthTexturePtr,
                motionTexturePtr,
                inputWidth,
                inputHeight,
                outputWidth,
                outputHeight,
                hdrpFrame,
                easuSourceFrame,
                easuDestinationFrame);
        }

        g_renderEventFrameDescriptorPayloadSetSuccesses.fetch_add(1);
        return 1;
    }

    int __cdecl VrisingDlss_GetRenderEventFrameDescriptorPayloadConsumedCount()
    {
        return g_renderEventFrameDescriptorPayloadConsumedCount.load();
    }

    const char* __cdecl VrisingDlss_GetRenderEventFrameDescriptorPayloadStatus()
    {
        std::lock_guard<std::mutex> lock(g_renderEventFrameDescriptorPayloadMutex);
        return g_renderEventFrameDescriptorPayloadStatus;
    }

    int __cdecl VrisingDlss_SetRenderEventDlssFeatureCreatePayload(
        void* sourceTexturePtr,
        void* destinationTexturePtr,
        int eventId,
        int sequence,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        int perfQualityValue,
        int featureFlags)
    {
        g_renderEventDlssFeatureCreatePayloadSetAttempts.fetch_add(1);
        if (sourceTexturePtr == nullptr || destinationTexturePtr == nullptr)
        {
            g_renderEventDlssFeatureCreatePayloadSetFailures.fetch_add(1);
            SetRenderEventDlssFeatureCreatePayloadFailureStatus("set", "source or destination pointer was null", eventId, sequence);
            return 0;
        }

        if (sourceTexturePtr == destinationTexturePtr)
        {
            g_renderEventDlssFeatureCreatePayloadSetFailures.fetch_add(1);
            SetRenderEventDlssFeatureCreatePayloadFailureStatus("set", "source and destination pointers were identical", eventId, sequence);
            return 0;
        }

        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            g_renderEventDlssFeatureCreatePayloadSetFailures.fetch_add(1);
            SetRenderEventDlssFeatureCreatePayloadFailureStatus("set", "runtime path was empty", eventId, sequence);
            return 0;
        }

        IUnknown* source = static_cast<IUnknown*>(sourceTexturePtr);
        IUnknown* destination = static_cast<IUnknown*>(destinationTexturePtr);
        source->AddRef();
        destination->AddRef();

        {
            std::lock_guard<std::mutex> lock(g_renderEventDlssFeatureCreatePayloadMutex);
            ReleaseRenderEventDlssFeatureCreatePayload(&g_renderEventDlssFeatureCreatePayload);
            g_renderEventDlssFeatureCreatePayload.textures.source = source;
            g_renderEventDlssFeatureCreatePayload.textures.destination = destination;
            g_renderEventDlssFeatureCreatePayload.textures.sourcePointer = sourceTexturePtr;
            g_renderEventDlssFeatureCreatePayload.textures.destinationPointer = destinationTexturePtr;
            g_renderEventDlssFeatureCreatePayload.textures.eventId = eventId;
            g_renderEventDlssFeatureCreatePayload.textures.sequence = sequence;
            g_renderEventDlssFeatureCreatePayload.runtimePath = runtimePath;
            g_renderEventDlssFeatureCreatePayload.applicationDataPath =
                applicationDataPath != nullptr && applicationDataPath[0] != L'\0'
                    ? applicationDataPath
                    : L".";
            g_renderEventDlssFeatureCreatePayload.applicationId = applicationId;
            g_renderEventDlssFeatureCreatePayload.perfQualityValue = perfQualityValue;
            g_renderEventDlssFeatureCreatePayload.featureFlags = featureFlags;
            std::snprintf(
                g_renderEventDlssFeatureCreatePayloadStatus,
                sizeof(g_renderEventDlssFeatureCreatePayloadStatus),
                "render event DLSS feature-create payload pending: setAttempts=%d; setSuccesses=%d; setFailures=%d; consumed=%d; consumeFailures=%d; eventId=%d; sequence=%d; sourcePtr=%p; destinationPtr=%p; appId=%llu; perfQuality=%d; flags=0x%08X",
                g_renderEventDlssFeatureCreatePayloadSetAttempts.load(),
                g_renderEventDlssFeatureCreatePayloadSetSuccesses.load() + 1,
                g_renderEventDlssFeatureCreatePayloadSetFailures.load(),
                g_renderEventDlssFeatureCreatePayloadConsumedCount.load(),
                g_renderEventDlssFeatureCreatePayloadConsumedFailures.load(),
                eventId,
                sequence,
                sourceTexturePtr,
                destinationTexturePtr,
                applicationId,
                perfQualityValue,
                static_cast<unsigned int>(featureFlags));
        }

        g_renderEventDlssFeatureCreatePayloadSetSuccesses.fetch_add(1);
        return 1;
    }

    int __cdecl VrisingDlss_GetRenderEventDlssFeatureCreateConsumedCount()
    {
        return g_renderEventDlssFeatureCreatePayloadConsumedCount.load();
    }

    const char* __cdecl VrisingDlss_GetRenderEventDlssFeatureCreateStatus()
    {
        std::lock_guard<std::mutex> lock(g_renderEventDlssFeatureCreatePayloadMutex);
        return g_renderEventDlssFeatureCreatePayloadStatus;
    }

    int __cdecl VrisingDlss_ProbeD3D11Texture(void* nativeTexturePtr)
    {
        if (nativeTexturePtr == nullptr)
        {
            SetD3D11ProbeStatus("D3D11 texture probe failed: native texture pointer was null");
            return 0;
        }

        IUnknown* unknown = static_cast<IUnknown*>(nativeTexturePtr);
        ID3D11Resource* resource = nullptr;
        HRESULT hr = unknown->QueryInterface(__uuidof(ID3D11Resource), reinterpret_cast<void**>(&resource));
        if (FAILED(hr) || resource == nullptr)
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "D3D11 texture probe failed: QueryInterface(ID3D11Resource) returned hr=0x%08X",
                static_cast<unsigned int>(hr));
            SetD3D11ProbeStatus(message);
            return 0;
        }

        D3D11_RESOURCE_DIMENSION dimension = D3D11_RESOURCE_DIMENSION_UNKNOWN;
        resource->GetType(&dimension);

        ID3D11Device* device = nullptr;
        resource->GetDevice(&device);
        if (device == nullptr)
        {
            resource->Release();
            SetD3D11ProbeStatus("D3D11 texture probe failed: resource did not return a device");
            return 0;
        }

        ID3D11DeviceContext* context = nullptr;
        device->GetImmediateContext(&context);
        if (context == nullptr)
        {
            device->Release();
            resource->Release();
            SetD3D11ProbeStatus("D3D11 texture probe failed: device did not return an immediate context");
            return 0;
        }

        DXGI_FORMAT format = DXGI_FORMAT_UNKNOWN;
        UINT width = 0;
        UINT height = 0;
        UINT mipLevels = 0;
        UINT arraySize = 0;

        if (dimension == D3D11_RESOURCE_DIMENSION_TEXTURE2D)
        {
            ID3D11Texture2D* texture2D = nullptr;
            hr = resource->QueryInterface(__uuidof(ID3D11Texture2D), reinterpret_cast<void**>(&texture2D));
            if (SUCCEEDED(hr) && texture2D != nullptr)
            {
                D3D11_TEXTURE2D_DESC desc{};
                texture2D->GetDesc(&desc);
                format = desc.Format;
                width = desc.Width;
                height = desc.Height;
                mipLevels = desc.MipLevels;
                arraySize = desc.ArraySize;
                texture2D->Release();
            }
        }

        SetD3D11ProbeStatusFormatted(hr, dimension, format, width, height, mipLevels, arraySize);

        context->Release();
        device->Release();
        resource->Release();
        return 1;
    }

    const char* __cdecl VrisingDlss_GetD3D11ProbeStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_d3d11ProbeStatus;
    }

    int __cdecl VrisingDlss_ProbeD3D11TexturePair(void* sourceTexturePtr, void* destinationTexturePtr)
    {
        EvaluateTextureInfo source{};
        EvaluateTextureInfo destination{};
        char error[384] = {};

        if (!TryDescribeEvaluateTexture("source", sourceTexturePtr, &source, error, sizeof(error))
            || !TryDescribeEvaluateTexture("destination", destinationTexturePtr, &destination, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "D3D11 texture pair probe rejected: %s", error);
            SetD3D11TexturePairProbeStatus(message);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            return 0;
        }

        if (source.device != destination.device)
        {
            SetD3D11TexturePairProbeStatus("D3D11 texture pair probe rejected: source and destination were not on the same D3D11 device");
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            return 0;
        }

        if (!(destination.width > source.width && destination.height > source.height))
        {
            char message[512];
            std::snprintf(
                message,
                sizeof(message),
                "D3D11 texture pair probe rejected: destination was not larger than source; source=%ux%u destination=%ux%u",
                source.width,
                source.height,
                destination.width,
                destination.height);
            SetD3D11TexturePairProbeStatus(message);
            ReleaseEvaluateTextureInfo(&source);
            ReleaseEvaluateTextureInfo(&destination);
            return 0;
        }

        const double widthScale = static_cast<double>(destination.width) / static_cast<double>(source.width);
        const double heightScale = static_cast<double>(destination.height) / static_cast<double>(source.height);
        char message[1024];
        std::snprintf(
            message,
            sizeof(message),
            "D3D11 texture pair probe succeeded; sameDevice=yes; source=%ux%u fmt=%u mips=%u array=%u; destination=%ux%u fmt=%u mips=%u array=%u; scale=(%.3fx,%.3fx)",
            source.width,
            source.height,
            static_cast<unsigned int>(source.format),
            source.mipLevels,
            source.arraySize,
            destination.width,
            destination.height,
            static_cast<unsigned int>(destination.format),
            destination.mipLevels,
            destination.arraySize,
            widthScale,
            heightScale);
        SetD3D11TexturePairProbeStatus(message);

        ReleaseEvaluateTextureInfo(&source);
        ReleaseEvaluateTextureInfo(&destination);
        return 1;
    }

    const char* __cdecl VrisingDlss_GetD3D11TexturePairProbeStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_d3d11TexturePairProbeStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssRuntime(const wchar_t* runtimePath)
    {
        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            SetDlssRuntimeProbeStatus("DLSS runtime probe failed: runtime path was empty");
            return 0;
        }

        HMODULE module = LoadLibraryW(runtimePath);
        if (module == nullptr)
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS runtime probe failed: LoadLibraryW returned Win32=%lu",
                static_cast<unsigned long>(GetLastError()));
            SetDlssRuntimeProbeStatus(message);
            return 0;
        }

        const bool hasD3D11Init = GetProcAddress(module, "NVSDK_NGX_D3D11_Init") != nullptr;
        const bool hasD3D11InitExt = GetProcAddress(module, "NVSDK_NGX_D3D11_Init_Ext") != nullptr;
        const bool hasD3D11CreateFeature = GetProcAddress(module, "NVSDK_NGX_D3D11_CreateFeature") != nullptr;
        const bool hasD3D11EvaluateFeature = GetProcAddress(module, "NVSDK_NGX_D3D11_EvaluateFeature") != nullptr;
        const bool hasD3D11EvaluateFeatureC = GetProcAddress(module, "NVSDK_NGX_D3D11_EvaluateFeature_C") != nullptr;
        const bool hasD3D11ReleaseFeature = GetProcAddress(module, "NVSDK_NGX_D3D11_ReleaseFeature") != nullptr;
        const bool hasD3D11Shutdown = GetProcAddress(module, "NVSDK_NGX_D3D11_Shutdown") != nullptr;
        const bool hasD3D11Shutdown1 = GetProcAddress(module, "NVSDK_NGX_D3D11_Shutdown1") != nullptr;
        const bool hasAllocateParameters = GetProcAddress(module, "NVSDK_NGX_D3D11_AllocateParameters") != nullptr;
        const bool hasCapabilityParameters = GetProcAddress(module, "NVSDK_NGX_D3D11_GetCapabilityParameters") != nullptr;
        const bool hasDestroyParameters = GetProcAddress(module, "NVSDK_NGX_D3D11_DestroyParameters") != nullptr;
        const bool hasPopulateParameters = GetProcAddress(module, "NVSDK_NGX_D3D11_PopulateParameters_Impl") != nullptr;
        const bool hasParameterSetI = GetProcAddress(module, "NVSDK_NGX_Parameter_SetI") != nullptr;
        const bool hasParameterSetUI = GetProcAddress(module, "NVSDK_NGX_Parameter_SetUI") != nullptr;
        const bool hasParameterSetF = GetProcAddress(module, "NVSDK_NGX_Parameter_SetF") != nullptr;
        const bool hasParameterSetD3D11Resource = GetProcAddress(module, "NVSDK_NGX_Parameter_SetD3d11Resource") != nullptr;
        const bool hasParameterSetVoidPointer = GetProcAddress(module, "NVSDK_NGX_Parameter_SetVoidPointer") != nullptr;
        const bool hasParameterGetI = GetProcAddress(module, "NVSDK_NGX_Parameter_GetI") != nullptr;
        const bool hasParameterGetUI = GetProcAddress(module, "NVSDK_NGX_Parameter_GetUI") != nullptr;

        FreeLibrary(module);

        const bool hasD3D11RuntimeSurface = hasD3D11Init
            && hasD3D11CreateFeature
            && hasD3D11EvaluateFeature
            && hasD3D11ReleaseFeature
            && (hasD3D11Shutdown || hasD3D11Shutdown1);
        const bool hasDirectParameterMapSurface = (hasAllocateParameters || hasCapabilityParameters)
            && hasDestroyParameters
            && hasParameterSetI
            && hasParameterSetUI
            && hasParameterSetF
            && (hasParameterSetD3D11Resource || hasParameterSetVoidPointer);
        const bool hasDirectCapabilitySurface = hasCapabilityParameters
            && hasDestroyParameters
            && (hasParameterGetI || hasParameterGetUI);
        const bool directDlssRouteCandidate = hasD3D11RuntimeSurface && hasDirectParameterMapSurface;

        char message[1400];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS runtime probe loaded and released runtime; d3d11RuntimeSurface=%s; directDlssRouteCandidate=%s; directParameterMapSurface=%s; directCapabilitySurface=%s; NGX exports: D3D11_Init=%s, D3D11_Init_Ext=%s, CreateFeature=%s, EvaluateFeature=%s, EvaluateFeature_C=%s, ReleaseFeature=%s, D3D11_Shutdown=%s, D3D11_Shutdown1=%s, AllocateParameters=%s, GetCapabilityParameters=%s, DestroyParameters=%s, PopulateParameters_Impl=%s, Parameter_SetI=%s, Parameter_SetUI=%s, Parameter_SetF=%s, Parameter_SetD3d11Resource=%s, Parameter_SetVoidPointer=%s, Parameter_GetI=%s, Parameter_GetUI=%s",
            hasD3D11RuntimeSurface ? "yes" : "no",
            directDlssRouteCandidate ? "yes" : "no",
            hasDirectParameterMapSurface ? "yes" : "no",
            hasDirectCapabilitySurface ? "yes" : "no",
            hasD3D11Init ? "yes" : "no",
            hasD3D11InitExt ? "yes" : "no",
            hasD3D11CreateFeature ? "yes" : "no",
            hasD3D11EvaluateFeature ? "yes" : "no",
            hasD3D11EvaluateFeatureC ? "yes" : "no",
            hasD3D11ReleaseFeature ? "yes" : "no",
            hasD3D11Shutdown ? "yes" : "no",
            hasD3D11Shutdown1 ? "yes" : "no",
            hasAllocateParameters ? "yes" : "no",
            hasCapabilityParameters ? "yes" : "no",
            hasDestroyParameters ? "yes" : "no",
            hasPopulateParameters ? "yes" : "no",
            hasParameterSetI ? "yes" : "no",
            hasParameterSetUI ? "yes" : "no",
            hasParameterSetF ? "yes" : "no",
            hasParameterSetD3D11Resource ? "yes" : "no",
            hasParameterSetVoidPointer ? "yes" : "no",
            hasParameterGetI ? "yes" : "no",
            hasParameterGetUI ? "yes" : "no");
        SetDlssRuntimeProbeStatus(message);
        return hasD3D11RuntimeSurface ? 1 : 0;
    }

    const char* __cdecl VrisingDlss_GetDlssRuntimeProbeStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssRuntimeProbeStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssInitQuery(
        void* nativeTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId)
    {
        if (nativeTexturePtr == nullptr)
        {
            SetDlssInitQueryStatus("DLSS init/query probe failed: native texture pointer was null");
            return 0;
        }

        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            SetDlssInitQueryStatus("DLSS init/query probe failed: runtime path was empty");
            return 0;
        }

        const wchar_t* appDataPath = applicationDataPath != nullptr && applicationDataPath[0] != L'\0'
            ? applicationDataPath
            : L".";

        ID3D11Resource* resource = nullptr;
        HRESULT hr = static_cast<IUnknown*>(nativeTexturePtr)->QueryInterface(
            __uuidof(ID3D11Resource),
            reinterpret_cast<void**>(&resource));
        if (FAILED(hr) || resource == nullptr)
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS init/query probe failed: QueryInterface(ID3D11Resource) returned hr=0x%08X",
                static_cast<unsigned int>(hr));
            SetDlssInitQueryStatus(message);
            return 0;
        }

        ID3D11Device* device = nullptr;
        resource->GetDevice(&device);
        if (device == nullptr)
        {
            resource->Release();
            SetDlssInitQueryStatus("DLSS init/query probe failed: resource did not return a D3D11 device");
            return 0;
        }

#if defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        int sdkWrapperResult = ProbeDlssInitQueryWithSdkWrapper(device, runtimePath, appDataPath, applicationId);
        device->Release();
        resource->Release();
        return sdkWrapperResult;
#endif

        HMODULE module = LoadLibraryW(runtimePath);
        if (module == nullptr)
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS init/query probe failed: LoadLibraryW returned Win32=%lu",
                static_cast<unsigned long>(GetLastError()));
            SetDlssInitQueryStatus(message);
            device->Release();
            resource->Release();
            return 0;
        }

        auto d3d11Init = GetNgxExport<NgxD3D11InitFunc>(module, "NVSDK_NGX_D3D11_Init");
        auto getCapabilities = GetNgxExport<NgxD3D11GetCapabilityParametersFunc>(module, "NVSDK_NGX_D3D11_GetCapabilityParameters");
        auto destroyParameters = GetNgxExport<NgxD3D11DestroyParametersFunc>(module, "NVSDK_NGX_D3D11_DestroyParameters");
        auto shutdown1 = GetNgxExport<NgxD3D11Shutdown1Func>(module, "NVSDK_NGX_D3D11_Shutdown1");
        auto shutdown = GetNgxExport<NgxD3D11ShutdownFunc>(module, "NVSDK_NGX_D3D11_Shutdown");
        auto getInt = GetNgxExport<NgxParameterGetIntFunc>(module, "NVSDK_NGX_Parameter_GetI");
        auto getUInt = GetNgxExport<NgxParameterGetUIntFunc>(module, "NVSDK_NGX_Parameter_GetUI");
        const bool hasPopulateParameters = GetProcAddress(module, "NVSDK_NGX_D3D11_PopulateParameters_Impl") != nullptr;

        if (d3d11Init == nullptr || (shutdown1 == nullptr && shutdown == nullptr))
        {
            char message[384];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS init/query probe failed: missing mandatory runtime exports Init=%s Shutdown1=%s Shutdown=%s",
                d3d11Init != nullptr ? "yes" : "no",
                shutdown1 != nullptr ? "yes" : "no",
                shutdown != nullptr ? "yes" : "no");
            SetDlssInitQueryStatus(message);
            FreeLibrary(module);
            device->Release();
            resource->Release();
            return 0;
        }

        if (getCapabilities == nullptr || destroyParameters == nullptr)
        {
            char message[512];
            std::snprintf(
                message,
                sizeof(message),
                "SDK wrapper integration required: production nvngx_dlss.dll exposes runtime entry points, but not all capability-query helper exports; GetCapabilityParameters=%s DestroyParameters=%s PopulateParameters_Impl=%s. Link NVIDIA's SDK wrapper before Stage 6 init/query can run.",
                getCapabilities != nullptr ? "yes" : "no",
                destroyParameters != nullptr ? "yes" : "no",
                hasPopulateParameters ? "yes" : "no");
            SetDlssInitQueryStatus(message);
            FreeLibrary(module);
            device->Release();
            resource->Release();
            return 0;
        }

        NgxResult initResult = d3d11Init(applicationId, appDataPath, device, nullptr, kNgxVersionApi);
        if (initResult != kNgxResultSuccess)
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS init/query probe failed: NVSDK_NGX_D3D11_Init returned 0x%08X; applicationId=%llu",
                initResult,
                applicationId);
            SetDlssInitQueryStatus(message);
            FreeLibrary(module);
            device->Release();
            resource->Release();
            return 0;
        }

        void* parameters = nullptr;
        NgxResult capabilityResult = getCapabilities(&parameters);
        if (capabilityResult != kNgxResultSuccess || parameters == nullptr)
        {
            NgxResult shutdownResult = shutdown1 != nullptr ? shutdown1(device) : shutdown();
            char message[320];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS init/query probe failed: GetCapabilityParameters returned 0x%08X; shutdown=0x%08X",
                capabilityResult,
                shutdownResult);
            SetDlssInitQueryStatus(message);
            FreeLibrary(module);
            device->Release();
            resource->Release();
            return 0;
        }

        int available = -1;
        int needsUpdatedDriver = -1;
        int minDriverMajor = -1;
        int minDriverMinor = -1;
        int featureInitResult = -1;
        NgxResult availableResult = 0;
        NgxResult needsDriverResult = 0;
        NgxResult minMajorResult = 0;
        NgxResult minMinorResult = 0;
        NgxResult featureInitResultStatus = 0;

        TryGetNgxIntParameter(parameters, "SuperSampling.Available", getInt, getUInt, &available, &availableResult);
        TryGetNgxIntParameter(parameters, "SuperSampling.NeedsUpdatedDriver", getInt, getUInt, &needsUpdatedDriver, &needsDriverResult);
        TryGetNgxIntParameter(parameters, "SuperSampling.MinDriverVersionMajor", getInt, getUInt, &minDriverMajor, &minMajorResult);
        TryGetNgxIntParameter(parameters, "SuperSampling.MinDriverVersionMinor", getInt, getUInt, &minDriverMinor, &minMinorResult);
        TryGetNgxIntParameter(parameters, "SuperSampling.FeatureInitResult", getInt, getUInt, &featureInitResult, &featureInitResultStatus);

        NgxResult destroyResult = destroyParameters(parameters);
        NgxResult shutdownResult = shutdown1 != nullptr ? shutdown1(device) : shutdown();

        SetDlssInitQueryCompletedStatus(
            "runtime exports",
            applicationId,
            initResult,
            capabilityResult,
            available,
            availableResult,
            needsUpdatedDriver,
            needsDriverResult,
            minDriverMajor,
            minDriverMinor,
            minMajorResult,
            minMinorResult,
            featureInitResult,
            featureInitResultStatus,
            destroyResult,
            shutdownResult);

        FreeLibrary(module);
        device->Release();
        resource->Release();

        return destroyResult == kNgxResultSuccess && shutdownResult == kNgxResultSuccess ? 1 : 0;
    }

    const char* __cdecl VrisingDlss_GetDlssInitQueryStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssInitQueryStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssOptimalSettings(
        void* nativeTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        unsigned int outputWidth,
        unsigned int outputHeight,
        int perfQualityValue)
    {
        if (nativeTexturePtr == nullptr)
        {
            SetDlssOptimalSettingsStatus("DLSS optimal-settings probe failed: native texture pointer was null");
            return 0;
        }

        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            SetDlssOptimalSettingsStatus("DLSS optimal-settings probe failed: runtime path was empty");
            return 0;
        }

        if (outputWidth == 0 || outputHeight == 0)
        {
            SetDlssOptimalSettingsStatus("DLSS optimal-settings probe failed: output dimensions must be non-zero");
            return 0;
        }

        const wchar_t* appDataPath = applicationDataPath != nullptr && applicationDataPath[0] != L'\0'
            ? applicationDataPath
            : L".";

#if !defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        (void)nativeTexturePtr;
        (void)appDataPath;
        (void)applicationId;
        (void)outputWidth;
        (void)outputHeight;
        (void)perfQualityValue;
        SetDlssOptimalSettingsStatus("DLSS optimal-settings probe blocked: native bridge was built without NVIDIA SDK wrapper integration");
        return 0;
#else
        ID3D11Resource* resource = nullptr;
        HRESULT hr = static_cast<IUnknown*>(nativeTexturePtr)->QueryInterface(
            __uuidof(ID3D11Resource),
            reinterpret_cast<void**>(&resource));
        if (FAILED(hr) || resource == nullptr)
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS optimal-settings probe failed: QueryInterface(ID3D11Resource) returned hr=0x%08X",
                static_cast<unsigned int>(hr));
            SetDlssOptimalSettingsStatus(message);
            return 0;
        }

        ID3D11Device* device = nullptr;
        resource->GetDevice(&device);
        resource->Release();
        if (device == nullptr)
        {
            SetDlssOptimalSettingsStatus("DLSS optimal-settings probe failed: resource did not return a D3D11 device");
            return 0;
        }

        int result = ProbeDlssOptimalSettingsWithSdkWrapper(
            device,
            runtimePath,
            appDataPath,
            applicationId,
            outputWidth,
            outputHeight,
            perfQualityValue);
        device->Release();
        return result;
#endif
    }

    const char* __cdecl VrisingDlss_GetDlssOptimalSettingsStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssOptimalSettingsStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssFeatureCreate(
        void* nativeTexturePtr,
        const wchar_t* runtimePath,
        const wchar_t* applicationDataPath,
        unsigned long long applicationId,
        unsigned int renderWidth,
        unsigned int renderHeight,
        unsigned int targetWidth,
        unsigned int targetHeight,
        int perfQualityValue,
        int featureFlags)
    {
        if (nativeTexturePtr == nullptr)
        {
            SetDlssFeatureCreateStatus("DLSS feature create probe failed: native texture pointer was null");
            return 0;
        }

        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            SetDlssFeatureCreateStatus("DLSS feature create probe failed: runtime path was empty");
            return 0;
        }

        if (renderWidth == 0 || renderHeight == 0 || targetWidth == 0 || targetHeight == 0)
        {
            SetDlssFeatureCreateStatus("DLSS feature create probe failed: render/target dimensions must be non-zero");
            return 0;
        }

        const wchar_t* appDataPath = applicationDataPath != nullptr && applicationDataPath[0] != L'\0'
            ? applicationDataPath
            : L".";

#if !defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        (void)appDataPath;
        (void)applicationId;
        (void)renderWidth;
        (void)renderHeight;
        (void)targetWidth;
        (void)targetHeight;
        (void)perfQualityValue;
        (void)featureFlags;
        SetDlssFeatureCreateStatus("DLSS feature create probe blocked: native bridge was built without NVIDIA SDK wrapper integration");
        return 0;
#else
        ID3D11Resource* resource = nullptr;
        HRESULT hr = static_cast<IUnknown*>(nativeTexturePtr)->QueryInterface(
            __uuidof(ID3D11Resource),
            reinterpret_cast<void**>(&resource));
        if (FAILED(hr) || resource == nullptr)
        {
            char message[256];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS feature create probe failed: QueryInterface(ID3D11Resource) returned hr=0x%08X",
                static_cast<unsigned int>(hr));
            SetDlssFeatureCreateStatus(message);
            return 0;
        }

        ID3D11Device* device = nullptr;
        resource->GetDevice(&device);
        resource->Release();
        if (device == nullptr)
        {
            SetDlssFeatureCreateStatus("DLSS feature create probe failed: resource did not return a D3D11 device");
            return 0;
        }

        int result = ProbeDlssFeatureCreateWithSdkWrapper(
            device,
            runtimePath,
            appDataPath,
            applicationId,
            renderWidth,
            renderHeight,
            targetWidth,
            targetHeight,
            perfQualityValue,
            featureFlags);
        device->Release();
        return result;
#endif
    }

    const char* __cdecl VrisingDlss_GetDlssFeatureCreateStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssFeatureCreateStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssEvaluateInputs(
        void* colorTexturePtr,
        void* outputTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr)
    {
        EvaluateTextureInfo color{};
        EvaluateTextureInfo output{};
        EvaluateTextureInfo depth{};
        EvaluateTextureInfo motion{};
        char error[384] = {};

        if (!TryDescribeEvaluateTexture("color", colorTexturePtr, &color, error, sizeof(error))
            || !TryDescribeEvaluateTexture("output", outputTexturePtr, &output, error, sizeof(error))
            || !TryDescribeEvaluateTexture("depth", depthTexturePtr, &depth, error, sizeof(error))
            || !TryDescribeEvaluateTexture("motion", motionTexturePtr, &motion, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS evaluate input probe failed: %s", error);
            SetDlssEvaluateInputStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const bool sameDevice = color.device == output.device
            && color.device == depth.device
            && color.device == motion.device;
        if (!sameDevice)
        {
            SetDlssEvaluateInputStatus("DLSS evaluate input probe failed: color/output/depth/motion textures were not on the same D3D11 device");
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const bool depthMatchesColor = EvaluateInputDimensionsMatch(color, depth);
        const bool motionMatchesColor = EvaluateInputDimensionsMatch(color, motion);
        if (!depthMatchesColor || !motionMatchesColor)
        {
            char message[640];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS evaluate input probe failed: input dimensions were not frame-aligned; color=%ux%u depth=%ux%u motion=%ux%u",
                color.width,
                color.height,
                depth.width,
                depth.height,
                motion.width,
                motion.height);
            SetDlssEvaluateInputStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        char message[1400];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS evaluate input probe succeeded; sameDevice=yes; color=%ux%u fmt=%u mips=%u array=%u; output=%ux%u fmt=%u mips=%u array=%u; depth=%ux%u fmt=%u mips=%u array=%u; motion=%ux%u fmt=%u mips=%u array=%u",
            color.width,
            color.height,
            static_cast<unsigned int>(color.format),
            color.mipLevels,
            color.arraySize,
            output.width,
            output.height,
            static_cast<unsigned int>(output.format),
            output.mipLevels,
            output.arraySize,
            depth.width,
            depth.height,
            static_cast<unsigned int>(depth.format),
            depth.mipLevels,
            depth.arraySize,
            motion.width,
            motion.height,
            static_cast<unsigned int>(motion.format),
            motion.mipLevels,
            motion.arraySize);
        SetDlssEvaluateInputStatus(message);

        ReleaseEvaluateTextureInfo(&color);
        ReleaseEvaluateTextureInfo(&output);
        ReleaseEvaluateTextureInfo(&depth);
        ReleaseEvaluateTextureInfo(&motion);
        return 1;
    }

    const char* __cdecl VrisingDlss_GetDlssEvaluateInputStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssEvaluateInputStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssSuperResolutionInputs(
        void* colorTexturePtr,
        void* outputTexturePtr,
        void* depthTexturePtr,
        void* motionTexturePtr)
    {
        EvaluateTextureInfo color{};
        EvaluateTextureInfo output{};
        EvaluateTextureInfo depth{};
        EvaluateTextureInfo motion{};
        char error[384] = {};

        if (!TryDescribeEvaluateTexture("color", colorTexturePtr, &color, error, sizeof(error))
            || !TryDescribeEvaluateTexture("output", outputTexturePtr, &output, error, sizeof(error))
            || !TryDescribeEvaluateTexture("depth", depthTexturePtr, &depth, error, sizeof(error))
            || !TryDescribeEvaluateTexture("motion", motionTexturePtr, &motion, error, sizeof(error)))
        {
            char message[512];
            std::snprintf(message, sizeof(message), "DLSS super-resolution input probe rejected: %s", error);
            SetDlssSuperResolutionInputStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const bool sameDevice = color.device == output.device
            && color.device == depth.device
            && color.device == motion.device;
        if (!sameDevice)
        {
            SetDlssSuperResolutionInputStatus("DLSS super-resolution input probe rejected: color/output/depth/motion textures were not on the same D3D11 device");
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const bool depthMatchesColor = EvaluateInputDimensionsMatch(color, depth);
        const bool motionMatchesColor = EvaluateInputDimensionsMatch(color, motion);
        if (!depthMatchesColor || !motionMatchesColor)
        {
            char message[640];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS super-resolution input probe rejected: input dimensions were not frame-aligned; color=%ux%u depth=%ux%u motion=%ux%u",
                color.width,
                color.height,
                depth.width,
                depth.height,
                motion.width,
                motion.height);
            SetDlssSuperResolutionInputStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const bool outputLargerThanColor = output.width > color.width && output.height > color.height;
        if (!outputLargerThanColor)
        {
            char message[512];
            std::snprintf(
                message,
                sizeof(message),
                "DLSS super-resolution input probe not accepted: output was not larger than render input; color=%ux%u output=%ux%u",
                color.width,
                color.height,
                output.width,
                output.height);
            SetDlssSuperResolutionInputStatus(message);
            ReleaseEvaluateTextureInfo(&color);
            ReleaseEvaluateTextureInfo(&output);
            ReleaseEvaluateTextureInfo(&depth);
            ReleaseEvaluateTextureInfo(&motion);
            return 0;
        }

        const double widthScale = static_cast<double>(output.width) / static_cast<double>(color.width);
        const double heightScale = static_cast<double>(output.height) / static_cast<double>(color.height);
        char message[1500];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS super-resolution input probe succeeded; sameDevice=yes; color=%ux%u fmt=%u mips=%u array=%u; output=%ux%u fmt=%u mips=%u array=%u; depth=%ux%u fmt=%u mips=%u array=%u; motion=%ux%u fmt=%u mips=%u array=%u; scale=(%.3fx,%.3fx)",
            color.width,
            color.height,
            static_cast<unsigned int>(color.format),
            color.mipLevels,
            color.arraySize,
            output.width,
            output.height,
            static_cast<unsigned int>(output.format),
            output.mipLevels,
            output.arraySize,
            depth.width,
            depth.height,
            static_cast<unsigned int>(depth.format),
            depth.mipLevels,
            depth.arraySize,
            motion.width,
            motion.height,
            static_cast<unsigned int>(motion.format),
            motion.mipLevels,
            motion.arraySize,
            widthScale,
            heightScale);
        SetDlssSuperResolutionInputStatus(message);

        ReleaseEvaluateTextureInfo(&color);
        ReleaseEvaluateTextureInfo(&output);
        ReleaseEvaluateTextureInfo(&depth);
        ReleaseEvaluateTextureInfo(&motion);
        return 1;
    }

    const char* __cdecl VrisingDlss_GetDlssSuperResolutionInputStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssSuperResolutionInputStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssEvaluate(
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
        int reset)
    {
        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            SetDlssEvaluateStatus("DLSS evaluate probe skipped: runtime path was empty");
            return 0;
        }

        const wchar_t* appDataPath = applicationDataPath != nullptr && applicationDataPath[0] != L'\0'
            ? applicationDataPath
            : L".";

#if !defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        (void)colorTexturePtr;
        (void)outputTexturePtr;
        (void)depthTexturePtr;
        (void)motionTexturePtr;
        (void)appDataPath;
        (void)applicationId;
        (void)perfQualityValue;
        (void)featureFlags;
        (void)jitterOffsetX;
        (void)jitterOffsetY;
        (void)motionVectorScaleX;
        (void)motionVectorScaleY;
        (void)sharpness;
        (void)reset;
        SetDlssEvaluateStatus("DLSS evaluate probe blocked: native bridge was built without NVIDIA SDK wrapper integration");
        return 0;
#else
        return ProbeDlssEvaluateWithSdkWrapper(
            colorTexturePtr,
            outputTexturePtr,
            depthTexturePtr,
            motionTexturePtr,
            runtimePath,
            appDataPath,
            applicationId,
            perfQualityValue,
            featureFlags,
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX,
            motionVectorScaleY,
            sharpness,
            reset);
#endif
    }

    const char* __cdecl VrisingDlss_GetDlssEvaluateStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssEvaluateStatus;
    }

    int __cdecl VrisingDlss_ProbeDlssPersistentEvaluate(
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
        int evaluateCount)
    {
        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            SetDlssPersistentEvaluateStatus("DLSS persistent evaluate probe skipped: runtime path was empty");
            return 0;
        }

        const wchar_t* appDataPath = applicationDataPath != nullptr && applicationDataPath[0] != L'\0'
            ? applicationDataPath
            : L".";

#if !defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        (void)colorTexturePtr;
        (void)outputTexturePtr;
        (void)depthTexturePtr;
        (void)motionTexturePtr;
        (void)appDataPath;
        (void)applicationId;
        (void)perfQualityValue;
        (void)featureFlags;
        (void)jitterOffsetX;
        (void)jitterOffsetY;
        (void)motionVectorScaleX;
        (void)motionVectorScaleY;
        (void)sharpness;
        (void)reset;
        (void)evaluateCount;
        SetDlssPersistentEvaluateStatus("DLSS persistent evaluate probe blocked: native bridge was built without NVIDIA SDK wrapper integration");
        return 0;
#else
        return ProbeDlssPersistentEvaluateWithSdkWrapper(
            colorTexturePtr,
            outputTexturePtr,
            depthTexturePtr,
            motionTexturePtr,
            runtimePath,
            appDataPath,
            applicationId,
            perfQualityValue,
            featureFlags,
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX,
            motionVectorScaleY,
            sharpness,
            reset,
            evaluateCount);
#endif
    }

    const char* __cdecl VrisingDlss_GetDlssPersistentEvaluateStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssPersistentEvaluateStatus;
    }

    int __cdecl VrisingDlss_EvaluateDlssFrameSequence(
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
        int reset)
    {
        if (runtimePath == nullptr || runtimePath[0] == L'\0')
        {
            SetDlssFrameSequenceStatus("DLSS frame-sequence evaluate probe skipped: runtime path was empty");
            return 0;
        }

        const wchar_t* appDataPath = applicationDataPath != nullptr && applicationDataPath[0] != L'\0'
            ? applicationDataPath
            : L".";

#if !defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        (void)colorTexturePtr;
        (void)outputTexturePtr;
        (void)depthTexturePtr;
        (void)motionTexturePtr;
        (void)appDataPath;
        (void)applicationId;
        (void)perfQualityValue;
        (void)featureFlags;
        (void)jitterOffsetX;
        (void)jitterOffsetY;
        (void)motionVectorScaleX;
        (void)motionVectorScaleY;
        (void)sharpness;
        (void)reset;
        SetDlssFrameSequenceStatus("DLSS frame-sequence evaluate probe blocked: native bridge was built without NVIDIA SDK wrapper integration");
        return 0;
#else
        return EvaluateDlssFrameSequenceWithSdkWrapper(
            colorTexturePtr,
            outputTexturePtr,
            depthTexturePtr,
            motionTexturePtr,
            runtimePath,
            appDataPath,
            applicationId,
            perfQualityValue,
            featureFlags,
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX,
            motionVectorScaleY,
            sharpness,
            reset);
#endif
    }

    int __cdecl VrisingDlss_ShutdownDlssFrameSequence()
    {
#if !defined(VRISINGDLSS_ENABLE_NGX_SDK_WRAPPER)
        SetDlssFrameSequenceStatus("DLSS frame-sequence shutdown blocked: native bridge was built without NVIDIA SDK wrapper integration");
        return 0;
#else
        return ShutdownDlssFrameSequenceWithSdkWrapper();
#endif
    }

    const char* __cdecl VrisingDlss_GetDlssFrameSequenceStatus()
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        return g_dlssFrameSequenceStatus;
    }
}
