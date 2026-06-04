param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root,
    [string]$Configuration = "Release",
    [switch]$AllowMissingBepInEx,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

function Resolve-RequiredPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing $Description`: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

$resolvedRoot = Resolve-RequiredPath -Path $Root -Description "repository root"
$resolvedGamePath = Resolve-RequiredPath -Path $GamePath -Description "V Rising game path"

$exePath = Join-Path $resolvedGamePath "VRising.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    Write-Warning "VRising.exe was not found under $resolvedGamePath. Continuing because -GamePath may point to a mod-manager profile layout."
}

$bepInExPath = Join-Path $resolvedGamePath "BepInEx"
if (-not (Test-Path -LiteralPath $bepInExPath) -and -not $AllowMissingBepInEx) {
    throw "BepInEx was not found at $bepInExPath. Install BepInExPack V Rising first, or pass -AllowMissingBepInEx to stage files only."
}

$pluginDll = Resolve-RequiredPath `
    -Path (Join-Path $resolvedRoot "src\VrisingDLSS.Plugin\bin\$Configuration\net6.0\VrisingDLSS.Plugin.dll") `
    -Description "plugin build output"

$nativeDll = Resolve-RequiredPath `
    -Path (Join-Path $resolvedRoot "artifacts\native-build\$Configuration\VrisingDLSS.Native.dll") `
    -Description "native bridge build output"

$pluginsPath = Join-Path $resolvedGamePath "BepInEx\plugins"
$targetPath = Join-Path $pluginsPath "VrisingDLSS"

$copyPlan = @(
    [pscustomobject]@{
        Source = $pluginDll
        Destination = Join-Path $targetPath "VrisingDLSS.Plugin.dll"
    },
    [pscustomobject]@{
        Source = $nativeDll
        Destination = Join-Path $targetPath "VrisingDLSS.Native.dll"
    }
)

$runtimeReadme = @"
VrisingDLSS runtime folder.

This folder intentionally does not include:
- PureDark binaries.
- NVIDIA nvngx_dlss.dll.
- V Rising game files.

This diagnostic scaffold does not evaluate DLSS yet.
"@

$forbiddenNearbyNames = @(
    "PDPerfPlugin.dll",
    "PerfMod.dll",
    "nvngx_dlss.dll",
    "sl.interposer.dll",
    "sl.common.dll",
    "sl.dlss.dll",
    "nvngx_dlssg.dll"
)

$warnings = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $pluginsPath) {
    Get-ChildItem -LiteralPath $pluginsPath -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $forbiddenNearbyNames -contains $_.Name } |
        ForEach-Object {
            $warnings.Add("Found third-party/runtime file near plugin tree: $($_.FullName)")
        }
}

if ($DryRun) {
    [pscustomobject]@{
        Mode = "DryRun"
        GamePath = $resolvedGamePath
        TargetPath = $targetPath
        Files = $copyPlan
        Warnings = $warnings
        LaunchesGame = $false
    }
    return
}

New-Item -ItemType Directory -Force -Path $targetPath | Out-Null

foreach ($item in $copyPlan) {
    Copy-Item -LiteralPath $item.Source -Destination $item.Destination -Force
}

Set-Content -LiteralPath (Join-Path $targetPath "README-runtime.txt") -Encoding UTF8 -Value $runtimeReadme

[pscustomobject]@{
    Mode = "Installed"
    GamePath = $resolvedGamePath
    TargetPath = $targetPath
    Files = $copyPlan
    Warnings = $warnings
    LaunchesGame = $false
}
