#if VRISINGDLSS_LOCAL_INTEROP
using BepInEx.Logging;
using Il2CppInterop.Runtime.Attributes;
using Il2CppInterop.Runtime.Injection;
using Il2CppInterop.Runtime;
using System;
using System.Threading;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

namespace VrisingDLSS.Plugin;

internal static class CustomPostProcessRenderEntryProbe
{
    private static readonly object Sync = new();
    private static bool Installed;
    private static bool TypeRegistered;
    private static bool AddedToGlobalSettings;
    private static GameObject? VolumeGameObject;
    private static Volume? MountedVolume;
    private static VolumeProfile? MountedProfile;
    private static ManualLogSource? Log;

    internal static void Install(ManualLogSource log)
    {
        lock (Sync)
        {
            if (Installed)
            {
                log.LogInfo("Custom post-process render-entry probe already installed.");
                return;
            }

            Log = log;
            RenderEntryComponent.ResetCounters();

            try
            {
                EnsureTypeRegistered(log);
                AddTypeToGlobalSettings(log);
                MountGlobalVolume(log);

                Installed = true;
                log.LogInfo("Custom post-process render-entry probe installed: injection=AfterPostProcess; volumeCreated=True; renderActive=True; commandBufferAccess=RenderOnly; nativeTextureAccess=False; dlssEvaluate=False");
            }
            catch (Exception ex)
            {
                log.LogWarning($"Custom post-process render-entry probe failed: {FirstLine(ex.Message)}");
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
                RemoveTypeFromGlobalSettings(log);
                DestroyMountedVolume(log);
            }
            catch (Exception ex)
            {
                log.LogWarning($"Custom post-process render-entry probe uninstall failed: {FirstLine(ex.Message)}");
            }
            finally
            {
                AddedToGlobalSettings = false;
                Installed = false;
                Log = null;
            }
        }
    }

    private static void EnsureTypeRegistered(ManualLogSource log)
    {
        if (TypeRegistered)
        {
            return;
        }

        if (!ClassInjector.IsTypeRegisteredInIl2Cpp<RenderEntryComponent>())
        {
            ClassInjector.RegisterTypeInIl2Cpp<RenderEntryComponent>();
            log.LogInfo("Custom post-process render-entry probe IL2CPP type registered.");
        }

        TypeRegistered = true;
    }

    private static void AddTypeToGlobalSettings(ManualLogSource log)
    {
        var settings = HDRenderPipelineGlobalSettings.instance;
        if (settings is null)
        {
            throw new InvalidOperationException("HDRenderPipelineGlobalSettings.instance was null.");
        }

        var typeName = typeof(RenderEntryComponent).AssemblyQualifiedName;
        if (string.IsNullOrWhiteSpace(typeName))
        {
            throw new InvalidOperationException("injected component type name was empty.");
        }

        var list = settings.afterPostProcessCustomPostProcesses;
        if (list is null)
        {
            throw new InvalidOperationException("afterPostProcessCustomPostProcesses list was null.");
        }

        if (!Contains(list, typeName))
        {
            list.Add(typeName);
            AddedToGlobalSettings = true;
        }

        settings.RefreshPostProcessTypes();
        log.LogInfo($"Custom post-process render-entry probe global settings registered: type={typeName}; addedToGlobalSettings={AddedToGlobalSettings}");
    }

    private static void RemoveTypeFromGlobalSettings(ManualLogSource log)
    {
        var typeName = typeof(RenderEntryComponent).AssemblyQualifiedName;
        if (!AddedToGlobalSettings || string.IsNullOrWhiteSpace(typeName))
        {
            return;
        }

        var settings = HDRenderPipelineGlobalSettings.instance;
        var list = settings?.afterPostProcessCustomPostProcesses;
        if (list is null)
        {
            return;
        }

        while (Contains(list, typeName))
        {
            list.Remove(typeName);
        }

        settings!.RefreshPostProcessTypes();
        log.LogInfo("Custom post-process render-entry probe global settings unregistered.");
    }

