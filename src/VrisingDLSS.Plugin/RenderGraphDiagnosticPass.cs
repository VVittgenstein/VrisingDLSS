#if VRISINGDLSS_LOCAL_INTEROP
using BepInEx.Logging;
using Il2CppInterop.Runtime.Injection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using UnityEngine.Experimental.Rendering.RenderGraphModule;
using UnityEngine.Rendering;

namespace VrisingDLSS.Plugin;

internal static class RenderGraphDiagnosticPass
{
    private const int MaxInjectAttempts = 12;
    private const int MaxRenderFuncAttempts = 12;
    private static readonly object Sync = new();
    private static readonly List<object> DelegateRoots = new();
    private static readonly Dictionary<int, ObservedGraphHandles> ObservedGraphs = new();
    private static readonly HashSet<int> InjectedGraphKeys = new();
    private static int InjectAttempts;
    private static int RenderFuncAttempts;
    private static bool Succeeded;
    private static bool PassDataRegistered;

    internal static bool TryInject(
        ManualLogSource log,
        NativeBridge bridge,
        MethodBase originalMethod,
        object?[]? args)
    {
        if (Succeeded || args is null)
        {
            return false;
        }

        var renderGraph = args.OfType<RenderGraph>().FirstOrDefault();
        if (renderGraph is null)
        {
            return false;
        }

        var handles = CollectTextureHandleArguments(originalMethod, args);
        var color = FindHandle(handles, static name =>
            name.Equals("source", StringComparison.OrdinalIgnoreCase)
            || name.IndexOf("color", StringComparison.OrdinalIgnoreCase) >= 0);
        var depth = FindHandle(handles, static name =>
            name.IndexOf("depth", StringComparison.OrdinalIgnoreCase) >= 0);
        var motion = FindHandle(handles, static name =>
            name.IndexOf("motion", StringComparison.OrdinalIgnoreCase) >= 0);
        if (!color.HasValue || !depth.HasValue || !motion.HasValue)
        {
            return false;
        }

        return TryInjectPass(log, bridge, renderGraph, color.Value, depth.Value, motion.Value, HookTargetCatalog.FormatMethod(originalMethod));
    }

    internal static bool ObserveBuilderDeclaration(
        ManualLogSource log,
        NativeBridge bridge,
        object? builderObject,
        object? textureHandleObject,
        string? resourceName)
    {
        if (Succeeded
            || builderObject is not RenderGraphBuilder builder
            || textureHandleObject is not TextureHandle textureHandle
            || string.IsNullOrWhiteSpace(resourceName))
        {
            return false;
        }

        var renderGraph = builder.m_RenderGraph;
        if (renderGraph is null)
        {
            return false;
        }

        var graphKey = renderGraph.GetHashCode();
        ObservedGraphHandles observed;
        lock (Sync)
        {
            ObservedGraphs.TryGetValue(graphKey, out observed);
            if (string.Equals(resourceName, "CameraColor", StringComparison.Ordinal))
            {
                observed.Color = new NamedTextureHandle(resourceName, textureHandle);
            }
            else if (string.Equals(resourceName, "CameraDepthStencil", StringComparison.Ordinal))
            {
                observed.Depth = new NamedTextureHandle(resourceName, textureHandle);
            }
            else if (string.Equals(resourceName, "Motion Vectors", StringComparison.Ordinal))
            {
                observed.Motion = new NamedTextureHandle(resourceName, textureHandle);
            }

            ObservedGraphs[graphKey] = observed;
            if (!observed.Color.HasValue || !observed.Depth.HasValue || !observed.Motion.HasValue)
            {
                return false;
            }

            if (!InjectedGraphKeys.Add(graphKey))
            {
                return false;
            }
        }

        return TryInjectPass(log, bridge, renderGraph, observed.Color.Value, observed.Depth.Value, observed.Motion.Value, "RenderGraphBuilder declared resources");
    }

