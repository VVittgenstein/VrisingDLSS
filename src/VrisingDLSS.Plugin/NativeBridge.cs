using BepInEx.Logging;
using System;
using System.Runtime.InteropServices;

namespace VrisingDLSS.Plugin;

internal sealed class NativeBridge
{
    private readonly ManualLogSource _log;
    private IntPtr _library;
    private GetIntDelegate? _getBridgeApiVersion;
    private GetStringPointerDelegate? _getBridgeVersion;
    private GetStringPointerDelegate? _getDiagnosticStatus;
    private GetPointerDelegate? _getRenderEventFunc;
    private GetIntDelegate? _getRenderEventCount;
    private GetIntDelegate? _getLastRenderEventId;
    private GetStringPointerDelegate? _getRenderEventStatus;
    private ProbePointerDelegate? _probeD3D11Texture;
    private GetStringPointerDelegate? _getD3D11ProbeStatus;
    private ProbeWideStringDelegate? _probeDlssRuntime;
    private GetStringPointerDelegate? _getDlssRuntimeProbeStatus;
    private ProbeDlssInitQueryDelegate? _probeDlssInitQuery;
    private GetStringPointerDelegate? _getDlssInitQueryStatus;
    private ProbeDlssOptimalSettingsDelegate? _probeDlssOptimalSettings;
    private GetStringPointerDelegate? _getDlssOptimalSettingsStatus;
    private ProbeDlssFeatureCreateDelegate? _probeDlssFeatureCreate;
    private GetStringPointerDelegate? _getDlssFeatureCreateStatus;
    private ProbeDlssEvaluateInputsDelegate? _probeDlssEvaluateInputs;
    private GetStringPointerDelegate? _getDlssEvaluateInputStatus;
    private ProbeDlssEvaluateInputsDelegate? _probeDlssSuperResolutionInputs;
    private GetStringPointerDelegate? _getDlssSuperResolutionInputStatus;
    private ProbeDlssEvaluateDelegate? _probeDlssEvaluate;
    private GetStringPointerDelegate? _getDlssEvaluateStatus;
    private ProbeDlssPersistentEvaluateDelegate? _probeDlssPersistentEvaluate;
    private GetStringPointerDelegate? _getDlssPersistentEvaluateStatus;
    private ProbeDlssEvaluateDelegate? _evaluateDlssFrameSequence;
    private GetIntDelegate? _shutdownDlssFrameSequence;
    private GetStringPointerDelegate? _getDlssFrameSequenceStatus;

    internal NativeBridge(ManualLogSource log)
    {
        _log = log;
    }

