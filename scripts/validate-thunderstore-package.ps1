param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$PackagePath
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Add-Violation {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Violations,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $Violations.Add($Message)
}

function Read-ZipEntryText {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Compression.ZipArchiveEntry]$Entry
    )

    $stream = $Entry.Open()
    try {
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Read-ZipEntryPrefix {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.Compression.ZipArchiveEntry]$Entry,

        [Parameter(Mandatory = $true)]
        [int]$Length
    )

    $bytes = [byte[]]::new($Length)
    $stream = $Entry.Open()
    try {
        $offset = 0
        while ($offset -lt $Length) {
            $read = $stream.Read($bytes, $offset, $Length - $offset)
            if ($read -le 0) {
                break
            }

            $offset += $read
        }

        if ($offset -lt $Length) {
            return $bytes[0..($offset - 1)]
        }

        return $bytes
    } finally {
        $stream.Dispose()
    }
}

function Test-TextContains {
    param(
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Needle
    )

    if ($null -eq $Text) {
        return $false
    }

    return $Text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-PngUInt32BigEndian {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [int]$Offset
    )

    return ([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        [uint32]$Bytes[$Offset + 3]
}

function Test-BytePrefixEqual {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [byte[]]$Expected
    )

    if ($Bytes.Length -lt $Expected.Length) {
        return $false
    }

    for ($index = 0; $index -lt $Expected.Length; $index++) {
        if ($Bytes[$index] -ne $Expected[$index]) {
            return $false
        }
    }

    return $true
}

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $manifestPath = Join-Path $Root "package\thunderstore\manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Missing manifest needed to infer package path: $manifestPath"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $PackagePath = Join-Path $Root "dist\VrisingDLSS-$($manifest.version_number)-thunderstore.zip"
}

if (-not (Test-Path -LiteralPath $PackagePath)) {
    throw "Package zip not found: $PackagePath"
}

$violations = [System.Collections.Generic.List[string]]::new()
$requiredEntries = @(
    "manifest.json",
    "README.md",
    "icon.png",
    "BepInEx/plugins/VrisingDLSS/VrisingDLSS.Plugin.dll",
    "BepInEx/plugins/VrisingDLSS/VrisingDLSS.Native.dll",
    "BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg",
    "BepInEx/plugins/VrisingDLSS/README-runtime.txt"
)
$allowedDllEntries = @(
    "BepInEx/plugins/VrisingDLSS/VrisingDLSS.Plugin.dll",
    "BepInEx/plugins/VrisingDLSS/VrisingDLSS.Native.dll"
)
$forbiddenFileNames = @(
    "PDPerfPlugin.dll",
    "PerfMod.dll",
    "nvngx_dlss.dll",
    "sl.interposer.dll",
    "sl.common.dll",
    "sl.dlss.dll",
    "nvngx_dlssg.dll"
)
$forbiddenExtensions = @(".exe", ".zip", ".7z", ".rar")