    private static bool TryInjectPass(
        ManualLogSource log,
        NativeBridge bridge,
        RenderGraph renderGraph,
        NamedTextureHandle color,
        NamedTextureHandle depth,
        NamedTextureHandle motion,
        string sourceLabel)
    {
        int attempt;
        lock (Sync)
        {
            if (InjectAttempts >= MaxInjectAttempts)
            {
                return false;
            }

            InjectAttempts++;
            attempt = InjectAttempts;
        }

        try
        {
            EnsurePassDataRegistered();

            var declaredColor = color.Handle;
            var declaredOutput = color.Handle;
            var declaredDepth = depth.Handle;
            var declaredMotion = motion.Handle;
            DiagnosticPassData passData = null!;
            var builder = renderGraph.AddRenderPass("VrisingDLSS DLSS input diagnostic", out passData);
            try
            {
                builder.AllowPassCulling(false);
                declaredColor = builder.ReadTexture(ref declaredColor);
                declaredOutput = builder.ReadWriteTexture(ref declaredOutput);
                declaredDepth = builder.ReadTexture(ref declaredDepth);
                declaredMotion = builder.ReadTexture(ref declaredMotion);

                Action<DiagnosticPassData, RenderGraphContext> action = (_, _) =>
                    RunRenderFunc(log, bridge, sourceLabel, declaredColor, declaredOutput, declaredDepth, declaredMotion);
                RenderFunc<DiagnosticPassData> renderFunc = action;
                lock (Sync)
                {
                    DelegateRoots.Add(action);
                    DelegateRoots.Add(renderFunc);
                }

                builder.SetRenderFunc(renderFunc);
                var pass = builder.m_RenderPass;
                log.LogInfo(
                    $"RenderGraph diagnostic pass configured #{attempt}: pass={pass?.name ?? "unknown"}; hasRenderFunc={pass?.HasRenderFunc()}; allowPassCulling={pass?.allowPassCulling}");
            }
            finally
            {
                builder.Dispose();
            }

            log.LogInfo($"RenderGraph diagnostic pass injected #{attempt}: source={sourceLabel}; color={color.Label}; depth={depth.Label}; motion={motion.Label}");
            return true;
        }
        catch (Exception ex)
        {
            log.LogWarning($"RenderGraph diagnostic pass injection failed #{attempt}: source={sourceLabel}; {FirstLine(GetExceptionMessage(ex))}");
            return false;
        }
    }

    private static void RunRenderFunc(
        ManualLogSource log,
        NativeBridge bridge,
        string sourceMethod,
        TextureHandle colorHandle,
        TextureHandle outputHandle,
        TextureHandle depthHandle,
        TextureHandle motionHandle)
    {
        if (Succeeded)
        {
            return;
        }

        int attempt;
        lock (Sync)
        {
            if (RenderFuncAttempts >= MaxRenderFuncAttempts)
            {
                return;
            }

            RenderFuncAttempts++;
            attempt = RenderFuncAttempts;
        }

        try
        {
            var registry = RenderGraphResourceRegistry.current;
            if (registry is null)
            {
                log.LogWarning($"RenderGraph diagnostic pass render #{attempt} blocked: registry.current was null.");
                return;
            }

            var colorReady = TryGetNativeTexturePointer(registry, ref colorHandle, out var colorPointer, out var colorStatus);
            var outputReady = TryGetNativeTexturePointer(registry, ref outputHandle, out var outputPointer, out var outputStatus);
            var depthReady = TryGetNativeTexturePointer(registry, ref depthHandle, out var depthPointer, out var depthStatus);
            var motionReady = TryGetNativeTexturePointer(registry, ref motionHandle, out var motionPointer, out var motionStatus);
            if (!colorReady || !outputReady || !depthReady || !motionReady)
            {
                log.LogWarning(
                    $"RenderGraph diagnostic pass render #{attempt} blocked: color={colorStatus}; output={outputStatus}; depth={depthStatus}; motion={motionStatus}");
                return;
            }

            log.LogInfo(
                $"DLSS evaluate input probe RenderGraph diagnostic pass candidate #{attempt}: source={sourceMethod}; color=0x{colorPointer.ToInt64():X}; output=0x{outputPointer.ToInt64():X}; depth=0x{depthPointer.ToInt64():X}; motion=0x{motionPointer.ToInt64():X}");
            var success = bridge.ProbeDlssEvaluateInputs(colorPointer, outputPointer, depthPointer, motionPointer);
            var status = bridge.GetDlssEvaluateInputStatus();
            if (success)
            {
                Succeeded = true;
                FrameResourceProbe.MarkDlssEvaluateInputProbeSucceeded();
                log.LogInfo($"DLSS evaluate input probe succeeded from RenderGraph diagnostic pass: {status}");
            }
            else
            {
                log.LogWarning($"DLSS evaluate input probe failed from RenderGraph diagnostic pass: {status}");
            }
        }
        catch (Exception ex)
        {
            log.LogWarning($"RenderGraph diagnostic pass render #{attempt} failed: {FirstLine(GetExceptionMessage(ex))}");
        }
    }

