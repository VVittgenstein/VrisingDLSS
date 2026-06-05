param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,
    [string]$HighDefinitionInteropPath,
    [string]$IlspyCmdPath = "C:\Software\dotnet-tools\ilspycmd.exe",
    [string]$DotnetRoot = "C:\Software\dotnet",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GamePath)) {
    throw "GamePath does not exist: $GamePath"
}

$resolvedGamePath = (Resolve-Path $GamePath).Path
$dataPath = Join-Path $resolvedGamePath "VRising_Data"
$metadataPath = Join-Path $dataPath "il2cpp_data\Metadata\global-metadata.dat"
$pluginsPath = Join-Path $dataPath "Plugins\x86_64"
$interopRoot = Join-Path $resolvedGamePath "BepInEx\interop"

if ([string]::IsNullOrWhiteSpace($HighDefinitionInteropPath)) {
    $HighDefinitionInteropPath = Join-Path $interopRoot "Unity.RenderPipelines.HighDefinition.Runtime.dll"
}

if (-not (Test-Path $metadataPath)) {
    throw "IL2CPP metadata file was not found: $metadataPath"
}

$terms = @(
    @{ Area = "Hook"; Term = "CustomVignette" },
    @{ Area = "Hook"; Term = "DynamicResolutionHandler" },
    @{ Area = "Hook"; Term = "HDRenderPipeline" },
    @{ Area = "Hook"; Term = "HDCamera" },
    @{ Area = "Hook"; Term = "SkyManager" },
    @{ Area = "Resource"; Term = "_CameraDepthTexture" },
    @{ Area = "Resource"; Term = "_CameraMotionVectorsTexture" },
    @{ Area = "NativeUnity"; Term = "UnityEngine.NVIDIA" },
    @{ Area = "NativeUnity"; Term = "DLSSContext" },
    @{ Area = "NativeUnity"; Term = "DLSSCommandInitializationData" },
    @{ Area = "NativeUnity"; Term = "DLSSTextureTable" },
    @{ Area = "NativeUnity"; Term = "DLSSQuality" },
    @{ Area = "NativeUnity"; Term = "NVUnityPlugin" },
    @{ Area = "NativeUnity"; Term = "NGX" },
    @{ Area = "NativeUnity"; Term = "nvsdk_ngx" },
    @{ Area = "Upscaler"; Term = "DLSS" },
    @{ Area = "Upscaler"; Term = "Deep Learning Super Sampling" },
    @{ Area = "Upscaler"; Term = "DLSS Color Mask" },
    @{ Area = "Upscaler"; Term = "DLSS destination" },
    @{ Area = "Upscaler"; Term = "XeSS" },
    @{ Area = "Upscaler"; Term = "AMD FSR 1.0" },
    @{ Area = "Upscaler"; Term = "AMD FidelityFX Super Resolution 1.0" },
    @{ Area = "AA"; Term = "Antialiasing Mode: TAA" }
)

$bytes = [System.IO.File]::ReadAllBytes($metadataPath)
$metadataText = [System.Text.Encoding]::UTF8.GetString($bytes)

$termStatus = foreach ($entry in $terms) {
    [PSCustomObject]@{
        Area = $entry.Area
        Term = $entry.Term
        Present = $metadataText.Contains($entry.Term)
    }
}

$runtimePattern = "nvngx|nvsdk|ngx|dlss|streamline|^sl\.|xess|fsr2|ffx"
$runtimeCandidates = @()

$runtimeSearchRoots = @($resolvedGamePath)
if (Test-Path $pluginsPath) {
    $runtimeSearchRoots += $pluginsPath
}

foreach ($root in $runtimeSearchRoots | Select-Object -Unique) {
    $runtimeCandidates += Get-ChildItem -LiteralPath $root -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $runtimePattern } |
        Select-Object FullName, Length, LastWriteTime
}

if (Test-Path $pluginsPath) {
    $runtimeCandidates += Get-ChildItem -LiteralPath $pluginsPath -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $runtimePattern } |
        Select-Object FullName, Length, LastWriteTime
}

function New-InteropCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Area,

        [Parameter(Mandatory = $true)]
        [string]$Term,

        [Parameter(Mandatory = $true)]
        [bool]$Present,

        [Parameter(Mandatory = $true)]
        [string]$Evidence
    )

    [PSCustomObject]@{
        Area = $Area
        Term = $Term
        Present = $Present
        Evidence = $Evidence
    }
}

function Test-AllPatterns {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text -notmatch $pattern) {
            return $false
        }
    }

    return $true
}

function Invoke-IlspyType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AssemblyPath,

        [Parameter(Mandatory = $true)]
        [string]$TypeName
    )

    if (-not (Test-Path -LiteralPath $IlspyCmdPath)) {
        return [PSCustomObject]@{
            Succeeded = $false
            Reason = "ilspycmd was not found at $IlspyCmdPath"
            Text = ""
        }
    }

    if (-not (Test-Path -LiteralPath $AssemblyPath)) {
        return [PSCustomObject]@{
            Succeeded = $false
            Reason = "Interop assembly was not found at $AssemblyPath"
            Text = ""
        }
    }

    if ((Test-Path -LiteralPath $DotnetRoot) -and [string]::IsNullOrWhiteSpace($env:DOTNET_ROOT)) {
        $env:DOTNET_ROOT = $DotnetRoot
    }

    $lines = New-Object System.Collections.Generic.List[string]
    try {
        & $IlspyCmdPath -t $TypeName $AssemblyPath 2>&1 | ForEach-Object {
            $lines.Add($_.ToString())
        }

        return [PSCustomObject]@{
            Succeeded = $true
            Reason = ""
            Text = ($lines -join [Environment]::NewLine)
        }
    } catch {
        if ($_.Exception.Message) {
            $lines.Add($_.Exception.Message)
        }

        return [PSCustomObject]@{
            Succeeded = $false
            Reason = ($lines -join [Environment]::NewLine)
            Text = ($lines -join [Environment]::NewLine)
        }
    }
}

