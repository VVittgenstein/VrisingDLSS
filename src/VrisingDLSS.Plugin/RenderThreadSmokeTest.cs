using BepInEx.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class RenderThreadSmokeTest
{
    private const string HarmonyId = PluginInfo.Guid + ".render-thread-smoke-test";
    private const int SmokeEventId = 240604;
    private const int MaxBeforeRenderAttempts = 120;
    private const int MaxRenderHookCalls = 120;
    private static readonly RenderHookTarget[] RenderHookTargets =
    {
        new("UnityEngine.Rendering.HighDefinition.CustomVignette", "Render"),
        new("UnityEngine.Rendering.HighDefinition.HDRenderPipeline", "UpdateShaderVariablesGlobalCB")
    };
    private static ScheduledRenderEvent? _scheduledRenderEvent;
    private static readonly object Sync = new();
    private static ManualLogSource? HookLog;
    private static NativeBridge? HookBridge;
    private static IntPtr HookCallback;
    private static object? HarmonyInstance;
    private static Type? HarmonyType;
    private static bool RenderHookInstalled;
    private static bool RenderHookCompleted;
    private static int RenderHookBeforeCount;
    private static int RenderHookCallCount;
    private static bool RenderHookIssuedEvent;

    internal static void Run(ManualLogSource log, NativeBridge bridge)
    {
        log.LogInfo("Running native render-thread smoke test.");

        var callback = bridge.GetRenderEventFunc();
        if (callback == IntPtr.Zero)
        {
            log.LogWarning("Native bridge render event callback export was not found.");
            return;
        }

        if (TryScheduleBeforeRenderEvent(log, bridge, callback))
        {
            return;
        }

        if (InstallRenderHookFallback(log, bridge, callback))
        {
            return;
        }

        log.LogWarning("Unity Application.onBeforeRender or GL.IssuePluginEvent was not found. Falling back to immediate CommandBuffer execution.");
        RunCommandBufferFallback(log, bridge, callback);
    }

    internal static void Uninstall(ManualLogSource log)
    {
        _scheduledRenderEvent?.Detach();
        _scheduledRenderEvent = null;
        UninstallRenderHook(log);
    }

    private static bool TryScheduleBeforeRenderEvent(ManualLogSource log, NativeBridge bridge, IntPtr callback)
    {
        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var applicationType = HookTargetCatalog.FindType(assemblies, "UnityEngine.Application");
        var glType = HookTargetCatalog.FindType(assemblies, "UnityEngine.GL");
        if (applicationType is null || glType is null)
        {
            return false;
        }

        var beforeRenderEvent = applicationType.GetEvent(
            "onBeforeRender",
            BindingFlags.Public | BindingFlags.Static);
        var issuePluginEvent = FindStaticIssuePluginEventMethod(glType);
        if (beforeRenderEvent?.EventHandlerType is null || issuePluginEvent is null)
        {
            return false;
        }

        try
        {
            _scheduledRenderEvent?.Detach();

            var beforeCount = bridge.GetRenderEventCount();
            var beforeStatus = bridge.GetRenderEventStatus();
            log.LogInfo($"Render-thread smoke status before scheduling: count={beforeCount}; status={beforeStatus}");

            var scheduledEvent = new ScheduledRenderEvent(
                log,
                bridge,
                callback,
                beforeRenderEvent,
                issuePluginEvent,
                beforeCount);

            scheduledEvent.Attach();
            _scheduledRenderEvent = scheduledEvent;
            log.LogInfo("Render-thread smoke test scheduled on UnityEngine.Application.onBeforeRender.");
            return true;
        }
        catch (Exception ex)
        {
            log.LogWarning($"Could not schedule render-thread smoke test on Application.onBeforeRender: {GetExceptionMessage(ex)}");
            return false;
        }
    }

    private static bool InstallRenderHookFallback(ManualLogSource log, NativeBridge bridge, IntPtr callback)
    {
        if (RenderHookInstalled)
        {
            log.LogInfo("Render-thread smoke hook is already installed.");
            return true;
        }

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var harmonyType = FindRuntimeType(assemblies, "HarmonyLib.Harmony");
        var harmonyMethodType = FindRuntimeType(assemblies, "HarmonyLib.HarmonyMethod");
        if (harmonyType is null || harmonyMethodType is null)
        {
            return false;
        }

        var harmonyConstructor = harmonyType.GetConstructor(new[] { typeof(string) });
        var harmonyMethodConstructor = harmonyMethodType.GetConstructor(new[] { typeof(MethodInfo) });
        var prefix = typeof(RenderThreadSmokeTest).GetMethod(nameof(RenderHookPrefix), BindingFlags.NonPublic | BindingFlags.Static);
        var patchMethod = FindPatchMethod(harmonyType);
        if (harmonyConstructor is null || harmonyMethodConstructor is null || prefix is null || patchMethod is null)
        {
            log.LogWarning("Harmony runtime shape was not recognized. Render-thread hook smoke test cannot be installed.");
            return false;
        }

        HookLog = log;
        HookBridge = bridge;
        HookCallback = callback;
        RenderHookBeforeCount = bridge.GetRenderEventCount();
        RenderHookCallCount = 0;
        RenderHookIssuedEvent = false;
        RenderHookCompleted = false;
        log.LogInfo($"Render-thread smoke status before render-hook scheduling: count={RenderHookBeforeCount}; status={bridge.GetRenderEventStatus()}");

        HarmonyInstance = harmonyConstructor.Invoke(new object[] { HarmonyId });
        HarmonyType = harmonyType;

        var patched = 0;
        foreach (var target in RenderHookTargets)
        {
            var targetType = HookTargetCatalog.FindType(assemblies, target.TypeName);
            if (targetType is null)
            {
                log.LogWarning($"Render-thread smoke hook target type not found: {target.TypeName}");
                continue;
            }

            foreach (var method in HookTargetCatalog.FindMethods(targetType, target.MemberName))
            {
                if (!CanPatch(method) || !HasCommandBufferParameter(method))
                {
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
                    log.LogInfo($"Render-thread smoke hook patched: {HookTargetCatalog.FormatMethod(method)}");
                }
                catch (Exception ex)
                {
                    log.LogWarning($"Render-thread smoke hook failed to patch {HookTargetCatalog.FormatMethod(method)}: {GetExceptionMessage(ex)}");
                }
            }
        }

        RenderHookInstalled = patched > 0;
        log.LogInfo($"Render-thread smoke hook patched {patched} method(s).");
        return RenderHookInstalled;
    }

    private static void RunCommandBufferFallback(ManualLogSource log, NativeBridge bridge, IntPtr callback)
    {
        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var commandBufferType = HookTargetCatalog.FindType(assemblies, "UnityEngine.Rendering.CommandBuffer");
        var graphicsType = HookTargetCatalog.FindType(assemblies, "UnityEngine.Graphics");
        if (commandBufferType is null || graphicsType is null)
        {
            log.LogWarning("Unity CommandBuffer or Graphics type was not found. Render-thread smoke test cannot run.");
            return;
        }

        object? commandBuffer = null;
        try
        {
            commandBuffer = Activator.CreateInstance(commandBufferType);
            if (commandBuffer is null)
            {
                log.LogWarning("Could not create UnityEngine.Rendering.CommandBuffer.");
                return;
            }

            TrySetCommandBufferName(commandBuffer, "VrisingDLSS render-thread smoke test");

            var issuePluginEvent = FindIssuePluginEventMethod(commandBufferType);
            var executeCommandBuffer = FindExecuteCommandBufferMethod(graphicsType, commandBufferType);
            if (issuePluginEvent is null || executeCommandBuffer is null)
            {
                log.LogWarning("Unity CommandBuffer.IssuePluginEvent or Graphics.ExecuteCommandBuffer method was not found.");
                return;
            }

            var beforeCount = bridge.GetRenderEventCount();
            var beforeStatus = bridge.GetRenderEventStatus();
            log.LogInfo($"Render-thread smoke status before issue: count={beforeCount}; status={beforeStatus}");

            issuePluginEvent.Invoke(commandBuffer, new object[] { callback, SmokeEventId });
            executeCommandBuffer.Invoke(null, new[] { commandBuffer });

            var afterCount = bridge.GetRenderEventCount();
            var afterStatus = bridge.GetRenderEventStatus();
            log.LogInfo($"Render-thread smoke status after issue: count={afterCount}; status={afterStatus}");

            if (afterCount > beforeCount && bridge.GetLastRenderEventId() == SmokeEventId)
            {
                log.LogInfo("Native render-thread smoke test event reached the native callback.");
            }
            else
            {
                log.LogWarning("Native render-thread smoke test was issued, but the native callback count did not advance immediately.");
            }
        }
        catch (Exception ex)
        {
            log.LogWarning($"Native render-thread smoke test failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            TryReleaseCommandBuffer(commandBuffer);
        }
    }

    private static MethodInfo? FindStaticIssuePluginEventMethod(Type glType)
    {
        return glType
            .GetMethods(BindingFlags.Public | BindingFlags.Static)
            .FirstOrDefault(method =>
            {
                if (method.Name != "IssuePluginEvent")
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 2
                    && parameters[0].ParameterType == typeof(IntPtr)
                    && parameters[1].ParameterType == typeof(int);
            });
    }

    private static void RenderHookPrefix(MethodBase __originalMethod, object? __instance, object?[]? __args)
    {
        try
        {
            var log = HookLog;
            var bridge = HookBridge;
            if (log is null || bridge is null || RenderHookCompleted)
            {
                return;
            }

            var callCount = System.Threading.Interlocked.Increment(ref RenderHookCallCount);
            var currentCount = bridge.GetRenderEventCount();
            var currentStatus = bridge.GetRenderEventStatus();
            if (currentCount > RenderHookBeforeCount && bridge.GetLastRenderEventId() == SmokeEventId)
            {
                log.LogInfo($"Render-thread smoke status after render hook callback: count={currentCount}; status={currentStatus}");
                log.LogInfo("Native render-thread smoke test event reached the native callback.");
                RenderHookCompleted = true;
                return;
            }

            if (callCount > MaxRenderHookCalls)
            {
                log.LogWarning($"Native render-thread smoke test callback did not advance within {MaxRenderHookCalls} CustomVignette.Render calls. Last status: {currentStatus}");
                RenderHookCompleted = true;
                return;
            }

            var commandBuffer = FindCommandBufferArg(__args);
            if (commandBuffer is null)
            {
                if (callCount == 1)
                {
                    log.LogWarning("Render-thread smoke hook did not receive a CommandBuffer argument.");
                }

                return;
            }

            var issuePluginEvent = FindIssuePluginEventMethod(commandBuffer.GetType());
            if (issuePluginEvent is null)
            {
                if (callCount == 1)
                {
                    log.LogWarning($"Render-thread smoke hook CommandBuffer type has no IssuePluginEvent(IntPtr, int): {commandBuffer.GetType().FullName}");
                }

                return;
            }

            issuePluginEvent.Invoke(commandBuffer, new object[] { HookCallback, SmokeEventId });
            lock (Sync)
            {
                if (!RenderHookIssuedEvent)
                {
                    RenderHookIssuedEvent = true;
                    log.LogInfo($"Render-thread smoke test issued CommandBuffer.IssuePluginEvent from {HookTargetCatalog.FormatMethod(__originalMethod)}.");
                }
            }
        }
        catch (Exception ex)
        {
            HookLog?.LogWarning($"Native render-thread smoke test failed: {GetExceptionMessage(ex)}");
            RenderHookCompleted = true;
        }
    }

    private static object? FindCommandBufferArg(object?[]? args)
    {
        if (args is null)
        {
            return null;
        }

        foreach (var arg in args)
        {
            if (arg is null)
            {
                continue;
            }

            var typeName = arg.GetType().FullName ?? arg.GetType().Name;
            if (typeName.IndexOf("CommandBuffer", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return arg;
            }
        }

        return null;
    }

    private static MethodInfo? FindIssuePluginEventMethod(Type commandBufferType)
    {
        return commandBufferType
            .GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .FirstOrDefault(method =>
            {
                if (method.Name != "IssuePluginEvent")
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 2
                    && parameters[0].ParameterType == typeof(IntPtr)
                    && parameters[1].ParameterType == typeof(int);
            });
    }

    private static MethodInfo? FindExecuteCommandBufferMethod(Type graphicsType, Type commandBufferType)
    {
        return graphicsType
            .GetMethods(BindingFlags.Public | BindingFlags.Static)
            .FirstOrDefault(method =>
            {
                if (method.Name != "ExecuteCommandBuffer")
                {
                    return false;
                }

                var parameters = method.GetParameters();
                return parameters.Length == 1
                    && parameters[0].ParameterType.IsAssignableFrom(commandBufferType);
            });
    }

    private static void TrySetCommandBufferName(object commandBuffer, string name)
    {
        try
        {
            var property = commandBuffer.GetType().GetProperty(
                "name",
                BindingFlags.Public | BindingFlags.Instance);

            if (property?.SetMethod is not null)
            {
                property.SetValue(commandBuffer, name);
            }
        }
        catch
        {
        }
    }

    private static void TryReleaseCommandBuffer(object? commandBuffer)
    {
        if (commandBuffer is null)
        {
            return;
        }

        try
        {
            var release = commandBuffer.GetType().GetMethod(
                "Release",
                BindingFlags.Public | BindingFlags.Instance,
                null,
                Type.EmptyTypes,
                null);

            release?.Invoke(commandBuffer, Array.Empty<object>());
        }
        catch
        {
        }
    }

    private static void UninstallRenderHook(ManualLogSource log)
    {
        if (!RenderHookInstalled || HarmonyInstance is null || HarmonyType is null)
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

            log.LogInfo("Render-thread smoke hook uninstalled.");
        }
        catch (Exception ex)
        {
            log.LogWarning($"Render-thread smoke hook uninstall failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            HookLog = null;
            HookBridge = null;
            HookCallback = IntPtr.Zero;
            HarmonyInstance = null;
            HarmonyType = null;
            RenderHookInstalled = false;
            RenderHookCompleted = false;
            RenderHookBeforeCount = 0;
            RenderHookCallCount = 0;
            RenderHookIssuedEvent = false;
        }
    }

    private static bool CanPatch(MethodInfo method)
    {
        return !method.ContainsGenericParameters
            && !method.IsAbstract
            && method.DeclaringType is not null;
    }

    private static bool HasCommandBufferParameter(MethodInfo method)
    {
        return method.GetParameters().Any(parameter =>
        {
            var typeName = parameter.ParameterType.FullName ?? parameter.ParameterType.Name;
            return typeName.IndexOf("CommandBuffer", StringComparison.OrdinalIgnoreCase) >= 0;
        });
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

    private sealed class ScheduledRenderEvent
    {
        private readonly ManualLogSource _log;
        private readonly NativeBridge _bridge;
        private readonly IntPtr _callback;
        private readonly EventInfo _beforeRenderEvent;
        private readonly MethodInfo _issuePluginEvent;
        private readonly int _beforeCount;
        private readonly Delegate _handler;
        private int _attempts;
        private bool _detached;

        internal ScheduledRenderEvent(
            ManualLogSource log,
            NativeBridge bridge,
            IntPtr callback,
            EventInfo beforeRenderEvent,
            MethodInfo issuePluginEvent,
            int beforeCount)
        {
            _log = log;
            _bridge = bridge;
            _callback = callback;
            _beforeRenderEvent = beforeRenderEvent;
            _issuePluginEvent = issuePluginEvent;
            _beforeCount = beforeCount;

            var handlerMethod = GetType().GetMethod(
                nameof(OnBeforeRender),
                BindingFlags.Instance | BindingFlags.NonPublic);
            _handler = Delegate.CreateDelegate(beforeRenderEvent.EventHandlerType!, this, handlerMethod!);
        }

        internal void Attach()
        {
            _beforeRenderEvent.AddEventHandler(null, _handler);
        }

        internal void Detach()
        {
            if (_detached)
            {
                return;
            }

            _detached = true;
            try
            {
                _beforeRenderEvent.RemoveEventHandler(null, _handler);
            }
            catch
            {
            }
        }

        private void OnBeforeRender()
        {
            if (_detached)
            {
                return;
            }

            try
            {
                var currentCount = _bridge.GetRenderEventCount();
                var currentStatus = _bridge.GetRenderEventStatus();
                if (currentCount > _beforeCount && _bridge.GetLastRenderEventId() == SmokeEventId)
                {
                    _log.LogInfo($"Render-thread smoke status after callback: count={currentCount}; status={currentStatus}");
                    _log.LogInfo("Native render-thread smoke test event reached the native callback.");
                    Detach();
                    _scheduledRenderEvent = null;
                    return;
                }

                _attempts++;
                if (_attempts > MaxBeforeRenderAttempts)
                {
                    _log.LogWarning($"Native render-thread smoke test callback did not advance within {MaxBeforeRenderAttempts} onBeforeRender callbacks. Last status: {currentStatus}");
                    Detach();
                    _scheduledRenderEvent = null;
                    return;
                }

                _issuePluginEvent.Invoke(null, new object[] { _callback, SmokeEventId });
                if (_attempts == 1)
                {
                    _log.LogInfo("Render-thread smoke test issued UnityEngine.GL.IssuePluginEvent from onBeforeRender.");
                }
            }
            catch (Exception ex)
            {
                _log.LogWarning($"Native render-thread smoke test failed: {GetExceptionMessage(ex)}");
                Detach();
                _scheduledRenderEvent = null;
            }
        }
    }

    private readonly record struct RenderHookTarget(string TypeName, string MemberName);
}
