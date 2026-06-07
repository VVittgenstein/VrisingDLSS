using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using System;
using System.IO;
using System.Reflection;

namespace VrisingDLSS.Plugin;

[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
public sealed class Plugin : BasePlugin
{
    private const string ModConfigFileName = "VrisingDLSS.cfg";
    private ManualLogSource? _log;
    private ModConfig? _config;
    private NativeBridge? _nativeBridge;

    public override void Load()
    {
        _log = Log;
        _config = new ModConfig(CreateModConfigFile());

        _log.LogInfo($"{PluginInfo.Name} {PluginInfo.Version} loaded.");
        _log.LogInfo("This is a clean-room scaffold. DLSS rendering is experimental and not MVP-validated yet; guarded evaluate diagnostics are local research only.");

        WarnIfReferenceBinariesAreInstalled();

        if (!_config.EnablePlugin.Value)
        {
            _log.LogInfo("Plugin disabled by configuration.");
            return;
        }

        if (_config.EnableDlss.Value)
        {
            _log.LogWarning("DLSS.EnableDLSS is true. The experimental user rendering path will use the crash-safe RenderGraph resource route and at most one DLSS evaluate per Unity frame when a compatible native bridge/runtime is available.");
        }
        if (_config.EnableDlssUserRenderingNoEvaluateProbe.Value)
        {
            _log.LogWarning("DLSS user-rendering no-evaluate diagnostic is true. This will exercise RenderGraph tuple discovery and Super Resolution input acceptance, but it will not call NGX evaluate or write into the output target.");
        }
        if (_config.EnableDlssCachedTupleDriverProbe.Value)
        {
            _log.LogWarning("DLSS cached tuple driver diagnostic is true. This probe stops steady-state GetTexture resource discovery after the first accepted tuple and drives that cached tuple from DynamicResolutionHandler.Update.");
        }

        if (_config.EnableHookProbe.Value)
        {
            HookProbe.Run(_log);
        }

        if (_config.EnableUpscalerStateProbe.Value)
        {
            UpscalerStateProbe.Install(_log);
        }

        if (_config.EnableRenderScaleControlProbe.Value || _config.EnableDlss.Value || _config.EnableDlssUserRenderingNoEvaluateProbe.Value || _config.EnableDlssCachedTupleDriverProbe.Value)
        {
            RenderScaleControlProbe.Install(_log, _config.QualityMode.Value, _config.RenderScaleOverride.Value);
        }

        if (_config.EnableHarmonyCallProbe.Value)
        {
            HarmonyCallProbe.Install(_log);
        }

        if (_config.EnableCustomPostProcessRegistrationProbe.Value)
        {
            RunCustomPostProcessRegistrationProbe();
        }
        if (_config.EnableCustomPostProcessRenderEntryProbe.Value)
        {
            RunCustomPostProcessRenderEntryProbe();
        }

        if (_config.EnableFrameResourceProbe.Value
            || _config.EnableDlssEvaluateInputProbe.Value
            || _config.EnableDlssSuperResolutionInputProbe.Value
            || _config.EnableDlssSuperResolutionEvaluateProbe.Value
            || _config.EnableDlssSuperResolutionPersistentEvaluateProbe.Value
            || _config.EnableDlssSuperResolutionFrameSequenceEvaluateProbe.Value
            || _config.EnableDlssVisibleWritebackProbe.Value
            || _config.EnableDlssEvaluateProbe.Value
            || _config.EnableDlssPersistentEvaluateProbe.Value
            || _config.EnableDlssPassResourceProbe.Value
            || _config.EnableRenderGraphPassBoundaryProbe.Value
            || _config.EnableRenderGraphPassMapProbe.Value
            || _config.EnableRenderGraphPassListProbe.Value
            || _config.EnableRenderGraphPassResourceDeclarationProbe.Value
            || _config.EnableRenderGraphPassDataSnapshotProbe.Value
            || _config.EnableRenderGraphPassRenderFuncMetadataProbe.Value
            || _config.EnableRenderGraphCompiledPassInfoProbe.Value
            || _config.EnableRenderGraphExecuteDelegateProbe.Value
            || _config.EnableNativeRenderFuncEntryProbe.Value
            || _config.EnableNativeRenderFuncArgumentProbe.Value
            || _config.EnableNativeRenderFuncResourceIdentityProbe.Value
            || _config.EnableNativeRenderFuncResourceTupleProbe.Value
            || _config.EnableNativeRenderFuncResourceResolveProbe.Value
            || _config.EnableNativeRenderFuncResourceNativePointerProbe.Value
            || _config.EnableDlss.Value
            || _config.EnableDlssUserRenderingNoEvaluateProbe.Value
            || _config.EnableDlssCachedTupleDriverProbe.Value)
        {
            RunFrameResourceProbe();
        }

        if (_config.EnableNativeBridgeSmokeTest.Value)
        {
            RunNativeBridgeSmokeTest();
        }

        if (_config.EnableRenderThreadSmokeTest.Value)
        {
            RunRenderThreadSmokeTest();
        }

        if (_config.EnableD3D11TextureProbe.Value)
        {
            RunD3D11TextureProbe();
        }

        if (_config.EnableDlssRuntimeProbe.Value)
        {
            RunDlssRuntimeProbe();
        }

        if (_config.EnableDlssInitQueryProbe.Value)
        {
            RunDlssInitQueryProbe();
        }

        if (_config.EnableDlssOptimalSettingsProbe.Value)
        {
            RunDlssOptimalSettingsProbe();
        }

        if (_config.EnableDlssFeatureCreateProbe.Value)
        {
            RunDlssFeatureCreateProbe();
        }
    }

    public override bool Unload()
    {
        if (_log is not null)
        {
            RenderThreadSmokeTest.Uninstall(_log);
            FrameResourceProbe.Uninstall(_log);
            RenderScaleControlProbe.Uninstall(_log);
            UpscalerStateProbe.Uninstall(_log);
            HarmonyCallProbe.Uninstall(_log);
            CustomPostProcessRenderEntryProbe.Uninstall(_log);
            CustomPostProcessRegistrationProbe.Uninstall(_log);
        }

        _log?.LogInfo($"{PluginInfo.Name} unloaded.");
        return true;
    }

    private void RunNativeBridgeSmokeTest()
    {
        if (_log is null)
        {
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        _log.LogInfo($"Native bridge API version: {bridge.GetBridgeApiVersion()}");
        _log.LogInfo($"Native bridge version: {bridge.GetBridgeVersion()}");
        _log.LogInfo($"Native bridge diagnostic status: {bridge.GetDiagnosticStatus()}");
    }

    private void RunRenderThreadSmokeTest()
    {
        if (_log is null)
        {
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        RenderThreadSmokeTest.Run(_log, bridge);
    }

    private void RunD3D11TextureProbe()
    {
        if (_log is null)
        {
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        D3D11TextureProbe.Run(_log, bridge);
    }

    private void RunFrameResourceProbe()
    {
        if (_log is null)
        {
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        FrameResourceProbe.Install(
            _log,
            bridge,
            _config?.EnableFrameResourceProbe.Value ?? false,
            _config?.EnableDlssEvaluateInputProbe.Value ?? false,
            _config?.EnableDlssEvaluateProbe.Value ?? false,
            _config?.EnableDlssPersistentEvaluateProbe.Value ?? false,
            _config?.EnableDlssSuperResolutionInputProbe.Value ?? false,
            _config?.EnableDlssSuperResolutionEvaluateProbe.Value ?? false,
            _config?.EnableDlssSuperResolutionPersistentEvaluateProbe.Value ?? false,
            _config?.EnableDlssSuperResolutionFrameSequenceEvaluateProbe.Value ?? false,
            _config?.EnableDlssVisibleWritebackProbe.Value ?? false,
            _config?.EnableDlss.Value ?? false,
            _config?.EnableDlssUserRenderingNoEvaluateProbe.Value ?? false,
            _config?.EnableDlssCachedTupleDriverProbe.Value ?? false,
            _config?.KeepDlssVisibleWritebackProbeRunning.Value ?? false,
            CreateDlssEvaluateProbeSettings(),
            _config?.EnableRenderGraphDiagnosticPass.Value ?? false,
            _config?.EnableExistingRenderFuncProbe.Value ?? false,
            _config?.EnableResourceMaterializationProbe.Value ?? false,
            _config?.EnableRenderGraphPassBoundaryProbe.Value ?? false,
            _config?.EnableRenderGraphPassMapProbe.Value ?? false,
            _config?.EnableRenderGraphPassListProbe.Value ?? false,
            _config?.EnableRenderGraphPassResourceDeclarationProbe.Value ?? false,
            _config?.EnableRenderGraphPassDataSnapshotProbe.Value ?? false,
            _config?.EnableRenderGraphPassRenderFuncMetadataProbe.Value ?? false,
            _config?.EnableRenderGraphCompiledPassInfoProbe.Value ?? false,
            _config?.EnableRenderGraphExecuteDelegateProbe.Value ?? false,
            _config?.EnableNativeRenderFuncEntryProbe.Value ?? false,
            _config?.EnableNativeRenderFuncArgumentProbe.Value ?? false,
            _config?.EnableNativeRenderFuncResourceIdentityProbe.Value ?? false,
            _config?.EnableNativeRenderFuncResourceTupleProbe.Value ?? false,
            _config?.EnableNativeRenderFuncResourceResolveProbe.Value ?? false,
            _config?.EnableNativeRenderFuncResourceNativePointerProbe.Value ?? false,
            _config?.EnableRenderGraphGetTextureProbe.Value ?? true,
            _config?.EnableDlssPassResourceProbe.Value ?? false);
    }

    private void RunCustomPostProcessRegistrationProbe()
    {
        if (_log is null)
        {
            return;
        }

        CustomPostProcessRegistrationProbe.Install(_log);
    }

    private void RunCustomPostProcessRenderEntryProbe()
    {
        if (_log is null)
        {
            return;
        }

        CustomPostProcessRenderEntryProbe.Install(_log);
    }

    private ConfigFile CreateModConfigFile()
    {
        var configPath = Path.Combine(ResolvePluginDirectory(), ModConfigFileName);
        _log?.LogInfo($"Using mod config: {configPath}");
        return new ConfigFile(configPath, true);
    }

    private void RunDlssRuntimeProbe()
    {
        if (_log is null || _config is null)
        {
            return;
        }

        var runtimePath = ResolveConfiguredRuntimePath(_config.DlssRuntimePath.Value);
        if (string.IsNullOrWhiteSpace(runtimePath))
        {
            _log.LogWarning("DLSS runtime probe skipped: DLSS.DlssRuntimePath is empty.");
            return;
        }

        if (!File.Exists(runtimePath))
        {
            _log.LogWarning($"DLSS runtime probe skipped: file does not exist: {runtimePath}");
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        var loaded = bridge.ProbeDlssRuntime(runtimePath);
        var status = bridge.GetDlssRuntimeProbeStatus();
        if (loaded)
        {
            _log.LogInfo($"DLSS runtime probe succeeded: {status}");
        }
        else
        {
            _log.LogWarning($"DLSS runtime probe failed: {status}");
        }
    }

    private void RunDlssInitQueryProbe()
    {
        if (_log is null || _config is null)
        {
            return;
        }

        var runtimePath = ResolveConfiguredRuntimePath(_config.DlssRuntimePath.Value);
        if (string.IsNullOrWhiteSpace(runtimePath))
        {
            _log.LogWarning("DLSS init/query probe skipped: DLSS.DlssRuntimePath is empty.");
            return;
        }

        if (!File.Exists(runtimePath))
        {
            _log.LogWarning($"DLSS init/query probe skipped: file does not exist: {runtimePath}");
            return;
        }

        if (!TryParseApplicationId(_config.DlssApplicationId.Value, out var applicationId))
        {
            _log.LogWarning($"DLSS init/query probe skipped: DLSS.DlssApplicationId is invalid: {_config.DlssApplicationId.Value}");
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        var pluginDirectory = ResolvePluginDirectory();
        DlssInitQueryProbe.Run(_log, bridge, runtimePath, pluginDirectory, applicationId);
    }

    private void RunDlssFeatureCreateProbe()
    {
        if (_log is null || _config is null)
        {
            return;
        }

        var runtimePath = ResolveConfiguredRuntimePath(_config.DlssRuntimePath.Value);
        if (string.IsNullOrWhiteSpace(runtimePath))
        {
            _log.LogWarning("DLSS feature create probe skipped: DLSS.DlssRuntimePath is empty.");
            return;
        }

        if (!File.Exists(runtimePath))
        {
            _log.LogWarning($"DLSS feature create probe skipped: file does not exist: {runtimePath}");
            return;
        }

        if (!TryParseApplicationId(_config.DlssApplicationId.Value, out var applicationId))
        {
            _log.LogWarning($"DLSS feature create probe skipped: DLSS.DlssApplicationId is invalid: {_config.DlssApplicationId.Value}");
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        var pluginDirectory = ResolvePluginDirectory();
        DlssFeatureCreateProbe.Run(_log, bridge, runtimePath, pluginDirectory, applicationId, _config.QualityMode.Value);
    }

    private void RunDlssOptimalSettingsProbe()
    {
        if (_log is null || _config is null)
        {
            return;
        }

        var runtimePath = ResolveConfiguredRuntimePath(_config.DlssRuntimePath.Value);
        if (string.IsNullOrWhiteSpace(runtimePath))
        {
            _log.LogWarning("DLSS optimal-settings probe skipped: DLSS.DlssRuntimePath is empty.");
            return;
        }

        if (!File.Exists(runtimePath))
        {
            _log.LogWarning($"DLSS optimal-settings probe skipped: file does not exist: {runtimePath}");
            return;
        }

        if (!TryParseApplicationId(_config.DlssApplicationId.Value, out var applicationId))
        {
            _log.LogWarning($"DLSS optimal-settings probe skipped: DLSS.DlssApplicationId is invalid: {_config.DlssApplicationId.Value}");
            return;
        }

        var bridge = TryLoadNativeBridge();
        if (bridge is null)
        {
            return;
        }

        var pluginDirectory = ResolvePluginDirectory();
        DlssOptimalSettingsProbe.Run(_log, bridge, runtimePath, pluginDirectory, applicationId, _config.QualityMode.Value);
    }

    private DlssEvaluateProbeSettings CreateDlssEvaluateProbeSettings()
    {
        if (_config is null)
        {
            return default;
        }

        var runtimePath = ResolveConfiguredRuntimePath(_config.DlssRuntimePath.Value);
        if ((_config.EnableDlss.Value || _config.EnableDlssEvaluateProbe.Value || _config.EnableDlssPersistentEvaluateProbe.Value || _config.EnableDlssSuperResolutionEvaluateProbe.Value || _config.EnableDlssSuperResolutionPersistentEvaluateProbe.Value || _config.EnableDlssSuperResolutionFrameSequenceEvaluateProbe.Value || _config.EnableDlssVisibleWritebackProbe.Value) && string.IsNullOrWhiteSpace(runtimePath))
        {
            _log?.LogWarning("DLSS rendering/evaluate/persistent/Super Resolution evaluate/persistent/frame-sequence/visible write-back path is enabled, but DLSS.DlssRuntimePath is empty. The native path will report skipped until a runtime path is configured.");
        }

        if (!TryParseApplicationId(_config.DlssApplicationId.Value, out var applicationId))
        {
            _log?.LogWarning($"DLSS evaluate probe will use application id 0 because DLSS.DlssApplicationId is invalid: {_config.DlssApplicationId.Value}");
        }

        var featureFlags = _config.AutoExposure.Value ? 1 << 6 : 0;
        return new DlssEvaluateProbeSettings(
            runtimePath,
            ResolvePluginDirectory(),
            applicationId,
            ResolveDlssPerfQualityValue(_config.QualityMode.Value),
            featureFlags,
            _config.Sharpness.Value,
            _config.ResetOnCameraCut.Value ? 1 : 0);
    }

    private static int ResolveDlssPerfQualityValue(string qualityMode)
    {
        var normalized = (qualityMode ?? string.Empty).Trim().Replace("-", string.Empty).Replace("_", string.Empty);
        return normalized.ToLowerInvariant() switch
        {
            "dlaa" => 5,
            "ultraperformance" => 3,
            "performance" => 0,
            "balanced" => 1,
            _ => 2,
        };
    }

    private static string ResolveConfiguredRuntimePath(string configuredPath)
    {
        if (string.IsNullOrWhiteSpace(configuredPath))
        {
            return string.Empty;
        }

        var trimmed = configuredPath.Trim().Trim('"');
        if (Path.IsPathRooted(trimmed))
        {
            return trimmed;
        }

        var pluginDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        return string.IsNullOrWhiteSpace(pluginDirectory)
            ? trimmed
            : Path.Combine(pluginDirectory, trimmed);
    }

    private static string ResolvePluginDirectory()
    {
        return Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? ".";
    }

    private static bool TryParseApplicationId(string configuredValue, out ulong applicationId)
    {
        applicationId = 0;
        if (string.IsNullOrWhiteSpace(configuredValue))
        {
            return true;
        }

        var trimmed = configuredValue.Trim();
        if (trimmed.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
        {
            return ulong.TryParse(
                trimmed.Substring(2),
                System.Globalization.NumberStyles.HexNumber,
                System.Globalization.CultureInfo.InvariantCulture,
                out applicationId);
        }

        return ulong.TryParse(
            trimmed,
            System.Globalization.NumberStyles.Integer,
            System.Globalization.CultureInfo.InvariantCulture,
            out applicationId);
    }

    private NativeBridge? TryLoadNativeBridge()
    {
        if (_nativeBridge is not null)
        {
            return _nativeBridge;
        }

        if (_log is null)
        {
            return null;
        }

        var pluginDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        if (string.IsNullOrWhiteSpace(pluginDirectory))
        {
            _log.LogWarning("Could not resolve plugin directory.");
            return null;
        }

        var bridgePath = Path.Combine(pluginDirectory, "VrisingDLSS.Native.dll");
        var bridge = new NativeBridge(_log);
        if (!bridge.TryLoad(bridgePath))
        {
            return null;
        }

        _nativeBridge = bridge;
        return _nativeBridge;
    }

    private void WarnIfReferenceBinariesAreInstalled()
    {
        if (_log is null)
        {
            return;
        }

        var pluginDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        if (string.IsNullOrWhiteSpace(pluginDirectory))
        {
            return;
        }

        var disallowedFiles = new[]
        {
            "PDPerfPlugin.dll",
            "PerfMod.dll"
        };

        foreach (var fileName in disallowedFiles)
        {
            var path = Path.Combine(pluginDirectory, fileName);
            if (File.Exists(path))
            {
                _log.LogWarning($"{fileName} was found next to this plugin. It is not used by this clean-room implementation and should not be redistributed with it.");
            }
        }
    }
}
