using BepInEx.Logging;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class UpscalerStateProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".upscaler-state-probe";
    private const int MaxCallLogs = 40;
    private static readonly object Sync = new();
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static ManualLogSource? Log;
    private static bool Installed;
    private static int CallCount;
    [ThreadStatic]
    private static bool InPostfix;

    internal static void Install(ManualLogSource log)
    {
        if (Installed)
        {
            log.LogInfo("Upscaler state probe is already installed.");
            return;
        }

        Log = log;
        log.LogInfo("Running read-only HDRP upscaler state probe.");

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        LogSnapshot(log, "install", assemblies);

        var harmonyType = HookTargetCatalog.FindType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = HookTargetCatalog.FindType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            log.LogWarning("Harmony runtime was not found. Upscaler state probe cannot patch runtime setters.");
            return;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var patchMethod = FindPatchMethod(harmonyType);
        var postfix = typeof(UpscalerStateProbe).GetMethod(nameof(ProbePostfix), BindingFlags.NonPublic | BindingFlags.Static);

        if (harmonyConstructor is null || harmonyMethodConstructor is null || patchMethod is null || postfix is null)
        {
            log.LogWarning("Harmony runtime shape was not recognized. Upscaler state probe cannot patch runtime setters.");
            return;
        }

        HarmonyInstance = harmonyConstructor.Invoke(new object[] { HarmonyId });
        HarmonyType = harmonyType;

        var patched = 0;
        var patchedMethodKeys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var method in DiscoverUpscalerStateMethods(assemblies))
        {
            if (TryPatchPostfixMethod(log, method, harmonyMethodConstructor, patchMethod, postfix, patchedMethodKeys))
            {
                patched++;
            }
        }

        Installed = patched > 0;
        log.LogInfo($"Upscaler state probe patched {patched} method(s).");
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

            log.LogInfo("Upscaler state probe uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"Upscaler state probe uninstall failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            Installed = false;
            HarmonyInstance = null;
            HarmonyType = null;
            Log = null;
            lock (Sync)
            {
                CallCount = 0;
            }
        }
    }

    private static IEnumerable<MethodInfo> DiscoverUpscalerStateMethods(IEnumerable<Assembly> assemblies)
    {
        foreach (var target in new[]
        {
            new UpscalerProbeTarget("UnityEngine.Rendering.HighDefinition.HDRenderPipeline", new[]
            {
                "SetFSRParameters",
                "SetUpscaleFilter",
                "SetupDLSSForCameraDataAndDynamicResHandler"
            }),
            new UpscalerProbeTarget("UnityEngine.Rendering.DynamicResolutionHandler", new[]
            {
                "SetDynamicResScaler",
                "SetSystemDynamicResScaler",
                "SetActiveDynamicScalerSlot",
                "SetUpscaleFilter"
            }),
            new UpscalerProbeTarget("UnityEngine.Rendering.HighDefinition.HDCamera", new[]
            {
                "RequestDynamicResolution",
                "IsDLSSEnabled",
                "UpsampleSyncPoint"
            })
        })
        {
            var type = HookTargetCatalog.FindType(assemblies, target.TypeName);
            if (type is null)
            {
                Log?.LogInfo($"Upscaler state target type not found: {target.TypeName} (optional)");
                continue;
            }

            foreach (var memberName in target.MemberNames)
            {
                foreach (var method in HookTargetCatalog.FindMethods(type, memberName))
                {
                    if (CanPatch(method))
                    {
                        yield return method;
                    }
                }
            }
        }
    }

    private static bool TryPatchPostfixMethod(
        ManualLogSource log,
        MethodInfo method,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        MethodInfo postfix,
        ISet<string> patchedMethodKeys)
    {
        if (!patchedMethodKeys.Add(GetMethodKey(method)))
        {
            return false;
        }

        try
        {
            var postfixPatch = harmonyMethodConstructor.Invoke(new object[] { postfix });
            var arguments = new object?[patchMethod.GetParameters().Length];
            arguments[0] = method;
            if (arguments.Length > 2)
            {
                arguments[2] = postfixPatch;
            }
            else
            {
                log.LogWarning("Harmony Patch overload does not expose a postfix argument.");
                return false;
            }

            patchMethod.Invoke(HarmonyInstance, arguments);
            log.LogInfo($"Upscaler state probe patched: {HookTargetCatalog.FormatMethod(method)}");
            return true;
        }
        catch (Exception ex)
        {
            log.LogWarning($"Upscaler state probe failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
            return false;
        }
    }

    private static void ProbePostfix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        if (InPostfix)
        {
            return;
        }

        try
        {
            InPostfix = true;

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

            if (count > MaxCallLogs && count % 300 != 0)
            {
                return;
            }

            var snapshot = DescribeUpscalerState(AppDomain.CurrentDomain.GetAssemblies());
            log.LogInfo(
                $"Upscaler state probe call #{count}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; instance={SummarizeValue(__instance)}; args=[{SummarizeArguments(__args)}]; snapshot={snapshot}");
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"Upscaler state probe postfix failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            InPostfix = false;
        }
    }

    private static void LogSnapshot(ManualLogSource log, string reason, IEnumerable<Assembly> assemblies)
    {
        try
        {
            log.LogInfo($"Upscaler state probe snapshot: reason={reason}; {DescribeUpscalerState(assemblies)}");
        }
        catch (Exception ex)
        {
            log.LogWarning($"Upscaler state probe snapshot failed: {GetExceptionMessage(ex)}");
        }
    }

    private static string DescribeUpscalerState(IEnumerable<Assembly> assemblies)
    {
        var parts = new List<string>();

        var hdrpType = HookTargetCatalog.FindType(assemblies, "UnityEngine.Rendering.HighDefinition.HDRenderPipeline");
        if (hdrpType is null)
        {
            parts.Add("HDRenderPipeline=missing");
        }
        else
        {
            parts.Add($"HDRenderPipeline.GetUpscaleFilter={TryInvokeStaticParameterlessString(hdrpType, "GetUpscaleFilter") ?? "unavailable"}");
            parts.Add($"HDRenderPipeline.GetUpscaleRes={TryInvokeStaticParameterlessString(hdrpType, "GetUpscaleRes") ?? "unavailable"}");
        }

        var dynamicResolutionType = HookTargetCatalog.FindType(assemblies, "UnityEngine.Rendering.DynamicResolutionHandler");
        if (dynamicResolutionType is null)
        {
            parts.Add("DynamicResolutionHandler=missing");
        }
        else
        {
            parts.Add($"DynamicResolutionHandler.s_ActiveScalerSlot={TryReadStaticFieldString(dynamicResolutionType, "s_ActiveScalerSlot") ?? "unavailable"}");
            parts.Add($"DynamicResolutionHandler.s_ActiveInstanceDirty={TryReadStaticFieldString(dynamicResolutionType, "s_ActiveInstanceDirty") ?? "unavailable"}");
            parts.Add($"DynamicResolutionHandler.s_CameraUpscaleFilters={SummarizeCameraUpscaleFilters(TryReadStaticFieldObject(dynamicResolutionType, "s_CameraUpscaleFilters"))}");

            var activeInstance = TryReadStaticFieldObject(dynamicResolutionType, "s_ActiveInstance");
            var defaultInstance = TryReadStaticFieldObject(dynamicResolutionType, "s_DefaultInstance");
            parts.Add($"DynamicResolutionHandler.s_ActiveInstance={SummarizeValue(activeInstance)}");
            parts.Add($"DynamicResolutionHandler.s_DefaultInstance={SummarizeValue(defaultInstance)}");

            var instance = activeInstance ?? defaultInstance;
            if (instance is null)
            {
                parts.Add("DynamicResolutionHandler.instanceSnapshot=null");
            }
            else
            {
                parts.Add($"DynamicResolutionHandler.instanceSnapshot={SummarizeDynamicResolutionHandler(instance)}");
            }
        }

        return string.Join("; ", parts);
    }

    private static string? TryInvokeStaticParameterlessString(Type type, string methodName)
    {
        try
        {
            var method = type
                .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static)
                .FirstOrDefault(candidate =>
                    string.Equals(candidate.Name, methodName, StringComparison.Ordinal)
                    && candidate.GetParameters().Length == 0);

            return method?.Invoke(null, Array.Empty<object>())?.ToString();
        }
        catch (Exception ex)
        {
            return $"error:{FirstLine(GetExceptionMessage(ex))}";
        }
    }

    private static string? TryInvokeParameterlessString(object instance, string methodName)
    {
        try
        {
            var method = instance.GetType()
                .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                .FirstOrDefault(candidate =>
                    string.Equals(candidate.Name, methodName, StringComparison.Ordinal)
                    && candidate.GetParameters().Length == 0);

            return method?.Invoke(instance, Array.Empty<object>())?.ToString();
        }
        catch (Exception ex)
        {
            return $"error:{FirstLine(GetExceptionMessage(ex))}";
        }
    }

    private static object? TryReadStaticFieldObject(Type type, string fieldName)
    {
        try
        {
            var field = type.GetField(fieldName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
            return field?.GetValue(null);
        }
        catch
        {
            return null;
        }
    }

    private static string? TryReadStaticFieldString(Type type, string fieldName)
    {
        return TryReadStaticFieldObject(type, fieldName)?.ToString();
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

    private static object? TryReadFieldObject(object instance, string fieldName)
    {
        try
        {
            var field = instance.GetType().GetField(
                fieldName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);

            return field?.GetValue(instance);
        }
        catch
        {
            return null;
        }
    }

    private static object? TryReadMemberObject(object instance, string memberName)
    {
        return TryReadPropertyObject(instance, memberName) ?? TryReadFieldObject(instance, memberName);
    }

    private static string? TryReadPropertyString(object instance, string propertyName)
    {
        return TryReadPropertyObject(instance, propertyName)?.ToString();
    }

    private static string? TryReadMemberString(object instance, string memberName)
    {
        return TryReadMemberObject(instance, memberName)?.ToString();
    }

    private static string SummarizeArguments(object?[]? args)
    {
        if (args is null || args.Length == 0)
        {
            return string.Empty;
        }

        return string.Join("; ", args.Select((arg, index) => $"arg{index}={SummarizeValue(arg)}"));
    }

    private static string SummarizeValue(object? value)
    {
        if (value is null)
        {
            return "null";
        }

        try
        {
            var typeName = value.GetType().FullName ?? value.GetType().Name;
            if (typeName == "UnityEngine.Rendering.HighDefinition.HDAdditionalCameraData")
            {
                return SummarizeHDAdditionalCameraData(value);
            }

            if (typeName == "UnityEngine.Rendering.HighDefinition.HDCamera")
            {
                return SummarizeHDCamera(value);
            }

            if (typeName == "UnityEngine.Rendering.GlobalDynamicResolutionSettings")
            {
                return SummarizeGlobalDynamicResolutionSettings(value);
            }

            if (typeName == "UnityEngine.Rendering.DynamicResolutionHandler")
            {
                return SummarizeDynamicResolutionHandler(value);
            }

            if (typeName == "UnityEngine.Camera")
            {
                return SummarizeUnityCamera(value);
            }

            var valueText = value.ToString();
            return string.IsNullOrWhiteSpace(valueText) || string.Equals(valueText, typeName, StringComparison.Ordinal)
                ? typeName
                : $"{typeName} value={valueText}";
        }
        catch
        {
            return "unavailable";
        }
    }

    private static string SummarizeHDAdditionalCameraData(object value)
    {
        var parts = new List<string>
        {
            "HDAdditionalCameraData"
        };

        AppendMembers(parts, value, new[]
        {
            "allowDynamicResolution",
            "allowDeepLearningSuperSampling",
            "cameraCanRenderDLSS",
            "deepLearningSuperSamplingUseCustomQualitySettings",
            "deepLearningSuperSamplingQuality",
            "deepLearningSuperSamplingUseCustomAttributes",
            "deepLearningSuperSamplingUseOptimalSettings",
            "deepLearningSuperSamplingSharpening",
            "fsrOverrideSharpness",
            "fsrSharpness",
            "materialMipBias",
            "hasPersistentHistory"
        });

        var camera = TryReadMemberObject(value, "m_Camera");
        if (camera is not null)
        {
            parts.Add($"camera={SummarizeUnityCamera(camera)}");
        }

        return string.Join(",", parts);
    }

    private static string SummarizeHDCamera(object value)
    {
        var parts = new List<string>
        {
            "HDCamera"
        };

        AppendMembers(parts, value, new[]
        {
            "name",
            "actualWidth",
            "actualHeight",
            "finalViewport",
            "postProcessViewportSize",
            "screenSize",
            "screenWidth",
            "screenHeight",
            "dynamicResolutionRequest",
            "taaFrameIndex",
            "taaJitter",
            "cameraFrameCount"
        });

        AppendInvocations(parts, value, new[]
        {
            "IsDLSSEnabled",
            "UpsampleSyncPoint",
            "RequiresCameraJitter",
            "GetCameraFrameCount"
        });

        var camera = TryReadMemberObject(value, "camera");
        if (camera is not null)
        {
            parts.Add($"camera={SummarizeUnityCamera(camera)}");
        }

        return string.Join(",", parts);
    }

    private static string SummarizeGlobalDynamicResolutionSettings(object value)
    {
        var parts = new List<string>
        {
            "GlobalDynamicResolutionSettings"
        };

        AppendMembers(parts, value, new[]
        {
            "enabled",
            "useMipBias",
            "enableDLSS",
            "DLSSPerfQualitySetting",
            "DLSSInjectionPoint",
            "DLSSUseOptimalSettings",
            "DLSSSharpness",
            "fsrOverrideSharpness",
            "fsrSharpness",
            "maxPercentage",
            "minPercentage",
            "dynResType",
            "upsampleFilter",
            "forceResolution",
            "forcedPercentage",
            "lowResTransparencyMinimumThreshold",
            "rayTracingHalfResThreshold",
            "lowResSSGIMinimumThreshold",
            "lowResVolumetricCloudsMinimumThreshold"
        });

        return string.Join(",", parts);
    }

    private static string SummarizeDynamicResolutionHandler(object value)
    {
        var parts = new List<string>
        {
            "DynamicResolutionHandler"
        };

        AppendMembers(parts, value, new[]
        {
            "filter",
            "finalViewport",
            "runUpscalerFilterOnFullResolution",
            "type",
            "forcingResolution"
        });

        AppendInvocations(parts, value, new[]
        {
            "DynamicResolutionEnabled",
            "GetCurrentScale",
            "GetLastScaledSize",
            "GetResolvedScale",
            "RequestsHardwareDynamicResolution",
            "HardwareDynamicResIsEnabled",
            "SoftwareDynamicResIsEnabled"
        });

        return string.Join(",", parts);
    }

    private static string SummarizeUnityCamera(object value)
    {
        var parts = new List<string>
        {
            "Camera"
        };

        AppendMembers(parts, value, new[]
        {
            "name",
            "pixelWidth",
            "pixelHeight",
            "scaledPixelWidth",
            "scaledPixelHeight",
            "allowDynamicResolution",
            "targetTexture",
            "cameraType",
            "enabled"
        });

        return string.Join(",", parts);
    }

    private static string SummarizeCameraUpscaleFilters(object? value)
    {
        if (value is null)
        {
            return "null";
        }

        if (value is not IEnumerable enumerable)
        {
            return SummarizeValue(value);
        }

        var entries = new List<string>();
        foreach (var entry in enumerable)
        {
            if (entries.Count >= 8)
            {
                entries.Add("...");
                break;
            }

            var key = TryReadMemberString(entry, "Key") ?? "?";
            var entryValue = TryReadMemberString(entry, "Value") ?? "?";
            entries.Add($"{key}:{entryValue}");
        }

        return entries.Count == 0 ? "empty" : string.Join("|", entries);
    }

    private static void AppendMembers(ICollection<string> parts, object value, IReadOnlyList<string> memberNames)
    {
        foreach (var memberName in memberNames)
        {
            var memberValue = TryReadMemberString(value, memberName);
            if (!string.IsNullOrWhiteSpace(memberValue))
            {
                parts.Add($"{memberName}={memberValue}");
            }
        }
    }

    private static void AppendInvocations(ICollection<string> parts, object value, IReadOnlyList<string> methodNames)
    {
        foreach (var methodName in methodNames)
        {
            var result = TryInvokeParameterlessString(value, methodName);
            if (!string.IsNullOrWhiteSpace(result))
            {
                parts.Add($"{methodName}={result}");
            }
        }
    }

    private static bool CanPatch(MethodInfo method)
    {
        return !method.ContainsGenericParameters
            && !method.IsAbstract
            && method.DeclaringType is not null;
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
                    && parameters[1].ParameterType.FullName == "HarmonyLib.HarmonyMethod"
                    && (parameters.Length == 2 || parameters[2].ParameterType.FullName == "HarmonyLib.HarmonyMethod");
            })
            .OrderByDescending(method => method.GetParameters().Length)
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

    private static string GetMethodKey(MethodBase method)
    {
        return $"{method.Module.ModuleVersionId}:{method.MetadataToken}";
    }

    private static string GetExceptionMessage(Exception ex)
    {
        return ex is TargetInvocationException { InnerException: not null }
            ? ex.InnerException.Message
            : ex.Message;
    }

    private static string FirstLine(string value)
    {
        var lineEnd = value.IndexOfAny(new[] { '\r', '\n' });
        return lineEnd >= 0 ? value[..lineEnd] : value;
    }

    private readonly record struct UpscalerProbeTarget(string TypeName, IReadOnlyList<string> MemberNames);
}
