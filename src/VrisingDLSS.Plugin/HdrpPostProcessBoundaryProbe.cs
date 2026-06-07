using BepInEx.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class HdrpPostProcessBoundaryProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".hdrp-postprocess-boundary-probe";
    private const int MaxInitialLogsPerMethod = 5;

    private static readonly BoundaryTarget[] Targets =
    {
        new("CustomVignette", new[] { "Render" }, Optional: true),
        new("LineOfSightVision", new[] { "Render" }, Optional: true),
        new("LineOfSight", new[] { "Render" }, Optional: true),
        new("BatFormFog", new[] { "Render" }, Optional: true),
        new("DarkForeground", new[] { "Render" }, Optional: true),
        new("ProjectM.ContestAreaEffect", new[] { "Render" }, Optional: true)
    };

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
            log.LogInfo("HDRP postprocess boundary probe is already installed.");
            return;
        }

        Log = log;

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var harmonyType = FindRuntimeType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = FindRuntimeType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            log.LogWarning("HDRP postprocess boundary probe blocked: Harmony runtime was not found.");
            return;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var prefix = typeof(HdrpPostProcessBoundaryProbe).GetMethod(nameof(ProbePrefix), BindingFlags.NonPublic | BindingFlags.Static);
        var patchMethod = FindPatchMethod(harmonyType);

        if (harmonyConstructor is null || harmonyMethodConstructor is null || prefix is null || patchMethod is null)
        {
            log.LogWarning("HDRP postprocess boundary probe blocked: Harmony runtime shape was not recognized.");
            return;
        }

        HarmonyInstance = harmonyConstructor.Invoke(new object[] { HarmonyId });
        HarmonyType = harmonyType;

        var patched = 0;
        foreach (var target in Targets)
        {
            var type = HookTargetCatalog.FindType(assemblies, target.TypeName);
            if (type is null)
            {
                var message = $"HDRP postprocess boundary probe target type not found: {target.TypeName}";
                if (target.Optional)
                {
                    log.LogInfo($"{message} (optional)");
                }
                else
                {
                    log.LogWarning(message);
                }

                continue;
            }

            foreach (var memberName in target.MemberNames)
            {
                var methods = HookTargetCatalog.FindMethods(type, memberName);
                if (methods.Count == 0)
                {
                    log.LogInfo($"HDRP postprocess boundary probe target method not found: {type.FullName}.{memberName}");
                    continue;
                }

                foreach (var method in methods)
                {
                    if (!CanPatch(method))
                    {
                        log.LogWarning($"HDRP postprocess boundary probe skipped unsupported method: {HookTargetCatalog.FormatMethod(method)}");
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
                        log.LogInfo($"HDRP postprocess boundary probe patched: {HookTargetCatalog.FormatMethod(method)}");
                    }
                    catch (Exception ex)
                    {
                        log.LogWarning($"HDRP postprocess boundary probe failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
                    }
                }
            }
        }

        Installed = patched > 0;
        log.LogInfo($"HDRP postprocess boundary probe installed: patched={patched}; targetSet=ProjectMCustomPostProcessRender; native=False; dlssEvaluate=False; getTexture=False; commandBufferWork=False");
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

            log.LogInfo("HDRP postprocess boundary probe uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"HDRP postprocess boundary probe uninstall failed: {GetExceptionMessage(ex)}");
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

    private static void ProbePrefix(MethodBase __originalMethod)
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

            var role = ClassifyBoundary(__originalMethod);
            log.LogInfo($"HDRP postprocess boundary probe call #{count}: role={role}; method={key}");
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"HDRP postprocess boundary probe prefix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static string ClassifyBoundary(MethodBase method)
    {
        var typeName = method.DeclaringType?.FullName ?? method.DeclaringType?.Name ?? string.Empty;
        if (string.Equals(typeName, "UnityEngine.Rendering.HighDefinition.HDRenderPipeline", StringComparison.Ordinal))
        {
            return method.Name switch
            {
                "RenderPostProcess" => "HDRP.RenderPostProcess",
                "DoDLSSPasses" => "HDRP.DoDLSSPasses",
                "DoDLSSPass" => "HDRP.DoDLSSPass",
                "CustomPostProcessPass" => "HDRP.CustomPostProcessPass",
                _ => "HDRP"
            };
        }

        return method.Name == "Render"
            ? "ProjectM.CustomPostProcess.Render"
            : "ProjectM.CustomPostProcess";
    }

    private static bool ShouldLogCall(int count)
    {
        return count <= MaxInitialLogsPerMethod
            || count == 10
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

    private readonly record struct BoundaryTarget(string TypeName, IReadOnlyList<string> MemberNames, bool Optional = false);
}
