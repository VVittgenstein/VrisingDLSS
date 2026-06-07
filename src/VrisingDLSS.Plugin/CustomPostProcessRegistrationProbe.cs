#if VRISINGDLSS_LOCAL_INTEROP
using BepInEx.Logging;
using Il2CppInterop.Runtime.Attributes;
using Il2CppInterop.Runtime.Injection;
using System;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

namespace VrisingDLSS.Plugin;

internal static class CustomPostProcessRegistrationProbe
{
    private static readonly object Sync = new();
    private static bool Installed;
    private static bool TypeRegistered;
    private static bool AddedToGlobalSettings;

    internal static void Install(ManualLogSource log)
    {
        lock (Sync)
        {
            if (Installed)
            {
                log.LogInfo("Custom post-process registration probe already installed.");
                return;
            }

            try
            {
                EnsureTypeRegistered(log);

                var settings = HDRenderPipelineGlobalSettings.instance;
                if (settings is null)
                {
                    log.LogWarning("Custom post-process registration probe blocked: HDRenderPipelineGlobalSettings.instance was null.");
                    return;
                }

                var typeName = typeof(RegistrationComponent).AssemblyQualifiedName;
                if (string.IsNullOrWhiteSpace(typeName))
                {
                    log.LogWarning("Custom post-process registration probe blocked: injected component type name was empty.");
                    return;
                }

                var list = settings.afterPostProcessCustomPostProcesses;
                if (list is null)
                {
                    log.LogWarning("Custom post-process registration probe blocked: afterPostProcessCustomPostProcesses list was null.");
                    return;
                }

                if (!Contains(list, typeName))
                {
                    list.Add(typeName);
                    AddedToGlobalSettings = true;
                }

                settings.RefreshPostProcessTypes();

                Installed = true;
                log.LogInfo($"Custom post-process registration probe installed: injection=AfterPostProcess; type={typeName}; addedToGlobalSettings={AddedToGlobalSettings}; volumeCreated=False; renderActive=False");
            }
            catch (Exception ex)
            {
                log.LogWarning($"Custom post-process registration probe failed: {FirstLine(ex.Message)}");
                Uninstall(log);
            }
        }
    }

    internal static void Uninstall(ManualLogSource log)
    {
        lock (Sync)
        {
            try
            {
                var typeName = typeof(RegistrationComponent).AssemblyQualifiedName;
                if (AddedToGlobalSettings && !string.IsNullOrWhiteSpace(typeName))
                {
                    var settings = HDRenderPipelineGlobalSettings.instance;
                    var list = settings?.afterPostProcessCustomPostProcesses;
                    if (list is not null)
                    {
                        while (Contains(list, typeName))
                        {
                            list.Remove(typeName);
                        }

                        settings!.RefreshPostProcessTypes();
                    }
                }
            }
            catch (Exception ex)
            {
                log.LogWarning($"Custom post-process registration probe uninstall failed: {FirstLine(ex.Message)}");
            }
            finally
            {
                AddedToGlobalSettings = false;
                Installed = false;
            }
        }
    }

    private static void EnsureTypeRegistered(ManualLogSource log)
    {
        if (TypeRegistered)
        {
            return;
        }

        if (!ClassInjector.IsTypeRegisteredInIl2Cpp<RegistrationComponent>())
        {
            ClassInjector.RegisterTypeInIl2Cpp<RegistrationComponent>();
            log.LogInfo("Custom post-process registration probe IL2CPP type registered.");
        }

        TypeRegistered = true;
    }

    private static bool Contains(Il2CppSystem.Collections.Generic.List<string> list, string value)
    {
        for (var index = 0; index < list.Count; index++)
        {
            if (string.Equals(list[index], value, StringComparison.Ordinal))
            {
                return true;
            }
        }

        return false;
    }

    private static string FirstLine(string value)
    {
        var lineEnd = value.IndexOfAny(new[] { '\r', '\n' });
        return lineEnd >= 0 ? value[..lineEnd] : value;
    }

    [Serializable]
    [Il2CppImplements(typeof(IPostProcessComponent))]
    private sealed class RegistrationComponent : CustomPostProcessVolumeComponent
    {
        public RegistrationComponent(IntPtr pointer)
            : base(pointer)
        {
        }

        public RegistrationComponent()
            : base(ClassInjector.DerivedConstructorPointer<RegistrationComponent>())
        {
            ClassInjector.DerivedConstructorBody(this);
        }

        public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

        public override bool visibleInSceneView => false;

        public bool IsActive()
        {
            return false;
        }

        public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
        {
        }
    }
}
#else
using BepInEx.Logging;

namespace VrisingDLSS.Plugin;

internal static class CustomPostProcessRegistrationProbe
{
    internal static void Install(ManualLogSource log)
    {
        log.LogWarning("Custom post-process registration probe blocked: local V Rising HDRP interop assemblies were not available at build time.");
    }

    internal static void Uninstall(ManualLogSource log)
    {
    }
}
#endif
