param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root,
    [string]$Il2CppDumperDir,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path

if ([string]::IsNullOrWhiteSpace($Il2CppDumperDir)) {
    $Il2CppDumperDir = Join-Path $resolvedRoot "ref\decompilation-vrising-2026-06-08\il2cpp-dumper"
}
$resolvedIl2CppDumperDir = (Resolve-Path -LiteralPath $Il2CppDumperDir).Path

$gameAssemblyPath = Join-Path $resolvedGamePath "GameAssembly.dll"
$scriptJsonPath = Join-Path $resolvedIl2CppDumperDir "script.json"

foreach ($path in @($gameAssemblyPath, $scriptJsonPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required local evidence file is missing: $path"
    }
}

$rg = Get-Command rg -ErrorAction SilentlyContinue
if ($null -eq $rg) {
    throw "ripgrep (rg) is required to read method addresses from script.json."
}

function Read-UInt16LE {
    param([byte[]]$Bytes, [int]$Offset)
    return [System.BitConverter]::ToUInt16($Bytes, $Offset)
}

function Read-UInt32LE {
    param([byte[]]$Bytes, [int]$Offset)
    return [System.BitConverter]::ToUInt32($Bytes, $Offset)
}

function Get-PeSections {
    param([Parameter(Mandatory = $true)][string]$Path)

    $header = New-Object byte[] 4096
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $read = $stream.Read($header, 0, $header.Length)
        if ($read -lt 512) {
            throw "PE header is unexpectedly short: $Path"
        }
    } finally {
        $stream.Dispose()
    }

    $peOffset = [int](Read-UInt32LE -Bytes $header -Offset 0x3C)
    $signature = [System.Text.Encoding]::ASCII.GetString($header, $peOffset, 4)
    if ($signature -ne "PE`0`0") {
        throw "File does not have a PE signature: $Path"
    }

    $sectionCount = [int](Read-UInt16LE -Bytes $header -Offset ($peOffset + 6))
    $optionalHeaderSize = [int](Read-UInt16LE -Bytes $header -Offset ($peOffset + 20))
    $sectionTableOffset = $peOffset + 24 + $optionalHeaderSize

    $sections = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $sectionCount; $i++) {
        $offset = $sectionTableOffset + ($i * 40)
        $nameBytes = $header[$offset..($offset + 7)]
        $name = ([System.Text.Encoding]::ASCII.GetString($nameBytes)).Trim([char]0)
        $virtualSize = Read-UInt32LE -Bytes $header -Offset ($offset + 8)
        $virtualAddress = Read-UInt32LE -Bytes $header -Offset ($offset + 12)
        $rawSize = Read-UInt32LE -Bytes $header -Offset ($offset + 16)
        $rawPointer = Read-UInt32LE -Bytes $header -Offset ($offset + 20)

        [void]$sections.Add([pscustomobject]@{
            Name = $name
            VirtualAddress = [uint32]$virtualAddress
            VirtualSize = [uint32]$virtualSize
            RawSize = [uint32]$rawSize
            RawPointer = [uint32]$rawPointer
        })
    }

    return @($sections.ToArray())
}

function Convert-RvaToFileOffset {
    param(
        [Parameter(Mandatory = $true)][object[]]$Sections,
        [Parameter(Mandatory = $true)][uint32]$Rva
    )

    foreach ($section in $Sections) {
        $start = [uint32]$section.VirtualAddress
        $size = [Math]::Max([uint32]$section.VirtualSize, [uint32]$section.RawSize)
        $end = [uint64]$start + [uint64]$size
        if ([uint64]$Rva -ge [uint64]$start -and [uint64]$Rva -lt $end) {
            return [uint64]$section.RawPointer + ([uint64]$Rva - [uint64]$start)
        }
    }

    throw ("RVA 0x{0:X} is outside PE sections." -f $Rva)
}

function Read-BytesAtOffset {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][uint64]$Offset,
        [int]$Count = 16
    )

    $buffer = New-Object byte[] $Count
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $stream.Seek([int64]$Offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $read = $stream.Read($buffer, 0, $Count)
        if ($read -lt $Count) {
            return $buffer[0..($read - 1)]
        }
        return $buffer
    } finally {
        $stream.Dispose()
    }
}

