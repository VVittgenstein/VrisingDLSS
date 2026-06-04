param(
    [string]$GamePath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-SteamInstallPath {
    $registryPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam",
        "HKCU:\SOFTWARE\Valve\Steam"
    )

    foreach ($registryPath in $registryPaths) {
        if (-not (Test-Path $registryPath)) {
            continue
        }

        $item = Get-ItemProperty $registryPath
        foreach ($property in @("InstallPath", "SteamPath")) {
            $value = $item.$property
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $candidate = $value -replace "/", "\"
                if (Test-Path $candidate) {
                    return (Resolve-Path $candidate).Path
                }
            }
        }
    }

    return $null
}

function Get-SteamLibraryPaths([string]$SteamPath) {
    $paths = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($SteamPath)) {
        $paths.Add($SteamPath)
    }

    $libraryFolders = Join-Path $SteamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $libraryFolders) {
        $content = Get-Content -LiteralPath $libraryFolders -Raw
        $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
        foreach ($match in $matches) {
            $path = $match.Groups[1].Value -replace "\\\\", "\"
            if ((Test-Path $path) -and -not $paths.Contains($path)) {
                $paths.Add((Resolve-Path $path).Path)
            }
        }
    }

    return $paths
}

function Read-AcfValue([string]$Path, [string]$Key) {
    if (-not (Test-Path $Path)) {
        return $null
    }

    $pattern = '^\s*"' + [regex]::Escape($Key) + '"\s+"([^"]+)"'
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match $pattern) {
            return $Matches[1]
        }
    }

    return $null
}

function Get-FileVersionOrNull([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path $Path)) {
        return $null
    }

    $versionInfo = (Get-Item -LiteralPath $Path).VersionInfo
    if ([string]::IsNullOrWhiteSpace($versionInfo.FileVersion)) {
        return $null
    }

    return $versionInfo.FileVersion
}

function Get-FileProductVersionOrNull([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path $Path)) {
        return $null
    }

    $versionInfo = (Get-Item -LiteralPath $Path).VersionInfo
    if ([string]::IsNullOrWhiteSpace($versionInfo.ProductVersion)) {
        return $null
    }

    return $versionInfo.ProductVersion
}

function Get-FirstLineOrNull([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path $Path)) {
        return $null
    }

    $line = Get-Content -LiteralPath $Path -TotalCount 1
    if ($null -eq $line) {
        return $null
    }

    return ("{0}" -f $line)
}

function Get-ScriptingAssemblyNames([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @()
    }

    if (-not (Test-Path $Path)) {
        return @()
    }

    try {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        return @($json.names)
    } catch {
        return @()
    }
}

$steamPath = Get-SteamInstallPath
$libraryPaths = @()
if ($steamPath) {
    $libraryPaths = @(Get-SteamLibraryPaths $steamPath)
}

$appId = "1604030"
$manifest = $null
$resolvedGamePath = $null

if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    if (Test-Path $GamePath) {
        $resolvedGamePath = (Resolve-Path $GamePath).Path
    }
} else {
    foreach ($libraryPath in $libraryPaths) {
        $candidateManifest = Join-Path $libraryPath "steamapps\appmanifest_$appId.acf"
        if (Test-Path $candidateManifest) {
            $manifest = $candidateManifest
            $installDir = Read-AcfValue $candidateManifest "installdir"
            if (-not [string]::IsNullOrWhiteSpace($installDir)) {
                $candidateGamePath = Join-Path $libraryPath "steamapps\common\$installDir"
                if (Test-Path $candidateGamePath) {
                    $resolvedGamePath = (Resolve-Path $candidateGamePath).Path
                    break
                }
            }
        }
    }
}

$exePath = if ($resolvedGamePath) { Join-Path $resolvedGamePath "VRising.exe" } else { $null }
$unityPlayerPath = if ($resolvedGamePath) { Join-Path $resolvedGamePath "UnityPlayer.dll" } else { $null }
$gameAssemblyPath = if ($resolvedGamePath) { Join-Path $resolvedGamePath "GameAssembly.dll" } else { $null }
$versionPath = if ($resolvedGamePath) { Join-Path $resolvedGamePath "VERSION" } else { $null }
$dataPath = if ($resolvedGamePath) { Join-Path $resolvedGamePath "VRising_Data" } else { $null }
$metadataPath = if ($dataPath) { Join-Path $dataPath "il2cpp_data\Metadata\global-metadata.dat" } else { $null }
$scriptingAssembliesPath = if ($dataPath) { Join-Path $dataPath "ScriptingAssemblies.json" } else { $null }
$bepInExPath = if ($resolvedGamePath) { Join-Path $resolvedGamePath "BepInEx" } else { $null }
$pluginsPath = if ($bepInExPath) { Join-Path $bepInExPath "plugins" } else { $null }
$interopPath = if ($bepInExPath) { Join-Path $bepInExPath "interop" } else { $null }
$logPath = if ($bepInExPath) { Join-Path $bepInExPath "LogOutput.log" } else { $null }