    private static void MountGlobalVolume(ManualLogSource log)
    {
        var profile = ScriptableObject.CreateInstance<VolumeProfile>();
        profile.name = "VrisingDLSS Custom PostProcess Render Entry Profile";
        profile.hideFlags = HideFlags.HideAndDontSave;

        var component = profile.Add(Il2CppType.Of<RenderEntryComponent>(), false);
        if (component is null)
        {
            throw new InvalidOperationException("VolumeProfile.Add returned null.");
        }

        component.active = true;

        var gameObject = new GameObject("VrisingDLSS Custom PostProcess Render Entry Probe");
        gameObject.hideFlags = HideFlags.HideAndDontSave;
        gameObject.layer = 0;
        UnityEngine.Object.DontDestroyOnLoad(gameObject);

        var volume = gameObject.AddComponent<Volume>();
        volume.isGlobal = true;
        volume.priority = 10000f;
        volume.weight = 1f;
        volume.sharedProfile = profile;

        VolumeGameObject = gameObject;
        MountedVolume = volume;
        MountedProfile = profile;

        log.LogInfo($"Custom post-process render-entry probe volume mounted: layer={gameObject.layer}; isGlobal={volume.isGlobal}; priority={volume.priority}; weight={volume.weight}; profileComponents={profile.components?.Count ?? -1}; componentActive={component.active}");
    }

    private static void DestroyMountedVolume(ManualLogSource log)
    {
        if (MountedVolume is not null)
        {
            try
            {
                VolumeManager.instance?.Unregister(MountedVolume, VolumeGameObject?.layer ?? 0);
            }
            catch (Exception ex)
            {
                log.LogWarning($"Custom post-process render-entry probe volume unregister failed: {FirstLine(ex.Message)}");
            }
        }

        if (VolumeGameObject is not null)
        {
            UnityEngine.Object.Destroy(VolumeGameObject);
            VolumeGameObject = null;
        }

        if (MountedProfile is not null)
        {
            UnityEngine.Object.Destroy(MountedProfile);
            MountedProfile = null;
        }

        MountedVolume = null;
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

    private static void LogRenderEntry(int count, CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        if (count != 1 && count % 300 != 0)
        {
            return;
        }

        Log?.LogInfo($"Custom post-process render-entry probe Render #{count}: cmdNull={cmd is null}; camera={DescribeCamera(camera)}; sourceNull={source is null}; destinationNull={destination is null}; copy=HDUtils.BlitCameraTexture; nativeTextureAccess=False; dlssEvaluate=False");
    }

    private static string DescribeCamera(HDCamera camera)
    {
        if (camera is null)
        {
            return "null";
        }

        try
        {
            return $"{camera.actualWidth}x{camera.actualHeight}";
        }
        catch
        {
            return "unavailable";
        }
    }

    [Serializable]
    [Il2CppImplements(typeof(IPostProcessComponent))]
    private sealed class RenderEntryComponent : CustomPostProcessVolumeComponent
    {
        private static int RenderCount;

        public RenderEntryComponent(IntPtr pointer)
            : base(pointer)
        {
        }

        public RenderEntryComponent()
            : base(ClassInjector.DerivedConstructorPointer<RenderEntryComponent>())
        {
            ClassInjector.DerivedConstructorBody(this);
            EnsureVolumeStorage();
        }

        public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

        public override bool visibleInSceneView => false;

        public bool IsActive()
        {
            return true;
        }

        public override void OnEnable()
        {
            EnsureVolumeStorage();
            base.OnEnable();
        }

        public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
        {
            var count = Interlocked.Increment(ref RenderCount);
            try
            {
                HDUtils.BlitCameraTexture(cmd, source, destination);
                LogRenderEntry(count, cmd, camera, source, destination);
            }
            catch (Exception ex)
            {
                Log?.LogWarning($"Custom post-process render-entry probe copy failed #{count}: {FirstLine(ex.Message)}");
            }
        }

        internal static void ResetCounters()
        {
            Interlocked.Exchange(ref RenderCount, 0);
        }

        private void EnsureVolumeStorage()
        {
            parameterList ??= new Il2CppSystem.Collections.Generic.List<VolumeParameter>();
        }
    }
}
#else
using BepInEx.Logging;

namespace VrisingDLSS.Plugin;

internal static class CustomPostProcessRenderEntryProbe
{
    internal static void Install(ManualLogSource log)
    {
        log.LogWarning("Custom post-process render-entry probe blocked: local V Rising HDRP interop assemblies were not available at build time.");
    }

    internal static void Uninstall(ManualLogSource log)
    {
    }
}
#endif
