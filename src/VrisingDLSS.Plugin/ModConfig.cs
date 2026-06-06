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
    internal ConfigEntry<bool> EnableDlssOptimalSettingsProbe { get; }
    internal ConfigEntry<bool> EnableDlssFeatureCreateProbe { get; }
    internal ConfigEntry<bool> EnableDlssEvaluateInputProbe { get; }
    internal ConfigEntry<bool> EnableDlssSuperResolutionInputProbe { get; }
    internal ConfigEntry<bool> EnableDlssSuperResolutionEvaluateProbe { get; }
    internal ConfigEntry<bool> EnableDlssSuperResolutionPersistentEvaluateProbe { get; }
    internal ConfigEntry<bool> EnableDlssSuperResolutionFrameSequenceEvaluateProbe { get; }
    internal ConfigEntry<bool> EnableDlssVisibleWritebackProbe { get; }
    internal ConfigEntry<bool> KeepDlssVisibleWritebackProbeRunning { get; }
    internal ConfigEntry<bool> EnableDlssEvaluateProbe { get; }
    internal ConfigEntry<bool> EnableDlssPersistentEvaluateProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphDiagnosticPass { get; }
    internal ConfigEntry<bool> EnableExistingRenderFuncProbe { get; }
    internal ConfigEntry<bool> EnableResourceMaterializationProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphPassBoundaryProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphPassMapProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphPassListProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphPassResourceDeclarationProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphPassDataSnapshotProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphExecuteDelegateProbe { get; }
    internal ConfigEntry<bool> EnableRenderGraphGetTextureProbe { get; }
    internal ConfigEntry<bool> EnableDlssPassResourceProbe { get; }
    internal ConfigEntry<bool> EnableUpscalerStateProbe { get; }
    internal ConfigEntry<bool> EnableRenderScaleControlProbe { get; }
    internal ConfigEntry<bool> EnableDlssUserRenderingNoEvaluateProbe { get; }
    internal ConfigEntry<bool> EnableDlssCachedTupleDriverProbe { get; }
    internal ConfigEntry<bool> EnableHookProbe { get; }
    internal ConfigEntry<bool> EnableHarmonyCallProbe { get; }
    internal ConfigEntry<bool> EnableFrameResourceProbe { get; }
    internal ConfigEntry<bool> EnableDlss { get; }
    internal ConfigEntry<string> DlssRuntimePath { get; }
    internal ConfigEntry<string> DlssApplicationId { get; }
    internal ConfigEntry<string> QualityMode { get; }
    internal ConfigEntry<string> PresetMode { get; }
    internal ConfigEntry<float> Sharpness { get; }
    internal ConfigEntry<bool> AutoExposure { get; }
    internal ConfigEntry<int> RenderScaleOverride { get; }
    internal ConfigEntry<string> MipBiasOverride { get; }
    internal ConfigEntry<bool> ResetOnCameraCut { get; }
    internal ConfigEntry<string> LogLevel { get; }
    internal ConfigEntry<bool> ShowOverlay { get; }

    internal ModConfig(ConfigFile config)
    {
        EnablePlugin = config.Bind("General", "EnablePlugin", true, "Enable the plugin scaffold.");
        EnableNativeBridgeSmokeTest = config.Bind("Diagnostics", "EnableNativeBridgeSmokeTest", false, "Try loading VrisingDLSS.Native.dll at startup.");
        EnableRenderThreadSmokeTest = config.Bind("Diagnostics", "EnableRenderThreadSmokeTest", false, "Issue a single Unity render-thread plugin event through VrisingDLSS.Native.dll. Diagnostic only.");
        EnableD3D11TextureProbe = config.Bind("Diagnostics", "EnableD3D11TextureProbe", false, "Create a temporary RenderTexture, pass its native texture pointer to VrisingDLSS.Native.dll, and verify D3D11 resource/device access. Diagnostic only.");
        EnableDlssRuntimeProbe = config.Bind("Diagnostics", "EnableDlssRuntimeProbe", false, "Try loading and releasing the user-supplied DLSS runtime path. Diagnostic only; does not initialize or evaluate DLSS.");
        EnableDlssInitQueryProbe = config.Bind("Diagnostics", "EnableDlssInitQueryProbe", false, "Guarded NGX init/query diagnostic with a temporary RenderTexture D3D11 device. May report blocked until NVIDIA SDK wrapper integration exists; does not create or evaluate a DLSS feature.");
        EnableDlssOptimalSettingsProbe = config.Bind("Diagnostics", "EnableDlssOptimalSettingsProbe", false, "SDK-wrapper diagnostic that queries DLSS optimal render size for a 4K output target and the selected quality mode. Diagnostic only; does not create or evaluate a DLSS feature.");
        EnableDlssFeatureCreateProbe = config.Bind("Diagnostics", "EnableDlssFeatureCreateProbe", false, "SDK-wrapper DLSS feature create/release diagnostic with a temporary RenderTexture D3D11 device. Diagnostic only; does not evaluate a frame.");
        EnableDlssEvaluateInputProbe = config.Bind("Diagnostics", "EnableDlssEvaluateInputProbe", false, "Validate same-frame color/output/depth/motion D3D11 texture inputs for the future DLSS evaluate path. Diagnostic only; does not evaluate a frame.");
        EnableDlssSuperResolutionInputProbe = config.Bind("Diagnostics", "EnableDlssSuperResolutionInputProbe", false, "Validate a DLSS Super Resolution-sized real-frame tuple where color/depth/motion render inputs are smaller than the output target. Diagnostic only; does not evaluate a frame.");
        EnableDlssSuperResolutionEvaluateProbe = config.Bind("Diagnostics", "EnableDlssSuperResolutionEvaluateProbe", false, "High-risk SDK-wrapper diagnostic that evaluates one discovered Super Resolution-sized frame-resource tuple. Leave false unless deliberate local/private testing is intentional.");
        EnableDlssSuperResolutionPersistentEvaluateProbe = config.Bind("Diagnostics", "EnableDlssSuperResolutionPersistentEvaluateProbe", false, "High-risk SDK-wrapper diagnostic that creates one DLSS feature and evaluates the discovered Super Resolution-sized tuple multiple times before release/shutdown. Leave false unless deliberate local/private testing is intentional.");
        EnableDlssSuperResolutionFrameSequenceEvaluateProbe = config.Bind("Diagnostics", "EnableDlssSuperResolutionFrameSequenceEvaluateProbe", false, "High-risk SDK-wrapper diagnostic that keeps one DLSS feature alive across multiple RenderGraph callbacks for a discovered Super Resolution-sized tuple. Leave false unless deliberate local/private testing is intentional.");
        EnableDlssVisibleWritebackProbe = config.Bind("Diagnostics", "EnableDlssVisibleWritebackProbe", false, "High-risk SDK-wrapper diagnostic that repeatedly evaluates DLSS into the selected visible-path Super Resolution output target. Leave false unless deliberate local/private image-correctness testing is intentional.");
        KeepDlssVisibleWritebackProbeRunning = config.Bind("Diagnostics", "KeepDlssVisibleWritebackProbeRunning", false, "Keep the visible write-back probe evaluating after its 30-success milestone until the game exits or the diagnostic is stopped. Local/private image-correctness testing only.");
        EnableDlssEvaluateProbe = config.Bind("Diagnostics", "EnableDlssEvaluateProbe", false, "High-risk SDK-wrapper diagnostic that creates a DLSS feature and evaluates one discovered frame-resource tuple. Leave false unless deliberate local/private testing is intentional.");
        EnableDlssPersistentEvaluateProbe = config.Bind("Diagnostics", "EnableDlssPersistentEvaluateProbe", false, "High-risk SDK-wrapper diagnostic that creates one DLSS feature and evaluates the discovered frame-resource tuple multiple times before release/shutdown. Leave false unless deliberate local/private testing is intentional.");
        EnableRenderGraphDiagnosticPass = config.Bind("Diagnostics", "EnableRenderGraphDiagnosticPass", false, "High-risk research-only RenderGraph pass injection for Stage 8A. Leave false unless crash-recovery testing is intentional.");
        EnableExistingRenderFuncProbe = config.Bind("Diagnostics", "EnableExistingRenderFuncProbe", false, "High-risk research-only patching of compiler-generated HDRP RenderGraph render functions. Leave false unless crash-recovery testing is intentional.");
        EnableResourceMaterializationProbe = config.Bind("Diagnostics", "EnableResourceMaterializationProbe", false, "Patch RenderGraph texture resource creation callbacks to observe already-created RTHandle/native texture resources during Stage 8A. Diagnostic only.");
        EnableRenderGraphPassBoundaryProbe = config.Bind("Diagnostics", "EnableRenderGraphPassBoundaryProbe", false, "High-risk research-only patching of RenderGraph pass execution boundaries. It logs pass metadata only and does not resolve textures or evaluate DLSS, but startup testing reproduced a coreclr crash.");
        EnableRenderGraphPassMapProbe = config.Bind("Diagnostics", "EnableRenderGraphPassMapProbe", false, "Read-only RenderGraph pass recording probe. Patches RenderGraph.OnPassAdded to log pass names/categories only; does not resolve textures or evaluate DLSS.");
        EnableRenderGraphPassListProbe = config.Bind("Diagnostics", "EnableRenderGraphPassListProbe", false, "Read-only RenderGraph compile-list probe. Patches CompileRenderGraph(int) to snapshot m_RenderPasses names/categories only; does not resolve textures or evaluate DLSS.");
        EnableRenderGraphPassResourceDeclarationProbe = config.Bind("Diagnostics", "EnableRenderGraphPassResourceDeclarationProbe", false, "Read-only RenderGraph pass resource declaration probe. Patches CompileRenderGraph(int) to snapshot focused pass read/write handle declarations only; does not resolve textures or evaluate DLSS.");
        EnableRenderGraphPassDataSnapshotProbe = config.Bind("Diagnostics", "EnableRenderGraphPassDataSnapshotProbe", false, "Read-only RenderGraph pass data snapshot probe. Patches CompileRenderGraph(int) to log focused pass data fields and TextureHandle declarations only; does not resolve textures or evaluate DLSS.");
        EnableRenderGraphExecuteDelegateProbe = config.Bind("Diagnostics", "EnableRenderGraphExecuteDelegateProbe", false, "Read-only RenderGraph execution-layer probe. Patches closed GetExecuteDelegate<TPassData>() methods for focused HDRP pass data only; does not resolve textures, touch command buffers, or evaluate DLSS.");
        EnableRenderGraphGetTextureProbe = config.Bind("Diagnostics", "EnableRenderGraphGetTextureProbe", true, "Patch RenderGraphResourceRegistry.GetTexture(TextureHandle&) for diagnostic resource discovery. Disable only for deliberate materialization-only isolation.");
        EnableDlssPassResourceProbe = config.Bind("Diagnostics", "EnableDlssPassResourceProbe", false, "High-risk research-only patching of DLSSPass resource helper methods. Does not patch DLSSPass.Render; leave false unless deliberate Stage 8A resource testing is intentional.");
        EnableUpscalerStateProbe = config.Bind("Diagnostics", "EnableUpscalerStateProbe", false, "Patch HDRP/dynamic-resolution/DLSS setup methods and log read-only camera/upscale state snapshots. Diagnostic only; does not change render scale.");
        EnableRenderScaleControlProbe = config.Bind("Diagnostics", "EnableRenderScaleControlProbe", false, "Experimental diagnostic that requests HDRP dynamic resolution at the selected DLSS quality's render-scale percentage while avoiding Unity's internal DLSS pass. Leave false unless deliberate local/private testing is intentional.");
        EnableDlssUserRenderingNoEvaluateProbe = config.Bind("Diagnostics", "EnableDlssUserRenderingNoEvaluateProbe", false, "Diagnostic-only control path that runs the user-rendering RenderGraph tuple discovery and Super Resolution input acceptance path but skips NGX evaluate/writeback.");
        EnableDlssCachedTupleDriverProbe = config.Bind("Diagnostics", "EnableDlssCachedTupleDriverProbe", false, "Diagnostic-only path that reuses the first accepted RenderGraph Super Resolution tuple from DynamicResolutionHandler.Update instead of continuing resource discovery on every GetTexture callback.");
        EnableHookProbe = config.Bind("Diagnostics", "EnableHookProbe", true, "Scan loaded assemblies for candidate HDRP hook points and log the result.");
        EnableHarmonyCallProbe = config.Bind("Diagnostics", "EnableHarmonyCallProbe", false, "Patch candidate HDRP methods with read-only Harmony prefixes and log call counts. Diagnostic only.");
        EnableFrameResourceProbe = config.Bind("Diagnostics", "EnableFrameResourceProbe", false, "Patch candidate HDRP render methods with read-only Harmony prefixes and log source/destination/depth/motion native texture pointers. Diagnostic only.");
        EnableDlss = config.Bind("DLSS", "EnableDLSS", false, "Enable the experimental DLSS Super Resolution user-rendering candidate. Current builds throttle it to at most one evaluate per Unity frame, log evidence, and fall back safely.");
        DlssRuntimePath = config.Bind("DLSS", "DlssRuntimePath", string.Empty, "Optional path to a user-supplied production nvngx_dlss.dll.");
        DlssApplicationId = config.Bind("DLSS", "DlssApplicationId", "0", "Optional NVIDIA NGX application id for init/query diagnostics. Decimal or 0x-prefixed hexadecimal.");
        QualityMode = config.Bind("DLSS", "QualityMode", "Performance", "Requested DLSS mode: DLAA, Quality, Balanced, Performance, or UltraPerformance.");
        PresetMode = config.Bind("DLSS", "PresetMode", "Recommended", "Requested DLSS preset mode: Recommended, Auto, PresetK, PresetL, or PresetM. Explicit presets are applied only after SDK mapping is verified.");
        Sharpness = config.Bind("DLSS", "Sharpness", 0.0f, "Optional sharpening value. 0 disables sharpening.");
        AutoExposure = config.Bind("DLSS", "AutoExposure", true, "Use DLSS auto-exposure when supported and verified.");
        RenderScaleOverride = config.Bind("Advanced", "RenderScaleOverride", 0, "Optional render-height override in pixels. 0 lets the selected DLSS quality mode choose the render scale.");
        MipBiasOverride = config.Bind("Advanced", "MipBiasOverride", "Auto", "Optional mip-map bias override. Auto lets the plugin choose a DLSS-appropriate bias when implemented.");
        ResetOnCameraCut = config.Bind("Advanced", "ResetOnCameraCut", true, "Reset temporal DLSS history on camera cuts when implemented.");
        LogLevel = config.Bind("Advanced", "LogLevel", "Info", "Requested plugin log level: Info, Warning, Debug, or Trace.");
        ShowOverlay = config.Bind("Advanced", "ShowOverlay", true, "Show a small diagnostic/status overlay when implemented.");
    }
}
