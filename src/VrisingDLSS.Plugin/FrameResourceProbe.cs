using BepInEx.Logging;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace VrisingDLSS.Plugin;

internal static class FrameResourceProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".frame-resource-probe";
    private const int MaxInitialLogsPerMethod = 5;
    private const int MaxRenderGraphBuilderDeclarationLogs = 40;
    private const int MaxRenderGraphBuilderStackLogs = 6;
    private const int MaxRenderGraphExecutionScopeLogs = 80;
    private const int MaxRenderGraphScopedEvaluateAttempts = 12;
    private const int MaxExistingRenderFuncLogs = 80;
    private const int MaxExistingRenderFuncRegistryMissingLogs = 12;
    private const int MaxExistingRenderFuncEvaluateAttempts = 12;
    private const int MaxRenderGraphResourceMaterializationLogs = 80;
    private const int MaxRenderGraphResourceMaterializationEvaluateAttempts = 12;
    private const int MaxRenderGraphGetTextureLogs = 40;
    private const int MaxDlssPassResourceHelperLogs = 40;
    private const int MaxDlssPassResourceEvaluateAttempts = 12;
    private const int MaxDlssEvaluateProbeAttempts = 3;
    private const int MaxDlssPersistentEvaluateProbeAttempts = 1;
    private const int MaxDlssSuperResolutionInputProbeAttempts = 128;
    private const int MaxDlssSuperResolutionEvaluateProbeAttempts = 1;
    private const int MaxDlssSuperResolutionPersistentEvaluateProbeAttempts = 1;
    private const int MaxDlssSuperResolutionFrameSequenceEvaluateProbeAttempts = 24;
    private const int TargetDlssSuperResolutionFrameSequenceEvaluateSuccesses = 3;
    private const int MaxDlssUserRenderingFailureLogs = 8;
    private const int DlssUserRenderingFallbackMaxAttemptsPerSecond = 240;
    private const int MaxDlssVisibleWritebackProbeAttempts = 120;
    private const int MaxDlssVisibleWritebackHoldAttempts = 30000;
    private const int TargetDlssVisibleWritebackProbeSuccesses = 30;
    private const int MaxDlssEvaluateOutputFollowupLogs = 12;
    private const int MaxTextureSearchDepth = 3;
    private static readonly long DlssUserRenderingFallbackMinAttemptTicks = Math.Max(1L, Stopwatch.Frequency / DlssUserRenderingFallbackMaxAttemptsPerSecond);
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
    private static int RenderGraphResourceMaterializationCallCount;
    private static int RenderGraphResourceMaterializationEvaluateAttemptCount;
    private static int RenderGraphResourceMaterializationEpoch;
    private static int RenderGraphGetTextureCallCount;
    private static int RenderGraphGetTextureEvaluateAttemptCount;
    private static int DlssPassResourceHelperCallCount;
    private static int DlssPassResourceEvaluateAttemptCount;
    private static int DlssEvaluateProbeAttemptCount;
    private static int DlssPersistentEvaluateProbeAttemptCount;
    private static int DlssSuperResolutionInputProbeAttemptCount;
    private static int DlssSuperResolutionEvaluateProbeAttemptCount;
    private static int DlssSuperResolutionPersistentEvaluateProbeAttemptCount;
    private static int DlssSuperResolutionFrameSequenceEvaluateProbeAttemptCount;
    private static int DlssSuperResolutionFrameSequenceEvaluateProbeSuccessCount;
    private static int DlssUserRenderingAttemptCount;
    private static int DlssUserRenderingSuccessCount;
    private static int DlssUserRenderingNoEvaluateAcceptedCount;
    private static int DlssUserRenderingFailureLogCount;
    private static int DlssUserRenderingLastAttemptFrameCount = -1;
    private static long DlssUserRenderingLastAttemptTimestamp;
    private static int DlssUserRenderingBridgeEvaluateTimedCount;
    private static long DlssUserRenderingBridgeEvaluateTotalTicks;
    private static long DlssUserRenderingBridgeEvaluateMaxTicks;
    private static int DlssVisibleWritebackProbeAttemptCount;
    private static int DlssVisibleWritebackProbeSuccessCount;
    private static int DlssEvaluateOutputFollowupLogCount;
    private static int DlssEvaluateOutputFollowupStartGetTextureCallCount;
    private static IntPtr DlssEvaluateOutputFollowupPointer;
    private static string? DlssEvaluateOutputFollowupResourceName;
    private static readonly Dictionary<string, RenderGraphTextureCandidate> RenderGraphResourceMaterializationCandidates = new(StringComparer.OrdinalIgnoreCase);
    private static readonly Dictionary<string, RenderGraphTextureCandidate> RenderGraphGetTextureCandidates = new(StringComparer.OrdinalIgnoreCase);
    private static readonly HashSet<string> DlssSuperResolutionInputProbeAttemptKeys = new(StringComparer.Ordinal);
    private static readonly Dictionary<string, MethodInfo?> ByRefResourceMethodCache = new(StringComparer.Ordinal);
    private static readonly Dictionary<string, PropertyInfo?> InstancePropertyCache = new(StringComparer.Ordinal);
    private static readonly Dictionary<string, FieldInfo?> InstanceFieldCache = new(StringComparer.Ordinal);
    private static readonly Dictionary<Type, MethodInfo?> NativeTexturePtrMethodCache = new();
    private static readonly Dictionary<Type, MethodInfo[]> TextureConversionMethodCache = new();
    private static readonly Dictionary<Type, PropertyInfo[]> LikelyTexturePropertyCache = new();
    private static readonly Dictionary<Type, FieldInfo[]> LikelyTextureFieldCache = new();
    private static DlssUserRenderingResourceTuple? DlssUserRenderingAcceptedTuple;
    private static int DlssUserRenderingCachedTupleUseCount;
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
    private static bool ResourceMaterializationProbeEnabled;
    private static bool DlssPassResourceProbeEnabled;
    private static bool RenderGraphGetTextureDiagnosticLoggingEnabled;
    private static bool DlssEvaluateInputProbeSucceeded;
    private static bool DlssEvaluateProbeEnabled;
    private static bool DlssEvaluateProbeSucceeded;
    private static bool DlssPersistentEvaluateProbeEnabled;
    private static bool DlssPersistentEvaluateProbeSucceeded;
    private static bool DlssSuperResolutionInputProbeEnabled;
    private static bool DlssSuperResolutionInputProbeSucceeded;
    private static bool DlssSuperResolutionEvaluateProbeEnabled;
    private static bool DlssSuperResolutionEvaluateProbeSucceeded;
    private static bool DlssSuperResolutionPersistentEvaluateProbeEnabled;
    private static bool DlssSuperResolutionPersistentEvaluateProbeSucceeded;
    private static bool DlssSuperResolutionFrameSequenceEvaluateProbeEnabled;
    private static bool DlssSuperResolutionFrameSequenceEvaluateProbeSucceeded;
    private static bool DlssSuperResolutionFrameSequenceShutdownLogged;
    private static bool DlssUserRenderingEnabled;
    private static bool DlssUserRenderingNoEvaluateEnabled;
    private static bool DlssUserRenderingSucceeded;
    private static bool DlssUserRenderingBlocked;
    private static bool DlssUserRenderingShutdownLogged;
    private static bool DlssUserRenderingFrameThrottleFallbackLogged;
    private static bool DlssVisibleWritebackProbeEnabled;
    private static bool KeepDlssVisibleWritebackProbeRunning;
    private static bool DlssVisibleWritebackProbeSucceeded;
    private static bool DlssVisibleWritebackShutdownLogged;
    private static DlssEvaluateProbeSettings DlssEvaluateSettings;
    private static bool UnityTimeLookupAttempted;
    private static PropertyInfo? UnityTimeFrameCountProperty;

    internal static void Install(
        ManualLogSource log,
        NativeBridge bridge,
        bool enableFrameResourceProbe = false,
        bool enableDlssEvaluateInputProbe = false,
        bool enableDlssEvaluateProbe = false,
        bool enableDlssPersistentEvaluateProbe = false,
        bool enableDlssSuperResolutionInputProbe = false,
        bool enableDlssSuperResolutionEvaluateProbe = false,
        bool enableDlssSuperResolutionPersistentEvaluateProbe = false,
        bool enableDlssSuperResolutionFrameSequenceEvaluateProbe = false,
        bool enableDlssVisibleWritebackProbe = false,
        bool enableDlssUserRendering = false,
        bool enableDlssUserRenderingNoEvaluate = false,
        bool keepDlssVisibleWritebackProbeRunning = false,
        DlssEvaluateProbeSettings dlssEvaluateSettings = default,
        bool enableRenderGraphDiagnosticPass = false,
        bool enableExistingRenderFuncProbe = false,
        bool enableResourceMaterializationProbe = false,
        bool enableDlssPassResourceProbe = false)
    {
        if (Installed)
        {
            log.LogInfo("Frame resource probe is already installed.");
            DlssEvaluateInputProbeEnabled = DlssEvaluateInputProbeEnabled || enableDlssEvaluateInputProbe || enableDlssEvaluateProbe || enableDlssPersistentEvaluateProbe || enableDlssSuperResolutionInputProbe || enableDlssSuperResolutionEvaluateProbe || enableDlssSuperResolutionPersistentEvaluateProbe || enableDlssSuperResolutionFrameSequenceEvaluateProbe || enableDlssVisibleWritebackProbe || enableDlssUserRendering || enableDlssUserRenderingNoEvaluate;
            DlssEvaluateProbeEnabled = DlssEvaluateProbeEnabled || enableDlssEvaluateProbe;
            DlssPersistentEvaluateProbeEnabled = DlssPersistentEvaluateProbeEnabled || enableDlssPersistentEvaluateProbe;
            DlssSuperResolutionInputProbeEnabled = DlssSuperResolutionInputProbeEnabled || enableDlssSuperResolutionInputProbe || enableDlssSuperResolutionEvaluateProbe || enableDlssSuperResolutionPersistentEvaluateProbe || enableDlssSuperResolutionFrameSequenceEvaluateProbe || enableDlssVisibleWritebackProbe || enableDlssUserRendering || enableDlssUserRenderingNoEvaluate;
            DlssSuperResolutionEvaluateProbeEnabled = DlssSuperResolutionEvaluateProbeEnabled || enableDlssSuperResolutionEvaluateProbe;
            DlssSuperResolutionPersistentEvaluateProbeEnabled = DlssSuperResolutionPersistentEvaluateProbeEnabled || enableDlssSuperResolutionPersistentEvaluateProbe;
            DlssSuperResolutionFrameSequenceEvaluateProbeEnabled = DlssSuperResolutionFrameSequenceEvaluateProbeEnabled || enableDlssSuperResolutionFrameSequenceEvaluateProbe;
            DlssVisibleWritebackProbeEnabled = DlssVisibleWritebackProbeEnabled || enableDlssVisibleWritebackProbe;
            DlssUserRenderingEnabled = DlssUserRenderingEnabled || enableDlssUserRendering || enableDlssUserRenderingNoEvaluate;
            DlssUserRenderingNoEvaluateEnabled = DlssUserRenderingNoEvaluateEnabled || enableDlssUserRenderingNoEvaluate;
            KeepDlssVisibleWritebackProbeRunning = KeepDlssVisibleWritebackProbeRunning || (enableDlssVisibleWritebackProbe && keepDlssVisibleWritebackProbeRunning);
            if (enableDlssEvaluateProbe || enableDlssPersistentEvaluateProbe || enableDlssSuperResolutionEvaluateProbe || enableDlssSuperResolutionPersistentEvaluateProbe || enableDlssSuperResolutionFrameSequenceEvaluateProbe || enableDlssVisibleWritebackProbe || enableDlssUserRendering)
            {
                DlssEvaluateSettings = dlssEvaluateSettings;
            }

            RenderGraphDiagnosticPassEnabled = RenderGraphDiagnosticPassEnabled || enableRenderGraphDiagnosticPass;
            ExistingRenderFuncProbeEnabled = ExistingRenderFuncProbeEnabled || enableExistingRenderFuncProbe;
            ResourceMaterializationProbeEnabled = ResourceMaterializationProbeEnabled || enableResourceMaterializationProbe;
            DlssPassResourceProbeEnabled = DlssPassResourceProbeEnabled || enableDlssPassResourceProbe;
            RenderGraphGetTextureDiagnosticLoggingEnabled = RenderGraphGetTextureDiagnosticLoggingEnabled || ShouldEnableRenderGraphGetTextureDiagnosticLogging(
                enableFrameResourceProbe,
                enableDlssEvaluateInputProbe,
                enableDlssEvaluateProbe,
                enableDlssPersistentEvaluateProbe,
                enableDlssSuperResolutionInputProbe,
                enableDlssSuperResolutionEvaluateProbe,
                enableDlssSuperResolutionPersistentEvaluateProbe,
                enableDlssSuperResolutionFrameSequenceEvaluateProbe,
                enableDlssVisibleWritebackProbe,
                enableDlssPassResourceProbe);
            return;
        }

        Log = log;
        Bridge = bridge;
        DlssEvaluateInputProbeEnabled = enableDlssEvaluateInputProbe || enableDlssEvaluateProbe || enableDlssPersistentEvaluateProbe || enableDlssSuperResolutionInputProbe || enableDlssSuperResolutionEvaluateProbe || enableDlssSuperResolutionPersistentEvaluateProbe || enableDlssSuperResolutionFrameSequenceEvaluateProbe || enableDlssVisibleWritebackProbe || enableDlssUserRendering || enableDlssUserRenderingNoEvaluate;
        DlssEvaluateProbeEnabled = enableDlssEvaluateProbe;
        DlssPersistentEvaluateProbeEnabled = enableDlssPersistentEvaluateProbe;
        DlssSuperResolutionInputProbeEnabled = enableDlssSuperResolutionInputProbe || enableDlssSuperResolutionEvaluateProbe || enableDlssSuperResolutionPersistentEvaluateProbe || enableDlssSuperResolutionFrameSequenceEvaluateProbe || enableDlssVisibleWritebackProbe || enableDlssUserRendering || enableDlssUserRenderingNoEvaluate;
        DlssSuperResolutionEvaluateProbeEnabled = enableDlssSuperResolutionEvaluateProbe;
        DlssSuperResolutionPersistentEvaluateProbeEnabled = enableDlssSuperResolutionPersistentEvaluateProbe;
        DlssSuperResolutionFrameSequenceEvaluateProbeEnabled = enableDlssSuperResolutionFrameSequenceEvaluateProbe;
        DlssVisibleWritebackProbeEnabled = enableDlssVisibleWritebackProbe;
        DlssUserRenderingEnabled = enableDlssUserRendering || enableDlssUserRenderingNoEvaluate;
        DlssUserRenderingNoEvaluateEnabled = enableDlssUserRenderingNoEvaluate;
        KeepDlssVisibleWritebackProbeRunning = enableDlssVisibleWritebackProbe && keepDlssVisibleWritebackProbeRunning;
        DlssEvaluateSettings = dlssEvaluateSettings;
        RenderGraphDiagnosticPassEnabled = enableRenderGraphDiagnosticPass;
        ExistingRenderFuncProbeEnabled = enableExistingRenderFuncProbe;
        ResourceMaterializationProbeEnabled = enableResourceMaterializationProbe;
        DlssPassResourceProbeEnabled = enableDlssPassResourceProbe;
        RenderGraphGetTextureDiagnosticLoggingEnabled = ShouldEnableRenderGraphGetTextureDiagnosticLogging(
            enableFrameResourceProbe,
            enableDlssEvaluateInputProbe,
            enableDlssEvaluateProbe,
            enableDlssPersistentEvaluateProbe,
            enableDlssSuperResolutionInputProbe,
            enableDlssSuperResolutionEvaluateProbe,
            enableDlssSuperResolutionPersistentEvaluateProbe,
            enableDlssSuperResolutionFrameSequenceEvaluateProbe,
            enableDlssVisibleWritebackProbe,
            enableDlssPassResourceProbe);
        DlssEvaluateInputProbeSucceeded = false;
        DlssEvaluateProbeSucceeded = false;
        DlssPersistentEvaluateProbeSucceeded = false;
        DlssSuperResolutionInputProbeSucceeded = false;
        DlssSuperResolutionEvaluateProbeSucceeded = false;
        DlssSuperResolutionPersistentEvaluateProbeSucceeded = false;
        DlssSuperResolutionFrameSequenceEvaluateProbeSucceeded = false;
        DlssSuperResolutionFrameSequenceShutdownLogged = false;
        DlssUserRenderingSucceeded = false;
        DlssUserRenderingBlocked = false;
        DlssUserRenderingShutdownLogged = false;
        DlssVisibleWritebackProbeSucceeded = false;
        DlssVisibleWritebackShutdownLogged = false;
        if (DlssEvaluateInputProbeEnabled)
        {
            log.LogInfo("DLSS evaluate input probe enabled.");
        }
        if (DlssEvaluateProbeEnabled)
        {
            log.LogWarning("DLSS evaluate probe enabled. This diagnostic can call NGX evaluate against live frame resources and should only be used in local/private testing.");
        }
        if (DlssPersistentEvaluateProbeEnabled)
        {
            log.LogWarning("DLSS persistent evaluate probe enabled. This diagnostic can call NGX evaluate multiple times against live frame resources and should only be used in local/private testing.");
        }
        if (DlssSuperResolutionInputProbeEnabled)
        {
            log.LogInfo("DLSS super-resolution input probe enabled.");
        }
        if (DlssSuperResolutionEvaluateProbeEnabled)
        {
            log.LogWarning("DLSS super-resolution evaluate probe enabled. This diagnostic can call NGX evaluate against a render-input-smaller-than-output tuple and should only be used in local/private testing.");
        }
        if (DlssSuperResolutionPersistentEvaluateProbeEnabled)
        {
            log.LogWarning("DLSS super-resolution persistent evaluate probe enabled. This diagnostic can call NGX evaluate multiple times against a render-input-smaller-than-output tuple and should only be used in local/private testing.");
        }
        if (DlssSuperResolutionFrameSequenceEvaluateProbeEnabled)
        {
            log.LogWarning("DLSS super-resolution frame-sequence evaluate probe enabled. This diagnostic keeps one NGX feature alive across multiple RenderGraph callbacks and should only be used in local/private testing.");
        }
        if (DlssVisibleWritebackProbeEnabled)
        {
            log.LogWarning("DLSS visible write-back probe enabled. This diagnostic repeatedly evaluates NGX into the selected Super Resolution output target and should only be used in local/private image-correctness testing.");
            if (KeepDlssVisibleWritebackProbeRunning)
            {
                log.LogWarning("DLSS visible write-back probe hold mode enabled. The probe will continue evaluating after the 30-success milestone until cleanup or the hold attempt limit.");
            }
        }
        if (DlssUserRenderingEnabled && !DlssUserRenderingNoEvaluateEnabled)
        {
            log.LogWarning("DLSS user rendering candidate enabled. This uses the Stage 10A visible-path output target with at most one DLSS evaluate per Unity frame and falls back safely when the native path is unavailable.");
        }
        if (DlssUserRenderingNoEvaluateEnabled)
        {
            log.LogWarning("DLSS user rendering no-evaluate diagnostic enabled. It accepts the same RenderGraph Super Resolution tuple but skips NGX evaluate/writeback for performance isolation.");
        }
        if (RenderGraphDiagnosticPassEnabled)
        {
            log.LogWarning("High-risk RenderGraph diagnostic pass injection is enabled. This route has caused a CoreCLR access violation in V Rising and should be used only for crash-recovery research.");
        }
        if (ExistingRenderFuncProbeEnabled)
        {
            log.LogWarning("High-risk existing HDRP render-func patching is enabled. This route has caused a CoreCLR access violation in V Rising and should be used only for crash-recovery research.");
        }
        if (ResourceMaterializationProbeEnabled)
        {
            log.LogInfo("RenderGraph resource materialization probe enabled.");
        }
        if (DlssPassResourceProbeEnabled)
        {
            log.LogWarning("High-risk DLSSPass resource helper probe is enabled. It patches GetViewResources/GetCameraResources only, not DLSSPass.Render; use only for deliberate Stage 8A resource testing.");
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
        if (enableFrameResourceProbe)
        {
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
        }
        else
        {
            log.LogInfo("Frame resource base probe skipped.");
        }

        if (DlssEvaluateInputProbeEnabled)
        {
            if (enableFrameResourceProbe)
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
            }
            else
            {
                log.LogInfo("Frame resource ordinary HDRP prefix probes skipped for crash-safe Stage 8A. Enable Diagnostics.EnableFrameResourceProbe only for deliberate discovery.");
            }

            if (enableFrameResourceProbe)
            {
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
            }
            else
            {
                log.LogInfo("Frame resource RenderGraph builder/execution-scope probes skipped for crash-safe Stage 8A. Enable Diagnostics.EnableFrameResourceProbe only for deliberate discovery.");
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

            if (ResourceMaterializationProbeEnabled)
            {
                var resourceMaterializationPatched = TryPatchRenderGraphResourceMaterializationMethods(
                    log,
                    assemblies,
                    harmonyMethodConstructor,
                    patchMethod,
                    patchedMethodKeys);
                patched += resourceMaterializationPatched;
                log.LogInfo($"Frame resource RenderGraph materialization probe patched {resourceMaterializationPatched} method(s).");
            }
            else
            {
                log.LogInfo("Frame resource RenderGraph materialization probe skipped.");
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

        if (DlssPassResourceProbeEnabled)
        {
            var dlssPassResourceHelperPatched = TryPatchDlssPassResourceHelperMethods(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys);
            patched += dlssPassResourceHelperPatched;
            log.LogInfo($"DLSSPass resource helper probe patched {dlssPassResourceHelperPatched} method(s).");
        }

        Installed = patched > 0;
        log.LogInfo($"Frame resource probe total patched {patched} method(s).");
    }

    internal static void Uninstall(ManualLogSource log)
    {
        if (!Installed || HarmonyInstance is null || HarmonyType is null)
        {
            return;
        }

        try
        {
            TryShutdownDlssUserRendering(log);
            TryShutdownDlssVisibleWriteback(log);
            if (DlssSuperResolutionFrameSequenceEvaluateProbeEnabled)
            {
                TryShutdownDlssSuperResolutionFrameSequence(log);
            }

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
            ResourceMaterializationProbeEnabled = false;
            DlssPassResourceProbeEnabled = false;
            RenderGraphGetTextureDiagnosticLoggingEnabled = false;
            DlssEvaluateProbeEnabled = false;
            DlssPersistentEvaluateProbeEnabled = false;
            DlssSuperResolutionInputProbeEnabled = false;
            DlssSuperResolutionEvaluateProbeEnabled = false;
            DlssSuperResolutionPersistentEvaluateProbeEnabled = false;
            DlssSuperResolutionFrameSequenceEvaluateProbeEnabled = false;
            DlssUserRenderingEnabled = false;
            DlssUserRenderingNoEvaluateEnabled = false;
            DlssVisibleWritebackProbeEnabled = false;
            KeepDlssVisibleWritebackProbeRunning = false;
            DlssEvaluateInputProbeSucceeded = false;
            DlssEvaluateProbeSucceeded = false;
            DlssPersistentEvaluateProbeSucceeded = false;
            DlssSuperResolutionInputProbeSucceeded = false;
            DlssSuperResolutionEvaluateProbeSucceeded = false;
            DlssSuperResolutionPersistentEvaluateProbeSucceeded = false;
            DlssSuperResolutionFrameSequenceEvaluateProbeSucceeded = false;
            DlssSuperResolutionFrameSequenceShutdownLogged = false;
            DlssUserRenderingSucceeded = false;
            DlssUserRenderingBlocked = false;
            DlssUserRenderingShutdownLogged = false;
            DlssVisibleWritebackProbeSucceeded = false;
            DlssVisibleWritebackShutdownLogged = false;
            lock (Sync)
            {
                CallCounts.Clear();
                RenderGraphResourceMaterializationCandidates.Clear();
                RenderGraphBuilderDeclarationCallCount = 0;
                RenderGraphExecutionScopeCallCount = 0;
                RenderGraphScopedEvaluateAttemptCount = 0;
                ExistingRenderFuncCallCount = 0;
                ExistingRenderFuncRegistryMissingCallCount = 0;
                ExistingRenderFuncEvaluateAttemptCount = 0;
                RenderGraphResourceMaterializationCallCount = 0;
                RenderGraphResourceMaterializationEvaluateAttemptCount = 0;
                RenderGraphResourceMaterializationEpoch = 0;
                RenderGraphGetTextureCallCount = 0;
                RenderGraphGetTextureEvaluateAttemptCount = 0;
                DlssEvaluateProbeAttemptCount = 0;
                DlssPersistentEvaluateProbeAttemptCount = 0;
                DlssSuperResolutionInputProbeAttemptCount = 0;
                DlssSuperResolutionEvaluateProbeAttemptCount = 0;
                DlssSuperResolutionPersistentEvaluateProbeAttemptCount = 0;
                DlssSuperResolutionFrameSequenceEvaluateProbeAttemptCount = 0;
                DlssSuperResolutionFrameSequenceEvaluateProbeSuccessCount = 0;
                DlssUserRenderingAttemptCount = 0;
                DlssUserRenderingSuccessCount = 0;
                DlssUserRenderingNoEvaluateAcceptedCount = 0;
                DlssUserRenderingFailureLogCount = 0;
                DlssUserRenderingLastAttemptFrameCount = -1;
                DlssUserRenderingLastAttemptTimestamp = 0;
                DlssUserRenderingBridgeEvaluateTimedCount = 0;
                DlssUserRenderingBridgeEvaluateTotalTicks = 0;
                DlssUserRenderingBridgeEvaluateMaxTicks = 0;
                DlssUserRenderingAcceptedTuple = null;
                DlssUserRenderingCachedTupleUseCount = 0;
                DlssUserRenderingFrameThrottleFallbackLogged = false;
                DlssVisibleWritebackProbeAttemptCount = 0;
                DlssVisibleWritebackProbeSuccessCount = 0;
                DlssSuperResolutionInputProbeAttemptKeys.Clear();
                DlssEvaluateOutputFollowupLogCount = 0;
                DlssEvaluateOutputFollowupStartGetTextureCallCount = 0;
                DlssEvaluateOutputFollowupPointer = IntPtr.Zero;
                DlssEvaluateOutputFollowupResourceName = null;
                RenderGraphGetTextureCandidates.Clear();
                DlssPassResourceHelperCallCount = 0;
                DlssPassResourceEvaluateAttemptCount = 0;
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

    private static int TryPatchRenderGraphResourceMaterializationMethods(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var patched = 0;
        var beginExecute = FindRenderGraphRegistryBeginExecuteMethod(assemblies);
        var beginExecutePrefix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphRegistryBeginExecutePrefix), BindingFlags.NonPublic | BindingFlags.Static);
        if (beginExecute is not null
            && beginExecutePrefix is not null
            && TryPatchFrameResourceMethod(
                log,
                beginExecute,
                harmonyMethodConstructor,
                patchMethod,
                beginExecutePrefix,
                patchedMethodKeys,
                "Frame resource RenderGraph materialization begin-execute"))
        {
            patched++;
        }
        else
        {
            log.LogWarning("Frame resource RenderGraph materialization begin-execute target was not found.");
        }

        var createTextureCallback = FindRenderGraphRegistryCreateTextureCallbackMethod(assemblies);
        var createTexturePostfix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphCreateTextureCallbackPostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (createTextureCallback is not null
            && createTexturePostfix is not null
            && TryPatchPostfixMethod(
                log,
                createTextureCallback,
                harmonyMethodConstructor,
                patchMethod,
                createTexturePostfix,
                patchedMethodKeys,
                "Frame resource RenderGraph texture materialization"))
        {
            patched++;
        }
        else
        {
            log.LogWarning("Frame resource RenderGraph texture materialization target was not found.");
        }

        return patched;
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

    private static int TryPatchDlssPassResourceHelperMethods(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var postfix = typeof(FrameResourceProbe).GetMethod(nameof(DlssPassResourceHelperPostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (postfix is null)
        {
            log.LogWarning("DLSSPass resource helper postfix target was not found.");
            return 0;
        }

        var dlssPassType = HookTargetCatalog.FindType(assemblies, "UnityEngine.Rendering.HighDefinition.DLSSPass");
        if (dlssPassType is null)
        {
            log.LogWarning("DLSSPass resource helper target type was not found.");
            return 0;
        }

        var patched = 0;
        foreach (var method in dlssPassType
            .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.DeclaredOnly)
            .Where(IsDlssPassResourceHelperMethod))
        {
            if (TryPatchPostfixMethod(
                log,
                method,
                harmonyMethodConstructor,
                patchMethod,
                postfix,
                patchedMethodKeys,
                "DLSSPass resource helper"))
            {
                patched++;
            }
        }

        return patched;
    }

    private static bool IsDlssPassResourceHelperMethod(MethodInfo method)
    {
        if (method.ContainsGenericParameters)
        {
            return false;
        }

        return string.Equals(method.Name, "GetViewResources", StringComparison.Ordinal)
            || string.Equals(method.Name, "GetCameraResources", StringComparison.Ordinal);
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

    private static MethodInfo? FindRenderGraphRegistryBeginExecuteMethod(IEnumerable<Assembly> assemblies)
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
                if (!string.Equals(method.Name, "BeginExecute", StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 1 && parameters[0].ParameterType == typeof(int);
            });
    }

    private static MethodInfo? FindRenderGraphRegistryCreateTextureCallbackMethod(IEnumerable<Assembly> assemblies)
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
                if (!string.Equals(method.Name, "CreateTextureCallback", StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 2
                    && TypeNameContains(parameters[0].ParameterType, "RenderGraphContext")
                    && TypeNameContains(parameters[1].ParameterType, "IRenderGraphResource")
                    && method.ReturnType == typeof(bool);
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

    private static void DlssPassResourceHelperPostfix(MethodBase __originalMethod, object? __result)
    {
        try
        {
            if (!DlssPassResourceProbeEnabled)
            {
                return;
            }

            var log = Log;
            var bridge = Bridge;
            if (log is null || bridge is null || __result is null)
            {
                return;
            }

            int count;
            lock (Sync)
            {
                DlssPassResourceHelperCallCount++;
                count = DlssPassResourceHelperCallCount;
            }

            var methodLabel = HookTargetCatalog.FormatMethod(__originalMethod);
            var candidates = CollectDlssPassResourceTextureCandidates(__originalMethod.Name, __result);
            if (candidates.Count == 0)
            {
                if (count <= MaxDlssPassResourceHelperLogs || count % 300 == 0)
                {
                    log.LogInfo($"DLSSPass resource helper #{count}: method={methodLabel}; result={SummarizeValue(__result)}; texture candidates=none");
                }

                return;
            }

            if (count <= MaxDlssPassResourceHelperLogs || count % 300 == 0)
            {
                log.LogInfo($"DLSSPass resource helper #{count}: method={methodLabel}; candidates=[{FormatNativeTextureCandidates(candidates)}]");
                foreach (var candidate in candidates.Take(8))
                {
                    var success = bridge.ProbeD3D11Texture(candidate.Pointer);
                    var status = bridge.GetD3D11ProbeStatus();
                    if (success)
                    {
                        log.LogInfo($"DLSSPass resource helper {candidate.Label}: D3D11 probe succeeded: {status}");
                    }
                    else
                    {
                        log.LogWarning($"DLSSPass resource helper {candidate.Label}: D3D11 probe failed: {status}");
                    }
                }
            }

            TryRunDlssPassResourceDlssEvaluateInputProbe(log, bridge, methodLabel, candidates);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"DLSSPass resource helper postfix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void RenderGraphRegistryBeginExecutePrefix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        try
        {
            if (!DlssEvaluateInputProbeEnabled || !ResourceMaterializationProbeEnabled)
            {
                return;
            }

            lock (Sync)
            {
                RenderGraphResourceMaterializationCandidates.Clear();
                RenderGraphGetTextureCandidates.Clear();
                RenderGraphResourceMaterializationEpoch++;
            }
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph materialization begin-execute prefix failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void RenderGraphCreateTextureCallbackPostfix(MethodBase __originalMethod, object? __instance, object?[]? __args, object? __result)
    {
        try
        {
            if (!DlssEvaluateInputProbeEnabled || !ResourceMaterializationProbeEnabled || DlssEvaluateInputProbeSucceeded)
            {
                return;
            }

            var log = Log;
            var bridge = Bridge;
            if (log is null || bridge is null || __args is null || __args.Length < 2 || !TryConvertToBoolean(__result))
            {
                return;
            }

            var resource = __args[1];
            if (resource is null || !TypeNameContains(resource.GetType(), "TextureResource"))
            {
                return;
            }

            var resourceName = TryInvokeParameterlessString(resource, "GetName")
                ?? TryReadPropertyString(resource, "name")
                ?? SummarizeValue(resource);
            var graphicsResource = TryReadPropertyObject(resource, "graphicsResource")
                ?? TryReadFieldObject(resource, "graphicsResource");

            object? owner = null;
            var pointer = IntPtr.Zero;
            var hasPointer = graphicsResource is not null
                && TryFindNativeTexturePtr(graphicsResource, out owner, out pointer)
                && pointer != IntPtr.Zero;

            int count;
            int epoch;
            lock (Sync)
            {
                RenderGraphResourceMaterializationCallCount++;
                count = RenderGraphResourceMaterializationCallCount;
                epoch = RenderGraphResourceMaterializationEpoch;
            }

            if (IsRenderGraphDlssRelevantResource(resourceName) || count <= MaxRenderGraphResourceMaterializationLogs || count % 300 == 0)
            {
                var status = graphicsResource is null
                    ? "graphicsResource=null"
                    : hasPointer
                        ? $"nativeOwner={SummarizeValue(owner ?? graphicsResource)} nativePtr=0x{pointer.ToInt64():X}"
                        : $"graphicsResource={SummarizeValue(graphicsResource)} nativePtr=not found";
                log.LogInfo($"RenderGraph texture materialization #{count}: epoch={epoch}; resourceName={resourceName}; {status}");
            }

            if (!hasPointer || !IsRenderGraphDlssRelevantResource(resourceName))
            {
                return;
            }

            IReadOnlyList<RenderGraphTextureCandidate> snapshot;
            lock (Sync)
            {
                var candidate = new RenderGraphTextureCandidate(
                    "RenderGraphResourceRegistry.CreateTextureCallback",
                    resourceName,
                    pointer,
                    $"TextureResource.graphicsResource nativeOwner={SummarizeValue(owner ?? graphicsResource!)} epoch={epoch}");
                RenderGraphResourceMaterializationCandidates[resourceName] = candidate;
                snapshot = RenderGraphResourceMaterializationCandidates.Values.ToArray();
            }

            TryRunRenderGraphMaterializationDlssEvaluateInputProbe(log, bridge, snapshot);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph texture materialization postfix failed: {GetExceptionMessage(ex)}");
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

            if (ShouldSkipRenderGraphGetTextureForStableUserRendering())
            {
                return;
            }

            var shouldLog = ShouldLogRenderGraphGetTexture(count);
            var handle = __args is { Length: > 0 } ? __args[0] : null;
            var resourceName = TryGetRenderGraphGetTextureResourceName(__instance, handle);
            var isCandidateResource = IsRenderGraphGetTextureCandidateResource(resourceName);
            if (!ShouldInspectRenderGraphGetTextureNativePointer(isCandidateResource, shouldLog))
            {
                return;
            }

            if (__result is null)
            {
                if (shouldLog)
                {
                    var handleSummary = SummarizeValue(handle);
                    log.LogInfo($"RenderGraph GetTexture call #{count}: resourceName={resourceName ?? "unavailable"}; handle={handleSummary}; result=null; nativePtr=not found");
                }

                return;
            }

            if (!TryFindNativeTexturePtr(__result, out var owner, out var pointer) || pointer == IntPtr.Zero)
            {
                if (shouldLog)
                {
                    var handleSummary = SummarizeValue(handle);
                    var resultSummary = SummarizeValue(__result);
                    log.LogInfo($"RenderGraph GetTexture call #{count}: resourceName={resourceName ?? "unavailable"}; handle={handleSummary}; result={resultSummary}; nativePtr=not found");
                }

                return;
            }

            if (isCandidateResource)
            {
                IReadOnlyList<RenderGraphTextureCandidate> snapshot;
                lock (Sync)
                {
                    var candidate = new RenderGraphTextureCandidate(
                        "RenderGraphResourceRegistry.GetTexture",
                        resourceName!,
                        pointer,
                        $"GetTexture nativeOwner={SummarizeValue(owner ?? __result)}",
                        TryGetUnityFrameCount(out var candidateFrame) ? candidateFrame : -1);
                    RenderGraphGetTextureCandidates[resourceName!] = candidate;
                    snapshot = RenderGraphGetTextureCandidates.Values.ToArray();
                }

                TryRunRenderGraphGetTextureDlssEvaluateInputProbe(log, bridge, snapshot);
                TryRunRenderGraphGetTextureDlssSuperResolutionInputProbe(log, bridge, snapshot);
            }

            TryLogDlssEvaluateOutputFollowup(log, bridge, count, resourceName, pointer);

            if (!shouldLog)
            {
                return;
            }

            var handleSummaryForLog = SummarizeValue(handle);
            var resultSummaryForLog = SummarizeValue(__result);
            var ownerSummary = owner is null ? "unknown" : SummarizeValue(owner);
            log.LogInfo($"RenderGraph GetTexture call #{count}: resourceName={resourceName ?? "unavailable"}; handle={handleSummaryForLog}; result={resultSummaryForLog}; nativeOwner={ownerSummary}; nativePtr=0x{pointer.ToInt64():X}");
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

    private static bool ShouldLogRenderGraphGetTexture(int count)
    {
        return RenderGraphGetTextureDiagnosticLoggingEnabled && (count <= MaxRenderGraphGetTextureLogs || count % 300 == 0);
    }

    private static bool ShouldSkipRenderGraphGetTextureForStableUserRendering()
    {
        bool canSkip;
        lock (Sync)
        {
            canSkip = DlssUserRenderingEnabled
                && !DlssUserRenderingBlocked
                && DlssUserRenderingAcceptedTuple.HasValue
                && !RenderGraphGetTextureDiagnosticLoggingEnabled
                && !DlssVisibleWritebackProbeEnabled
                && DlssEvaluateOutputFollowupPointer == IntPtr.Zero;
        }

        return canSkip && WasDlssUserRenderingAttemptedThisFrameOrInterval();
    }

    private static bool ShouldInspectRenderGraphGetTextureNativePointer(bool isCandidateResource, bool shouldLog)
    {
        if (isCandidateResource || shouldLog)
        {
            return true;
        }

        lock (Sync)
        {
            return DlssEvaluateOutputFollowupPointer != IntPtr.Zero;
        }
    }

    private static bool ShouldEnableRenderGraphGetTextureDiagnosticLogging(
        bool enableFrameResourceProbe,
        bool enableDlssEvaluateInputProbe,
        bool enableDlssEvaluateProbe,
        bool enableDlssPersistentEvaluateProbe,
        bool enableDlssSuperResolutionInputProbe,
        bool enableDlssSuperResolutionEvaluateProbe,
        bool enableDlssSuperResolutionPersistentEvaluateProbe,
        bool enableDlssSuperResolutionFrameSequenceEvaluateProbe,
        bool enableDlssVisibleWritebackProbe,
        bool enableDlssPassResourceProbe)
    {
        return enableFrameResourceProbe
            || enableDlssEvaluateInputProbe
            || enableDlssEvaluateProbe
            || enableDlssPersistentEvaluateProbe
            || enableDlssSuperResolutionInputProbe
            || enableDlssSuperResolutionEvaluateProbe
            || enableDlssSuperResolutionPersistentEvaluateProbe
            || enableDlssSuperResolutionFrameSequenceEvaluateProbe
            || enableDlssVisibleWritebackProbe
            || enableDlssPassResourceProbe;
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

    private static void TryRunRenderGraphMaterializationDlssEvaluateInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (DlssEvaluateInputProbeSucceeded)
        {
            return;
        }

        var available = candidates.Where(candidate => candidate.Pointer != IntPtr.Zero).ToArray();
        var color = FindExistingRenderFuncCandidate(available, static candidate =>
            CandidateNameContains(candidate, "source")
            || CandidateNameContains(candidate, "input")
            || CandidateNameContains(candidate, "color")
            || string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal));
        var output = FindExistingRenderFuncCandidate(available, static candidate =>
            CandidateNameContains(candidate, "destination")
            || CandidateNameContains(candidate, "output")
            || CandidateNameContains(candidate, "target")
            || CandidateNameContains(candidate, "backbuffer")
            || CandidateNameContains(candidate, "afterpost")
            || CandidateNameContains(candidate, "final"));
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
            if (RenderGraphResourceMaterializationEvaluateAttemptCount >= MaxRenderGraphResourceMaterializationEvaluateAttempts)
            {
                return;
            }

            RenderGraphResourceMaterializationEvaluateAttemptCount++;
            attempt = RenderGraphResourceMaterializationEvaluateAttemptCount;
        }

        var outputSameAsColor = output.Value.Pointer == color.Value.Pointer;
        log.LogInfo(
            $"DLSS evaluate input probe RenderGraph materialization candidate #{attempt}: color={color.Value.ResourceName} 0x{color.Value.Pointer.ToInt64():X}; output={output.Value.ResourceName} 0x{output.Value.Pointer.ToInt64():X}{(outputSameAsColor ? " same-as-color" : string.Empty)}; depth={depth.Value.ResourceName} 0x{depth.Value.Pointer.ToInt64():X}; motion={motion.Value.ResourceName} 0x{motion.Value.Pointer.ToInt64():X}");

        var success = bridge.ProbeDlssEvaluateInputs(
            color.Value.Pointer,
            output.Value.Pointer,
            depth.Value.Pointer,
            motion.Value.Pointer);
        var status = bridge.GetDlssEvaluateInputStatus();
        if (success)
        {
            DlssEvaluateInputProbeSucceeded = true;
            log.LogInfo($"DLSS evaluate input probe succeeded from RenderGraph materialization: {status}");
            TryRunDlssEvaluateProbe(
                log,
                bridge,
                "RenderGraph materialization",
                color.Value.Pointer,
                output.Value.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.Value.ResourceName);
            TryRunDlssPersistentEvaluateProbe(
                log,
                bridge,
                "RenderGraph materialization",
                color.Value.Pointer,
                output.Value.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.Value.ResourceName);
        }
        else
        {
            log.LogWarning($"DLSS evaluate input probe failed from RenderGraph materialization: {status}");
        }
    }

    private static void TryRunRenderGraphGetTextureDlssEvaluateInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (DlssEvaluateInputProbeSucceeded)
        {
            return;
        }

        var available = candidates.Where(candidate => candidate.Pointer != IntPtr.Zero).ToArray();
        var color = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal));
        var output = available
            .Where(IsLikelyRenderGraphOutput)
            .OrderByDescending(GetRenderGraphOutputPriority)
            .FirstOrDefault();
        var outputMissing = output.Pointer == IntPtr.Zero;
        var depth = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraDepthStencil", StringComparison.Ordinal)
            || candidate.ResourceName.IndexOf("CameraDepth", StringComparison.OrdinalIgnoreCase) >= 0);
        var motion = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "Motion Vectors", StringComparison.Ordinal));

        if (color is null || outputMissing || depth is null || motion is null)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (RenderGraphGetTextureEvaluateAttemptCount >= MaxRenderGraphScopedEvaluateAttempts)
            {
                return;
            }

            RenderGraphGetTextureEvaluateAttemptCount++;
            attempt = RenderGraphGetTextureEvaluateAttemptCount;
        }

        var outputSameAsColor = output.Pointer == color.Value.Pointer;
        log.LogInfo(
            $"DLSS evaluate input probe RenderGraph GetTexture candidate #{attempt}: color={color.Value.ResourceName} 0x{color.Value.Pointer.ToInt64():X}; output={output.ResourceName} 0x{output.Pointer.ToInt64():X}{(outputSameAsColor ? " same-as-color" : string.Empty)}; depth={depth.Value.ResourceName} 0x{depth.Value.Pointer.ToInt64():X}; motion={motion.Value.ResourceName} 0x{motion.Value.Pointer.ToInt64():X}");

        var success = bridge.ProbeDlssEvaluateInputs(
            color.Value.Pointer,
            output.Pointer,
            depth.Value.Pointer,
            motion.Value.Pointer);
        var status = bridge.GetDlssEvaluateInputStatus();
        if (success)
        {
            DlssEvaluateInputProbeSucceeded = true;
            log.LogInfo($"DLSS evaluate input probe succeeded from RenderGraph GetTexture: {status}");
            TryRunDlssEvaluateProbe(
                log,
                bridge,
                "RenderGraph GetTexture",
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.ResourceName);
            TryRunDlssPersistentEvaluateProbe(
                log,
                bridge,
                "RenderGraph GetTexture",
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.ResourceName);
        }
        else
        {
            log.LogWarning($"DLSS evaluate input probe failed from RenderGraph GetTexture: {status}");
        }
    }

    private static void TryRunRenderGraphGetTextureDlssSuperResolutionInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (!DlssSuperResolutionInputProbeEnabled)
        {
            return;
        }

        if (DlssSuperResolutionInputProbeSucceeded)
        {
            if (DlssVisibleWritebackProbeEnabled)
            {
                TryRunDlssVisibleWritebackProbe(log, bridge, "RenderGraph GetTexture", candidates);
            }
            else if (DlssUserRenderingEnabled)
            {
                TryRunDlssUserRendering(log, bridge, "RenderGraph GetTexture", candidates);
            }
            else
            {
                TryRunDlssSuperResolutionFrameSequenceEvaluateProbe(log, bridge, "RenderGraph GetTexture", candidates);
            }
            return;
        }

        var available = candidates.Where(candidate => candidate.Pointer != IntPtr.Zero).ToArray();
        var color = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal));
        var depth = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraDepthStencil", StringComparison.Ordinal)
            || candidate.ResourceName.IndexOf("CameraDepth", StringComparison.OrdinalIgnoreCase) >= 0);
        var motion = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "Motion Vectors", StringComparison.Ordinal));

        if (color is null || depth is null || motion is null)
        {
            return;
        }

        var outputs = available
            .Where(IsLikelyRenderGraphOutput)
            .OrderByDescending(GetRenderGraphOutputPriority)
            .ToArray();
        foreach (var output in outputs)
        {
            if (output.Pointer == IntPtr.Zero || output.Pointer == color.Value.Pointer)
            {
                continue;
            }

            var tupleKey = FormatDlssResourceTupleKey(
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer);
            int attempt;
            lock (Sync)
            {
                if (DlssSuperResolutionInputProbeSucceeded
                    || DlssSuperResolutionInputProbeAttemptKeys.Contains(tupleKey)
                    || DlssSuperResolutionInputProbeAttemptCount >= MaxDlssSuperResolutionInputProbeAttempts)
                {
                    continue;
                }

                DlssSuperResolutionInputProbeAttemptKeys.Add(tupleKey);
                DlssSuperResolutionInputProbeAttemptCount++;
                attempt = DlssSuperResolutionInputProbeAttemptCount;
            }

            log.LogInfo(
                $"DLSS super-resolution input probe candidate #{attempt} from RenderGraph GetTexture: color={color.Value.ResourceName} 0x{color.Value.Pointer.ToInt64():X}; output={output.ResourceName} 0x{output.Pointer.ToInt64():X}; depth={depth.Value.ResourceName} 0x{depth.Value.Pointer.ToInt64():X}; motion={motion.Value.ResourceName} 0x{motion.Value.Pointer.ToInt64():X}");

            var success = bridge.ProbeDlssSuperResolutionInputs(
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer);
            var status = bridge.GetDlssSuperResolutionInputStatus();
            if (success)
            {
                DlssSuperResolutionInputProbeSucceeded = true;
                log.LogInfo($"DLSS super-resolution input probe succeeded from RenderGraph GetTexture: {status}");
                TryRunDlssSuperResolutionEvaluateProbe(
                    log,
                    bridge,
                    "RenderGraph GetTexture",
                    color.Value.Pointer,
                    output.Pointer,
                    depth.Value.Pointer,
                    motion.Value.Pointer,
                    output.ResourceName);
                TryRunDlssSuperResolutionPersistentEvaluateProbe(
                    log,
                    bridge,
                    "RenderGraph GetTexture",
                    color.Value.Pointer,
                    output.Pointer,
                    depth.Value.Pointer,
                    motion.Value.Pointer,
                    output.ResourceName);
                if (DlssVisibleWritebackProbeEnabled)
                {
                    TryRunDlssVisibleWritebackProbe(
                        log,
                        bridge,
                        "RenderGraph GetTexture",
                        color.Value.Pointer,
                        output.Pointer,
                        depth.Value.Pointer,
                        motion.Value.Pointer,
                        output.ResourceName);
                }
                else if (DlssUserRenderingEnabled)
                {
                    RememberDlssUserRenderingAcceptedTuple(
                        log,
                        "RenderGraph GetTexture",
                        color.Value.Pointer,
                        output.Pointer,
                        depth.Value.Pointer,
                        motion.Value.Pointer,
                        output.ResourceName);
                    TryRunDlssUserRendering(
                        log,
                        bridge,
                        "RenderGraph GetTexture",
                        color.Value.Pointer,
                        output.Pointer,
                        depth.Value.Pointer,
                        motion.Value.Pointer,
                        output.ResourceName);
                }
                else
                {
                    TryRunDlssSuperResolutionFrameSequenceEvaluateProbe(
                        log,
                        bridge,
                        "RenderGraph GetTexture",
                        color.Value.Pointer,
                        output.Pointer,
                        depth.Value.Pointer,
                        motion.Value.Pointer,
                        output.ResourceName);
                }
                return;
            }

            log.LogInfo($"DLSS super-resolution input probe not accepted from RenderGraph GetTexture: {status}");
        }
    }

    private static void TryRunDlssPassResourceDlssEvaluateInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string methodLabel,
        IReadOnlyList<NativeTextureCandidate> candidates)
    {
        if (!DlssEvaluateInputProbeEnabled || DlssEvaluateInputProbeSucceeded)
        {
            return;
        }

        var available = candidates.Where(candidate => candidate.Pointer != IntPtr.Zero).ToArray();
        var color = FindNativeTextureCandidate(available, static label => LabelEndsWith(label, "source"));
        var output = FindNativeTextureCandidate(available, static label => LabelEndsWith(label, "output"));
        var depth = FindNativeTextureCandidate(available, static label => LabelEndsWith(label, "depth"));
        var motion = FindNativeTextureCandidate(available, static label =>
            LabelEndsWith(label, "motionVectors")
            || LabelEndsWith(label, "motion"));

        if (color is null || output is null || depth is null || motion is null)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (DlssPassResourceEvaluateAttemptCount >= MaxDlssPassResourceEvaluateAttempts)
            {
                return;
            }

            DlssPassResourceEvaluateAttemptCount++;
            attempt = DlssPassResourceEvaluateAttemptCount;
        }

        log.LogInfo(
            $"DLSS evaluate input probe DLSSPass resource helper candidate #{attempt}: method={methodLabel}; color={color.Value.Label} 0x{color.Value.Pointer.ToInt64():X}; output={output.Value.Label} 0x{output.Value.Pointer.ToInt64():X}; depth={depth.Value.Label} 0x{depth.Value.Pointer.ToInt64():X}; motion={motion.Value.Label} 0x{motion.Value.Pointer.ToInt64():X}");

        var success = bridge.ProbeDlssEvaluateInputs(
            color.Value.Pointer,
            output.Value.Pointer,
            depth.Value.Pointer,
            motion.Value.Pointer);
        var status = bridge.GetDlssEvaluateInputStatus();
        if (success)
        {
            DlssEvaluateInputProbeSucceeded = true;
            log.LogInfo($"DLSS evaluate input probe succeeded from DLSSPass resource helper: {status}");
            TryRunDlssEvaluateProbe(
                log,
                bridge,
                "DLSSPass resource helper",
                color.Value.Pointer,
                output.Value.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.Value.Label);
            TryRunDlssPersistentEvaluateProbe(
                log,
                bridge,
                "DLSSPass resource helper",
                color.Value.Pointer,
                output.Value.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.Value.Label);
        }
        else
        {
            log.LogWarning($"DLSS evaluate input probe failed from DLSSPass resource helper: {status}");
        }
    }

    private static void TryRunDlssEvaluateProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName)
    {
        if (!DlssEvaluateProbeEnabled || DlssEvaluateProbeSucceeded)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (DlssEvaluateProbeAttemptCount >= MaxDlssEvaluateProbeAttempts)
            {
                return;
            }

            DlssEvaluateProbeAttemptCount++;
            attempt = DlssEvaluateProbeAttemptCount;
        }

        log.LogInfo(
            $"DLSS evaluate probe candidate #{attempt} from {source}: color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; sharpness={DlssEvaluateSettings.Sharpness}; reset={DlssEvaluateSettings.Reset}");

        var success = bridge.ProbeDlssEvaluate(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            DlssEvaluateSettings.RuntimePath,
            DlssEvaluateSettings.ApplicationDataPath,
            DlssEvaluateSettings.ApplicationId,
            DlssEvaluateSettings.PerfQualityValue,
            DlssEvaluateSettings.FeatureFlags,
            0.0f,
            0.0f,
            1.0f,
            1.0f,
            DlssEvaluateSettings.Sharpness,
            DlssEvaluateSettings.Reset);
        var status = bridge.GetDlssEvaluateStatus();
        if (success)
        {
            DlssEvaluateProbeSucceeded = true;
            TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            log.LogInfo($"DLSS evaluate probe succeeded from {source}: {status}");
        }
        else if (status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS evaluate probe blocked from {source}: {status}");
        }
        else if (status.IndexOf("skipped", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS evaluate probe skipped from {source}: {status}");
        }
        else
        {
            log.LogWarning($"DLSS evaluate probe failed from {source}: {status}");
        }
    }

    private static void TryRunDlssSuperResolutionEvaluateProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName)
    {
        if (!DlssSuperResolutionEvaluateProbeEnabled || DlssSuperResolutionEvaluateProbeSucceeded)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (DlssSuperResolutionEvaluateProbeAttemptCount >= MaxDlssSuperResolutionEvaluateProbeAttempts)
            {
                return;
            }

            DlssSuperResolutionEvaluateProbeAttemptCount++;
            attempt = DlssSuperResolutionEvaluateProbeAttemptCount;
        }

        log.LogInfo(
            $"DLSS super-resolution evaluate probe candidate #{attempt} from {source}: color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; sharpness={DlssEvaluateSettings.Sharpness}; reset={DlssEvaluateSettings.Reset}");

        var success = bridge.ProbeDlssEvaluate(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            DlssEvaluateSettings.RuntimePath,
            DlssEvaluateSettings.ApplicationDataPath,
            DlssEvaluateSettings.ApplicationId,
            DlssEvaluateSettings.PerfQualityValue,
            DlssEvaluateSettings.FeatureFlags,
            0.0f,
            0.0f,
            1.0f,
            1.0f,
            DlssEvaluateSettings.Sharpness,
            DlssEvaluateSettings.Reset);
        var status = bridge.GetDlssEvaluateStatus();
        if (success)
        {
            DlssSuperResolutionEvaluateProbeSucceeded = true;
            TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            log.LogInfo($"DLSS super-resolution evaluate probe succeeded from {source}: {status}");
        }
        else if (status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS super-resolution evaluate probe blocked from {source}: {status}");
        }
        else if (status.IndexOf("skipped", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS super-resolution evaluate probe skipped from {source}: {status}");
        }
        else
        {
            log.LogWarning($"DLSS super-resolution evaluate probe failed from {source}: {status}");
        }
    }

    private static void TryRunDlssPersistentEvaluateProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName)
    {
        if (!DlssPersistentEvaluateProbeEnabled || DlssPersistentEvaluateProbeSucceeded)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (DlssPersistentEvaluateProbeAttemptCount >= MaxDlssPersistentEvaluateProbeAttempts)
            {
                return;
            }

            DlssPersistentEvaluateProbeAttemptCount++;
            attempt = DlssPersistentEvaluateProbeAttemptCount;
        }

        const int evaluateCount = 3;
        log.LogInfo(
            $"DLSS persistent evaluate probe candidate #{attempt} from {source}: color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; sharpness={DlssEvaluateSettings.Sharpness}; reset={DlssEvaluateSettings.Reset}; evaluateCount={evaluateCount}");

        var success = bridge.ProbeDlssPersistentEvaluate(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            DlssEvaluateSettings.RuntimePath,
            DlssEvaluateSettings.ApplicationDataPath,
            DlssEvaluateSettings.ApplicationId,
            DlssEvaluateSettings.PerfQualityValue,
            DlssEvaluateSettings.FeatureFlags,
            0.0f,
            0.0f,
            1.0f,
            1.0f,
            DlssEvaluateSettings.Sharpness,
            DlssEvaluateSettings.Reset,
            evaluateCount);
        var status = bridge.GetDlssPersistentEvaluateStatus();
        if (success)
        {
            DlssPersistentEvaluateProbeSucceeded = true;
            TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            log.LogInfo($"DLSS persistent evaluate probe succeeded from {source}: {status}");
        }
        else if (status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS persistent evaluate probe blocked from {source}: {status}");
        }
        else if (status.IndexOf("skipped", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS persistent evaluate probe skipped from {source}: {status}");
        }
        else
        {
            log.LogWarning($"DLSS persistent evaluate probe failed from {source}: {status}");
        }
    }

    private static void TryRunDlssSuperResolutionPersistentEvaluateProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName)
    {
        if (!DlssSuperResolutionPersistentEvaluateProbeEnabled || DlssSuperResolutionPersistentEvaluateProbeSucceeded)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (DlssSuperResolutionPersistentEvaluateProbeAttemptCount >= MaxDlssSuperResolutionPersistentEvaluateProbeAttempts)
            {
                return;
            }

            DlssSuperResolutionPersistentEvaluateProbeAttemptCount++;
            attempt = DlssSuperResolutionPersistentEvaluateProbeAttemptCount;
        }

        const int evaluateCount = 3;
        log.LogInfo(
            $"DLSS super-resolution persistent evaluate probe candidate #{attempt} from {source}: color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; sharpness={DlssEvaluateSettings.Sharpness}; reset={DlssEvaluateSettings.Reset}; evaluateCount={evaluateCount}");

        var success = bridge.ProbeDlssPersistentEvaluate(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            DlssEvaluateSettings.RuntimePath,
            DlssEvaluateSettings.ApplicationDataPath,
            DlssEvaluateSettings.ApplicationId,
            DlssEvaluateSettings.PerfQualityValue,
            DlssEvaluateSettings.FeatureFlags,
            0.0f,
            0.0f,
            1.0f,
            1.0f,
            DlssEvaluateSettings.Sharpness,
            DlssEvaluateSettings.Reset,
            evaluateCount);
        var status = bridge.GetDlssPersistentEvaluateStatus();
        if (success)
        {
            DlssSuperResolutionPersistentEvaluateProbeSucceeded = true;
            TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            log.LogInfo($"DLSS super-resolution persistent evaluate probe succeeded from {source}: {status}");
        }
        else if (status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS super-resolution persistent evaluate probe blocked from {source}: {status}");
        }
        else if (status.IndexOf("skipped", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS super-resolution persistent evaluate probe skipped from {source}: {status}");
        }
        else
        {
            log.LogWarning($"DLSS super-resolution persistent evaluate probe failed from {source}: {status}");
        }
    }

    private static void TryRunDlssSuperResolutionFrameSequenceEvaluateProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (!DlssSuperResolutionFrameSequenceEvaluateProbeEnabled || DlssSuperResolutionFrameSequenceEvaluateProbeSucceeded)
        {
            return;
        }

        var available = candidates.Where(candidate => candidate.Pointer != IntPtr.Zero).ToArray();
        var color = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal));
        var depth = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraDepthStencil", StringComparison.Ordinal)
            || candidate.ResourceName.IndexOf("CameraDepth", StringComparison.OrdinalIgnoreCase) >= 0);
        var motion = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "Motion Vectors", StringComparison.Ordinal));

        if (color is null || depth is null || motion is null)
        {
            return;
        }

        var outputs = available
            .Where(IsLikelyRenderGraphOutput)
            .OrderByDescending(GetRenderGraphOutputPriority)
            .ToArray();
        foreach (var output in outputs)
        {
            if (output.Pointer == IntPtr.Zero || output.Pointer == color.Value.Pointer)
            {
                continue;
            }

            var accepted = bridge.ProbeDlssSuperResolutionInputs(
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer);
            if (!accepted)
            {
                continue;
            }

            TryRunDlssSuperResolutionFrameSequenceEvaluateProbe(
                log,
                bridge,
                source,
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.ResourceName);
            return;
        }
    }

    private static void TryRunDlssSuperResolutionFrameSequenceEvaluateProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName)
    {
        if (!DlssSuperResolutionFrameSequenceEvaluateProbeEnabled || DlssSuperResolutionFrameSequenceEvaluateProbeSucceeded)
        {
            return;
        }

        var attempt = 0;
        var successCount = 0;
        var shutdownForAttemptLimit = false;
        lock (Sync)
        {
            if (DlssSuperResolutionFrameSequenceEvaluateProbeAttemptCount >= MaxDlssSuperResolutionFrameSequenceEvaluateProbeAttempts)
            {
                shutdownForAttemptLimit = true;
            }
            else
            {
                DlssSuperResolutionFrameSequenceEvaluateProbeAttemptCount++;
                attempt = DlssSuperResolutionFrameSequenceEvaluateProbeAttemptCount;
                successCount = DlssSuperResolutionFrameSequenceEvaluateProbeSuccessCount;
            }
        }

        if (shutdownForAttemptLimit)
        {
            TryShutdownDlssSuperResolutionFrameSequence(log);
            return;
        }

        var reset = successCount == 0 ? DlssEvaluateSettings.Reset : 0;
        log.LogInfo(
            $"DLSS super-resolution frame-sequence evaluate probe candidate #{attempt} from {source}: color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; sharpness={DlssEvaluateSettings.Sharpness}; reset={reset}; targetSuccesses={TargetDlssSuperResolutionFrameSequenceEvaluateSuccesses}");

        var success = bridge.EvaluateDlssFrameSequence(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            DlssEvaluateSettings.RuntimePath,
            DlssEvaluateSettings.ApplicationDataPath,
            DlssEvaluateSettings.ApplicationId,
            DlssEvaluateSettings.PerfQualityValue,
            DlssEvaluateSettings.FeatureFlags,
            0.0f,
            0.0f,
            1.0f,
            1.0f,
            DlssEvaluateSettings.Sharpness,
            reset);
        var status = bridge.GetDlssFrameSequenceStatus();
        if (success)
        {
            int currentSuccessCount;
            lock (Sync)
            {
                DlssSuperResolutionFrameSequenceEvaluateProbeSuccessCount++;
                currentSuccessCount = DlssSuperResolutionFrameSequenceEvaluateProbeSuccessCount;
            }

            TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            if (currentSuccessCount >= TargetDlssSuperResolutionFrameSequenceEvaluateSuccesses)
            {
                DlssSuperResolutionFrameSequenceEvaluateProbeSucceeded = true;
                log.LogInfo($"DLSS super-resolution frame-sequence evaluate probe succeeded from {source}: sequenceSuccesses={currentSuccessCount}/{TargetDlssSuperResolutionFrameSequenceEvaluateSuccesses}; {status}");
                TryShutdownDlssSuperResolutionFrameSequence(log);
            }
            else
            {
                log.LogInfo($"DLSS super-resolution frame-sequence evaluate probe step succeeded from {source}: sequenceSuccesses={currentSuccessCount}/{TargetDlssSuperResolutionFrameSequenceEvaluateSuccesses}; {status}");
            }
        }
        else if (status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS super-resolution frame-sequence evaluate probe blocked from {source}: {status}");
        }
        else if (status.IndexOf("skipped", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS super-resolution frame-sequence evaluate probe skipped from {source}: {status}");
        }
        else
        {
            log.LogWarning($"DLSS super-resolution frame-sequence evaluate probe failed from {source}: {status}");
        }
    }

    private static void TryRunDlssUserRendering(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (!DlssUserRenderingEnabled || DlssUserRenderingBlocked)
        {
            return;
        }

        if (WasDlssUserRenderingAttemptedThisFrameOrInterval())
        {
            return;
        }

        var currentFrameKnown = TryGetUnityFrameCount(out var currentFrame);
        var available = candidates
            .Where(candidate =>
                candidate.Pointer != IntPtr.Zero
                && (!currentFrameKnown || candidate.FrameCount < 0 || candidate.FrameCount == currentFrame))
            .ToArray();
        var color = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal));
        var depth = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraDepthStencil", StringComparison.Ordinal)
            || candidate.ResourceName.IndexOf("CameraDepth", StringComparison.OrdinalIgnoreCase) >= 0);
        var motion = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "Motion Vectors", StringComparison.Ordinal));

        if (color is null || depth is null || motion is null)
        {
            return;
        }

        var outputs = available
            .Where(IsLikelyRenderGraphOutput)
            .OrderByDescending(GetRenderGraphOutputPriority)
            .ToArray();
        if (TryRunCachedDlssUserRenderingTuple(log, bridge, source, color.Value, depth.Value, motion.Value, outputs))
        {
            return;
        }

        foreach (var output in outputs)
        {
            if (output.Pointer == IntPtr.Zero || output.Pointer == color.Value.Pointer)
            {
                continue;
            }

            var accepted = bridge.ProbeDlssSuperResolutionInputs(
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer);
            if (!accepted)
            {
                continue;
            }

            RememberDlssUserRenderingAcceptedTuple(
                log,
                source,
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.ResourceName);
            TryRunDlssUserRendering(
                log,
                bridge,
                source,
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.ResourceName);
            return;
        }
    }

    private static bool TryRunCachedDlssUserRenderingTuple(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        RenderGraphTextureCandidate color,
        RenderGraphTextureCandidate depth,
        RenderGraphTextureCandidate motion,
        IReadOnlyList<RenderGraphTextureCandidate> outputs)
    {
        DlssUserRenderingResourceTuple tuple;
        lock (Sync)
        {
            if (!DlssUserRenderingAcceptedTuple.HasValue)
            {
                return false;
            }

            tuple = DlssUserRenderingAcceptedTuple.Value;
        }

        if (color.Pointer != tuple.ColorPointer
            || depth.Pointer != tuple.DepthPointer
            || motion.Pointer != tuple.MotionPointer)
        {
            return false;
        }

        foreach (var output in outputs)
        {
            if (output.Pointer != tuple.OutputPointer || output.Pointer == IntPtr.Zero)
            {
                continue;
            }

            int useCount;
            lock (Sync)
            {
                DlssUserRenderingCachedTupleUseCount++;
                useCount = DlssUserRenderingCachedTupleUseCount;
            }

            if (useCount <= 3 || useCount % 300 == 0)
            {
                log.LogInfo($"DLSS user rendering reused accepted tuple from {source}: cachedFrames={useCount}; outputResourceName={output.ResourceName ?? tuple.OutputResourceName ?? "unavailable"}");
            }

            TryRunDlssUserRendering(
                log,
                bridge,
                $"{source} cached tuple",
                tuple.ColorPointer,
                tuple.OutputPointer,
                tuple.DepthPointer,
                tuple.MotionPointer,
                output.ResourceName ?? tuple.OutputResourceName,
                "cached tuple reused; input probe not repeated for this frame");
            return true;
        }

        return false;
    }

    private static void RememberDlssUserRenderingAcceptedTuple(
        ManualLogSource log,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName)
    {
        var tuple = new DlssUserRenderingResourceTuple(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            string.IsNullOrWhiteSpace(outputResourceName) ? null : outputResourceName);
        var changed = false;
        lock (Sync)
        {
            if (!DlssUserRenderingAcceptedTuple.HasValue || !DlssUserRenderingAcceptedTuple.Value.Equals(tuple))
            {
                DlssUserRenderingAcceptedTuple = tuple;
                DlssUserRenderingCachedTupleUseCount = 0;
                changed = true;
            }
        }

        if (changed)
        {
            log.LogInfo(
                $"DLSS user rendering accepted tuple cached from {source}: color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; outputResourceName={outputResourceName ?? "unavailable"}");
        }
    }

    private static void TryRunDlssUserRendering(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName,
        string? noEvaluateStatusOverride = null)
    {
        if (!DlssUserRenderingEnabled || DlssUserRenderingBlocked)
        {
            return;
        }

        if (!TryReserveDlssUserRenderingAttempt(log, out var unityFrame, out var unityFrameKnown))
        {
            return;
        }

        int attempt;
        int successCount;
        lock (Sync)
        {
            DlssUserRenderingAttemptCount++;
            attempt = DlssUserRenderingAttemptCount;
            successCount = DlssUserRenderingSuccessCount;
        }

        var reset = successCount == 0 ? DlssEvaluateSettings.Reset : 0;
        if (ShouldLogDlssUserRenderingAttempt(attempt))
        {
            var unityFrameLabel = unityFrameKnown ? unityFrame.ToString() : "unknown";
            log.LogInfo(
                $"DLSS user rendering candidate #{attempt} from {source}: unityFrame={unityFrameLabel}; color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; outputResourceName={outputResourceName ?? "unavailable"}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; sharpness={DlssEvaluateSettings.Sharpness}; reset={reset}");
        }

        if (DlssUserRenderingNoEvaluateEnabled)
        {
            int currentAcceptedCount;
            lock (Sync)
            {
                DlssUserRenderingNoEvaluateAcceptedCount++;
                currentAcceptedCount = DlssUserRenderingNoEvaluateAcceptedCount;
                DlssUserRenderingSucceeded = true;
            }

            if (currentAcceptedCount <= 5 || currentAcceptedCount % 300 == 0)
            {
                var unityFrameLabel = unityFrameKnown ? unityFrame.ToString() : "unknown";
                var inputStatus = noEvaluateStatusOverride ?? bridge.GetDlssSuperResolutionInputStatus();
                log.LogInfo($"DLSS user rendering no-evaluate accepted from {source}: acceptedFrames={currentAcceptedCount}; unityFrame={unityFrameLabel}; outputResourceName={outputResourceName ?? "unavailable"}; {inputStatus}");
            }

            return;
        }

        var evaluateStartTimestamp = Stopwatch.GetTimestamp();
        var success = bridge.EvaluateDlssFrameSequence(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            DlssEvaluateSettings.RuntimePath,
            DlssEvaluateSettings.ApplicationDataPath,
            DlssEvaluateSettings.ApplicationId,
            DlssEvaluateSettings.PerfQualityValue,
            DlssEvaluateSettings.FeatureFlags,
            0.0f,
            0.0f,
            1.0f,
            1.0f,
            DlssEvaluateSettings.Sharpness,
            reset);
        var evaluateTicks = Stopwatch.GetTimestamp() - evaluateStartTimestamp;
        var timing = RecordDlssUserRenderingBridgeEvaluateTiming(evaluateTicks);
        var status = bridge.GetDlssFrameSequenceStatus();
        if (success)
        {
            int currentSuccessCount;
            bool firstSuccess;
            lock (Sync)
            {
                DlssUserRenderingSuccessCount++;
                currentSuccessCount = DlssUserRenderingSuccessCount;
                firstSuccess = !DlssUserRenderingSucceeded;
                DlssUserRenderingSucceeded = true;
            }

            TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            if (firstSuccess || currentSuccessCount <= 5 || currentSuccessCount % 300 == 0)
            {
                var unityFrameLabel = unityFrameKnown ? unityFrame.ToString() : "unknown";
                log.LogInfo($"DLSS user rendering evaluate succeeded from {source}: sequenceSuccesses={currentSuccessCount}; unityFrame={unityFrameLabel}; outputResourceName={outputResourceName ?? "unavailable"}; bridgeTiming={timing}; {status}");
            }
        }
        else
        {
            var statusKind = status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0
                ? "blocked"
                : status.IndexOf("skipped", StringComparison.OrdinalIgnoreCase) >= 0
                    ? "skipped"
                    : "failed";
            if (ShouldLogDlssUserRenderingFailure(attempt))
            {
                log.LogWarning($"DLSS user rendering evaluate {statusKind} from {source}: bridgeTiming={timing}; {status}");
            }

            if (string.Equals(statusKind, "blocked", StringComparison.Ordinal) || string.Equals(statusKind, "skipped", StringComparison.Ordinal))
            {
                lock (Sync)
                {
                    DlssUserRenderingBlocked = true;
                }

                log.LogWarning("DLSS user rendering candidate disabled for this session after a non-retryable native response. Check DLSS.DlssRuntimePath and native SDK-wrapper availability before re-enabling.");
            }
        }
    }

    private static string RecordDlssUserRenderingBridgeEvaluateTiming(long lastTicks)
    {
        int count;
        long totalTicks;
        long maxTicks;
        lock (Sync)
        {
            DlssUserRenderingBridgeEvaluateTimedCount++;
            DlssUserRenderingBridgeEvaluateTotalTicks += lastTicks;
            if (lastTicks > DlssUserRenderingBridgeEvaluateMaxTicks)
            {
                DlssUserRenderingBridgeEvaluateMaxTicks = lastTicks;
            }

            count = DlssUserRenderingBridgeEvaluateTimedCount;
            totalTicks = DlssUserRenderingBridgeEvaluateTotalTicks;
            maxTicks = DlssUserRenderingBridgeEvaluateMaxTicks;
        }

        var lastMs = StopwatchTicksToMilliseconds(lastTicks);
        var averageMs = count > 0 ? StopwatchTicksToMilliseconds(totalTicks) / count : 0.0;
        var maxMs = StopwatchTicksToMilliseconds(maxTicks);
        return $"lastMs={FormatMilliseconds(lastMs)},avgMs={FormatMilliseconds(averageMs)},maxMs={FormatMilliseconds(maxMs)},samples={count}";
    }

    private static double StopwatchTicksToMilliseconds(long ticks)
    {
        return ticks * 1000.0 / Stopwatch.Frequency;
    }

    private static string FormatMilliseconds(double value)
    {
        return value.ToString("0.###", CultureInfo.InvariantCulture);
    }

    private static bool WasDlssUserRenderingAttemptedThisFrameOrInterval()
    {
        if (TryGetUnityFrameCount(out var frameCount))
        {
            lock (Sync)
            {
                return DlssUserRenderingLastAttemptFrameCount == frameCount;
            }
        }

        var lastAttemptTimestamp = 0L;
        lock (Sync)
        {
            lastAttemptTimestamp = DlssUserRenderingLastAttemptTimestamp;
        }

        return lastAttemptTimestamp != 0
            && Stopwatch.GetTimestamp() - lastAttemptTimestamp < DlssUserRenderingFallbackMinAttemptTicks;
    }

    private static bool TryReserveDlssUserRenderingAttempt(ManualLogSource log, out int unityFrame, out bool unityFrameKnown)
    {
        unityFrameKnown = TryGetUnityFrameCount(out unityFrame);
        if (unityFrameKnown)
        {
            lock (Sync)
            {
                if (DlssUserRenderingLastAttemptFrameCount == unityFrame)
                {
                    return false;
                }

                DlssUserRenderingLastAttemptFrameCount = unityFrame;
                return true;
            }
        }

        var now = Stopwatch.GetTimestamp();
        lock (Sync)
        {
            if (DlssUserRenderingLastAttemptTimestamp != 0
                && now - DlssUserRenderingLastAttemptTimestamp < DlssUserRenderingFallbackMinAttemptTicks)
            {
                return false;
            }

            DlssUserRenderingLastAttemptTimestamp = now;
            if (!DlssUserRenderingFrameThrottleFallbackLogged)
            {
                DlssUserRenderingFrameThrottleFallbackLogged = true;
                log.LogWarning($"DLSS user rendering could not read UnityEngine.Time.frameCount; using a {DlssUserRenderingFallbackMaxAttemptsPerSecond} Hz wall-clock throttle.");
            }

            return true;
        }
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

    private static bool ShouldLogDlssUserRenderingAttempt(int attempt)
    {
        return attempt <= 3 || attempt % 300 == 0;
    }

    private static bool ShouldLogDlssUserRenderingFailure(int attempt)
    {
        lock (Sync)
        {
            if (DlssUserRenderingFailureLogCount < MaxDlssUserRenderingFailureLogs)
            {
                DlssUserRenderingFailureLogCount++;
                return true;
            }
        }

        return attempt % 300 == 0;
    }

    private static void TryShutdownDlssUserRendering(ManualLogSource log)
    {
        NativeBridge? bridge;
        lock (Sync)
        {
            if (!DlssUserRenderingEnabled)
            {
                return;
            }

            if (DlssUserRenderingShutdownLogged)
            {
                return;
            }

            DlssUserRenderingShutdownLogged = true;
            if (DlssUserRenderingNoEvaluateEnabled)
            {
                bridge = null;
            }
            else
            {
                bridge = Bridge;
            }
        }

        if (bridge is null)
        {
            if (DlssUserRenderingNoEvaluateEnabled)
            {
                log.LogInfo("DLSS user rendering no-evaluate shutdown skipped: no native frame sequence was created.");
            }

            return;
        }

        var success = bridge.ShutdownDlssFrameSequence();
        var status = bridge.GetDlssFrameSequenceStatus();
        if (success)
        {
            log.LogInfo($"DLSS user rendering shutdown succeeded: {status}");
        }
        else
        {
            log.LogWarning($"DLSS user rendering shutdown failed: {status}");
        }
    }

    private static void TryRunDlssVisibleWritebackProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IReadOnlyList<RenderGraphTextureCandidate> candidates)
    {
        if (!DlssVisibleWritebackProbeEnabled || (DlssVisibleWritebackProbeSucceeded && !KeepDlssVisibleWritebackProbeRunning))
        {
            return;
        }

        var available = candidates.Where(candidate => candidate.Pointer != IntPtr.Zero).ToArray();
        var color = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraColor", StringComparison.Ordinal));
        var depth = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "CameraDepthStencil", StringComparison.Ordinal)
            || candidate.ResourceName.IndexOf("CameraDepth", StringComparison.OrdinalIgnoreCase) >= 0);
        var motion = FindExistingRenderFuncCandidate(available, static candidate =>
            string.Equals(candidate.ResourceName, "Motion Vectors", StringComparison.Ordinal));

        if (color is null || depth is null || motion is null)
        {
            return;
        }

        var outputs = available
            .Where(IsLikelyRenderGraphOutput)
            .OrderByDescending(GetRenderGraphOutputPriority)
            .ToArray();
        foreach (var output in outputs)
        {
            if (output.Pointer == IntPtr.Zero || output.Pointer == color.Value.Pointer)
            {
                continue;
            }

            var accepted = bridge.ProbeDlssSuperResolutionInputs(
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer);
            if (!accepted)
            {
                continue;
            }

            TryRunDlssVisibleWritebackProbe(
                log,
                bridge,
                source,
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer,
                output.ResourceName);
            return;
        }
    }

    private static void TryRunDlssVisibleWritebackProbe(
        ManualLogSource log,
        NativeBridge bridge,
        string source,
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer,
        string? outputResourceName)
    {
        if (!DlssVisibleWritebackProbeEnabled || (DlssVisibleWritebackProbeSucceeded && !KeepDlssVisibleWritebackProbeRunning))
        {
            return;
        }

        var attempt = 0;
        var successCount = 0;
        var shutdownForAttemptLimit = false;
        var successCountAtAttemptLimit = 0;
        lock (Sync)
        {
            var maxAttempts = KeepDlssVisibleWritebackProbeRunning
                ? MaxDlssVisibleWritebackHoldAttempts
                : MaxDlssVisibleWritebackProbeAttempts;
            if (DlssVisibleWritebackProbeAttemptCount >= maxAttempts)
            {
                shutdownForAttemptLimit = true;
                successCountAtAttemptLimit = DlssVisibleWritebackProbeSuccessCount;
            }
            else
            {
                DlssVisibleWritebackProbeAttemptCount++;
                attempt = DlssVisibleWritebackProbeAttemptCount;
                successCount = DlssVisibleWritebackProbeSuccessCount;
            }
        }

        if (shutdownForAttemptLimit)
        {
            if (KeepDlssVisibleWritebackProbeRunning && successCountAtAttemptLimit >= TargetDlssVisibleWritebackProbeSuccesses)
            {
                log.LogInfo($"DLSS visible write-back hold reached attempt limit after {successCountAtAttemptLimit} successful evaluates; shutting down.");
            }
            else
            {
                log.LogWarning($"DLSS visible write-back probe failed: attempt limit reached before {TargetDlssVisibleWritebackProbeSuccesses} successful evaluates.");
            }
            TryShutdownDlssVisibleWriteback(log);
            return;
        }

        var reset = successCount == 0 ? DlssEvaluateSettings.Reset : 0;
        if (ShouldLogDlssVisibleWritebackAttempt(attempt, successCount))
        {
            log.LogInfo(
                $"DLSS visible write-back probe candidate #{attempt} from {source}: color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}; outputResourceName={outputResourceName ?? "unavailable"}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; sharpness={DlssEvaluateSettings.Sharpness}; reset={reset}; targetSuccesses={TargetDlssVisibleWritebackProbeSuccesses}; keepRunning={KeepDlssVisibleWritebackProbeRunning}");
        }

        var success = bridge.EvaluateDlssFrameSequence(
            colorPointer,
            outputPointer,
            depthPointer,
            motionPointer,
            DlssEvaluateSettings.RuntimePath,
            DlssEvaluateSettings.ApplicationDataPath,
            DlssEvaluateSettings.ApplicationId,
            DlssEvaluateSettings.PerfQualityValue,
            DlssEvaluateSettings.FeatureFlags,
            0.0f,
            0.0f,
            1.0f,
            1.0f,
            DlssEvaluateSettings.Sharpness,
            reset);
        var status = bridge.GetDlssFrameSequenceStatus();
        if (success)
        {
            int currentSuccessCount;
            bool reachedTargetNow;
            lock (Sync)
            {
                DlssVisibleWritebackProbeSuccessCount++;
                currentSuccessCount = DlssVisibleWritebackProbeSuccessCount;
                reachedTargetNow = currentSuccessCount >= TargetDlssVisibleWritebackProbeSuccesses && !DlssVisibleWritebackProbeSucceeded;
                if (reachedTargetNow)
                {
                    DlssVisibleWritebackProbeSucceeded = true;
                }
            }

            TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            if (reachedTargetNow)
            {
                log.LogInfo($"DLSS visible write-back probe succeeded from {source}: sequenceSuccesses={currentSuccessCount}/{TargetDlssVisibleWritebackProbeSuccesses}; outputResourceName={outputResourceName ?? "unavailable"}; keepRunning={KeepDlssVisibleWritebackProbeRunning}; {status}");
                if (!KeepDlssVisibleWritebackProbeRunning)
                {
                    TryShutdownDlssVisibleWriteback(log);
                }
            }
            else if (currentSuccessCount <= 5 || currentSuccessCount % 10 == 0)
            {
                log.LogInfo($"DLSS visible write-back probe step succeeded from {source}: sequenceSuccesses={currentSuccessCount}/{TargetDlssVisibleWritebackProbeSuccesses}; outputResourceName={outputResourceName ?? "unavailable"}; {status}");
            }
            else if (KeepDlssVisibleWritebackProbeRunning && currentSuccessCount > TargetDlssVisibleWritebackProbeSuccesses && currentSuccessCount % 60 == 0)
            {
                log.LogInfo($"DLSS visible write-back hold step succeeded from {source}: sequenceSuccesses={currentSuccessCount}/{TargetDlssVisibleWritebackProbeSuccesses}; outputResourceName={outputResourceName ?? "unavailable"}; {status}");
            }
        }
        else if (status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS visible write-back probe blocked from {source}: {status}");
        }
        else if (status.IndexOf("skipped", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            log.LogWarning($"DLSS visible write-back probe skipped from {source}: {status}");
        }
        else
        {
            log.LogWarning($"DLSS visible write-back probe failed from {source}: {status}");
        }
    }

    private static bool ShouldLogDlssVisibleWritebackAttempt(int attempt, int successCount)
    {
        if (!KeepDlssVisibleWritebackProbeRunning)
        {
            return true;
        }

        return attempt <= 5
            || attempt == TargetDlssVisibleWritebackProbeSuccesses
            || successCount < TargetDlssVisibleWritebackProbeSuccesses
            || attempt % 60 == 0;
    }

    private static void TryShutdownDlssVisibleWriteback(ManualLogSource log)
    {
        NativeBridge? bridge;
        lock (Sync)
        {
            if (!DlssVisibleWritebackProbeEnabled)
            {
                return;
            }

            if (DlssVisibleWritebackShutdownLogged)
            {
                return;
            }

            DlssVisibleWritebackShutdownLogged = true;
            bridge = Bridge;
        }

        if (bridge is null)
        {
            return;
        }

        var success = bridge.ShutdownDlssFrameSequence();
        var status = bridge.GetDlssFrameSequenceStatus();
        if (success)
        {
            log.LogInfo($"DLSS visible write-back shutdown succeeded: {status}");
        }
        else
        {
            log.LogWarning($"DLSS visible write-back shutdown failed: {status}");
        }
    }

    private static void TryShutdownDlssSuperResolutionFrameSequence(ManualLogSource log)
    {
        NativeBridge? bridge;
        lock (Sync)
        {
            if (DlssSuperResolutionFrameSequenceShutdownLogged)
            {
                return;
            }

            DlssSuperResolutionFrameSequenceShutdownLogged = true;
            bridge = Bridge;
        }

        if (bridge is null)
        {
            return;
        }

        var success = bridge.ShutdownDlssFrameSequence();
        var status = bridge.GetDlssFrameSequenceStatus();
        if (success)
        {
            log.LogInfo($"DLSS super-resolution frame-sequence shutdown succeeded: {status}");
        }
        else
        {
            log.LogWarning($"DLSS super-resolution frame-sequence shutdown failed: {status}");
        }
    }

    private static void TrackDlssEvaluateOutputFollowup(IntPtr outputPointer, string? outputResourceName)
    {
        lock (Sync)
        {
            DlssEvaluateOutputFollowupPointer = outputPointer;
            DlssEvaluateOutputFollowupResourceName = string.IsNullOrWhiteSpace(outputResourceName)
                ? null
                : outputResourceName;
            DlssEvaluateOutputFollowupStartGetTextureCallCount = RenderGraphGetTextureCallCount;
            DlssEvaluateOutputFollowupLogCount = 0;
        }
    }

    private static void TryLogDlssEvaluateOutputFollowup(
        ManualLogSource log,
        NativeBridge bridge,
        int getTextureCallCount,
        string? resourceName,
        IntPtr pointer)
    {
        int followup;
        int deltaCalls;
        bool samePointer;
        bool sameResourceName;
        string expectedResourceName;
        lock (Sync)
        {
            if ((!DlssEvaluateProbeSucceeded && !DlssPersistentEvaluateProbeSucceeded && !DlssSuperResolutionEvaluateProbeSucceeded && !DlssSuperResolutionPersistentEvaluateProbeSucceeded && !DlssSuperResolutionFrameSequenceEvaluateProbeSucceeded && !DlssVisibleWritebackProbeSucceeded && !DlssUserRenderingSucceeded) || DlssEvaluateOutputFollowupPointer == IntPtr.Zero)
            {
                return;
            }

            samePointer = pointer == DlssEvaluateOutputFollowupPointer;
            sameResourceName = !string.IsNullOrWhiteSpace(resourceName)
                && string.Equals(resourceName, DlssEvaluateOutputFollowupResourceName, StringComparison.OrdinalIgnoreCase);
            if (!samePointer && !sameResourceName)
            {
                return;
            }

            if (DlssEvaluateOutputFollowupLogCount >= MaxDlssEvaluateOutputFollowupLogs)
            {
                return;
            }

            var candidateDeltaCalls = getTextureCallCount - DlssEvaluateOutputFollowupStartGetTextureCallCount;
            if (candidateDeltaCalls <= 0)
            {
                return;
            }

            DlssEvaluateOutputFollowupLogCount++;
            followup = DlssEvaluateOutputFollowupLogCount;
            deltaCalls = candidateDeltaCalls;
            expectedResourceName = DlssEvaluateOutputFollowupResourceName ?? "unavailable";
        }

        var success = bridge.ProbeD3D11Texture(pointer);
        var status = bridge.GetD3D11ProbeStatus();
        var message =
            $"call={getTextureCallCount}; deltaCalls={deltaCalls}; resourceName={resourceName ?? "unavailable"}; expectedResourceName={expectedResourceName}; sameResourceName={sameResourceName}; samePointer={samePointer}; nativePtr=0x{pointer.ToInt64():X}; {status}";
        if (success)
        {
            log.LogInfo($"DLSS evaluate output follow-up #{followup}: {message}");
        }
        else
        {
            log.LogWarning($"DLSS evaluate output follow-up failed #{followup}: {message}");
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

    private static IReadOnlyList<NativeTextureCandidate> CollectDlssPassResourceTextureCandidates(string methodName, object result)
    {
        var candidates = new List<NativeTextureCandidate>();
        var seenLabels = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var seenObjects = new HashSet<int>();

        foreach (var textureObject in EnumerateNamedDlssPassTextureObjects(methodName, result, 0, seenObjects))
        {
            if (!seenLabels.Add(textureObject.Label))
            {
                continue;
            }

            if (TryFindNativeTexturePtr(textureObject.Value, out _, out var pointer) && pointer != IntPtr.Zero)
            {
                candidates.Add(new NativeTextureCandidate(textureObject.Label, pointer));
            }
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

    private static IEnumerable<NamedTextureObjectCandidate> EnumerateNamedDlssPassTextureObjects(
        string label,
        object? value,
        int depth,
        ISet<int> seenObjects)
    {
        if (value is null || depth > 3 || IsTerminalValue(value))
        {
            yield break;
        }

        var type = value.GetType();
        if (TypeLooksTextureLike(type))
        {
            yield return new NamedTextureObjectCandidate(label, value);
            yield break;
        }

        if (!type.IsValueType && !seenObjects.Add(RuntimeHelpers.GetHashCode(value)))
        {
            yield break;
        }

        const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
        foreach (var field in type.GetFields(flags))
        {
            if (!MemberMayContainDlssPassTexture(field.Name, field.FieldType))
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

            foreach (var nested in EnumerateNamedDlssPassTextureObjects($"{label}.{field.Name}", fieldValue, depth + 1, seenObjects))
            {
                yield return nested;
            }
        }

        foreach (var property in type.GetProperties(flags))
        {
            if (property.GetIndexParameters().Length != 0
                || property.GetMethod is null
                || !MemberMayContainDlssPassTexture(property.Name, property.PropertyType))
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

            foreach (var nested in EnumerateNamedDlssPassTextureObjects($"{label}.{property.Name}", propertyValue, depth + 1, seenObjects))
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

    private static bool MemberMayContainDlssPassTexture(string name, Type type)
    {
        return TypeLooksTextureLike(type)
            || name.IndexOf("resources", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("tmpView", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("source", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("output", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("depth", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("motion", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("biasColorMask", StringComparison.OrdinalIgnoreCase) >= 0;
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

    private static NativeTextureCandidate? FindNativeTextureCandidate(
        IEnumerable<NativeTextureCandidate> candidates,
        Func<string, bool> labelPredicate)
    {
        var candidate = candidates.FirstOrDefault(candidate => labelPredicate(candidate.Label));
        return candidate.Pointer == IntPtr.Zero ? null : candidate;
    }

    private static bool LabelEndsWith(string label, string suffix)
    {
        return label.EndsWith(suffix, StringComparison.OrdinalIgnoreCase)
            || label.EndsWith($".{suffix}", StringComparison.OrdinalIgnoreCase);
    }

    private static bool CandidateNameContains(RenderGraphTextureCandidate candidate, string value)
    {
        return candidate.Label.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0
            || candidate.ResourceName.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static string FormatDlssResourceTupleKey(
        IntPtr colorPointer,
        IntPtr outputPointer,
        IntPtr depthPointer,
        IntPtr motionPointer)
    {
        return $"{colorPointer.ToInt64():X}|{outputPointer.ToInt64():X}|{depthPointer.ToInt64():X}|{motionPointer.ToInt64():X}";
    }

    private static bool IsLikelyRenderGraphOutput(RenderGraphTextureCandidate candidate)
    {
        var name = candidate.ResourceName;
        return name.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("Uber Post Destination", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("TAA Destination", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("Apply Exposure Destination", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("Backbuffer", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("AfterPost", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("Output", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("Destination", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static int GetRenderGraphOutputPriority(RenderGraphTextureCandidate candidate)
    {
        var name = candidate.ResourceName;
        if (name.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0) { return 100; }
        if (name.IndexOf("Backbuffer", StringComparison.OrdinalIgnoreCase) >= 0) { return 90; }
        if (name.IndexOf("Uber Post Destination", StringComparison.OrdinalIgnoreCase) >= 0) { return 80; }
        if (name.IndexOf("Output", StringComparison.OrdinalIgnoreCase) >= 0) { return 70; }
        if (name.IndexOf("AfterPost", StringComparison.OrdinalIgnoreCase) >= 0) { return 65; }
        if (name.IndexOf("TAA Destination", StringComparison.OrdinalIgnoreCase) >= 0) { return 60; }
        if (name.IndexOf("Apply Exposure Destination", StringComparison.OrdinalIgnoreCase) >= 0) { return 50; }
        if (name.IndexOf("Destination", StringComparison.OrdinalIgnoreCase) >= 0) { return 40; }
        return 0;
    }

    private static string? TryGetRenderGraphGetTextureResourceName(object? registry, object? textureHandle)
    {
        if (registry is null || textureHandle is null)
        {
            return null;
        }

        var resourceHandle = TryGetResourceHandleFromTextureHandle(textureHandle);
        return resourceHandle is null ? null : TryGetRenderGraphResourceName(registry, resourceHandle);
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

    private static bool IsRenderGraphGetTextureCandidateResource(string? resourceName)
    {
        return IsRenderGraphDlssRelevantResource(resourceName)
            || (resourceName is not null
                && (resourceName.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0
                    || resourceName.IndexOf("Uber Post Destination", StringComparison.OrdinalIgnoreCase) >= 0
                    || resourceName.IndexOf("TAA Destination", StringComparison.OrdinalIgnoreCase) >= 0
                    || resourceName.IndexOf("Apply Exposure Destination", StringComparison.OrdinalIgnoreCase) >= 0
                    || resourceName.IndexOf("Backbuffer", StringComparison.OrdinalIgnoreCase) >= 0
                    || resourceName.IndexOf("AfterPost", StringComparison.OrdinalIgnoreCase) >= 0
                    || resourceName.IndexOf("Output", StringComparison.OrdinalIgnoreCase) >= 0
                    || resourceName.IndexOf("Destination", StringComparison.OrdinalIgnoreCase) >= 0));
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

    private static string FormatNativeTextureCandidates(IReadOnlyList<NativeTextureCandidate> candidates)
    {
        return string.Join("; ", candidates
            .Take(16)
            .Select(candidate => $"{candidate.Label} nativePtr=0x{candidate.Pointer.ToInt64():X}"));
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
            var method = FindCachedNativeTexturePtrMethod(candidate.GetType());

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

        foreach (var method in GetCachedTextureConversionMethods(type))
        {
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
        var registryType = registry.GetType();
        var handleType = handle.GetType();
        var cacheKey = $"{registryType.AssemblyQualifiedName}|{methodName}|{handleType.AssemblyQualifiedName}";
        lock (Sync)
        {
            if (ByRefResourceMethodCache.TryGetValue(cacheKey, out var cached))
            {
                return cached;
            }
        }

        MethodInfo? method = null;
        try
        {
            var handleTypeName = handleType.FullName;
            method = registryType
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
        catch
        {
            method = null;
        }

        lock (Sync)
        {
            ByRefResourceMethodCache[cacheKey] = method;
        }

        return method;
    }

    private static MethodInfo? FindCachedNativeTexturePtrMethod(Type type)
    {
        lock (Sync)
        {
            if (NativeTexturePtrMethodCache.TryGetValue(type, out var cached))
            {
                return cached;
            }
        }

        MethodInfo? method = null;
        try
        {
            method = type.GetMethod(
                "GetNativeTexturePtr",
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
                null,
                Type.EmptyTypes,
                null);
        }
        catch
        {
            method = null;
        }

        lock (Sync)
        {
            NativeTexturePtrMethodCache[type] = method;
        }

        return method;
    }

    private static MethodInfo[] GetCachedTextureConversionMethods(Type type)
    {
        lock (Sync)
        {
            if (TextureConversionMethodCache.TryGetValue(type, out var cached))
            {
                return cached;
            }
        }

        MethodInfo[] methods;
        try
        {
            methods = type
                .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static)
                .Where(method =>
                {
                    if (method.Name != "op_Implicit" && method.Name != "op_Explicit")
                    {
                        return false;
                    }

                    var parameters = method.GetParameters();
                    return parameters.Length == 1
                        && parameters[0].ParameterType == type
                        && TypeLooksTextureLike(method.ReturnType);
                })
                .ToArray();
        }
        catch
        {
            methods = Array.Empty<MethodInfo>();
        }

        lock (Sync)
        {
            TextureConversionMethodCache[type] = methods;
        }

        return methods;
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

        foreach (var property in GetCachedLikelyTextureProperties(type))
        {
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

        foreach (var field in GetCachedLikelyTextureFields(type))
        {
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

    private static PropertyInfo[] GetCachedLikelyTextureProperties(Type type)
    {
        lock (Sync)
        {
            if (LikelyTexturePropertyCache.TryGetValue(type, out var cached))
            {
                return cached;
            }
        }

        PropertyInfo[] properties;
        try
        {
            properties = type
                .GetProperties(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                .Where(property =>
                    property.GetIndexParameters().Length == 0
                    && property.GetMethod is not null
                    && (NameLooksTextureLike(property.Name) || TypeLooksTextureLike(property.PropertyType)))
                .ToArray();
        }
        catch
        {
            properties = Array.Empty<PropertyInfo>();
        }

        lock (Sync)
        {
            LikelyTexturePropertyCache[type] = properties;
        }

        return properties;
    }

    private static FieldInfo[] GetCachedLikelyTextureFields(Type type)
    {
        lock (Sync)
        {
            if (LikelyTextureFieldCache.TryGetValue(type, out var cached))
            {
                return cached;
            }
        }

        FieldInfo[] fields;
        try
        {
            fields = type
                .GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                .Where(field => NameLooksTextureLike(field.Name) || TypeLooksTextureLike(field.FieldType))
                .ToArray();
        }
        catch
        {
            fields = Array.Empty<FieldInfo>();
        }

        lock (Sync)
        {
            LikelyTextureFieldCache[type] = fields;
        }

        return fields;
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
            var property = FindCachedInstanceProperty(instance.GetType(), propertyName);

            return property?.GetValue(instance);
        }
        catch
        {
            return null;
        }
    }

    private static PropertyInfo? FindCachedInstanceProperty(Type type, string propertyName)
    {
        var cacheKey = $"{type.AssemblyQualifiedName}|{propertyName}";
        lock (Sync)
        {
            if (InstancePropertyCache.TryGetValue(cacheKey, out var cached))
            {
                return cached;
            }
        }

        PropertyInfo? property = null;
        try
        {
            property = type.GetProperty(
                propertyName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            if (property?.GetIndexParameters().Length != 0 || property?.GetMethod is null)
            {
                property = null;
            }
        }
        catch
        {
            property = null;
        }

        lock (Sync)
        {
            InstancePropertyCache[cacheKey] = property;
        }

        return property;
    }

    private static bool TryConvertToBoolean(object? value)
    {
        try
        {
            return value switch
            {
                bool boolean => boolean,
                null => false,
                _ => Convert.ToBoolean(value)
            };
        }
        catch
        {
            return false;
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
            var field = FindCachedInstanceField(instance.GetType(), fieldName);

            return field?.GetValue(instance);
        }
        catch
        {
            return null;
        }
    }

    private static FieldInfo? FindCachedInstanceField(Type type, string fieldName)
    {
        var cacheKey = $"{type.AssemblyQualifiedName}|{fieldName}";
        lock (Sync)
        {
            if (InstanceFieldCache.TryGetValue(cacheKey, out var cached))
            {
                return cached;
            }
        }

        FieldInfo? field = null;
        try
        {
            field = type.GetField(
                fieldName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
        }
        catch
        {
            field = null;
        }

        lock (Sync)
        {
            InstanceFieldCache[cacheKey] = field;
        }

        return field;
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

    private readonly record struct NamedTextureObjectCandidate(string Label, object Value);

    private readonly record struct RenderGraphTextureCandidate(string Label, string ResourceName, IntPtr Pointer, string Status, int FrameCount = -1);

    private readonly record struct RenderGraphRegistryCandidate(string Label, object Instance);

    private readonly record struct DlssUserRenderingResourceTuple(
        IntPtr ColorPointer,
        IntPtr OutputPointer,
        IntPtr DepthPointer,
        IntPtr MotionPointer,
        string? OutputResourceName);
}

internal readonly record struct DlssEvaluateProbeSettings(
    string RuntimePath,
    string ApplicationDataPath,
    ulong ApplicationId,
    int PerfQualityValue,
    int FeatureFlags,
    float Sharpness,
    int Reset);