$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName -replace "\\", "/" })
    $entryMap = @{}
    foreach ($entry in $archive.Entries) {
        $entryMap[$entry.FullName -replace "\\", "/"] = $entry
    }

    foreach ($requiredEntry in $requiredEntries) {
        if (-not $entryMap.ContainsKey($requiredEntry)) {
            Add-Violation -Violations $violations -Message "Missing required package entry: $requiredEntry"
        }
    }

    foreach ($entryName in $entries) {
        $fileName = [System.IO.Path]::GetFileName($entryName)
        $extension = [System.IO.Path]::GetExtension($entryName).ToLowerInvariant()
        if ($entryName.StartsWith("VrisingDLSS/", [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-Violation -Violations $violations -Message "Legacy root plugin folder found; use BepInEx/plugins/VrisingDLSS instead: $entryName"
        }

        if ($extension -eq ".dll" -and -not ($allowedDllEntries -contains $entryName)) {
            Add-Violation -Violations $violations -Message "Unexpected DLL in package: $entryName"
        }

        if ($forbiddenExtensions -contains $extension) {
            Add-Violation -Violations $violations -Message "Nested binary/archive file in package: $entryName"
        }

        if ($forbiddenFileNames -contains $fileName) {
            Add-Violation -Violations $violations -Message "Forbidden third-party/runtime file in package: $entryName"
        }
    }

    if ($entryMap.ContainsKey("manifest.json")) {
        try {
            $packageManifest = Read-ZipEntryText -Entry $entryMap["manifest.json"] | ConvertFrom-Json
            if ($packageManifest.name -notmatch "^[A-Za-z0-9_]+$") {
                Add-Violation -Violations $violations -Message "manifest.json name must use only letters, numbers, or underscores."
            }

            if ($packageManifest.version_number -notmatch "^\d+\.\d+\.\d+$") {
                Add-Violation -Violations $violations -Message "manifest.json version_number must be Major.Minor.Patch."
            }

            if ([string]::IsNullOrWhiteSpace($packageManifest.description) -or $packageManifest.description.Length -gt 250) {
                Add-Violation -Violations $violations -Message "manifest.json description must be non-empty and at most 250 characters."
            } else {
                $description = [string]$packageManifest.description
                if (-not ((Test-TextContains -Text $description -Needle "diagnostic") -or (Test-TextContains -Text $description -Needle "scaffold"))) {
                    Add-Violation -Violations $violations -Message "manifest.json description must label this pre-MVP package as diagnostic or scaffold."
                }

                foreach ($forbiddenDescriptionPhrase in @(
                    "enables DLSS",
                    "working DLSS",
                    "playable DLSS",
                    "ready for public gameplay",
                    "improves performance",
                    "boosts FPS"
                )) {
                    if (Test-TextContains -Text $description -Needle $forbiddenDescriptionPhrase) {
                        Add-Violation -Violations $violations -Message "manifest.json description contains misleading pre-MVP claim: $forbiddenDescriptionPhrase"
                    }
                }
            }

            $expectedDependency = "BepInEx-BepInExPack_V_Rising-1.733.2"
            if (-not (@($packageManifest.dependencies) -contains $expectedDependency)) {
                Add-Violation -Violations $violations -Message "manifest.json dependencies must include $expectedDependency."
            }

            if ([string]::IsNullOrWhiteSpace($packageManifest.website_url)) {
                Add-Violation -Violations $violations -Message "manifest.json website_url must point to the source repository."
            }
        } catch {
            Add-Violation -Violations $violations -Message "manifest.json could not be parsed: $($_.Exception.Message)"
        }
    }

    if ($entryMap.ContainsKey("README.md")) {
        $readmeText = Read-ZipEntryText -Entry $entryMap["README.md"]
        if ([string]::IsNullOrWhiteSpace($readmeText)) {
            Add-Violation -Violations $violations -Message "README.md must not be empty."
        } else {
            foreach ($requiredReadmePhrase in @(
                "does not enable DLSS",
                "not ready for public gameplay use",
                "local/private",
                "nvngx_dlss.dll"
            )) {
                if (-not (Test-TextContains -Text $readmeText -Needle $requiredReadmePhrase)) {
                    Add-Violation -Violations $violations -Message "README.md must include diagnostic release boundary phrase: $requiredReadmePhrase"
                }
            }

            foreach ($forbiddenReadmePhrase in @(
                "enables DLSS today",
                "working DLSS release",
                "is ready for public gameplay",
                "ready for public gameplay release"
            )) {
                if (Test-TextContains -Text $readmeText -Needle $forbiddenReadmePhrase) {
                    Add-Violation -Violations $violations -Message "README.md contains misleading pre-MVP claim: $forbiddenReadmePhrase"
                }
            }
        }
    }

    $configEntryName = "BepInEx/plugins/VrisingDLSS/VrisingDLSS.cfg"
    if ($entryMap.ContainsKey($configEntryName)) {
        $configText = Read-ZipEntryText -Entry $entryMap[$configEntryName]
        foreach ($requiredConfigLine in @(
            "EnableDLSS = false",
            "EnableDlssEvaluateInputProbe = false",
            "EnableDlssEvaluateProbe = false",
            "EnableRenderGraphDiagnosticPass = false",
            "EnableExistingRenderFuncProbe = false",
            "EnableResourceMaterializationProbe = false",
            "EnableDlssPassResourceProbe = false",
            "EnableUpscalerStateProbe = false",
            "EnableHookProbe = true"
        )) {
            if (-not (Test-TextContains -Text $configText -Needle $requiredConfigLine)) {
                Add-Violation -Violations $violations -Message "Packaged config must keep diagnostic-safe default: $requiredConfigLine"
            }
        }
    }

    if ($entryMap.ContainsKey("icon.png")) {
        $header = [byte[]](Read-ZipEntryPrefix -Entry $entryMap["icon.png"] -Length 24)
        $pngSignature = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        if ($header.Length -lt 24) {
            Add-Violation -Violations $violations -Message "icon.png is too short to be a valid PNG."
        } elseif (-not (Test-BytePrefixEqual -Bytes $header -Expected $pngSignature)) {
            Add-Violation -Violations $violations -Message "icon.png does not have a valid PNG signature."
        } else {
            $width = Get-PngUInt32BigEndian -Bytes $header -Offset 16
            $height = Get-PngUInt32BigEndian -Bytes $header -Offset 20
            if ($width -ne 256 -or $height -ne 256) {
                Add-Violation -Violations $violations -Message "icon.png must be exactly 256x256, found ${width}x${height}."
            }
        }
    }
} finally {
    $archive.Dispose()
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Thunderstore package validation passed: $PackagePath"
