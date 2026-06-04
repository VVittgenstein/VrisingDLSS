using BepInEx.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace VrisingDLSS.Plugin;

internal static class FrameResourceProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".frame-resource-probe";
    private const int MaxInitialLogsPerMethod = 5;
    private const int MaxTextureSearchDepth = 3;
    private static readonly FrameProbeTarget[] Targets =
    {
        new("UnityEngine.Rendering.HighDefinition.CustomVignette", "Render"),
        new("UnityEngine.Rendering.HighDefinition.HDRenderPipeline", "UpdateShaderVariablesGlobalCB")
    };
    private static readonly object Sync = new();
    private static readonly Dictionary<string, int> CallCounts = new(StringComparer.Ordinal);
    private static readonly string[] GlobalTextureNames =
    {
        "_CameraDepthTexture",
        "_CameraMotionVectorsTexture"
    };

    private static ManualLogSource? Log;
    private static NativeBridge? Bridge;
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static bool Installed;
    private static bool DlssEvaluateInputProbeEnabled;
    private static bool DlssEvaluateInputProbeSucceeded;

    internal static void Install(ManualLogSource log, NativeBridge bridge, bool enableDlssEvaluateInputProbe = false)
    {
        if (Installed)
        {
            log.LogInfo("Frame resource probe is already installed.");
            DlssEvaluateInputProbeEnabled = DlssEvaluateInputProbeEnabled || enableDlssEvaluateInputProbe;
            return;
        }

        Log = log;
        Bridge = bridge;
        DlssEvaluateInputProbeEnabled = enableDlssEvaluateInputProbe;
        DlssEvaluateInputProbeSucceeded = false;
        if (DlssEvaluateInputProbeEnabled)
        {
            log.LogInfo("DLSS evaluate input probe enabled.");
        }

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var harmonyType = FindRuntimeType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = FindRuntimeType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            log.LogWarning("Harmony runtime was not found. Install/verify BepInEx before enabling EnableFrameResourceProbe.");
            return;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var prefix = typeof(FrameResourceProbe).GetMethod(nameof(ProbePrefix), BindingFlags.NonPublic | BindingFlags.Static);
        var patchMethod = FindPatchMethod(harmonyType);

        if (harmonyConstructor is null || harmonyMethodConstructor is null || prefix is null || patchMethod is null)
        {
            log.LogWarning("Harmony runtime shape was not recognized. Frame resource probe cannot be installed.");
            return;
        }

        HarmonyInstance = harmonyConstructor.Invoke(new object[] { HarmonyId });
        HarmonyType = harmonyType;

        var patched = 0;
        var patchedMethodKeys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var target in Targets)
        {
            var targetType = HookTargetCatalog.FindType(assemblies, target.TypeName);
            if (targetType is null)
            {
                log.LogWarning($"Frame resource probe target type not found: {target.TypeName}");
                continue;
            }

            foreach (var method in HookTargetCatalog.FindMethods(targetType, target.MemberName))
            {
                if (TryPatchFrameResourceMethod(
                    log,
                    method,
                    harmonyMethodConstructor,
                    patchMethod,
                    prefix,
                    patchedMethodKeys,
                    "Frame resource probe"))
                {
                    patched++;
                }
            }
        }

        if (DlssEvaluateInputProbeEnabled)
        {
            var extendedPatched = 0;
            foreach (var method in DiscoverExtendedFrameResourceMethods(assemblies))
            {
                if (TryPatchFrameResourceMethod(
                    log,
                    method,
                    harmonyMethodConstructor,
                    patchMethod,
                    prefix,
                    patchedMethodKeys,
                    "Frame resource extended candidate"))
                {
                    patched++;
                    extendedPatched++;
                }
            }

            log.LogInfo($"Frame resource extended candidate probe patched {extendedPatched} method(s).");
        }

        Installed = patched > 0;
        log.LogInfo($"Frame resource probe patched {patched} method(s).");
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

            log.LogInfo("Frame resource probe uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"Frame resource probe uninstall failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            Installed = false;
            HarmonyInstance = null;
            HarmonyType = null;
            Log = null;
            Bridge = null;
            DlssEvaluateInputProbeEnabled = false;
            DlssEvaluateInputProbeSucceeded = false;
            lock (Sync)
            {
                CallCounts.Clear();
            }
        }
    }

    private static bool TryPatchFrameResourceMethod(
        ManualLogSource log,
        MethodInfo method,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        MethodInfo prefix,
        ISet<string> patchedMethodKeys,
        string logPrefix)
    {
        if (!CanPatch(method))
        {
            log.LogWarning($"{logPrefix} skipped unsupported method: {HookTargetCatalog.FormatMethod(method)}");
            return false;
        }

        if (!patchedMethodKeys.Add(GetMethodKey(method)))
        {
            return false;
        }

        try
        {
            var prefixPatch = harmonyMethodConstructor.Invoke(new object[] { prefix });
            var arguments = new object?[patchMethod.GetParameters().Length];
            arguments[0] = method;
            arguments[1] = prefixPatch;
            patchMethod.Invoke(HarmonyInstance, arguments);
            log.LogInfo($"{logPrefix} patched: {HookTargetCatalog.FormatMethod(method)}");
            return true;
        }
        catch (Exception ex)
        {
            log.LogWarning($"{logPrefix} failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
            return false;
        }
    }

    private static IEnumerable<MethodInfo> DiscoverExtendedFrameResourceMethods(IEnumerable<Assembly> assemblies)
    {
        foreach (var assembly in assemblies)
        {
            if (!IsExtendedProbeAssembly(assembly))
            {
                continue;
            }

            foreach (var type in SafeGetTypes(assembly))
            {
                foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                {
                    if (IsExtendedFrameResourceMethod(method))
                    {
                        yield return method;
                    }
                }
            }
        }
    }

    private static bool IsExtendedProbeAssembly(Assembly assembly)
    {
        var name = assembly.GetName().Name ?? string.Empty;
        return name.Equals("Unity.RenderPipelines.HighDefinition.Runtime", StringComparison.Ordinal)
            || name.Equals("ProjectM", StringComparison.Ordinal)
            || name.Equals("ProjectM.Camera", StringComparison.Ordinal)
            || name.Equals("ProjectM.Presentation.Systems", StringComparison.Ordinal);
    }

    private static bool IsExtendedFrameResourceMethod(MethodInfo method)
    {
        if (!string.Equals(method.Name, "Render", StringComparison.Ordinal))
        {
            return false;
        }

        var parameters = method.GetParameters();
        return parameters.Any(parameter => TypeNameContains(parameter.ParameterType, "CommandBuffer"))
            && parameters.Any(parameter => TypeNameContains(parameter.ParameterType, "HDCamera"))
            && parameters.Count(parameter => TypeNameContains(parameter.ParameterType, "RTHandle")) >= 2;
    }

    private static string GetMethodKey(MethodInfo method)
    {
        return $"{method.Module.ModuleVersionId:N}:{method.MetadataToken}";
    }

    private static bool TypeNameContains(Type type, string value)
    {
        var name = type.FullName ?? type.Name;
        return name.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static void ProbePrefix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        try
        {
            var log = Log;
            var bridge = Bridge;
            if (log is null || bridge is null)
            {
                return;
            }

            var key = HookTargetCatalog.FormatMethod(__originalMethod);
            int count;
            lock (Sync)
            {
                CallCounts.TryGetValue(key, out count);
                count++;
                CallCounts[key] = count;
            }

            if (!ShouldInspect(count))
            {
                return;
            }

            log.LogInfo($"Frame resource probe call #{count}: {key}");
            if (__args is not null)
            {
                for (var index = 0; index < __args.Length; index++)
                {
                    ProbeTextureCandidate(log, bridge, $"arg{index}", __args[index]);
                }
            }

            foreach (var globalTextureName in GlobalTextureNames)
            {
                var texture = TryGetGlobalTexture(globalTextureName);
                ProbeTextureCandidate(log, bridge, $"global:{globalTextureName}", texture);
            }

            TryRunDlssEvaluateInputProbe(log, bridge, __originalMethod, __args);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"Frame resource probe prefix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void TryRunDlssEvaluateInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        MethodBase originalMethod,
        object?[]? args)
    {
        if (!DlssEvaluateInputProbeEnabled || DlssEvaluateInputProbeSucceeded)
        {
            return;
        }

        var methodLabel = HookTargetCatalog.FormatMethod(originalMethod);
        var argumentTextures = CollectArgumentTextureCandidates(originalMethod, args);
        if (argumentTextures.Count < 2)
        {
            log.LogWarning($"DLSS evaluate input probe blocked: {methodLabel} did not expose two texture-like source/output arguments.");
            return;
        }

        if (!TryGetGlobalNativeTexture("_CameraDepthTexture", out var depthTexture))
        {
            log.LogWarning($"DLSS evaluate input probe blocked: {methodLabel} did not expose global _CameraDepthTexture.");
            return;
        }

        if (!TryGetGlobalNativeTexture("_CameraMotionVectorsTexture", out var motionTexture))
        {
            log.LogWarning($"DLSS evaluate input probe blocked: {methodLabel} did not expose global _CameraMotionVectorsTexture.");
            return;
        }

        var colorTexture = argumentTextures[0];
        var outputTexture = argumentTextures[1];
        log.LogInfo(
            $"DLSS evaluate input probe candidate: color={colorTexture.Label} 0x{colorTexture.Pointer.ToInt64():X}; output={outputTexture.Label} 0x{outputTexture.Pointer.ToInt64():X}; depth=0x{depthTexture.Pointer.ToInt64():X}; motion=0x{motionTexture.Pointer.ToInt64():X}");

        var success = bridge.ProbeDlssEvaluateInputs(
            colorTexture.Pointer,
            outputTexture.Pointer,
            depthTexture.Pointer,
            motionTexture.Pointer);
        var status = bridge.GetDlssEvaluateInputStatus();
        if (success)
        {
            DlssEvaluateInputProbeSucceeded = true;
            log.LogInfo($"DLSS evaluate input probe succeeded: {status}");
        }
        else
        {
            log.LogWarning($"DLSS evaluate input probe failed: {status}");
        }
    }

    private static IReadOnlyList<NativeTextureCandidate> CollectArgumentTextureCandidates(MethodBase originalMethod, object?[]? args)
    {
        var candidates = new List<NativeTextureCandidate>();
        if (args is null)
        {
            return candidates;
        }

        var parameters = originalMethod.GetParameters();
        for (var index = 0; index < args.Length; index++)
        {
            var arg = args[index];
            if (arg is null)
            {
                continue;
            }

            if (!TryFindNativeTexturePtr(arg, out _, out var pointer) || pointer == IntPtr.Zero)
            {
                continue;
            }

            var parameterName = index < parameters.Length && !string.IsNullOrWhiteSpace(parameters[index].Name)
                ? parameters[index].Name!
                : $"arg{index}";
            candidates.Add(new NativeTextureCandidate(parameterName, pointer));
        }

        return candidates;
    }

    private static bool TryGetGlobalNativeTexture(string textureName, out NativeTextureCandidate candidate)
    {
        candidate = default;
        var texture = TryGetGlobalTexture(textureName);
        if (texture is null)
        {
            return false;
        }

        if (!TryFindNativeTexturePtr(texture, out _, out var pointer) || pointer == IntPtr.Zero)
        {
            return false;
        }

        candidate = new NativeTextureCandidate(textureName, pointer);
        return true;
    }

    private static void ProbeTextureCandidate(ManualLogSource log, NativeBridge bridge, string label, object? candidate)
    {
        if (candidate is null)
        {
            log.LogInfo($"Frame resource {label}: null");
            return;
        }

        var summary = SummarizeValue(candidate);
        if (!TryFindNativeTexturePtr(candidate, out var owner, out var pointer))
        {
            log.LogInfo($"Frame resource {label}: {summary}; nativePtr=not found");
            return;
        }

        var ownerSummary = owner is null ? "unknown" : SummarizeValue(owner);
        log.LogInfo($"Frame resource {label}: {summary}; nativeOwner={ownerSummary}; nativePtr=0x{pointer.ToInt64():X}");
        if (pointer == IntPtr.Zero)
        {
            log.LogWarning($"Frame resource {label}: native pointer is null.");
            return;
        }

        var success = bridge.ProbeD3D11Texture(pointer);
        var status = bridge.GetD3D11ProbeStatus();
        if (success)
        {
            log.LogInfo($"Frame resource {label}: D3D11 probe succeeded: {status}");
        }
        else
        {
            log.LogWarning($"Frame resource {label}: D3D11 probe failed: {status}");
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

    private static bool TryFindNativeTexturePtr(object candidate, out object? owner, out IntPtr pointer)
    {
        var visited = new HashSet<int>();
        return TryFindNativeTexturePtr(candidate, 0, visited, out owner, out pointer);
    }

    private static bool TryFindNativeTexturePtr(
        object? candidate,
        int depth,
        ISet<int> visited,
        out object? owner,
        out IntPtr pointer)
    {
        owner = null;
        pointer = IntPtr.Zero;
        if (candidate is null || depth > MaxTextureSearchDepth || IsTerminalValue(candidate))
        {
            return false;
        }

        var identity = RuntimeHelpers.GetHashCode(candidate);
        if (!visited.Add(identity))
        {
            return false;
        }

        var nativePointer = TryGetNativeTexturePtr(candidate);
        if (nativePointer.HasValue)
        {
            owner = candidate;
            pointer = nativePointer.Value;
            return true;
        }

        foreach (var nested in EnumerateLikelyTextureMembers(candidate))
        {
            if (TryFindNativeTexturePtr(nested, depth + 1, visited, out owner, out pointer))
            {
                return true;
            }
        }

        return false;
    }

    private static IntPtr? TryGetNativeTexturePtr(object candidate)
    {
        try
        {
            var method = candidate.GetType().GetMethod(
                "GetNativeTexturePtr",
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
                null,
                Type.EmptyTypes,
                null);

            var value = method?.Invoke(candidate, Array.Empty<object>());
            return value is IntPtr pointer ? pointer : null;
        }
        catch
        {
            return null;
        }
    }

    private static IEnumerable<object?> EnumerateLikelyTextureMembers(object candidate)
    {
        var type = candidate.GetType();
        foreach (var propertyName in new[]
        {
            "rt",
            "RT",
            "renderTexture",
            "texture",
            "targetTexture",
            "m_RT",
            "m_Texture",
            "m_RenderTexture"
        })
        {
            var value = TryReadPropertyObject(candidate, propertyName);
            if (value is not null)
            {
                yield return value;
            }
        }

        foreach (var property in type.GetProperties(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            if (property.GetIndexParameters().Length != 0 || property.GetMethod is null)
            {
                continue;
            }

            if (!NameLooksTextureLike(property.Name) && !TypeLooksTextureLike(property.PropertyType))
            {
                continue;
            }

            object? value;
            try
            {
                value = property.GetValue(candidate);
            }
            catch
            {
                continue;
            }

            if (value is not null)
            {
                yield return value;
            }
        }

        foreach (var field in type.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            if (!NameLooksTextureLike(field.Name) && !TypeLooksTextureLike(field.FieldType))
            {
                continue;
            }

            object? value;
            try
            {
                value = field.GetValue(candidate);
            }
            catch
            {
                continue;
            }

            if (value is not null)
            {
                yield return value;
            }
        }
    }

    private static bool NameLooksTextureLike(string name)
    {
        return name.IndexOf("texture", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("render", StringComparison.OrdinalIgnoreCase) >= 0
            || string.Equals(name, "rt", StringComparison.OrdinalIgnoreCase);
    }

    private static bool TypeLooksTextureLike(Type type)
    {
        var fullName = type.FullName ?? type.Name;
        return fullName.IndexOf("Texture", StringComparison.OrdinalIgnoreCase) >= 0
            || fullName.IndexOf("RTHandle", StringComparison.OrdinalIgnoreCase) >= 0
            || fullName.IndexOf("RenderTarget", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static bool IsTerminalValue(object value)
    {
        var type = value.GetType();
        return type.IsPrimitive
            || type.IsEnum
            || type == typeof(string)
            || type == typeof(decimal)
            || type == typeof(IntPtr)
            || type == typeof(UIntPtr);
    }

    private static bool ShouldInspect(int count)
    {
        return count <= MaxInitialLogsPerMethod
            || count == 30
            || count == 100
            || count % 300 == 0;
    }

    private static bool CanPatch(MethodInfo method)
    {
        return !method.ContainsGenericParameters
            && !method.IsAbstract
            && method.DeclaringType is not null;
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

    private static IEnumerable<Type> SafeGetTypes(Assembly assembly)
    {
        try
        {
            return assembly.GetTypes();
        }
        catch (ReflectionTypeLoadException ex)
        {
            return ex.Types.Where(type => type is not null).Cast<Type>();
        }
        catch
        {
            return Array.Empty<Type>();
        }
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

    private static string SummarizeValue(object? value)
    {
        if (value is null)
        {
            return "null";
        }

        var type = value.GetType();
        var parts = new List<string> { type.FullName ?? type.Name };

        foreach (var propertyName in new[]
        {
            "name",
            "width",
            "height",
            "actualWidth",
            "actualHeight",
            "rtHandleProperties",
            "graphicsFormat",
            "colorFormat",
            "dimension"
        })
        {
            var propertyValue = TryReadPropertyString(value, propertyName);
            if (propertyValue is not null)
            {
                parts.Add($"{propertyName}={propertyValue}");
            }
        }

        return string.Join(" ", parts);
    }

    private static object? TryReadPropertyObject(object instance, string propertyName)
    {
        try
        {
            var property = instance.GetType().GetProperty(
                propertyName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);

            if (property is null || property.GetIndexParameters().Length != 0 || property.GetMethod is null)
            {
                return null;
            }

            return property.GetValue(instance);
        }
        catch
        {
            return null;
        }
    }

    private static string? TryReadPropertyString(object instance, string propertyName)
    {
        var value = TryReadPropertyObject(instance, propertyName);
        return value?.ToString();
    }

    private static string GetExceptionMessage(Exception ex)
    {
        return ex is TargetInvocationException { InnerException: not null }
            ? ex.InnerException.Message
            : ex.Message;
    }

    private readonly record struct FrameProbeTarget(string TypeName, string MemberName);

    private readonly record struct NativeTextureCandidate(string Label, IntPtr Pointer);
}
