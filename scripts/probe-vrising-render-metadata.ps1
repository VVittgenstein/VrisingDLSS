param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,
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

$result = [PSCustomObject]@{
    GamePath = $resolvedGamePath
    MetadataPath = $metadataPath
    MetadataLength = (Get-Item -LiteralPath $metadataPath).Length
    Terms = @($termStatus)
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
}