    internal bool TryLoad(string bridgePath)
    {
        if (!NativeMethods.SetDllDirectory(System.IO.Path.GetDirectoryName(bridgePath)))
        {
            _log.LogWarning($"SetDllDirectory failed for native bridge folder. Win32={Marshal.GetLastWin32Error()}");
        }

        _library = NativeMethods.LoadLibrary(bridgePath);
        if (_library == IntPtr.Zero)
        {
            _log.LogWarning($"Native bridge not loaded: {bridgePath}. Win32={Marshal.GetLastWin32Error()}");
            return false;
        }

        _getBridgeApiVersion = GetExport<GetIntDelegate>("VrisingDlss_GetBridgeApiVersion");
        _getBridgeVersion = GetExport<GetStringPointerDelegate>("VrisingDlss_GetBridgeVersion");
        _getDiagnosticStatus = GetExport<GetStringPointerDelegate>("VrisingDlss_GetDiagnosticStatus");
        _getRenderEventFunc = GetOptionalExport<GetPointerDelegate>("VrisingDlss_GetRenderEventFunc");
        _getRenderEventCount = GetOptionalExport<GetIntDelegate>("VrisingDlss_GetRenderEventCount");
        _getLastRenderEventId = GetOptionalExport<GetIntDelegate>("VrisingDlss_GetLastRenderEventId");
        _getRenderEventStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetRenderEventStatus");
        _probeD3D11Texture = GetOptionalExport<ProbePointerDelegate>("VrisingDlss_ProbeD3D11Texture");
        _getD3D11ProbeStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetD3D11ProbeStatus");
        _probeDlssRuntime = GetOptionalExport<ProbeWideStringDelegate>("VrisingDlss_ProbeDlssRuntime");
        _getDlssRuntimeProbeStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssRuntimeProbeStatus");
        _probeDlssInitQuery = GetOptionalExport<ProbeDlssInitQueryDelegate>("VrisingDlss_ProbeDlssInitQuery");
        _getDlssInitQueryStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssInitQueryStatus");
        _probeDlssOptimalSettings = GetOptionalExport<ProbeDlssOptimalSettingsDelegate>("VrisingDlss_ProbeDlssOptimalSettings");
        _getDlssOptimalSettingsStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssOptimalSettingsStatus");
        _probeDlssFeatureCreate = GetOptionalExport<ProbeDlssFeatureCreateDelegate>("VrisingDlss_ProbeDlssFeatureCreate");
        _getDlssFeatureCreateStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssFeatureCreateStatus");
        _probeDlssEvaluateInputs = GetOptionalExport<ProbeDlssEvaluateInputsDelegate>("VrisingDlss_ProbeDlssEvaluateInputs");
        _getDlssEvaluateInputStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssEvaluateInputStatus");
        _probeDlssSuperResolutionInputs = GetOptionalExport<ProbeDlssEvaluateInputsDelegate>("VrisingDlss_ProbeDlssSuperResolutionInputs");
        _getDlssSuperResolutionInputStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssSuperResolutionInputStatus");
        _probeDlssEvaluate = GetOptionalExport<ProbeDlssEvaluateDelegate>("VrisingDlss_ProbeDlssEvaluate");
        _getDlssEvaluateStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssEvaluateStatus");
        _probeDlssPersistentEvaluate = GetOptionalExport<ProbeDlssPersistentEvaluateDelegate>("VrisingDlss_ProbeDlssPersistentEvaluate");
        _getDlssPersistentEvaluateStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssPersistentEvaluateStatus");
        _evaluateDlssFrameSequence = GetOptionalExport<ProbeDlssEvaluateDelegate>("VrisingDlss_EvaluateDlssFrameSequence");
        _shutdownDlssFrameSequence = GetOptionalExport<GetIntDelegate>("VrisingDlss_ShutdownDlssFrameSequence");
        _getDlssFrameSequenceStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssFrameSequenceStatus");

        return _getBridgeApiVersion is not null
            && _getBridgeVersion is not null
            && _getDiagnosticStatus is not null;
    }

    internal int GetBridgeApiVersion() => _getBridgeApiVersion?.Invoke() ?? -1;

    internal string GetBridgeVersion() => PtrToString(_getBridgeVersion?.Invoke() ?? IntPtr.Zero);

    internal string GetDiagnosticStatus() => PtrToString(_getDiagnosticStatus?.Invoke() ?? IntPtr.Zero);

    internal IntPtr GetRenderEventFunc() => _getRenderEventFunc?.Invoke() ?? IntPtr.Zero;

    internal int GetRenderEventCount() => _getRenderEventCount?.Invoke() ?? -1;

    internal int GetLastRenderEventId() => _getLastRenderEventId?.Invoke() ?? -1;

