param(
    [Parameter(Mandatory = $true)]
    [string]$RuntimePath
)

$ErrorActionPreference = "Stop"

function Convert-RvaToFileOffset {
    param(
        [uint32]$Rva,
        [array]$Sections
    )

    foreach ($section in $Sections) {
        $size = [Math]::Max($section.VirtualSize, $section.RawSize)
        if ($Rva -ge $section.VirtualAddress -and $Rva -lt ($section.VirtualAddress + $size)) {
            return [int]($section.RawPointer + ($Rva - $section.VirtualAddress))
        }
    }

    return [int]$Rva
}

function Get-PeExportNames {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 0x40) {
        throw "File is too small to be a PE image: $Path"
    }

    $dosHeaderOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($dosHeaderOffset -le 0 -or $dosHeaderOffset + 0x18 -ge $bytes.Length) {
        throw "Invalid PE header offset in: $Path"
    }

    $numberOfSections = [BitConverter]::ToUInt16($bytes, $dosHeaderOffset + 0x6)
    $optionalHeaderSize = [BitConverter]::ToUInt16($bytes, $dosHeaderOffset + 0x14)
    $optionalHeaderOffset = $dosHeaderOffset + 0x18
    $magic = [BitConverter]::ToUInt16($bytes, $optionalHeaderOffset)
    $dataDirectoryOffset = $optionalHeaderOffset + $(if ($magic -eq 0x20b) { 0x70 } elseif ($magic -eq 0x10b) { 0x60 } else { throw "Unsupported PE optional header magic 0x$($magic.ToString('X4')) in: $Path" })
    $exportDirectoryRva = [BitConverter]::ToUInt32($bytes, $dataDirectoryOffset)
    if ($exportDirectoryRva -eq 0) {
        return @()
    }

    $sectionHeaderOffset = $optionalHeaderOffset + $optionalHeaderSize
    $sections = for ($i = 0; $i -lt $numberOfSections; $i++) {
        $offset = $sectionHeaderOffset + (40 * $i)
        [pscustomobject]@{
            VirtualSize = [BitConverter]::ToUInt32($bytes, $offset + 8)
            VirtualAddress = [BitConverter]::ToUInt32($bytes, $offset + 12)
            RawSize = [BitConverter]::ToUInt32($bytes, $offset + 16)
            RawPointer = [BitConverter]::ToUInt32($bytes, $offset + 20)
        }
    }

    $exportDirectoryOffset = Convert-RvaToFileOffset -Rva $exportDirectoryRva -Sections $sections
    $numberOfNames = [BitConverter]::ToUInt32($bytes, $exportDirectoryOffset + 24)
    $addressOfNamesRva = [BitConverter]::ToUInt32($bytes, $exportDirectoryOffset + 32)
    $namesOffset = Convert-RvaToFileOffset -Rva $addressOfNamesRva -Sections $sections

    $exports = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $numberOfNames; $i++) {
        $nameRva = [BitConverter]::ToUInt32($bytes, $namesOffset + (4 * $i))
        $nameOffset = Convert-RvaToFileOffset -Rva $nameRva -Sections $sections
        $endOffset = $nameOffset
        while ($endOffset -lt $bytes.Length -and $bytes[$endOffset] -ne 0) {
            $endOffset++
        }

        $exports.Add([Text.Encoding]::ASCII.GetString($bytes, $nameOffset, $endOffset - $nameOffset))
    }

    return $exports
}

$resolvedRuntimePath = (Resolve-Path -LiteralPath $RuntimePath).Path
$exportNames = @(Get-PeExportNames -Path $resolvedRuntimePath)
$exportSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($name in $exportNames) {
    [void]$exportSet.Add($name)
}

function Has-Export([string]$Name) {
    return $exportSet.Contains($Name)
}

