using BepInEx.Logging;
using System;
using System.Collections.Generic;
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

    private static ManualLogSource? Log;
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static bool Installed;

    internal static void Install(ManualLogSource log)
    {
        if (Installed)
        {
            log.LogInfo("HDRP postprocess render args probe is already installed.");
            return;
        }

        Log = log;

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
        log.LogInfo($"HDRP postprocess render args probe installed: patched={patched}; target=DarkForeground.Render; native=False; dlssEvaluate=False; getTexture=False; commandBufferWork=False");
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
            }
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

            if (!ShouldLogCall(count))
            {
                return;
            }

            log.LogInfo(
                $"HDRP postprocess render args snapshot #{count}: " +
                $"method={HookTargetCatalog.FormatMethod(__originalMethod)}; " +
                $"{DescribeCommandBuffer(__0)}; " +
                $"{DescribeCamera(__1)}; " +
                $"{DescribeRtHandle("source", __2)}; " +
                $"{DescribeRtHandle("destination", __3)}");
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

    private static string DescribeCamera(object? value)
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
}