    private static IReadOnlyList<NamedTextureHandle> CollectTextureHandleArguments(MethodBase originalMethod, object?[] args)
    {
        var parameters = originalMethod.GetParameters();
        var handles = new List<NamedTextureHandle>();
        for (var index = 0; index < args.Length; index++)
        {
            var name = index < parameters.Length && !string.IsNullOrWhiteSpace(parameters[index].Name)
                ? parameters[index].Name!
                : $"arg{index}";
            if (args[index] is TextureHandle handle)
            {
                handles.Add(new NamedTextureHandle(name, handle));
                continue;
            }

            CollectNestedTextureHandles(name, args[index], handles);
        }

        return handles;
    }

    private static void CollectNestedTextureHandles(string prefix, object? value, ICollection<NamedTextureHandle> handles)
    {
        if (value is null)
        {
            return;
        }

        var type = value.GetType();
        foreach (var property in type.GetProperties(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            if (property.GetIndexParameters().Length != 0
                || property.GetMethod is null
                || property.PropertyType != typeof(TextureHandle))
            {
                continue;
            }

            try
            {
                if (property.GetValue(value) is TextureHandle handle)
                {
                    handles.Add(new NamedTextureHandle($"{prefix}.{property.Name}", handle));
                }
            }
            catch
            {
                // Ignore properties whose generated IL2CPP accessor is not safe in this context.
            }
        }

        foreach (var field in type.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            if (field.FieldType != typeof(TextureHandle))
            {
                continue;
            }

            try
            {
                if (field.GetValue(value) is TextureHandle handle)
                {
                    handles.Add(new NamedTextureHandle($"{prefix}.{field.Name}", handle));
                }
            }
            catch
            {
                // Ignore fields whose generated IL2CPP accessor is not safe in this context.
            }
        }
    }

    private static NamedTextureHandle? FindHandle(IReadOnlyList<NamedTextureHandle> handles, Func<string, bool> predicate)
    {
        foreach (var handle in handles)
        {
            if (predicate(handle.Label))
            {
                return handle;
            }
        }

        return null;
    }

    private static bool TryGetNativeTexturePointer(
        RenderGraphResourceRegistry registry,
        ref TextureHandle handle,
        out IntPtr pointer,
        out string status)
    {
        pointer = IntPtr.Zero;
        try
        {
            var rtHandle = registry.GetTexture(ref handle);
            if (rtHandle is null)
            {
                status = "GetTexture returned null";
                return false;
            }

            var renderTexture = rtHandle.rt;
            if (renderTexture is null)
            {
                status = $"GetTexture returned {rtHandle.name}; rt=null";
                return false;
            }

            pointer = renderTexture.GetNativeTexturePtr();
            status = $"{rtHandle.name} {renderTexture.width}x{renderTexture.height} ptr=0x{pointer.ToInt64():X}";
            return pointer != IntPtr.Zero;
        }
        catch (Exception ex)
        {
            status = $"GetTexture threw {FirstLine(GetExceptionMessage(ex))}";
            return false;
        }
    }

    private static void EnsurePassDataRegistered()
    {
        if (PassDataRegistered)
        {
            return;
        }

        lock (Sync)
        {
            if (PassDataRegistered)
            {
                return;
            }

            if (!ClassInjector.IsTypeRegisteredInIl2Cpp<DiagnosticPassData>())
            {
                ClassInjector.RegisterTypeInIl2Cpp<DiagnosticPassData>();
            }

            PassDataRegistered = true;
        }
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

    private readonly record struct NamedTextureHandle(string Label, TextureHandle Handle);

    private struct ObservedGraphHandles
    {
        internal NamedTextureHandle? Color;
        internal NamedTextureHandle? Depth;
        internal NamedTextureHandle? Motion;
    }

    private sealed class DiagnosticPassData : Il2CppSystem.Object
    {
        public DiagnosticPassData(IntPtr pointer)
            : base(pointer)
        {
        }

        public DiagnosticPassData()
            : base(ClassInjector.DerivedConstructorPointer<DiagnosticPassData>())
        {
            ClassInjector.DerivedConstructorBody(this);
        }
    }
}
#endif
