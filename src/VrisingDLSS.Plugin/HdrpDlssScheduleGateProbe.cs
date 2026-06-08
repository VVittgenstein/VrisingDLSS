using BepInEx.Logging;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class HdrpDlssScheduleGateProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".hdrp-dlss-schedule-gate-probe";
    private const int MaxCallLogs = 48;
    private const int MaxMemberWriteFailureLogs = 24;
    private const string GlobalDynamicResolutionSettingsTypeName = "UnityEngine.Rendering.GlobalDynamicResolutionSettings";
    private const string HdrpPipelineTypeName = "UnityEngine.Rendering.HighDefinition.HDRenderPipeline";
    private const string HdrpCameraDataTypeName = "UnityEngine.Rendering.HighDefinition.HDAdditionalCameraData";
    private const string UnityCameraTypeName = "UnityEngine.Camera";
    private const float DlaaRenderScalePercent = 100f;
    private const float QualityRenderScalePercent = 66.6667f;
    private const float BalancedRenderScalePercent = 58f;
    private const float PerformanceRenderScalePercent = 50f;
    private const float UltraPerformanceRenderScalePercent = 33.3333f;

    private static readonly object Sync = new();
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static ManualLogSource? Log;
    private static bool Installed;
    private static int CallLogCount;
    private static int MemberWriteFailureLogCount;
    private static ScheduleGateSettings Settings;

    internal static void Install(ManualLogSource log, string qualityMode, int renderScaleOverride)
    {
        if (Installed)
        {
            log.LogInfo("HDRP DLSS schedule-gate probe is already installed.");
            return;
        }

        Log = log;
        Settings = new ScheduleGateSettings(qualityMode, renderScaleOverride);
        log.LogWarning("HDRP DLSS schedule-gate probe enabled. This default-off diagnostic mutates HDRP DLSS scheduling gates only; it does not load NGX, call the native bridge, patch DLSSPass.Render, or evaluate DLSS.");

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var harmonyType = HookTargetCatalog.FindType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = HookTargetCatalog.FindType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            log.LogWarning("Harmony runtime was not found. HDRP DLSS schedule-gate probe cannot be installed.");
            return;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var patchMethod = FindPatchMethod(harmonyType);
        var prefix = typeof(HdrpDlssScheduleGateProbe).GetMethod(nameof(ProbePrefix), BindingFlags.NonPublic | BindingFlags.Static);
        var postfix = typeof(HdrpDlssScheduleGateProbe).GetMethod(nameof(ProbePostfix), BindingFlags.NonPublic | BindingFlags.Static);

        if (harmonyConstructor is null || harmonyMethodConstructor is null || patchMethod is null || prefix is null || postfix is null)
        {
            log.LogWarning("Harmony runtime shape was not recognized. HDRP DLSS schedule-gate probe cannot be installed.");
            return;
        }

        HarmonyInstance = harmonyConstructor.Invoke(new object[] { HarmonyId });
        HarmonyType = harmonyType;

        var pipelineType = HookTargetCatalog.FindType(assemblies, HdrpPipelineTypeName);
        if (pipelineType is null)
        {
            log.LogWarning($"HDRP DLSS schedule-gate target type not found: {HdrpPipelineTypeName}");
            return;
        }

        var patched = 0;
        foreach (var method in HookTargetCatalog.FindMethods(pipelineType, "SetupDLSSForCameraDataAndDynamicResHandler"))
        {
            if (!CanPatch(method))
            {
                log.LogWarning($"HDRP DLSS schedule-gate skipped unsupported method: {HookTargetCatalog.FormatMethod(method)}");
                continue;
            }

            try
            {
                var prefixPatch = harmonyMethodConstructor.Invoke(new object[] { prefix });
                var postfixPatch = harmonyMethodConstructor.Invoke(new object[] { postfix });
                var arguments = new object?[patchMethod.GetParameters().Length];
                arguments[0] = method;
                arguments[1] = prefixPatch;
                if (arguments.Length > 2)
                {
                    arguments[2] = postfixPatch;
                }

                patchMethod.Invoke(HarmonyInstance, arguments);
                patched++;
                log.LogInfo($"HDRP DLSS schedule-gate patched: {HookTargetCatalog.FormatMethod(method)}");
            }
            catch (Exception ex)
            {
                log.LogWarning($"HDRP DLSS schedule-gate failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
            }
        }

        Installed = patched > 0;
        log.LogInfo($"HDRP DLSS schedule-gate probe patched {patched} method(s). Target scale={DescribeTargetScale(null)}.");
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

            log.LogInfo("HDRP DLSS schedule-gate probe uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"HDRP DLSS schedule-gate probe uninstall failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            Installed = false;
            HarmonyInstance = null;
            HarmonyType = null;
            Log = null;
            lock (Sync)
            {
                CallLogCount = 0;
                MemberWriteFailureLogCount = 0;
            }
        }
    }

    private static void ProbePrefix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        ApplyMutation("prefix", __originalMethod, __instance, __args, forceCameraCanRenderDlss: false);
    }

    private static void ProbePostfix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        ApplyMutation("postfix", __originalMethod, __instance, __args, forceCameraCanRenderDlss: true);
    }

    private static void ApplyMutation(string phase, MethodBase originalMethod, object? instance, object?[]? args, bool forceCameraCanRenderDlss)
    {
        try
        {
            var log = Log;
            if (log is null || args is null)
            {
                return;
            }

            var targetPercentage = ResolveTargetPercentage();
            var changes = new List<string>();

            TryMutatePipelineAssetDynamicResolutionSettings(instance, targetPercentage, changes);

            if (args.Length > 0)
            {
                var cameraData = args[0];
                TryMutateHDAdditionalCameraData(cameraData, changes);

                if (forceCameraCanRenderDlss
                    && cameraData is not null
                    && IsHDAdditionalCameraData(cameraData)
                    && !ValueIsTrue(TryReadMember(cameraData, "cameraCanRenderDLSS")))
                {
                    TrySetBoolMember(cameraData, "cameraCanRenderDLSS", true, changes);
                }
            }

            if (args.Length > 1)
            {
                TryMutateUnityCamera(args[1], changes);
            }

            if (args.Length > 3 && args[3] is bool cameraRequestedDynamicRes && !cameraRequestedDynamicRes)
            {
                args[3] = true;
                changes.Add("cameraRequestedDynamicRes=False->True");
            }

            if (args.Length > 4)
            {
                var drsSettings = args[4];
                if (TryMutateDynamicResolutionSettings(ref drsSettings, targetPercentage, changes, "outDrsSettings"))
                {
                    args[4] = drsSettings;
                }
            }

            if (ShouldLogCall())
            {
                log.LogInfo(
                    $"HDRP DLSS schedule-gate {phase}: method={HookTargetCatalog.FormatMethod(originalMethod)}; targetScale={DescribeTargetScale(targetPercentage)}; changes={FormatChanges(changes)}; state={DescribeState(instance, args)}");
            }
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"HDRP DLSS schedule-gate {phase} failed: {GetExceptionMessage(ex)}");
        }
    }

    private static bool TryMutateHDAdditionalCameraData(object? cameraData, ICollection<string> changes)
    {
        if (!IsHDAdditionalCameraData(cameraData))
        {
            return false;
        }

        var changed = false;
        changed |= TrySetBoolMember(cameraData, "allowDynamicResolution", true, changes);
        changed |= TrySetBoolMember(cameraData, "allowDeepLearningSuperSampling", true, changes);
        changed |= TrySetBoolMember(cameraData, "deepLearningSuperSamplingUseCustomQualitySettings", true, changes);
        changed |= TrySetUIntMember(cameraData, "deepLearningSuperSamplingQuality", ResolveDlssPerfQualityValue(Settings.QualityMode), changes);
        changed |= TrySetBoolMember(cameraData, "deepLearningSuperSamplingUseCustomAttributes", true, changes);
        changed |= TrySetBoolMember(cameraData, "deepLearningSuperSamplingUseOptimalSettings", false, changes);
        changed |= TrySetFloatMember(cameraData, "deepLearningSuperSamplingSharpening", 0f, changes);
        return changed;
    }

    private static bool IsHDAdditionalCameraData(object? cameraData)
    {
        return cameraData is not null && cameraData.GetType().FullName == HdrpCameraDataTypeName;
    }

    private static bool TryMutateUnityCamera(object? camera, ICollection<string> changes)
    {
        return camera is not null
            && camera.GetType().FullName == UnityCameraTypeName
            && TrySetBoolMember(camera, "allowDynamicResolution", true, changes);
    }

    private static bool TryMutatePipelineAssetDynamicResolutionSettings(object? pipeline, float targetPercentage, ICollection<string> changes)
    {
        if (pipeline is null || pipeline.GetType().FullName != HdrpPipelineTypeName)
        {
            return false;
        }

        var asset = TryReadMember(pipeline, "m_Asset") ?? TryReadMember(pipeline, "asset");
        if (asset is null)
        {
            return false;
        }

        var pipelineSettingsMember = FindWritableMember(asset.GetType(), "currentPlatformRenderPipelineSettings");
        if (pipelineSettingsMember is null)
        {
            return false;
        }

        var pipelineSettings = ReadMember(asset, pipelineSettingsMember);
        if (pipelineSettings is null)
        {
            return false;
        }

        var dynamicSettingsMember = FindWritableMember(pipelineSettings.GetType(), "dynamicResolutionSettings");
        if (dynamicSettingsMember is null)
        {
            return false;
        }

        var dynamicSettings = ReadMember(pipelineSettings, dynamicSettingsMember);
        var changed = TryMutateDynamicResolutionSettings(ref dynamicSettings, targetPercentage, changes, "asset.drs");
        if (!changed)
        {
            return false;
        }

        WriteMember(pipelineSettings, dynamicSettingsMember, dynamicSettings);
        WriteMember(asset, pipelineSettingsMember, pipelineSettings);
        changes.Add($"asset.drsAfter={SummarizeDynamicResolutionSettings(dynamicSettings)}");
        return true;
    }

    private static bool TryMutateDynamicResolutionSettings(ref object? settings, float targetPercentage, ICollection<string> changes, string prefix)
    {
        if (settings is null || settings.GetType().FullName != GlobalDynamicResolutionSettingsTypeName)
        {
            return false;
        }

        var changed = false;
        changed |= TrySetBoolMember(settings, "enabled", true, changes, prefix);
        changed |= TrySetBoolMember(settings, "useMipBias", true, changes, prefix);
        changed |= TrySetBoolMember(settings, "enableDLSS", true, changes, prefix);
        changed |= TrySetUIntMember(settings, "DLSSPerfQualitySetting", ResolveDlssPerfQualityValue(Settings.QualityMode), changes, prefix);
        changed |= TrySetBoolMember(settings, "DLSSUseOptimalSettings", false, changes, prefix);
        changed |= TrySetFloatMember(settings, "DLSSSharpness", 0f, changes, prefix);
        changed |= TrySetFloatMember(settings, "maxPercentage", 100f, changes, prefix);
        changed |= TrySetFloatMember(settings, "minPercentage", Math.Min(targetPercentage, 100f), changes, prefix);
        changed |= TrySetEnumMember(settings, "dynResType", "Hardware", changes, prefix);
        changed |= TrySetEnumMember(settings, "upsampleFilter", "TAAU", changes, prefix);
        changed |= TrySetEnumMember(settings, "DLSSInjectionPoint", "BeforePost", changes, prefix);
        changed |= TrySetBoolMember(settings, "forceResolution", true, changes, prefix);
        changed |= TrySetFloatMember(settings, "forcedPercentage", targetPercentage, changes, prefix);
        return changed;
    }

    private static bool TrySetBoolMember(object? instance, string memberName, bool value, ICollection<string> changes, string? prefix = null)
    {
        return instance is not null && TrySetMember(instance, memberName, value, changes, prefix);
    }

    private static bool TrySetUIntMember(object? instance, string memberName, uint value, ICollection<string> changes, string? prefix = null)
    {
        return instance is not null && TrySetMember(instance, memberName, value, changes, prefix);
    }

    private static bool TrySetFloatMember(object? instance, string memberName, float value, ICollection<string> changes, string? prefix = null)
    {
        return instance is not null && TrySetMember(instance, memberName, value, changes, prefix);
    }

    private static bool TrySetEnumMember(object instance, string memberName, string enumName, ICollection<string> changes, string? prefix = null)
    {
        try
        {
            var member = FindWritableMember(instance.GetType(), memberName);
            if (member is null)
            {
                return false;
            }

            var memberType = GetMemberType(member);
            if (memberType is null || !memberType.IsEnum)
            {
                return false;
            }

            var value = Enum.Parse(memberType, enumName, ignoreCase: false);
            return TrySetMember(instance, memberName, value, changes, prefix);
        }
        catch
        {
            return false;
        }
    }

    private static bool TrySetMember(object instance, string memberName, object value, ICollection<string> changes, string? prefix = null)
    {
        try
        {
            var member = FindWritableMember(instance.GetType(), memberName);
            if (member is null)
            {
                return false;
            }

            var current = ReadMember(instance, member);
            if (ValuesEqual(current, value))
            {
                return false;
            }

            WriteMember(instance, member, value);
            var after = ReadMember(instance, member);
            if (!ValuesEqual(after, value))
            {
                LogMemberWriteFailure(instance.GetType(), memberName, current, value, after);
                return false;
            }

            changes.Add($"{FormatMemberName(prefix, memberName)}={FormatValue(current)}->{FormatValue(after)}");
            return true;
        }
        catch (Exception ex)
        {
            LogMemberWriteFailure(instance.GetType(), memberName, TryReadMember(instance, memberName), value, null, GetExceptionMessage(ex));
            return false;
        }
    }

    private static string DescribeState(object? pipeline, object?[] args)
    {
        var cameraData = args.Length > 0 ? args[0] : null;
        var camera = args.Length > 1 ? args[1] : null;
        var cameraRequestedDynamicRes = args.Length > 3 ? args[3] : null;
        var outDrsSettings = args.Length > 4 ? args[4] : null;
        var platformDetected = TryReadStaticProperty("UnityEngine.Rendering.HighDefinition.HDDynamicResolutionPlatformCapabilities", "DLSSDetected");
        var mDlssPass = pipeline is null ? null : TryReadMember(pipeline, "m_DLSSPass");
        var mDlssPassEnabled = pipeline is null ? null : TryReadMember(pipeline, "m_DLSSPassEnabled");

        return string.Join(
            "; ",
            new[]
            {
                $"platformDLSSDetected={FormatValue(platformDetected)}",
                $"m_DLSSPass={SummarizeObject(mDlssPass)}",
                $"m_DLSSPassEnabled={FormatValue(mDlssPassEnabled)}",
                $"cameraRequestedDynamicRes={FormatValue(cameraRequestedDynamicRes)}",
                $"cameraData={SummarizeCameraData(cameraData)}",
                $"camera={SummarizeCamera(camera)}",
                $"outDrsSettings={SummarizeDynamicResolutionSettings(outDrsSettings)}",
                $"assetDrs={SummarizeAssetDynamicResolutionSettings(pipeline)}"
            });
    }

    private static string SummarizeCameraData(object? cameraData)
    {
        if (cameraData is null)
        {
            return "null";
        }

        return $"type={cameraData.GetType().FullName}; allowDynamicResolution={FormatValue(TryReadMember(cameraData, "allowDynamicResolution"))}; allowDeepLearningSuperSampling={FormatValue(TryReadMember(cameraData, "allowDeepLearningSuperSampling"))}; cameraCanRenderDLSS={FormatValue(TryReadMember(cameraData, "cameraCanRenderDLSS"))}; customQuality={FormatValue(TryReadMember(cameraData, "deepLearningSuperSamplingUseCustomQualitySettings"))}; quality={FormatValue(TryReadMember(cameraData, "deepLearningSuperSamplingQuality"))}; customAttributes={FormatValue(TryReadMember(cameraData, "deepLearningSuperSamplingUseCustomAttributes"))}; optimal={FormatValue(TryReadMember(cameraData, "deepLearningSuperSamplingUseOptimalSettings"))}; sharpness={FormatValue(TryReadMember(cameraData, "deepLearningSuperSamplingSharpening"))}";
    }

    private static string SummarizeCamera(object? camera)
    {
        if (camera is null)
        {
            return "null";
        }

        return $"type={camera.GetType().FullName}; allowDynamicResolution={FormatValue(TryReadMember(camera, "allowDynamicResolution"))}; cameraType={FormatValue(TryReadMember(camera, "cameraType"))}; pixelWidth={FormatValue(TryReadMember(camera, "pixelWidth"))}; pixelHeight={FormatValue(TryReadMember(camera, "pixelHeight"))}";
    }

    private static string SummarizeAssetDynamicResolutionSettings(object? pipeline)
    {
        if (pipeline is null)
        {
            return "null";
        }

        var asset = TryReadMember(pipeline, "m_Asset") ?? TryReadMember(pipeline, "asset");
        var pipelineSettings = asset is null ? null : TryReadMember(asset, "currentPlatformRenderPipelineSettings");
        var dynamicSettings = pipelineSettings is null ? null : TryReadMember(pipelineSettings, "dynamicResolutionSettings");
        return SummarizeDynamicResolutionSettings(dynamicSettings);
    }

    private static string SummarizeDynamicResolutionSettings(object? settings)
    {
        if (settings is null)
        {
            return "null";
        }

        return $"type={settings.GetType().FullName}; enabled={FormatValue(TryReadMember(settings, "enabled"))}; useMipBias={FormatValue(TryReadMember(settings, "useMipBias"))}; enableDLSS={FormatValue(TryReadMember(settings, "enableDLSS"))}; quality={FormatValue(TryReadMember(settings, "DLSSPerfQualitySetting"))}; optimal={FormatValue(TryReadMember(settings, "DLSSUseOptimalSettings"))}; sharpness={FormatValue(TryReadMember(settings, "DLSSSharpness"))}; injection={FormatValue(TryReadMember(settings, "DLSSInjectionPoint"))}; dynResType={FormatValue(TryReadMember(settings, "dynResType"))}; upsampleFilter={FormatValue(TryReadMember(settings, "upsampleFilter"))}; forceResolution={FormatValue(TryReadMember(settings, "forceResolution"))}; forcedPercentage={FormatValue(TryReadMember(settings, "forcedPercentage"))}; minPercentage={FormatValue(TryReadMember(settings, "minPercentage"))}; maxPercentage={FormatValue(TryReadMember(settings, "maxPercentage"))}";
    }

    private static object? TryReadStaticProperty(string typeName, string propertyName)
    {
        try
        {
            var type = HookTargetCatalog.FindType(AppDomain.CurrentDomain.GetAssemblies(), typeName);
            var property = type?.GetProperty(propertyName, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
            return property?.GetIndexParameters().Length == 0 ? property.GetValue(null) : null;
        }
        catch
        {
            return null;
        }
    }

    private static object? TryReadMember(object instance, string memberName)
    {
        try
        {
            var member = FindReadableMember(instance.GetType(), memberName);
            return member is null ? null : ReadMember(instance, member);
        }
        catch
        {
            return null;
        }
    }

    private static MemberInfo? FindReadableMember(Type type, string memberName)
    {
        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
        var property = type.GetProperty(memberName, flags);
        if (property is not null && property.GetIndexParameters().Length == 0 && property.GetMethod is not null)
        {
            return property;
        }

        return type.GetField(memberName, flags);
    }

    private static MemberInfo? FindWritableMember(Type type, string memberName)
    {
        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
        var property = type.GetProperty(memberName, flags);
        if (property is not null && property.GetIndexParameters().Length == 0 && property.SetMethod is not null)
        {
            return property;
        }

        var field = type.GetField(memberName, flags);
        return field is not null && !field.IsInitOnly ? field : null;
    }

    private static Type? GetMemberType(MemberInfo member)
    {
        return member switch
        {
            FieldInfo field => field.FieldType,
            PropertyInfo property => property.PropertyType,
            _ => null
        };
    }

    private static object? ReadMember(object instance, MemberInfo member)
    {
        return member switch
        {
            FieldInfo field => field.GetValue(instance),
            PropertyInfo property => property.GetValue(instance),
            _ => null
        };
    }

    private static void WriteMember(object instance, MemberInfo member, object? value)
    {
        switch (member)
        {
            case FieldInfo field:
                field.SetValue(instance, value);
                break;
            case PropertyInfo property:
                property.SetValue(instance, value);
                break;
        }
    }

    private static bool ValuesEqual(object? left, object right)
    {
        if (left is null)
        {
            return false;
        }

        if (left is float leftFloat && right is float rightFloat)
        {
            return Math.Abs(leftFloat - rightFloat) < 0.0001f;
        }

        if (left.GetType().IsEnum && right.GetType().IsEnum)
        {
            return string.Equals(left.ToString(), right.ToString(), StringComparison.Ordinal);
        }

        return Equals(left, right);
    }

    private static bool ValueIsTrue(object? value)
    {
        return value is bool boolValue && boolValue;
    }

    private static void LogMemberWriteFailure(Type type, string memberName, object? before, object expected, object? after, string? error = null)
    {
        int count;
        lock (Sync)
        {
            if (MemberWriteFailureLogCount >= MaxMemberWriteFailureLogs)
            {
                return;
            }

            MemberWriteFailureLogCount++;
            count = MemberWriteFailureLogCount;
        }

        var detail = string.IsNullOrWhiteSpace(error) ? string.Empty : $"; error={error}";
        Log?.LogWarning($"HDRP DLSS schedule-gate member write did not stick #{count}: {type.FullName}.{memberName}; before={FormatValue(before)}; expected={FormatValue(expected)}; after={FormatValue(after)}{detail}");
    }

    private static bool ShouldLogCall()
    {
        lock (Sync)
        {
            if (CallLogCount >= MaxCallLogs)
            {
                return false;
            }

            CallLogCount++;
            return true;
        }
    }

    private static float ResolveTargetPercentage()
    {
        if (Settings.RenderScaleOverride > 0)
        {
            return Math.Clamp(Settings.RenderScaleOverride, 1, 100);
        }

        return Settings.QualityMode.Trim().ToUpperInvariant() switch
        {
            "DLAA" => DlaaRenderScalePercent,
            "QUALITY" => QualityRenderScalePercent,
            "BALANCED" => BalancedRenderScalePercent,
            "PERFORMANCE" => PerformanceRenderScalePercent,
            "ULTRAPERFORMANCE" or "ULTRA_PERFORMANCE" or "ULTRA PERFORMANCE" => UltraPerformanceRenderScalePercent,
            _ => PerformanceRenderScalePercent
        };
    }

    private static uint ResolveDlssPerfQualityValue(string qualityMode)
    {
        return qualityMode.Trim().ToUpperInvariant() switch
        {
            "DLAA" => 4,
            "QUALITY" => 2,
            "BALANCED" => 1,
            "PERFORMANCE" => 0,
            "ULTRAPERFORMANCE" or "ULTRA_PERFORMANCE" or "ULTRA PERFORMANCE" => 3,
            _ => 0
        };
    }

    private static string DescribeTargetScale(float? targetPercentage)
    {
        var percentage = targetPercentage ?? ResolveTargetPercentage();
        return $"{Settings.QualityMode}/{FormatPercentage(percentage)}";
    }

    private static string FormatPercentage(float percentage)
    {
        return percentage.ToString("0.###", CultureInfo.InvariantCulture) + "%";
    }

    private static string FormatMemberName(string? prefix, string memberName)
    {
        return string.IsNullOrWhiteSpace(prefix) ? memberName : $"{prefix}.{memberName}";
    }

    private static string FormatChanges(IReadOnlyCollection<string> changes)
    {
        return changes.Count == 0 ? "none" : string.Join("; ", changes);
    }

    private static string FormatValue(object? value)
    {
        return value switch
        {
            null => "null",
            float floatValue => floatValue.ToString("0.###", CultureInfo.InvariantCulture),
            double doubleValue => doubleValue.ToString("0.###", CultureInfo.InvariantCulture),
            _ => value.ToString() ?? string.Empty
        };
    }

    private static string SummarizeObject(object? value)
    {
        return value is null ? "null" : value.GetType().FullName ?? value.GetType().Name;
    }

    private static bool CanPatch(MethodInfo method)
    {
        return !method.ContainsGenericParameters && !method.IsAbstract;
    }

    private static MethodInfo? FindPatchMethod(Type harmonyType)
    {
        return harmonyType.GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .Where(method => method.Name == "Patch")
            .OrderByDescending(method => method.GetParameters().Length)
            .FirstOrDefault(method =>
            {
                var parameters = method.GetParameters();
                return parameters.Length >= 2
                    && parameters[0].ParameterType == typeof(MethodBase)
                    && parameters[1].ParameterType.FullName == "HarmonyLib.HarmonyMethod";
            });
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
                return parameters.Length == parameterTypes.Count
                    && parameters.Select(parameter => parameter.ParameterType).SequenceEqual(parameterTypes);
            });
    }

    private static string GetExceptionMessage(Exception ex)
    {
        return ex.InnerException is not null ? $"{ex.Message} Inner: {ex.InnerException.Message}" : ex.Message;
    }

    private readonly record struct ScheduleGateSettings(string QualityMode, int RenderScaleOverride);
}
