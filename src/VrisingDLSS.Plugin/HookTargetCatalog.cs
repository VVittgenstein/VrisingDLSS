using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace VrisingDLSS.Plugin;

internal static class HookTargetCatalog
{
    internal static readonly ProbeTarget[] Targets =
    {
        new("UnityEngine.Rendering.HighDefinition.CustomVignette", new[] { "IsActive", "Render", "Cleanup" }),
        new("UnityEngine.Rendering.HighDefinition.HDCamera", new[] { "UpdateAllViewConstants", "UpdateAntialiasing" }),
        new("UnityEngine.Rendering.DynamicResolutionHandler", new[] { "DynamicResolutionEnabled", "SetDynamicResScaler" }),
        new("UnityEngine.Rendering.HighDefinition.SkyManager", new[] { "IsLightingSkyValid" }),
        new("UnityEngine.Rendering.HighDefinition.HDRenderPipeline", new[] { "UpdateShaderVariablesGlobalCB" })
    };

    internal static Type? FindType(IEnumerable<Assembly> assemblies, string fullName)
    {
        foreach (var assembly in assemblies)
        {
            var type = assembly.GetType(fullName, throwOnError: false);
            if (type is not null)
            {
                return type;
            }
        }

        var shortName = fullName.Split('.').Last();
        foreach (var assembly in assemblies)
        {
            foreach (var type in SafeGetTypes(assembly))
            {
                if (type.Name == shortName)
                {
                    return type;
                }
            }
        }

        return null;
    }

    internal static IReadOnlyList<MethodInfo> FindMethods(Type type, string memberName)
    {
        const BindingFlags flags = BindingFlags.Public
            | BindingFlags.NonPublic
            | BindingFlags.Instance
            | BindingFlags.Static
            | BindingFlags.DeclaredOnly;

        var methods = new List<MethodInfo>();
        methods.AddRange(type.GetMethods(flags).Where(method => method.Name == memberName));

        var property = type.GetProperty(memberName, flags);
        if (property?.GetMethod is not null)
        {
            methods.Add(property.GetMethod);
        }

        var getterName = $"get_{memberName}";
        methods.AddRange(type.GetMethods(flags).Where(method => method.Name == getterName));

        return methods
            .GroupBy(method => new { method.MetadataToken, Module = method.Module.ModuleVersionId })
            .Select(group => group.First())
            .ToArray();
    }

    internal static string FormatMethod(MethodBase method)
    {
        var parameters = string.Join(", ", method.GetParameters().Select(parameter =>
            $"{parameter.ParameterType.Name} {parameter.Name}"));

        var returnType = method is MethodInfo methodInfo
            ? methodInfo.ReturnType.Name
            : "void";

        return $"{method.DeclaringType?.FullName}.{method.Name}({parameters}) -> {returnType}";
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

    internal readonly record struct ProbeTarget(string TypeName, IReadOnlyList<string> MemberNames);
}