$interopAssemblies = @()
if ($interopPath -and (Test-Path $interopPath)) {
    $interopAssemblies = Get-ChildItem -LiteralPath $interopPath -Filter "*.dll" -File |
        Select-Object -ExpandProperty Name
}

$targetAssemblyNames = @(
    "Unity.RenderPipelines.HighDefinition.Runtime.dll",
    "Unity.RenderPipelines.HighDefinition.Config.Runtime.dll",
    "Unity.RenderPipelines.Core.Runtime.dll",
    "UnityEngine.CoreModule.dll",
    "UnityEngine.NVIDIAModule.dll",
    "ProjectM.dll",
    "ProjectM.Camera.dll",
    "ProjectM.Hybrid.Performance.dll",
    "Stunlock.Core.dll"
)

$scriptingAssemblies = Get-ScriptingAssemblyNames $scriptingAssembliesPath

$targetAssemblyStatus = @()
foreach ($assemblyName in $targetAssemblyNames) {
    $targetAssemblyStatus += [PSCustomObject]@{
        Name = $assemblyName
        Present = ($interopAssemblies -contains $assemblyName)
    }
}

$scriptingAssemblyStatus = @()
foreach ($assemblyName in $targetAssemblyNames) {
    $scriptingAssemblyStatus += [PSCustomObject]@{
        Name = $assemblyName
        Present = ($scriptingAssemblies -contains $assemblyName)
    }
}

$result = [PSCustomObject]@{
    SteamPath = $steamPath
    SteamLibraries = $libraryPaths
    AppManifest = $manifest
    GamePath = $resolvedGamePath
    GameInstalled = (-not [string]::IsNullOrWhiteSpace($resolvedGamePath))
    GameVersion = Get-FirstLineOrNull $versionPath
    ExePath = $exePath
    ExeExists = ($exePath -and (Test-Path $exePath))
    UnityPlayerVersion = Get-FileVersionOrNull $unityPlayerPath
    UnityPlayerProductVersion = Get-FileProductVersionOrNull $unityPlayerPath
    GameAssemblyPath = $gameAssemblyPath
    GameAssemblyExists = ($gameAssemblyPath -and (Test-Path $gameAssemblyPath))
    DataPath = $dataPath
    Il2CppMetadataPath = $metadataPath
    Il2CppMetadataExists = ($metadataPath -and (Test-Path $metadataPath))
    ScriptingAssembliesPath = $scriptingAssembliesPath
    ScriptingAssembliesExists = ($scriptingAssembliesPath -and (Test-Path $scriptingAssembliesPath))
    ScriptingAssemblyCount = $scriptingAssemblies.Count
    PlayerTargetAssemblies = $scriptingAssemblyStatus
    BepInExInstalled = ($bepInExPath -and (Test-Path $bepInExPath))
    PluginsPath = $pluginsPath
    InteropPath = $interopPath
    InteropGenerated = ($interopPath -and (Test-Path $interopPath))
    InteropAssemblyCount = $interopAssemblies.Count
    InteropTargetAssemblies = $targetAssemblyStatus
    LogPath = $logPath
    LogExists = ($logPath -and (Test-Path $logPath))
    Notes = @(
        if (-not $resolvedGamePath) { "V Rising appmanifest_1604030.acf was not found in Steam libraries." }
        if ($resolvedGamePath -and -not (Test-Path $metadataPath)) { "IL2CPP metadata was not found at the expected player data path." }
        if ($resolvedGamePath -and -not (Test-Path $scriptingAssembliesPath)) { "ScriptingAssemblies.json was not found at the expected player data path." }
        if ($resolvedGamePath -and -not (Test-Path $bepInExPath)) { "BepInEx is not installed in the game folder." }
        if ($bepInExPath -and -not (Test-Path $interopPath)) { "BepInEx interop assemblies are not generated yet; run the game once with BepInEx installed." }
    )
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result | Format-List
    if ($scriptingAssemblyStatus.Count -gt 0) {
        "Player assembly probe:"
        $scriptingAssemblyStatus | Format-Table -AutoSize
    }
    if ($targetAssemblyStatus.Count -gt 0) {
        "BepInEx interop assembly probe:"
        $targetAssemblyStatus | Format-Table -AutoSize
    }
}
