using BepInEx.Logging;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Threading;

namespace VrisingDLSS.Plugin;

internal static class FrameResourceProbe
{
    private const string HarmonyId = PluginInfo.Guid + ".frame-resource-probe";
    private const int MaxInitialLogsPerMethod = 5;
    private const int MaxRenderGraphBuilderDeclarationLogs = 40;
    private const int MaxRenderGraphBuilderStackLogs = 6;
    private const int MaxRenderGraphPassBoundaryLogs = 160;
    private const int MaxRenderGraphPassMapLogs = 240;
    private const int MaxRenderGraphPassListCompileLogs = 80;
    private const int MaxRenderGraphPassListEntryLogs = 320;
    private const int MaxRenderGraphPassDeclarationLogs = 260;
    private const int MaxRenderGraphPassDataSnapshotLogs = 220;
    private const int MaxRenderGraphPassRenderFuncMetadataLogs = 220;
    private const int MaxRenderGraphCompiledPassInfoLogs = 220;
    private const int MaxRenderGraphExecuteDelegateLogs = 180;
    private const int MaxNativeRenderFuncEntryStatusLogs = 80;
    private const int MaxNativeRenderFuncArgumentStatusLogs = 80;
    private const int MaxNativeRenderFuncContextStatusLogs = 80;
    private const int MaxNativeRenderFuncCommandBufferEventStatusLogs = 80;
    private const int NativeRenderFuncCommandBufferEventId = 260607;
    private const int MaxNativeRenderFuncCommandBufferPayloadStatusLogs = 80;
    private const int NativeRenderFuncCommandBufferPayloadEventId = 260608;
    private const int MaxNativeRenderFuncCommandBufferFrameDescriptorStatusLogs = 80;
    private const int NativeRenderFuncCommandBufferFrameDescriptorEventId = 260610;
    private const int MaxNativeRenderFuncCommandBufferDlssFeatureCreateStatusLogs = 80;
    private const int NativeRenderFuncCommandBufferDlssFeatureCreateEventId = 260609;
    private const int MaxNativeRenderFuncResourceIdentityStatusLogs = 80;
    private const int MaxNativeRenderFuncResourceTupleStatusLogs = 80;
    private const int MaxNativeRenderFuncResourceResolveStatusLogs = 80;
    private const int MaxNativeRenderFuncResourceNativePointerStatusLogs = 80;
    private const int NativeRenderFuncEntryStableObservationThreshold = 3;
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
    private static int RenderGraphPassBoundaryCallCount;
    private static int RenderGraphPassMapCallCount;
    private static int RenderGraphPassListCompileCallCount;
    private static int RenderGraphPassListEntryLogCount;
    private static int RenderGraphPassDeclarationLogCount;
    private static int RenderGraphPassDataSnapshotLogCount;
    private static int RenderGraphPassRenderFuncMetadataLogCount;
    private static int RenderGraphCompiledPassInfoLogCount;
    private static int RenderGraphExecuteDelegateLogCount;
    private static int NativeRenderFuncEntryStatusLogCount;
    private static int NativeRenderFuncEntryObservationLogCount;
    private static int NativeRenderFuncEntryCallCount;
    private static int NativeRenderFuncArgumentStatusLogCount;
    private static int NativeRenderFuncArgumentSampleCount;
    private static int NativeRenderFuncArgumentThisNonZeroCount;
    private static int NativeRenderFuncArgumentPassDataNonZeroCount;
    private static int NativeRenderFuncArgumentContextNonZeroCount;
    private static int NativeRenderFuncArgumentMethodInfoNonZeroCount;
    private static int NativeRenderFuncContextStatusLogCount;
    private static int NativeRenderFuncContextSampleCount;
    private static int NativeRenderFuncContextNonZeroCount;
    private static int NativeRenderFuncContextWrapSuccessCount;
    private static int NativeRenderFuncContextCmdNonNullCount;
    private static int NativeRenderFuncContextCmdPointerNonZeroCount;
    private static int NativeRenderFuncContextWrapFailureCount;
    private static int NativeRenderFuncCommandBufferEventStatusLogCount;
    private static int NativeRenderFuncCommandBufferEventIssueAttemptCount;
    private static int NativeRenderFuncCommandBufferEventIssueSuccessCount;
    private static int NativeRenderFuncCommandBufferEventIssueFailureCount;
    private static int NativeRenderFuncCommandBufferPayloadStatusLogCount;
    private static int NativeRenderFuncCommandBufferPayloadSetAttemptCount;
    private static int NativeRenderFuncCommandBufferPayloadSetSuccessCount;
    private static int NativeRenderFuncCommandBufferPayloadSetFailureCount;
    private static int NativeRenderFuncCommandBufferPayloadIssueAttemptCount;
    private static int NativeRenderFuncCommandBufferPayloadIssueSuccessCount;
    private static int NativeRenderFuncCommandBufferPayloadIssueFailureCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorStatusLogCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorSetAttemptCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorSetSuccessCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorSetFailureCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorIssueAttemptCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorIssueSuccessCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorIssueFailureCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateStatusLogCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateSetAttemptCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateSetSuccessCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateSetFailureCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateIssueAttemptCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateIssueSuccessCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateIssueFailureCount;
    private static int NativeRenderFuncResourceIdentityStatusLogCount;
    private static int NativeRenderFuncResourceTupleStatusLogCount;
    private static int NativeRenderFuncResourceResolveStatusLogCount;
    private static int NativeRenderFuncResourceNativePointerStatusLogCount;
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
    private static volatile bool DlssUserRenderingHasAcceptedTuple;
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
    private static bool RenderGraphPassBoundaryProbeEnabled;
    private static bool RenderGraphPassMapProbeEnabled;
    private static bool RenderGraphPassListProbeEnabled;
    private static bool RenderGraphPassResourceDeclarationProbeEnabled;
    private static bool RenderGraphPassDataSnapshotProbeEnabled;
    private static bool RenderGraphPassRenderFuncMetadataProbeEnabled;
    private static bool RenderGraphCompiledPassInfoProbeEnabled;
    private static bool RenderGraphExecuteDelegateProbeEnabled;
    private static bool NativeRenderFuncEntryProbeEnabled;
    private static bool NativeRenderFuncArgumentProbeEnabled;
    private static bool NativeRenderFuncContextProbeEnabled;
    private static bool NativeRenderFuncCommandBufferEventProbeEnabled;
    private static bool NativeRenderFuncCommandBufferPayloadProbeEnabled;
    private static bool NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled;
    private static bool NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled;
    private static bool NativeRenderFuncResourceIdentityProbeEnabled;
    private static bool NativeRenderFuncResourceTupleProbeEnabled;
    private static bool NativeRenderFuncResourceResolveProbeEnabled;
    private static bool NativeRenderFuncResourceNativePointerProbeEnabled;
    private static bool NativeRenderFuncResourceD3D11ProbeEnabled;
    private static bool NativeRenderFuncEntryInstallAttempted;
    private static bool NativeRenderFuncEntryInstalled;
    private static bool NativeRenderFuncEntryCountAdvancedLogged;
    private static bool NativeRenderFuncArgumentSampleAdvancedLogged;
    private static bool NativeRenderFuncContextAdvancedLogged;
    private static bool NativeRenderFuncCommandBufferEventAdvancedLogged;
    private static bool NativeRenderFuncCommandBufferPayloadAdvancedLogged;
    private static bool NativeRenderFuncCommandBufferFrameDescriptorAdvancedLogged;
    private static bool NativeRenderFuncCommandBufferDlssFeatureCreateAdvancedLogged;
    private static bool NativeRenderFuncResourceIdentityAdvancedLogged;
    private static bool NativeRenderFuncResourceTupleAdvancedLogged;
    private static bool NativeRenderFuncResourceResolveAdvancedLogged;
    private static bool NativeRenderFuncResourceNativePointerAdvancedLogged;
    private static bool NativeRenderFuncResourceD3D11AdvancedLogged;
    private static bool RenderGraphGetTextureProbeEnabled;
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
    private static bool DlssCachedTupleDriverProbeEnabled;
    private static bool DlssVisibleWritebackProbeEnabled;
    private static bool KeepDlssVisibleWritebackProbeRunning;
    private static bool DlssVisibleWritebackProbeSucceeded;
    private static bool DlssVisibleWritebackShutdownLogged;
    private static DlssEvaluateProbeSettings DlssEvaluateSettings;
    private static long NativeRenderFuncArgumentLastThisPtr;
    private static long NativeRenderFuncArgumentLastPassDataPtr;
    private static long NativeRenderFuncArgumentLastContextPtr;
    private static long NativeRenderFuncArgumentLastMethodInfoPtr;
    private static long NativeRenderFuncContextLastContextPtr;
    private static long NativeRenderFuncContextLastWrappedContextPtr;
    private static long NativeRenderFuncContextLastCommandBufferPtr;
    private static string? NativeRenderFuncContextLastCommandBufferSummary;
    private static string? NativeRenderFuncContextLastFailure;
    private static int NativeRenderFuncCommandBufferEventBeforeCount;
    private static int NativeRenderFuncCommandBufferEventLastCount;
    private static int NativeRenderFuncCommandBufferEventLastEventId;
    private static long NativeRenderFuncCommandBufferEventCallbackPtr;
    private static long NativeRenderFuncCommandBufferEventLastCommandBufferPtr;
    private static string? NativeRenderFuncCommandBufferEventLastStatus;
    private static string? NativeRenderFuncCommandBufferEventLastFailure;
    private static MethodInfo? NativeRenderFuncCommandBufferEventIssuePluginEventMethod;
    private static int NativeRenderFuncCommandBufferPayloadBeforeConsumedCount;
    private static int NativeRenderFuncCommandBufferPayloadLastConsumedCount;
    private static int NativeRenderFuncCommandBufferPayloadLastEventId;
    private static int NativeRenderFuncCommandBufferPayloadSequence;
    private static long NativeRenderFuncCommandBufferPayloadCallbackPtr;
    private static long NativeRenderFuncCommandBufferPayloadLastCommandBufferPtr;
    private static string? NativeRenderFuncCommandBufferPayloadLastStatus;
    private static string? NativeRenderFuncCommandBufferPayloadLastFailure;
    private static MethodInfo? NativeRenderFuncCommandBufferPayloadIssuePluginEventMethod;
    private static int NativeRenderFuncCommandBufferFrameDescriptorBeforeConsumedCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorLastConsumedCount;
    private static int NativeRenderFuncCommandBufferFrameDescriptorLastEventId;
    private static int NativeRenderFuncCommandBufferFrameDescriptorSequence;
    private static long NativeRenderFuncCommandBufferFrameDescriptorCallbackPtr;
    private static long NativeRenderFuncCommandBufferFrameDescriptorLastCommandBufferPtr;
    private static string? NativeRenderFuncCommandBufferFrameDescriptorLastStatus;
    private static string? NativeRenderFuncCommandBufferFrameDescriptorLastFailure;
    private static MethodInfo? NativeRenderFuncCommandBufferFrameDescriptorIssuePluginEventMethod;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateBeforeConsumedCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateLastConsumedCount;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateLastEventId;
    private static int NativeRenderFuncCommandBufferDlssFeatureCreateSequence;
    private static long NativeRenderFuncCommandBufferDlssFeatureCreateCallbackPtr;
    private static long NativeRenderFuncCommandBufferDlssFeatureCreateLastCommandBufferPtr;
    private static string? NativeRenderFuncCommandBufferDlssFeatureCreateLastStatus;
    private static string? NativeRenderFuncCommandBufferDlssFeatureCreateLastFailure;
    private static MethodInfo? NativeRenderFuncCommandBufferDlssFeatureCreateIssuePluginEventMethod;
    private static IntPtr NativeRenderFuncEntryCandidatePointer;
    private static int NativeRenderFuncEntryCandidateObservationCount;
    private static string? NativeRenderFuncEntryCandidatePassName;
    private static string? NativeRenderFuncEntryCandidateMethodSummary;
    private static object? NativeRenderFuncEntryDetour;
    private static NativeRenderFuncEntryDelegate? NativeRenderFuncEntryReplacementDelegate;
    private static NativeRenderFuncEntryDelegate? NativeRenderFuncEntryOriginalDelegate;
    private static bool UnityTimeLookupAttempted;
    private static PropertyInfo? UnityTimeFrameCountProperty;
    private static NativeRenderFuncResourceNativePointerTarget? NativeRenderFuncResourceNativePointerArmedTarget;
    private static NativeRenderFuncResourceNativePointerObservation? NativeRenderFuncResourceNativePointerSourceObservation;
    private static NativeRenderFuncResourceNativePointerObservation? NativeRenderFuncResourceNativePointerDestinationObservation;

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
        bool enableDlssCachedTupleDriverProbe = false,
        bool keepDlssVisibleWritebackProbeRunning = false,
        DlssEvaluateProbeSettings dlssEvaluateSettings = default,
        bool enableRenderGraphDiagnosticPass = false,
        bool enableExistingRenderFuncProbe = false,
        bool enableResourceMaterializationProbe = false,
        bool enableRenderGraphPassBoundaryProbe = false,
        bool enableRenderGraphPassMapProbe = false,
        bool enableRenderGraphPassListProbe = false,
        bool enableRenderGraphPassResourceDeclarationProbe = false,
        bool enableRenderGraphPassDataSnapshotProbe = false,
        bool enableRenderGraphPassRenderFuncMetadataProbe = false,
        bool enableRenderGraphCompiledPassInfoProbe = false,
        bool enableRenderGraphExecuteDelegateProbe = false,
        bool enableNativeRenderFuncEntryProbe = false,
        bool enableNativeRenderFuncArgumentProbe = false,
        bool enableNativeRenderFuncContextProbe = false,
        bool enableNativeRenderFuncCommandBufferEventProbe = false,
        bool enableNativeRenderFuncCommandBufferPayloadProbe = false,
        bool enableNativeRenderFuncCommandBufferFrameDescriptorProbe = false,
        bool enableNativeRenderFuncCommandBufferDlssFeatureCreateProbe = false,
        bool enableNativeRenderFuncResourceIdentityProbe = false,
        bool enableNativeRenderFuncResourceTupleProbe = false,
        bool enableNativeRenderFuncResourceResolveProbe = false,
        bool enableNativeRenderFuncResourceNativePointerProbe = false,
        bool enableNativeRenderFuncResourceD3D11Probe = false,
        bool enableRenderGraphGetTextureProbe = true,
        bool enableDlssPassResourceProbe = false)
    {
        var nativeRenderFuncCommandBufferEventRequested = enableNativeRenderFuncCommandBufferEventProbe;
        var nativeRenderFuncCommandBufferPayloadRequested = enableNativeRenderFuncCommandBufferPayloadProbe;
        var nativeRenderFuncCommandBufferFrameDescriptorRequested = enableNativeRenderFuncCommandBufferFrameDescriptorProbe;
        var nativeRenderFuncCommandBufferDlssFeatureCreateRequested = enableNativeRenderFuncCommandBufferDlssFeatureCreateProbe;
        var nativeRenderFuncContextRequested = enableNativeRenderFuncContextProbe || nativeRenderFuncCommandBufferEventRequested || nativeRenderFuncCommandBufferPayloadRequested || nativeRenderFuncCommandBufferFrameDescriptorRequested || nativeRenderFuncCommandBufferDlssFeatureCreateRequested;
        var nativeRenderFuncResourceNativePointerRequested = enableNativeRenderFuncResourceNativePointerProbe || enableNativeRenderFuncResourceD3D11Probe || nativeRenderFuncCommandBufferPayloadRequested || nativeRenderFuncCommandBufferFrameDescriptorRequested || nativeRenderFuncCommandBufferDlssFeatureCreateRequested;
        var nativeRenderFuncResourceTupleRequested = enableNativeRenderFuncResourceTupleProbe || enableNativeRenderFuncResourceResolveProbe || nativeRenderFuncResourceNativePointerRequested;
        var nativeRenderFuncResourceIdentityRequested = enableNativeRenderFuncResourceIdentityProbe || nativeRenderFuncResourceTupleRequested;
        var nativeRenderFuncArgumentRequested = enableNativeRenderFuncArgumentProbe || nativeRenderFuncContextRequested || nativeRenderFuncResourceIdentityRequested;
        var nativeRenderFuncEntryRequested = enableNativeRenderFuncEntryProbe || nativeRenderFuncArgumentRequested;
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
            DlssCachedTupleDriverProbeEnabled = DlssCachedTupleDriverProbeEnabled || enableDlssCachedTupleDriverProbe;
            KeepDlssVisibleWritebackProbeRunning = KeepDlssVisibleWritebackProbeRunning || (enableDlssVisibleWritebackProbe && keepDlssVisibleWritebackProbeRunning);
            if (enableDlssEvaluateProbe || enableDlssPersistentEvaluateProbe || enableDlssSuperResolutionEvaluateProbe || enableDlssSuperResolutionPersistentEvaluateProbe || enableDlssSuperResolutionFrameSequenceEvaluateProbe || enableDlssVisibleWritebackProbe || enableDlssUserRendering || enableDlssUserRenderingNoEvaluate || enableDlssCachedTupleDriverProbe || nativeRenderFuncCommandBufferDlssFeatureCreateRequested)
            {
                DlssEvaluateSettings = dlssEvaluateSettings;
            }

            RenderGraphDiagnosticPassEnabled = RenderGraphDiagnosticPassEnabled || enableRenderGraphDiagnosticPass;
            ExistingRenderFuncProbeEnabled = ExistingRenderFuncProbeEnabled || enableExistingRenderFuncProbe;
            ResourceMaterializationProbeEnabled = ResourceMaterializationProbeEnabled || enableResourceMaterializationProbe;
            RenderGraphPassBoundaryProbeEnabled = RenderGraphPassBoundaryProbeEnabled || enableRenderGraphPassBoundaryProbe;
            RenderGraphPassMapProbeEnabled = RenderGraphPassMapProbeEnabled || enableRenderGraphPassMapProbe;
            RenderGraphPassListProbeEnabled = RenderGraphPassListProbeEnabled || enableRenderGraphPassListProbe;
            RenderGraphPassResourceDeclarationProbeEnabled = RenderGraphPassResourceDeclarationProbeEnabled || enableRenderGraphPassResourceDeclarationProbe;
            RenderGraphPassDataSnapshotProbeEnabled = RenderGraphPassDataSnapshotProbeEnabled || enableRenderGraphPassDataSnapshotProbe;
            RenderGraphPassRenderFuncMetadataProbeEnabled = RenderGraphPassRenderFuncMetadataProbeEnabled || enableRenderGraphPassRenderFuncMetadataProbe;
            RenderGraphCompiledPassInfoProbeEnabled = RenderGraphCompiledPassInfoProbeEnabled || enableRenderGraphCompiledPassInfoProbe;
            RenderGraphExecuteDelegateProbeEnabled = RenderGraphExecuteDelegateProbeEnabled || enableRenderGraphExecuteDelegateProbe;
            NativeRenderFuncEntryProbeEnabled = NativeRenderFuncEntryProbeEnabled || nativeRenderFuncEntryRequested;
            NativeRenderFuncArgumentProbeEnabled = NativeRenderFuncArgumentProbeEnabled || nativeRenderFuncArgumentRequested;
            NativeRenderFuncContextProbeEnabled = NativeRenderFuncContextProbeEnabled || nativeRenderFuncContextRequested;
            NativeRenderFuncCommandBufferEventProbeEnabled = NativeRenderFuncCommandBufferEventProbeEnabled || nativeRenderFuncCommandBufferEventRequested;
            NativeRenderFuncCommandBufferPayloadProbeEnabled = NativeRenderFuncCommandBufferPayloadProbeEnabled || nativeRenderFuncCommandBufferPayloadRequested;
            NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled = NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled || nativeRenderFuncCommandBufferFrameDescriptorRequested;
            NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled = NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled || nativeRenderFuncCommandBufferDlssFeatureCreateRequested;
            NativeRenderFuncResourceIdentityProbeEnabled = NativeRenderFuncResourceIdentityProbeEnabled || nativeRenderFuncResourceIdentityRequested;
            NativeRenderFuncResourceTupleProbeEnabled = NativeRenderFuncResourceTupleProbeEnabled || nativeRenderFuncResourceTupleRequested;
            NativeRenderFuncResourceResolveProbeEnabled = NativeRenderFuncResourceResolveProbeEnabled || enableNativeRenderFuncResourceResolveProbe;
            NativeRenderFuncResourceNativePointerProbeEnabled = NativeRenderFuncResourceNativePointerProbeEnabled || nativeRenderFuncResourceNativePointerRequested;
            NativeRenderFuncResourceD3D11ProbeEnabled = NativeRenderFuncResourceD3D11ProbeEnabled || enableNativeRenderFuncResourceD3D11Probe;
            RenderGraphGetTextureProbeEnabled = RenderGraphGetTextureProbeEnabled || enableRenderGraphGetTextureProbe;
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
        DlssCachedTupleDriverProbeEnabled = enableDlssCachedTupleDriverProbe;
        KeepDlssVisibleWritebackProbeRunning = enableDlssVisibleWritebackProbe && keepDlssVisibleWritebackProbeRunning;
        DlssEvaluateSettings = dlssEvaluateSettings;
        RenderGraphDiagnosticPassEnabled = enableRenderGraphDiagnosticPass;
        ExistingRenderFuncProbeEnabled = enableExistingRenderFuncProbe;
        ResourceMaterializationProbeEnabled = enableResourceMaterializationProbe;
        RenderGraphPassBoundaryProbeEnabled = enableRenderGraphPassBoundaryProbe;
        RenderGraphPassMapProbeEnabled = enableRenderGraphPassMapProbe;
        RenderGraphPassListProbeEnabled = enableRenderGraphPassListProbe;
        RenderGraphPassResourceDeclarationProbeEnabled = enableRenderGraphPassResourceDeclarationProbe;
        RenderGraphPassDataSnapshotProbeEnabled = enableRenderGraphPassDataSnapshotProbe;
        RenderGraphPassRenderFuncMetadataProbeEnabled = enableRenderGraphPassRenderFuncMetadataProbe;
        RenderGraphCompiledPassInfoProbeEnabled = enableRenderGraphCompiledPassInfoProbe;
        RenderGraphExecuteDelegateProbeEnabled = enableRenderGraphExecuteDelegateProbe;
        NativeRenderFuncEntryProbeEnabled = nativeRenderFuncEntryRequested;
        NativeRenderFuncArgumentProbeEnabled = nativeRenderFuncArgumentRequested;
        NativeRenderFuncContextProbeEnabled = nativeRenderFuncContextRequested;
        NativeRenderFuncCommandBufferEventProbeEnabled = nativeRenderFuncCommandBufferEventRequested;
        NativeRenderFuncCommandBufferPayloadProbeEnabled = nativeRenderFuncCommandBufferPayloadRequested;
        NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled = nativeRenderFuncCommandBufferFrameDescriptorRequested;
        NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled = nativeRenderFuncCommandBufferDlssFeatureCreateRequested;
        NativeRenderFuncResourceIdentityProbeEnabled = nativeRenderFuncResourceIdentityRequested;
        NativeRenderFuncResourceTupleProbeEnabled = nativeRenderFuncResourceTupleRequested;
        NativeRenderFuncResourceResolveProbeEnabled = enableNativeRenderFuncResourceResolveProbe;
        NativeRenderFuncResourceNativePointerProbeEnabled = nativeRenderFuncResourceNativePointerRequested;
        NativeRenderFuncResourceD3D11ProbeEnabled = enableNativeRenderFuncResourceD3D11Probe;
        RenderGraphGetTextureProbeEnabled = enableRenderGraphGetTextureProbe;
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
        if (DlssCachedTupleDriverProbeEnabled)
        {
            log.LogWarning("DLSS cached tuple driver diagnostic enabled. It discovers one RenderGraph tuple, then drives the cached tuple from DynamicResolutionHandler.Update while fast-skipping steady-state GetTexture work.");
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
        if (RenderGraphPassBoundaryProbeEnabled)
        {
            log.LogWarning("High-risk RenderGraph pass-boundary probe enabled. It patches pass execution for metadata only and does not resolve textures or evaluate DLSS, but this route reproduced a coreclr startup crash in V Rising.");
        }
        if (RenderGraphPassMapProbeEnabled)
        {
            log.LogInfo("RenderGraph pass-map probe enabled. It patches OnPassAdded for read-only pass name/category logging and does not resolve textures or evaluate DLSS.");
        }
        if (RenderGraphPassListProbeEnabled)
        {
            log.LogInfo("RenderGraph pass-list probe enabled. It patches CompileRenderGraph(int) for read-only m_RenderPasses name/category snapshots and does not resolve textures or evaluate DLSS.");
        }
        if (RenderGraphPassResourceDeclarationProbeEnabled)
        {
            log.LogInfo("RenderGraph pass resource-declaration probe enabled. It patches CompileRenderGraph(int) for focused read/write handle declarations only and does not resolve textures or evaluate DLSS.");
        }
        if (RenderGraphPassDataSnapshotProbeEnabled)
        {
            log.LogInfo("RenderGraph pass-data snapshot probe enabled. It patches CompileRenderGraph(int) for focused pass data fields only and does not resolve textures or evaluate DLSS.");
        }
        if (RenderGraphPassRenderFuncMetadataProbeEnabled)
        {
            log.LogInfo("RenderGraph pass render-func metadata probe enabled. It patches CompileRenderGraph(int) to read focused pass renderFunc delegate metadata only and does not call or patch render functions.");
        }
        if (RenderGraphCompiledPassInfoProbeEnabled)
        {
            log.LogInfo("RenderGraph compiled-pass-info probe enabled. It patches CompileRenderGraph(int) for read-only focused pass culling/sync/lifetime snapshots and does not resolve textures, touch command buffers, or evaluate DLSS.");
        }
        if (RenderGraphExecuteDelegateProbeEnabled)
        {
            log.LogInfo("RenderGraph execute-delegate probe enabled. It patches closed GetExecuteDelegate<TPassData>() methods for focused pass data only and does not resolve textures, touch command buffers, or evaluate DLSS.");
        }
        if (NativeRenderFuncEntryProbeEnabled)
        {
            log.LogWarning("Native render-func entry no-op probe enabled. It waits for one stable EASU method_ptr, increments a counter, and immediately calls the original trampoline; use only for menu-only local boundary testing.");
        }
        if (NativeRenderFuncArgumentProbeEnabled)
        {
            log.LogWarning("Native render-func argument preflight enabled. It reuses the entry detour to sample raw callback argument pointers only; no pointer dereference, command buffer access, resource resolution, or DLSS evaluate.");
        }
        if (NativeRenderFuncContextProbeEnabled)
        {
            log.LogWarning("Native render-func context preflight enabled. It wraps only the proven EASU RenderGraphContext pointer and reads ctx.cmd identity; it does not issue command-buffer work or evaluate DLSS.");
        }
        if (NativeRenderFuncCommandBufferEventProbeEnabled)
        {
            log.LogWarning("Native render-func command-buffer event preflight enabled. It issues one native no-op plugin event through the proven EASU ctx.cmd boundary; it does not pass texture resources or evaluate DLSS.");
        }
        if (NativeRenderFuncCommandBufferPayloadProbeEnabled)
        {
            log.LogWarning("Native render-func command-buffer payload preflight enabled. It sets the focused EASU source/destination native texture pointers as a native pending payload, then consumes it from one ctx.cmd plugin event; it does not load NGX, evaluate DLSS, or write visible output.");
        }
        if (NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled)
        {
            log.LogWarning("Native render-func command-buffer frame-descriptor preflight enabled. It carries focused EASU source/output plus HDRP depth/motion native pointers through one ctx.cmd plugin event and records descriptor metadata only; no D3D11 validation, NGX, DLSS evaluate, or visible write-back.");
        }
        if (NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled)
        {
            log.LogWarning("Native render-func command-buffer DLSS feature-create preflight enabled. It sets the focused EASU source/destination native texture pointers as a native pending payload, then creates/releases one NGX DLSS feature from one ctx.cmd plugin event; it does not evaluate DLSS or write visible output.");
        }
        if (NativeRenderFuncResourceIdentityProbeEnabled)
        {
            log.LogWarning("Native render-func resource identity preflight enabled. It correlates raw callback pointers with managed EASU pass-data and TextureHandle identity from CompileRenderGraph only; no native-callback pointer dereference, GetTexture, command buffer access, or DLSS evaluate.");
        }
        if (NativeRenderFuncResourceTupleProbeEnabled)
        {
            log.LogWarning("Native render-func resource tuple preflight enabled. It formats the proven EASU pass-data match into input/output dimensions plus source/destination TextureHandle resource identity only; no native-callback pointer dereference, GetTexture, command buffer access, texture resolution, or DLSS evaluate.");
        }

        if (NativeRenderFuncResourceResolveProbeEnabled)
        {
            log.LogWarning("Native render-func resource resolve preflight enabled. It resolves the proven EASU source/destination TextureHandles through RenderGraphResourceRegistry.GetTextureResource only; it does not call GetTexture, read native texture pointers, touch command buffers, or evaluate DLSS.");
        }

        if (NativeRenderFuncResourceNativePointerProbeEnabled)
        {
            log.LogWarning("Native render-func resource native-pointer preflight enabled. It passively observes engine-owned GetTexture returns only for the proven EASU source/destination handles; it does not run D3D11 validation, touch command buffers, or evaluate DLSS.");
        }
        if (NativeRenderFuncResourceD3D11ProbeEnabled)
        {
            log.LogWarning("Native render-func resource D3D11 preflight enabled. It validates only the proven EASU source/destination native texture pair for D3D11 device/dimensions; no command-buffer access or DLSS evaluate.");
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

            if ((RenderGraphGetTextureProbeEnabled || NativeRenderFuncResourceNativePointerProbeEnabled)
                && TryPatchRenderGraphGetTextureMethod(
                    log,
                    assemblies,
                    harmonyMethodConstructor,
                    patchMethod,
                    patchedMethodKeys))
            {
                patched++;
            }
            else if (!RenderGraphGetTextureProbeEnabled && !NativeRenderFuncResourceNativePointerProbeEnabled)
            {
                log.LogInfo("Frame resource RenderGraph GetTexture postfix skipped by Diagnostics.EnableRenderGraphGetTextureProbe=false.");
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

        if (NativeRenderFuncResourceNativePointerProbeEnabled
            && !DlssEvaluateInputProbeEnabled
            && TryPatchRenderGraphGetTextureMethod(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys))
        {
            patched++;
        }

        if (RenderGraphPassBoundaryProbeEnabled
            && TryPatchRenderGraphExecutionScopeMethod(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys))
        {
            patched++;
        }

        if (RenderGraphPassMapProbeEnabled
            && TryPatchRenderGraphPassMapMethod(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys))
        {
            patched++;
        }

        if ((RenderGraphPassListProbeEnabled || RenderGraphPassResourceDeclarationProbeEnabled || RenderGraphPassDataSnapshotProbeEnabled || RenderGraphPassRenderFuncMetadataProbeEnabled || RenderGraphCompiledPassInfoProbeEnabled || NativeRenderFuncEntryProbeEnabled || NativeRenderFuncResourceIdentityProbeEnabled || NativeRenderFuncResourceTupleProbeEnabled || NativeRenderFuncResourceResolveProbeEnabled || NativeRenderFuncResourceNativePointerProbeEnabled)
            && TryPatchRenderGraphPassListMethod(
                log,
                assemblies,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys))
        {
            patched++;
        }

        if (RenderGraphExecuteDelegateProbeEnabled)
        {
            var executeDelegatePatched = TryPatchRenderGraphExecuteDelegateMethods(
                log,
                harmonyMethodConstructor,
                patchMethod,
                patchedMethodKeys);
            patched += executeDelegatePatched;
            log.LogInfo($"RenderGraph execute-delegate probe patched {executeDelegatePatched} method(s).");
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
            TryDisposeNativeRenderFuncEntryDetour(log);
            return;
        }

        try
        {
            TryDisposeNativeRenderFuncEntryDetour(log);
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
            RenderGraphPassBoundaryProbeEnabled = false;
            RenderGraphPassMapProbeEnabled = false;
            RenderGraphPassListProbeEnabled = false;
            RenderGraphPassResourceDeclarationProbeEnabled = false;
            RenderGraphPassDataSnapshotProbeEnabled = false;
            RenderGraphPassRenderFuncMetadataProbeEnabled = false;
            RenderGraphCompiledPassInfoProbeEnabled = false;
            RenderGraphExecuteDelegateProbeEnabled = false;
            NativeRenderFuncEntryProbeEnabled = false;
            NativeRenderFuncArgumentProbeEnabled = false;
            NativeRenderFuncContextProbeEnabled = false;
            NativeRenderFuncCommandBufferEventProbeEnabled = false;
            NativeRenderFuncCommandBufferPayloadProbeEnabled = false;
            NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled = false;
            NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled = false;
            NativeRenderFuncResourceIdentityProbeEnabled = false;
            NativeRenderFuncResourceTupleProbeEnabled = false;
            NativeRenderFuncResourceResolveProbeEnabled = false;
            NativeRenderFuncResourceNativePointerProbeEnabled = false;
            NativeRenderFuncResourceD3D11ProbeEnabled = false;
            HdrpEasuInputOutputCorrelationProbeState.Reset();
            NativeRenderFuncEntryInstallAttempted = false;
            NativeRenderFuncEntryInstalled = false;
            NativeRenderFuncEntryCountAdvancedLogged = false;
            NativeRenderFuncArgumentSampleAdvancedLogged = false;
            NativeRenderFuncContextAdvancedLogged = false;
            NativeRenderFuncCommandBufferEventAdvancedLogged = false;
            NativeRenderFuncCommandBufferPayloadAdvancedLogged = false;
            NativeRenderFuncCommandBufferFrameDescriptorAdvancedLogged = false;
            NativeRenderFuncCommandBufferDlssFeatureCreateAdvancedLogged = false;
            NativeRenderFuncResourceIdentityAdvancedLogged = false;
            NativeRenderFuncResourceTupleAdvancedLogged = false;
            NativeRenderFuncResourceResolveAdvancedLogged = false;
            NativeRenderFuncResourceNativePointerAdvancedLogged = false;
            NativeRenderFuncResourceD3D11AdvancedLogged = false;
            RenderGraphGetTextureProbeEnabled = false;
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
            DlssCachedTupleDriverProbeEnabled = false;
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
                RenderGraphPassBoundaryCallCount = 0;
                RenderGraphPassMapCallCount = 0;
                RenderGraphPassListCompileCallCount = 0;
                RenderGraphPassListEntryLogCount = 0;
                RenderGraphPassDeclarationLogCount = 0;
                RenderGraphPassDataSnapshotLogCount = 0;
                RenderGraphPassRenderFuncMetadataLogCount = 0;
                RenderGraphCompiledPassInfoLogCount = 0;
                RenderGraphExecuteDelegateLogCount = 0;
                NativeRenderFuncEntryStatusLogCount = 0;
                NativeRenderFuncEntryObservationLogCount = 0;
                NativeRenderFuncEntryCallCount = 0;
                NativeRenderFuncArgumentStatusLogCount = 0;
                NativeRenderFuncContextStatusLogCount = 0;
                NativeRenderFuncCommandBufferEventStatusLogCount = 0;
                NativeRenderFuncCommandBufferPayloadStatusLogCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorStatusLogCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateStatusLogCount = 0;
                NativeRenderFuncResourceIdentityStatusLogCount = 0;
                NativeRenderFuncResourceTupleStatusLogCount = 0;
                NativeRenderFuncResourceResolveStatusLogCount = 0;
                NativeRenderFuncResourceNativePointerStatusLogCount = 0;
                NativeRenderFuncArgumentSampleCount = 0;
                NativeRenderFuncArgumentThisNonZeroCount = 0;
                NativeRenderFuncArgumentPassDataNonZeroCount = 0;
                NativeRenderFuncArgumentContextNonZeroCount = 0;
                NativeRenderFuncArgumentMethodInfoNonZeroCount = 0;
                NativeRenderFuncContextSampleCount = 0;
                NativeRenderFuncContextNonZeroCount = 0;
                NativeRenderFuncContextWrapSuccessCount = 0;
                NativeRenderFuncContextCmdNonNullCount = 0;
                NativeRenderFuncContextCmdPointerNonZeroCount = 0;
                NativeRenderFuncContextWrapFailureCount = 0;
                NativeRenderFuncCommandBufferEventIssueAttemptCount = 0;
                NativeRenderFuncCommandBufferEventIssueSuccessCount = 0;
                NativeRenderFuncCommandBufferEventIssueFailureCount = 0;
                NativeRenderFuncCommandBufferPayloadSetAttemptCount = 0;
                NativeRenderFuncCommandBufferPayloadSetSuccessCount = 0;
                NativeRenderFuncCommandBufferPayloadSetFailureCount = 0;
                NativeRenderFuncCommandBufferPayloadIssueAttemptCount = 0;
                NativeRenderFuncCommandBufferPayloadIssueSuccessCount = 0;
                NativeRenderFuncCommandBufferPayloadIssueFailureCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorSetAttemptCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorSetSuccessCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorSetFailureCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorIssueAttemptCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorIssueSuccessCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorIssueFailureCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateSetAttemptCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateSetSuccessCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateSetFailureCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateIssueAttemptCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateIssueSuccessCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateIssueFailureCount = 0;
                NativeRenderFuncArgumentLastThisPtr = 0;
                NativeRenderFuncArgumentLastPassDataPtr = 0;
                NativeRenderFuncArgumentLastContextPtr = 0;
                NativeRenderFuncArgumentLastMethodInfoPtr = 0;
                NativeRenderFuncContextLastContextPtr = 0;
                NativeRenderFuncContextLastWrappedContextPtr = 0;
                NativeRenderFuncContextLastCommandBufferPtr = 0;
                NativeRenderFuncContextLastCommandBufferSummary = null;
                NativeRenderFuncContextLastFailure = null;
                NativeRenderFuncCommandBufferEventBeforeCount = 0;
                NativeRenderFuncCommandBufferEventLastCount = 0;
                NativeRenderFuncCommandBufferEventLastEventId = 0;
                NativeRenderFuncCommandBufferEventCallbackPtr = 0;
                NativeRenderFuncCommandBufferEventLastCommandBufferPtr = 0;
                NativeRenderFuncCommandBufferEventLastStatus = null;
                NativeRenderFuncCommandBufferEventLastFailure = null;
                NativeRenderFuncCommandBufferEventIssuePluginEventMethod = null;
                NativeRenderFuncCommandBufferPayloadBeforeConsumedCount = 0;
                NativeRenderFuncCommandBufferPayloadLastConsumedCount = 0;
                NativeRenderFuncCommandBufferPayloadLastEventId = 0;
                NativeRenderFuncCommandBufferPayloadSequence = 0;
                NativeRenderFuncCommandBufferPayloadCallbackPtr = 0;
                NativeRenderFuncCommandBufferPayloadLastCommandBufferPtr = 0;
                NativeRenderFuncCommandBufferPayloadLastStatus = null;
                NativeRenderFuncCommandBufferPayloadLastFailure = null;
                NativeRenderFuncCommandBufferPayloadIssuePluginEventMethod = null;
                NativeRenderFuncCommandBufferFrameDescriptorBeforeConsumedCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorLastConsumedCount = 0;
                NativeRenderFuncCommandBufferFrameDescriptorLastEventId = 0;
                NativeRenderFuncCommandBufferFrameDescriptorSequence = 0;
                NativeRenderFuncCommandBufferFrameDescriptorCallbackPtr = 0;
                NativeRenderFuncCommandBufferFrameDescriptorLastCommandBufferPtr = 0;
                NativeRenderFuncCommandBufferFrameDescriptorLastStatus = null;
                NativeRenderFuncCommandBufferFrameDescriptorLastFailure = null;
                NativeRenderFuncCommandBufferFrameDescriptorIssuePluginEventMethod = null;
                NativeRenderFuncCommandBufferDlssFeatureCreateBeforeConsumedCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateLastConsumedCount = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateLastEventId = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateSequence = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateCallbackPtr = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateLastCommandBufferPtr = 0;
                NativeRenderFuncCommandBufferDlssFeatureCreateLastStatus = null;
                NativeRenderFuncCommandBufferDlssFeatureCreateLastFailure = null;
                NativeRenderFuncCommandBufferDlssFeatureCreateIssuePluginEventMethod = null;
                NativeRenderFuncEntryCandidatePointer = IntPtr.Zero;
                NativeRenderFuncEntryCandidateObservationCount = 0;
                NativeRenderFuncEntryCandidatePassName = null;
                NativeRenderFuncEntryCandidateMethodSummary = null;
                NativeRenderFuncResourceNativePointerArmedTarget = null;
                NativeRenderFuncResourceNativePointerSourceObservation = null;
                NativeRenderFuncResourceNativePointerDestinationObservation = null;
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
                DlssUserRenderingHasAcceptedTuple = false;
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

    private static bool TryPatchRenderGraphPassMapMethod(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var method = FindRenderGraphPassMapMethod(assemblies);
        var postfix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphPassMapPostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (method is null || postfix is null)
        {
            log.LogWarning("RenderGraph pass-map target was not found.");
            return false;
        }

        return TryPatchPostfixMethod(
            log,
            method,
            harmonyMethodConstructor,
            patchMethod,
            postfix,
            patchedMethodKeys,
            "RenderGraph pass-map");
    }

    private static bool TryPatchRenderGraphPassListMethod(
        ManualLogSource log,
        IEnumerable<Assembly> assemblies,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
        var method = FindRenderGraphPassListMethod(assemblies);
        var postfix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphPassListPostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (method is null || postfix is null)
        {
            log.LogWarning("RenderGraph pass-list target was not found.");
            return false;
        }

        return TryPatchPostfixMethod(
            log,
            method,
            harmonyMethodConstructor,
            patchMethod,
            postfix,
            patchedMethodKeys,
            "RenderGraph pass-list");
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

    private static int TryPatchRenderGraphExecuteDelegateMethods(
        ManualLogSource log,
        ConstructorInfo harmonyMethodConstructor,
        MethodInfo patchMethod,
        ISet<string> patchedMethodKeys)
    {
#if VRISINGDLSS_LOCAL_INTEROP
        var methodDefinition = typeof(UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphPass)
            .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
            .FirstOrDefault(method =>
            {
                if (!string.Equals(method.Name, "GetExecuteDelegate", StringComparison.Ordinal)
                    || !method.IsGenericMethodDefinition)
                {
                    return false;
                }

                return method.GetParameters().Length == 0;
            });
        var postfix = typeof(FrameResourceProbe).GetMethod(nameof(RenderGraphExecuteDelegatePostfix), BindingFlags.NonPublic | BindingFlags.Static);
        if (methodDefinition is null || postfix is null)
        {
            log.LogWarning("RenderGraph execute-delegate target was not found.");
            return 0;
        }

        var patched = 0;
        foreach (var passDataType in new[]
        {
            typeof(UnityEngine.Rendering.HighDefinition.HDRenderPipeline.DLSSData),
            typeof(UnityEngine.Rendering.HighDefinition.HDRenderPipeline.UberPostPassData),
            typeof(UnityEngine.Rendering.HighDefinition.HDRenderPipeline.EASUData),
            typeof(UnityEngine.Rendering.HighDefinition.HDRenderPipeline.FinalPassData)
        })
        {
            MethodInfo method;
            try
            {
                method = methodDefinition.MakeGenericMethod(passDataType);
            }
            catch (Exception ex)
            {
                log.LogWarning($"RenderGraph execute-delegate failed to close {passDataType.FullName}: {GetExceptionMessage(ex)}");
                continue;
            }

            if (TryPatchPostfixMethod(
                log,
                method,
                harmonyMethodConstructor,
                patchMethod,
                postfix,
                patchedMethodKeys,
                $"RenderGraph execute-delegate {passDataType.Name}"))
            {
                patched++;
            }
        }

        return patched;
#else
        log.LogWarning("RenderGraph execute-delegate probe requires local V Rising interop references and was not compiled into this build.");
        return 0;
#endif
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

        var methods = renderGraphType
            .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
            .Where(IsRenderGraphExecutionScopeMethod)
            .ToArray();

        return methods.FirstOrDefault(method => method.GetParameters().Length == 3)
            ?? methods.FirstOrDefault();
    }

    private static bool IsRenderGraphExecutionScopeMethod(MethodInfo method)
    {
        if (!string.Equals(method.Name, "PreRenderPassExecute", StringComparison.Ordinal))
        {
            return false;
        }

        var parameters = method.GetParameters();
        if (parameters.Length == 3)
        {
            return parameters[0].ParameterType.IsByRef
                && TypeNameContains(parameters[0].ParameterType.GetElementType()!, "CompiledPassInfo")
                && TypeNameContains(parameters[1].ParameterType, "RenderGraphPass")
                && TypeNameContains(parameters[2].ParameterType, "RenderGraphContext");
        }

        return parameters.Length == 2
            && parameters[0].ParameterType.IsByRef
            && TypeNameContains(parameters[0].ParameterType.GetElementType()!, "CompiledPassInfo")
            && TypeNameContains(parameters[1].ParameterType, "RenderGraphContext");
    }

    private static MethodInfo? FindRenderGraphPassMapMethod(IEnumerable<Assembly> assemblies)
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
                if (!string.Equals(method.Name, "OnPassAdded", StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 1
                    && TypeNameContains(parameters[0].ParameterType, "RenderGraphPass");
            });
    }

    private static MethodInfo? FindRenderGraphPassListMethod(IEnumerable<Assembly> assemblies)
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
                if (!string.Equals(method.Name, "CompileRenderGraph", StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 1 && parameters[0].ParameterType == typeof(int);
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
        var genericSuffix = method.IsGenericMethod
            ? ":" + string.Join(",", method.GetGenericArguments().Select(type => type.FullName ?? type.Name))
            : string.Empty;
        return $"{method.Module.ModuleVersionId:N}:{method.MetadataToken}{genericSuffix}";
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
            if (RenderGraphPassBoundaryProbeEnabled)
            {
                TryLogRenderGraphPassBoundary(__originalMethod, __args);
                if (!DlssEvaluateInputProbeEnabled)
                {
                    return;
                }
            }

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

            var pass = FindRenderGraphPassArgument(__args);
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

    private static void RenderGraphPassMapPostfix(MethodBase __originalMethod, object?[]? __args)
    {
        try
        {
            if (!RenderGraphPassMapProbeEnabled)
            {
                return;
            }

            var log = Log;
            if (log is null)
            {
                return;
            }

            int count;
            lock (Sync)
            {
                RenderGraphPassMapCallCount++;
                count = RenderGraphPassMapCallCount;
            }

            if (count > MaxRenderGraphPassMapLogs && count % 300 != 0)
            {
                return;
            }

            var pass = FindRenderGraphPassArgument(__args);
            if (pass is null)
            {
                log.LogInfo($"RenderGraph pass map #{count}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; pass=not found; args=[{SummarizeArguments(__args)}]");
                return;
            }

            var passName = FirstLine(GetRenderGraphPassName(pass));
            var passType = pass.GetType().FullName ?? pass.GetType().Name;
            var category = ClassifyRenderGraphPassBoundary(passName, passType);
            log.LogInfo($"RenderGraph pass map #{count}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; pass=\"{passName}\"; category={category}; passType={passType}");
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph pass-map logging failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void RenderGraphPassListPostfix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        try
        {
            if (!RenderGraphPassListProbeEnabled
                && !RenderGraphPassResourceDeclarationProbeEnabled
                && !RenderGraphPassDataSnapshotProbeEnabled
                && !RenderGraphPassRenderFuncMetadataProbeEnabled
                && !RenderGraphCompiledPassInfoProbeEnabled
                && !NativeRenderFuncEntryProbeEnabled
                && !NativeRenderFuncResourceIdentityProbeEnabled
                && !NativeRenderFuncResourceTupleProbeEnabled
                && !NativeRenderFuncResourceResolveProbeEnabled
                && !NativeRenderFuncResourceNativePointerProbeEnabled)
            {
                return;
            }

            var log = Log;
            if (log is null || __instance is null)
            {
                return;
            }

            int compileCount;
            lock (Sync)
            {
                RenderGraphPassListCompileCallCount++;
                compileCount = RenderGraphPassListCompileCallCount;
            }

            var passesObject = TryReadPropertyObject(__instance, "m_RenderPasses")
                ?? TryReadFieldObject(__instance, "m_RenderPasses");
            if (passesObject is null)
            {
                if (RenderGraphPassListProbeEnabled
                    && (compileCount <= MaxRenderGraphPassListCompileLogs || compileCount % 300 == 0))
                {
                    log.LogInfo($"RenderGraph pass-list compile #{compileCount}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; m_RenderPasses=not found; args=[{SummarizeArguments(__args)}]");
                }

                return;
            }

            var passes = EnumerateRuntimeSequence(passesObject)
                .Where(pass => pass is not null)
                .Cast<object>()
                .ToArray();
            var declaredCount = TryReadInt(passesObject, "Count", out var count)
                ? count.ToString(CultureInfo.InvariantCulture)
                : "unknown";
            var focusCount = 0;
            var passSummaries = new List<(int Ordinal, object Pass, string Name, string TypeName, string Category)>();
            for (var index = 0; index < passes.Length; index++)
            {
                var pass = passes[index];
                var passName = FirstLine(GetRenderGraphPassName(pass));
                var passType = pass.GetType().FullName ?? pass.GetType().Name;
                var category = ClassifyRenderGraphPassBoundary(passName, passType);
                if (!string.Equals(category, "other", StringComparison.Ordinal))
                {
                    focusCount++;
                }

                passSummaries.Add((index, pass, passName, passType, category));
            }

            if (RenderGraphPassListProbeEnabled
                && (compileCount <= MaxRenderGraphPassListCompileLogs || compileCount % 300 == 0))
            {
                log.LogInfo($"RenderGraph pass-list compile #{compileCount}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; passCount={declaredCount}; enumerated={passes.Length}; focusCount={focusCount}; args=[{SummarizeArguments(__args)}]");
            }

            if (RenderGraphPassListProbeEnabled)
            {
                var logAllEntriesForCompile = compileCount <= 3;
                foreach (var summary in passSummaries)
                {
                    if (!logAllEntriesForCompile && string.Equals(summary.Category, "other", StringComparison.Ordinal))
                    {
                        continue;
                    }

                    int entryCount;
                    lock (Sync)
                    {
                        RenderGraphPassListEntryLogCount++;
                        entryCount = RenderGraphPassListEntryLogCount;
                    }

                    if (entryCount > MaxRenderGraphPassListEntryLogs && entryCount % 500 != 0)
                    {
                        continue;
                    }

                    var info = DescribeRenderGraphPassListEntry(summary.Pass);
                    log.LogInfo($"RenderGraph pass-list entry #{entryCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}{info}");
                }
            }

            TryLogRenderGraphPassResourceDeclarations(compileCount, passSummaries);
            TryLogRenderGraphPassDataSnapshots(compileCount, passSummaries);
            TryLogNativeRenderFuncResourceIdentity(compileCount, passSummaries);
            TryLogNativeRenderFuncResourceTuple(compileCount, passSummaries);
            TryLogNativeRenderFuncResourceResolve(compileCount, __instance, passSummaries);
            TryArmNativeRenderFuncResourceNativePointerTarget(compileCount, passSummaries);
            TryLogRenderGraphPassRenderFuncMetadata(compileCount, passSummaries);
            TryLogRenderGraphCompiledPassInfos(compileCount, __instance, passSummaries);
            TryLogNativeRenderFuncEntryStatus(compileCount);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph pass-list logging failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void RenderGraphExecuteDelegatePostfix(MethodBase __originalMethod, object? __instance, object? __result)
    {
        try
        {
            if (!RenderGraphExecuteDelegateProbeEnabled)
            {
                return;
            }

            var log = Log;
            if (log is null)
            {
                return;
            }

            int executeLogCount;
            lock (Sync)
            {
                RenderGraphExecuteDelegateLogCount++;
                executeLogCount = RenderGraphExecuteDelegateLogCount;
            }

            if (executeLogCount > MaxRenderGraphExecuteDelegateLogs && executeLogCount % 500 != 0)
            {
                return;
            }

            if (__instance is null)
            {
                log.LogInfo($"RenderGraph execute-delegate pass=not found #{executeLogCount}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; result={SummarizeValue(__result)}");
                return;
            }

            var passName = FirstLine(GetRenderGraphPassName(__instance));
            var passType = __instance.GetType().FullName ?? __instance.GetType().Name;
            var category = ClassifyRenderGraphPassBoundary(passName, passType);
            var passData = TryReadPropertyObject(__instance, "data")
                ?? TryReadFieldObject(__instance, "data")
                ?? TryReadTypedRenderGraphPassDataSnapshotObject(__instance, passName);
            if (passData is null)
            {
                log.LogInfo($"RenderGraph execute-delegate data=not found #{executeLogCount}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; pass=\"{passName}\"; category={category}; passType={passType}; result={SummarizeValue(__result)}");
                return;
            }

            var dataType = passData.GetType().FullName ?? passData.GetType().Name;
            var members = CollectRenderGraphPassDataSnapshotMembers(passName, dataType, passData);
            var formattedMembers = members.Count == 0
                ? "none"
                : string.Join("; ", members.Take(48).Select(FormatRenderGraphPassDataSnapshotMember));
            var truncated = members.Count > 48 ? $"; truncated={members.Count - 48}" : string.Empty;

            log.LogInfo($"RenderGraph execute-delegate #{executeLogCount}: method={HookTargetCatalog.FormatMethod(__originalMethod)}; pass=\"{passName}\"; category={category}; passType={passType}; dataType={dataType}; memberCount={members.Count}; members=[{formattedMembers}]{truncated}; result={SummarizeValue(__result)}");
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph execute-delegate logging failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void TryLogRenderGraphPassResourceDeclarations(
        int compileCount,
        IEnumerable<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!RenderGraphPassResourceDeclarationProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        foreach (var summary in passSummaries)
        {
            if (!IsFocusedRenderGraphPassDeclarationTarget(summary.Name, summary.Category))
            {
                continue;
            }

            int declarationLogCount;
            lock (Sync)
            {
                RenderGraphPassDeclarationLogCount++;
                declarationLogCount = RenderGraphPassDeclarationLogCount;
            }

            if (declarationLogCount > MaxRenderGraphPassDeclarationLogs && declarationLogCount % 500 != 0)
            {
                continue;
            }

            var declarations = CollectRenderGraphPassResourceDeclarations(summary.Pass);
            var formattedDeclarations = declarations.Count == 0
                ? "none"
                : string.Join("; ", declarations.Take(48).Select(FormatRenderGraphPassResourceDeclaration));
            var truncated = declarations.Count > 48 ? $"; truncated={declarations.Count - 48}" : string.Empty;

            log.LogInfo($"RenderGraph pass declaration #{declarationLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; declarationCount={declarations.Count}; declarations=[{formattedDeclarations}]{truncated}");
        }
    }

    private static void TryLogRenderGraphPassDataSnapshots(
        int compileCount,
        IEnumerable<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!RenderGraphPassDataSnapshotProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        foreach (var summary in passSummaries)
        {
            if (!IsFocusedRenderGraphPassDataSnapshotTarget(summary.Name, summary.TypeName, summary.Category))
            {
                continue;
            }

            int snapshotLogCount;
            lock (Sync)
            {
                RenderGraphPassDataSnapshotLogCount++;
                snapshotLogCount = RenderGraphPassDataSnapshotLogCount;
            }

            if (snapshotLogCount > MaxRenderGraphPassDataSnapshotLogs && snapshotLogCount % 500 != 0)
            {
                continue;
            }

            var passData = TryReadPropertyObject(summary.Pass, "data")
                ?? TryReadFieldObject(summary.Pass, "data")
                ?? TryReadTypedRenderGraphPassDataSnapshotObject(summary.Pass, summary.Name);
            if (passData is null)
            {
                log.LogInfo($"RenderGraph pass-data snapshot data=not found #{snapshotLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}");
                continue;
            }

            var dataType = passData.GetType().FullName ?? passData.GetType().Name;
            var members = CollectRenderGraphPassDataSnapshotMembers(summary.Name, dataType, passData);
            var formattedMembers = members.Count == 0
                ? "none"
                : string.Join("; ", members.Take(48).Select(FormatRenderGraphPassDataSnapshotMember));
            var truncated = members.Count > 48 ? $"; truncated={members.Count - 48}" : string.Empty;

            log.LogInfo($"RenderGraph pass-data snapshot #{snapshotLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}; dataType={dataType}; memberCount={members.Count}; members=[{formattedMembers}]{truncated}");
        }
    }

    private static void TryLogNativeRenderFuncResourceIdentity(
        int compileCount,
        IEnumerable<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!NativeRenderFuncResourceIdentityProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        foreach (var summary in passSummaries)
        {
            if (!IsNativeRenderFuncResourceIdentityTarget(summary.Name, summary.TypeName, summary.Category))
            {
                continue;
            }

            int statusLogCount;
            bool skipStatusLog;
            lock (Sync)
            {
                NativeRenderFuncResourceIdentityStatusLogCount++;
                statusLogCount = NativeRenderFuncResourceIdentityStatusLogCount;
                skipStatusLog = statusLogCount > MaxNativeRenderFuncResourceIdentityStatusLogs && statusLogCount % 300 != 0;
            }

            var passData = TryReadPropertyObject(summary.Pass, "data")
                ?? TryReadFieldObject(summary.Pass, "data")
                ?? TryReadTypedRenderGraphPassDataSnapshotObject(summary.Pass, summary.Name);
            if (passData is null)
            {
                if (!skipStatusLog)
                {
                    log.LogInfo($"Native render-func resource identity data=not found #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}");
                }

                continue;
            }

            var dataType = passData.GetType().FullName ?? passData.GetType().Name;
            var managedPassDataPointer = TryGetIl2CppObjectPointer(passData);
            var members = CollectRenderGraphPassDataSnapshotMembers(summary.Name, dataType, passData);
            var hasTextureIdentity = HasFocusedTextureIdentity(members);
            var formattedMembers = members.Count == 0
                ? "none"
                : string.Join("; ", members.Take(24).Select(FormatRenderGraphPassDataSnapshotMember));
            var truncated = members.Count > 24 ? $"; truncated={members.Count - 24}" : string.Empty;

            var sampleCount = Volatile.Read(ref NativeRenderFuncArgumentSampleCount);
            var entryCount = Volatile.Read(ref NativeRenderFuncEntryCallCount);
            var lastThisPtr = Volatile.Read(ref NativeRenderFuncArgumentLastThisPtr);
            var lastPassDataPtr = Volatile.Read(ref NativeRenderFuncArgumentLastPassDataPtr);
            var lastContextPtr = Volatile.Read(ref NativeRenderFuncArgumentLastContextPtr);
            var lastMethodInfoPtr = Volatile.Read(ref NativeRenderFuncArgumentLastMethodInfoPtr);

            bool installed;
            IntPtr candidatePointer;
            string? passName;
            lock (Sync)
            {
                installed = NativeRenderFuncEntryInstalled;
                candidatePointer = NativeRenderFuncEntryCandidatePointer;
                passName = NativeRenderFuncEntryCandidatePassName;
            }

            var passDataMatches = managedPassDataPointer != IntPtr.Zero
                && lastPassDataPtr != 0
                && managedPassDataPointer.ToInt64() == lastPassDataPtr;
            var shouldLogAdvanced = false;
            if (sampleCount > 0 && passDataMatches && hasTextureIdentity)
            {
                lock (Sync)
                {
                    if (!NativeRenderFuncResourceIdentityAdvancedLogged)
                    {
                        NativeRenderFuncResourceIdentityAdvancedLogged = true;
                        shouldLogAdvanced = true;
                    }
                }
            }

            if (!skipStatusLog)
            {
                log.LogInfo($"Native render-func resource identity status #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; installed={installed}; entryCount={entryCount}; sampleCount={sampleCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; nativeLastPassData=0x{lastPassDataPtr:X}; passDataMatches={passDataMatches}; hasTextureIdentity={hasTextureIdentity}; nativeLastThis=0x{lastThisPtr:X}; nativeLastContext=0x{lastContextPtr:X}; nativeLastMethodInfo=0x{lastMethodInfoPtr:X}; candidatePointer=0x{candidatePointer.ToInt64():X}; candidatePass=\"{passName ?? "unknown"}\"; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}; dataType={dataType}; memberCount={members.Count}; members=[{formattedMembers}]{truncated}");
            }

            if (shouldLogAdvanced)
            {
                log.LogInfo($"Native render-func resource identity advanced: compile={compileCount}; sampleCount={sampleCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; nativeLastPassData=0x{lastPassDataPtr:X}; passDataMatches={passDataMatches}; hasTextureIdentity={hasTextureIdentity}; pass=\"{summary.Name}\"; members=[{formattedMembers}]{truncated}");
            }
        }
    }

    private static bool IsNativeRenderFuncResourceIdentityTarget(string passName, string passType, string category)
    {
        var value = $"{passName} {passType} {category}";
        return value.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("EASUData", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static bool HasFocusedTextureIdentity(IEnumerable<RenderGraphPassDataSnapshotMember> members)
    {
        return members.Any(member =>
            (string.Equals(member.Label, "source", StringComparison.Ordinal)
                || string.Equals(member.Label, "destination", StringComparison.Ordinal))
            && (string.Equals(member.Kind, "texture", StringComparison.Ordinal)
                || string.Equals(member.Kind, "texture-resource", StringComparison.Ordinal)));
    }

    private static void TryLogNativeRenderFuncResourceTuple(
        int compileCount,
        IEnumerable<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!NativeRenderFuncResourceTupleProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        foreach (var summary in passSummaries)
        {
            if (!IsNativeRenderFuncResourceIdentityTarget(summary.Name, summary.TypeName, summary.Category))
            {
                continue;
            }

            int statusLogCount;
            bool skipStatusLog;
            lock (Sync)
            {
                NativeRenderFuncResourceTupleStatusLogCount++;
                statusLogCount = NativeRenderFuncResourceTupleStatusLogCount;
                skipStatusLog = statusLogCount > MaxNativeRenderFuncResourceTupleStatusLogs && statusLogCount % 300 != 0;
            }

            var passData = TryReadPropertyObject(summary.Pass, "data")
                ?? TryReadFieldObject(summary.Pass, "data")
                ?? TryReadTypedRenderGraphPassDataSnapshotObject(summary.Pass, summary.Name);
            if (passData is null)
            {
                if (!skipStatusLog)
                {
                    log.LogInfo($"Native render-func resource tuple data=not found #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}");
                }

                continue;
            }

            var dataType = passData.GetType().FullName ?? passData.GetType().Name;
            var managedPassDataPointer = TryGetIl2CppObjectPointer(passData);
            var members = CollectRenderGraphPassDataSnapshotMembers(summary.Name, dataType, passData);
            var hasTuple = TryBuildNativeRenderFuncResourceTuple(members, out var tuple);

            var sampleCount = Volatile.Read(ref NativeRenderFuncArgumentSampleCount);
            var entryCount = Volatile.Read(ref NativeRenderFuncEntryCallCount);
            var lastPassDataPtr = Volatile.Read(ref NativeRenderFuncArgumentLastPassDataPtr);
            var lastContextPtr = Volatile.Read(ref NativeRenderFuncArgumentLastContextPtr);
            var lastMethodInfoPtr = Volatile.Read(ref NativeRenderFuncArgumentLastMethodInfoPtr);

            bool installed;
            IntPtr candidatePointer;
            string? passName;
            lock (Sync)
            {
                installed = NativeRenderFuncEntryInstalled;
                candidatePointer = NativeRenderFuncEntryCandidatePointer;
                passName = NativeRenderFuncEntryCandidatePassName;
            }

            var passDataMatches = managedPassDataPointer != IntPtr.Zero
                && lastPassDataPtr != 0
                && managedPassDataPointer.ToInt64() == lastPassDataPtr;
            var tupleReady = sampleCount > 0 && passDataMatches && hasTuple;
            var shouldLogAdvanced = false;
            if (tupleReady)
            {
                lock (Sync)
                {
                    if (!NativeRenderFuncResourceTupleAdvancedLogged)
                    {
                        NativeRenderFuncResourceTupleAdvancedLogged = true;
                        shouldLogAdvanced = true;
                    }
                }
            }

            var tupleSummary = hasTuple
                ? FormatNativeRenderFuncResourceTuple(tuple)
                : "missing";
            if (!skipStatusLog)
            {
                log.LogInfo($"Native render-func resource tuple status #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; installed={installed}; entryCount={entryCount}; sampleCount={sampleCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; nativeLastPassData=0x{lastPassDataPtr:X}; passDataMatches={passDataMatches}; tupleReady={tupleReady}; nativeLastContext=0x{lastContextPtr:X}; nativeLastMethodInfo=0x{lastMethodInfoPtr:X}; candidatePointer=0x{candidatePointer.ToInt64():X}; candidatePass=\"{passName ?? "unknown"}\"; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}; dataType={dataType}; tuple={tupleSummary}");
            }

            if (shouldLogAdvanced)
            {
                log.LogInfo($"Native render-func resource tuple advanced: compile={compileCount}; sampleCount={sampleCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; nativeLastPassData=0x{lastPassDataPtr:X}; passDataMatches={passDataMatches}; tupleReady={tupleReady}; pass=\"{summary.Name}\"; tuple={tupleSummary}");
            }
        }
    }

    private static void TryLogNativeRenderFuncResourceResolve(
        int compileCount,
        object renderGraph,
        IEnumerable<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!NativeRenderFuncResourceResolveProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        foreach (var summary in passSummaries)
        {
            if (!IsNativeRenderFuncResourceIdentityTarget(summary.Name, summary.TypeName, summary.Category))
            {
                continue;
            }

            int statusLogCount;
            bool skipStatusLog;
            lock (Sync)
            {
                NativeRenderFuncResourceResolveStatusLogCount++;
                statusLogCount = NativeRenderFuncResourceResolveStatusLogCount;
                skipStatusLog = statusLogCount > MaxNativeRenderFuncResourceResolveStatusLogs && statusLogCount % 300 != 0;
            }

            var passData = TryReadPropertyObject(summary.Pass, "data")
                ?? TryReadFieldObject(summary.Pass, "data")
                ?? TryReadTypedRenderGraphPassDataSnapshotObject(summary.Pass, summary.Name);
            if (passData is null)
            {
                if (!skipStatusLog)
                {
                    log.LogInfo($"Native render-func resource resolve data=not found #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}");
                }

                continue;
            }

            var dataType = passData.GetType().FullName ?? passData.GetType().Name;
            var managedPassDataPointer = TryGetIl2CppObjectPointer(passData);
            var hasTuple = TryBuildNativeRenderFuncResourceTupleFromPassData(passData, out var tuple, out var sourceHandle, out var destinationHandle);

            var sampleCount = Volatile.Read(ref NativeRenderFuncArgumentSampleCount);
            var entryCount = Volatile.Read(ref NativeRenderFuncEntryCallCount);
            var lastPassDataPtr = Volatile.Read(ref NativeRenderFuncArgumentLastPassDataPtr);
            var lastContextPtr = Volatile.Read(ref NativeRenderFuncArgumentLastContextPtr);
            var lastMethodInfoPtr = Volatile.Read(ref NativeRenderFuncArgumentLastMethodInfoPtr);

            bool installed;
            IntPtr candidatePointer;
            string? passName;
            lock (Sync)
            {
                installed = NativeRenderFuncEntryInstalled;
                candidatePointer = NativeRenderFuncEntryCandidatePointer;
                passName = NativeRenderFuncEntryCandidatePassName;
            }

            var passDataMatches = managedPassDataPointer != IntPtr.Zero
                && lastPassDataPtr != 0
                && managedPassDataPointer.ToInt64() == lastPassDataPtr;
            var tupleReady = sampleCount > 0 && passDataMatches && hasTuple;
            var sourceResolve = tupleReady
                ? TryResolveNativeRenderFuncTextureResource(renderGraph, "source", sourceHandle)
                : NativeRenderFuncResourceResolveSummary.NotReady("source", "tuple not ready");
            var destinationResolve = tupleReady
                ? TryResolveNativeRenderFuncTextureResource(renderGraph, "destination", destinationHandle)
                : NativeRenderFuncResourceResolveSummary.NotReady("destination", "tuple not ready");
            var resourceReady = tupleReady && sourceResolve.TextureResourceReady && destinationResolve.TextureResourceReady;
            var graphicsReady = resourceReady && sourceResolve.GraphicsResourceReady && destinationResolve.GraphicsResourceReady;

            var shouldLogAdvanced = false;
            if (resourceReady)
            {
                lock (Sync)
                {
                    if (!NativeRenderFuncResourceResolveAdvancedLogged)
                    {
                        NativeRenderFuncResourceResolveAdvancedLogged = true;
                        shouldLogAdvanced = true;
                    }
                }
            }

            var tupleSummary = hasTuple
                ? FormatNativeRenderFuncResourceTuple(tuple)
                : "missing";
            var resolveSummary = $"source=({FormatNativeRenderFuncResourceResolve(sourceResolve)}); destination=({FormatNativeRenderFuncResourceResolve(destinationResolve)})";
            if (!skipStatusLog)
            {
                log.LogInfo($"Native render-func resource resolve status #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; installed={installed}; entryCount={entryCount}; sampleCount={sampleCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; nativeLastPassData=0x{lastPassDataPtr:X}; passDataMatches={passDataMatches}; tupleReady={tupleReady}; resourceReady={resourceReady}; graphicsReady={graphicsReady}; nativeLastContext=0x{lastContextPtr:X}; nativeLastMethodInfo=0x{lastMethodInfoPtr:X}; candidatePointer=0x{candidatePointer.ToInt64():X}; candidatePass=\"{passName ?? "unknown"}\"; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}; dataType={dataType}; tuple={tupleSummary}; resolve={resolveSummary}");
            }

            if (shouldLogAdvanced)
            {
                log.LogInfo($"Native render-func resource resolve advanced: compile={compileCount}; sampleCount={sampleCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; nativeLastPassData=0x{lastPassDataPtr:X}; passDataMatches={passDataMatches}; tupleReady={tupleReady}; resourceReady={resourceReady}; graphicsReady={graphicsReady}; pass=\"{summary.Name}\"; tuple={tupleSummary}; resolve={resolveSummary}");
            }
        }
    }

    private static bool TryBuildNativeRenderFuncResourceTuple(
        IReadOnlyList<RenderGraphPassDataSnapshotMember> members,
        out NativeRenderFuncResourceTupleSummary tuple)
    {
        tuple = default;
        var inputWidth = TryReadIntSnapshotMember(members, "inputWidth");
        var inputHeight = TryReadIntSnapshotMember(members, "inputHeight");
        var outputWidth = TryReadIntSnapshotMember(members, "outputWidth");
        var outputHeight = TryReadIntSnapshotMember(members, "outputHeight");
        var source = TryReadTextureSnapshotMember(members, "source");
        var destination = TryReadTextureSnapshotMember(members, "destination");
        if (!inputWidth.HasValue
            || !inputHeight.HasValue
            || !outputWidth.HasValue
            || !outputHeight.HasValue
            || string.IsNullOrWhiteSpace(source)
            || string.IsNullOrWhiteSpace(destination))
        {
            return false;
        }

        tuple = new NativeRenderFuncResourceTupleSummary(
            inputWidth.Value,
            inputHeight.Value,
            outputWidth.Value,
            outputHeight.Value,
            source,
            destination);
        return true;
    }

    private static bool TryBuildNativeRenderFuncResourceTupleFromPassData(
        object passData,
        out NativeRenderFuncResourceTupleSummary tuple,
        out object? sourceHandle,
        out object? destinationHandle)
    {
        tuple = default;
        sourceHandle = TryReadTextureHandleMember(passData, "source");
        destinationHandle = TryReadTextureHandleMember(passData, "destination");
        if (!TryReadInt(passData, "inputWidth", out var inputWidth)
            || !TryReadInt(passData, "inputHeight", out var inputHeight)
            || !TryReadInt(passData, "outputWidth", out var outputWidth)
            || !TryReadInt(passData, "outputHeight", out var outputHeight)
            || sourceHandle is null
            || destinationHandle is null)
        {
            return false;
        }

        tuple = new NativeRenderFuncResourceTupleSummary(
            inputWidth,
            inputHeight,
            outputWidth,
            outputHeight,
            SummarizeTextureHandleResource(sourceHandle),
            SummarizeTextureHandleResource(destinationHandle));
        return true;
    }

    private static object? TryReadTextureHandleMember(object instance, string memberName)
    {
        var value = TryReadPropertyObject(instance, memberName)
            ?? TryReadFieldObject(instance, memberName);
        return value is not null && TypeNameContains(value.GetType(), "TextureHandle")
            ? value
            : null;
    }

    private static string SummarizeTextureHandleResource(object textureHandle)
    {
        var resourceHandle = TryGetResourceHandleFromTextureHandle(textureHandle);
        return resourceHandle is null
            ? FirstLine(SummarizeValue(textureHandle))
            : FirstLine(SummarizeValue(resourceHandle));
    }

    private static NativeRenderFuncResourceResolveSummary TryResolveNativeRenderFuncTextureResource(
        object renderGraph,
        string label,
        object? textureHandle)
    {
        if (textureHandle is null)
        {
            return NativeRenderFuncResourceResolveSummary.NotReady(label, "TextureHandle missing");
        }

        if (!TypeNameContains(textureHandle.GetType(), "TextureHandle"))
        {
            return NativeRenderFuncResourceResolveSummary.NotReady(label, $"not a TextureHandle: {FirstLine(SummarizeValue(textureHandle))}");
        }

        var resourceHandle = TryGetResourceHandleFromTextureHandle(textureHandle);
        if (resourceHandle is null)
        {
            return NativeRenderFuncResourceResolveSummary.NotReady(label, "TextureHandle.handle not readable");
        }

        var registries = EnumerateRenderGraphRegistries(renderGraph).ToArray();
        if (registries.Length == 0)
        {
            return NativeRenderFuncResourceResolveSummary.NotReady(label, "no RenderGraphResourceRegistry candidate found");
        }

        var details = new List<string>();
        var textureResourceReady = false;
        var graphicsResourceReady = false;
        foreach (var registry in registries)
        {
            var method = FindByRefResourceMethod(registry.Instance, "GetTextureResource", resourceHandle);
            if (method is null)
            {
                details.Add($"{registry.Label}.GetTextureResource missing");
                continue;
            }

            object? textureResource;
            try
            {
                textureResource = method.Invoke(registry.Instance, new[] { resourceHandle });
            }
            catch (Exception ex)
            {
                details.Add($"{registry.Label}.GetTextureResource threw {FirstLine(GetExceptionMessage(ex))}");
                continue;
            }

            if (textureResource is null)
            {
                details.Add($"{registry.Label}.GetTextureResource returned null");
                continue;
            }

            textureResourceReady = true;
            var textureSummary = FirstLine(SummarizeValue(textureResource));
            var graphicsResource = TryReadPropertyObject(textureResource, "graphicsResource")
                ?? TryReadFieldObject(textureResource, "graphicsResource");
            if (graphicsResource is null)
            {
                details.Add($"{registry.Label}.GetTextureResource returned {textureSummary}; graphicsResource=null");
                continue;
            }

            graphicsResourceReady = true;
            details.Add($"{registry.Label}.GetTextureResource returned {textureSummary}; graphicsResource={FirstLine(SummarizeValue(graphicsResource))}");
        }

        return new NativeRenderFuncResourceResolveSummary(
            label,
            SummarizeTextureHandleResource(textureHandle),
            textureResourceReady,
            graphicsResourceReady,
            details.Count == 0 ? "no registry calls made" : string.Join("; ", details));
    }

    private static string FormatNativeRenderFuncResourceResolve(NativeRenderFuncResourceResolveSummary summary)
    {
        return $"handle=\"{summary.Handle}\"; textureResourceReady={summary.TextureResourceReady}; graphicsResourceReady={summary.GraphicsResourceReady}; details=\"{summary.Details}\"";
    }

    private static void TryArmNativeRenderFuncResourceNativePointerTarget(
        int compileCount,
        IEnumerable<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!NativeRenderFuncResourceNativePointerProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        foreach (var summary in passSummaries)
        {
            if (!IsNativeRenderFuncResourceIdentityTarget(summary.Name, summary.TypeName, summary.Category))
            {
                continue;
            }

            int statusLogCount;
            bool skipStatusLog;
            lock (Sync)
            {
                NativeRenderFuncResourceNativePointerStatusLogCount++;
                statusLogCount = NativeRenderFuncResourceNativePointerStatusLogCount;
                skipStatusLog = statusLogCount > MaxNativeRenderFuncResourceNativePointerStatusLogs && statusLogCount % 300 != 0;
            }

            var passData = TryReadPropertyObject(summary.Pass, "data")
                ?? TryReadFieldObject(summary.Pass, "data")
                ?? TryReadTypedRenderGraphPassDataSnapshotObject(summary.Pass, summary.Name);
            if (passData is null)
            {
                if (!skipStatusLog)
                {
                    log.LogInfo($"Native render-func resource native-pointer data=not found #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}");
                }

                continue;
            }

            var dataType = passData.GetType().FullName ?? passData.GetType().Name;
            var managedPassDataPointer = TryGetIl2CppObjectPointer(passData);
            var hasTuple = TryBuildNativeRenderFuncResourceTupleFromPassData(passData, out var tuple, out var sourceHandle, out var destinationHandle);

            var sampleCount = Volatile.Read(ref NativeRenderFuncArgumentSampleCount);
            var entryCount = Volatile.Read(ref NativeRenderFuncEntryCallCount);
            var lastPassDataPtr = Volatile.Read(ref NativeRenderFuncArgumentLastPassDataPtr);
            var lastContextPtr = Volatile.Read(ref NativeRenderFuncArgumentLastContextPtr);
            var lastMethodInfoPtr = Volatile.Read(ref NativeRenderFuncArgumentLastMethodInfoPtr);

            var passDataMatches = managedPassDataPointer != IntPtr.Zero
                && lastPassDataPtr != 0
                && managedPassDataPointer.ToInt64() == lastPassDataPtr;
            var tupleReady = sampleCount > 0 && passDataMatches && hasTuple;
            var tupleSummary = hasTuple
                ? FormatNativeRenderFuncResourceTuple(tuple)
                : "missing";
            var sourceResource = sourceHandle is null ? "unavailable" : SummarizeTextureHandleResource(sourceHandle);
            var destinationResource = destinationHandle is null ? "unavailable" : SummarizeTextureHandleResource(destinationHandle);

            bool targetArmed = false;
            bool targetChanged = false;
            if (tupleReady && sourceHandle is not null && destinationHandle is not null)
            {
                var target = new NativeRenderFuncResourceNativePointerTarget(
                    compileCount,
                    managedPassDataPointer.ToInt64(),
                    sourceResource,
                    destinationResource,
                    tupleSummary);
                lock (Sync)
                {
                    var current = NativeRenderFuncResourceNativePointerArmedTarget;
                    var allowCorrelationTargetRefresh = HdrpEasuInputOutputCorrelationProbeState.ShouldRefreshEasuOutput();
                    var allowFrameDescriptorTargetRefresh = NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled
                        && Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorSetSuccessCount) <= 0;
                    targetChanged = !current.HasValue
                        || ((allowCorrelationTargetRefresh || allowFrameDescriptorTargetRefresh) && current.Value.CompileCount != target.CompileCount)
                        || !string.Equals(current.Value.SourceResourceHandle, target.SourceResourceHandle, StringComparison.Ordinal)
                        || !string.Equals(current.Value.DestinationResourceHandle, target.DestinationResourceHandle, StringComparison.Ordinal);
                    if (targetChanged && (!NativeRenderFuncResourceNativePointerAdvancedLogged || allowCorrelationTargetRefresh || allowFrameDescriptorTargetRefresh))
                    {
                        NativeRenderFuncResourceNativePointerArmedTarget = target;
                        NativeRenderFuncResourceNativePointerSourceObservation = null;
                        NativeRenderFuncResourceNativePointerDestinationObservation = null;
                        targetArmed = true;
                    }
                }
            }

            if (!skipStatusLog)
            {
                log.LogInfo($"Native render-func resource native-pointer target status #{statusLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; entryCount={entryCount}; sampleCount={sampleCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; nativeLastPassData=0x{lastPassDataPtr:X}; passDataMatches={passDataMatches}; tupleReady={tupleReady}; targetChanged={targetChanged}; nativeLastContext=0x{lastContextPtr:X}; nativeLastMethodInfo=0x{lastMethodInfoPtr:X}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}; dataType={dataType}; tuple={tupleSummary}");
            }

            if (targetArmed)
            {
                log.LogInfo($"Native render-func resource native-pointer target armed: compile={compileCount}; managedPassData=0x{managedPassDataPointer.ToInt64():X}; source=\"{sourceResource}\"; destination=\"{destinationResource}\"; tuple={tupleSummary}");
            }
        }
    }

    private static int? TryReadIntSnapshotMember(
        IEnumerable<RenderGraphPassDataSnapshotMember> members,
        string label)
    {
        foreach (var member in members)
        {
            if (!string.Equals(member.Label, label, StringComparison.Ordinal))
            {
                continue;
            }

            var summary = member.Summary;
            var separator = summary.LastIndexOf('=');
            var valueText = separator >= 0 ? summary[(separator + 1)..] : summary;
            if (int.TryParse(valueText.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var value))
            {
                return value;
            }
        }

        return null;
    }

    private static string? TryReadTextureSnapshotMember(
        IEnumerable<RenderGraphPassDataSnapshotMember> members,
        string label)
    {
        foreach (var member in members)
        {
            if (string.Equals(member.Label, label, StringComparison.Ordinal)
                && (string.Equals(member.Kind, "texture", StringComparison.Ordinal)
                    || string.Equals(member.Kind, "texture-resource", StringComparison.Ordinal)))
            {
                return member.Summary;
            }
        }

        return null;
    }

    private static string FormatNativeRenderFuncResourceTuple(NativeRenderFuncResourceTupleSummary tuple)
    {
        return $"input={tuple.InputWidth}x{tuple.InputHeight}; output={tuple.OutputWidth}x{tuple.OutputHeight}; source=\"{tuple.Source}\"; destination=\"{tuple.Destination}\"";
    }

    private static void TryLogRenderGraphPassRenderFuncMetadata(
        int compileCount,
        IEnumerable<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!RenderGraphPassRenderFuncMetadataProbeEnabled && !NativeRenderFuncEntryProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        foreach (var summary in passSummaries)
        {
            if (!IsFocusedRenderGraphPassDataSnapshotTarget(summary.Name, summary.TypeName, summary.Category))
            {
                continue;
            }

            var metadataLogCount = 0;
            var shouldLogMetadata = false;
            if (RenderGraphPassRenderFuncMetadataProbeEnabled)
            {
                lock (Sync)
                {
                    RenderGraphPassRenderFuncMetadataLogCount++;
                    metadataLogCount = RenderGraphPassRenderFuncMetadataLogCount;
                }

                shouldLogMetadata = metadataLogCount <= MaxRenderGraphPassRenderFuncMetadataLogs || metadataLogCount % 500 == 0;
            }

            if (!shouldLogMetadata && !NativeRenderFuncEntryProbeEnabled)
            {
                continue;
            }

            var renderFunc = TryReadPropertyObject(summary.Pass, "renderFunc")
                ?? TryReadFieldObject(summary.Pass, "renderFunc")
                ?? TryReadTypedRenderGraphPassRenderFuncObject(summary.Pass, summary.Name);
            if (renderFunc is null)
            {
                if (shouldLogMetadata)
                {
                    log.LogInfo($"RenderGraph pass render-func metadata renderFunc=not found #{metadataLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}");
                }

                continue;
            }

            TryObserveNativeRenderFuncEntryCandidate(compileCount, summary, renderFunc);
            if (shouldLogMetadata)
            {
                var renderFuncSummary = SummarizeRenderGraphRenderFunc(renderFunc);
                log.LogInfo($"RenderGraph pass render-func metadata #{metadataLogCount}: compile={compileCount}; ordinal={summary.Ordinal}; pass=\"{summary.Name}\"; category={summary.Category}; passType={summary.TypeName}; renderFunc={renderFuncSummary}");
            }
        }
    }

    private static void TryObserveNativeRenderFuncEntryCandidate(
        int compileCount,
        (int Ordinal, object Pass, string Name, string TypeName, string Category) summary,
        object renderFunc)
    {
        if (!NativeRenderFuncEntryProbeEnabled || !IsNativeRenderFuncEntryTarget(summary.Name, summary.TypeName, summary.Category, renderFunc))
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        if (!TryReadRenderFuncPointer(renderFunc, "method_ptr", out var methodPtr) || methodPtr == IntPtr.Zero)
        {
            log.LogWarning($"Native render-func entry probe failed: EASU method_ptr was not available at compile={compileCount}; pass=\"{summary.Name}\"; ordinal={summary.Ordinal}");
            return;
        }

        var methodSummary = SummarizeNativeRenderFuncEntryMethod(renderFunc);
        var shouldInstall = false;
        var observations = 0;
        var candidateChanged = false;
        var candidateAlreadyInstalled = false;
        var previousPointer = IntPtr.Zero;
        lock (Sync)
        {
            if (NativeRenderFuncEntryCandidatePointer == IntPtr.Zero)
            {
                NativeRenderFuncEntryCandidatePointer = methodPtr;
                NativeRenderFuncEntryCandidatePassName = summary.Name;
                NativeRenderFuncEntryCandidateMethodSummary = methodSummary;
            }
            else if (NativeRenderFuncEntryCandidatePointer != methodPtr)
            {
                previousPointer = NativeRenderFuncEntryCandidatePointer;
                candidateChanged = true;
                NativeRenderFuncEntryInstallAttempted = true;
            }

            if (!candidateChanged)
            {
                NativeRenderFuncEntryCandidateObservationCount++;
                observations = NativeRenderFuncEntryCandidateObservationCount;
                NativeRenderFuncEntryCandidatePassName = summary.Name;
                NativeRenderFuncEntryCandidateMethodSummary = methodSummary;
                candidateAlreadyInstalled = NativeRenderFuncEntryInstalled;
                if (!NativeRenderFuncEntryInstalled
                    && !NativeRenderFuncEntryInstallAttempted
                    && NativeRenderFuncEntryCandidateObservationCount >= NativeRenderFuncEntryStableObservationThreshold)
                {
                    NativeRenderFuncEntryInstallAttempted = true;
                    shouldInstall = true;
                }
            }
        }

        if (candidateChanged)
        {
            log.LogWarning($"Native render-func entry probe failed: EASU method_ptr changed before install; previous=0x{previousPointer.ToInt64():X}; current=0x{methodPtr.ToInt64():X}; pass=\"{summary.Name}\"");
            return;
        }

        int observationLogCount;
        lock (Sync)
        {
            NativeRenderFuncEntryObservationLogCount++;
            observationLogCount = NativeRenderFuncEntryObservationLogCount;
        }

        if (observationLogCount <= MaxNativeRenderFuncEntryStatusLogs || observationLogCount % 300 == 0)
        {
            log.LogInfo($"Native render-func entry candidate observed #{observationLogCount}: compile={compileCount}; pass=\"{summary.Name}\"; ordinal={summary.Ordinal}; category={summary.Category}; method_ptr=0x{methodPtr.ToInt64():X}; observations={observations}; installed={candidateAlreadyInstalled}; {methodSummary}");
        }

        if (shouldInstall)
        {
            TryInstallNativeRenderFuncEntryDetour(methodPtr, summary.Name, methodSummary);
        }
    }

    private static bool IsNativeRenderFuncEntryTarget(string passName, string passType, string category, object renderFunc)
    {
        var value = $"{passName} {passType} {category}";
        if (value.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) < 0
            && value.IndexOf("EASUData", StringComparison.OrdinalIgnoreCase) < 0)
        {
            return false;
        }

        var methodName = TryReadNativeRenderFuncEntryMethodName(renderFunc);
        return string.IsNullOrWhiteSpace(methodName)
            || methodName.IndexOf("EdgeAdaptiveSpatialUpsampling", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static void TryInstallNativeRenderFuncEntryDetour(IntPtr methodPtr, string passName, string methodSummary)
    {
        var log = Log;
        if (log is null)
        {
            return;
        }

        object? detour = null;
        try
        {
            var assemblies = AppDomain.CurrentDomain.GetAssemblies();
            var runtimeType = FindRuntimeType(assemblies, "Il2CppInterop.Runtime.Startup.Il2CppInteropRuntime");
            if (runtimeType is null)
            {
                log.LogWarning("Native render-func entry probe failed: Il2CppInteropRuntime type was not found.");
                return;
            }

            var runtimeInstance = TryReadStaticPropertyObject(runtimeType, "Instance");
            var detourProvider = runtimeInstance is null
                ? null
                : TryReadPropertyObject(runtimeInstance, "DetourProvider");
            if (detourProvider is null)
            {
                log.LogWarning("Native render-func entry probe failed: Il2CppInterop DetourProvider was not available.");
                return;
            }

            var replacementDelegate = new NativeRenderFuncEntryDelegate(NativeRenderFuncEntryDetourCallback);
            var createMethod = detourProvider.GetType()
                .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                .Where(method => string.Equals(method.Name, "Create", StringComparison.Ordinal))
                .Where(method => method.IsGenericMethodDefinition)
                .FirstOrDefault(method =>
                {
                    var parameters = method.GetParameters();
                    return parameters.Length == 2
                        && parameters[0].ParameterType == typeof(IntPtr);
                });
            if (createMethod is null)
            {
                log.LogWarning("Native render-func entry probe failed: DetourProvider.Create<TDelegate>(IntPtr, TDelegate) was not found.");
                return;
            }

            detour = createMethod
                .MakeGenericMethod(typeof(NativeRenderFuncEntryDelegate))
                .Invoke(detourProvider, new object[] { methodPtr, replacementDelegate });
            if (detour is null)
            {
                log.LogWarning("Native render-func entry probe failed: DetourProvider.Create returned null.");
                return;
            }

            var generateTrampolineMethod = detour.GetType()
                .GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                .Where(method => string.Equals(method.Name, "GenerateTrampoline", StringComparison.Ordinal))
                .Where(method => method.IsGenericMethodDefinition)
                .FirstOrDefault(method => method.GetParameters().Length == 0);
            var applyMethod = FindMethodBySignature(detour.GetType(), "Apply", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance, Array.Empty<Type>());
            if (generateTrampolineMethod is null || applyMethod is null)
            {
                DisposeObject(detour);
                log.LogWarning("Native render-func entry probe failed: detour trampoline/apply methods were not found.");
                return;
            }

            var originalDelegate = generateTrampolineMethod
                .MakeGenericMethod(typeof(NativeRenderFuncEntryDelegate))
                .Invoke(detour, Array.Empty<object>()) as NativeRenderFuncEntryDelegate;
            if (originalDelegate is null)
            {
                DisposeObject(detour);
                log.LogWarning("Native render-func entry probe failed: original trampoline delegate was not created.");
                return;
            }

            NativeRenderFuncEntryReplacementDelegate = replacementDelegate;
            NativeRenderFuncEntryOriginalDelegate = originalDelegate;
            applyMethod.Invoke(detour, Array.Empty<object>());

            lock (Sync)
            {
                NativeRenderFuncEntryDetour = detour;
                NativeRenderFuncEntryInstalled = true;
                NativeRenderFuncEntryCandidatePassName = passName;
                NativeRenderFuncEntryCandidateMethodSummary = methodSummary;
            }

            log.LogInfo($"Native render-func entry detour installed: pass=\"{passName}\"; method_ptr=0x{methodPtr.ToInt64():X}; {methodSummary}");
        }
        catch (Exception ex)
        {
            if (detour is not null)
            {
                DisposeObject(detour);
            }

            NativeRenderFuncEntryOriginalDelegate = null;
            NativeRenderFuncEntryReplacementDelegate = null;
            log.LogWarning($"Native render-func entry probe failed: detour install threw {FirstLine(GetExceptionMessage(ex))}");
        }
    }

    private static void TryLogNativeRenderFuncEntryStatus(int compileCount)
    {
        if (!NativeRenderFuncEntryProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        var entryCount = Volatile.Read(ref NativeRenderFuncEntryCallCount);
        var shouldLogAdvanced = false;
        var installed = false;
        var observations = 0;
        var pointer = IntPtr.Zero;
        var statusLogCount = 0;
        var skipStatusLog = false;
        string? passName = null;
        string? methodSummary = null;
        lock (Sync)
        {
            NativeRenderFuncEntryStatusLogCount++;
            statusLogCount = NativeRenderFuncEntryStatusLogCount;
            if (statusLogCount > MaxNativeRenderFuncEntryStatusLogs && statusLogCount % 300 != 0)
            {
                skipStatusLog = true;
            }

            installed = NativeRenderFuncEntryInstalled;
            observations = NativeRenderFuncEntryCandidateObservationCount;
            pointer = NativeRenderFuncEntryCandidatePointer;
            passName = NativeRenderFuncEntryCandidatePassName;
            methodSummary = NativeRenderFuncEntryCandidateMethodSummary;
            if (installed && entryCount > 0 && !NativeRenderFuncEntryCountAdvancedLogged)
            {
                NativeRenderFuncEntryCountAdvancedLogged = true;
                shouldLogAdvanced = true;
            }
        }

        if (!skipStatusLog)
        {
            log.LogInfo($"Native render-func entry status #{statusLogCount}: compile={compileCount}; installed={installed}; entryCount={entryCount}; observations={observations}; candidatePointer=0x{pointer.ToInt64():X}; pass=\"{passName ?? "unknown"}\"; {methodSummary ?? "method=unknown"}");
        }

        if (shouldLogAdvanced)
        {
            log.LogInfo($"Native render-func entry count advanced: entryCount={entryCount}; pass=\"{passName ?? "unknown"}\"; candidatePointer=0x{pointer.ToInt64():X}");
        }

        TryLogNativeRenderFuncArgumentStatus(compileCount);
    }

    private static void TryLogNativeRenderFuncArgumentStatus(int compileCount)
    {
        if (!NativeRenderFuncArgumentProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        var sampleCount = Volatile.Read(ref NativeRenderFuncArgumentSampleCount);
        var entryCount = Volatile.Read(ref NativeRenderFuncEntryCallCount);
        var thisNonZeroCount = Volatile.Read(ref NativeRenderFuncArgumentThisNonZeroCount);
        var passDataNonZeroCount = Volatile.Read(ref NativeRenderFuncArgumentPassDataNonZeroCount);
        var contextNonZeroCount = Volatile.Read(ref NativeRenderFuncArgumentContextNonZeroCount);
        var methodInfoNonZeroCount = Volatile.Read(ref NativeRenderFuncArgumentMethodInfoNonZeroCount);
        var lastThisPtr = Volatile.Read(ref NativeRenderFuncArgumentLastThisPtr);
        var lastPassDataPtr = Volatile.Read(ref NativeRenderFuncArgumentLastPassDataPtr);
        var lastContextPtr = Volatile.Read(ref NativeRenderFuncArgumentLastContextPtr);
        var lastMethodInfoPtr = Volatile.Read(ref NativeRenderFuncArgumentLastMethodInfoPtr);
        var shouldLogAdvanced = false;
        var statusLogCount = 0;
        var skipStatusLog = false;
        var installed = false;
        var pointer = IntPtr.Zero;
        string? passName = null;
        lock (Sync)
        {
            NativeRenderFuncArgumentStatusLogCount++;
            statusLogCount = NativeRenderFuncArgumentStatusLogCount;
            if (statusLogCount > MaxNativeRenderFuncArgumentStatusLogs && statusLogCount % 300 != 0)
            {
                skipStatusLog = true;
            }

            installed = NativeRenderFuncEntryInstalled;
            pointer = NativeRenderFuncEntryCandidatePointer;
            passName = NativeRenderFuncEntryCandidatePassName;
            if (sampleCount > 0 && !NativeRenderFuncArgumentSampleAdvancedLogged)
            {
                NativeRenderFuncArgumentSampleAdvancedLogged = true;
                shouldLogAdvanced = true;
            }
        }

        if (!skipStatusLog)
        {
            log.LogInfo($"Native render-func argument status #{statusLogCount}: compile={compileCount}; installed={installed}; entryCount={entryCount}; sampleCount={sampleCount}; nonzeroThis={thisNonZeroCount}; nonzeroPassData={passDataNonZeroCount}; nonzeroContext={contextNonZeroCount}; nonzeroMethodInfo={methodInfoNonZeroCount}; lastThis=0x{lastThisPtr:X}; lastPassData=0x{lastPassDataPtr:X}; lastContext=0x{lastContextPtr:X}; lastMethodInfo=0x{lastMethodInfoPtr:X}; candidatePointer=0x{pointer.ToInt64():X}; pass=\"{passName ?? "unknown"}\"");
        }

        if (shouldLogAdvanced)
        {
            log.LogInfo($"Native render-func argument sample advanced: sampleCount={sampleCount}; nonzeroThis={thisNonZeroCount}; nonzeroPassData={passDataNonZeroCount}; nonzeroContext={contextNonZeroCount}; nonzeroMethodInfo={methodInfoNonZeroCount}; lastThis=0x{lastThisPtr:X}; lastPassData=0x{lastPassDataPtr:X}; lastContext=0x{lastContextPtr:X}; lastMethodInfo=0x{lastMethodInfoPtr:X}; pass=\"{passName ?? "unknown"}\"");
        }

        TryLogNativeRenderFuncContextStatus(compileCount);
    }

    private static void TryLogNativeRenderFuncContextStatus(int compileCount)
    {
        if (!NativeRenderFuncContextProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        var sampleCount = Volatile.Read(ref NativeRenderFuncContextSampleCount);
        var entryCount = Volatile.Read(ref NativeRenderFuncEntryCallCount);
        var nonZeroContextCount = Volatile.Read(ref NativeRenderFuncContextNonZeroCount);
        var wrapSuccessCount = Volatile.Read(ref NativeRenderFuncContextWrapSuccessCount);
        var cmdNonNullCount = Volatile.Read(ref NativeRenderFuncContextCmdNonNullCount);
        var cmdPointerNonZeroCount = Volatile.Read(ref NativeRenderFuncContextCmdPointerNonZeroCount);
        var wrapFailureCount = Volatile.Read(ref NativeRenderFuncContextWrapFailureCount);
        var lastContextPtr = Volatile.Read(ref NativeRenderFuncContextLastContextPtr);
        var lastWrappedContextPtr = Volatile.Read(ref NativeRenderFuncContextLastWrappedContextPtr);
        var lastCommandBufferPtr = Volatile.Read(ref NativeRenderFuncContextLastCommandBufferPtr);
        var shouldLogAdvanced = false;
        var statusLogCount = 0;
        var skipStatusLog = false;
        var installed = false;
        var pointer = IntPtr.Zero;
        string? passName = null;
        string? commandBufferSummary = null;
        string? failure = null;
        lock (Sync)
        {
            NativeRenderFuncContextStatusLogCount++;
            statusLogCount = NativeRenderFuncContextStatusLogCount;
            if (statusLogCount > MaxNativeRenderFuncContextStatusLogs && statusLogCount % 300 != 0)
            {
                skipStatusLog = true;
            }

            installed = NativeRenderFuncEntryInstalled;
            pointer = NativeRenderFuncEntryCandidatePointer;
            passName = NativeRenderFuncEntryCandidatePassName;
            commandBufferSummary = NativeRenderFuncContextLastCommandBufferSummary;
            failure = NativeRenderFuncContextLastFailure;
            if (cmdPointerNonZeroCount > 0 && !NativeRenderFuncContextAdvancedLogged)
            {
                NativeRenderFuncContextAdvancedLogged = true;
                shouldLogAdvanced = true;
            }
        }

        if (!skipStatusLog)
        {
            log.LogInfo($"Native render-func context status #{statusLogCount}: compile={compileCount}; installed={installed}; entryCount={entryCount}; sampleCount={sampleCount}; nonzeroContext={nonZeroContextCount}; wrapSuccess={wrapSuccessCount}; cmdNonNull={cmdNonNullCount}; cmdPointerNonZero={cmdPointerNonZeroCount}; wrapFailures={wrapFailureCount}; lastContext=0x{lastContextPtr:X}; lastWrappedContext=0x{lastWrappedContextPtr:X}; lastCmd=0x{lastCommandBufferPtr:X}; cmd=\"{commandBufferSummary ?? "unknown"}\"; failure=\"{failure ?? "none"}\"; candidatePointer=0x{pointer.ToInt64():X}; pass=\"{passName ?? "unknown"}\"");
        }

        if (shouldLogAdvanced)
        {
            log.LogInfo($"Native render-func context advanced: sampleCount={sampleCount}; nonzeroContext={nonZeroContextCount}; wrapSuccess={wrapSuccessCount}; cmdNonNull={cmdNonNullCount}; cmdPointerNonZero={cmdPointerNonZeroCount}; wrapFailures={wrapFailureCount}; lastContext=0x{lastContextPtr:X}; lastWrappedContext=0x{lastWrappedContextPtr:X}; lastCmd=0x{lastCommandBufferPtr:X}; cmd=\"{commandBufferSummary ?? "unknown"}\"; pass=\"{passName ?? "unknown"}\"");
        }

        TryLogNativeRenderFuncCommandBufferEventStatus(compileCount);
        TryLogNativeRenderFuncCommandBufferPayloadStatus(compileCount);
        TryLogNativeRenderFuncCommandBufferFrameDescriptorStatus(compileCount);
        TryLogNativeRenderFuncCommandBufferDlssFeatureCreateStatus(compileCount);
    }

    private static void TryLogNativeRenderFuncCommandBufferEventStatus(int compileCount)
    {
        if (!NativeRenderFuncCommandBufferEventProbeEnabled)
        {
            return;
        }

        var log = Log;
        var bridge = Bridge;
        if (log is null || bridge is null)
        {
            return;
        }

        var issueAttempts = Volatile.Read(ref NativeRenderFuncCommandBufferEventIssueAttemptCount);
        var issueSuccesses = Volatile.Read(ref NativeRenderFuncCommandBufferEventIssueSuccessCount);
        var issueFailures = Volatile.Read(ref NativeRenderFuncCommandBufferEventIssueFailureCount);
        var beforeCount = Volatile.Read(ref NativeRenderFuncCommandBufferEventBeforeCount);
        var currentCount = bridge.GetRenderEventCount();
        var lastEventId = bridge.GetLastRenderEventId();
        var callbackReached = issueSuccesses > 0
            && currentCount > beforeCount
            && lastEventId == NativeRenderFuncCommandBufferEventId;
        var callbackPtr = Volatile.Read(ref NativeRenderFuncCommandBufferEventCallbackPtr);
        var commandBufferPtr = Volatile.Read(ref NativeRenderFuncCommandBufferEventLastCommandBufferPtr);
        var shouldLogAdvanced = false;
        var statusLogCount = 0;
        var skipStatusLog = false;
        var installed = false;
        var pointer = IntPtr.Zero;
        string? passName = null;
        string? status = null;
        string? failure = null;
        lock (Sync)
        {
            NativeRenderFuncCommandBufferEventStatusLogCount++;
            statusLogCount = NativeRenderFuncCommandBufferEventStatusLogCount;
            if (statusLogCount > MaxNativeRenderFuncCommandBufferEventStatusLogs && statusLogCount % 300 != 0)
            {
                skipStatusLog = true;
            }

            installed = NativeRenderFuncEntryInstalled;
            pointer = NativeRenderFuncEntryCandidatePointer;
            passName = NativeRenderFuncEntryCandidatePassName;
            status = bridge.GetRenderEventStatus();
            NativeRenderFuncCommandBufferEventLastCount = currentCount;
            NativeRenderFuncCommandBufferEventLastEventId = lastEventId;
            NativeRenderFuncCommandBufferEventLastStatus = status;
            failure = NativeRenderFuncCommandBufferEventLastFailure;
            if (callbackReached && !NativeRenderFuncCommandBufferEventAdvancedLogged)
            {
                NativeRenderFuncCommandBufferEventAdvancedLogged = true;
                shouldLogAdvanced = true;
            }
        }

        if (!skipStatusLog)
        {
            log.LogInfo($"Native render-func command-buffer event status #{statusLogCount}: compile={compileCount}; installed={installed}; issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeCount={beforeCount}; currentCount={currentCount}; lastEventId={lastEventId}; callbackReached={callbackReached}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferEventId}; status=\"{status ?? "unknown"}\"; failure=\"{failure ?? "none"}\"; candidatePointer=0x{pointer.ToInt64():X}; pass=\"{passName ?? "unknown"}\"");
        }

        if (shouldLogAdvanced)
        {
            log.LogInfo($"Native render-func command-buffer event advanced: issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeCount={beforeCount}; currentCount={currentCount}; lastEventId={lastEventId}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferEventId}; status=\"{status ?? "unknown"}\"; pass=\"{passName ?? "unknown"}\"");
        }
    }

    private static void TryLogNativeRenderFuncCommandBufferPayloadStatus(int compileCount)
    {
        if (!NativeRenderFuncCommandBufferPayloadProbeEnabled)
        {
            return;
        }

        var log = Log;
        var bridge = Bridge;
        if (log is null || bridge is null)
        {
            return;
        }

        var setAttempts = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadSetAttemptCount);
        var setSuccesses = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadSetSuccessCount);
        var setFailures = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadSetFailureCount);
        var issueAttempts = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadIssueAttemptCount);
        var issueSuccesses = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadIssueSuccessCount);
        var issueFailures = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadIssueFailureCount);
        var beforeConsumed = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadBeforeConsumedCount);
        var consumedCount = bridge.GetRenderEventTexturePayloadConsumedCount();
        var lastEventId = bridge.GetLastRenderEventId();
        var callbackReached = setSuccesses > 0
            && issueSuccesses > 0
            && consumedCount > beforeConsumed
            && lastEventId == NativeRenderFuncCommandBufferPayloadEventId;
        var callbackPtr = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadCallbackPtr);
        var commandBufferPtr = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadLastCommandBufferPtr);
        var sequence = Volatile.Read(ref NativeRenderFuncCommandBufferPayloadSequence);
        var shouldLogAdvanced = false;
        var statusLogCount = 0;
        var skipStatusLog = false;
        var installed = false;
        var pointer = IntPtr.Zero;
        string? passName = null;
        string? status = null;
        string? failure = null;
        lock (Sync)
        {
            NativeRenderFuncCommandBufferPayloadStatusLogCount++;
            statusLogCount = NativeRenderFuncCommandBufferPayloadStatusLogCount;
            if (statusLogCount > MaxNativeRenderFuncCommandBufferPayloadStatusLogs && statusLogCount % 300 != 0)
            {
                skipStatusLog = true;
            }

            installed = NativeRenderFuncEntryInstalled;
            pointer = NativeRenderFuncEntryCandidatePointer;
            passName = NativeRenderFuncEntryCandidatePassName;
            status = bridge.GetRenderEventTexturePayloadStatus();
            NativeRenderFuncCommandBufferPayloadLastConsumedCount = consumedCount;
            NativeRenderFuncCommandBufferPayloadLastEventId = lastEventId;
            NativeRenderFuncCommandBufferPayloadLastStatus = status;
            failure = NativeRenderFuncCommandBufferPayloadLastFailure;
            if (callbackReached && !NativeRenderFuncCommandBufferPayloadAdvancedLogged)
            {
                NativeRenderFuncCommandBufferPayloadAdvancedLogged = true;
                shouldLogAdvanced = true;
            }
        }

        if (!skipStatusLog)
        {
            log.LogInfo($"Native render-func command-buffer payload status #{statusLogCount}: compile={compileCount}; installed={installed}; setAttempts={setAttempts}; setSuccesses={setSuccesses}; setFailures={setFailures}; issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeConsumed={beforeConsumed}; consumed={consumedCount}; lastEventId={lastEventId}; callbackReached={callbackReached}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferPayloadEventId}; sequence={sequence}; status=\"{status ?? "unknown"}\"; failure=\"{failure ?? "none"}\"; candidatePointer=0x{pointer.ToInt64():X}; pass=\"{passName ?? "unknown"}\"");
        }

        if (shouldLogAdvanced)
        {
            log.LogInfo($"Native render-func command-buffer payload advanced: setAttempts={setAttempts}; setSuccesses={setSuccesses}; setFailures={setFailures}; issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeConsumed={beforeConsumed}; consumed={consumedCount}; lastEventId={lastEventId}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferPayloadEventId}; sequence={sequence}; status=\"{status ?? "unknown"}\"; pass=\"{passName ?? "unknown"}\"");
        }
    }

    private static void TryLogNativeRenderFuncCommandBufferFrameDescriptorStatus(int compileCount)
    {
        if (!NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled)
        {
            return;
        }

        var log = Log;
        var bridge = Bridge;
        if (log is null || bridge is null)
        {
            return;
        }

        var setAttempts = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorSetAttemptCount);
        var setSuccesses = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorSetSuccessCount);
        var setFailures = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorSetFailureCount);
        var issueAttempts = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorIssueAttemptCount);
        var issueSuccesses = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorIssueSuccessCount);
        var issueFailures = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorIssueFailureCount);
        var beforeConsumed = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorBeforeConsumedCount);
        var consumedCount = bridge.GetRenderEventFrameDescriptorPayloadConsumedCount();
        var lastEventId = bridge.GetLastRenderEventId();
        var callbackReached = consumedCount > beforeConsumed
            && consumedCount >= 0
            && beforeConsumed >= 0
            && lastEventId == NativeRenderFuncCommandBufferFrameDescriptorEventId;
        var callbackPtr = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorCallbackPtr);
        var commandBufferPtr = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorLastCommandBufferPtr);
        var sequence = Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorSequence);
        string? status = null;
        string? failure = null;
        bool shouldLog;
        bool shouldLogAdvanced = false;
        int statusLogCount;
        IntPtr pointer;
        string? passName;

        lock (Sync)
        {
            pointer = NativeRenderFuncEntryCandidatePointer;
            passName = NativeRenderFuncEntryCandidatePassName;
            NativeRenderFuncCommandBufferFrameDescriptorStatusLogCount++;
            statusLogCount = NativeRenderFuncCommandBufferFrameDescriptorStatusLogCount;
            if (statusLogCount > MaxNativeRenderFuncCommandBufferFrameDescriptorStatusLogs && statusLogCount % 300 != 0)
            {
                return;
            }

            status = bridge.GetRenderEventFrameDescriptorPayloadStatus();
            NativeRenderFuncCommandBufferFrameDescriptorLastConsumedCount = consumedCount;
            NativeRenderFuncCommandBufferFrameDescriptorLastEventId = lastEventId;
            NativeRenderFuncCommandBufferFrameDescriptorLastStatus = status;
            failure = NativeRenderFuncCommandBufferFrameDescriptorLastFailure;
            if (callbackReached && !NativeRenderFuncCommandBufferFrameDescriptorAdvancedLogged)
            {
                NativeRenderFuncCommandBufferFrameDescriptorAdvancedLogged = true;
                shouldLogAdvanced = true;
            }

            shouldLog = true;
        }

        if (shouldLog)
        {
            log.LogInfo($"Native render-func command-buffer frame descriptor status #{statusLogCount}: compile={compileCount}; installed={NativeRenderFuncEntryInstalled}; setAttempts={setAttempts}; setSuccesses={setSuccesses}; setFailures={setFailures}; issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeConsumed={beforeConsumed}; consumed={consumedCount}; lastEventId={lastEventId}; callbackReached={callbackReached}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferFrameDescriptorEventId}; sequence={sequence}; status=\"{status ?? "unknown"}\"; failure=\"{failure ?? "none"}\"; candidatePointer=0x{pointer.ToInt64():X}; pass=\"{passName ?? "unknown"}\"");
        }

        if (shouldLogAdvanced)
        {
            log.LogInfo($"Native render-func command-buffer frame descriptor advanced: setAttempts={setAttempts}; setSuccesses={setSuccesses}; setFailures={setFailures}; issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeConsumed={beforeConsumed}; consumed={consumedCount}; lastEventId={lastEventId}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferFrameDescriptorEventId}; sequence={sequence}; status=\"{status ?? "unknown"}\"; pass=\"{passName ?? "unknown"}\"");
        }
    }

    private static void TryLogNativeRenderFuncCommandBufferDlssFeatureCreateStatus(int compileCount)
    {
        if (!NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled)
        {
            return;
        }

        var log = Log;
        var bridge = Bridge;
        if (log is null || bridge is null)
        {
            return;
        }

        var setAttempts = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetAttemptCount);
        var setSuccesses = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetSuccessCount);
        var setFailures = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetFailureCount);
        var issueAttempts = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueAttemptCount);
        var issueSuccesses = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueSuccessCount);
        var issueFailures = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueFailureCount);
        var beforeConsumed = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateBeforeConsumedCount);
        var consumedCount = bridge.GetRenderEventDlssFeatureCreateConsumedCount();
        var lastEventId = bridge.GetLastRenderEventId();
        var callbackReached = setSuccesses > 0
            && issueSuccesses > 0
            && consumedCount > beforeConsumed
            && lastEventId == NativeRenderFuncCommandBufferDlssFeatureCreateEventId;
        var callbackPtr = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateCallbackPtr);
        var commandBufferPtr = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateLastCommandBufferPtr);
        var sequence = Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateSequence);
        var shouldLogAdvanced = false;
        var statusLogCount = 0;
        var skipStatusLog = false;
        var installed = false;
        var pointer = IntPtr.Zero;
        string? passName = null;
        string? status = null;
        string? failure = null;
        lock (Sync)
        {
            NativeRenderFuncCommandBufferDlssFeatureCreateStatusLogCount++;
            statusLogCount = NativeRenderFuncCommandBufferDlssFeatureCreateStatusLogCount;
            if (statusLogCount > MaxNativeRenderFuncCommandBufferDlssFeatureCreateStatusLogs && statusLogCount % 300 != 0)
            {
                skipStatusLog = true;
            }

            installed = NativeRenderFuncEntryInstalled;
            pointer = NativeRenderFuncEntryCandidatePointer;
            passName = NativeRenderFuncEntryCandidatePassName;
            status = bridge.GetRenderEventDlssFeatureCreateStatus();
            NativeRenderFuncCommandBufferDlssFeatureCreateLastConsumedCount = consumedCount;
            NativeRenderFuncCommandBufferDlssFeatureCreateLastEventId = lastEventId;
            NativeRenderFuncCommandBufferDlssFeatureCreateLastStatus = status;
            failure = NativeRenderFuncCommandBufferDlssFeatureCreateLastFailure;
            if (callbackReached && !NativeRenderFuncCommandBufferDlssFeatureCreateAdvancedLogged)
            {
                NativeRenderFuncCommandBufferDlssFeatureCreateAdvancedLogged = true;
                shouldLogAdvanced = true;
            }
        }

        if (!skipStatusLog)
        {
            log.LogInfo($"Native render-func command-buffer DLSS feature-create status #{statusLogCount}: compile={compileCount}; installed={installed}; setAttempts={setAttempts}; setSuccesses={setSuccesses}; setFailures={setFailures}; issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeConsumed={beforeConsumed}; consumed={consumedCount}; lastEventId={lastEventId}; callbackReached={callbackReached}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferDlssFeatureCreateEventId}; sequence={sequence}; status=\"{status ?? "unknown"}\"; failure=\"{failure ?? "none"}\"; candidatePointer=0x{pointer.ToInt64():X}; pass=\"{passName ?? "unknown"}\"");
        }

        if (shouldLogAdvanced)
        {
            log.LogInfo($"Native render-func command-buffer DLSS feature-create advanced: setAttempts={setAttempts}; setSuccesses={setSuccesses}; setFailures={setFailures}; issueAttempts={issueAttempts}; issueSuccesses={issueSuccesses}; issueFailures={issueFailures}; beforeConsumed={beforeConsumed}; consumed={consumedCount}; lastEventId={lastEventId}; callback=0x{callbackPtr:X}; lastCmd=0x{commandBufferPtr:X}; eventId={NativeRenderFuncCommandBufferDlssFeatureCreateEventId}; sequence={sequence}; status=\"{status ?? "unknown"}\"; pass=\"{passName ?? "unknown"}\"");
        }
    }

    private static void TryDisposeNativeRenderFuncEntryDetour(ManualLogSource log)
    {
        object? detour;
        lock (Sync)
        {
            detour = NativeRenderFuncEntryDetour;
            NativeRenderFuncEntryDetour = null;
            NativeRenderFuncEntryInstalled = false;
            NativeRenderFuncEntryOriginalDelegate = null;
            NativeRenderFuncEntryReplacementDelegate = null;
        }

        if (detour is null)
        {
            return;
        }

        try
        {
            DisposeObject(detour);
            log.LogInfo("Native render-func entry detour disposed.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"Native render-func entry detour dispose failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void DisposeObject(object instance)
    {
        if (instance is IDisposable disposable)
        {
            disposable.Dispose();
            return;
        }

        var disposeMethod = FindMethodBySignature(
            instance.GetType(),
            "Dispose",
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
            Array.Empty<Type>());
        disposeMethod?.Invoke(instance, Array.Empty<object>());
    }

    private static void NativeRenderFuncEntryDetourCallback(
        IntPtr thisPtr,
        IntPtr passDataPtr,
        IntPtr renderGraphContextPtr,
        IntPtr methodInfoPtr)
    {
        Interlocked.Increment(ref NativeRenderFuncEntryCallCount);
        if (NativeRenderFuncArgumentProbeEnabled)
        {
            RecordNativeRenderFuncArgumentSample(thisPtr, passDataPtr, renderGraphContextPtr, methodInfoPtr);
        }
        if (NativeRenderFuncContextProbeEnabled)
        {
            RecordNativeRenderFuncContextSample(renderGraphContextPtr);
        }

        var original = NativeRenderFuncEntryOriginalDelegate;
        original?.Invoke(thisPtr, passDataPtr, renderGraphContextPtr, methodInfoPtr);
    }

    private static void RecordNativeRenderFuncArgumentSample(
        IntPtr thisPtr,
        IntPtr passDataPtr,
        IntPtr renderGraphContextPtr,
        IntPtr methodInfoPtr)
    {
        Interlocked.Increment(ref NativeRenderFuncArgumentSampleCount);
        if (thisPtr != IntPtr.Zero)
        {
            Interlocked.Increment(ref NativeRenderFuncArgumentThisNonZeroCount);
        }

        if (passDataPtr != IntPtr.Zero)
        {
            Interlocked.Increment(ref NativeRenderFuncArgumentPassDataNonZeroCount);
        }

        if (renderGraphContextPtr != IntPtr.Zero)
        {
            Interlocked.Increment(ref NativeRenderFuncArgumentContextNonZeroCount);
        }

        if (methodInfoPtr != IntPtr.Zero)
        {
            Interlocked.Increment(ref NativeRenderFuncArgumentMethodInfoNonZeroCount);
        }

        Interlocked.Exchange(ref NativeRenderFuncArgumentLastThisPtr, thisPtr.ToInt64());
        Interlocked.Exchange(ref NativeRenderFuncArgumentLastPassDataPtr, passDataPtr.ToInt64());
        Interlocked.Exchange(ref NativeRenderFuncArgumentLastContextPtr, renderGraphContextPtr.ToInt64());
        Interlocked.Exchange(ref NativeRenderFuncArgumentLastMethodInfoPtr, methodInfoPtr.ToInt64());
    }

    private static void RecordNativeRenderFuncContextSample(IntPtr renderGraphContextPtr)
    {
        Interlocked.Increment(ref NativeRenderFuncContextSampleCount);
        if (renderGraphContextPtr == IntPtr.Zero)
        {
            return;
        }

        Interlocked.Increment(ref NativeRenderFuncContextNonZeroCount);
        Interlocked.Exchange(ref NativeRenderFuncContextLastContextPtr, renderGraphContextPtr.ToInt64());

#if VRISINGDLSS_LOCAL_INTEROP
        try
        {
            var context = new UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphContext(renderGraphContextPtr);
            var wrappedContextPtr = TryGetIl2CppObjectPointer(context);
            if (wrappedContextPtr != IntPtr.Zero)
            {
                Interlocked.Exchange(ref NativeRenderFuncContextLastWrappedContextPtr, wrappedContextPtr.ToInt64());
            }

            Interlocked.Increment(ref NativeRenderFuncContextWrapSuccessCount);
            var commandBuffer = context.cmd;
            if (commandBuffer is null)
            {
                return;
            }

            Interlocked.Increment(ref NativeRenderFuncContextCmdNonNullCount);
            var commandBufferPtr = TryGetIl2CppObjectPointer(commandBuffer);
            if (commandBufferPtr != IntPtr.Zero)
            {
                Interlocked.Increment(ref NativeRenderFuncContextCmdPointerNonZeroCount);
                Interlocked.Exchange(ref NativeRenderFuncContextLastCommandBufferPtr, commandBufferPtr.ToInt64());
            }

            lock (Sync)
            {
                NativeRenderFuncContextLastCommandBufferSummary = FirstLine(SummarizeValue(commandBuffer));
            }

            if (NativeRenderFuncCommandBufferEventProbeEnabled)
            {
                TryIssueNativeRenderFuncCommandBufferEvent(commandBuffer, commandBufferPtr);
            }

            if (NativeRenderFuncCommandBufferPayloadProbeEnabled)
            {
                TryIssueNativeRenderFuncCommandBufferPayloadEvent(commandBuffer, commandBufferPtr);
            }

            if (NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled)
            {
                TryIssueNativeRenderFuncCommandBufferFrameDescriptorEvent(commandBuffer, commandBufferPtr);
            }

            if (NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled)
            {
                TryIssueNativeRenderFuncCommandBufferDlssFeatureCreateEvent(commandBuffer, commandBufferPtr);
            }
        }
        catch (Exception ex)
        {
            Interlocked.Increment(ref NativeRenderFuncContextWrapFailureCount);
            lock (Sync)
            {
                NativeRenderFuncContextLastFailure = FirstLine(GetExceptionMessage(ex));
            }
        }
#else
        Interlocked.Increment(ref NativeRenderFuncContextWrapFailureCount);
        lock (Sync)
        {
            NativeRenderFuncContextLastFailure = "VRISINGDLSS_LOCAL_INTEROP was not defined";
        }
#endif
    }

    private static void TryIssueNativeRenderFuncCommandBufferEvent(object commandBuffer, IntPtr commandBufferPtr)
    {
        if (Interlocked.CompareExchange(ref NativeRenderFuncCommandBufferEventIssueAttemptCount, 1, 0) != 0)
        {
            return;
        }

        var bridge = Bridge;
        if (bridge is null)
        {
            RecordNativeRenderFuncCommandBufferEventFailure("Native bridge was not available");
            Interlocked.Increment(ref NativeRenderFuncCommandBufferEventIssueFailureCount);
            return;
        }

        try
        {
            var callback = bridge.GetRenderEventFunc();
            if (callback == IntPtr.Zero)
            {
                RecordNativeRenderFuncCommandBufferEventFailure("native render event callback pointer was null");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferEventIssueFailureCount);
                return;
            }

            var issuePluginEvent = NativeRenderFuncCommandBufferEventIssuePluginEventMethod;
            if (issuePluginEvent is null || issuePluginEvent.DeclaringType != commandBuffer.GetType())
            {
                issuePluginEvent = FindCommandBufferIssuePluginEventMethod(commandBuffer.GetType());
                NativeRenderFuncCommandBufferEventIssuePluginEventMethod = issuePluginEvent;
            }

            if (issuePluginEvent is null)
            {
                RecordNativeRenderFuncCommandBufferEventFailure($"IssuePluginEvent(IntPtr, int) not found on {commandBuffer.GetType().FullName}");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferEventIssueFailureCount);
                return;
            }

            var beforeCount = bridge.GetRenderEventCount();
            var beforeStatus = bridge.GetRenderEventStatus();
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferEventBeforeCount, beforeCount);
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferEventCallbackPtr, callback.ToInt64());
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferEventLastCommandBufferPtr, commandBufferPtr.ToInt64());
            lock (Sync)
            {
                NativeRenderFuncCommandBufferEventLastStatus = beforeStatus;
                NativeRenderFuncCommandBufferEventLastFailure = null;
            }

            issuePluginEvent.Invoke(commandBuffer, new object[] { callback, NativeRenderFuncCommandBufferEventId });
            Interlocked.Increment(ref NativeRenderFuncCommandBufferEventIssueSuccessCount);
        }
        catch (Exception ex)
        {
            RecordNativeRenderFuncCommandBufferEventFailure(FirstLine(GetExceptionMessage(ex)));
            Interlocked.Increment(ref NativeRenderFuncCommandBufferEventIssueFailureCount);
        }
    }

    private static void RecordNativeRenderFuncCommandBufferEventFailure(string failure)
    {
        lock (Sync)
        {
            NativeRenderFuncCommandBufferEventLastFailure = failure;
        }

        Log?.LogWarning($"Native render-func command-buffer event failed: {failure}");
    }

    private static void TryIssueNativeRenderFuncCommandBufferPayloadEvent(object commandBuffer, IntPtr commandBufferPtr)
    {
        if (Volatile.Read(ref NativeRenderFuncCommandBufferPayloadSetSuccessCount) <= 0)
        {
            return;
        }

        if (Interlocked.CompareExchange(ref NativeRenderFuncCommandBufferPayloadIssueAttemptCount, 1, 0) != 0)
        {
            return;
        }

        var bridge = Bridge;
        if (bridge is null)
        {
            RecordNativeRenderFuncCommandBufferPayloadIssueFailure("Native bridge was not available");
            Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadIssueFailureCount);
            return;
        }

        try
        {
            var callback = bridge.GetRenderEventFunc();
            if (callback == IntPtr.Zero)
            {
                RecordNativeRenderFuncCommandBufferPayloadIssueFailure("native render event callback pointer was null");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadIssueFailureCount);
                return;
            }

            var issuePluginEvent = NativeRenderFuncCommandBufferPayloadIssuePluginEventMethod;
            if (issuePluginEvent is null || issuePluginEvent.DeclaringType != commandBuffer.GetType())
            {
                issuePluginEvent = FindCommandBufferIssuePluginEventMethod(commandBuffer.GetType());
                NativeRenderFuncCommandBufferPayloadIssuePluginEventMethod = issuePluginEvent;
            }

            if (issuePluginEvent is null)
            {
                RecordNativeRenderFuncCommandBufferPayloadIssueFailure($"IssuePluginEvent(IntPtr, int) not found on {commandBuffer.GetType().FullName}");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadIssueFailureCount);
                return;
            }

            Interlocked.Exchange(ref NativeRenderFuncCommandBufferPayloadCallbackPtr, callback.ToInt64());
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferPayloadLastCommandBufferPtr, commandBufferPtr.ToInt64());
            lock (Sync)
            {
                NativeRenderFuncCommandBufferPayloadLastFailure = null;
            }

            issuePluginEvent.Invoke(commandBuffer, new object[] { callback, NativeRenderFuncCommandBufferPayloadEventId });
            Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadIssueSuccessCount);
        }
        catch (Exception ex)
        {
            RecordNativeRenderFuncCommandBufferPayloadIssueFailure(FirstLine(GetExceptionMessage(ex)));
            Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadIssueFailureCount);
        }
    }

    private static void RecordNativeRenderFuncCommandBufferPayloadIssueFailure(string failure)
    {
        lock (Sync)
        {
            NativeRenderFuncCommandBufferPayloadLastFailure = failure;
        }

        Log?.LogWarning($"Native render-func command-buffer payload event failed: {failure}");
    }

    private static void TryIssueNativeRenderFuncCommandBufferFrameDescriptorEvent(object commandBuffer, IntPtr commandBufferPtr)
    {
        if (Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorSetSuccessCount) <= 0)
        {
            return;
        }

        if (Interlocked.CompareExchange(ref NativeRenderFuncCommandBufferFrameDescriptorIssueAttemptCount, 1, 0) != 0)
        {
            return;
        }

        try
        {
            var bridge = Bridge;
            if (bridge is null)
            {
                RecordNativeRenderFuncCommandBufferFrameDescriptorIssueFailure("Native bridge was not available");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorIssueFailureCount);
                return;
            }

            var callback = bridge.GetRenderEventFunc();
            if (callback == IntPtr.Zero)
            {
                RecordNativeRenderFuncCommandBufferFrameDescriptorIssueFailure("native render event callback pointer was null");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorIssueFailureCount);
                return;
            }

            var issuePluginEvent = NativeRenderFuncCommandBufferFrameDescriptorIssuePluginEventMethod;
            if (issuePluginEvent is null)
            {
                issuePluginEvent = FindCommandBufferIssuePluginEventMethod(commandBuffer.GetType());
                NativeRenderFuncCommandBufferFrameDescriptorIssuePluginEventMethod = issuePluginEvent;
            }

            if (issuePluginEvent is null)
            {
                RecordNativeRenderFuncCommandBufferFrameDescriptorIssueFailure($"IssuePluginEvent(IntPtr, int) not found on {commandBuffer.GetType().FullName}");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorIssueFailureCount);
                return;
            }

            Interlocked.Exchange(ref NativeRenderFuncCommandBufferFrameDescriptorCallbackPtr, callback.ToInt64());
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferFrameDescriptorLastCommandBufferPtr, commandBufferPtr.ToInt64());
            lock (Sync)
            {
                NativeRenderFuncCommandBufferFrameDescriptorLastFailure = null;
            }

            issuePluginEvent.Invoke(commandBuffer, new object[] { callback, NativeRenderFuncCommandBufferFrameDescriptorEventId });
            Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorIssueSuccessCount);
        }
        catch (Exception ex)
        {
            RecordNativeRenderFuncCommandBufferFrameDescriptorIssueFailure(FirstLine(GetExceptionMessage(ex)));
            Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorIssueFailureCount);
        }
    }

    private static void RecordNativeRenderFuncCommandBufferFrameDescriptorIssueFailure(string failure)
    {
        lock (Sync)
        {
            NativeRenderFuncCommandBufferFrameDescriptorLastFailure = failure;
        }

        Log?.LogWarning($"Native render-func command-buffer frame descriptor event failed: {failure}");
    }

    private static void TryIssueNativeRenderFuncCommandBufferDlssFeatureCreateEvent(object commandBuffer, IntPtr commandBufferPtr)
    {
        if (Volatile.Read(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetSuccessCount) <= 0)
        {
            return;
        }

        if (Interlocked.CompareExchange(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueAttemptCount, 1, 0) != 0)
        {
            return;
        }

        var bridge = Bridge;
        if (bridge is null)
        {
            RecordNativeRenderFuncCommandBufferDlssFeatureCreateIssueFailure("Native bridge was not available");
            Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueFailureCount);
            return;
        }

        try
        {
            var callback = bridge.GetRenderEventFunc();
            if (callback == IntPtr.Zero)
            {
                RecordNativeRenderFuncCommandBufferDlssFeatureCreateIssueFailure("native render event callback pointer was null");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueFailureCount);
                return;
            }

            var issuePluginEvent = NativeRenderFuncCommandBufferDlssFeatureCreateIssuePluginEventMethod;
            if (issuePluginEvent is null || issuePluginEvent.DeclaringType != commandBuffer.GetType())
            {
                issuePluginEvent = FindCommandBufferIssuePluginEventMethod(commandBuffer.GetType());
                NativeRenderFuncCommandBufferDlssFeatureCreateIssuePluginEventMethod = issuePluginEvent;
            }

            if (issuePluginEvent is null)
            {
                RecordNativeRenderFuncCommandBufferDlssFeatureCreateIssueFailure($"IssuePluginEvent(IntPtr, int) not found on {commandBuffer.GetType().FullName}");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueFailureCount);
                return;
            }

            Interlocked.Exchange(ref NativeRenderFuncCommandBufferDlssFeatureCreateCallbackPtr, callback.ToInt64());
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferDlssFeatureCreateLastCommandBufferPtr, commandBufferPtr.ToInt64());
            lock (Sync)
            {
                NativeRenderFuncCommandBufferDlssFeatureCreateLastFailure = null;
            }

            issuePluginEvent.Invoke(commandBuffer, new object[] { callback, NativeRenderFuncCommandBufferDlssFeatureCreateEventId });
            Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueSuccessCount);
        }
        catch (Exception ex)
        {
            RecordNativeRenderFuncCommandBufferDlssFeatureCreateIssueFailure(FirstLine(GetExceptionMessage(ex)));
            Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateIssueFailureCount);
        }
    }

    private static void RecordNativeRenderFuncCommandBufferDlssFeatureCreateIssueFailure(string failure)
    {
        lock (Sync)
        {
            NativeRenderFuncCommandBufferDlssFeatureCreateLastFailure = failure;
        }

        Log?.LogWarning($"Native render-func command-buffer DLSS feature-create event failed: {failure}");
    }

    private static MethodInfo? FindCommandBufferIssuePluginEventMethod(Type commandBufferType)
    {
        return commandBufferType
            .GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .FirstOrDefault(method =>
            {
                if (!string.Equals(method.Name, "IssuePluginEvent", StringComparison.Ordinal))
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 2
                    && parameters[0].ParameterType == typeof(IntPtr)
                    && parameters[1].ParameterType == typeof(int);
            });
    }

    private static string SummarizeNativeRenderFuncEntryMethod(object renderFunc)
    {
        var methodInfo = TryReadMemberObject(renderFunc, "method")
            ?? TryReadMemberObject(renderFunc, "Method")
            ?? TryReadMemberObject(renderFunc, "method_info")
            ?? TryReadMemberObject(renderFunc, "original_method_info");
        if (methodInfo is null)
        {
            return "method=not found";
        }

        var methodName = FirstLine(TryReadPropertyString(methodInfo, "Name") ?? "unknown");
        var declaringType = FirstLine(TryReadPropertyString(methodInfo, "DeclaringType") ?? "unknown");
        var reflectedType = FirstLine(TryReadPropertyString(methodInfo, "ReflectedType") ?? "unknown");
        var metadataToken = FirstLine(TryReadPropertyString(methodInfo, "MetadataToken") ?? "unknown");
        return $"methodName={methodName}; declaringType={declaringType}; reflectedType={reflectedType}; metadataToken={metadataToken}";
    }

    private static string? TryReadNativeRenderFuncEntryMethodName(object renderFunc)
    {
        var methodInfo = TryReadMemberObject(renderFunc, "method")
            ?? TryReadMemberObject(renderFunc, "Method")
            ?? TryReadMemberObject(renderFunc, "method_info")
            ?? TryReadMemberObject(renderFunc, "original_method_info");
        return methodInfo is null ? null : TryReadPropertyString(methodInfo, "Name");
    }

    private static bool TryReadRenderFuncPointer(object renderFunc, string memberName, out IntPtr pointer)
    {
        pointer = IntPtr.Zero;
        var value = TryReadMemberObject(renderFunc, memberName);
        switch (value)
        {
            case IntPtr intPtr:
                pointer = intPtr;
                return true;
            case UIntPtr uintPtr:
                pointer = unchecked((IntPtr)(long)uintPtr.ToUInt64());
                return true;
            case long signed:
                pointer = new IntPtr(signed);
                return true;
            case ulong unsigned:
                pointer = unchecked((IntPtr)(long)unsigned);
                return true;
            default:
                return false;
        }
    }

    private static IntPtr TryGetIl2CppObjectPointer(object value)
    {
#if VRISINGDLSS_LOCAL_INTEROP
        if (value is Il2CppInterop.Runtime.InteropTypes.Il2CppObjectBase il2CppObject)
        {
            try
            {
                return il2CppObject.Pointer;
            }
            catch
            {
                return IntPtr.Zero;
            }
        }
#endif

        return TryCoercePointer(
            TryReadPropertyObject(value, "Pointer")
            ?? TryReadFieldObject(value, "Pointer")
            ?? TryReadFieldObject(value, "pointer")
            ?? TryReadFieldObject(value, "m_Ptr"));
    }

    private static IntPtr TryCoercePointer(object? value)
    {
        return value switch
        {
            IntPtr intPtr => intPtr,
            UIntPtr uintPtr => unchecked((IntPtr)(long)uintPtr.ToUInt64()),
            long signed => new IntPtr(signed),
            ulong unsigned => unchecked((IntPtr)(long)unsigned),
            int signedInt => new IntPtr(signedInt),
            uint unsignedInt => new IntPtr(unchecked((int)unsignedInt)),
            _ => IntPtr.Zero
        };
    }

    private static void TryLogRenderGraphCompiledPassInfos(
        int compileCount,
        object renderGraph,
        IReadOnlyList<(int Ordinal, object Pass, string Name, string TypeName, string Category)> passSummaries)
    {
        if (!RenderGraphCompiledPassInfoProbeEnabled)
        {
            return;
        }

        var log = Log;
        if (log is null)
        {
            return;
        }

        var compiledPassInfos = TryReadRenderGraphCompiledPassInfos(renderGraph, out var compiledPassInfoSource);
        if (compiledPassInfos is null)
        {
            log.LogInfo($"RenderGraph compiled-pass-info compile #{compileCount}: compiledPassInfos=not found");
            return;
        }

        var compiledInfos = EnumerateRuntimeSequence(compiledPassInfos)
            .Where(info => info is not null)
            .Cast<object>()
            .ToArray();
        var declaredCount = TryReadInt(compiledPassInfos, "size", out var size)
            ? size.ToString(CultureInfo.InvariantCulture)
            : "unknown";
        var focusCount = compiledInfos.Count(info =>
        {
            var name = FirstLine(TryReadPropertyString(info, "name") ?? TryReadFieldString(info, "name") ?? string.Empty);
            var index = TryReadInt(info, "index", out var passIndex) ? passIndex : -1;
            var fallback = passSummaries.FirstOrDefault(summary => summary.Ordinal == index);
            var category = ClassifyRenderGraphPassBoundary(
                string.IsNullOrWhiteSpace(name) ? fallback.Name : name,
                fallback.TypeName ?? info.GetType().FullName ?? info.GetType().Name);
            return !string.Equals(category, "other", StringComparison.Ordinal);
        });

        if (compileCount <= MaxRenderGraphPassListCompileLogs || compileCount % 300 == 0)
        {
            log.LogInfo($"RenderGraph compiled-pass-info compile #{compileCount}: source={compiledPassInfoSource}; compiledCount={declaredCount}; enumerated={compiledInfos.Length}; focusCount={focusCount}");
        }

        foreach (var compiledInfo in compiledInfos)
        {
            var compiledName = FirstLine(TryReadPropertyString(compiledInfo, "name") ?? TryReadFieldString(compiledInfo, "name") ?? string.Empty);
            var compiledIndex = TryReadInt(compiledInfo, "index", out var index) ? index : -1;
            var fallback = passSummaries.FirstOrDefault(summary => summary.Ordinal == compiledIndex);
            var passName = string.IsNullOrWhiteSpace(compiledName) ? fallback.Name : compiledName;
            var passType = fallback.TypeName ?? compiledInfo.GetType().FullName ?? compiledInfo.GetType().Name;
            var category = ClassifyRenderGraphPassBoundary(passName, passType);
            if (string.Equals(category, "other", StringComparison.Ordinal))
            {
                continue;
            }

            int infoLogCount;
            lock (Sync)
            {
                RenderGraphCompiledPassInfoLogCount++;
                infoLogCount = RenderGraphCompiledPassInfoLogCount;
            }

            if (infoLogCount > MaxRenderGraphCompiledPassInfoLogs && infoLogCount % 500 != 0)
            {
                continue;
            }

            var state = DescribeRenderGraphCompiledPassInfo(compiledInfo, fallback.Pass);
            var resourceCreateSummary = SummarizeRenderGraphResourceLifetimeLists(TryReadPropertyObject(compiledInfo, "resourceCreateList") ?? TryReadFieldObject(compiledInfo, "resourceCreateList"));
            var resourceReleaseSummary = SummarizeRenderGraphResourceLifetimeLists(TryReadPropertyObject(compiledInfo, "resourceReleaseList") ?? TryReadFieldObject(compiledInfo, "resourceReleaseList"));
            log.LogInfo($"RenderGraph compiled-pass-info #{infoLogCount}: compile={compileCount}; ordinal={compiledIndex}; pass=\"{passName}\"; category={category}; passType={passType}{state}; resourceCreateList={resourceCreateSummary}; resourceReleaseList={resourceReleaseSummary}");
        }
    }

    private static object? TryReadRenderGraphCompiledPassInfos(object renderGraph, out string source)
    {
        source = "not found";

        var direct = TryReadMemberObject(renderGraph, "m_CompiledPassInfos")
            ?? TryReadMemberObject(renderGraph, "compiledPassInfos");
        if (direct is not null)
        {
            source = "renderGraph";
            return direct;
        }

        var currentCompiledGraph = TryReadMemberObject(renderGraph, "m_CurrentCompiledGraph");
        var current = TryReadCompiledGraphPassInfos(currentCompiledGraph);
        if (current is not null)
        {
            source = "m_CurrentCompiledGraph.compiledPassInfos";
            return current;
        }

        var defaultCompiledGraph = TryReadMemberObject(renderGraph, "m_DefaultCompiledGraph");
        var fallback = TryReadCompiledGraphPassInfos(defaultCompiledGraph);
        if (fallback is not null)
        {
            source = "m_DefaultCompiledGraph.compiledPassInfos";
            return fallback;
        }

        return null;
    }

    private static object? TryReadCompiledGraphPassInfos(object? compiledGraph)
    {
        return compiledGraph is null
            ? null
            : TryReadMemberObject(compiledGraph, "compiledPassInfos")
                ?? TryReadMemberObject(compiledGraph, "m_CompiledPassInfos");
    }

    private static void TryLogRenderGraphPassBoundary(MethodBase originalMethod, object?[]? args)
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
                RenderGraphPassBoundaryCallCount++;
                count = RenderGraphPassBoundaryCallCount;
            }

            if (count > MaxRenderGraphPassBoundaryLogs && count % 300 != 0)
            {
                return;
            }

            var passInfo = FindTypedArgument(args, "CompiledPassInfo")
                ?? (args is { Length: > 0 } ? args[0] : null);
            var pass = FindRenderGraphPassArgument(args);
            if (pass is null)
            {
                log.LogInfo($"RenderGraph pass boundary #{count}: method={HookTargetCatalog.FormatMethod(originalMethod)}; pass=not found; args=[{SummarizeArguments(args)}]");
                return;
            }

            var passName = FirstLine(GetRenderGraphPassName(pass));
            var passType = pass.GetType().FullName ?? pass.GetType().Name;
            var category = ClassifyRenderGraphPassBoundary(passName, passType);
            var passInfoSummary = DescribeRenderGraphCompiledPassInfo(passInfo, pass);

            log.LogInfo($"RenderGraph pass boundary #{count}: method={HookTargetCatalog.FormatMethod(originalMethod)}; pass=\"{passName}\"; category={category}; passType={passType}{passInfoSummary}");
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph pass-boundary logging failed: {GetExceptionMessage(ex)}");
        }
    }

    private static string DescribeRenderGraphCompiledPassInfo(object? passInfo, object? pass)
    {
        var parts = new List<string>();
        if (pass is not null)
        {
            AddSimpleMemberSummary(parts, "passIndex", pass, "index");
        }

        if (passInfo is not null)
        {
            AddSimpleMemberSummary(parts, "compiledIndex", passInfo, "index");
            AddSimpleMemberSummary(parts, "culled", passInfo, "culled");
            AddSimpleMemberSummary(parts, "culledByRendererList", passInfo, "culledByRendererList");
            AddSimpleMemberSummary(parts, "hasSideEffect", passInfo, "hasSideEffect");
            AddSimpleMemberSummary(parts, "enableAsyncCompute", passInfo, "enableAsyncCompute");
            AddSimpleMemberSummary(parts, "refCount", passInfo, "refCount");
            AddSimpleMemberSummary(parts, "syncToPassIndex", passInfo, "syncToPassIndex");
            AddSimpleMemberSummary(parts, "syncFromPassIndex", passInfo, "syncFromPassIndex");
            AddSimpleMemberSummary(parts, "needGraphicsFence", passInfo, "needGraphicsFence");
        }

        return parts.Count == 0 ? string.Empty : $"; info={string.Join(",", parts)}";
    }

    private static string SummarizeRenderGraphResourceLifetimeLists(object? lifetimeLists)
    {
        if (lifetimeLists is null)
        {
            return "not found";
        }

        var counts = EnumerateRuntimeSequence(lifetimeLists)
            .Select(CountRuntimeSequenceItems)
            .ToArray();
        if (counts.Length == 0)
        {
            return "empty";
        }

        var total = counts.Sum();
        var formattedCounts = string.Join(",", counts.Take(8).Select(count => count.ToString(CultureInfo.InvariantCulture)));
        var truncated = counts.Length > 8 ? $",truncated={counts.Length - 8}" : string.Empty;
        return $"groups={counts.Length},total={total},counts=[{formattedCounts}{truncated}]";
    }

    private static int CountRuntimeSequenceItems(object? sequence)
    {
        var count = 0;
        foreach (var _ in EnumerateRuntimeSequence(sequence))
        {
            count++;
        }

        return count;
    }

    private static string DescribeRenderGraphPassListEntry(object pass)
    {
        var parts = new List<string>();
        AddSimpleMemberSummary(parts, "passIndex", pass, "index");
        AddSimpleMemberSummary(parts, "customSampler", pass, "customSampler");
        AddSimpleMemberSummary(parts, "allowPassCulling", pass, "allowPassCulling");
        AddSimpleMemberSummary(parts, "enableAsyncCompute", pass, "enableAsyncCompute");
        return parts.Count == 0 ? string.Empty : $"; info={string.Join(",", parts)}";
    }

    private static bool IsFocusedRenderGraphPassDeclarationTarget(string passName, string category)
    {
        if (string.Equals(category, "upscale", StringComparison.Ordinal)
            || string.Equals(category, "postprocess", StringComparison.Ordinal)
            || string.Equals(category, "final", StringComparison.Ordinal)
            || string.Equals(category, "dlss", StringComparison.Ordinal))
        {
            return true;
        }

        return passName.IndexOf("Motion Vector", StringComparison.OrdinalIgnoreCase) >= 0
            || passName.IndexOf("MotionVectors", StringComparison.OrdinalIgnoreCase) >= 0
            || passName.IndexOf("Motion Blur", StringComparison.OrdinalIgnoreCase) >= 0
            || passName.IndexOf("Temporal Anti", StringComparison.OrdinalIgnoreCase) >= 0
            || passName.IndexOf("TAA", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static bool IsFocusedRenderGraphPassDataSnapshotTarget(string passName, string passType, string category)
    {
        if (string.Equals(category, "dlss", StringComparison.Ordinal))
        {
            return true;
        }

        var value = $"{passName} {passType}";
        return value.IndexOf("Uber Post", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("UberPostPassData", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("EASUData", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Final Pass", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("FinalPassData", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static object? TryReadTypedRenderGraphPassDataSnapshotObject(object pass, string passName)
    {
#if VRISINGDLSS_LOCAL_INTEROP
        if (pass is not Il2CppInterop.Runtime.InteropTypes.Il2CppObjectBase il2CppPass)
        {
            return null;
        }

        try
        {
            if (passName.IndexOf("Deep Learning Super Sampling", StringComparison.OrdinalIgnoreCase) >= 0
                || passName.IndexOf("DLSS", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassData<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.DLSSData>(il2CppPass);
            }

            if (passName.IndexOf("Uber Post", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassData<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.UberPostPassData>(il2CppPass);
            }

            if (passName.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassData<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.EASUData>(il2CppPass);
            }

            if (passName.IndexOf("Final Pass", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassData<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.FinalPassData>(il2CppPass);
            }
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph pass-data typed read failed for pass \"{FirstLine(passName)}\": {GetExceptionMessage(ex)}");
        }
#endif
        return null;
    }

#if VRISINGDLSS_LOCAL_INTEROP
    private static object? TryReadTypedRenderGraphPassData<TPassData>(
        Il2CppInterop.Runtime.InteropTypes.Il2CppObjectBase pass)
        where TPassData : class
    {
        var typedPass = pass.TryCast<UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphPass<TPassData>>();
        return typedPass?.data;
    }

    private static object? TryReadTypedRenderGraphPassRenderFunc<TPassData>(
        Il2CppInterop.Runtime.InteropTypes.Il2CppObjectBase pass)
        where TPassData : class
    {
        var typedPass = pass.TryCast<UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphPass<TPassData>>();
        return typedPass?.renderFunc;
    }
#endif

    private static object? TryReadTypedRenderGraphPassRenderFuncObject(object pass, string passName)
    {
#if VRISINGDLSS_LOCAL_INTEROP
        if (pass is not Il2CppInterop.Runtime.InteropTypes.Il2CppObjectBase il2CppPass)
        {
            return null;
        }

        try
        {
            if (passName.IndexOf("Deep Learning Super Sampling", StringComparison.OrdinalIgnoreCase) >= 0
                || passName.IndexOf("DLSS", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassRenderFunc<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.DLSSData>(il2CppPass);
            }

            if (passName.IndexOf("Uber Post", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassRenderFunc<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.UberPostPassData>(il2CppPass);
            }

            if (passName.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassRenderFunc<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.EASUData>(il2CppPass);
            }

            if (passName.IndexOf("Final Pass", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TryReadTypedRenderGraphPassRenderFunc<UnityEngine.Rendering.HighDefinition.HDRenderPipeline.FinalPassData>(il2CppPass);
            }
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"RenderGraph pass render-func metadata typed read failed for pass \"{FirstLine(passName)}\": {GetExceptionMessage(ex)}");
        }
#endif
        return null;
    }

    private static IReadOnlyList<RenderGraphPassDataSnapshotMember> CollectRenderGraphPassDataSnapshotMembers(
        string passName,
        string dataType,
        object passData)
    {
        var members = new List<RenderGraphPassDataSnapshotMember>();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var memberName in GetRenderGraphPassDataSnapshotMemberNames(passName, dataType))
        {
            AddRenderGraphPassDataSnapshotMember(memberName, passData, members, seen);
        }

        return members;
    }

    private static IReadOnlyList<string> GetRenderGraphPassDataSnapshotMemberNames(string passName, string dataType)
    {
        var value = $"{passName} {dataType}";
        if (value.IndexOf("Uber Post", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("UberPostPassData", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return new[]
            {
                "width",
                "height",
                "viewCount",
                "source",
                "destination",
                "logLut",
                "bloomTexture"
            };
        }

        if (value.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("EASUData", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return new[]
            {
                "inputWidth",
                "inputHeight",
                "outputWidth",
                "outputHeight",
                "viewCount",
                "source",
                "destination"
            };
        }

        if (value.IndexOf("Final Pass", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("FinalPassData", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return new[]
            {
                "performUpsampling",
                "dynamicResIsOn",
                "dynamicResFilter",
                "source",
                "destination",
                "afterPostProcessTexture",
                "alphaTexture",
                "uiBuffer",
                "postProcessIsFinalPass"
            };
        }

        if (value.IndexOf("Deep Learning Super Sampling", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("DLSSData", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return new[]
            {
                "resourceHandles",
                "parameters"
            };
        }

        return Array.Empty<string>();
    }

    private static void AddRenderGraphPassDataSnapshotMember(
        string memberName,
        object passData,
        ICollection<RenderGraphPassDataSnapshotMember> members,
        ISet<string> seen)
    {
        var value = TryReadPropertyObject(passData, memberName)
            ?? TryReadFieldObject(passData, memberName);
        if (value is null)
        {
            return;
        }

        var kind = "value";
        string summary;
        if (TypeNameContains(value.GetType(), "TextureHandle"))
        {
            kind = "texture";
            var resourceHandle = TryGetResourceHandleFromTextureHandle(value);
            summary = resourceHandle is null
                ? FirstLine(SummarizeValue(value))
                : FirstLine(SummarizeValue(resourceHandle));
        }
        else if (TypeNameContains(value.GetType(), "ResourceHandle"))
        {
            kind = IsTextureResourceHandle(value) ? "texture-resource" : "resource";
            summary = FirstLine(SummarizeValue(value));
        }
        else
        {
            summary = FirstLine(SummarizeValue(value));
        }

        var key = $"{memberName}:{kind}:{summary}";
        if (!seen.Add(key))
        {
            return;
        }

        members.Add(new RenderGraphPassDataSnapshotMember(memberName, kind, summary));
    }

    private static string FormatRenderGraphPassDataSnapshotMember(RenderGraphPassDataSnapshotMember member)
    {
        return $"{member.Label}:{member.Kind}:{member.Summary}";
    }

    private static IReadOnlyList<RenderGraphPassResourceDeclaration> CollectRenderGraphPassResourceDeclarations(object pass)
    {
        var declarations = new List<RenderGraphPassResourceDeclaration>();
        var seen = new HashSet<string>(StringComparer.Ordinal);

        var colorBuffers = TryReadPropertyObject(pass, "colorBuffers")
            ?? TryReadFieldObject(pass, "_colorBuffers_k__BackingField");
        var colorIndex = 0;
        foreach (var colorBuffer in EnumerateRuntimeSequence(colorBuffers))
        {
            AddTextureHandleDeclaration($"color[{colorIndex}]", colorBuffer, declarations, seen);
            colorIndex++;
        }

        var depthBuffer = TryReadPropertyObject(pass, "depthBuffer")
            ?? TryReadFieldObject(pass, "_depthBuffer_k__BackingField");
        AddTextureHandleDeclaration("depth", depthBuffer, declarations, seen);

        var resourceReadLists = TryReadPropertyObject(pass, "resourceReadLists")
            ?? TryReadFieldObject(pass, "resourceReadLists");
        AddResourceListDeclarations("read", resourceReadLists, declarations, seen);

        var resourceWriteLists = TryReadPropertyObject(pass, "resourceWriteLists")
            ?? TryReadFieldObject(pass, "resourceWriteLists");
        AddResourceListDeclarations("write", resourceWriteLists, declarations, seen);

        return declarations;
    }

    private static void AddResourceListDeclarations(
        string labelPrefix,
        object? resourceLists,
        ICollection<RenderGraphPassResourceDeclaration> declarations,
        ISet<string> seen)
    {
        var listIndex = 0;
        foreach (var resourceList in EnumerateRuntimeSequence(resourceLists))
        {
            var itemIndex = 0;
            foreach (var resourceHandle in EnumerateRuntimeSequence(resourceList))
            {
                AddResourceHandleDeclaration($"{labelPrefix}[{listIndex}:{itemIndex}]", resourceHandle, declarations, seen);
                itemIndex++;
            }

            listIndex++;
        }
    }

    private static void AddTextureHandleDeclaration(
        string label,
        object? textureHandle,
        ICollection<RenderGraphPassResourceDeclaration> declarations,
        ISet<string> seen)
    {
        if (textureHandle is null || !TypeNameContains(textureHandle.GetType(), "TextureHandle"))
        {
            return;
        }

        var resourceHandle = TryGetResourceHandleFromTextureHandle(textureHandle);
        var summary = resourceHandle is null
            ? FirstLine(SummarizeValue(textureHandle))
            : FirstLine(SummarizeValue(resourceHandle));
        AddRenderGraphPassResourceDeclaration(label, "texture", summary, declarations, seen);
    }

    private static void AddResourceHandleDeclaration(
        string label,
        object? resourceHandle,
        ICollection<RenderGraphPassResourceDeclaration> declarations,
        ISet<string> seen)
    {
        if (resourceHandle is null || !TypeNameContains(resourceHandle.GetType(), "ResourceHandle"))
        {
            return;
        }

        var kind = IsTextureResourceHandle(resourceHandle) ? "texture-resource" : "resource";
        AddRenderGraphPassResourceDeclaration(label, kind, FirstLine(SummarizeValue(resourceHandle)), declarations, seen);
    }

    private static void AddRenderGraphPassResourceDeclaration(
        string label,
        string kind,
        string summary,
        ICollection<RenderGraphPassResourceDeclaration> declarations,
        ISet<string> seen)
    {
        var key = $"{label}:{kind}:{summary}";
        if (!seen.Add(key))
        {
            return;
        }

        declarations.Add(new RenderGraphPassResourceDeclaration(label, kind, summary));
    }

    private static string FormatRenderGraphPassResourceDeclaration(RenderGraphPassResourceDeclaration declaration)
    {
        return $"{declaration.Label}:{declaration.Kind}:{declaration.Summary}";
    }

    private static void AddSimpleMemberSummary(ICollection<string> parts, string label, object instance, string memberName)
    {
        var value = TryReadPropertyString(instance, memberName)
            ?? TryReadFieldString(instance, memberName);
        if (!string.IsNullOrWhiteSpace(value))
        {
            parts.Add($"{label}={FirstLine(value)}");
        }
    }

    private static string ClassifyRenderGraphPassBoundary(string passName, string passType)
    {
        var value = $"{passName} {passType}";
        if (value.IndexOf("Deep Learning Super Sampling", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("DLSS", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return "dlss";
        }

        if (value.IndexOf("Upsampling", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Upsampled", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Edge Adaptive Spatial Upsampling", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("FSR", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return "upscale";
        }

        if (value.IndexOf("FinalPass", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Final Pass", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("BlitFinalCameraTexture", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Backbuffer", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return "final";
        }

        if (value.IndexOf("PostProcess", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Post Process", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Uber", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("FXAA", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("SMAA", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return "postprocess";
        }

        if (value.IndexOf("Temporal", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("TAA", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Motion Vector", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("MotionVectors", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return "temporal";
        }

        return "other";
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
            if (!DlssEvaluateInputProbeEnabled || !ResourceMaterializationProbeEnabled)
            {
                return;
            }

            if (DlssEvaluateInputProbeSucceeded
                && !DlssSuperResolutionInputProbeEnabled
                && !DlssVisibleWritebackProbeEnabled
                && !DlssUserRenderingEnabled)
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
                    $"TextureResource.graphicsResource nativeOwner={SummarizeValue(owner ?? graphicsResource!)} epoch={epoch}",
                    TryGetUnityFrameCount(out var candidateFrame) ? candidateFrame : -1);
                RenderGraphResourceMaterializationCandidates[resourceName] = candidate;
                snapshot = RenderGraphResourceMaterializationCandidates.Values.ToArray();
            }

            TryRunRenderGraphMaterializationDlssEvaluateInputProbe(log, bridge, snapshot);
            TryRunRenderGraphDlssSuperResolutionInputProbe(log, bridge, snapshot, "RenderGraph materialization");
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
            if (ShouldFastSkipRenderGraphGetTextureForCachedTupleDriver())
            {
                return;
            }

            var log = Log;
            if (log is null)
            {
                return;
            }

            TryHandleNativeRenderFuncResourceNativePointerGetTexture(log, __args, __result);
            if (!RenderGraphGetTextureProbeEnabled)
            {
                return;
            }

            var bridge = Bridge;
            if (bridge is null)
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
                TryRunRenderGraphDlssSuperResolutionInputProbe(log, bridge, snapshot, "RenderGraph GetTexture");
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

    private static void TryHandleNativeRenderFuncResourceNativePointerGetTexture(
        ManualLogSource log,
        object?[]? args,
        object? result)
    {
        if (!NativeRenderFuncResourceNativePointerProbeEnabled)
        {
            return;
        }

        NativeRenderFuncResourceNativePointerTarget target;
        lock (Sync)
        {
            var shouldKeepRefreshingForFrameDescriptor = NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled
                && Volatile.Read(ref NativeRenderFuncCommandBufferFrameDescriptorSetSuccessCount) <= 0;
            if ((NativeRenderFuncResourceNativePointerAdvancedLogged
                    && !HdrpEasuInputOutputCorrelationProbeState.ShouldRefreshEasuOutput()
                    && !shouldKeepRefreshingForFrameDescriptor)
                || !NativeRenderFuncResourceNativePointerArmedTarget.HasValue)
            {
                return;
            }

            target = NativeRenderFuncResourceNativePointerArmedTarget.Value;
        }

        var handle = args is { Length: > 0 } ? args[0] : null;
        if (handle is null)
        {
            return;
        }

        var resourceHandle = TryGetResourceHandleFromTextureHandle(handle);
        if (resourceHandle is null)
        {
            return;
        }

        var resourceHandleSummary = FirstLine(SummarizeValue(resourceHandle));
        string? label = null;
        if (string.Equals(resourceHandleSummary, target.SourceResourceHandle, StringComparison.Ordinal))
        {
            label = "source";
        }
        else if (string.Equals(resourceHandleSummary, target.DestinationResourceHandle, StringComparison.Ordinal))
        {
            label = "destination";
        }

        if (label is null)
        {
            return;
        }

        int statusLogCount;
        bool shouldLog;
        lock (Sync)
        {
            NativeRenderFuncResourceNativePointerStatusLogCount++;
            statusLogCount = NativeRenderFuncResourceNativePointerStatusLogCount;
            shouldLog = statusLogCount <= MaxNativeRenderFuncResourceNativePointerStatusLogs || statusLogCount % 300 == 0;
        }

        if (result is null)
        {
            if (shouldLog)
            {
                log.LogInfo($"Native render-func resource native-pointer status #{statusLogCount}: label={label}; handle=\"{resourceHandleSummary}\"; result=null; nativePtr=not found; targetCompile={target.CompileCount}; tuple={target.TupleSummary}");
            }

            return;
        }

        if (!TryFindNativeTexturePtr(result, out var owner, out var pointer) || pointer == IntPtr.Zero)
        {
            if (shouldLog)
            {
                log.LogInfo($"Native render-func resource native-pointer status #{statusLogCount}: label={label}; handle=\"{resourceHandleSummary}\"; result={FirstLine(SummarizeValue(result))}; nativePtr=not found; targetCompile={target.CompileCount}; tuple={target.TupleSummary}");
            }

            return;
        }

        var observation = new NativeRenderFuncResourceNativePointerObservation(
            label,
            resourceHandleSummary,
            pointer,
            owner is null ? "unknown" : FirstLine(SummarizeValue(owner)),
            FirstLine(SummarizeValue(result)),
            TryGetUnityFrameCount(out var frameCount) ? frameCount : -1);

        bool shouldLogAdvanced = false;
        bool shouldProbeD3D11Pair = false;
        NativeRenderFuncResourceNativePointerObservation? sourceObservation;
        NativeRenderFuncResourceNativePointerObservation? destinationObservation;
        lock (Sync)
        {
            if (string.Equals(label, "source", StringComparison.Ordinal))
            {
                NativeRenderFuncResourceNativePointerSourceObservation = observation;
            }
            else
            {
                NativeRenderFuncResourceNativePointerDestinationObservation = observation;
            }

            sourceObservation = NativeRenderFuncResourceNativePointerSourceObservation;
            destinationObservation = NativeRenderFuncResourceNativePointerDestinationObservation;
            if (sourceObservation.HasValue
                && destinationObservation.HasValue
                && !NativeRenderFuncResourceNativePointerAdvancedLogged)
            {
                NativeRenderFuncResourceNativePointerAdvancedLogged = true;
                shouldLogAdvanced = true;
            }

            if (sourceObservation.HasValue
                && destinationObservation.HasValue
                && NativeRenderFuncResourceD3D11ProbeEnabled
                && !NativeRenderFuncResourceD3D11AdvancedLogged)
            {
                NativeRenderFuncResourceD3D11AdvancedLogged = true;
                shouldProbeD3D11Pair = true;
            }
        }

        if (shouldLog)
        {
            log.LogInfo($"Native render-func resource native-pointer status #{statusLogCount}: label={label}; handle=\"{resourceHandleSummary}\"; result={observation.ResultSummary}; nativeOwner={observation.NativeOwnerSummary}; nativePtr=0x{pointer.ToInt64():X}; frame={observation.FrameCount}; targetCompile={target.CompileCount}; tuple={target.TupleSummary}");
        }

        if (shouldLogAdvanced && sourceObservation.HasValue && destinationObservation.HasValue)
        {
            log.LogInfo($"Native render-func resource native-pointer advanced: source=({FormatNativeRenderFuncResourceNativePointerObservation(sourceObservation.Value)}); destination=({FormatNativeRenderFuncResourceNativePointerObservation(destinationObservation.Value)}); targetCompile={target.CompileCount}; targetManagedPassData=0x{target.ManagedPassDataPointer:X}; tuple={target.TupleSummary}");
        }

        if (shouldProbeD3D11Pair && sourceObservation.HasValue && destinationObservation.HasValue)
        {
            TryLogNativeRenderFuncResourceD3D11Pair(log, sourceObservation.Value, destinationObservation.Value, target);
        }

        if (sourceObservation.HasValue && destinationObservation.HasValue)
        {
            HdrpEasuInputOutputCorrelationProbeState.RecordEasuOutput(
                log,
                new HdrpEasuInputOutputCorrelationProbeState.EasuOutputSnapshot(
                    sourceObservation.Value.Pointer,
                    destinationObservation.Value.Pointer,
                    sourceObservation.Value.FrameCount,
                    destinationObservation.Value.FrameCount,
                    target.CompileCount,
                    $"0x{target.ManagedPassDataPointer:X}",
                    target.TupleSummary,
                    FormatNativeRenderFuncResourceNativePointerObservation(sourceObservation.Value),
                    FormatNativeRenderFuncResourceNativePointerObservation(destinationObservation.Value)));
        }

        if (NativeRenderFuncCommandBufferPayloadProbeEnabled && sourceObservation.HasValue && destinationObservation.HasValue)
        {
            TrySetNativeRenderFuncCommandBufferPayload(log, sourceObservation.Value, destinationObservation.Value, target);
        }

        if (NativeRenderFuncCommandBufferFrameDescriptorProbeEnabled && sourceObservation.HasValue && destinationObservation.HasValue)
        {
            TrySetNativeRenderFuncCommandBufferFrameDescriptorPayload(log, sourceObservation.Value, destinationObservation.Value, target);
        }

        if (NativeRenderFuncCommandBufferDlssFeatureCreateProbeEnabled && sourceObservation.HasValue && destinationObservation.HasValue)
        {
            TrySetNativeRenderFuncCommandBufferDlssFeatureCreatePayload(log, sourceObservation.Value, destinationObservation.Value, target);
        }
    }

    private static string FormatNativeRenderFuncResourceNativePointerObservation(NativeRenderFuncResourceNativePointerObservation observation)
    {
        return $"handle=\"{observation.ResourceHandle}\"; nativePtr=0x{observation.Pointer.ToInt64():X}; nativeOwner={observation.NativeOwnerSummary}; result={observation.ResultSummary}; frame={observation.FrameCount}";
    }

    private static void TryLogNativeRenderFuncResourceD3D11Pair(
        ManualLogSource log,
        NativeRenderFuncResourceNativePointerObservation sourceObservation,
        NativeRenderFuncResourceNativePointerObservation destinationObservation,
        NativeRenderFuncResourceNativePointerTarget target)
    {
        try
        {
            var bridge = Bridge;
            if (bridge is null)
            {
                log.LogWarning("Native render-func resource D3D11 pair failed: native bridge was unavailable.");
                return;
            }

            var success = bridge.ProbeD3D11TexturePair(sourceObservation.Pointer, destinationObservation.Pointer);
            var status = bridge.GetD3D11TexturePairProbeStatus();
            var message = $"Native render-func resource D3D11 pair {(success ? "advanced" : "failed")}: source=({FormatNativeRenderFuncResourceNativePointerObservation(sourceObservation)}); destination=({FormatNativeRenderFuncResourceNativePointerObservation(destinationObservation)}); targetCompile={target.CompileCount}; targetManagedPassData=0x{target.ManagedPassDataPointer:X}; tuple={target.TupleSummary}; {status}";
            if (success)
            {
                log.LogInfo(message);
            }
            else
            {
                log.LogWarning(message);
            }
        }
        catch (Exception ex)
        {
            log.LogWarning($"Native render-func resource D3D11 pair failed: {GetExceptionMessage(ex)}");
        }
    }

    private static void TrySetNativeRenderFuncCommandBufferPayload(
        ManualLogSource log,
        NativeRenderFuncResourceNativePointerObservation sourceObservation,
        NativeRenderFuncResourceNativePointerObservation destinationObservation,
        NativeRenderFuncResourceNativePointerTarget target)
    {
        if (Interlocked.CompareExchange(ref NativeRenderFuncCommandBufferPayloadSetAttemptCount, 1, 0) != 0)
        {
            return;
        }

        try
        {
            var bridge = Bridge;
            if (bridge is null)
            {
                RecordNativeRenderFuncCommandBufferPayloadSetFailure("native bridge was unavailable");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadSetFailureCount);
                return;
            }

            var sequence = Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadSequence);
            var beforeConsumed = bridge.GetRenderEventTexturePayloadConsumedCount();
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferPayloadBeforeConsumedCount, beforeConsumed);
            var success = bridge.SetRenderEventTexturePayload(
                sourceObservation.Pointer,
                destinationObservation.Pointer,
                NativeRenderFuncCommandBufferPayloadEventId,
                sequence);
            var status = bridge.GetRenderEventTexturePayloadStatus();
            lock (Sync)
            {
                NativeRenderFuncCommandBufferPayloadLastStatus = status;
                NativeRenderFuncCommandBufferPayloadLastFailure = success ? null : status;
            }

            var message = $"Native render-func command-buffer payload set {(success ? "advanced" : "failed")}: source=({FormatNativeRenderFuncResourceNativePointerObservation(sourceObservation)}); destination=({FormatNativeRenderFuncResourceNativePointerObservation(destinationObservation)}); targetCompile={target.CompileCount}; targetManagedPassData=0x{target.ManagedPassDataPointer:X}; tuple={target.TupleSummary}; beforeConsumed={beforeConsumed}; eventId={NativeRenderFuncCommandBufferPayloadEventId}; sequence={sequence}; status=\"{status}\"";
            if (success)
            {
                Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadSetSuccessCount);
                log.LogInfo(message);
            }
            else
            {
                Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadSetFailureCount);
                log.LogWarning(message);
            }
        }
        catch (Exception ex)
        {
            RecordNativeRenderFuncCommandBufferPayloadSetFailure(FirstLine(GetExceptionMessage(ex)));
            Interlocked.Increment(ref NativeRenderFuncCommandBufferPayloadSetFailureCount);
        }
    }

    private static void RecordNativeRenderFuncCommandBufferPayloadSetFailure(string failure)
    {
        lock (Sync)
        {
            NativeRenderFuncCommandBufferPayloadLastFailure = failure;
        }

        Log?.LogWarning($"Native render-func command-buffer payload set failed: {failure}");
    }

    private static void TrySetNativeRenderFuncCommandBufferFrameDescriptorPayload(
        ManualLogSource log,
        NativeRenderFuncResourceNativePointerObservation sourceObservation,
        NativeRenderFuncResourceNativePointerObservation destinationObservation,
        NativeRenderFuncResourceNativePointerTarget target)
    {
        if (Interlocked.CompareExchange(ref NativeRenderFuncCommandBufferFrameDescriptorSetAttemptCount, 1, 0) != 0)
        {
            return;
        }

        try
        {
            if (!HdrpEasuInputOutputCorrelationProbeState.TryGetFrameDescriptor(out var descriptor))
            {
                lock (Sync)
                {
                    NativeRenderFuncCommandBufferFrameDescriptorLastFailure = "HDRP/EASU frame descriptor was not ready";
                }

                log.LogInfo($"Native render-func command-buffer frame descriptor waiting: source=({FormatNativeRenderFuncResourceNativePointerObservation(sourceObservation)}); destination=({FormatNativeRenderFuncResourceNativePointerObservation(destinationObservation)}); targetCompile={target.CompileCount}; targetManagedPassData=0x{target.ManagedPassDataPointer:X}; tuple={target.TupleSummary}; reason=\"HDRP/EASU descriptor not ready\"");
                Interlocked.Exchange(ref NativeRenderFuncCommandBufferFrameDescriptorSetAttemptCount, 0);
                return;
            }

            var bridge = Bridge;
            if (bridge is null)
            {
                RecordNativeRenderFuncCommandBufferFrameDescriptorSetFailure("native bridge was unavailable");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorSetFailureCount);
                return;
            }

            var sequence = Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorSequence);
            var beforeConsumed = bridge.GetRenderEventFrameDescriptorPayloadConsumedCount();
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferFrameDescriptorBeforeConsumedCount, beforeConsumed);
            var success = bridge.SetRenderEventFrameDescriptorPayload(
                descriptor.SourcePointer,
                descriptor.DestinationPointer,
                descriptor.DepthPointer,
                descriptor.MotionPointer,
                descriptor.InputWidth,
                descriptor.InputHeight,
                descriptor.OutputWidth,
                descriptor.OutputHeight,
                descriptor.HdrpFrame,
                descriptor.EasuSourceFrame,
                descriptor.EasuDestinationFrame,
                NativeRenderFuncCommandBufferFrameDescriptorEventId,
                sequence);
            var status = bridge.GetRenderEventFrameDescriptorPayloadStatus();
            lock (Sync)
            {
                NativeRenderFuncCommandBufferFrameDescriptorLastStatus = status;
                NativeRenderFuncCommandBufferFrameDescriptorLastFailure = success ? null : status;
            }

            var message = $"Native render-func command-buffer frame descriptor set {(success ? "advanced" : "failed")}: source=({FormatNativeRenderFuncResourceNativePointerObservation(sourceObservation)}); destination=({FormatNativeRenderFuncResourceNativePointerObservation(destinationObservation)}); depthMotion=({descriptor.HdrpGlobalTextureSummary}); targetCompile={target.CompileCount}; targetManagedPassData=0x{target.ManagedPassDataPointer:X}; tuple={target.TupleSummary}; descriptorFrames=hdrp:{descriptor.HdrpFrame},easuSource:{descriptor.EasuSourceFrame},easuDestination:{descriptor.EasuDestinationFrame}; size=input:{descriptor.InputWidth}x{descriptor.InputHeight},output:{descriptor.OutputWidth}x{descriptor.OutputHeight}; beforeConsumed={beforeConsumed}; eventId={NativeRenderFuncCommandBufferFrameDescriptorEventId}; sequence={sequence}; status=\"{status}\"";
            if (success)
            {
                Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorSetSuccessCount);
                log.LogInfo(message);
            }
            else
            {
                Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorSetFailureCount);
                log.LogWarning(message);
            }
        }
        catch (Exception ex)
        {
            RecordNativeRenderFuncCommandBufferFrameDescriptorSetFailure(FirstLine(GetExceptionMessage(ex)));
            Interlocked.Increment(ref NativeRenderFuncCommandBufferFrameDescriptorSetFailureCount);
        }
    }

    private static void RecordNativeRenderFuncCommandBufferFrameDescriptorSetFailure(string failure)
    {
        lock (Sync)
        {
            NativeRenderFuncCommandBufferFrameDescriptorLastFailure = failure;
        }

        Log?.LogWarning($"Native render-func command-buffer frame descriptor set failed: {failure}");
    }

    private static void TrySetNativeRenderFuncCommandBufferDlssFeatureCreatePayload(
        ManualLogSource log,
        NativeRenderFuncResourceNativePointerObservation sourceObservation,
        NativeRenderFuncResourceNativePointerObservation destinationObservation,
        NativeRenderFuncResourceNativePointerTarget target)
    {
        if (Interlocked.CompareExchange(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetAttemptCount, 1, 0) != 0)
        {
            return;
        }

        try
        {
            var bridge = Bridge;
            if (bridge is null)
            {
                RecordNativeRenderFuncCommandBufferDlssFeatureCreateSetFailure("native bridge was unavailable");
                Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetFailureCount);
                return;
            }

            var sequence = Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateSequence);
            var beforeConsumed = bridge.GetRenderEventDlssFeatureCreateConsumedCount();
            Interlocked.Exchange(ref NativeRenderFuncCommandBufferDlssFeatureCreateBeforeConsumedCount, beforeConsumed);
            var success = bridge.SetRenderEventDlssFeatureCreatePayload(
                sourceObservation.Pointer,
                destinationObservation.Pointer,
                NativeRenderFuncCommandBufferDlssFeatureCreateEventId,
                sequence,
                DlssEvaluateSettings.RuntimePath ?? string.Empty,
                string.IsNullOrWhiteSpace(DlssEvaluateSettings.ApplicationDataPath) ? "." : DlssEvaluateSettings.ApplicationDataPath,
                DlssEvaluateSettings.ApplicationId,
                DlssEvaluateSettings.PerfQualityValue,
                DlssEvaluateSettings.FeatureFlags);
            var status = bridge.GetRenderEventDlssFeatureCreateStatus();
            lock (Sync)
            {
                NativeRenderFuncCommandBufferDlssFeatureCreateLastStatus = status;
                NativeRenderFuncCommandBufferDlssFeatureCreateLastFailure = success ? null : status;
            }

            var message = $"Native render-func command-buffer DLSS feature-create set {(success ? "advanced" : "failed")}: source=({FormatNativeRenderFuncResourceNativePointerObservation(sourceObservation)}); destination=({FormatNativeRenderFuncResourceNativePointerObservation(destinationObservation)}); targetCompile={target.CompileCount}; targetManagedPassData=0x{target.ManagedPassDataPointer:X}; tuple={target.TupleSummary}; beforeConsumed={beforeConsumed}; eventId={NativeRenderFuncCommandBufferDlssFeatureCreateEventId}; sequence={sequence}; perfQuality={DlssEvaluateSettings.PerfQualityValue}; flags=0x{DlssEvaluateSettings.FeatureFlags:X}; status=\"{status}\"";
            if (success)
            {
                Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetSuccessCount);
                log.LogInfo(message);
            }
            else
            {
                Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetFailureCount);
                log.LogWarning(message);
            }
        }
        catch (Exception ex)
        {
            RecordNativeRenderFuncCommandBufferDlssFeatureCreateSetFailure(FirstLine(GetExceptionMessage(ex)));
            Interlocked.Increment(ref NativeRenderFuncCommandBufferDlssFeatureCreateSetFailureCount);
        }
    }

    private static void RecordNativeRenderFuncCommandBufferDlssFeatureCreateSetFailure(string failure)
    {
        lock (Sync)
        {
            NativeRenderFuncCommandBufferDlssFeatureCreateLastFailure = failure;
        }

        Log?.LogWarning($"Native render-func command-buffer DLSS feature-create set failed: {failure}");
    }

    private static bool ShouldLogRenderGraphGetTexture(int count)
    {
        return RenderGraphGetTextureDiagnosticLoggingEnabled && (count <= MaxRenderGraphGetTextureLogs || count % 300 == 0);
    }

    private static bool ShouldFastSkipRenderGraphGetTextureForCachedTupleDriver()
    {
        if (!DlssCachedTupleDriverProbeEnabled || !DlssUserRenderingHasAcceptedTuple)
        {
            return false;
        }

        lock (Sync)
        {
            return DlssUserRenderingEnabled
                && !DlssUserRenderingBlocked
                && DlssUserRenderingAcceptedTuple.HasValue
                && !RenderGraphGetTextureDiagnosticLoggingEnabled
                && !DlssVisibleWritebackProbeEnabled
                && DlssEvaluateOutputFollowupPointer == IntPtr.Zero;
        }
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

    private static void TryRunRenderGraphDlssSuperResolutionInputProbe(
        ManualLogSource log,
        NativeBridge bridge,
        IReadOnlyList<RenderGraphTextureCandidate> candidates,
        string source)
    {
        if (!DlssSuperResolutionInputProbeEnabled)
        {
            return;
        }

        if (DlssSuperResolutionInputProbeSucceeded)
        {
            if (DlssVisibleWritebackProbeEnabled)
            {
                TryRunDlssVisibleWritebackProbe(log, bridge, source, candidates);
            }
            else if (DlssUserRenderingEnabled)
            {
                TryRunDlssUserRendering(log, bridge, source, candidates);
            }
            else
            {
                TryRunDlssSuperResolutionFrameSequenceEvaluateProbe(log, bridge, source, candidates);
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
                $"DLSS super-resolution input probe candidate #{attempt} from {source}: color={color.Value.ResourceName} 0x{color.Value.Pointer.ToInt64():X}; output={output.ResourceName} 0x{output.Pointer.ToInt64():X}; depth={depth.Value.ResourceName} 0x{depth.Value.Pointer.ToInt64():X}; motion={motion.Value.ResourceName} 0x{motion.Value.Pointer.ToInt64():X}");

            var success = bridge.ProbeDlssSuperResolutionInputs(
                color.Value.Pointer,
                output.Pointer,
                depth.Value.Pointer,
                motion.Value.Pointer);
            var status = bridge.GetDlssSuperResolutionInputStatus();
            if (success)
            {
                DlssSuperResolutionInputProbeSucceeded = true;
                log.LogInfo($"DLSS super-resolution input probe succeeded from {source}: {status}");
                TryRunDlssSuperResolutionEvaluateProbe(
                    log,
                    bridge,
                    source,
                    color.Value.Pointer,
                    output.Pointer,
                    depth.Value.Pointer,
                    motion.Value.Pointer,
                    output.ResourceName);
                TryRunDlssSuperResolutionPersistentEvaluateProbe(
                    log,
                    bridge,
                    source,
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
                        source,
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
                        source,
                        color.Value.Pointer,
                        output.Pointer,
                        depth.Value.Pointer,
                        motion.Value.Pointer,
                        output.ResourceName);
                    if (ShouldDeferDlssUserRenderingEvaluateToCachedTupleDriver())
                    {
                        LogDlssCachedTupleDriverArmed(log, source, output.ResourceName);
                        return;
                    }

                    TryRunDlssUserRendering(
                        log,
                        bridge,
                        source,
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
                        source,
                        color.Value.Pointer,
                        output.Pointer,
                        depth.Value.Pointer,
                        motion.Value.Pointer,
                        output.ResourceName);
                }
                return;
            }

            log.LogInfo($"DLSS super-resolution input probe not accepted from {source}: {status}");
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
            if (DlssCachedTupleDriverProbeEnabled && !DlssUserRenderingNoEvaluateEnabled)
            {
                log.LogInfo($"DLSS cached tuple driver armed from {source}: outputResourceName={output.ResourceName ?? "unavailable"}; evaluate deferred to DynamicResolutionHandler.Update driver.");
                return;
            }

            if (ShouldDeferDlssUserRenderingEvaluateToCachedTupleDriver())
            {
                LogDlssCachedTupleDriverArmed(log, source, output.ResourceName);
                return;
            }

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

    internal static void TryRunCachedDlssUserRenderingDriver(string source)
    {
        try
        {
            if (!DlssCachedTupleDriverProbeEnabled
                || !DlssUserRenderingEnabled
                || DlssUserRenderingBlocked
                || WasDlssUserRenderingAttemptedThisFrameOrInterval())
            {
                return;
            }

            var log = Log;
            var bridge = Bridge;
            if (log is null || bridge is null)
            {
                return;
            }

            DlssUserRenderingResourceTuple tuple;
            int useCount;
            lock (Sync)
            {
                if (!DlssUserRenderingAcceptedTuple.HasValue)
                {
                    return;
                }

                tuple = DlssUserRenderingAcceptedTuple.Value;
                DlssUserRenderingCachedTupleUseCount++;
                useCount = DlssUserRenderingCachedTupleUseCount;
            }

            if (useCount <= 3 || useCount % 300 == 0)
            {
                log.LogInfo($"DLSS cached tuple driver invoked from {source}: driverCalls={useCount}; outputResourceName={tuple.OutputResourceName ?? "unavailable"}");
            }

            TryRunDlssUserRendering(
                log,
                bridge,
                $"{source} cached tuple driver",
                tuple.ColorPointer,
                tuple.OutputPointer,
                tuple.DepthPointer,
                tuple.MotionPointer,
                tuple.OutputResourceName,
                "cached tuple driver; input probe not repeated for this frame",
                trackOutputFollowup: false);
        }
        catch (Exception ex)
        {
            Log?.LogWarning($"DLSS cached tuple driver failed from {source}: {GetExceptionMessage(ex)}");
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

            if (ShouldDeferDlssUserRenderingEvaluateToCachedTupleDriver())
            {
                return true;
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

    private static bool ShouldDeferDlssUserRenderingEvaluateToCachedTupleDriver()
    {
        return DlssCachedTupleDriverProbeEnabled && !DlssUserRenderingNoEvaluateEnabled;
    }

    private static void LogDlssCachedTupleDriverArmed(
        ManualLogSource log,
        string source,
        string? outputResourceName)
    {
        log.LogInfo($"DLSS cached tuple driver armed from {source}: outputResourceName={outputResourceName ?? "unavailable"}; evaluate deferred to DynamicResolutionHandler.Update driver.");
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

            DlssUserRenderingHasAcceptedTuple = true;
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
        string? noEvaluateStatusOverride = null,
        bool trackOutputFollowup = true)
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

            if (trackOutputFollowup)
            {
                TrackDlssEvaluateOutputFollowup(outputPointer, outputResourceName);
            }
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

    private static object? FindRenderGraphPassArgument(object?[]? args)
    {
        var pass = FindTypedArgument(args, "RenderGraphPass");
        if (pass is not null)
        {
            return pass;
        }

        var passInfo = FindTypedArgument(args, "CompiledPassInfo")
            ?? (args is { Length: > 0 } ? args[0] : null);
        if (passInfo is null)
        {
            return null;
        }

        return TryReadPropertyObject(passInfo, "pass")
            ?? TryReadFieldObject(passInfo, "pass");
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

        if (TypeNameContains(sequence.GetType(), "DynamicArray")
            && TryReadInt(sequence, "size", out var dynamicArraySize))
        {
            var backingArray = TryReadPropertyObject(sequence, "m_Array")
                ?? TryReadFieldObject(sequence, "m_Array");
            if (backingArray is IEnumerable dynamicArrayEnumerable)
            {
                var emitted = 0;
                foreach (var item in dynamicArrayEnumerable)
                {
                    if (emitted >= dynamicArraySize)
                    {
                        yield break;
                    }

                    emitted++;
                    if (item is not null)
                    {
                        yield return item;
                    }
                }

                yield break;
            }
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
        var raw = TryReadPropertyObject(instance, propertyName)
            ?? TryReadFieldObject(instance, propertyName)
            ?? TryReadFieldObject(instance, $"_{propertyName}_k__BackingField")
            ?? TryReadFieldObject(instance, $"<{propertyName}>k__BackingField");
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

    private static string SummarizeRenderGraphRenderFunc(object renderFunc)
    {
        var parts = new List<string>
        {
            renderFunc.GetType().FullName ?? renderFunc.GetType().Name
        };

        foreach (var memberName in new[]
        {
            "method_ptr",
            "invoke_impl",
            "method",
            "delegate_trampoline",
            "extra_arg",
            "method_code",
            "interp_method",
            "interp_invoke_impl"
        })
        {
            AddRenderFuncPointerSummary(parts, memberName, renderFunc);
        }

        foreach (var memberName in new[]
        {
            "Method",
            "Target",
            "method_info",
            "original_method_info",
            "m_target",
            "data",
            "delegates"
        })
        {
            AddRenderFuncObjectSummary(parts, memberName, renderFunc);
        }

        return string.Join(" ", parts);
    }

    private static void AddRenderFuncPointerSummary(ICollection<string> parts, string memberName, object renderFunc)
    {
        var value = TryReadPropertyObject(renderFunc, memberName)
            ?? TryReadFieldObject(renderFunc, memberName);
        if (value is null)
        {
            return;
        }

        if (value is IntPtr pointer)
        {
            parts.Add($"{memberName}=0x{pointer.ToInt64():X}");
            return;
        }

        if (value is UIntPtr unsignedPointer)
        {
            parts.Add($"{memberName}=0x{unsignedPointer.ToUInt64():X}");
            return;
        }

        parts.Add($"{memberName}={FirstLine(SummarizeValue(value))}");
    }

    private static void AddRenderFuncObjectSummary(ICollection<string> parts, string memberName, object renderFunc)
    {
        var value = TryReadPropertyObject(renderFunc, memberName)
            ?? TryReadFieldObject(renderFunc, memberName);
        if (value is null)
        {
            return;
        }

        var summary = memberName.IndexOf("method", StringComparison.OrdinalIgnoreCase) >= 0
            ? SummarizeRenderFuncMethodInfo(value)
            : FirstLine(SummarizeValue(value));
        parts.Add($"{memberName}={summary}");
    }

    private static string SummarizeRenderFuncMethodInfo(object methodInfo)
    {
        var parts = new List<string>
        {
            FirstLine(SummarizeValue(methodInfo))
        };

        foreach (var propertyName in new[] { "Name", "DeclaringType", "ReflectedType", "MetadataToken" })
        {
            var value = TryReadPropertyObject(methodInfo, propertyName);
            if (value is null)
            {
                continue;
            }

            parts.Add($"{propertyName}={FirstLine(SummarizeValue(value))}");
        }

        return string.Join(",", parts);
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
        if (IsTerminalValue(value))
        {
            var formattedValue = value is IFormattable formattable
                ? formattable.ToString(null, CultureInfo.InvariantCulture)
                : value.ToString();
            return $"{type.FullName ?? type.Name}={FirstLine(formattedValue ?? string.Empty)}";
        }

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

    private static object? TryReadMemberObject(object instance, string memberName)
    {
        return TryReadPropertyObject(instance, memberName)
            ?? TryReadFieldObject(instance, memberName);
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

    private readonly record struct RenderGraphPassResourceDeclaration(string Label, string Kind, string Summary);

    private readonly record struct RenderGraphPassDataSnapshotMember(string Label, string Kind, string Summary);

    private readonly record struct NativeRenderFuncResourceTupleSummary(
        int InputWidth,
        int InputHeight,
        int OutputWidth,
        int OutputHeight,
        string Source,
        string Destination);

    private readonly record struct NativeRenderFuncResourceResolveSummary(
        string Label,
        string Handle,
        bool TextureResourceReady,
        bool GraphicsResourceReady,
        string Details)
    {
        internal static NativeRenderFuncResourceResolveSummary NotReady(string label, string details)
        {
            return new NativeRenderFuncResourceResolveSummary(label, "unavailable", false, false, details);
        }
    }

    private readonly record struct NativeRenderFuncResourceNativePointerTarget(
        int CompileCount,
        long ManagedPassDataPointer,
        string SourceResourceHandle,
        string DestinationResourceHandle,
        string TupleSummary);

    private readonly record struct NativeRenderFuncResourceNativePointerObservation(
        string Label,
        string ResourceHandle,
        IntPtr Pointer,
        string NativeOwnerSummary,
        string ResultSummary,
        int FrameCount);

    private readonly record struct RenderGraphRegistryCandidate(string Label, object Instance);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void NativeRenderFuncEntryDelegate(
        IntPtr thisPtr,
        IntPtr passDataPtr,
        IntPtr renderGraphContextPtr,
        IntPtr methodInfoPtr);

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
