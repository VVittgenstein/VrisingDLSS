param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$Configuration = "Release",
    [switch]$AllowMissingBinaries
)

$ErrorActionPreference = "Stop"

$packageRoot = Join-Path $Root "package\thunderstore"
$distRoot = Join-Path $Root "dist"
$stagingRoot = Join-Path $distRoot "thunderstore-staging"
$manifestPath = Join-Path $packageRoot "manifest.json"
$iconPath = Join-Path $packageRoot "icon.png"
$readmePath = Join-Path $packageRoot "README.md"
$changelogPath = Join-Path $packageRoot "CHANGELOG.md"
$noticesPath = Join-Path $packageRoot "ThirdPartyNotices.md"
$configTemplatePath = Join-Path $packageRoot "VrisingDLSS.cfg"

foreach ($requiredPath in @($manifestPath, $iconPath, $readmePath, $configTemplatePath)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Missing required Thunderstore package file: $requiredPath"
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$version = $manifest.version_number
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "manifest.json has no version_number."
}

$pluginDll = Join-Path $Root "src\VrisingDLSS.Plugin\bin\$Configuration\net6.0\VrisingDLSS.Plugin.dll"
$nativeDll = Join-Path $Root "artifacts\native-build\$Configuration\VrisingDLSS.Native.dll"

$missing = @()
if (-not (Test-Path $pluginDll)) { $missing += $pluginDll }
if (-not (Test-Path $nativeDll)) { $missing += $nativeDll }

if ($missing.Count -gt 0 -and -not $AllowMissingBinaries) {
    $message = "Missing build outputs:`n" + ($missing -join "`n") + "`nBuild first or pass -AllowMissingBinaries to stage metadata only."
    throw $message
}

if (Test-Path $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null

Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagingRoot "manifest.json")
Copy-Item -LiteralPath $iconPath -Destination (Join-Path $stagingRoot "icon.png")
Copy-Item -LiteralPath $readmePath -Destination (Join-Path $stagingRoot "README.md")
if (Test-Path $changelogPath) {
    Copy-Item -LiteralPath $changelogPath -Destination (Join-Path $stagingRoot "CHANGELOG.md")
}
if (Test-Path $noticesPath) {
    Copy-Item -LiteralPath $noticesPath -Destination (Join-Path $stagingRoot "ThirdPartyNotices.md")
}

$pluginFolder = Join-Path $stagingRoot "BepInEx\plugins\VrisingDLSS"
New-Item -ItemType Directory -Force -Path $pluginFolder | Out-Null

if (Test-Path $pluginDll) {
    Copy-Item -LiteralPath $pluginDll -Destination (Join-Path $pluginFolder "VrisingDLSS.Plugin.dll")
}
if (Test-Path $nativeDll) {
    Copy-Item -LiteralPath $nativeDll -Destination (Join-Path $pluginFolder "VrisingDLSS.Native.dll")
}
Copy-Item -LiteralPath $configTemplatePath -Destination (Join-Path $pluginFolder "VrisingDLSS.cfg")

Set-Content -LiteralPath (Join-Path $pluginFolder "README-runtime.txt") -Encoding UTF8 -Value @"
VrisingDLSS runtime folder.

This package intentionally does not include:
- PureDark binaries.
- NVIDIA nvngx_dlss.dll.
- V Rising game files.

If this build supports DLSS runtime loading, init/query, feature create/release, or evaluate-input diagnostics, follow the project README for how to provide a production nvngx_dlss.dll yourself when a stage requires it.
"@

& (Join-Path $Root "scripts\check-release-boundary.ps1") -Root $Root

$zipPath = Join-Path $distRoot ("VrisingDLSS-$version-thunderstore.zip")
if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $zipPath -Force
& (Join-Path $Root "scripts\validate-thunderstore-package.ps1") -Root $Root -PackagePath $zipPath
Write-Host "Created package: $zipPath"
