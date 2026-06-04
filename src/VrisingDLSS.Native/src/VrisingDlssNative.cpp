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
    std::atomic<int> g_renderEventCount{0};
    std::atomic<int> g_lastRenderEventId{-1};
    std::mutex g_probeStatusMutex;
    char g_d3d11ProbeStatus[512] = "D3D11 texture probe has not run";
    char g_dlssRuntimeProbeStatus[512] = "DLSS runtime probe has not run";
    char g_dlssInitQueryStatus[1024] = "DLSS init/query probe has not run";
    char g_dlssFeatureCreateStatus[1024] = "DLSS feature create probe has not run";
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

    void VRISINGDLSS_RENDER_EVENT_CALL OnRenderEvent(int eventId)
    {
        g_lastRenderEventId.store(eventId);
        g_renderEventCount.fetch_add(1);
    }

    void SetD3D11ProbeStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_d3d11ProbeStatus, sizeof(g_d3d11ProbeStatus), "%s", message);
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

    void SetDlssFeatureCreateStatus(const char* message)
    {
        std::lock_guard<std::mutex> lock(g_probeStatusMutex);
        std::snprintf(g_dlssFeatureCreateStatus, sizeof(g_dlssFeatureCreateStatus), "%s", message);
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
        return 6;
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
        const bool hasD3D11CreateFeature = GetProcAddress(module, "NVSDK_NGX_D3D11_CreateFeature") != nullptr;
        const bool hasD3D11EvaluateFeature = GetProcAddress(module, "NVSDK_NGX_D3D11_EvaluateFeature") != nullptr;
        const bool hasD3D11ReleaseFeature = GetProcAddress(module, "NVSDK_NGX_D3D11_ReleaseFeature") != nullptr;
        const bool hasD3D11Shutdown = GetProcAddress(module, "NVSDK_NGX_D3D11_Shutdown") != nullptr;
        const bool hasD3D11Shutdown1 = GetProcAddress(module, "NVSDK_NGX_D3D11_Shutdown1") != nullptr;
        const bool hasCapabilityParameters = GetProcAddress(module, "NVSDK_NGX_D3D11_GetCapabilityParameters") != nullptr;
        const bool hasPopulateParameters = GetProcAddress(module, "NVSDK_NGX_D3D11_PopulateParameters_Impl") != nullptr;

        FreeLibrary(module);

        const bool hasD3D11RuntimeSurface = hasD3D11Init
            && hasD3D11CreateFeature
            && hasD3D11EvaluateFeature
            && hasD3D11ReleaseFeature
            && (hasD3D11Shutdown || hasD3D11Shutdown1);

        char message[512];
        std::snprintf(
            message,
            sizeof(message),
            "DLSS runtime probe loaded and released runtime; known NGX exports: D3D11_Init=%s, CreateFeature=%s, EvaluateFeature=%s, ReleaseFeature=%s, D3D11_Shutdown=%s, D3D11_Shutdown1=%s, GetCapabilityParameters=%s, PopulateParameters_Impl=%s",
            hasD3D11Init ? "yes" : "no",
            hasD3D11CreateFeature ? "yes" : "no",
            hasD3D11EvaluateFeature ? "yes" : "no",
            hasD3D11ReleaseFeature ? "yes" : "no",
            hasD3D11Shutdown ? "yes" : "no",
            hasD3D11Shutdown1 ? "yes" : "no",
            hasCapabilityParameters ? "yes" : "no",
            hasPopulateParameters ? "yes" : "no");
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
}
