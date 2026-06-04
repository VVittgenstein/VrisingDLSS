using BepInEx.Configuration;

namespace VrisingDLSS.Plugin;

internal sealed class ModConfig
{
    internal ConfigEntry<bool> EnablePlugin { get; }
    internal ConfigEntry<bool> EnableNativeBridgeSmokeTest { get; }
    internal ConfigEntry<bool> EnableRenderThreadSmokeTest { get; }
    internal ConfigEntry<bool> EnableD3D11TextureProbe { get; }
    internal ConfigEntry<bool> EnableDlssRuntimeProbe { get; }
    internal ConfigEntry<bool> EnableDlssInitQueryProbe { get; }
    internal ConfigEntry<bool> EnableDlssFeatureCreateProbe { get; }
    internal ConfigEntry<bool> EnableHookProbe { get; }
    internal ConfigEntry<bool> EnableHarmonyCallProbe { get; }
    internal ConfigEntry<bool> EnableFrameResourceProbe { get; }
    internal ConfigEntry<bool> ShowOverlay { get; }
    internal ConfigEntry<string> DlssRuntimePath { get; }
    internal ConfigEntry<string> DlssApplicationId { get; }
    internal ConfigEntry<string> QualityMode { get; }
    internal ConfigEntry<float> Sharpness { get; }

    internal ModConfig(ConfigFile config)
    {
        EnablePlugin = config.Bind("General", "EnablePlugin", true, "Enable the plugin scaffold.");
        EnableNativeBridgeSmokeTest = config.Bind("Diagnostics", "EnableNativeBridgeSmokeTest", false, "Try loading VrisingDLSS.Native.dll at startup.");
        EnableRenderThreadSmokeTest = config.Bind("Diagnostics", "EnableRenderThreadSmokeTest", false, "Issue a single Unity render-thread plugin event through VrisingDLSS.Native.dll. Diagnostic only.");
        EnableD3D11TextureProbe = config.Bind("Diagnostics", "EnableD3D11TextureProbe", false, "Create a temporary RenderTexture, pass its native texture pointer to VrisingDLSS.Native.dll, and verify D3D11 resource/device access. Diagnostic only.");
        EnableDlssRuntimeProbe = config.Bind("Diagnostics", "EnableDlssRuntimeProbe", false, "Try loading and releasing the user-supplied DLSS runtime path. Diagnostic only; does not initialize or evaluate DLSS.");
        EnableDlssInitQueryProbe = config.Bind("Diagnostics", "EnableDlssInitQueryProbe", false, "Guarded NGX init/query diagnostic with a temporary RenderTexture D3D11 device. May report blocked until NVIDIA SDK wrapper integration exists; does not create or evaluate a DLSS feature.");
        EnableDlssFeatureCreateProbe = config.Bind("Diagnostics", "EnableDlssFeatureCreateProbe", false, "SDK-wrapper DLSS feature create/release diagnostic with a temporary RenderTexture D3D11 device. Diagnostic only; does not evaluate a frame.");
        EnableHookProbe = config.Bind("Diagnostics", "EnableHookProbe", true, "Scan loaded assemblies for candidate HDRP hook points and log the result.");
        EnableHarmonyCallProbe = config.Bind("Diagnostics", "EnableHarmonyCallProbe", false, "Patch candidate HDRP methods with read-only Harmony prefixes and log call counts. Diagnostic only.");
        EnableFrameResourceProbe = config.Bind("Diagnostics", "EnableFrameResourceProbe", false, "Patch candidate HDRP render methods with read-only Harmony prefixes and log source/destination/depth/motion native texture pointers. Diagnostic only.");
        ShowOverlay = config.Bind("Diagnostics", "ShowOverlay", true, "Show a small diagnostic overlay when implemented.");
        DlssRuntimePath = config.Bind("DLSS", "DlssRuntimePath", string.Empty, "Optional path to a user-supplied production nvngx_dlss.dll.");
        DlssApplicationId = config.Bind("DLSS", "DlssApplicationId", "0", "Optional NVIDIA NGX application id for init/query diagnostics. Decimal or 0x-prefixed hexadecimal.");
        QualityMode = config.Bind("DLSS", "QualityMode", "Quality", "Requested DLSS mode: Quality, Balanced, Performance, UltraPerformance, or DLAA.");
        Sharpness = config.Bind("DLSS", "Sharpness", 0.0f, "Optional sharpening value. 0 disables sharpening.");
    }
}