    internal string GetRenderEventStatus() => PtrToString(_getRenderEventStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeD3D11Texture(IntPtr nativeTexturePtr) => _probeD3D11Texture?.Invoke(nativeTexturePtr) == 1;

    internal string GetD3D11ProbeStatus() => PtrToString(_getD3D11ProbeStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssRuntime(string runtimePath) => _probeDlssRuntime?.Invoke(runtimePath) == 1;

    internal string GetDlssRuntimeProbeStatus() => PtrToString(_getDlssRuntimeProbeStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssInitQuery(
        IntPtr nativeTexturePtr,
        string runtimePath,
        string applicationDataPath,
        ulong applicationId) =>
        _probeDlssInitQuery?.Invoke(nativeTexturePtr, runtimePath, applicationDataPath, applicationId) == 1;

    internal string GetDlssInitQueryStatus() => PtrToString(_getDlssInitQueryStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssOptimalSettings(
        IntPtr nativeTexturePtr,
        string runtimePath,
        string applicationDataPath,
        ulong applicationId,
        uint outputWidth,
        uint outputHeight,
        int perfQualityValue) =>
        _probeDlssOptimalSettings?.Invoke(
            nativeTexturePtr,
            runtimePath,
            applicationDataPath,
            applicationId,
            outputWidth,
            outputHeight,
            perfQualityValue) == 1;

    internal string GetDlssOptimalSettingsStatus() => PtrToString(_getDlssOptimalSettingsStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssFeatureCreate(
        IntPtr nativeTexturePtr,
        string runtimePath,
        string applicationDataPath,
        ulong applicationId,
        uint renderWidth,
        uint renderHeight,
        uint targetWidth,
        uint targetHeight,
        int perfQualityValue,
        int featureFlags) =>
        _probeDlssFeatureCreate?.Invoke(
            nativeTexturePtr,
            runtimePath,
            applicationDataPath,
            applicationId,
            renderWidth,
            renderHeight,
            targetWidth,
            targetHeight,
            perfQualityValue,
            featureFlags) == 1;

    internal string GetDlssFeatureCreateStatus() => PtrToString(_getDlssFeatureCreateStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssEvaluateInputs(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr) =>
        _probeDlssEvaluateInputs?.Invoke(colorTexturePtr, outputTexturePtr, depthTexturePtr, motionTexturePtr) == 1;

    internal string GetDlssEvaluateInputStatus() => PtrToString(_getDlssEvaluateInputStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssSuperResolutionInputs(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr) =>
        _probeDlssSuperResolutionInputs?.Invoke(colorTexturePtr, outputTexturePtr, depthTexturePtr, motionTexturePtr) == 1;

    internal string GetDlssSuperResolutionInputStatus() => PtrToString(_getDlssSuperResolutionInputStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssEvaluate(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr,
        string runtimePath,
        string applicationDataPath,
        ulong applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset) =>
        _probeDlssEvaluate?.Invoke(
            colorTexturePtr,
            outputTexturePtr,
            depthTexturePtr,
            motionTexturePtr,
            runtimePath,
            applicationDataPath,
            applicationId,
            perfQualityValue,
            featureFlags,
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX,
            motionVectorScaleY,
            sharpness,
            reset) == 1;

    internal string GetDlssEvaluateStatus() => PtrToString(_getDlssEvaluateStatus?.Invoke() ?? IntPtr.Zero);

    internal bool ProbeDlssPersistentEvaluate(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr,
        string runtimePath,
        string applicationDataPath,
        ulong applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset,
        int evaluateCount) =>
        _probeDlssPersistentEvaluate?.Invoke(
            colorTexturePtr,
            outputTexturePtr,
            depthTexturePtr,
            motionTexturePtr,
            runtimePath,
            applicationDataPath,
            applicationId,
            perfQualityValue,
            featureFlags,
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX,
            motionVectorScaleY,
            sharpness,
            reset,
            evaluateCount) == 1;

    internal string GetDlssPersistentEvaluateStatus() => PtrToString(_getDlssPersistentEvaluateStatus?.Invoke() ?? IntPtr.Zero);

    internal bool EvaluateDlssFrameSequence(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr,
        string runtimePath,
        string applicationDataPath,
        ulong applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset) =>
        _evaluateDlssFrameSequence?.Invoke(
            colorTexturePtr,
            outputTexturePtr,
            depthTexturePtr,
            motionTexturePtr,
            runtimePath,
            applicationDataPath,
            applicationId,
            perfQualityValue,
            featureFlags,
            jitterOffsetX,
            jitterOffsetY,
            motionVectorScaleX,
            motionVectorScaleY,
            sharpness,
            reset) == 1;

    internal bool ShutdownDlssFrameSequence() => _shutdownDlssFrameSequence?.Invoke() == 1;

    internal string GetDlssFrameSequenceStatus() => PtrToString(_getDlssFrameSequenceStatus?.Invoke() ?? IntPtr.Zero);

    private T? GetExport<T>(string exportName) where T : Delegate
    {
        var address = NativeMethods.GetProcAddress(_library, exportName);
        if (address == IntPtr.Zero)
        {
            _log.LogWarning($"Native bridge export missing: {exportName}");
            return null;
        }

        return Marshal.GetDelegateForFunctionPointer<T>(address);
    }

    private T? GetOptionalExport<T>(string exportName) where T : Delegate
    {
        var address = NativeMethods.GetProcAddress(_library, exportName);
        return address == IntPtr.Zero
            ? null
            : Marshal.GetDelegateForFunctionPointer<T>(address);
    }

    private static string PtrToString(IntPtr pointer)
    {
        return pointer == IntPtr.Zero
            ? string.Empty
            : Marshal.PtrToStringAnsi(pointer) ?? string.Empty;
    }

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int GetIntDelegate();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate IntPtr GetStringPointerDelegate();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate IntPtr GetPointerDelegate();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int ProbePointerDelegate(IntPtr pointer);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    private delegate int ProbeWideStringDelegate([MarshalAs(UnmanagedType.LPWStr)] string value);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    private delegate int ProbeDlssInitQueryDelegate(
        IntPtr nativeTexturePtr,
        [MarshalAs(UnmanagedType.LPWStr)] string runtimePath,
        [MarshalAs(UnmanagedType.LPWStr)] string applicationDataPath,
        ulong applicationId);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    private delegate int ProbeDlssOptimalSettingsDelegate(
        IntPtr nativeTexturePtr,
        [MarshalAs(UnmanagedType.LPWStr)] string runtimePath,
        [MarshalAs(UnmanagedType.LPWStr)] string applicationDataPath,
        ulong applicationId,
        uint outputWidth,
        uint outputHeight,
        int perfQualityValue);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    private delegate int ProbeDlssFeatureCreateDelegate(
        IntPtr nativeTexturePtr,
        [MarshalAs(UnmanagedType.LPWStr)] string runtimePath,
        [MarshalAs(UnmanagedType.LPWStr)] string applicationDataPath,
        ulong applicationId,
        uint renderWidth,
        uint renderHeight,
        uint targetWidth,
        uint targetHeight,
        int perfQualityValue,
        int featureFlags);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int ProbeDlssEvaluateInputsDelegate(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    private delegate int ProbeDlssEvaluateDelegate(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr,
        [MarshalAs(UnmanagedType.LPWStr)] string runtimePath,
        [MarshalAs(UnmanagedType.LPWStr)] string applicationDataPath,
        ulong applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
    private delegate int ProbeDlssPersistentEvaluateDelegate(
        IntPtr colorTexturePtr,
        IntPtr outputTexturePtr,
        IntPtr depthTexturePtr,
        IntPtr motionTexturePtr,
        [MarshalAs(UnmanagedType.LPWStr)] string runtimePath,
        [MarshalAs(UnmanagedType.LPWStr)] string applicationDataPath,
        ulong applicationId,
        int perfQualityValue,
        int featureFlags,
        float jitterOffsetX,
        float jitterOffsetY,
        float motionVectorScaleX,
        float motionVectorScaleY,
        float sharpness,
        int reset,
        int evaluateCount);

    private static class NativeMethods
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        internal static extern IntPtr LoadLibrary(string fileName);

        [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
        internal static extern IntPtr GetProcAddress(IntPtr module, string procName);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        internal static extern bool SetDllDirectory(string? pathName);
    }
}
