param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Backup", "Compare", "Restore")]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$SaveDir,

    [Parameter(Mandatory = $true)]
    [string]$Label,

    [string]$Root,
    [string]$ReferenceDir,
    [switch]$ArchiveCurrent
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$artifactRoot = Join-Path $resolvedRoot "artifacts\gameplay-automation"
$safeLabel = $Label -replace "[^A-Za-z0-9_.-]", "-"

function Resolve-ExistingPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Name does not exist: $Path"
    }

    (Resolve-Path -LiteralPath $Path).Path
}

function Assert-VRisingSavePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $cloudRoot = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\CloudSaves"
    $resolvedCloudRoot = (Resolve-Path -LiteralPath $cloudRoot).Path
    $full = [System.IO.Path]::GetFullPath($Path)
    $rootWithSlash = $resolvedCloudRoot.TrimEnd('\') + '\'

    if (-not $full.StartsWith($rootWithSlash, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to protect a path outside V Rising CloudSaves: $full"
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$ChildPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $child = [System.IO.Path]::GetFullPath($ChildPath)
    if (-not $child.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is not under base path. Base=$base Child=$child"
    }

    $child.Substring($base.Length)
}

function Get-SaveManifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force |
        Sort-Object FullName |
        ForEach-Object {
            $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
            [pscustomobject]@{
                RelativePath = (Get-RelativePath -BasePath $Path -ChildPath $_.FullName)
                Length = [int64]$_.Length
                LastWriteTimeUtc = $_.LastWriteTimeUtc.ToString("o")
                Sha256 = $hash.Hash
            }
        })
}

function Compare-SaveManifests {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActualDir,

        [Parameter(Mandatory = $true)]
        [string]$ReferenceDir
    )

    $actual = @(Get-SaveManifest -Path $ActualDir)
    $reference = @(Get-SaveManifest -Path $ReferenceDir)
    $actualByPath = @{}
    $referenceByPath = @{}

    foreach ($item in $actual) {
        $actualByPath[$item.RelativePath] = $item
    }

    foreach ($item in $reference) {
        $referenceByPath[$item.RelativePath] = $item
    }

    $changes = @()
    $referenceKeys = @($referenceByPath.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $actualKeys = @($actualByPath.Keys | ForEach-Object { [string]$_ } | Sort-Object)

    foreach ($path in $referenceKeys) {
        if (-not $actualByPath.ContainsKey($path)) {
            $changes += [pscustomobject]@{
                    Type = "Missing"
                    RelativePath = $path
                    ReferenceLength = $referenceByPath[$path].Length
                    ActualLength = $null
                    ReferenceSha256 = $referenceByPath[$path].Sha256
                    ActualSha256 = ""
                }
            continue
        }

        $expected = $referenceByPath[$path]
        $observed = $actualByPath[$path]
        if ($expected.Length -ne $observed.Length -or $expected.Sha256 -ne $observed.Sha256) {
            $changes += [pscustomobject]@{
                    Type = "Changed"
                    RelativePath = $path
                    ReferenceLength = $expected.Length
                    ActualLength = $observed.Length
                    ReferenceSha256 = $expected.Sha256
                    ActualSha256 = $observed.Sha256
                }
        }
    }

    foreach ($path in $actualKeys) {
        if (-not $referenceByPath.ContainsKey($path)) {
            $changes += [pscustomobject]@{
                    Type = "Added"
                    RelativePath = $path
                    ReferenceLength = $null
                    ActualLength = $actualByPath[$path].Length
                    ReferenceSha256 = ""
                    ActualSha256 = $actualByPath[$path].Sha256
                }
        }
    }

    [pscustomobject]@{
        ReferenceFileCount = $reference.Count
        ActualFileCount = $actual.Count
        ChangeCount = @($changes).Count
        Changes = @($changes)
    }
}

function Copy-DirectoryChildren {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    foreach ($child in @(Get-ChildItem -LiteralPath $SourceDir -Force)) {
        Copy-Item -LiteralPath $child.FullName -Destination $DestinationDir -Recurse -Force
    }
}

function Clear-DirectoryChildren {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        return
    }

    foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force)) {
        Remove-Item -LiteralPath $child.FullName -Recurse -Force
    }
}

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
$resolvedSaveDir = [System.IO.Path]::GetFullPath($SaveDir)
Assert-VRisingSavePath -Path $resolvedSaveDir

