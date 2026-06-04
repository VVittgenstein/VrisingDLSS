param(
    [ValidateSet(
        "loader",
        "native",
        "render-thread",
        "d3d11",
        "frame-resource",
        "dlss-runtime",
        "dlss-init-query"
    )]
    [string]$Stage = "loader",

    [string]$GamePath,
    [string]$OutputPath,
    [string]$DlssRuntimePath = "",
    [string]$DlssApplicationId = "0",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$pluginGuid = "dev.vrisingdlss.plugin"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    if ([string]::IsNullOrWhiteSpace($GamePath)) {
        throw "Pass -GamePath or -OutputPath."
    }

    $OutputPath = Join-Path $GamePath "BepInEx\config\$pluginGuid.cfg"
}

function New-ConfigMap {
    $config = [ordered]@{
        General = [ordered]@{
            EnablePlugin = "true"
        }
        Diagnostics = [ordered]@{
            EnableNativeBridgeSmokeTest = "false"
            EnableRenderThreadSmokeTest = "false"
            EnableD3D11TextureProbe = "false"
            EnableFrameResourceProbe = "false"
            EnableDlssRuntimeProbe = "false"
            EnableDlssInitQueryProbe = "false"
            EnableHookProbe = "true"
            EnableHarmonyCallProbe = "false"
            ShowOverlay = "true"
        }
        DLSS = [ordered]@{
            DlssRuntimePath = $DlssRuntimePath
            DlssApplicationId = $DlssApplicationId
            QualityMode = "Quality"
            Sharpness = "0"
        }
    }

    return ,$config
}

function Set-SwitchesForStage {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [string]$StageName
    )

    switch ($StageName) {
        "loader" {
        }
        "native" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
        }
        "render-thread" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableRenderThreadSmokeTest = "true"
        }
        "d3d11" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableRenderThreadSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
        }
        "frame-resource" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableHarmonyCallProbe = "true"
            $Config.Diagnostics.EnableFrameResourceProbe = "true"
        }
        "dlss-runtime" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
        }
        "dlss-init-query" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssInitQueryProbe = "true"
        }
    }
}

function ConvertTo-BepInExConfigText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($sectionName in $Config.Keys) {
        [void]$lines.Add("[$sectionName]")
        foreach ($key in $Config[$sectionName].Keys) {
            [void]$lines.Add("$key = $($Config[$sectionName][$key])")
        }
        [void]$lines.Add("")
    }

    $lines -join [Environment]::NewLine
}

$config = New-ConfigMap
Set-SwitchesForStage -Config $config -StageName $Stage
$text = ConvertTo-BepInExConfigText -Config $config

if ($DryRun) {
    [pscustomobject]@{
        Mode = "DryRun"
        Stage = $Stage
        OutputPath = $OutputPath
        Config = $text
        LaunchesGame = $false
    }
    return
}

$directory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Set-Content -LiteralPath $OutputPath -Encoding UTF8 -Value $text

[pscustomobject]@{
    Mode = "Written"
    Stage = $Stage
    OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path
    LaunchesGame = $false
}
