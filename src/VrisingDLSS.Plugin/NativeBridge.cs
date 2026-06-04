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
    private ProbeDlssFeatureCreateDelegate? _probeDlssFeatureCreate;
    private GetStringPointerDelegate? _getDlssFeatureCreateStatus;
    private ProbeDlssEvaluateInputsDelegate? _probeDlssEvaluateInputs;
    private GetStringPointerDelegate? _getDlssEvaluateInputStatus;

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
        _probeDlssFeatureCreate = GetOptionalExport<ProbeDlssFeatureCreateDelegate>("VrisingDlss_ProbeDlssFeatureCreate");
        _getDlssFeatureCreateStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssFeatureCreateStatus");
        _probeDlssEvaluateInputs = GetOptionalExport<ProbeDlssEvaluateInputsDelegate>("VrisingDlss_ProbeDlssEvaluateInputs");
        _getDlssEvaluateInputStatus = GetOptionalExport<GetStringPointerDelegate>("VrisingDlss_GetDlssEvaluateInputStatus");

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
