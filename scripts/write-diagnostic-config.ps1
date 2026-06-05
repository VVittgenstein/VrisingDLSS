param(
    [ValidateSet(
        "loader",
        "native",
        "harmony-call",
        "render-thread",
        "d3d11",
        "frame-resource",
        "upscaler-state",
        "dlss-runtime",
        "dlss-init-query",
        "dlss-feature-create",
        "dlss-evaluate-inputs",
        "dlss-super-resolution-inputs",
        "dlss-super-resolution-evaluate",
        "dlss-super-resolution-persistent-evaluate",
        "dlss-super-resolution-frame-sequence",
        "dlss-visible-writeback",
        "render-scale-control",
        "dlss-user-rendering",
        "dlss-evaluate",
        "dlss-persistent-evaluate",
        "dlsspass-resource"
    )]
    [string]$Stage = "loader",

    [string]$GamePath,
    [string]$OutputPath,
    [string]$DlssRuntimePath = "",
    [string]$DlssApplicationId = "0",
    [switch]$KeepVisibleWritebackRunning,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    if ([string]::IsNullOrWhiteSpace($GamePath)) {
        throw "Pass -GamePath or -OutputPath."
    }

    $OutputPath = Join-Path $GamePath "BepInEx\plugins\VrisingDLSS\VrisingDLSS.cfg"
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
            EnableDlssFeatureCreateProbe = "false"
            EnableDlssEvaluateInputProbe = "false"
            EnableDlssSuperResolutionInputProbe = "false"
            EnableDlssSuperResolutionEvaluateProbe = "false"
            EnableDlssSuperResolutionPersistentEvaluateProbe = "false"
            EnableDlssSuperResolutionFrameSequenceEvaluateProbe = "false"
            EnableDlssVisibleWritebackProbe = "false"
            KeepDlssVisibleWritebackProbeRunning = "false"
            EnableDlssEvaluateProbe = "false"
            EnableDlssPersistentEvaluateProbe = "false"
            EnableRenderGraphDiagnosticPass = "false"
            EnableExistingRenderFuncProbe = "false"
            EnableResourceMaterializationProbe = "false"
            EnableDlssPassResourceProbe = "false"
            EnableUpscalerStateProbe = "false"
            EnableRenderScaleControlProbe = "false"
            EnableHookProbe = "true"
            EnableHarmonyCallProbe = "false"
        }
        DLSS = [ordered]@{
            EnableDLSS = "false"
            DlssRuntimePath = $DlssRuntimePath
            DlssApplicationId = $DlssApplicationId
            QualityMode = "Performance"
            PresetMode = "Recommended"
            Sharpness = "0"
            AutoExposure = "true"
        }
        Advanced = [ordered]@{
            RenderScaleOverride = "0"
            MipBiasOverride = "Auto"
            ResetOnCameraCut = "true"
            LogLevel = "Info"
            ShowOverlay = "true"
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
        "harmony-call" {
            $Config.Diagnostics.EnableHarmonyCallProbe = "true"
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
            $Config.Diagnostics.EnableFrameResourceProbe = "true"
        }
        "upscaler-state" {
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
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
        "dlss-feature-create" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssInitQueryProbe = "true"
            $Config.Diagnostics.EnableDlssFeatureCreateProbe = "true"
        }
        "dlss-evaluate-inputs" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "dlss-super-resolution-inputs" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionInputProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "dlss-super-resolution-evaluate" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionEvaluateProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "dlss-super-resolution-persistent-evaluate" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionPersistentEvaluateProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "dlss-super-resolution-frame-sequence" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionFrameSequenceEvaluateProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "dlss-visible-writeback" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionInputProbe = "true"
            $Config.Diagnostics.EnableDlssVisibleWritebackProbe = "true"
            if ($KeepVisibleWritebackRunning) {
                $Config.Diagnostics.KeepDlssVisibleWritebackProbeRunning = "true"
            }
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "render-scale-control" {
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
            $Config.Diagnostics.EnableRenderScaleControlProbe = "true"
        }
        "dlss-user-rendering" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
            $Config.Diagnostics.EnableRenderScaleControlProbe = "true"
            $Config.DLSS.EnableDLSS = "true"
        }
        "dlss-evaluate" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionPersistentEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionFrameSequenceEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "dlss-persistent-evaluate" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssRuntimeProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionInputProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionPersistentEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssSuperResolutionFrameSequenceEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssEvaluateProbe = "true"
            $Config.Diagnostics.EnableDlssPersistentEvaluateProbe = "true"
            $Config.Diagnostics.EnableResourceMaterializationProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
        }
        "dlsspass-resource" {
            $Config.Diagnostics.EnableNativeBridgeSmokeTest = "true"
            $Config.Diagnostics.EnableD3D11TextureProbe = "true"
            $Config.Diagnostics.EnableDlssPassResourceProbe = "true"
            $Config.Diagnostics.EnableUpscalerStateProbe = "true"
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
