param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path
)

$ErrorActionPreference = "Stop"

$releaseRoots = @(
    (Join-Path $Root "src"),
    (Join-Path $Root "package"),
    (Join-Path $Root "dist\thunderstore-staging")
)

$forbiddenPatterns = @(
    "PDPerfPlugin.dll",
    "PerfMod.dll",
    "nvngx_dlss.dll",
    "sl.interposer.dll",
    "sl.common.dll",
    "sl.dlss.dll",
    "nvngx_dlssg.dll",
    "Assembly-CSharp.dll",
    "GameAssembly.dll",
    "UnityPlayer.dll",
    "UnityEngine.CoreModule.dll",
    "Unity.RenderPipelines.Core.Runtime.dll",
    "Unity.RenderPipelines.HighDefinition.Runtime.dll",
    "ProjectM.dll"
)

$forbiddenExtensions = @(".exe", ".zip", ".7z", ".rar")
$allowedProjectDlls = @(
    "VrisingDLSS.Plugin.dll",
    "VrisingDLSS.Native.dll"
)
$violations = New-Object System.Collections.Generic.List[string]

foreach ($releaseRoot in $releaseRoots) {
    if (-not (Test-Path $releaseRoot)) {
        continue
    }

    Get-ChildItem -LiteralPath $releaseRoot -Recurse -Force -File | ForEach-Object {
        if ($_.Extension.ToLowerInvariant() -eq ".dll" -and -not ($allowedProjectDlls -contains $_.Name)) {
            $violations.Add("Unexpected DLL in release tree: $($_.FullName)")
        }

        if ($forbiddenExtensions -contains $_.Extension.ToLowerInvariant()) {
            $violations.Add("Binary-like file in release tree: $($_.FullName)")
        }

        if ($forbiddenPatterns -contains $_.Name) {
            $violations.Add("Forbidden third-party runtime in release tree: $($_.FullName)")
        }
    }
}

$manifestPath = Join-Path $Root "package\thunderstore\manifest.json"
if (Test-Path $manifestPath) {
    $null = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} else {
    $violations.Add("Missing Thunderstore manifest: $manifestPath")
}

$iconPath = Join-Path $Root "package\thunderstore\icon.png"
if (-not (Test-Path $iconPath)) {
    Write-Warning "Thunderstore icon.png is missing; package is not upload-ready."
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Release boundary check passed."
