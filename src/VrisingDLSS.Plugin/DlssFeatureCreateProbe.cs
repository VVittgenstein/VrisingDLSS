using BepInEx.Logging;
using System;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class DlssFeatureCreateProbe
{
    private const int ProbeSize = 64;
    private const int TargetWidth = 1920;
    private const int TargetHeight = 1080;
    private const int DlssFeatureFlagAutoExposure = 1 << 6;

    internal static void Run(
        ManualLogSource log,
        NativeBridge bridge,
        string runtimePath,
        string applicationDataPath,
        ulong applicationId,
        string qualityMode)
    {
        log.LogInfo("Running DLSS feature create/release probe.");

        var assemblies = AppDomain.CurrentDomain.GetAssemblies();
        var renderTextureType = HookTargetCatalog.FindType(assemblies, "UnityEngine.RenderTexture");
        if (renderTextureType is null)
        {
            log.LogWarning("UnityEngine.RenderTexture type was not found. DLSS feature create probe cannot run.");
            return;
        }

        var mode = ResolveMode(qualityMode);
        object? renderTexture = null;
        try
        {
            renderTexture = CreateRenderTexture(renderTextureType);
            if (renderTexture is null)
            {
                log.LogWarning("Could not create a temporary UnityEngine.RenderTexture for DLSS feature create probing.");
                return;
            }

            TrySetName(renderTexture, "VrisingDLSS DLSS feature create probe");

            if (!InvokeBool(renderTexture, "Create"))
            {
                log.LogWarning("Temporary RenderTexture.Create() returned false.");
                return;
            }

            var nativeTexturePtr = GetNativeTexturePtr(renderTexture);
            log.LogInfo($"DLSS feature create temporary RenderTexture native pointer: 0x{nativeTexturePtr.ToInt64():X}");
            if (nativeTexturePtr == IntPtr.Zero)
            {
                log.LogWarning("Temporary RenderTexture returned a null native pointer.");
                return;
            }

            var success = bridge.ProbeDlssFeatureCreate(
                nativeTexturePtr,
                runtimePath,
                applicationDataPath,
                applicationId,
                mode.RenderWidth,
                mode.RenderHeight,
                TargetWidth,
                TargetHeight,
                mode.PerfQualityValue,
                DlssFeatureFlagAutoExposure);
            var status = bridge.GetDlssFeatureCreateStatus();
            if (success)
            {
                log.LogInfo($"DLSS feature create probe succeeded: {status}");
            }
            else if (status.IndexOf("blocked", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                log.LogWarning($"DLSS feature create probe blocked: {status}");
            }
            else
            {
                log.LogWarning($"DLSS feature create probe failed: {status}");
            }
        }
        catch (Exception ex)
        {
            log.LogWarning($"DLSS feature create probe failed: {GetExceptionMessage(ex)}");
        }
        finally
        {
            TryRelease(renderTexture);
        }
    }

    private static ModeSettings ResolveMode(string qualityMode)
    {
        var normalized = (qualityMode ?? string.Empty).Trim().Replace("-", string.Empty).Replace("_", string.Empty);
        return normalized.ToLowerInvariant() switch
        {
            "dlaa" => new ModeSettings(1920, 1080, 5),
            "ultraperformance" => new ModeSettings(640, 360, 3),
            "performance" => new ModeSettings(960, 540, 0),
            "balanced" => new ModeSettings(1129, 635, 1),
            _ => new ModeSettings(1280, 720, 2),
        };
    }

    private static object? CreateRenderTexture(Type renderTextureType)
    {
        var intConstructor = renderTextureType.GetConstructor(new[] { typeof(int), typeof(int), typeof(int) });
        if (intConstructor is not null)
        {
            return intConstructor.Invoke(new object[] { ProbeSize, ProbeSize, 0 });
        }

        var constructors = renderTextureType.GetConstructors()
            .OrderBy(constructor => constructor.GetParameters().Length);

        foreach (var constructor in constructors)
        {
            var parameters = constructor.GetParameters();
            var args = new object?[parameters.Length];
            var canUse = true;

            for (var index = 0; index < parameters.Length; index++)
            {
                var parameterType = parameters[index].ParameterType;
                if (parameterType == typeof(int))
                {
                    args[index] = index < 2 ? ProbeSize : 0;
                }
                else if (parameterType == typeof(bool))
                {
                    args[index] = false;
                }
                else if (parameterType.IsEnum)
                {
                    args[index] = Enum.ToObject(parameterType, 0);
                }
                else
                {
                    canUse = false;
                    break;
                }
            }

            if (!canUse)
            {
                continue;
            }

            try
            {
                return constructor.Invoke(args);
            }
            catch
            {
            }
        }

        return null;
    }

    private static IntPtr GetNativeTexturePtr(object renderTexture)
    {
        var method = renderTexture.GetType().GetMethod(
            "GetNativeTexturePtr",
            BindingFlags.Public | BindingFlags.Instance,
            null,
            Type.EmptyTypes,
            null);

        var value = method?.Invoke(renderTexture, Array.Empty<object>());
        return value is IntPtr pointer ? pointer : IntPtr.Zero;
    }

    private static bool InvokeBool(object instance, string methodName)
    {
        var method = instance.GetType().GetMethod(
            methodName,
            BindingFlags.Public | BindingFlags.Instance,
            null,
            Type.EmptyTypes,
            null);

        if (method is null)
        {
            return false;
        }

        var value = method.Invoke(instance, Array.Empty<object>());
        return value is bool result && result;
    }

    private static void TrySetName(object instance, string name)
    {
        try
        {
            var property = instance.GetType().GetProperty(
                "name",
                BindingFlags.Public | BindingFlags.Instance);

            if (property?.SetMethod is not null)
            {
                property.SetValue(instance, name);
            }
        }
        catch
        {
        }
    }

    private static void TryRelease(object? renderTexture)
    {
        if (renderTexture is null)
        {
            return;
        }

        try
        {
            var release = renderTexture.GetType().GetMethod(
                "Release",
                BindingFlags.Public | BindingFlags.Instance,
                null,
                Type.EmptyTypes,
                null);

            release?.Invoke(renderTexture, Array.Empty<object>());
        }
        catch
        {
        }
    }

    private static string GetExceptionMessage(Exception ex)
    {
        return ex is TargetInvocationException { InnerException: not null }
            ? ex.InnerException.Message
            : ex.Message;
    }

    private readonly struct ModeSettings
    {
        internal ModeSettings(uint renderWidth, uint renderHeight, int perfQualityValue)
        {
            RenderWidth = renderWidth;
            RenderHeight = renderHeight;
            PerfQualityValue = perfQualityValue;
        }

        internal uint RenderWidth { get; }
        internal uint RenderHeight { get; }
        internal int PerfQualityValue { get; }
    }
}
