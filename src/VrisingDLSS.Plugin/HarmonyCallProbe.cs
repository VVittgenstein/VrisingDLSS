using BepInEx.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class HarmonyCallProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".readonly-call-probe";
    private const int MaxInitialLogsPerMethod = 3;
    private static readonly object Sync = new();
    private static readonly Dictionary<string, int> CallCounts = new(StringComparer.Ordinal);

    private static ManualLogSource? Log;
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static bool Installed;

    internal static void Install(ManualLogSource log)
    {
        if (Installed)
        {
            log.LogInfo("Read-only Harmony call probe is already installed.");
            return;
        }

        Log = log;

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var harmonyType = FindRuntimeType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = FindRuntimeType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            log.LogWarning("Harmony runtime was not found. Install/verify BepInEx before enabling EnableHarmonyCallProbe.");
            return;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var prefix = typeof(HarmonyCallProbe).GetMethod(nameof(ProbePrefix), BindingFlags.NonPublic | BindingFlags.Static);
        var patchMethod = FindPatchMethod(harmonyType);

        if (harmonyConstructor is null || harmonyMethodConstructor is null || prefix is null || patchMethod is null)
        {
            log.LogWarning("Harmony runtime shape was not recognized. Read-only call probe cannot be installed.");
            return;
        }

        HarmonyInstance = harmonyConstructor.Invoke(new object[] { HarmonyId });
        HarmonyType = harmonyType;

        var patched = 0;
        foreach (var target in HookTargetCatalog.Targets)
        {
            var type = HookTargetCatalog.FindType(assemblies, target.TypeName);
            if (type is null)
            {
                log.LogWarning($"Harmony probe target type not found: {target.TypeName}");
                continue;
            }

            foreach (var memberName in target.MemberNames)
            {
                foreach (var method in HookTargetCatalog.FindMethods(type, memberName))
                {
                    if (!CanPatch(method))
                    {
                        log.LogWarning($"Harmony probe skipped unsupported method: {HookTargetCatalog.FormatMethod(method)}");
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
                        log.LogInfo($"Harmony probe patched: {HookTargetCatalog.FormatMethod(method)}");
                    }
                    catch (Exception ex)
                    {
                        log.LogWarning($"Harmony probe failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
                    }
                }
            }
        }

        Installed = patched > 0;
        log.LogInfo($"Read-only Harmony call probe patched {patched} method(s).");
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

            log.LogInfo("Read-only Harmony call probe uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"Read-only Harmony call probe uninstall failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            Installed = false;
            HarmonyInstance = null;
            HarmonyType = null;
            lock (Sync)
            {
                CallCounts.Clear();
            }
        }
    }

    private static void ProbePrefix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        try
        {
            var log = Log;
            if (log is null)
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

            if (!ShouldLogCall(count))
            {
                return;
            }

            var instanceSummary = SummarizeValue(__instance);
            var argsSummary = __args is null || __args.Length == 0
                ? "args=[]"
                : $"args=[{string.Join("; ", __args.Select(SummarizeValue))}]";

            log.LogInfo($"Harmony probe call #{count}: {key}; instance={instanceSummary}; {argsSummary}");
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"Harmony probe prefix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static bool ShouldLogCall(int count)
    {
        return count <= MaxInitialLogsPerMethod
            || count == 10
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
            "pixelWidth",
            "pixelHeight",
            "graphicsFormat",
            "colorFormat",
            "dimension",
            "nearClipPlane",
            "farClipPlane",
            "fieldOfView"
        })
        {
            var propertyValue = TryReadProperty(value, propertyName);
            if (propertyValue is not null)
            {
                parts.Add($"{propertyName}={propertyValue}");
            }
        }

        return string.Join(" ", parts);
    }

    private static string? TryReadProperty(object instance, string propertyName)
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

            var value = property.GetValue(instance);
            return value?.ToString();
        }
        catch
        {
            return null;
        }
    }

    private static string GetExceptionMessage(Exception ex)
    {
        return ex is TargetInvocationException { InnerException: not null }
            ? ex.InnerException.Message
            : ex.Message;
    }
}
