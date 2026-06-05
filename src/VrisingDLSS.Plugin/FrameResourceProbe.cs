using BepInEx.Logging;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace VrisingDLSS.Plugin;

internal static class FrameResourceProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".frame-resource-probe";
    private const int MaxInitialLogsPerMethod = 5;
    private const int MaxRenderGraphBuilderDeclarationLogs = 80;
    private const int MaxRenderGraphBuilderStackLogs = 12;
    private const int MaxRenderGraphExecutionScopeLogs = 80;
    private const int MaxRenderGraphScopedEvaluateAttempts = 12;
    private const int MaxExistingRenderFuncLogs = 80;
    private const int MaxExistingRenderFuncRegistryMissingLogs = 12;
    private const int MaxExistingRenderFuncEvaluateAttempts = 12;
    private const int MaxRenderGraphGetTextureLogs = 40;
    private const int MaxTextureSearchDepth = 3;
    private static readonly FrameProbeTarget[] Targets =
    {
        new("UnityEngine.Rendering.HighDefinition.CustomVignette", "Render"),
        new("UnityEngine.Rendering.HighDefinition.HDRenderPipeline", "UpdateShaderVariablesGlobalCB")
    };
    private static readonly object Sync = new();
    private static readonly Dictionary<string, int> CallCounts = new(StringComparer.Ordinal);
    private static int RenderGraphBuilderDeclarationCallCount;
    private static int RenderGraphExecutionScopeCallCount;
    private static int RenderGraphScopedEvaluateAttemptCount;
    private static int ExistingRenderFuncCallCount;
    private static int ExistingRenderFuncRegistryMissingCallCount;
    private static int ExistingRenderFuncEvaluateAttemptCount;
    private static int RenderGraphGetTextureCallCount;
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
    private static bool RenderGraphDiagnosticPassEnabled;
    private static bool ExistingRenderFuncProbeEnabled;
    private static bool DlssEvaluateInputProbeSucceeded;

    internal static void Install(
        ManualLogSource log,
        NativeBridge bridge,
        bool enableDlssEvaluateInputProbe = false,
        bool enableRenderGraphDiagnosticPass = false,
        bool enableExistingRenderFuncProbe = false)
    {
        if (Installed)
        {
            log.LogInfo("Frame resource probe is already installed.");
            DlssEvaluateInputProbeEnabled = DlssEvaluateInputProbeEnabled || enableDlssEvaluateInputProbe;
            RenderGraphDiagnosticPassEnabled = RenderGraphDiagnosticPassEnabled || enableRenderGraphDiagnosticPass;
            ExistingRenderFuncProbeEnabled = ExistingRenderFuncProbeEnabled || enableExistingRenderFuncProbe;
            return;
        }

        Log = log;
        Bridge = bridge;
        DlssEvaluateInputProbeEnabled = enableDlssEvaluateInputProbe;
        RenderGraphDiagnosticPassEnabled = enableRenderGraphDiagnosticPass;
        ExistingRenderFuncProbeEnabled = enableExistingRenderFuncProbe;
        DlssEvaluateInputProbeSucceeded = false;
        if (DlssEvaluateInputProbeEnabled)
        {
            log.LogInfo("DLSS evaluate input probe enabled.");
        }
        if (RenderGraphDiagnosticPassEnabled)
        {
            log.LogWarning("High-risk RenderGraph diagnostic pass injection is enabled. This route has caused a CoreCLR access violation in V Rising and should be used only for crash-recovery research.");
        }
        if (ExistingRenderFuncProbeEnabled)
        {
            log.LogWarning("High-risk existing HDRP render-func patching is enabled. This route has caused a CoreCLR access violation in V Rising and should be used only for crash-recovery research.");
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

            var renderGraphPatched = 0;
            foreach (var method in DiscoverRenderGraphFrameResourceMethods(assemblies))
            {
                if (TryPatchFrameResourceMethod(
                    log,
                    method,
                    harmonyMethodConstructor,
                    patchMethod,
                    prefix,
                    patchedMethodKeys,
                    "Frame resource RenderGraph candidate"))
                {
                    patched++;
                    renderGraphPatched++;
                }
            }

            log.LogInfo($"Frame resource RenderGraph candidate probe patched {renderGraphPatched} method(s).");

            var renderGraphBuilderPatched = TryPatchRenderGraphBuilderDeclarationMethods(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys);
            patched += renderGraphBuilderPatched;
            log.LogInfo($"Frame resource RenderGraph builder declaration probe patched {renderGraphBuilderPatched} method(s).");

            if (TryPatchRenderGraphExecutionScopeMethod(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys))
            {
                patched++;
            }

            if (TryPatchRenderGraphGetTextureMethod(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys))
            {
                patched++;
            }

            if (ExistingRenderFuncProbeEnabled)
            {
                var existingRenderFuncPatched = TryPatchExistingRenderFuncMethods(
                    log,
                    assemblies,
                    harmonyMethodConstructor,
                    patchMethod,
                    patchedMethodKeys);
                patched += existingRenderFuncPatched;
                log.LogInfo($"Frame resource existing HDRP render-func probe patched {existingRenderFuncPatched} method(s).");
            }
            else
            {
                log.LogInfo("Frame resource existing HDRP render-func probe skipped. Enable Diagnostics.EnableExistingRenderFuncProbe only for crash-recovery research.");
            }
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
            RenderGraphDiagnosticPassEnabled = false;
            ExistingRenderFuncProbeEnabled = false;
            DlssEvaluateInputProbeSucceeded = false;
            lock (Sync)
            {
                CallCounts.Clear();
                RenderGraphBuilderDeclarationCallCount = 0;
                RenderGraphExecutionScopeCallCount = 0;
                RenderGraphScopedEvaluateAttemptCount = 0;
                ExistingRenderFuncCallCount = 0;
                ExistingRenderFuncRegistryMissingCallCount = 0;
                ExistingRenderFuncEvaluateAttemptCount = 0;
                RenderGraphGetTextureCallCount = 0;
            }
        }
    }

    private static int TryPatchRenderGraphBuilderDeclarationMethods(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var prefix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphBuilderDeclarationPrefix), BindingFlags.NonPublic | BindingFlags.Static);
        if (prefix is null)
        {
            log.LogWarning("Frame resource RenderGraph builder declaration prefix target was not found.");
            return 0;
        }

        var patched = 0;
        foreach (var method in DiscoverRenderGraphBuilderDeclarationMethods(assemblies))
        {
            if (TryPatchFrameResourceMethod(
                log,
                method,
                harmonyMethodConstructor,
                patchMethod,
                prefix,
                patchedMethodKeys,
                "Frame resource RenderGraph builder declaration"))
            {
                patched++;
            }
        }

        return patched;
    }

    private static bool TryPatchRenderGraphGetTextureMethod(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var method = FindRenderGraphGetTextureMethod(assemblies);
        var postfix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphGetTexturePostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (method is null || postfix is null || !CanPatch(method))
        {
            log.LogWarning("Frame resource RenderGraph GetTexture postfix target was not found.");
            return false;
        }

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
            log.LogInfo($"Frame resource RenderGraph GetTexture postfix patched: {HookTargetCatalog.FormatMethod(method)}");
            return true;
        }
        catch (Exception ex)
        {
            log.LogWarning($"Frame resource RenderGraph GetTexture postfix failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
            return false;
        }
    }

    private static bool TryPatchRenderGraphExecutionScopeMethod(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var method = FindRenderGraphExecutionScopeMethod(assemblies);
        var postfix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphExecutionScopePostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (method is null || postfix is null || !CanPatch(method))
        {
            log.LogWarning("Frame resource RenderGraph execution scope target was not found.");
            return false;
        }

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
            log.LogInfo($"Frame resource RenderGraph execution scope patched: {HookTargetCatalog.FormatMethod(method)}");
            return true;
        }
        catch (Exception ex)
        {
            log.LogWarning($"Frame resource RenderGraph execution scope failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
            return false;
        }
    }

    private static int TryPatchExistingRenderFuncMethods(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var postfix = typeof(FrameResourceProbe).GetMethod(nameof(ExistingRenderFuncPostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (postfix is null)
        {
            log.LogWarning("Frame resource existing HDRP render-func postfix target was not found.");
            return 0;
        }

        var patched = 0;
        foreach (var method in DiscoverExistingRenderFuncMethods(assemblies))
        {
            if (TryPatchPostfixMethod(
                log,
                method,
                harmonyMethodConstructor,
                patchMethod,
                postfix,
                patchedMethodKeys,
                "Frame resource existing HDRP render-func"))
            {
                patched++;
            }
        }

        return patched;
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

    private static bool TryPatchPostfixMethod(
        ManualLogSource log,
        MethodInfo method,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        MethodInfo postfix,
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

    private static IEnumerable<MethodInfo> DiscoverRenderGraphFrameResourceMethods(IEnumerable<Assembly> assemblies)
    {
        foreach (var assembly in assemblies)
        {
            if (!IsRenderGraphProbeAssembly(assembly))
            {
                continue;
            }

            foreach (var type in SafeGetTypes(assembly))
            {
                foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                {
                    if (IsRenderGraphFrameResourceMethod(method))
                    {
                        yield return method;
                    }
                }
            }
        }
    }

    private static bool IsRenderGraphProbeAssembly(Assembly assembly)
    {
        var name = assembly.GetName().Name ?? string.Empty;
        return name.Equals("Unity.RenderPipelines.HighDefinition.Runtime", StringComparison.Ordinal);
    }

    private static bool IsRenderGraphFrameResourceMethod(MethodInfo method)
    {
        if (!IsRenderGraphCandidateName(method.Name))
        {
            return false;
        }

        var parameters = method.GetParameters();
        return parameters.Any(parameter => TypeNameContains(parameter.ParameterType, "RenderGraph"))
            && parameters.Any(parameter => TypeNameContains(parameter.ParameterType, "TextureHandle"))
            && parameters.Any(parameter => TypeNameContains(parameter.ParameterType, "HDCamera") || TypeNameContains(parameter.ParameterType, "PrepassOutput"));
    }

    private static bool IsRenderGraphCandidateName(string methodName)
    {
        return string.Equals(methodName, "RenderPostProcess", StringComparison.Ordinal)
            || string.Equals(methodName, "DoCustomPostProcess", StringComparison.Ordinal)
            || string.Equals(methodName, "BlitFinalCameraTexture", StringComparison.Ordinal)
            || string.Equals(methodName, "RenderAfterPostProcessObjects", StringComparison.Ordinal)
            || string.Equals(methodName, "RenderCameraMotionVectors", StringComparison.Ordinal)
            || string.Equals(methodName, "ResolveMotionVector", StringComparison.Ordinal)
            || string.Equals(methodName, "BlitCameraTexture_Internal", StringComparison.Ordinal)
            || string.Equals(methodName, "GetPostprocessOutputHandle", StringComparison.Ordinal)
            || string.Equals(methodName, "GetPostprocessUpsampledOutputHandle", StringComparison.Ordinal);
    }

    private static IEnumerable<MethodInfo> DiscoverExistingRenderFuncMethods(IEnumerable<Assembly> assemblies)
    {
        foreach (var assembly in assemblies)
        {
            if (!IsRenderGraphProbeAssembly(assembly))
            {
                continue;
            }

            foreach (var type in SafeGetTypes(assembly))
            {
                if (!string.Equals(type.Name, "__c", StringComparison.Ordinal)
                    || type.FullName?.IndexOf("HDRenderPipeline", StringComparison.Ordinal) < 0)
                {
                    continue;
                }

                foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                {
                    if (IsExistingRenderFuncMethod(method))
                    {
                        yield return method;
                    }
                }
            }
        }
    }

    private static bool IsExistingRenderFuncMethod(MethodInfo method)
    {
        if (!ExistingRenderFuncNameLooksUseful(method.Name))
        {
            return false;
        }

        var parameters = method.GetParameters();
        if (parameters.Length != 2 || !TypeNameContains(parameters[1].ParameterType, "RenderGraphContext"))
        {
            return false;
        }

        return HasUsefulTextureHandleMembers(parameters[0].ParameterType);
    }

    private static bool ExistingRenderFuncNameLooksUseful(string methodName)
    {
        return methodName.IndexOf("DoCustomPostProcess", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("DoDLSSPass", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("DoDLSSColorMaskPass", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("TemporalAntiAliasing", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("DoTemporalAntialiasing", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("MotionBlurPass", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("FXAAPass", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("SMAAPass", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("UberPass", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("FinalPass", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("BlitFinalCameraTexture", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("RenderCameraMotionVectors", StringComparison.Ordinal) >= 0
            || methodName.IndexOf("ResolveMotionVector", StringComparison.Ordinal) >= 0;
    }

    private static bool HasUsefulTextureHandleMembers(Type type)
    {
        if (CountDirectTextureHandleMembers(type) >= 2)
        {
            return true;
        }

        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
        return type.GetFields(flags)
            .Any(field => MemberTypeHasUsefulTextureHandles(field.Name, field.FieldType))
            || type.GetProperties(flags)
                .Any(property => property.GetIndexParameters().Length == 0
                    && property.GetMethod is not null
                    && MemberTypeHasUsefulTextureHandles(property.Name, property.PropertyType));
    }

    private static bool MemberTypeHasUsefulTextureHandles(string name, Type type)
    {
        return MemberMayContainTextureHandle(name, type)
            && (TypeNameContains(type, "TextureHandle")
                || CountDirectTextureHandleMembers(type) >= 2);
    }

    private static int CountDirectTextureHandleMembers(Type type)
    {
        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
        var fields = type.GetFields(flags)
            .Count(field => TypeNameContains(field.FieldType, "TextureHandle"));
        var properties = type.GetProperties(flags)
            .Count(property => property.GetIndexParameters().Length == 0
                && property.GetMethod is not null
                && TypeNameContains(property.PropertyType, "TextureHandle"));

        return fields + properties;
    }

    private static MethodInfo? FindRenderGraphGetTextureMethod(IEnumerable<Assembly> assemblies)
    {
        var registryType = FindRuntimeType(
            assemblies,
            "UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphResourceRegistry");
        if (registryType is null)
        {
            return null;
        }

        return registryType
            .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
            .FirstOrDefault(method =>
            {
                if (!string.Equals(method.Name, "GetTexture", StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 1
                    && parameters[0].ParameterType.IsByRef
                    && TypeNameContains(parameters[0].ParameterType.GetElementType()!, "TextureHandle");
            });
    }

    private static MethodInfo? FindRenderGraphExecutionScopeMethod(IEnumerable<Assembly> assemblies)
    {
        var renderGraphType = FindRuntimeType(
            assemblies,
            "UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraph");
        if (renderGraphType is null)
        {
            return null;
        }

        return renderGraphType
            .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
            .FirstOrDefault(method =>
            {
                if (!string.Equals(method.Name, "PreRenderPassExecute", StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 3
                    && parameters[0].ParameterType.IsByRef
                    && TypeNameContains(parameters[0].ParameterType.GetElementType()!, "CompiledPassInfo")
                    && TypeNameContains(parameters[1].ParameterType, "RenderGraphPass")
                    && TypeNameContains(parameters[2].ParameterType, "RenderGraphContext");
            });
    }

    private static IEnumerable<MethodInfo> DiscoverRenderGraphBuilderDeclarationMethods(IEnumerable<Assembly> assemblies)
    {
        var builderType = FindRuntimeType(
            assemblies,
            "UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphBuilder");
        if (builderType is null)
        {
            yield break;
        }

        foreach (var method in builderType.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            if (IsRenderGraphBuilderDeclarationMethod(method))
            {
                yield return method;
            }
        }
    }

    private static bool IsRenderGraphBuilderDeclarationMethod(MethodInfo method)
    {
        if (method.ContainsGenericParameters)
        {
            return false;
        }

        if (!string.Equals(method.Name, "UseColorBuffer", StringComparison.Ordinal)
            && !string.Equals(method.Name, "UseDepthBuffer", StringComparison.Ordinal)
            && !string.Equals(method.Name, "ReadTexture", StringComparison.Ordinal)
            && !string.Equals(method.Name, "WriteTexture", StringComparison.Ordinal)
            && !string.Equals(method.Name, "ReadWriteTexture", StringComparison.Ordinal))
        {
            return false;
        }

        return method.GetParameters().Any(parameter =>
            parameter.ParameterType.IsByRef
            && TypeNameContains(parameter.ParameterType.GetElementType()!, "TextureHandle"));
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

#if VRISINGDLSS_LOCAL_INTEROP
            if (DlssEvaluateInputProbeEnabled && RenderGraphDiagnosticPassEnabled)
            {
                RenderGraphDiagnosticPass.TryInject(log, bridge, __originalMethod, __args);
            }
#endif

            if (!ShouldInspect(count))
            {
                return;
            }

            log.LogInfo($"Frame resource probe call #{count}: {key}");
            var renderGraph = FindRenderGraphArgument(__args);
            if (__args is not null)
            {
                for (var index = 0; index < __args.Length; index++)
                {
                    ProbeTextureCandidate(log, bridge, $"arg{index}", __args[index], renderGraph);
                }
            }

            foreach (var globalTextureName in GlobalTextureNames)
            {
                var texture = TryGetGlobalTexture(globalTextureName);
                ProbeTextureCandidate(log, bridge, $"global:{globalTextureName}", texture);
            }

            TryRunDlssEvaluateInputProbe(log, bridge, __originalMethod, __args, renderGraph);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"Frame resource probe prefix failed: {GetExceptionMessage(ex)}");
        }
    }

    internal static void MarkDlssEvaluateInputProbeSucceeded()
    {
        DlssEvaluateInputProbeSucceeded = true;
    }

    private static void RenderGraphBuilderDeclarationPrefix(MethodBase __originalMethod, object? __instance, object?[]? __args)
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
                RenderGraphBuilderDeclarationCallCount++;
                count = RenderGraphBuilderDeclarationCallCount;
            }

#if VRISINGDLSS_LOCAL_INTEROP
            if (DlssEvaluateInputProbeEnabled
                && RenderGraphDiagnosticPassEnabled
                && Bridge is { } bridge
                && TryGetRenderGraphBuilderDeclarationDetails(__instance, __args, out var textureHandle, out var resourceName))
            {
                RenderGraphDiagnosticPass.ObserveBuilderDeclaration(log, bridge, __instance, textureHandle, resourceName);
            }
#endif

            if (count > MaxRenderGraphBuilderDeclarationLogs && count % 300 != 0)
            {
                return;
            }

            log.LogInfo($"RenderGraph builder declaration #{count}: {HookTargetCatalog.FormatMethod(__originalMethod)}; args=[{SummarizeArguments(__args)}]{DescribeRenderGraphBuilderDeclaration(__instance, __args)}");
            if (count <= MaxRenderGraphBuilderStackLogs)
            {
                log.LogInfo($"RenderGraph builder declaration caller #{count}: {GetManagedCallerSummary()}");
            }
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph builder declaration prefix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void RenderGraphExecutionScopePostfix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        try
        {
            if (!DlssEvaluateInputProbeEnabled)
            {
                return;
            }

            var log = Log;
            var bridge = Bridge;
            if (log is null || bridge is null || __instance is null)
            {
                return;
            }

            var pass = FindTypedArgument(__args, "RenderGraphPass");
            if (pass is null)
            {
                return;
            }

            var registry = TryReadPropertyObject(__instance, "m_Resources")
                ?? TryReadFieldObject(__instance, "m_Resources");
            if (registry is null)
            {
                return;
            }

            int count;
            lock (Sync)
            {
                RenderGraphExecutionScopeCallCount++;
                count = RenderGraphExecutionScopeCallCount;
            }

            var passName = GetRenderGraphPassName(pass);
            var candidates = CollectRenderGraphExecutionTextureCandidates(registry, pass);
            if (candidates.Count == 0)
            {
                if (count <= MaxRenderGraphExecutionScopeLogs || count % 300 == 0)
                {
                    log.LogInfo($"RenderGraph execution scope #{count}: pass={passName}; candidates=none");
                }

                return;
            }

            if (count <= MaxRenderGraphExecutionScopeLogs || count % 300 == 0)
            {
                log.LogInfo($"RenderGraph execution scope #{count}: pass={passName}; candidates=[{FormatRenderGraphTextureCandidates(candidates)}]");
            }

            TryRunRenderGraphScopedDlssEvaluateInputProbe(log, bridge, pass, candidates);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph execution scope postfix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void ExistingRenderFuncPostfix(MethodBase __originalMethod, object?[]? __args)
    {
        try
        {
            if (!DlssEvaluateInputProbeEnabled || DlssEvaluateInputProbeSucceeded)
            {
                return;
            }

            var log = Log;
            var bridge = Bridge;
            if (log is null || bridge is null || __args is null || __args.Length < 2)
            {
                return;
            }

            var passData = __args.FirstOrDefault(arg => arg is not null && !TypeNameContains(arg.GetType(), "RenderGraphContext"));
            if (passData is null)
            {
                return;
            }

            var methodLabel = HookTargetCatalog.FormatMethod(__originalMethod);
            var registry = TryGetCurrentRenderGraphRegistry();
            if (registry is null)
            {
                int missingCount;
                lock (Sync)
                {
                    ExistingRenderFuncRegistryMissingCallCount++;
                    missingCount = ExistingRenderFuncRegistryMissingCallCount;
                }

                if (missingCount <= MaxExistingRenderFuncRegistryMissingLogs || missingCount % 300 == 0)
                {
                    log.LogInfo($"Existing HDRP render-func scope without current registry #{missingCount}: method={methodLabel}; passData={SummarizeValue(passData)}");
                }

                return;
            }

            int count;
            lock (Sync)
            {
                ExistingRenderFuncCallCount++;
                count = ExistingRenderFuncCallCount;
            }

            var candidates = CollectExistingRenderFuncTextureCandidates(registry, passData);
            if (candidates.Count == 0)
            {
                if (count <= MaxExistingRenderFuncLogs || count % 300 == 0)
                {
                    log.LogInfo($"Existing HDRP render-func scope #{count}: method={methodLabel}; candidates=none");
                }

                return;
            }

            if (count <= MaxExistingRenderFuncLogs || count % 300 == 0)
            {
                log.LogInfo($"Existing HDRP render-func scope #{count}: method={methodLabel}; candidates=[{FormatRenderGraphTextureCandidates(candidates)}]");
            }

            TryRunExistingRenderFuncDlssEvaluateInputProbe(log, bridge, methodLabel, candidates);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"Existing HDRP render-func postfix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void RenderGraphGetTexturePostfix(MethodBase __originalMethod, object? __instance, object?[]? __args, object? __result)
    {
        try
        {
            var log = Log;
            var bridge = Bridge;
            if (log is null || bridge is null)
            {
                return;
            }

            int count;
            lock (Sync)
            {
                RenderGraphGetTextureCallCount++;
                count = RenderGraphGetTextureCallCount;
            }

            if (count > MaxRenderGraphGetTextureLogs && count % 300 != 0)
            {
                return;
            }

            var handle = __args is { Length: > 0 } ? __args[0] : null;
            var handleSummary = SummarizeValue(handle);
            var resultSummary = SummarizeValue(__result);
            if (__result is null)
            {
                log.LogInfo($"RenderGraph GetTexture call #{count}: handle={handleSummary}; result=null; nativePtr=not found");
                return;
            }

            if (!TryFindNativeTexturePtr(__result, out var owner, out var pointer) || pointer == IntPtr.Zero)
            {
                log.LogInfo($"RenderGraph GetTexture call #{count}: handle={handleSummary}; result={resultSummary}; nativePtr=not found");
                return;
            }

            var ownerSummary = owner is null ? "unknown" : SummarizeValue(owner);
            log.LogInfo($"RenderGraph GetTexture call #{count}: handle={handleSummary}; result={resultSummary}; nativeOwner={ownerSummary}; nativePtr=0x{pointer.ToInt64():X}");
            var success = bridge.ProbeD3D11Texture(pointer);
            var status = bridge.GetD3D11ProbeStatus();
            if (success)
            {
                log.LogInfo($"RenderGraph GetTexture call #{count}: D3D11 probe succeeded: {status}");
            }
            else
            {
                log.LogWarning($"RenderGraph GetTexture call #{count}: D3D11 probe failed: {status}");
            }
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph GetTexture postfix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void TryRunDlssEvaluateInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        MethodBase originalMethod,
        object?[]? args,
        object? renderGraph)
    {
        if (!DlssEvaluateInputProbeEnabled || DlssEvaluateInputProbeSucceeded)
        {
            return;
        }

        var methodLabel = HookTargetCatalog.FormatMethod(originalMethod);
        var argumentTextures = CollectArgumentTextureCandidates(originalMethod, args, renderGraph);
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

    private static void TryRunRenderGraphScopedDlssEvaluateInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        object pass,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (DlssEvaluateInputProbeSucceeded)
        {
            return;
        }

        var color = FindCandidate(candidates, static name => string.Equals(name, "CameraColor", StringComparison.Ordinal));
        var depth = FindCandidate(candidates, static name => string.Equals(name, "CameraDepthStencil", StringComparison.Ordinal)
            || name.IndexOf("CameraDepth", StringComparison.OrdinalIgnoreCase) >= 0);
        var motion = FindCandidate(candidates, static name => string.Equals(name, "Motion Vectors", StringComparison.Ordinal));

        if (color is null || depth is null || motion is null)
        {
            return;
        }

        var output = candidates
            .Where(candidate => candidate.Pointer != IntPtr.Zero)
            .Where(candidate => string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal))
            .OrderByDescending(candidate => candidate.Label.StartsWith("color", StringComparison.OrdinalIgnoreCase)
                || candidate.Label.StartsWith("write", StringComparison.OrdinalIgnoreCase))
            .FirstOrDefault();
        var outputIsPlaceholder = output.Pointer == IntPtr.Zero;
        if (outputIsPlaceholder)
        {
            output = color.Value;
        }
        else
        {
            outputIsPlaceholder = output.Pointer == color.Value.Pointer;
        }

        int attempt;
        lock (Sync)
        {
            if (RenderGraphScopedEvaluateAttemptCount >= MaxRenderGraphScopedEvaluateAttempts)
            {
                return;
            }

            RenderGraphScopedEvaluateAttemptCount++;
            attempt = RenderGraphScopedEvaluateAttemptCount;
        }

        var passName = GetRenderGraphPassName(pass);
        log.LogInfo(
            $"DLSS evaluate input probe RenderGraph-scope candidate #{attempt}: pass={passName}; color={color.Value.Label}/{color.Value.ResourceName} 0x{color.Value.Pointer.ToInt64():X}; output={output.Label}/{output.ResourceName} 0x{output.Pointer.ToInt64():X}{(outputIsPlaceholder ? " placeholder=same-as-color" : string.Empty)}; depth={depth.Value.Label}/{depth.Value.ResourceName} 0x{depth.Value.Pointer.ToInt64():X}; motion={motion.Value.Label}/{motion.Value.ResourceName} 0x{motion.Value.Pointer.ToInt64():X}");

        var success = bridge.ProbeDlssEvaluateInputs(
            color.Value.Pointer,
            output.Pointer,
            depth.Value.Pointer,
            motion.Value.Pointer);
        var status = bridge.GetDlssEvaluateInputStatus();
        if (success)
        {
            DlssEvaluateInputProbeSucceeded = true;
            log.LogInfo($"DLSS evaluate input probe succeeded from RenderGraph execution scope: {status}");
        }
        else
        {
            log.LogWarning($"DLSS evaluate input probe failed from RenderGraph execution scope: {status}");
        }
    }

    private static void TryRunExistingRenderFuncDlssEvaluateInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string methodLabel,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (DlssEvaluateInputProbeSucceeded)
        {
            return;
        }

        var available = candidates.Where(candidate => candidate.Pointer != IntPtr.Zero).ToArray();
        var color = FindExistingRenderFuncCandidate(available, static candidate =>
            CandidateNameContains(candidate, "source")
            || CandidateNameContains(candidate, "color")
            || string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal));
        var output = FindExistingRenderFuncCandidate(available, static candidate =>
            CandidateNameContains(candidate, "destination")
            || CandidateNameContains(candidate, "output")
            || CandidateNameContains(candidate, "target"));
        var depth = FindExistingRenderFuncCandidate(available, static candidate =>
            CandidateNameContains(candidate, "depth")
            || string.Equals(candidate.ResourceName, "CameraDepthStencil", StringComparison.Ordinal));
        var motion = FindExistingRenderFuncCandidate(available, static candidate =>
            CandidateNameContains(candidate, "motion")
            || string.Equals(candidate.ResourceName, "Motion Vectors", StringComparison.Ordinal));

        if (color is null || output is null || depth is null || motion is null)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (ExistingRenderFuncEvaluateAttemptCount >= MaxExistingRenderFuncEvaluateAttempts)
            {
                return;
            }

            ExistingRenderFuncEvaluateAttemptCount++;
            attempt = ExistingRenderFuncEvaluateAttemptCount;
        }

        var outputSameAsColor = output.Value.Pointer == color.Value.Pointer;
        log.LogInfo(
            $"DLSS evaluate input probe existing HDRP render-func candidate #{attempt}: method={methodLabel}; color={color.Value.Label}/{color.Value.ResourceName} 0x{color.Value.Pointer.ToInt64():X}; output={output.Value.Label}/{output.Value.ResourceName} 0x{output.Value.Pointer.ToInt64():X}{(outputSameAsColor ? " same-as-color" : string.Empty)}; depth={depth.Value.Label}/{depth.Value.ResourceName} 0x{depth.Value.Pointer.ToInt64():X}; motion={motion.Value.Label}/{motion.Value.ResourceName} 0x{motion.Value.Pointer.ToInt64():X}");

        var success = bridge.ProbeDlssEvaluateInputs(
            color.Value.Pointer,
            output.Value.Pointer,
            depth.Value.Pointer,
            motion.Value.Pointer);
        var status = bridge.GetDlssEvaluateInputStatus();
        if (success)
        {
            DlssEvaluateInputProbeSucceeded = true;
            log.LogInfo($"DLSS evaluate input probe succeeded from existing HDRP render-func: {status}");
        }
        else
        {
            log.LogWarning($"DLSS evaluate input probe failed from existing HDRP render-func: {status}");
        }
    }

    private static IReadOnlyList<NativeTextureCandidate> CollectArgumentTextureCandidates(MethodBase originalMethod, object?[]? args, object? renderGraph)
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

            if (!TryFindNativeTexturePtr(arg, renderGraph, out _, out var pointer) || pointer == IntPtr.Zero)
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

    private static IReadOnlyList<RenderGraphTextureCandidate> CollectRenderGraphExecutionTextureCandidates(object registry, object pass)
    {
        var candidates = new List<RenderGraphTextureCandidate>();
        var seen = new HashSet<string>(StringComparer.Ordinal);

        var colorBuffers = TryReadPropertyObject(pass, "colorBuffers")
            ?? TryReadFieldObject(pass, "_colorBuffers_k__BackingField");
        var colorIndex = 0;
        foreach (var colorBuffer in EnumerateRuntimeSequence(colorBuffers))
        {
            AddTextureHandleCandidate(registry, $"color[{colorIndex}]", colorBuffer, candidates, seen);
            colorIndex++;
        }

        var depthBuffer = TryReadPropertyObject(pass, "depthBuffer")
            ?? TryReadFieldObject(pass, "_depthBuffer_k__BackingField");
        AddTextureHandleCandidate(registry, "depth", depthBuffer, candidates, seen);

        var resourceReadLists = TryReadPropertyObject(pass, "resourceReadLists")
            ?? TryReadFieldObject(pass, "resourceReadLists");
        AddResourceListCandidates(registry, "read", resourceReadLists, candidates, seen);

        var resourceWriteLists = TryReadPropertyObject(pass, "resourceWriteLists")
            ?? TryReadFieldObject(pass, "resourceWriteLists");
        AddResourceListCandidates(registry, "write", resourceWriteLists, candidates, seen);

        return candidates;
    }

    private static IReadOnlyList<RenderGraphTextureCandidate> CollectExistingRenderFuncTextureCandidates(object registry, object passData)
    {
        var candidates = new List<RenderGraphTextureCandidate>();
        var seenCandidates = new HashSet<string>(StringComparer.Ordinal);
        var seenObjects = new HashSet<int>();

        foreach (var textureHandle in EnumerateNamedTextureHandles(passData.GetType().Name, passData, 0, seenObjects))
        {
            AddTextureHandleCandidate(registry, textureHandle.Label, textureHandle.Value, candidates, seenCandidates, includeNonCanonical: true);
        }

        return candidates;
    }

    private static IEnumerable<NamedTextureHandleCandidate> EnumerateNamedTextureHandles(
        string label,
        object? value,
        int depth,
        ISet<int> seenObjects)
    {
        if (value is null || depth > 3)
        {
            yield break;
        }

        var type = value.GetType();
        if (TypeNameContains(type, "TextureHandle"))
        {
            yield return new NamedTextureHandleCandidate(label, value);
            yield break;
        }

        if (!type.IsValueType && !seenObjects.Add(RuntimeHelpers.GetHashCode(value)))
        {
            yield break;
        }

        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
        foreach (var field in type.GetFields(flags))
        {
            if (!MemberMayContainTextureHandle(field.Name, field.FieldType))
            {
                continue;
            }

            object? fieldValue;
            try
            {
                fieldValue = field.GetValue(value);
            }
            catch
            {
                continue;
            }

            foreach (var nested in EnumerateNamedTextureHandles($"{label}.{field.Name}", fieldValue, depth + 1, seenObjects))
            {
                yield return nested;
            }
        }

        foreach (var property in type.GetProperties(flags))
        {
            if (property.GetIndexParameters().Length != 0
                || property.GetMethod is null
                || !MemberMayContainTextureHandle(property.Name, property.PropertyType))
            {
                continue;
            }

            object? propertyValue;
            try
            {
                propertyValue = property.GetValue(value);
            }
            catch
            {
                continue;
            }

            foreach (var nested in EnumerateNamedTextureHandles($"{label}.{property.Name}", propertyValue, depth + 1, seenObjects))
            {
                yield return nested;
            }
        }
    }

    private static bool MemberMayContainTextureHandle(string name, Type type)
    {
        return TypeNameContains(type, "TextureHandle")
            || TypeNameContains(type, "ResourceHandles")
            || name.IndexOf("resource", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("source", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("destination", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("output", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("depth", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("motion", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("color", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static void AddResourceListCandidates(
        object registry,
        string labelPrefix,
        object? resourceLists,
        ICollection<RenderGraphTextureCandidate> candidates,
        ISet<string> seen)
    {
        var listIndex = 0;
        foreach (var resourceList in EnumerateRuntimeSequence(resourceLists))
        {
            var itemIndex = 0;
            foreach (var resourceHandle in EnumerateRuntimeSequence(resourceList))
            {
                AddResourceHandleCandidate(registry, $"{labelPrefix}[{listIndex}:{itemIndex}]", resourceHandle, candidates, seen);
                itemIndex++;
            }

            listIndex++;
        }
    }

    private static void AddTextureHandleCandidate(
        object registry,
        string label,
        object? textureHandle,
        ICollection<RenderGraphTextureCandidate> candidates,
        ISet<string> seen,
        bool includeNonCanonical = false)
    {
        if (textureHandle is null || !TypeNameContains(textureHandle.GetType(), "TextureHandle"))
        {
            return;
        }

        var resourceHandle = TryGetResourceHandleFromTextureHandle(textureHandle);
        if (resourceHandle is null)
        {
            return;
        }

        var resourceName = TryGetRenderGraphResourceName(registry, resourceHandle);
        if (!includeNonCanonical && !IsRenderGraphDlssRelevantResource(resourceName))
        {
            return;
        }

        AddRenderGraphTextureCandidate(registry, label, resourceName ?? label, textureHandle, resourceHandle, candidates, seen);
    }

    private static void AddResourceHandleCandidate(
        object registry,
        string label,
        object? resourceHandle,
        ICollection<RenderGraphTextureCandidate> candidates,
        ISet<string> seen)
    {
        if (resourceHandle is null || !TypeNameContains(resourceHandle.GetType(), "ResourceHandle"))
        {
            return;
        }

        if (!IsTextureResourceHandle(resourceHandle))
        {
            return;
        }

        var resourceName = TryGetRenderGraphResourceName(registry, resourceHandle);
        if (!IsRenderGraphDlssRelevantResource(resourceName))
        {
            return;
        }

        AddRenderGraphTextureCandidate(registry, label, resourceName!, null, resourceHandle, candidates, seen);
    }

    private static void AddRenderGraphTextureCandidate(
        object registry,
        string label,
        string resourceName,
        object? textureHandle,
        object resourceHandle,
        ICollection<RenderGraphTextureCandidate> candidates,
        ISet<string> seen)
    {
        var key = $"{label}:{resourceName}:{SummarizeValue(resourceHandle)}";
        if (!seen.Add(key))
        {
            return;
        }

        var status = new List<string>();
        object? owner = null;
        var pointer = IntPtr.Zero;

        var graphicsResource = TryGetRenderGraphTextureResourceGraphicsResource(registry, resourceHandle, out var resourceStatus);
        status.Add(resourceStatus);
        if (graphicsResource is not null && TryFindNativeTexturePtr(graphicsResource, out owner, out pointer) && pointer != IntPtr.Zero)
        {
            candidates.Add(new RenderGraphTextureCandidate(label, resourceName, pointer, $"TextureResource.graphicsResource nativeOwner={SummarizeValue(owner ?? graphicsResource)}"));
            return;
        }

        if (textureHandle is not null)
        {
            var texture = TryGetRenderGraphTexture(registry, textureHandle, out var textureStatus);
            status.Add(textureStatus);
            if (texture is not null && TryFindNativeTexturePtr(texture, out owner, out pointer) && pointer != IntPtr.Zero)
            {
                candidates.Add(new RenderGraphTextureCandidate(label, resourceName, pointer, $"GetTexture nativeOwner={SummarizeValue(owner ?? texture)}"));
                return;
            }
        }

        candidates.Add(new RenderGraphTextureCandidate(label, resourceName, IntPtr.Zero, string.Join("; ", status.Where(value => !string.IsNullOrWhiteSpace(value)))));
    }

    private static RenderGraphTextureCandidate? FindCandidate(IReadOnlyList<RenderGraphTextureCandidate> candidates, Func<string, bool> predicate)
    {
        var candidate = candidates
            .Where(candidate => candidate.Pointer != IntPtr.Zero)
            .FirstOrDefault(candidate => predicate(candidate.ResourceName));
        return candidate.Pointer == IntPtr.Zero ? null : candidate;
    }

    private static RenderGraphTextureCandidate? FindExistingRenderFuncCandidate(
        IEnumerable<RenderGraphTextureCandidate> candidates,
        Func<RenderGraphTextureCandidate, bool> predicate)
    {
        var candidate = candidates.FirstOrDefault(predicate);
        return candidate.Pointer == IntPtr.Zero ? null : candidate;
    }

    private static bool CandidateNameContains(RenderGraphTextureCandidate candidate, string value)
    {
        return candidate.Label.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0
            || candidate.ResourceName.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static object? TryGetCurrentRenderGraphRegistry()
    {
        var registryType = FindRuntimeType(
            AppDomain.CurrentDomain.GetAssemblies(),
            "UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphResourceRegistry");
        if (registryType is null)
        {
            return null;
        }

        foreach (var propertyName in new[] { "current", "m_CurrentRegistry" })
        {
            var current = TryReadStaticPropertyObject(registryType, propertyName);
            if (current is not null)
            {
                return current;
            }
        }

        foreach (var fieldName in new[] { "m_CurrentRegistry", "current" })
        {
            var current = TryReadStaticFieldObject(registryType, fieldName);
            if (current is not null)
            {
                return current;
            }
        }

        return null;
    }

    private static object? TryGetResourceHandleFromTextureHandle(object textureHandle)
    {
        return TryReadPropertyObject(textureHandle, "handle")
            ?? TryReadFieldObject(textureHandle, "handle");
    }

    private static object? TryGetRenderGraphTexture(object registry, object textureHandle, out string status)
    {
        var method = FindByRefResourceMethod(registry, "GetTexture", textureHandle);
        if (method is null)
        {
            status = "GetTexture missing";
            return null;
        }

        try
        {
            var texture = method.Invoke(registry, new[] { textureHandle });
            status = texture is null ? "GetTexture returned null" : $"GetTexture returned {SummarizeValue(texture)}";
            return texture;
        }
        catch (Exception ex)
        {
            status = $"GetTexture threw {FirstLine(GetExceptionMessage(ex))}";
            return null;
        }
    }

    private static object? TryGetRenderGraphTextureResourceGraphicsResource(object registry, object resourceHandle, out string status)
    {
        var method = FindByRefResourceMethod(registry, "GetTextureResource", resourceHandle);
        if (method is null)
        {
            status = "GetTextureResource missing";
            return null;
        }

        try
        {
            var textureResource = method.Invoke(registry, new[] { resourceHandle });
            if (textureResource is null)
            {
                status = "GetTextureResource returned null";
                return null;
            }

            var graphicsResource = TryReadPropertyObject(textureResource, "graphicsResource")
                ?? TryReadFieldObject(textureResource, "graphicsResource");
            status = graphicsResource is null
                ? $"GetTextureResource returned {SummarizeValue(textureResource)}; graphicsResource=null"
                : $"GetTextureResource returned {SummarizeValue(textureResource)}; graphicsResource={SummarizeValue(graphicsResource)}";
            return graphicsResource;
        }
        catch (Exception ex)
        {
            status = $"GetTextureResource threw {FirstLine(GetExceptionMessage(ex))}";
            return null;
        }
    }

    private static bool IsTextureResourceHandle(object resourceHandle)
    {
        var type = TryReadPropertyString(resourceHandle, "type")
            ?? TryReadFieldString(resourceHandle, "_type_k__BackingField");
        var iType = TryReadPropertyString(resourceHandle, "iType");
        return string.Equals(type, "Texture", StringComparison.Ordinal)
            || string.Equals(iType, "0", StringComparison.Ordinal);
    }

    private static bool IsRenderGraphDlssRelevantResource(string? resourceName)
    {
        return string.Equals(resourceName, "CameraColor", StringComparison.Ordinal)
            || string.Equals(resourceName, "CameraDepthStencil", StringComparison.Ordinal)
            || string.Equals(resourceName, "Motion Vectors", StringComparison.Ordinal)
            || string.Equals(resourceName, "NormalBuffer", StringComparison.Ordinal);
    }

    private static object? FindTypedArgument(object?[]? args, string typeNamePart)
    {
        if (args is null)
        {
            return null;
        }

        foreach (var arg in args)
        {
            if (arg is not null && TypeNameContains(arg.GetType(), typeNamePart))
            {
                return arg;
            }
        }

        return null;
    }

    private static string GetRenderGraphPassName(object pass)
    {
        return TryReadPropertyString(pass, "name")
            ?? TryReadFieldString(pass, "_name_k__BackingField")
            ?? SummarizeValue(pass);
    }

    private static string FormatRenderGraphTextureCandidates(IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        return string.Join("; ", candidates
            .Take(16)
            .Select(candidate => candidate.Pointer == IntPtr.Zero
                ? $"{candidate.Label}/{candidate.ResourceName} nativePtr=not found ({candidate.Status})"
                : $"{candidate.Label}/{candidate.ResourceName} nativePtr=0x{candidate.Pointer.ToInt64():X} ({candidate.Status})"));
    }

    private static IEnumerable<object?> EnumerateRuntimeSequence(object? sequence)
    {
        if (sequence is null || sequence is string)
        {
            yield break;
        }

        if (sequence is IEnumerable enumerable)
        {
            foreach (var item in enumerable)
            {
                if (item is not null)
                {
                    yield return item;
                }
            }

            yield break;
        }

        if (!TryReadInt(sequence, "Count", out var count)
            && !TryReadInt(sequence, "Length", out count))
        {
            yield break;
        }

        var itemProperty = sequence
            .GetType()
            .GetProperties(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
            .FirstOrDefault(property =>
                property.GetIndexParameters().Length == 1
                && property.GetIndexParameters()[0].ParameterType == typeof(int)
                && property.GetMethod is not null);
        if (itemProperty is null)
        {
            yield break;
        }

        for (var index = 0; index < count; index++)
        {
            object? item;
            try
            {
                item = itemProperty.GetValue(sequence, new object[] { index });
            }
            catch
            {
                continue;
            }

            if (item is not null)
            {
                yield return item;
            }
        }
    }

    private static bool TryReadInt(object instance, string propertyName, out int value)
    {
        value = 0;
        var raw = TryReadPropertyObject(instance, propertyName);
        if (raw is int intValue)
        {
            value = intValue;
            return true;
        }

        return raw is not null && int.TryParse(raw.ToString(), out value);
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

    private static void ProbeTextureCandidate(ManualLogSource log, NativeBridge bridge, string label, object? candidate, object? renderGraph = null)
    {
        if (candidate is null)
        {
            log.LogInfo($"Frame resource {label}: null");
            return;
        }

        var summary = SummarizeValue(candidate);
        if (!TryFindNativeTexturePtr(candidate, renderGraph, out var owner, out var pointer))
        {
            log.LogInfo($"Frame resource {label}: {summary}; nativePtr=not found");
            var renderGraphStatus = TryDescribeRenderGraphTextureResolution(renderGraph, candidate);
            if (renderGraphStatus is not null)
            {
                log.LogInfo($"Frame resource {label}: {renderGraphStatus}");
            }

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

    private static object? FindRenderGraphArgument(object?[]? args)
    {
        if (args is null)
        {
            return null;
        }

        foreach (var arg in args)
        {
            if (arg is not null && TypeNameContains(arg.GetType(), "RenderGraph"))
            {
                return arg;
            }
        }

        return null;
    }

    private static bool TryFindNativeTexturePtr(object candidate, out object? owner, out IntPtr pointer)
    {
        return TryFindNativeTexturePtr(candidate, null, out owner, out pointer);
    }

    private static bool TryFindNativeTexturePtr(object candidate, object? renderGraph, out object? owner, out IntPtr pointer)
    {
        var visited = new HashSet<int>();
        return TryFindNativeTexturePtr(candidate, renderGraph, 0, visited, out owner, out pointer);
    }

    private static bool TryFindNativeTexturePtr(
        object? candidate,
        object? renderGraph,
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

        foreach (var resolved in EnumerateRenderGraphTextureResolutions(renderGraph, candidate))
        {
            if (TryFindNativeTexturePtr(resolved, renderGraph, depth + 1, visited, out owner, out pointer))
            {
                return true;
            }
        }

        foreach (var converted in EnumerateTextureConversions(candidate))
        {
            if (TryFindNativeTexturePtr(converted, renderGraph, depth + 1, visited, out owner, out pointer))
            {
                return true;
            }
        }

        foreach (var nested in EnumerateLikelyTextureMembers(candidate))
        {
            if (TryFindNativeTexturePtr(nested, renderGraph, depth + 1, visited, out owner, out pointer))
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

    private static IEnumerable<object?> EnumerateTextureConversions(object candidate)
    {
        var type = candidate.GetType();
        if (!TypeLooksTextureLike(type))
        {
            yield break;
        }

        foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static))
        {
            if (method.Name != "op_Implicit" && method.Name != "op_Explicit")
            {
                continue;
            }

            var parameters = method.GetParameters();
            if (parameters.Length != 1 || parameters[0].ParameterType != type || !TypeLooksTextureLike(method.ReturnType))
            {
                continue;
            }

            object? converted;
            try
            {
                converted = method.Invoke(null, new[] { candidate });
            }
            catch
            {
                continue;
            }

            if (converted is not null)
            {
                yield return converted;
            }
        }
    }

    private static IEnumerable<object?> EnumerateRenderGraphTextureResolutions(object? renderGraph, object candidate)
    {
        if (renderGraph is null || !TypeNameContains(candidate.GetType(), "TextureHandle"))
        {
            yield break;
        }

        foreach (var registry in EnumerateRenderGraphRegistries(renderGraph))
        {
            var resourceHandle = TryReadPropertyObject(candidate, "handle")
                ?? TryReadFieldObject(candidate, "handle");
            if (resourceHandle is null)
            {
                continue;
            }

            foreach (var textureResource in InvokeByRefResourceMethod(registry.Instance, "GetTextureResource", resourceHandle))
            {
                if (textureResource is not null)
                {
                    yield return textureResource;
                    yield return TryReadPropertyObject(textureResource, "graphicsResource")
                        ?? TryReadFieldObject(textureResource, "graphicsResource");
                }
            }
        }
    }

    private static IEnumerable<object?> InvokeByRefResourceMethod(object registry, string methodName, object handle)
    {
        var method = FindByRefResourceMethod(registry, methodName, handle);
        if (method is null)
        {
            yield break;
        }

        object? value;
        try
        {
            value = method.Invoke(registry, new[] { handle });
        }
        catch
        {
            yield break;
        }

        if (value is not null)
        {
            yield return value;
        }
    }

    private static MethodInfo? FindByRefResourceMethod(object registry, string methodName, object handle)
    {
        var handleTypeName = handle.GetType().FullName;
        return registry.GetType()
            .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
            .FirstOrDefault(candidate =>
            {
                if (!string.Equals(candidate.Name, methodName, StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = candidate.GetParameters();
                var elementType = parameters.Length == 1 && parameters[0].ParameterType.IsByRef
                    ? parameters[0].ParameterType.GetElementType()
                    : null;
                return string.Equals(elementType?.FullName, handleTypeName, StringComparison.Ordinal);
            });
    }

    private static IEnumerable<RenderGraphRegistryCandidate> EnumerateRenderGraphRegistries(object renderGraph)
    {
        var seen = new HashSet<int>();

        var fromGraph = TryReadPropertyObject(renderGraph, "m_Resources")
            ?? TryReadFieldObject(renderGraph, "m_Resources");
        if (fromGraph is not null && seen.Add(RuntimeHelpers.GetHashCode(fromGraph)))
        {
            yield return new RenderGraphRegistryCandidate("renderGraph.m_Resources", fromGraph);
        }

        var registryType = FindRuntimeType(
            AppDomain.CurrentDomain.GetAssemblies(),
            "UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphResourceRegistry");
        if (registryType is null)
        {
            yield break;
        }

        foreach (var propertyName in new[] { "current", "m_CurrentRegistry" })
        {
            var current = TryReadStaticPropertyObject(registryType, propertyName);
            if (current is not null && seen.Add(RuntimeHelpers.GetHashCode(current)))
            {
                yield return new RenderGraphRegistryCandidate($"RenderGraphResourceRegistry.{propertyName}", current);
            }
        }

        foreach (var fieldName in new[] { "m_CurrentRegistry", "current" })
        {
            var current = TryReadStaticFieldObject(registryType, fieldName);
            if (current is not null && seen.Add(RuntimeHelpers.GetHashCode(current)))
            {
                yield return new RenderGraphRegistryCandidate($"RenderGraphResourceRegistry.{fieldName}", current);
            }
        }
    }

    private static string? TryDescribeRenderGraphTextureResolution(object? renderGraph, object candidate)
    {
        if (renderGraph is null || !TypeNameContains(candidate.GetType(), "TextureHandle"))
        {
            return null;
        }

        var details = new List<string>();
        var registries = EnumerateRenderGraphRegistries(renderGraph).ToList();
        if (registries.Count == 0)
        {
            return "RenderGraph texture resolve: no resource registry found.";
        }

        foreach (var registry in registries)
        {
            details.Add($"{registry.Label}.GetTexture not called from prefix");

            var resourceHandle = TryReadPropertyObject(candidate, "handle")
                ?? TryReadFieldObject(candidate, "handle");
            if (resourceHandle is not null)
            {
                details.Add(DescribeByRefResourceCall(registry, "GetTextureResource", resourceHandle, out var textureResource));
                if (textureResource is not null)
                {
                    var graphicsResource = TryReadPropertyObject(textureResource, "graphicsResource")
                        ?? TryReadFieldObject(textureResource, "graphicsResource");
                    details.Add(graphicsResource is null
                        ? $"{registry.Label}.TextureResource.graphicsResource returned null"
                        : $"{registry.Label}.TextureResource.graphicsResource returned {SummarizeValue(graphicsResource)}");
                }
            }
            else
            {
                details.Add($"{registry.Label}.TextureHandle.handle not readable");
            }
        }

        return $"RenderGraph texture resolve: {string.Join("; ", details)}";
    }

    private static string DescribeByRefResourceCall(RenderGraphRegistryCandidate registry, string methodName, object handle, out object? value)
    {
        value = null;
        var method = FindByRefResourceMethod(registry.Instance, methodName, handle);
        if (method is null)
        {
            return $"{registry.Label}.{methodName} missing";
        }

        try
        {
            value = method.Invoke(registry.Instance, new[] { handle });
            return value is null
                ? $"{registry.Label}.{methodName} returned null"
                : $"{registry.Label}.{methodName} returned {SummarizeValue(value)}";
        }
        catch (Exception ex)
        {
            return $"{registry.Label}.{methodName} threw {FirstLine(GetExceptionMessage(ex))}";
        }
    }

    private static string DescribeRenderGraphBuilderDeclaration(object? builder, object?[]? args)
    {
        if (!TryGetRenderGraphBuilderDeclarationDetails(builder, args, out _, out var resourceName))
        {
            return string.Empty;
        }

        return resourceName is null ? "; resourceName=unavailable" : $"; resourceName={resourceName}";
    }

    private static bool TryGetRenderGraphBuilderDeclarationDetails(
        object? builder,
        object?[]? args,
        out object? textureHandle,
        out string? resourceName)
    {
        textureHandle = null;
        resourceName = null;
        if (builder is null || args is null)
        {
            return false;
        }

        textureHandle = args.FirstOrDefault(arg => arg is not null && TypeNameContains(arg.GetType(), "TextureHandle"));
        if (textureHandle is null)
        {
            return false;
        }

        var resourceHandle = TryReadPropertyObject(textureHandle, "handle")
            ?? TryReadFieldObject(textureHandle, "handle");
        if (resourceHandle is null)
        {
            return true;
        }

        var registry = TryReadPropertyObject(builder, "m_Resources")
            ?? TryReadFieldObject(builder, "m_Resources");
        if (registry is null)
        {
            return true;
        }

        resourceName = TryGetRenderGraphResourceName(registry, resourceHandle);
        return true;
    }

    private static string? TryGetRenderGraphResourceName(object registry, object resourceHandle)
    {
        var method = FindByRefResourceMethod(registry, "GetRenderGraphResourceName", resourceHandle);
        if (method is null)
        {
            return null;
        }

        try
        {
            return method.Invoke(registry, new[] { resourceHandle })?.ToString();
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

    private static string SummarizeArguments(object?[]? args)
    {
        if (args is null || args.Length == 0)
        {
            return string.Empty;
        }

        return string.Join("; ", args.Select((arg, index) => $"arg{index}={SummarizeValue(arg)}"));
    }

    private static string GetManagedCallerSummary()
    {
        try
        {
            var frames = new StackTrace(2, false).GetFrames();
            if (frames is null || frames.Length == 0)
            {
                return "unavailable";
            }

            var callers = frames
                .Select(frame => frame.GetMethod())
                .Where(method => method is not null)
                .Cast<MethodBase>()
                .Where(method => method.DeclaringType is not null)
                .Select(method => $"{method.DeclaringType!.FullName}.{method.Name}")
                .Where(name => name.IndexOf(nameof(FrameResourceProbe), StringComparison.Ordinal) < 0)
                .Where(name => name.IndexOf("Harmony", StringComparison.OrdinalIgnoreCase) < 0)
                .Where(name => name.IndexOf("Il2CppInterop", StringComparison.OrdinalIgnoreCase) < 0)
                .Take(8)
                .ToArray();

            return callers.Length == 0 ? "unavailable" : string.Join(" <- ", callers);
        }
        catch
        {
            return "unavailable";
        }
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
            "dimension",
            "handle",
            "type",
            "index",
            "IsValid"
        })
        {
            var propertyValue = TryReadPropertyString(value, propertyName);
            if (propertyValue is not null)
            {
                parts.Add($"{propertyName}={propertyValue}");
            }
        }

        foreach (var fieldName in new[]
        {
            "handle",
            "m_Handle",
            "m_Type",
            "index",
            "m_Index"
        })
        {
            var fieldValue = TryReadFieldString(value, fieldName);
            if (fieldValue is not null)
            {
                parts.Add($"{fieldName}={fieldValue}");
            }
        }

        AddNestedHandleSummary(parts, value);

        return string.Join(" ", parts);
    }

    private static void AddNestedHandleSummary(ICollection<string> parts, object value)
    {
        var handle = TryReadPropertyObject(value, "handle")
            ?? TryReadFieldObject(value, "handle");
        if (handle is null || ReferenceEquals(handle, value))
        {
            return;
        }

        foreach (var propertyName in new[] { "index", "type", "iType", "IsValid" })
        {
            var propertyValue = TryReadPropertyString(handle, propertyName);
            if (propertyValue is not null)
            {
                parts.Add($"handle.{propertyName}={propertyValue}");
            }
        }

        foreach (var fieldName in new[] { "m_Value", "_type_k__BackingField" })
        {
            var fieldValue = TryReadFieldString(handle, fieldName);
            if (fieldValue is not null)
            {
                parts.Add($"handle.{fieldName}={fieldValue}");
            }
        }
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

    private static object? TryReadStaticPropertyObject(Type type, string propertyName)
    {
        try
        {
            var property = type.GetProperty(
                propertyName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);

            if (property is null || property.GetIndexParameters().Length != 0 || property.GetMethod is null)
            {
                return null;
            }

            return property.GetValue(null);
        }
        catch
        {
            return null;
        }
    }

    private static object? TryReadStaticFieldObject(Type type, string fieldName)
    {
        try
        {
            var field = type.GetField(
                fieldName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);

            return field?.GetValue(null);
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

    private static string? TryReadFieldString(object instance, string fieldName)
    {
        return TryReadFieldObject(instance, fieldName)?.ToString();
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

    private readonly record struct FrameProbeTarget(string TypeName, string MemberName);

    private readonly record struct NativeTextureCandidate(string Label, IntPtr Pointer);

    private readonly record struct NamedTextureHandleCandidate(string Label, object Value);

    private readonly record struct RenderGraphTextureCandidate(string Label, string ResourceName, IntPtr Pointer, string Status);

    private readonly record struct RenderGraphRegistryCandidate(string Label, object Instance);
}