$hasD3D11RuntimeSurface = (Has-Export "NVSDK_NGX_D3D11_Init") `
    -and (Has-Export "NVSDK_NGX_D3D11_CreateFeature") `
    -and (Has-Export "NVSDK_NGX_D3D11_EvaluateFeature") `
    -and (Has-Export "NVSDK_NGX_D3D11_ReleaseFeature") `
    -and ((Has-Export "NVSDK_NGX_D3D11_Shutdown") -or (Has-Export "NVSDK_NGX_D3D11_Shutdown1"))

$hasDirectParameterMapSurface = ((Has-Export "NVSDK_NGX_D3D11_AllocateParameters") -or (Has-Export "NVSDK_NGX_D3D11_GetCapabilityParameters")) `
    -and (Has-Export "NVSDK_NGX_D3D11_DestroyParameters") `
    -and (Has-Export "NVSDK_NGX_Parameter_SetI") `
    -and (Has-Export "NVSDK_NGX_Parameter_SetUI") `
    -and (Has-Export "NVSDK_NGX_Parameter_SetF") `
    -and ((Has-Export "NVSDK_NGX_Parameter_SetD3d11Resource") -or (Has-Export "NVSDK_NGX_Parameter_SetVoidPointer"))

$hasDirectCapabilitySurface = (Has-Export "NVSDK_NGX_D3D11_GetCapabilityParameters") `
    -and (Has-Export "NVSDK_NGX_D3D11_DestroyParameters") `
    -and ((Has-Export "NVSDK_NGX_Parameter_GetI") -or (Has-Export "NVSDK_NGX_Parameter_GetUI"))

[pscustomobject]@{
    RuntimePath = $resolvedRuntimePath
    ExportCount = $exportNames.Count
    D3D11RuntimeSurface = $hasD3D11RuntimeSurface
    DirectParameterMapSurface = $hasDirectParameterMapSurface
    DirectCapabilitySurface = $hasDirectCapabilitySurface
    DirectDlssRouteCandidate = $hasD3D11RuntimeSurface -and $hasDirectParameterMapSurface
    D3D11_Init = Has-Export "NVSDK_NGX_D3D11_Init"
    D3D11_Init_Ext = Has-Export "NVSDK_NGX_D3D11_Init_Ext"
    D3D11_CreateFeature = Has-Export "NVSDK_NGX_D3D11_CreateFeature"
    D3D11_EvaluateFeature = Has-Export "NVSDK_NGX_D3D11_EvaluateFeature"
    D3D11_EvaluateFeature_C = Has-Export "NVSDK_NGX_D3D11_EvaluateFeature_C"
    D3D11_ReleaseFeature = Has-Export "NVSDK_NGX_D3D11_ReleaseFeature"
    D3D11_Shutdown = Has-Export "NVSDK_NGX_D3D11_Shutdown"
    D3D11_Shutdown1 = Has-Export "NVSDK_NGX_D3D11_Shutdown1"
    D3D11_AllocateParameters = Has-Export "NVSDK_NGX_D3D11_AllocateParameters"
    D3D11_GetCapabilityParameters = Has-Export "NVSDK_NGX_D3D11_GetCapabilityParameters"
    D3D11_DestroyParameters = Has-Export "NVSDK_NGX_D3D11_DestroyParameters"
    D3D11_PopulateParameters_Impl = Has-Export "NVSDK_NGX_D3D11_PopulateParameters_Impl"
    Parameter_SetI = Has-Export "NVSDK_NGX_Parameter_SetI"
    Parameter_SetUI = Has-Export "NVSDK_NGX_Parameter_SetUI"
    Parameter_SetF = Has-Export "NVSDK_NGX_Parameter_SetF"
    Parameter_SetD3d11Resource = Has-Export "NVSDK_NGX_Parameter_SetD3d11Resource"
    Parameter_SetVoidPointer = Has-Export "NVSDK_NGX_Parameter_SetVoidPointer"
    Parameter_GetI = Has-Export "NVSDK_NGX_Parameter_GetI"
    Parameter_GetUI = Has-Export "NVSDK_NGX_Parameter_GetUI"
}
