using BepInEx.Logging;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class RenderScaleControlProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".render-scale-control-probe";
    private const int MaxInitialLogs = 20;
    private const int MaxMemberWriteFailureLogs = 20;
    private const int MaxHardwareDynamicResolutionRequestLogs = 16;
    private const int MaxHardwareDynamicResolutionRequestFailureLogs = 3;
    private const int MaxHandlerRequestDiagnosticLogs = 12;
    private const int MaxSoftwareFallbackDiagnosticLogs = 12;
    private const string GlobalDynamicResolutionSettingsTypeName = "UnityEngine.Rendering.GlobalDynamicResolutionSettings";
    private const string TaaUpscaleFilterName = "TAAU";
    private const float DlaaRenderScalePercent = 100f;
    private const float QualityRenderScalePercent = 66.6667f;
    private const float BalancedRenderScalePercent = 58f;
    private const float PerformanceRenderScalePercent = 50f;
    private const float UltraPerformanceRenderScalePercent = 33.3333f;

    private static readonly RenderScaleProbeTarget[] Targets =
    {
        new("UnityEngine.Rendering.HighDefinition.HDRenderPipeline", new[] { "SetupDLSSForCameraDataAndDynamicResHandler" }),
        new("UnityEngine.Rendering.DynamicResolutionHandler", new[] { "Update", "SetCurrentCameraRequest" }),
        new("UnityEngine.Rendering.HighDefinition.HDCamera", new[] { "RequestDynamicResolution" })
    };

    private static readonly object Sync = new();
    private static ManualLogSource? Log;
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static MethodInfo? SetHardwareDynamicResolutionStateMethod;
    private static bool Installed;
    private static int CallCount;
    private static int ScaleLogCount;
    private static int CameraUpscaleFilterSetCount;
    private static int MemberWriteFailureLogCount;
    private static int HardwareDynamicResolutionRequestLogCount;
    private static int HardwareDynamicResolutionRequestFailureLogCount;
    private static int HandlerRequestDiagnosticLogCount;
    private static int SoftwareFallbackDiagnosticLogCount;
    private static RenderScaleSettings Settings;

    internal static void Install(ManualLogSource log, string qualityMode, int renderScaleOverride)
    {
        if (Installed)
        {
            log.LogInfo("Render-scale control probe is already installed.");
            return;
        }

        Log = log;
        Settings = new RenderScaleSettings(qualityMode, renderScaleOverride);

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var harmonyType = FindRuntimeType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = FindRuntimeType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            log.LogWarning("Harmony runtime was not found. Render-scale control probe cannot be installed.");
            return;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var prefix = typeof(RenderScaleControlProbe).GetMethod(nameof(ProbePrefix), BindingFlags.NonPublic | BindingFlags.Static);
        var postfix = typeof(RenderScaleControlProbe).GetMethod(nameof(ProbePostfix), BindingFlags.NonPublic | BindingFlags.Static);
        var patchMethod = FindPatchMethod(harmonyType);

        if (harmonyConstructor is null || harmonyMethodConstructor is null || prefix is null || postfix is null || patchMethod is null)
        {
            log.LogWarning("Harmony runtime shape was not recognized. Render-scale control probe cannot be installed.");
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
                log.LogWarning($"Render-scale control target type not found: {target.TypeName}");
                continue;
            }

            foreach (var memberName in target.MemberNames)
            {
                foreach (var method in HookTargetCatalog.FindMethods(type, memberName))
                {
                    if (!CanPatch(method))
                    {
                        log.LogWarning($"Render-scale control skipped unsupported method: {HookTargetCatalog.FormatMethod(method)}");
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
                        log.LogInfo($"Render-scale control patched: {HookTargetCatalog.FormatMethod(method)}");
                    }
                    catch (Exception ex)
                    {
                        log.LogWarning($"Render-scale control failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
                    }
                }
            }
        }

        Installed = patched > 0;
        log.LogInfo($"Render-scale control probe patched {patched} method(s). Target scale={DescribeTargetScale(null)}; upscaleFilter={TaaUpscaleFilterName}; HDRP internal DLSS is not forced by this probe.");
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

            log.LogInfo("Render-scale control probe uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"Render-scale control probe uninstall failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            Installed = false;
            HarmonyInstance = null;
            HarmonyType = null;
            SetHardwareDynamicResolutionStateMethod = null;
            CallCount = 0;
            ScaleLogCount = 0;
            CameraUpscaleFilterSetCount = 0;
            MemberWriteFailureLogCount = 0;
            HardwareDynamicResolutionRequestLogCount = 0;
            HardwareDynamicResolutionRequestFailureLogCount = 0;
            HandlerRequestDiagnosticLogCount = 0;
            SoftwareFallbackDiagnosticLogCount = 0;
        }
    }

    private static void ProbePrefix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        ApplyMutation("prefix", __originalMethod, __instance, __args);
    }

    private static void ProbePostfix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        ApplyMutation("postfix", __originalMethod, __instance, __args);
    }

    private static void ApplyMutation(string phase, MethodBase originalMethod, object? instance, object?[]? args)
    {
        try
        {
            var log = Log;
            if (log is null || args is null)
            {
                return;
            }

            var methodName = originalMethod.Name;
            var camera = FindCamera(instance, args);
            var targetPercentage = ResolveTargetPercentage(camera);
            var changes = new List<string>();

            TryRequestHardwareDynamicResolutionState(changes);

            if (methodName == "SetupDLSSForCameraDataAndDynamicResHandler")
            {
                if (args.Length > 0 && TryMutateHDAdditionalCameraData(args[0], changes))
                {
                    // Mutating the IL2CPP object is enough; keep the slot populated for by-ref writeback safety.
                    args[0] = args[0];
                }

                var setupCamera = args.Length > 1 ? args[1] : null;
                if (setupCamera is not null && TryMutateUnityCamera(setupCamera, changes))
                {
                    TrySetPerCameraUpscaleFilter(setupCamera, changes);
                }

                if (args.Length > 3 && args[3] is bool cameraRequestedDynamicRes && !cameraRequestedDynamicRes)
                {
                    args[3] = true;
                    changes.Add("cameraRequestedDynamicRes=false->true");
                }

                if (args.Length > 4)
                {
                    var settings = args[4];
                    if (TryMutateDynamicResolutionSettings(ref settings, targetPercentage, changes))
                    {
                        args[4] = settings;
                    }
                }
            }
            else if (methodName == "Update")
            {
                TryMutateDynamicResolutionHandler(instance, changes);

                if (args.Length > 0)
                {
                    var settings = args[0];
                    if (TryMutateDynamicResolutionSettings(ref settings, targetPercentage, changes))
                    {
                        args[0] = settings;
                    }
                }
            }
            else if (methodName == "SetCurrentCameraRequest" || methodName == "RequestDynamicResolution")
            {
                if (args.Length > 0 && args[0] is bool request && !request)
                {
                    args[0] = true;
                    changes.Add($"{methodName}.request=false->true");
                }
            }

            if (changes.Count == 0)
            {
                return;
            }

            int count;
            lock (Sync)
            {
                CallCount++;
                count = CallCount;
            }

            if (ShouldLog(count))
            {
                log.LogInfo($"Render-scale control {phase} #{count}: method={HookTargetCatalog.FormatMethod(originalMethod)}; targetScale={FormatPercentage(targetPercentage)}; changes={string.Join("; ", changes)}");
            }
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"Render-scale control {phase} failed: {GetExceptionMessage(ex)}");
        }
    }

    private static bool TryMutateHDAdditionalCameraData(object? cameraData, ICollection<string> changes)
    {
        if (cameraData is null || cameraData.GetType().FullName != "UnityEngine.Rendering.HighDefinition.HDAdditionalCameraData")
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

    private static bool TryMutateUnityCamera(object? camera, ICollection<string> changes)
    {
        return camera is not null
            && camera.GetType().FullName == "UnityEngine.Camera"
            && TrySetBoolMember(camera, "allowDynamicResolution", true, changes);
    }

    private static bool TryMutateDynamicResolutionHandler(object? handler, ICollection<string> changes)
    {
        if (handler is null)
        {
            LogHandlerRequestDiagnostic("handler=null");
            return false;
        }

        var handlerType = handler.GetType();
        if (handlerType.FullName != "UnityEngine.Rendering.DynamicResolutionHandler")
        {
            LogHandlerRequestDiagnostic($"unexpected handler type={handlerType.FullName ?? handlerType.Name}");
            return false;
        }

        var before = TryReadMember(handler, "m_CurrentCameraRequest");
        var invoked = TryInvokeSetCurrentCameraRequest(handler, out var invokeError);
        var changed = TrySetBoolMember(handler, "m_CurrentCameraRequest", true, changes);
        var after = TryReadMember(handler, "m_CurrentCameraRequest");
        var writable = FindWritableMember(handlerType, "m_CurrentCameraRequest") is not null;

        LogHandlerRequestDiagnostic(
            $"type={handlerType.FullName}; before={FormatValue(before)}; invokedSetCurrentCameraRequest={invoked}; fieldWritable={writable}; after={FormatValue(after)}{(string.IsNullOrWhiteSpace(invokeError) ? string.Empty : $"; invokeError={invokeError}")}");

        var softwareFallbackChanged = TryForceSoftwareFallback(handler, changes);
        return changed || invoked || softwareFallbackChanged;
    }

    private static bool TryForceSoftwareFallback(object handler, ICollection<string> changes)
    {
        var handlerType = handler.GetType();
        var requestBefore = TryReadMember(handler, "m_CurrentCameraRequest");
        var fallbackBefore = TryReadMember(handler, "m_ForceSoftwareFallback");
        var typeBefore = TryReadMember(handler, "type");
        var scalableBefore = SummarizeScalableBufferManager();

        var invokedFallback = TryInvokeParameterless(handler, "ForceSoftwareFallback", out _, out var fallbackInvokeError);
        var fallbackAfterInvoke = TryReadMember(handler, "m_ForceSoftwareFallback");
        var fieldChanged = false;
        if (!ValueIsTrue(fallbackAfterInvoke))
        {
            fieldChanged = TrySetBoolMember(handler, "m_ForceSoftwareFallback", true, changes);
        }

        var requestAfter = TryReadMember(handler, "m_CurrentCameraRequest");
        var fallbackAfter = TryReadMember(handler, "m_ForceSoftwareFallback");
        var softwareEnabled = TryInvokeParameterless(handler, "SoftwareDynamicResIsEnabled", out var softwareEnabledValue, out var softwareEnabledError);
        var hardwareEnabled = TryInvokeParameterless(handler, "HardwareDynamicResIsEnabled", out var hardwareEnabledValue, out var hardwareEnabledError);
        var dynamicEnabled = TryInvokeParameterless(handler, "DynamicResolutionEnabled", out var dynamicEnabledValue, out var dynamicEnabledError);
        var currentScale = TryInvokeParameterless(handler, "GetCurrentScale", out var currentScaleValue, out var currentScaleError);
        var resolvedScale = TryInvokeParameterless(handler, "GetResolvedScale", out var resolvedScaleValue, out var resolvedScaleError);
        var scalableAfter = SummarizeScalableBufferManager();

        if (invokedFallback && !ValueIsTrue(fallbackBefore) && ValueIsTrue(fallbackAfterInvoke))
        {
            changes.Add("ForceSoftwareFallback=false->true");
        }

        var fallbackWritable = FindWritableMember(handlerType, "m_ForceSoftwareFallback") is not null;
        LogSoftwareFallbackDiagnostic(
            $"type={handlerType.FullName}; requestBefore={FormatValue(requestBefore)}; requestAfter={FormatValue(requestAfter)}; typeBefore={FormatValue(typeBefore)}; fallbackBefore={FormatValue(fallbackBefore)}; invokedForceSoftwareFallback={invokedFallback}; fallbackFieldWritable={fallbackWritable}; fallbackAfter={FormatValue(fallbackAfter)}; SoftwareDynamicResIsEnabled={FormatInvocation(softwareEnabled, softwareEnabledValue, softwareEnabledError)}; HardwareDynamicResIsEnabled={FormatInvocation(hardwareEnabled, hardwareEnabledValue, hardwareEnabledError)}; DynamicResolutionEnabled={FormatInvocation(dynamicEnabled, dynamicEnabledValue, dynamicEnabledError)}; GetCurrentScale={FormatInvocation(currentScale, currentScaleValue, currentScaleError)}; GetResolvedScale={FormatInvocation(resolvedScale, resolvedScaleValue, resolvedScaleError)}; ScalableBufferManagerBefore={scalableBefore}; ScalableBufferManagerAfter={scalableAfter}{(string.IsNullOrWhiteSpace(fallbackInvokeError) ? string.Empty : $"; fallbackInvokeError={fallbackInvokeError}")}");

        return invokedFallback || fieldChanged;
    }

    private static bool TryInvokeSetCurrentCameraRequest(object handler, out string error)
    {
        error = string.Empty;
        try
        {
            var method = FindMethodBySignature(
                handler.GetType(),
                "SetCurrentCameraRequest",
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
                new[] { typeof(bool) });

            if (method is null)
            {
                error = "method not found";
                return false;
            }

            method.Invoke(handler, new object[] { true });
            return true;
        }
        catch (Exception ex)
        {
            error = GetExceptionMessage(ex);
            return false;
        }
    }

    private static bool TryInvokeParameterless(object instance, string methodName, out object? value, out string error)
    {
        value = null;
        error = string.Empty;
        try
        {
            var method = FindMethodBySignature(
                instance.GetType(),
                methodName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
                Array.Empty<Type>());

            if (method is null)
            {
                error = "method not found";
                return false;
            }

            value = method.Invoke(instance, Array.Empty<object>());
            return true;
        }
        catch (Exception ex)
        {
            error = GetExceptionMessage(ex);
            return false;
        }
    }

    private static bool TryMutateDynamicResolutionSettings(ref object? settings, float targetPercentage, ICollection<string> changes)
    {
        if (settings is null || settings.GetType().FullName != GlobalDynamicResolutionSettingsTypeName)
        {
            return false;
        }

        var before = SummarizeDynamicResolutionSettings(settings);
        var changed = false;
        changed |= TrySetBoolMember(settings, "enabled", true, changes);
        changed |= TrySetBoolMember(settings, "useMipBias", true, changes);
        changed |= TrySetBoolMember(settings, "enableDLSS", false, changes);
        changed |= TrySetUIntMember(settings, "DLSSPerfQualitySetting", ResolveDlssPerfQualityValue(Settings.QualityMode), changes);
        changed |= TrySetBoolMember(settings, "DLSSUseOptimalSettings", false, changes);
        changed |= TrySetFloatMember(settings, "DLSSSharpness", 0f, changes);
        changed |= TrySetFloatMember(settings, "maxPercentage", 100f, changes);
        changed |= TrySetFloatMember(settings, "minPercentage", Math.Min(targetPercentage, 100f), changes);
        changed |= TrySetEnumMember(settings, "dynResType", "Hardware", changes);
        changed |= TrySetEnumMember(settings, "upsampleFilter", TaaUpscaleFilterName, changes);
        changed |= TrySetBoolMember(settings, "forceResolution", true, changes);
        changed |= TrySetFloatMember(settings, "forcedPercentage", targetPercentage, changes);

        if (!changed)
        {
            return false;
        }

        var after = SummarizeDynamicResolutionSettings(settings);
        if (ShouldLogScaleDetail())
        {
            changes.Add($"settingsBefore={before}");
            changes.Add($"settingsAfter={after}");
        }

        return true;
    }

    private static void TrySetPerCameraUpscaleFilter(object camera, ICollection<string> changes)
    {
        if (CameraUpscaleFilterSetCount >= 16)
        {
            return;
        }

        try
        {
            var dynamicResolutionType = HookTargetCatalog.FindType(AppDomain.CurrentDomain.GetAssemblies(), "UnityEngine.Rendering.DynamicResolutionHandler");
            if (dynamicResolutionType is null)
            {
                return;
            }

            var method = dynamicResolutionType.GetMethods(BindingFlags.Public | BindingFlags.Static)
                .FirstOrDefault(candidate =>
                {
                    if (candidate.Name != "SetUpscaleFilter")
                    {
                        return false;
                    }

                    var parameters = candidate.GetParameters();
                    return parameters.Length == 2
                        && parameters[0].ParameterType.FullName == "UnityEngine.Camera"
                        && parameters[1].ParameterType.IsEnum;
                });

            if (method is null)
            {
                return;
            }

            var filterType = method.GetParameters()[1].ParameterType;
            var filter = Enum.Parse(filterType, TaaUpscaleFilterName, ignoreCase: false);
            method.Invoke(null, new[] { camera, filter });
            CameraUpscaleFilterSetCount++;
            changes.Add($"SetUpscaleFilter={TaaUpscaleFilterName}");
        }
        catch (Exception ex)
        {
            if (CameraUpscaleFilterSetCount == 0)
            {
                Log?.LogWarning($"Render-scale control could not set per-camera upscale filter: {GetExceptionMessage(ex)}");
            }

            CameraUpscaleFilterSetCount++;
        }
    }

    private static void TryRequestHardwareDynamicResolutionState(ICollection<string> changes)
    {
        try
        {
            var method = GetSetHardwareDynamicResolutionStateMethod();
            if (method is null)
            {
                LogHardwareDynamicResolutionRequestFailure("method not found");
                return;
            }

            method.Invoke(null, new object[] { true });
            if (ShouldLogHardwareDynamicResolutionRequest())
            {
                changes.Add("RTHandles.SetHardwareDynamicResolutionState=true");
            }
        }
        catch (Exception ex)
        {
            LogHardwareDynamicResolutionRequestFailure(GetExceptionMessage(ex));
        }
    }

    private static MethodInfo? GetSetHardwareDynamicResolutionStateMethod()
    {
        if (SetHardwareDynamicResolutionStateMethod is not null)
        {
            return SetHardwareDynamicResolutionStateMethod;
        }

        var rtHandlesType = HookTargetCatalog.FindType(AppDomain.CurrentDomain.GetAssemblies(), "UnityEngine.Rendering.RTHandles");
        var method = rtHandlesType?.GetMethods(BindingFlags.Public | BindingFlags.Static)
            .FirstOrDefault(candidate =>
            {
                if (candidate.Name != "SetHardwareDynamicResolutionState")
                {
                    return false;
                }

                var parameters = candidate.GetParameters();
                return parameters.Length == 1 && parameters[0].ParameterType == typeof(bool);
            });

        if (method is not null)
        {
            SetHardwareDynamicResolutionStateMethod = method;
        }

        return method;
    }

    private static bool ShouldLogHardwareDynamicResolutionRequest()
    {
        lock (Sync)
        {
            if (HardwareDynamicResolutionRequestLogCount >= MaxHardwareDynamicResolutionRequestLogs)
            {
                return false;
            }

            HardwareDynamicResolutionRequestLogCount++;
            return true;
        }
    }

    private static void LogHardwareDynamicResolutionRequestFailure(string error)
    {
        int count;
        lock (Sync)
        {
            if (HardwareDynamicResolutionRequestFailureLogCount >= MaxHardwareDynamicResolutionRequestFailureLogs)
            {
                return;
            }

            HardwareDynamicResolutionRequestFailureLogCount++;
            count = HardwareDynamicResolutionRequestFailureLogCount;
        }

        Log?.LogWarning($"Render-scale control could not request hardware dynamic resolution state #{count}: {error}");
    }

    private static void LogHandlerRequestDiagnostic(string message)
    {
        int count;
        lock (Sync)
        {
            if (HandlerRequestDiagnosticLogCount >= MaxHandlerRequestDiagnosticLogs)
            {
                return;
            }

            HandlerRequestDiagnosticLogCount++;
            count = HandlerRequestDiagnosticLogCount;
        }

        Log?.LogInfo($"Render-scale control handler request diagnostic #{count}: {message}");
    }

    private static void LogSoftwareFallbackDiagnostic(string message)
    {
        int count;
        lock (Sync)
        {
            if (SoftwareFallbackDiagnosticLogCount >= MaxSoftwareFallbackDiagnosticLogs)
            {
                return;
            }

            SoftwareFallbackDiagnosticLogCount++;
            count = SoftwareFallbackDiagnosticLogCount;
        }

        Log?.LogInfo($"Render-scale control software fallback diagnostic #{count}: {message}");
    }

    private static bool TrySetBoolMember(object instance, string memberName, bool value, ICollection<string> changes)
    {
        return TrySetMember(instance, memberName, value, changes);
    }

    private static bool TrySetUIntMember(object instance, string memberName, uint value, ICollection<string> changes)
    {
        return TrySetMember(instance, memberName, value, changes);
    }

    private static bool TrySetFloatMember(object instance, string memberName, float value, ICollection<string> changes)
    {
        return TrySetMember(instance, memberName, value, changes);
    }

    private static bool TrySetEnumMember(object instance, string memberName, string enumName, ICollection<string> changes)
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
            return TrySetMember(instance, memberName, value, changes);
        }
        catch
        {
            return false;
        }
    }

    private static bool TrySetMember(object instance, string memberName, object value, ICollection<string> changes)
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

            changes.Add($"{memberName}={FormatValue(current)}->{FormatValue(after)}");
            return true;
        }
        catch (Exception ex)
        {
            LogMemberWriteFailure(instance.GetType(), memberName, TrySafeRead(instance, memberName), value, null, GetExceptionMessage(ex));
            return false;
        }
    }

    private static object? TrySafeRead(object instance, string memberName)
    {
        try
        {
            return TryReadMember(instance, memberName);
        }
        catch
        {
            return null;
        }
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

        var detail = string.IsNullOrWhiteSpace(error) ? "" : $"; error={error}";
        Log?.LogWarning($"Render-scale control member write did not stick #{count}: {type.FullName}.{memberName}; before={FormatValue(before)}; expected={FormatValue(expected)}; after={FormatValue(after)}{detail}");
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
            PropertyInfo property => property.PropertyType,
            FieldInfo field => field.FieldType,
            _ => null
        };
    }

    private static object? ReadMember(object instance, MemberInfo member)
    {
        return member switch
        {
            PropertyInfo property => property.GetValue(instance),
            FieldInfo field => field.GetValue(instance),
            _ => null
        };
    }

    private static void WriteMember(object instance, MemberInfo member, object value)
    {
        switch (member)
        {
            case PropertyInfo property:
                property.SetValue(instance, value);
                break;
            case FieldInfo field:
                field.SetValue(instance, value);
                break;
        }
    }

    private static object? FindCamera(object? instance, object?[] args)
    {
        foreach (var arg in args)
        {
            if (arg is not null && arg.GetType().FullName == "UnityEngine.Camera")
            {
                return arg;
            }
        }

        if (instance is not null && instance.GetType().FullName == "UnityEngine.Rendering.HighDefinition.HDCamera")
        {
            return TryReadMember(instance, "camera");
        }

        foreach (var arg in args)
        {
            if (arg is not null && arg.GetType().FullName == "UnityEngine.Rendering.HighDefinition.HDCamera")
            {
                return TryReadMember(arg, "camera");
            }
        }

        return null;
    }

    private static object? TryReadMember(object instance, string memberName)
    {
        try
        {
            const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
            var property = instance.GetType().GetProperty(memberName, flags);
            if (property is not null && property.GetIndexParameters().Length == 0 && property.GetMethod is not null)
            {
                return property.GetValue(instance);
            }

            var field = instance.GetType().GetField(memberName, flags);
            return field?.GetValue(instance);
        }
        catch
        {
            return null;
        }
    }

    private static object? TryReadStaticMember(Type type, string memberName)
    {
        try
        {
            const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static;
            var property = type.GetProperty(memberName, flags);
            if (property is not null && property.GetIndexParameters().Length == 0 && property.GetMethod is not null)
            {
                return property.GetValue(null);
            }

            var field = type.GetField(memberName, flags);
            return field?.GetValue(null);
        }
        catch
        {
            return null;
        }
    }

    private static string SummarizeScalableBufferManager()
    {
        var type = HookTargetCatalog.FindType(AppDomain.CurrentDomain.GetAssemblies(), "UnityEngine.ScalableBufferManager");
        if (type is null)
        {
            return "missing";
        }

        var width = TryReadStaticMember(type, "widthScaleFactor");
        var height = TryReadStaticMember(type, "heightScaleFactor");
        return $"widthScaleFactor={FormatValue(width)},heightScaleFactor={FormatValue(height)}";
    }

    private static float ResolveTargetPercentage(object? camera)
    {
        if (Settings.RenderScaleOverride > 0)
        {
            var outputHeight = TryReadFloat(camera, "pixelHeight") ?? TryReadFloat(camera, "scaledPixelHeight");
            if (outputHeight is > 0f)
            {
                return ClampPercentage(Settings.RenderScaleOverride * 100f / outputHeight.Value);
            }

            if (Settings.RenderScaleOverride <= 100)
            {
                return ClampPercentage(Settings.RenderScaleOverride);
            }
        }

        return ClampPercentage(Settings.QualityMode.Trim().Replace("-", string.Empty).Replace("_", string.Empty).ToLowerInvariant() switch
        {
            "dlaa" => DlaaRenderScalePercent,
            "quality" => QualityRenderScalePercent,
            "balanced" => BalancedRenderScalePercent,
            "ultraperformance" => UltraPerformanceRenderScalePercent,
            _ => PerformanceRenderScalePercent,
        });
    }

    private static string DescribeTargetScale(object? camera)
    {
        return FormatPercentage(ResolveTargetPercentage(camera));
    }

    private static float ClampPercentage(float percentage)
    {
        return Math.Clamp(percentage, 5f, 100f);
    }

    private static float? TryReadFloat(object? instance, string memberName)
    {
        if (instance is null)
        {
            return null;
        }

        try
        {
            var value = TryReadMember(instance, memberName);
            return value switch
            {
                int intValue => intValue,
                float floatValue => floatValue,
                double doubleValue => (float)doubleValue,
                _ => null
            };
        }
        catch
        {
            return null;
        }
    }

    private static uint ResolveDlssPerfQualityValue(string qualityMode)
    {
        var normalized = (qualityMode ?? string.Empty).Trim().Replace("-", string.Empty).Replace("_", string.Empty);
        return normalized.ToLowerInvariant() switch
        {
            "dlaa" => 5,
            "ultraperformance" => 3,
            "performance" => 0,
            "balanced" => 1,
            _ => 2,
        };
    }

    private static string SummarizeDynamicResolutionSettings(object settings)
    {
        var parts = new List<string>();
        foreach (var memberName in new[]
        {
            "enabled",
            "useMipBias",
            "enableDLSS",
            "DLSSPerfQualitySetting",
            "DLSSUseOptimalSettings",
            "maxPercentage",
            "minPercentage",
            "dynResType",
            "upsampleFilter",
            "forceResolution",
            "forcedPercentage"
        })
        {
            var value = TryReadMember(settings, memberName);
            if (value is not null)
            {
                parts.Add($"{memberName}={FormatValue(value)}");
            }
        }

        return parts.Count == 0 ? "unavailable" : string.Join(",", parts);
    }

    private static bool ValuesEqual(object? current, object expected)
    {
        if (current is null)
        {
            return false;
        }

        if (current is float currentFloat && expected is float expectedFloat)
        {
            return Math.Abs(currentFloat - expectedFloat) < 0.001f;
        }

        return current.Equals(expected);
    }

    private static bool ValueIsTrue(object? value)
    {
        return value is bool boolValue && boolValue;
    }

    private static string FormatInvocation(bool invoked, object? value, string error)
    {
        if (invoked)
        {
            return FormatValue(value);
        }

        return string.IsNullOrWhiteSpace(error) ? "unavailable" : $"unavailable({error})";
    }

    private static string FormatValue(object? value)
    {
        return value switch
        {
            null => "null",
            float floatValue => FormatPercentage(floatValue),
            double doubleValue => doubleValue.ToString("0.###", CultureInfo.InvariantCulture),
            _ => value.ToString() ?? "null"
        };
    }

    private static string FormatPercentage(float value)
    {
        return value.ToString("0.###", CultureInfo.InvariantCulture);
    }

    private static bool ShouldLog(int count)
    {
        return count <= MaxInitialLogs
            || count == 50
            || count == 100
            || count % 300 == 0;
    }

    private static bool ShouldLogScaleDetail()
    {
        lock (Sync)
        {
            ScaleLogCount++;
            return ScaleLogCount <= 8 || ScaleLogCount == 50 || ScaleLogCount % 300 == 0;
        }
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

    private readonly record struct RenderScaleSettings(string QualityMode, int RenderScaleOverride);
    private readonly record struct RenderScaleProbeTarget(string TypeName, IReadOnlyList<string> MemberNames);
}
