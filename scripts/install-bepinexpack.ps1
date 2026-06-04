param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root,
    [string]$Version = "1.733.2",
    [string]$ZipPath,
    [string]$DownloadUrl,
    [string]$CacheDir,
    [switch]$AllowNonGamePath,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($CacheDir)) {
    $CacheDir = Join-Path $Root "ref\packages"
}

if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
    $DownloadUrl = "https://thunderstore.io/package/download/BepInEx/BepInExPack_V_Rising/$Version/"
}

function Resolve-RequiredDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Missing $Description`: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

$resolvedRoot = Resolve-RequiredDirectory -Path $Root -Description "repository root"
$resolvedGamePath = Resolve-RequiredDirectory -Path $GamePath -Description "V Rising game path"

$exePath = Join-Path $resolvedGamePath "VRising.exe"
if (-not (Test-Path -LiteralPath $exePath) -and -not $AllowNonGamePath) {
    throw "VRising.exe was not found under $resolvedGamePath. Pass -AllowNonGamePath only for a deliberate staging directory."
}

if ([string]::IsNullOrWhiteSpace($ZipPath)) {
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
    $ZipPath = Join-Path $CacheDir "BepInEx-BepInExPack_V_Rising-$Version.zip"

    if (-not (Test-Path -LiteralPath $ZipPath)) {
        if ($DryRun) {
            [pscustomobject]@{
                Mode = "DryRun"
                GamePath = $resolvedGamePath
                Version = $Version
                ZipPath = $ZipPath
                DownloadUrl = $DownloadUrl
                DownloadNeeded = $true
                FilesPlanned = 0
                ExistingConflicts = @()
                LaunchesGame = $false
            }
            return
        }

        Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $ZipPath
    }
}

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    throw "BepInExPack zip was not found: $ZipPath"
}

$resolvedZipPath = (Resolve-Path -LiteralPath $ZipPath).Path

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedZipPath)
try {
    $prefix = "BepInExPack_V_Rising/"
    $entries = @($zip.Entries | Where-Object {
        $_.FullName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::IsNullOrWhiteSpace($_.Name)
    })

    if ($entries.Count -eq 0) {
        throw "Zip does not contain expected BepInExPack_V_Rising/ payload: $resolvedZipPath"
    }

    $copyPlan = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $entries) {
        $relative = $entry.FullName.Substring($prefix.Length).Replace("/", "\")
        if ([string]::IsNullOrWhiteSpace($relative)) {
            continue
        }

        $destination = Join-Path $resolvedGamePath $relative
        [void]$copyPlan.Add([pscustomobject]@{
            Entry = $entry.FullName
            Destination = $destination
            Length = $entry.Length
            Exists = Test-Path -LiteralPath $destination
        })
    }

    $conflicts = @($copyPlan | Where-Object { $_.Exists })

    if ($DryRun) {
        [pscustomobject]@{
            Mode = "DryRun"
            GamePath = $resolvedGamePath
            Version = $Version
            ZipPath = $resolvedZipPath
            DownloadUrl = $DownloadUrl
            DownloadNeeded = $false
            FilesPlanned = $copyPlan.Count
            ExistingConflicts = @($conflicts | Select-Object -First 25 Destination)
            ExistingConflictCount = $conflicts.Count
            LaunchesGame = $false
        }
        return
    }

    if ($conflicts.Count -gt 0 -and -not $Force) {
        $sample = ($conflicts | Select-Object -First 10 -ExpandProperty Destination) -join "`n"
        throw "BepInExPack destination already has $($conflicts.Count) file(s). Pass -Force to overwrite. Sample:`n$sample"
    }

    foreach ($entry in $entries) {
        $relative = $entry.FullName.Substring($prefix.Length).Replace("/", "\")
        if ([string]::IsNullOrWhiteSpace($relative)) {
            continue
        }

        $destination = Join-Path $resolvedGamePath $relative
        $directory = Split-Path -Parent $destination
        if (-not [string]::IsNullOrWhiteSpace($directory)) {
            New-Item -ItemType Directory -Force -Path $directory | Out-Null
        }

        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
    }

    [pscustomobject]@{
        Mode = "Installed"
        GamePath = $resolvedGamePath
        Version = $Version
        ZipPath = $resolvedZipPath
        FilesCopied = $copyPlan.Count
        OverwroteExisting = $conflicts.Count
        LaunchesGame = $false
    }
}
finally {
    $zip.Dispose()
}