function Find-MethodRva {
    param([Parameter(Mandatory = $true)][string]$Name)

    $pattern = [regex]::Escape($Name)
    $lines = @(& $rg.Source "-n" "-B" "1" "-A" "2" $pattern $scriptJsonPath 2>$null)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) {
        return $null
    }

    $current = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -eq "--") {
            $text = $current -join "`n"
            if ($text -match '"Name":\s*"(?<name>[^"]+)"' -and $Matches.name -eq $Name -and
                $text -match '"Address":\s*(?<address>[0-9]+)') {
                return [uint32]([int64]$Matches.address)
            }
            $current.Clear()
            continue
        }

        [void]$current.Add($line)
    }

    if ($current.Count -gt 0) {
        $text = $current -join "`n"
        if ($text -match '"Name":\s*"(?<name>[^"]+)"' -and $Matches.name -eq $Name -and
            $text -match '"Address":\s*(?<address>[0-9]+)') {
            return [uint32]([int64]$Matches.address)
        }
    }

    return $null
}

function Format-Bytes {
    param([byte[]]$Bytes)
    return (($Bytes | ForEach-Object { "{0:X2}" -f $_ }) -join " ")
}

function Classify-EntryBytes {
    param([byte[]]$Bytes)

    if ($Bytes.Count -ge 3 -and $Bytes[0] -eq 0x32 -and $Bytes[1] -eq 0xC0 -and $Bytes[2] -eq 0xC3) {
        return "ReturnsFalse"
    }
    if ($Bytes.Count -ge 3 -and $Bytes[0] -eq 0x33 -and $Bytes[1] -eq 0xC0 -and $Bytes[2] -eq 0xC3) {
        return "ReturnsNull"
    }
    if ($Bytes.Count -ge 3 -and $Bytes[0] -eq 0xC2 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0x00) {
        return "ReturnsImmediately"
    }
    if ($Bytes.Count -ge 1 -and $Bytes[0] -eq 0xC3) {
        return "ReturnsImmediately"
    }

    return "NonStubLike"
}

$methodSpecs = @(
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$SetupFeature"; Expected = "ReturnsFalse" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$Create"; Expected = "ReturnsNull" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$BeginFrame"; Expected = "ReturnsImmediately" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$SetupDRSScaling"; Expected = "ReturnsImmediately" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$Render"; Expected = "ReturnsImmediately" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$.ctor"; Expected = "ReturnsImmediately" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$DoDLSSPass"; Expected = "NonStubLike" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$RenderPostProcess"; Expected = "NonStubLike" },
    [pscustomobject]@{ Name = "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$CreateCameraResources"; Expected = "NonStubLike" }
)

$sections = Get-PeSections -Path $gameAssemblyPath
$issues = New-Object System.Collections.Generic.List[string]
$methods = New-Object System.Collections.Generic.List[object]

foreach ($spec in $methodSpecs) {
    $rva = Find-MethodRva -Name $spec.Name
    if ($null -eq $rva) {
        [void]$issues.Add("Missing method address in script.json: $($spec.Name)")
        [void]$methods.Add([pscustomobject]@{
            Name = $spec.Name
            RvaHex = ""
            FileOffsetHex = ""
            EntryBytes = ""
            Classification = "Missing"
            Expected = $spec.Expected
            MatchesExpected = $false
        })
        continue
    }

    $fileOffset = Convert-RvaToFileOffset -Sections $sections -Rva $rva
    $bytes = [byte[]](Read-BytesAtOffset -Path $gameAssemblyPath -Offset $fileOffset -Count 16)
    $classification = Classify-EntryBytes -Bytes $bytes
    $matches = $classification -eq $spec.Expected
    if (-not $matches) {
        [void]$issues.Add("Unexpected native entry shape for $($spec.Name): expected $($spec.Expected), got $classification")
    }

    [void]$methods.Add([pscustomobject]@{
        Name = $spec.Name
        Rva = [uint32]$rva
        RvaHex = "0x{0:X}" -f $rva
        FileOffset = [uint64]$fileOffset
        FileOffsetHex = "0x{0:X}" -f $fileOffset
        EntryBytes = Format-Bytes -Bytes $bytes
        Classification = $classification
        Expected = $spec.Expected
        MatchesExpected = $matches
    })
}

$result = [pscustomobject]@{
    Status = $(if ($issues.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    GamePath = $resolvedGamePath
    GameAssembly = $gameAssemblyPath
    ScriptJson = $scriptJsonPath
    Methods = @($methods.ToArray())
    Issues = @($issues.ToArray())
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}
