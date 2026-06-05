param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

function Get-ConfigValueMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $map = @{}
    $section = ""
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            $section = $trimmed.Trim("[", "]")
            continue
        }

        $parts = $trimmed -split "=", 2
        if ($parts.Count -ne 2) {
            continue
        }

        $key = if ([string]::IsNullOrWhiteSpace($section)) {
            $parts[0].Trim()
        } else {
            "$section.$($parts[0].Trim())"
        }

        $map[$key] = $parts[1].Trim()
    }

    return $map
}

function Test-ConfigTrue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    return $Map.ContainsKey($Key) -and $Map[$Key].Equals("true", [StringComparison]::OrdinalIgnoreCase)
}

function Get-ConfiguredStage {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssEvaluateInputProbe") { return "dlss-evaluate-inputs" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssPassResourceProbe") { return "dlsspass-resource" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssFeatureCreateProbe") { return "dlss-feature-create" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssInitQueryProbe") { return "dlss-init-query" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableDlssRuntimeProbe") { return "dlss-runtime" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableFrameResourceProbe") { return "frame-resource" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableUpscalerStateProbe") { return "upscaler-state" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableHarmonyCallProbe") { return "harmony-call" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableD3D11TextureProbe") { return "d3d11" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableRenderThreadSmokeTest") { return "render-thread" }
    if (Test-ConfigTrue -Map $Config -Key "Diagnostics.EnableNativeBridgeSmokeTest") { return "native" }
    return "loader"
}

function Get-FirstStageStatus {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Results,

        [Parameter(Mandatory = $true)]
        [string]$StagePrefix
    )

    $match = $Results | Where-Object { $_.Stage -like "$StagePrefix*" } | Select-Object -First 1
    if ($match) {
        return $match.Status
    }

    return "Missing"
}

