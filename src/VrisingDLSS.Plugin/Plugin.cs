using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using System;
using System.IO;
using System.Reflection;

namespace VrisingDLSS.Plugin;

[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
public sealed class Plugin : BasePlugin
{
    private ManualLogSource? _log;
    private ModConfig? _config;
    private NativeBridge? _nativeBridge;

    public override void Load()
    {
        _log = Log;
        _config = new ModConfig(Config);

        _log.LogInfo($"{PluginInfo.Name} {PluginInfo.Version} loaded.");
        _log.LogInfo("This is a clean-room scaffold. DLSS evaluation is not implemented yet.");

        WarnIfReferenceBinariesAreInstalled();

        if (!_config.EnablePlugin.Value)
        {
            _log.LogInfo("Plugin disabled by configuration.");
            return;
        }

        if (_config.EnableHookProbe.Value)
        {
            HookProbe.Run(_log);
        }

        if (_config.EnableHarmonyCallProbe.Value)
        {
            HarmonyCallProbe.Install(_log);
        }

        if (_config.EnableFrameResourceProbe.Value)
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
            HarmonyCallProbe.Uninstall(_log);
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

        FrameResourceProbe.Install(_log, bridge);
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