switch ($Mode) {
    "Backup" {
        $saveDirExisting = Resolve-ExistingPath -Path $resolvedSaveDir -Name "SaveDir"
        $backupRoot = Join-Path $artifactRoot "SaveBackupDir-$safeLabel"
        $backupDir = Join-Path $backupRoot (Split-Path -Leaf $saveDirExisting)
        if (Test-Path -LiteralPath $backupRoot) {
            throw "Backup root already exists: $backupRoot"
        }

        Copy-DirectoryChildren -SourceDir $saveDirExisting -DestinationDir $backupDir
        $zipPath = Join-Path $artifactRoot "SaveBackup-$safeLabel.zip"
        if (Test-Path -LiteralPath $zipPath) {
            throw "Backup zip already exists: $zipPath"
        }

        Compress-Archive -LiteralPath $backupDir -DestinationPath $zipPath -Force
        $manifestPath = Join-Path $artifactRoot "SaveManifestBefore-$safeLabel.json"
        $manifest = [pscustomobject]@{
            Mode = "Backup"
            Label = $safeLabel
            SaveDir = $saveDirExisting
            BackupRoot = $backupRoot
            BackupDir = $backupDir
            ZipPath = $zipPath
            FileCount = @(Get-SaveManifest -Path $saveDirExisting).Count
            Files = @(Get-SaveManifest -Path $saveDirExisting)
        }
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

        [pscustomobject]@{
            Mode = "Backup"
            Label = $safeLabel
            SaveDir = $saveDirExisting
            BackupRoot = $backupRoot
            BackupDir = $backupDir
            ZipPath = $zipPath
            ManifestPath = $manifestPath
            FileCount = $manifest.FileCount
            LaunchesGame = $false
        }
        break
    }

    "Compare" {
        if ([string]::IsNullOrWhiteSpace($ReferenceDir)) {
            throw "Compare mode requires -ReferenceDir."
        }

        $referenceResolved = Resolve-ExistingPath -Path $ReferenceDir -Name "ReferenceDir"
        $comparison = Compare-SaveManifests -ActualDir $resolvedSaveDir -ReferenceDir $referenceResolved
        $comparePath = Join-Path $artifactRoot "SaveCompare-$safeLabel.json"
        $result = [pscustomobject]@{
            CompareMode = "SaveCompare"
            Label = $safeLabel
            CompareStatus = $(if ($comparison.ChangeCount -eq 0) { "Restored" } else { "Changed" })
            SaveDir = $resolvedSaveDir
            ReferenceDir = $referenceResolved
            ReferenceFileCount = $comparison.ReferenceFileCount
            ActualFileCount = $comparison.ActualFileCount
            ChangeCount = $comparison.ChangeCount
            Changes = @($comparison.Changes)
        }
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $comparePath -Encoding UTF8
        $result | Add-Member -NotePropertyName ComparePath -NotePropertyValue $comparePath -PassThru
        break
    }

    "Restore" {
        if ([string]::IsNullOrWhiteSpace($ReferenceDir)) {
            throw "Restore mode requires -ReferenceDir."
        }

        $referenceResolved = Resolve-ExistingPath -Path $ReferenceDir -Name "ReferenceDir"
        $beforeComparison = Compare-SaveManifests -ActualDir $resolvedSaveDir -ReferenceDir $referenceResolved
        $beforePath = Join-Path $artifactRoot "SaveCompareBeforeRestore-$safeLabel.json"
        $beforeResult = [pscustomobject]@{
            CompareMode = "SaveCompareBeforeRestore"
            Label = $safeLabel
            CompareStatus = $(if ($beforeComparison.ChangeCount -eq 0) { "Restored" } else { "Changed" })
            SaveDir = $resolvedSaveDir
            ReferenceDir = $referenceResolved
            ReferenceFileCount = $beforeComparison.ReferenceFileCount
            ActualFileCount = $beforeComparison.ActualFileCount
            ChangeCount = $beforeComparison.ChangeCount
            Changes = @($beforeComparison.Changes)
        }
        $beforeResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $beforePath -Encoding UTF8

        $archivePath = ""
        if ($ArchiveCurrent -and (Test-Path -LiteralPath $resolvedSaveDir)) {
            $archivePath = Join-Path $artifactRoot "SaveAfterRun-$safeLabel.zip"
            Compress-Archive -LiteralPath $resolvedSaveDir -DestinationPath $archivePath -Force
        }

        Clear-DirectoryChildren -Path $resolvedSaveDir
        Copy-DirectoryChildren -SourceDir $referenceResolved -DestinationDir $resolvedSaveDir

        $afterComparison = Compare-SaveManifests -ActualDir $resolvedSaveDir -ReferenceDir $referenceResolved
        $afterPath = Join-Path $artifactRoot "SaveCompareAfterRestore-$safeLabel.json"
        $afterResult = [pscustomobject]@{
            CompareMode = "SaveCompareAfterRestore"
            Label = $safeLabel
            CompareStatus = $(if ($afterComparison.ChangeCount -eq 0) { "Restored" } else { "Changed" })
            SaveDir = $resolvedSaveDir
            ReferenceDir = $referenceResolved
            ReferenceFileCount = $afterComparison.ReferenceFileCount
            ActualFileCount = $afterComparison.ActualFileCount
            ChangeCount = $afterComparison.ChangeCount
            Changes = @($afterComparison.Changes)
        }
        $afterResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $afterPath -Encoding UTF8

        [pscustomobject]@{
            Mode = "Restore"
            Label = $safeLabel
            SaveDir = $resolvedSaveDir
            ReferenceDir = $referenceResolved
            ArchivePath = $archivePath
            BeforeComparePath = $beforePath
            BeforeChangeCount = $beforeComparison.ChangeCount
            AfterComparePath = $afterPath
            CompareStatus = $afterResult.CompareStatus
            ChangeCount = $afterComparison.ChangeCount
            LaunchesGame = $false
        }
        break
    }
}