function Get-NextRecommendation {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Inspect,

        [Parameter(Mandatory = $true)]
        [bool]$PluginInstalled,

        [Parameter(Mandatory = $true)]
        [bool]$ConfigExists,

        [Parameter(Mandatory = $true)]
        [object[]]$LogResults
    )

    if (-not $Inspect.GameInstalled) {
        return "Provide a valid -GamePath that contains VRising.exe."
    }

    if (-not $Inspect.BepInExInstalled) {
        return "powershell -ExecutionPolicy Bypass -File scripts\install-bepinexpack.ps1 -GamePath `"$($Inspect.GamePath)`" -DryRun"
    }

    if (-not $PluginInstalled) {
        return "powershell -ExecutionPolicy Bypass -File scripts\install-local-package.ps1 -GamePath `"$($Inspect.GamePath)`" -DryRun"
    }

    if (-not $ConfigExists) {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage loader"
    }

    if (-not $Inspect.LogExists) {
        return "Launch the staged local/offline test once, exit after BepInEx starts, then run scripts\analyze-bepinex-log.ps1."
    }

    $loader = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 1"
    if ($loader -ne "Pass") {
        return "Keep Stage loader config, rerun the local/offline test, then inspect BepInEx\LogOutput.log."
    }

    $evaluateInputs = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 8A"
    if ($evaluateInputs -eq "Pass") {
        return "Stage 8A evaluate-input probing passed. Next engineering step is a guarded SDK-wrapper DLSS evaluate call with DLSS disabled by default."
    }

    if ($evaluateInputs -eq "Blocked") {
        return "Stage 8A is blocked until color/output/depth/motion native textures are present in the same frame; try scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-evaluate-inputs -DurationSeconds 240 and enter a local/private gameplay scene."
    }

    if ($evaluateInputs -eq "Fail") {
        return "Stage 8A evaluate-input probing reached native validation but failed. Preserve the status line and inspect D3D11 resource/device/dimension mismatch."
    }

    if ($evaluateInputs -eq "Partial") {
        return "Stage 8A started but did not produce pass/blocked/fail evidence. If this was the main menu, run scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-evaluate-inputs -DurationSeconds 240 and enter a local/private gameplay scene, then preserve the archived log."
    }

    $hook = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 2"
    if ($hook -ne "Pass") {
        return "Keep Stage loader config until the hook probe finds CustomVignette; review Hook target log lines."
    }

    $upscaler = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 2B"
    if ($upscaler -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage upscaler-state"
    }

    $native = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 4"
    if ($native -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage native"
    }

    $renderThread = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5A"
    if ($renderThread -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage render-thread"
    }

    $d3d11 = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5B"
    if ($d3d11 -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage d3d11"
    }

    $frame = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5C"
    if ($frame -ne "Pass") {
        return "powershell -ExecutionPolicy Bypass -File scripts\write-diagnostic-config.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage frame-resource"
    }

    $runtime = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 5D"
    if ($runtime -ne "Pass") {
        return "Set DLSS.DlssRuntimePath, then run write-diagnostic-config.ps1 -Stage dlss-runtime."
    }

    $initQuery = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 6"
    if ($initQuery -eq "Blocked") {
        return "Stage 6 is blocked until the native bridge has an explicit NVIDIA SDK wrapper integration path; repeating the same dlss-init-query diagnostic with only nvngx_dlss.dll will not advance it."
    }

    if ($initQuery -ne "Pass") {
        return "Set DLSS.DlssRuntimePath/DlssApplicationId, then run write-diagnostic-config.ps1 -Stage dlss-init-query."
    }

    $featureCreate = Get-FirstStageStatus -Results $LogResults -StagePrefix "Stage 7"
    if ($featureCreate -eq "Blocked") {
        return "Stage 7 feature create is blocked until the native bridge is built with the optional NVIDIA SDK wrapper path."
    }

    if ($featureCreate -ne "Pass") {
        return "Use the optional SDK-wrapper native build, then run write-diagnostic-config.ps1 -Stage dlss-feature-create."
    }

    return "Run scripts\run-vrising-diagnostic.ps1 -GamePath `"$($Inspect.GamePath)`" -Stage dlss-evaluate-inputs -DurationSeconds 240 in a local/private gameplay scene to prove the real frame resources can enter the native evaluate ABI."
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$inspectScript = Join-Path $resolvedRoot "scripts\inspect-vrising-install.ps1"
$analyzeScript = Join-Path $resolvedRoot "scripts\analyze-bepinex-log.ps1"

$inspectJson = & $inspectScript -GamePath $GamePath -Json
$inspect = $inspectJson | ConvertFrom-Json

$pluginDir = Join-Path $inspect.GamePath "BepInEx\plugins\VrisingDLSS"
$pluginDll = Join-Path $pluginDir "VrisingDLSS.Plugin.dll"
$nativeDll = Join-Path $pluginDir "VrisingDLSS.Native.dll"
$pluginInstalled = (Test-Path -LiteralPath $pluginDll) -and (Test-Path -LiteralPath $nativeDll)

$configPath = Join-Path $inspect.GamePath "BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg"
$configExists = Test-Path -LiteralPath $configPath
$config = Get-ConfigValueMap -Path $configPath
$configuredStage = if ($configExists) { Get-ConfiguredStage -Config $config } else { "missing" }

$logResults = @(& $analyzeScript -GamePath $inspect.GamePath)
$recommendation = Get-NextRecommendation `
    -Inspect $inspect `
    -PluginInstalled $pluginInstalled `
    -ConfigExists $configExists `
    -LogResults $logResults

[pscustomobject]@{
    GamePath = $inspect.GamePath
    GameVersion = $inspect.GameVersion
    BepInExInstalled = $inspect.BepInExInstalled
    PluginInstalled = $pluginInstalled
    ConfigPath = $configPath
    ConfigExists = $configExists
    ConfiguredStage = $configuredStage
    InteropGenerated = $inspect.InteropGenerated
    LogExists = $inspect.LogExists
    LogPath = $inspect.LogPath
    StageResults = $logResults
    NextRecommendation = $recommendation
    LaunchesGame = $false
}
