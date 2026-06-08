using BepInEx.Logging;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class HdrpPostProcessRenderArgsProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".hdrp-postprocess-render-args-probe";
    private const string TargetTypeName = "DarkForeground";
    private const int MaxFailureLogs = 8;

    private static readonly object Sync = new();
    private static int CallCount;
    private static int FailureCount;
    private static bool GlobalTextureAdvancedLogged;

    private static ManualLogSource? Log;
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static bool Installed;
    private static bool GlobalTextureSnapshotEnabled;
    private static bool UnityTimeLookupAttempted;
    private static PropertyInfo? UnityTimeFrameCountProperty;

    internal static void Install(ManualLogSource log, bool enableGlobalTextureSnapshot)
    {
        if (Installed)
        {
            log.LogInfo("HDRP postprocess render args probe is already installed.");
            return;
        }

        Log = log;
        GlobalTextureSnapshotEnabled = enableGlobalTextureSnapshot;
        if (enableGlobalTextureSnapshot)
        {
            HdrpEasuInputOutputCorrelationProbeState.Reset(active: true);
        }

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var harmonyType = FindRuntimeType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = FindRuntimeType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            log.LogWarning("HDRP postprocess render args probe blocked: Harmony runtime was not found.");
            return;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var prefix = typeof(HdrpPostProcessRenderArgsProbe).GetMethod(nameof(ProbePrefix), BindingFlags.NonPublic | BindingFlags.Static);
        var patchMethod = FindPatchMethod(harmonyType);

        if (harmonyConstructor is null || harmonyMethodConstructor is null || prefix is null || patchMethod is null)
        {
            log.LogWarning("HDRP postprocess render args probe blocked: Harmony runtime shape was not recognized.");
            return;
        }

        var targetType = HookTargetCatalog.FindType(assemblies, TargetTypeName);
        if (targetType is null)
        {
            log.LogWarning($"HDRP postprocess render args probe blocked: target type not found: {TargetTypeName}");
            return;
        }

        HarmonyInstance = harmonyConstructor.Invoke(new object[] { HarmonyId });
        HarmonyType = harmonyType;

        var patched = 0;
        foreach (var method in HookTargetCatalog.FindMethods(targetType, "Render"))
        {
            if (!CanPatch(method))
            {
                log.LogWarning($"HDRP postprocess render args probe skipped unsupported method: {HookTargetCatalog.FormatMethod(method)}");
                continue;
            }

            if (!IsPostProcessRenderSignature(method))
            {
                log.LogInfo($"HDRP postprocess render args probe skipped non-postprocess signature: {HookTargetCatalog.FormatMethod(method)}");
                continue;
            }

            try
            {
                var prefixPatch = harmonyMethodConstructor.Invoke(new object[] { prefix });
                var arguments = new object?[patchMethod.GetParameters().Length];
                arguments[0] = method;
                arguments[1] = prefixPatch;
                patchMethod.Invoke(HarmonyInstance, arguments);
                patched++;
                log.LogInfo($"HDRP postprocess render args probe patched: {HookTargetCatalog.FormatMethod(method)}");
            }
            catch (Exception ex)
            {
                log.LogWarning($"HDRP postprocess render args probe failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
            }
        }

        Installed = patched > 0;
        log.LogInfo($"HDRP postprocess render args probe installed: patched={patched}; target=DarkForeground.Render; globalTextureSnapshot={enableGlobalTextureSnapshot}; dlssEvaluate=False; getTexture=False; commandBufferWork=False");
    }

    internal static void Uninstall(ManualLogSource log)
    {
        if (!Installed || HarmonyInstance is null || HarmonyType is null)
        {
            return;
        }

        try
        {
            var unpatchSelf = FindMethodBySignature(
                HarmonyType,
                "UnpatchSelf",
                BindingFlags.Public | BindingFlags.Instance,
                Array.Empty<Type>());

            if (unpatchSelf is not null)
            {
                unpatchSelf.Invoke(HarmonyInstance, Array.Empty<object>());
            }
            else
            {
                var unpatchAll = FindMethodBySignature(
                    HarmonyType,
                    "UnpatchAll",
                    BindingFlags.Public | BindingFlags.Static,
                    new[] { typeof(string) });

                unpatchAll?.Invoke(null, new object[] { HarmonyId });
            }

            log.LogInfo("HDRP postprocess render args probe uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"HDRP postprocess render args probe uninstall failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            Installed = false;
            HarmonyInstance = null;
            HarmonyType = null;
            lock (Sync)
            {
                CallCount = 0;
                FailureCount = 0;
                GlobalTextureAdvancedLogged = false;
            }
            GlobalTextureSnapshotEnabled = false;
            UnityTimeLookupAttempted = false;
            UnityTimeFrameCountProperty = null;
            HdrpEasuInputOutputCorrelationProbeState.Reset();
        }
    }

    private static void ProbePrefix(MethodBase __originalMethod, object? __0, object? __1, object? __2, object? __3)
    {
        try
        {
            var log = Log;
            if (log is null)
            {
                return;
            }

            int count;
            lock (Sync)
            {
                CallCount++;
                count = CallCount;
            }

            var shouldLogCall = ShouldLogCall(count);
            if (!shouldLogCall && !GlobalTextureSnapshotEnabled)
            {
                return;
            }

            var hasDepthNativePointer = false;
            var hasMotionNativePointer = false;
            var depthNativePointer = IntPtr.Zero;
            var motionNativePointer = IntPtr.Zero;
            var globalTextureSummary = GlobalTextureSnapshotEnabled
                ? DescribeGlobalTextureSnapshot(out hasDepthNativePointer, out hasMotionNativePointer, out depthNativePointer, out motionNativePointer)
                : null;
            var methodLabel = HookTargetCatalog.FormatMethod(__originalMethod);
            var dlssFrameParameters = ReadDlssFrameParameters(__1);
            var cameraSummary = DescribeCamera(__1, dlssFrameParameters);
            var sourceSummary = DescribeRtHandle("source", __2);
            var destinationSummary = DescribeRtHandle("destination", __3);
            var frameCount = TryGetUnityFrameCount(out var currentFrame) ? currentFrame : -1;

            if (shouldLogCall)
            {
                log.LogInfo(
                    $"HDRP postprocess render args snapshot #{count}: " +
                    $"method={methodLabel}; " +
                    $"frame={frameCount}; " +
                    $"{DescribeCommandBuffer(__0)}; " +
                    $"{cameraSummary}; " +
                    $"{sourceSummary}; " +
                    $"{destinationSummary}" +
                    (globalTextureSummary is null ? string.Empty : $"; {globalTextureSummary}"));
            }

            if (GlobalTextureSnapshotEnabled && hasDepthNativePointer && hasMotionNativePointer)
            {
                var shouldLogAdvanced = false;
                lock (Sync)
                {
                    if (!GlobalTextureAdvancedLogged)
                    {
                        GlobalTextureAdvancedLogged = true;
                        shouldLogAdvanced = true;
                    }
                }

                HdrpEasuInputOutputCorrelationProbeState.RecordHdrpInput(
                    log,
                    new HdrpEasuInputOutputCorrelationProbeState.HdrpInputSnapshot(
                        count,
                        frameCount,
                        methodLabel,
                        cameraSummary,
                        sourceSummary,
                        destinationSummary,
                        globalTextureSummary ?? "globalTextures=unavailable",
                        depthNativePointer,
                        motionNativePointer,
                        dlssFrameParameters.JitterOffsetX,
                        dlssFrameParameters.JitterOffsetY,
                        dlssFrameParameters.PreExposure,
                        dlssFrameParameters.ResetHistory));

                if (shouldLogAdvanced)
                {
                    log.LogInfo(
                        $"HDRP postprocess render args global textures advanced: " +
                        $"method={methodLabel}; frame={frameCount}; {cameraSummary}; {sourceSummary}; {destinationSummary}; {globalTextureSummary}");
                }
            }
        }
        catch (Exception ex)
        {
            var shouldLog = false;
            lock (Sync)
            {
                FailureCount++;
                shouldLog = FailureCount <= MaxFailureLogs;
            }

            if (shouldLog)
            {
                Log?.LogWarning($"HDRP postprocess render args probe prefix failed: {GetExceptionMessage(ex)}");
            }
        }
    }

    private static string DescribeCommandBuffer(object? value)
    {
        if (value is null)
        {
            return "cmd=null";
        }

        var parts = NewObjectParts(value);
        AppendMember(parts, value, "name");
        return $"cmd={{{string.Join(", ", parts)}}}";
    }

    private static string DescribeCamera(object? value, DlssFrameParameters dlssFrameParameters)
    {
        if (value is null)
        {
            return "camera=null";
        }

        var parts = NewObjectParts(value);
        AppendMember(parts, value, "name");
        AppendMember(parts, value, "actualWidth");
        AppendMember(parts, value, "actualHeight");
        AppendMember(parts, value, "viewCount");
        AppendMember(parts, value, "isFirstFrame");
        AppendNestedUnityObject(parts, value, "camera");
        parts.Add(dlssFrameParameters.Summary);
        return $"camera={{{string.Join(", ", parts)}}}";
    }

    private static string DescribeRtHandle(string role, object? value)
    {
        if (value is null)
        {
            return $"{role}=null";
        }

        var parts = NewObjectParts(value);
        AppendMember(parts, value, "name");
        AppendMember(parts, value, "referenceSize");
        AppendMember(parts, value, "scaleFactor");
        AppendMember(parts, value, "useScaling");
        AppendMember(parts, value, "isMSAAEnabled");
        AppendMember(parts, value, "rtHandleProperties");
        AppendNestedTexture(parts, value, "rt");
        AppendNestedTexture(parts, value, "externalTexture");
        return $"{role}={{{string.Join(", ", parts)}}}";
    }

    private static string DescribeGlobalTextureSnapshot(
        out bool hasDepthNativePointer,
        out bool hasMotionNativePointer,
        out IntPtr depthNativePointer,
        out IntPtr motionNativePointer)
    {
        var depth = DescribeGlobalTexture("_CameraDepthTexture", out hasDepthNativePointer, out depthNativePointer);
        var motion = DescribeGlobalTexture("_CameraMotionVectorsTexture", out hasMotionNativePointer, out motionNativePointer);
        return $"globalTextures=[{depth}; {motion}]";
    }

    private static string DescribeGlobalTexture(string textureName, out bool hasNativePointer, out IntPtr nativePointer)
    {
        hasNativePointer = false;
        nativePointer = IntPtr.Zero;
        try
        {
            var texture = TryGetGlobalTexture(textureName);
            if (texture is null)
            {
                return $"{textureName}=null";
            }

            nativePointer = TryGetNativeTexturePtr(texture);
            hasNativePointer = nativePointer != IntPtr.Zero;
            var pointerSummary = hasNativePointer
                ? $"0x{nativePointer.ToInt64():X}"
                : "not found";
            return $"{textureName}={DescribeTextureLike(texture)}, nativePtr={pointerSummary}";
        }
        catch (Exception ex)
        {
            return $"{textureName}=<error:{Sanitize(GetExceptionMessage(ex), 96)}>";
        }
    }

    private static object? TryGetGlobalTexture(string textureName)
    {
        var shaderType = HookTargetCatalog.FindType(AppDomain.CurrentDomain.GetAssemblies(), "UnityEngine.Shader");
        if (shaderType is null)
        {
            return null;
        }

        var method = shaderType.GetMethod(
            "GetGlobalTexture",
            BindingFlags.Public | BindingFlags.Static,
            null,
            new[] { typeof(string) },
            null);
        return method?.Invoke(null, new object[] { textureName });
    }

    private static IntPtr TryGetNativeTexturePtr(object texture)
    {
        var method = texture.GetType().GetMethod(
            "GetNativeTexturePtr",
            BindingFlags.Public | BindingFlags.Instance,
            null,
            Type.EmptyTypes,
            null);
        if (method?.Invoke(texture, Array.Empty<object>()) is IntPtr pointer)
        {
            return pointer;
        }

        return IntPtr.Zero;
    }

    private static string DescribeTextureLike(object value)
    {
        var parts = NewObjectParts(value);
        AppendMember(parts, value, "name");
        AppendMember(parts, value, "width");
        AppendMember(parts, value, "height");
        AppendMember(parts, value, "graphicsFormat");
        AppendMember(parts, value, "format");
        AppendMember(parts, value, "dimension");
        AppendMember(parts, value, "volumeDepth");
        AppendMember(parts, value, "antiAliasing");
        return $"{{{string.Join(", ", parts)}}}";
    }

    private static void AppendNestedTexture(List<string> parts, object value, string memberName)
    {
        if (!TryReadMember(value, memberName, out var memberValue) || memberValue is null)
        {
            return;
        }

        parts.Add($"{memberName}={DescribeTextureLike(memberValue)}");
    }

    private static void AppendNestedUnityObject(List<string> parts, object value, string memberName)
    {
        if (!TryReadMember(value, memberName, out var memberValue) || memberValue is null)
        {
            return;
        }

        var nestedParts = NewObjectParts(memberValue);
        AppendMember(nestedParts, memberValue, "name");
        AppendMember(nestedParts, memberValue, "allowDynamicResolution");
        AppendMember(nestedParts, memberValue, "pixelWidth");
        AppendMember(nestedParts, memberValue, "pixelHeight");
        parts.Add($"{memberName}={{{string.Join(", ", nestedParts)}}}");
    }

    private static List<string> NewObjectParts(object value)
    {
        return new List<string> { $"type={FormatType(value.GetType())}" };
    }

    private static void AppendMember(List<string> parts, object value, string memberName)
    {
        try
        {
            if (TryReadMember(value, memberName, out var memberValue))
            {
                parts.Add($"{memberName}={FormatScalar(memberValue)}");
            }
        }
        catch (Exception ex)
        {
            parts.Add($"{memberName}=<error:{Sanitize(GetExceptionMessage(ex), 60)}>");
        }
    }

    private static bool TryReadMember(object value, string memberName, out object? memberValue)
    {
        var type = value.GetType();
        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;

        var property = type.GetProperties(flags)
            .FirstOrDefault(candidate =>
                candidate.Name == memberName &&
                candidate.GetIndexParameters().Length == 0 &&
                candidate.GetMethod is not null);
        if (property is not null)
        {
            memberValue = property.GetValue(value);
            return true;
        }

        var field = type.GetFields(flags).FirstOrDefault(candidate => candidate.Name == memberName);
        if (field is not null)
        {
            memberValue = field.GetValue(value);
            return true;
        }

        memberValue = null;
        return false;
    }

    private static bool TryInvokeParameterless(object value, string methodName, out object? result)
    {
        var type = value.GetType();
        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;

        var method = type.GetMethods(flags)
            .FirstOrDefault(candidate =>
                candidate.Name == methodName &&
                candidate.GetParameters().Length == 0);
        if (method is null)
        {
            result = null;
            return false;
        }

        result = method.Invoke(value, Array.Empty<object>());
        return true;
    }

    private static DlssFrameParameters ReadDlssFrameParameters(object? camera)
    {
        if (camera is null)
        {
            return DlssFrameParameters.Default;
        }

        var jitterX = 0.0f;
        var jitterY = 0.0f;
        var jitterAvailable = false;
        if (TryReadMember(camera, "taaJitter", out var jitterValue)
            && jitterValue is not null
            && TryReadVectorComponent(jitterValue, "x", out var rawJitterX)
            && TryReadVectorComponent(jitterValue, "y", out var rawJitterY))
        {
            jitterX = -rawJitterX;
            jitterY = -rawJitterY;
            jitterAvailable = true;
        }

        var preExposure = 1.0f;
        var preExposureAvailable = false;
        if (TryInvokeParameterless(camera, "GpuExposureValue", out var exposureValue)
            && TryConvertSingle(exposureValue, out var rawExposure))
        {
            preExposure = Math.Min(2.0f, Math.Max(0.35f, rawExposure));
            preExposureAvailable = true;
        }

        var resetHistory = false;
        var resetAvailable = false;
        if (TryReadMember(camera, "resetPostProcessingHistory", out var resetValue)
            && TryConvertBoolean(resetValue, out resetHistory))
        {
            resetAvailable = true;
        }

        return new DlssFrameParameters(
            jitterX,
            jitterY,
            preExposure,
            resetHistory,
            jitterAvailable,
            preExposureAvailable,
            resetAvailable);
    }

    private static bool TryReadVectorComponent(object value, string memberName, out float result)
    {
        result = 0.0f;
        return TryReadMember(value, memberName, out var component)
            && TryConvertSingle(component, out result);
    }

    private static bool TryConvertSingle(object? value, out float result)
    {
        result = 0.0f;
        if (value is null)
        {
            return false;
        }

        try
        {
            result = Convert.ToSingle(value, CultureInfo.InvariantCulture);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool TryConvertBoolean(object? value, out bool result)
    {
        result = false;
        if (value is bool typed)
        {
            result = typed;
            return true;
        }

        if (value is null)
        {
            return false;
        }

        return bool.TryParse(value.ToString(), out result);
    }

    private static string FormatScalar(object? value)
    {
        if (value is null)
        {
            return "null";
        }

        var type = value.GetType();
        if (value is string text)
        {
            return $"\"{Sanitize(text, 96)}\"";
        }

        if (type.IsPrimitive || type.IsEnum || value is decimal)
        {
            return Sanitize(Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture) ?? string.Empty, 96);
        }

        if (type.IsValueType)
        {
            return Sanitize(value.ToString() ?? string.Empty, 120);
        }

        return FormatType(type);
    }

    private static string Sanitize(string text, int maxLength)
    {
        var compact = text.Replace("\r", " ").Replace("\n", " ").Trim();
        return compact.Length <= maxLength
            ? compact
            : compact[..maxLength] + "...";
    }

    private static string FormatType(Type type)
    {
        return (type.FullName ?? type.Name).Replace('+', '.');
    }

    private static bool ShouldLogCall(int count)
    {
        return count <= 5
            || count == 10
            || count == 30
            || count == 100
            || count == 300;
    }

    private static bool TryGetUnityFrameCount(out int frameCount)
    {
        frameCount = 0;
        try
        {
            if (!UnityTimeLookupAttempted)
            {
                UnityTimeLookupAttempted = true;
                UnityTimeFrameCountProperty = AppDomain.CurrentDomain.GetAssemblies()
                    .Select(assembly => assembly.GetType("UnityEngine.Time", throwOnError: false))
                    .FirstOrDefault(type => type is not null)
                    ?.GetProperty("frameCount", BindingFlags.Public | BindingFlags.Static);
            }

            var value = UnityTimeFrameCountProperty?.GetValue(null);
            if (value is int intValue)
            {
                frameCount = intValue;
                return true;
            }

            return value is not null && int.TryParse(value.ToString(), out frameCount);
        }
        catch
        {
            return false;
        }
    }

    private static bool CanPatch(MethodInfo method)
    {
        return !method.ContainsGenericParameters
            && !method.IsAbstract
            && method.DeclaringType is not null;
    }

    private static bool IsPostProcessRenderSignature(MethodInfo method)
    {
        var parameters = method.GetParameters();
        return parameters.Length == 4
            && ParameterTypeMatches(parameters[0], "CommandBuffer")
            && ParameterTypeMatches(parameters[1], "HDCamera")
            && ParameterTypeMatches(parameters[2], "RTHandle")
            && ParameterTypeMatches(parameters[3], "RTHandle");
    }

    private static bool ParameterTypeMatches(ParameterInfo parameter, string shortName)
    {
        var type = parameter.ParameterType;
        var name = type.FullName ?? type.Name;
        return string.Equals(type.Name, shortName, StringComparison.Ordinal)
            || string.Equals(name, shortName, StringComparison.Ordinal)
            || name.EndsWith("." + shortName, StringComparison.Ordinal);
    }

    private static Type? FindRuntimeType(IEnumerable<Assembly> assemblies, string fullName)
    {
        foreach (var assembly in assemblies)
        {
            var type = assembly.GetType(fullName, throwOnError: false);
            if (type is not null)
            {
                return type;
            }
        }

        return null;
    }

    private static MethodInfo? FindPatchMethod(Type harmonyType)
    {
        return harmonyType.GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .Where(method => method.Name == "Patch")
            .Where(method =>
            {
                var parameters = method.GetParameters();
                return parameters.Length >= 2
                    && typeof(MethodBase).IsAssignableFrom(parameters[0].ParameterType)
                    && parameters[1].ParameterType.FullName == "HarmonyLib.HarmonyMethod";
            })
            .OrderBy(method => method.GetParameters().Length)
            .FirstOrDefault();
    }

    private static MethodInfo? FindMethodBySignature(Type type, string name, BindingFlags flags, IReadOnlyList<Type> parameterTypes)
    {
        return type.GetMethods(flags)
            .FirstOrDefault(method =>
            {
                if (method.Name != name)
                {
                    return false;
                }

                var parameters = method.GetParameters();
                if (parameters.Length != parameterTypes.Count)
                {
                    return false;
                }

                for (var index = 0; index < parameters.Length; index++)
                {
                    if (parameters[index].ParameterType != parameterTypes[index])
                    {
                        return false;
                    }
                }

                return true;
            });
    }

    private static string GetExceptionMessage(Exception ex)
    {
        return ex is TargetInvocationException { InnerException: not null }
            ? ex.InnerException.Message
            : ex.Message;
    }

    private readonly record struct DlssFrameParameters(
        float JitterOffsetX,
        float JitterOffsetY,
        float PreExposure,
        bool ResetHistory,
        bool JitterAvailable,
        bool PreExposureAvailable,
        bool ResetHistoryAvailable)
    {
        internal static DlssFrameParameters Default { get; } = new(
            0.0f,
            0.0f,
            1.0f,
            false,
            false,
            false,
            false);

        internal string Summary =>
            string.Format(
                CultureInfo.InvariantCulture,
                "dlssFrameParams=jitter=({0:0.####},{1:0.####}),preExposure={2:0.####},resetHistory={3},available=(jitter:{4},preExposure:{5},reset:{6})",
                JitterOffsetX,
                JitterOffsetY,
                PreExposure,
                ResetHistory,
                JitterAvailable,
                PreExposureAvailable,
                ResetHistoryAvailable);
    }
}