$interopChecks = New-Object System.Collections.Generic.List[object]
$interopProbe = [PSCustomObject]@{
    AssemblyPath = $HighDefinitionInteropPath
    IlspyCmdPath = $IlspyCmdPath
    Ran = $false
    Reason = ""
}

$dlssPass = Invoke-IlspyType -AssemblyPath $HighDefinitionInteropPath -TypeName "UnityEngine.Rendering.HighDefinition.DLSSPass"
$hdRenderPipeline = Invoke-IlspyType -AssemblyPath $HighDefinitionInteropPath -TypeName "UnityEngine.Rendering.HighDefinition.HDRenderPipeline"

if ($dlssPass.Succeeded -or $hdRenderPipeline.Succeeded) {
    $interopProbe.Ran = $true
} else {
    $interopProbe.Reason = @($dlssPass.Reason, $hdRenderPipeline.Reason) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1
}

if ($dlssPass.Succeeded) {
    $dlssText = $dlssPass.Text
    $interopChecks.Add((New-InteropCheck `
        -Area "DLSSPass" `
        -Term "ViewResourceHandles source/output/depth/motionVectors/biasColorMask" `
        -Present (Test-AllPatterns -Text $dlssText -Patterns @(
                "public\s+TextureHandle\s+source",
                "public\s+TextureHandle\s+output",
                "public\s+TextureHandle\s+depth",
                "public\s+TextureHandle\s+motionVectors",
                "public\s+TextureHandle\s+biasColorMask"
            )) `
        -Evidence "UnityEngine.Rendering.HighDefinition.DLSSPass.ViewResourceHandles"))
    $interopChecks.Add((New-InteropCheck `
        -Area "DLSSPass" `
        -Term "ViewResources Texture source/output/depth/motionVectors/biasColorMask" `
        -Present (Test-AllPatterns -Text $dlssText -Patterns @(
                "Texture\s+source",
                "Texture\s+output",
                "Texture\s+depth",
                "Texture\s+motionVectors",
                "Texture\s+biasColorMask"
            )) `
        -Evidence "UnityEngine.Rendering.HighDefinition.DLSSPass.ViewResources"))
    $interopChecks.Add((New-InteropCheck `
        -Area "DLSSPass" `
        -Term "GetViewResources/CreateCameraResources/GetCameraResources helpers" `
        -Present (Test-AllPatterns -Text $dlssText -Patterns @(
                "GetViewResources",
                "CreateCameraResources",
                "GetCameraResources"
            )) `
        -Evidence "Static helper methods exist in generated interop"))
    $interopChecks.Add((New-InteropCheck `
        -Area "DLSSPass" `
        -Term "Render(Parameters, CameraResources, CommandBuffer)" `
        -Present ($dlssText -match "Render\(\s*Parameters\s+parameters,\s*CameraResources\s+resources,\s*CommandBuffer\s+cmdBuffer\s*\)") `
        -Evidence "Static shape only; this runtime hook is rejected by local crash evidence"))
}

if ($hdRenderPipeline.Succeeded) {
    $hdText = $hdRenderPipeline.Text
    foreach ($method in @(
            "SetFSRParameters",
            "GetUpscaleRes",
            "SetUpscaleFilter",
            "GetUpscaleFilter",
            "SetupDLSSForCameraDataAndDynamicResHandler",
            "GetPostprocessUpsampledOutputHandle",
            "DoDLSSPasses",
            "DoDLSSPass",
            "DoTemporalAntialiasing"
        )) {
        $interopChecks.Add((New-InteropCheck `
            -Area "HDRenderPipeline" `
            -Term $method `
            -Present ($hdText -match [regex]::Escape($method)) `
            -Evidence "UnityEngine.Rendering.HighDefinition.HDRenderPipeline generated interop"))
    }
}

$result = [PSCustomObject]@{
    GamePath = $resolvedGamePath
    MetadataPath = $metadataPath
    MetadataLength = (Get-Item -LiteralPath $metadataPath).Length
    HighDefinitionInteropPath = $HighDefinitionInteropPath
    Terms = @($termStatus)
    InteropProbe = $interopProbe
    InteropChecks = @($interopChecks.ToArray())
    RuntimeCandidates = @($runtimeCandidates | Sort-Object FullName -Unique)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result | Select-Object GamePath, MetadataPath, MetadataLength | Format-List
    "Metadata term probe:"
    $termStatus | Format-Table -AutoSize
    "Runtime DLL candidates:"
    if ($runtimeCandidates.Count -gt 0) {
        $runtimeCandidates | Sort-Object FullName -Unique | Format-Table -AutoSize
    } else {
        "None found."
    }
    "Generated HDRP interop probe:"
    $interopProbe | Format-List
    if ($interopChecks.Count -gt 0) {
        $interopChecks | Format-Table -AutoSize
    } else {
        "No interop checks ran."
    }
}
