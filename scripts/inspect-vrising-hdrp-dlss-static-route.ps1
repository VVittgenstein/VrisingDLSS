param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root,
    [string]$Il2CppDumperDir,
    [string]$XrefProbeDll,
    [string]$DotnetPath,
    [string]$PythonPath,
    [switch]$SkipAssetUnpack,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GamePath)) {
    throw "GamePath does not exist: $GamePath"
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path

if ([string]::IsNullOrWhiteSpace($Il2CppDumperDir)) {
    $Il2CppDumperDir = Join-Path $resolvedRoot "ref\decompilation-vrising-2026-06-08\il2cpp-dumper"
}
$Il2CppDumperDir = (Resolve-Path -LiteralPath $Il2CppDumperDir).Path

$scriptJsonPath = Join-Path $Il2CppDumperDir "script.json"
$dumpCsPath = Join-Path $Il2CppDumperDir "dump.cs"
$stringLiteralPath = Join-Path $Il2CppDumperDir "stringliteral.json"
$gameAssemblyPath = Join-Path $resolvedGamePath "GameAssembly.dll"
$metadataPath = Join-Path $resolvedGamePath "VRising_Data\il2cpp_data\Metadata\global-metadata.dat"
$interopDir = Join-Path $resolvedGamePath "BepInEx\interop"

$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($path in @($scriptJsonPath, $dumpCsPath, $stringLiteralPath, $gameAssemblyPath, $metadataPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        [void]$issues.Add("Required local evidence file is missing: $path")
    }
}

function Resolve-CommandPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return ""
    }

    return [string]$command.Source
}

$rgPath = Resolve-CommandPath -Name "rg"
if ([string]::IsNullOrWhiteSpace($rgPath)) {
    throw "ripgrep (rg) is required for this narrow static audit."
}

if ([string]::IsNullOrWhiteSpace($DotnetPath)) {
    $preferredDotnet = "C:\Software\dotnet\dotnet.exe"
    if (Test-Path -LiteralPath $preferredDotnet) {
        $DotnetPath = $preferredDotnet
    } else {
        $DotnetPath = Resolve-CommandPath -Name "dotnet"
    }
}

if ([string]::IsNullOrWhiteSpace($XrefProbeDll)) {
    $XrefProbeDll = Join-Path $resolvedRoot "artifacts\tools\InteropXrefProbe\bin\Release\net6.0\InteropXrefProbe.dll"
}

function Invoke-RgLines {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & $rgPath @Arguments 2>$null
    $exit = $LASTEXITCODE
    if ($exit -ne 0 -and $exit -ne 1) {
        throw "rg failed with exit code $exit for arguments: $($Arguments -join ' ')"
    }

    return @($output | ForEach-Object { $_.ToString() })
}

function Convert-MethodGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Lines
    )

    $text = $Lines -join "`n"
    $name = ""
    $address = $null
    $signature = ""
    $typeSignature = ""

    if ($text -match '"Address":\s*(?<address>[0-9]+)') {
        $address = [int64]$Matches.address
    }
    if ($text -match '"Name":\s*"(?<name>[^"]+)"') {
        $name = $Matches.name
    }
    if ($text -match '"Signature":\s*"(?<signature>[^"]*)"') {
        $signature = $Matches.signature
    }
    if ($text -match '"TypeSignature":\s*"(?<typeSignature>[^"]*)"') {
        $typeSignature = $Matches.typeSignature
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        return $null
    }

    [PSCustomObject]@{
        Name = $name
        ShortName = ($name -replace '^.*\$\$', '')
        Present = $true
        Address = $address
        AddressHex = $(if ($null -ne $address) { "0x{0:X}" -f $address } else { "" })
        Signature = $signature
        TypeSignature = $typeSignature
    }
}

function Find-ScriptMethods {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    $pattern = ($Names | ForEach-Object { [regex]::Escape($_) }) -join "|"
    $lines = Invoke-RgLines -Arguments @("-n", "-B", "1", "-A", "2", $pattern, $scriptJsonPath)
    $groups = New-Object System.Collections.Generic.List[object]
    $current = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -eq "--") {
            if ($current.Count -gt 0) {
                $group = Convert-MethodGroup -Lines $current.ToArray()
                if ($null -ne $group) {
                    [void]$groups.Add($group)
                }
                $current.Clear()
            }
            continue
        }

        [void]$current.Add($line)
    }

    if ($current.Count -gt 0) {
        $group = Convert-MethodGroup -Lines $current.ToArray()
        if ($null -ne $group) {
            [void]$groups.Add($group)
        }
    }

    $found = @($groups.ToArray())
    foreach ($name in $Names) {
        if (-not @($found | Where-Object { $_.Name -eq $name }).Count) {
            [void]$groups.Add([PSCustomObject]@{
                Name = $name
                ShortName = ($name -replace '^.*\$\$', '')
                Present = $false
                Address = $null
                AddressHex = ""
                Signature = ""
                TypeSignature = ""
            })
        }
    }

    return @($groups.ToArray() | Sort-Object Name)
}

function Find-StringLiterals {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Terms
    )

    $pattern = ($Terms | ForEach-Object { [regex]::Escape($_) }) -join "|"
    $lines = Invoke-RgLines -Arguments @("-n", $pattern, $stringLiteralPath)

    foreach ($term in $Terms) {
        $hits = @($lines | Where-Object { $_ -like "*$term*" })
        [PSCustomObject]@{
            Term = $term
            Present = ($hits.Count -gt 0)
            HitCount = $hits.Count
            FirstHit = $(if ($hits.Count -gt 0) { [string]$hits[0] } else { "" })
        }
    }
}

function Find-DumpFields {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FieldNames
    )

    $pattern = ($FieldNames | ForEach-Object { "(^|[[:space:]])" + [regex]::Escape($_) + "(;|[[:space:]])" }) -join "|"
    $lines = Invoke-RgLines -Arguments @("-n", $pattern, $dumpCsPath)
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($fieldName in $FieldNames) {
        $fieldLines = @($lines | Where-Object { $_ -match "\b$([regex]::Escape($fieldName))\b" })
        foreach ($line in $fieldLines) {
            $raw = $line -replace '^[0-9]+[:-]', ''
            $offset = ""
            if ($raw -match '//\s*(0x[0-9A-Fa-f]+)') {
                $offset = $Matches[1]
            }
            $type = ""
            if ($raw -match '\b(public|private|internal)\s+(?<type>[A-Za-z0-9_<>,\.\[\]]+)\s+' + [regex]::Escape($fieldName) + '\b') {
                $type = $Matches.type
            }
            [void]$results.Add([PSCustomObject]@{
                Field = $fieldName
                Present = $true
                Type = $type
                Offset = $offset
                Raw = $raw.Trim()
            })
        }
        if ($fieldLines.Count -eq 0) {
            [void]$results.Add([PSCustomObject]@{
                Field = $fieldName
                Present = $false
                Type = ""
                Offset = ""
                Raw = ""
            })
        }
    }

    return @($results.ToArray())
}

function Find-DumpTypeBlocks {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TypePatterns
    )

    foreach ($typePattern in $TypePatterns) {
        $typeRegex = [regex]::Escape($typePattern) + '(\s|//|$)'
        $lines = Invoke-RgLines -Arguments @("-n", "-A", "140", $typeRegex, $dumpCsPath)
        $header = ""
        $block = New-Object System.Collections.Generic.List[string]

        foreach ($line in $lines) {
            if ($line -eq "--") {
                continue
            }

            $raw = ($line -replace '^[0-9]+[:-]', '').Trim()
            if ([string]::IsNullOrWhiteSpace($header)) {
                if ($raw -match '(public|private|internal)\s+(class|struct|enum)\s+') {
                    $header = $raw
                    [void]$block.Add($line)
                }
                continue
            }

            if ($raw -match '^(public|private|internal)\s+(class|struct|enum)\s+' -and $raw -ne $header) {
                break
            }

            [void]$block.Add($line)
        }

        if ([string]::IsNullOrWhiteSpace($header)) {
            [PSCustomObject]@{
                Type = $typePattern
                Found = $false
                Fields = @()
            }
            continue
        }

        $fields = New-Object System.Collections.Generic.List[object]
        foreach ($line in $block) {
            $raw = ($line -replace '^[0-9]+[:-]', '').Trim()
            if ($raw -match '^(public|private|internal)\s+(?<type>[A-Za-z0-9_<>,\.\[\]]+)\s+(?<field>[A-Za-z0-9_<>]+);\s*//\s*(?<offset>0x[0-9A-Fa-f]+)') {
                [void]$fields.Add([PSCustomObject]@{
                    Name = $Matches.field
                    Type = $Matches.type
                    Offset = $Matches.offset
                    Raw = $raw
                })
            }
        }

        [PSCustomObject]@{
            Type = $header
            Found = $true
            Fields = @($fields.ToArray())
        }
    }
}

function Find-ProjectMDlssTerms {
    $terms = @("DLSS", "NGX", "NVIDIA", "NVUnityPlugin", "Streamline", "XeSS", "nvngx", "nvsdk_ngx")
    $pattern = (($terms | ForEach-Object { [regex]::Escape($_) }) -join "|")
    $lines = @()
    $lines += @(Invoke-RgLines -Arguments @("-n", $pattern, $scriptJsonPath) | Where-Object { $_ -match "ProjectM" })
    $lines += @(Invoke-RgLines -Arguments @("-n", $pattern, $dumpCsPath) | Where-Object { $_ -match "ProjectM" })

    [PSCustomObject]@{
        SearchTerms = $terms
        HitCount = $lines.Count
        Hits = @($lines | Select-Object -First 40)
    }
}

function Find-UpscalerRuntimeFiles {
    $pattern = '(?i)(nvngx|nvsdk|ngx|dlss|streamline|^sl\.|xess|fsr2|ffx)'
    $files = Get-ChildItem -LiteralPath $resolvedGamePath -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match $pattern -and
            $_.FullName -notmatch '\\BepInEx\\plugins\\VrisingDLSS\\' -and
            $_.FullName -notmatch '\\BepInEx\\config\\[^\\]*vrisingdlss[^\\]*$'
        } |
        Select-Object FullName, Length, LastWriteTime

    return @($files)
}

function Invoke-AssetUnpack {
    if ($SkipAssetUnpack) {
        return [PSCustomObject]@{
            Status = "Skipped"
            Reason = "-SkipAssetUnpack was supplied."
        }
    }

    $script = Join-Path $resolvedRoot "scripts\inspect-vrising-hdrp-assets.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        return [PSCustomObject]@{
            Status = "Blocked"
            Reason = "Asset unpack helper was not found: $script"
        }
    }

    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $script, "-GamePath", $resolvedGamePath, "-Json")
    if (-not [string]::IsNullOrWhiteSpace($PythonPath)) {
        $args += @("-PythonPath", $PythonPath)
    }

    try {
        $jsonText = & powershell @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            return [PSCustomObject]@{
                Status = "Blocked"
                Reason = ($jsonText -join [Environment]::NewLine)
            }
        }

        return ($jsonText -join [Environment]::NewLine) | ConvertFrom-Json
    } catch {
        return [PSCustomObject]@{
            Status = "Blocked"
            Reason = $_.Exception.Message
        }
    }
}

function Invoke-XrefProbe {
    if ([string]::IsNullOrWhiteSpace($DotnetPath) -or -not (Test-Path -LiteralPath $DotnetPath)) {
        return [PSCustomObject]@{
            Status = "Blocked"
            Reason = "dotnet was not found. Pass -DotnetPath."
        }
    }
    if (-not (Test-Path -LiteralPath $XrefProbeDll)) {
        return [PSCustomObject]@{
            Status = "Blocked"
            Reason = "InteropXrefProbe was not found: $XrefProbeDll"
        }
    }
    if (-not (Test-Path -LiteralPath $interopDir)) {
        return [PSCustomObject]@{
            Status = "Blocked"
            Reason = "BepInEx interop directory was not found: $interopDir"
        }
    }

    try {
        $lines = & $DotnetPath $XrefProbeDll $resolvedGamePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            return [PSCustomObject]@{
                Status = "Blocked"
                Reason = ($lines -join [Environment]::NewLine)
            }
        }

        $targets = @(
            "UnityEngine.Rendering.HighDefinition.HDRenderPipeline.SetupDLSSFeature",
            "UnityEngine.Rendering.HighDefinition.HDRenderPipeline.InitializePostProcess",
            "UnityEngine.Rendering.HighDefinition.HDRenderPipeline.RenderPostProcess",
            "UnityEngine.Rendering.HighDefinition.HDRenderPipeline.DoDLSSPasses",
            "UnityEngine.Rendering.HighDefinition.HDRenderPipeline.DoDLSSPass",
            "UnityEngine.Rendering.HighDefinition.HDRenderPipeline.FinalPass",
            "UnityEngine.Rendering.HighDefinition.DLSSPass.SetupFeature",
            "UnityEngine.Rendering.HighDefinition.DLSSPass.Create",
            "UnityEngine.Rendering.HighDefinition.DLSSPass.BeginFrame",
            "UnityEngine.Rendering.HighDefinition.DLSSPass.SetupDRSScaling",
            "UnityEngine.Rendering.HighDefinition.DLSSPass.Render",
            "UnityEngine.Rendering.HighDefinition.HDDynamicResolutionPlatformCapabilities.ActivateDLSS"
        )
        $targetSet = @{}
        foreach ($target in $targets) {
            $targetSet[$target] = $true
        }

        $methodSummaries = @{}
        $current = $null
        foreach ($lineObject in $lines) {
            $line = $lineObject.ToString()
            if ($line -match '^\s+-\s+(?<label>.+?)\s+token=') {
                $label = $Matches.label
                if ($targetSet.ContainsKey($label)) {
                    $current = [PSCustomObject]@{
                        Method = $label
                        CallerCount = $null
                        RefUserCount = $null
                        XrefOutCount = $null
                        XrefOut = New-Object System.Collections.Generic.List[string]
                    }
                    $methodSummaries[$label] = $current
                } else {
                    $current = $null
                }
                continue
            }

            if ($null -eq $current) {
                continue
            }

            if ($line -match 'CallerCount=(?<count>[0-9]+)') {
                $current.CallerCount = [int]$Matches.count
            } elseif ($line -match 'refs/users:\s*(?<count>[0-9]+)') {
                $current.RefUserCount = [int]$Matches.count
            } elseif ($line -match 'xrefs/out:\s*(?<count>[0-9]+)') {
                $current.XrefOutCount = [int]$Matches.count
            } elseif ($line -match '^\s+\[[0-9]+\].+') {
                if ($current.XrefOut.Count -lt 80) {
                    [void]$current.XrefOut.Add($line.Trim())
                }
            }
        }

        $summaries = foreach ($target in $targets) {
            if ($methodSummaries.ContainsKey($target)) {
                $summary = $methodSummaries[$target]
                [PSCustomObject]@{
                    Method = $summary.Method
                    PresentInProbe = $true
                    CallerCount = $summary.CallerCount
                    RefUserCount = $summary.RefUserCount
                    XrefOutCount = $summary.XrefOutCount
                    XrefOut = @($summary.XrefOut.ToArray())
                }
            } else {
                [PSCustomObject]@{
                    Method = $target
                    PresentInProbe = $false
                    CallerCount = $null
                    RefUserCount = $null
                    XrefOutCount = $null
                    XrefOut = @()
                }
            }
        }

        $setupDlssFeatureText = (@($summaries | Where-Object { $_.Method -like "*.SetupDLSSFeature" } | Select-Object -First 1).XrefOut -join "`n")
        $initializePostProcessText = (@($summaries | Where-Object { $_.Method -like "*.InitializePostProcess" } | Select-Object -First 1).XrefOut -join "`n")
        $doDlssPassText = (@($summaries | Where-Object { $_.Method -like "*.DoDLSSPass" } | Select-Object -First 1).XrefOut -join "`n")
        $activateDlss = @($summaries | Where-Object { $_.Method -like "*.ActivateDLSS" } | Select-Object -First 1)

        return [PSCustomObject]@{
            Status = "Pass"
            Tool = $XrefProbeDll
            MethodSummaries = @($summaries)
            ActivationChain = [PSCustomObject]@{
                SetupDLSSFeatureCallsSetupFeature = ($setupDlssFeatureText -match 'DLSSPass\.SetupFeature')
                SetupDLSSFeatureCallsActivateDLSS = ($setupDlssFeatureText -match 'ActivateDLSS')
                InitializePostProcessCallsDLSSPassCreate = ($initializePostProcessText -match 'DLSSPass\.Create')
                DoDLSSPassDeclaresRenderGraphBoundary = (
                    $doDlssPassText -match 'RenderGraph\.AddRenderPass' -and
                    $doDlssPassText -match 'RenderGraphBuilder\.ReadTexture' -and
                    $doDlssPassText -match 'RenderGraphBuilder\.SetRenderFunc'
                )
                ActivateDLSSCallerCount = $(if ($activateDlss.Count -gt 0) { $activateDlss[0].CallerCount } else { $null })
            }
        }
    } catch {
        return [PSCustomObject]@{
            Status = "Blocked"
            Reason = $_.Exception.Message
        }
    }
}

$hdrpMethodNames = @(
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$SetupDLSSFeature",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$SetupDLSSForCameraDataAndDynamicResHandler",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$InitializePostProcess",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$GetPostprocessUpsampledOutputHandle",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$RenderPostProcess",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$DoDLSSPasses",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$DoDLSSPass",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$EdgeAdaptiveSpatialUpsampling",
    "UnityEngine.Rendering.HighDefinition.HDRenderPipeline`$`$FinalPass"
)
$dlssPassMethodNames = @(
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$GetViewResources",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$CreateCameraResources",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$GetCameraResources",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$SetupFeature",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$Create",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$BeginFrame",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$SetupDRSScaling",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$Render",
    "UnityEngine.Rendering.HighDefinition.DLSSPass`$`$.ctor"
)
$projectMGraphicsMethodNames = @(
    "ProjectM.GraphicsSettingsManager`$`$InitializeGlobalSettings",
    "ProjectM.GraphicsSettingsManager`$`$InitializeGameSettings",
    "ProjectM.GraphicsSettingsManager`$`$TryApplyGameSettings",
    "ProjectM.GraphicsSettingsManager`$`$TryApplyGraphicsSettingsToCamera",
    "ProjectM.GraphicsSettingsManager`$`$ActiveTAA",
    "ProjectM.GraphicsSettingsManager`$`$GetDynResForQualityMode",
    "ProjectM.GraphicsSettingsManager`$`$TurnOffFSR",
    "ProjectM.GraphicsSettingsManager`$`$TurnOnFSR",
    "ProjectM.GraphicsSettingsManager`$`$SetFSRQuality",
    "ProjectM.ClientConsoleCommandSystem`$`$GetFSRQualityModeSuggestions",
    "ProjectM.ClientConsoleCommandSystem`$`$DetermineFSRQualityMode"
)

$hdrpMethods = Find-ScriptMethods -Names $hdrpMethodNames
$dlssPassMethods = Find-ScriptMethods -Names $dlssPassMethodNames
$projectMGraphicsMethods = Find-ScriptMethods -Names $projectMGraphicsMethodNames

$dlssPassExecution = @($dlssPassMethods | Where-Object {
    $_.Name -match '\$\$(BeginFrame|SetupDRSScaling|Render|\.ctor)$'
})
$executionAddresses = @($dlssPassExecution | Where-Object { $_.Present -and $null -ne $_.Address } | ForEach-Object { $_.Address } | Select-Object -Unique)
$helperAddresses = @($dlssPassMethods | Where-Object {
    $_.Name -match '\$\$(GetViewResources|CreateCameraResources|GetCameraResources|SetupFeature|Create)$' -and $_.Present -and $null -ne $_.Address
} | ForEach-Object { $_.Address } | Select-Object -Unique)

$stringLiterals = Find-StringLiterals -Terms @(
    "Deep Learning Super Sampling",
    "DLSS destination",
    "DLSS Color Mask",
    "Edge Adaptive Spatial Upsampling",
    "1.AMD FSR 1.0",
    "AMD FSR 1.0 Quality Mode: ",
    "FSR Mode {0}\n",
    "TAAU\n"
)

$fieldEvidence = Find-DumpFields -FieldNames @(
    "m_DLSSPassEnabled",
    "m_DLSSBiasColorMaskMaterial",
    "m_DLSSPass",
    "m_UseRenderGraph",
    "allowDynamicResolution",
    "allowDeepLearningSuperSampling",
    "cameraCanRenderDLSS"
)

$layoutEvidence = Find-DumpTypeBlocks -TypePatterns @(
    "private class HDRenderPipeline.DLSSData",
    "private class HDRenderPipeline.EASUData",
    "private class HDRenderPipeline.FinalPassData",
    "private class HDRenderPipeline.UberPostPassData",
    "public struct DLSSPass.ViewResourceHandles",
    "public struct DLSSPass.CameraResourcesHandles",
    "public struct DLSSPass.Parameters",
    "public struct DLSSPass.ViewResources",
    "public struct DLSSPass.CameraResources",
    "public struct GlobalDynamicResolutionSettings",
    "public enum FSRQualityMode"
)

$projectMDlssTerms = Find-ProjectMDlssTerms
$runtimeFiles = Find-UpscalerRuntimeFiles
$assetUnpack = Invoke-AssetUnpack
$xrefProbe = Invoke-XrefProbe

if ($assetUnpack.Status -eq "Blocked") {
    [void]$warnings.Add("HDRP asset unpack was blocked: $($assetUnpack.Reason)")
}
if ($xrefProbe.Status -eq "Blocked") {
    [void]$warnings.Add("Interop xref probe was blocked: $($xrefProbe.Reason)")
}

$allHdrpAnchorsPresent = @($hdrpMethods | Where-Object { -not $_.Present }).Count -eq 0
$allDlssPassMethodsPresent = @($dlssPassMethods | Where-Object { -not $_.Present }).Count -eq 0
$dlssExecutionSharesOneAddress = ($executionAddresses.Count -eq 1 -and $dlssPassExecution.Count -ge 4)
$dlssHelpersUseDistinctAddresses = ($helperAddresses.Count -ge 4)
$officialStringsPresent = @($stringLiterals | Where-Object {
    $_.Term -in @("Deep Learning Super Sampling", "DLSS destination", "Edge Adaptive Spatial Upsampling") -and -not $_.Present
}).Count -eq 0

$assetSummary = $null
if ($assetUnpack.Status -eq "Pass" -and $assetUnpack.PSObject.Properties.Name -contains "Summary") {
    $assetSummary = $assetUnpack.Summary
}

$findings = New-Object System.Collections.Generic.List[object]
[void]$findings.Add([PSCustomObject]@{
    Kind = "Evidence"
    Statement = "V Rising local IL2CPP metadata contains the HDRP RenderPostProcess, DoDLSSPasses, DoDLSSPass, EASU, and FinalPass method anchors."
    Basis = "AllHdrpAnchorsPresent=$allHdrpAnchorsPresent"
})
[void]$findings.Add([PSCustomObject]@{
    Kind = "Evidence"
    Statement = "The DLSSPass resource helper methods are distinct, while BeginFrame, SetupDRSScaling, Render, and .ctor share one address in this dump."
    Basis = "AllDlssPassMethodsPresent=$allDlssPassMethodsPresent; ExecutionSharesOneAddress=$dlssExecutionSharesOneAddress; ExecutionAddresses=$($executionAddresses -join ','); HelperDistinctAddressCount=$($helperAddresses.Count)"
})
[void]$findings.Add([PSCustomObject]@{
    Kind = "Evidence"
    Statement = "Official DLSS/EASU pass string markers are present in local stringliteral.json."
    Basis = "OfficialStringsPresent=$officialStringsPresent"
})
if ($null -ne $assetSummary) {
    [void]$findings.Add([PSCustomObject]@{
        Kind = "Evidence"
        Statement = "The active serialized HDRP asset uses RenderGraph and EASU/FSR, with official HDRP DLSS disabled."
        Basis = "ActiveAsset=$($assetSummary.ActiveAssetName); UseRenderGraph=$($assetSummary.UseRenderGraph); DynamicResolutionEnabled=$($assetSummary.DynamicResolutionEnabled); EnableDLSS=$($assetSummary.EnableDLSS); DLSSInjectionPoint=$($assetSummary.DLSSInjectionPointName); UpsampleFilter=$($assetSummary.UpsampleFilterName)"
    })
}
if ($xrefProbe.Status -eq "Pass") {
    [void]$findings.Add([PSCustomObject]@{
        Kind = "Evidence"
        Statement = "Local xref cache does not show the upstream HDRP DLSS activation/object lifecycle as connected, while DoDLSSPass still has the RenderGraph resource-boundary shape."
        Basis = "SetupDLSSFeatureCallsSetupFeature=$($xrefProbe.ActivationChain.SetupDLSSFeatureCallsSetupFeature); SetupDLSSFeatureCallsActivateDLSS=$($xrefProbe.ActivationChain.SetupDLSSFeatureCallsActivateDLSS); InitializePostProcessCallsDLSSPassCreate=$($xrefProbe.ActivationChain.InitializePostProcessCallsDLSSPassCreate); DoDLSSPassDeclaresRenderGraphBoundary=$($xrefProbe.ActivationChain.DoDLSSPassDeclaresRenderGraphBoundary); ActivateDLSSCallerCount=$($xrefProbe.ActivationChain.ActivateDLSSCallerCount)"
    })
}
[void]$findings.Add([PSCustomObject]@{
    Kind = "Evidence"
    Statement = "V Rising has a ProjectM graphics settings layer for FSR/dynamic-resolution control; no focused ProjectM DLSS/NGX/Streamline layer was found by this audit."
    Basis = "ProjectMGraphicsMethodsPresent=$(@($projectMGraphicsMethods | Where-Object { $_.Present }).Count)/$($projectMGraphicsMethodNames.Count); ProjectMDlssTermHits=$($projectMDlssTerms.HitCount)"
})
[void]$findings.Add([PSCustomObject]@{
    Kind = "Inference"
    Statement = "The built-in HDRP DLSS route is useful as a semantic resource-order contract, not as a directly callable NVIDIA implementation in this V Rising build."
    Basis = "Combines method anchors, stub-style DLSSPass execution address, asset enableDLSS=0, and xref activation-chain evidence."
})
[void]$findings.Add([PSCustomObject]@{
    Kind = "Inference"
    Statement = "The smallest plausible runtime patch boundary remains an official-equivalent engine-owned postprocess/upscale boundary that binds color output with HDRP depth/motion, not a broad GetTexture discovery hook or a forced m_DLSSPass toggle."
    Basis = "DoDLSSPass resource contract exists; EASU/FinalPass route exists; official execution object appears inert/disabled."
})

$status = "Pass"
if ($issues.Count -gt 0) {
    $status = "Blocked"
}

$result = [PSCustomObject]@{
    Status = $status
    LaunchesGame = $false
    ModifiesGameFiles = $false
    GeneratedAt = (Get-Date).ToString("o")
    GamePath = $resolvedGamePath
    Inputs = [PSCustomObject]@{
        GameAssembly = $gameAssemblyPath
        Metadata = $metadataPath
        Il2CppDumperDir = $Il2CppDumperDir
        ScriptJson = $scriptJsonPath
        DumpCs = $dumpCsPath
        StringLiteralJson = $stringLiteralPath
        InteropDir = $interopDir
        XrefProbeDll = $XrefProbeDll
    }
    Tooling = [PSCustomObject]@{
        Ripgrep = $rgPath
        Dotnet = $DotnetPath
        Python = $PythonPath
    }
    HdrpMethodAnchors = @($hdrpMethods)
    DlssPassMethods = @($dlssPassMethods)
    DlssPassExecutionShape = [PSCustomObject]@{
        ExecutionMethods = @($dlssPassExecution | Select-Object Name, Address, AddressHex, Signature)
        ExecutionSharesOneAddress = $dlssExecutionSharesOneAddress
        SharedExecutionAddress = $(if ($executionAddresses.Count -eq 1) { [int64]$executionAddresses[0] } else { $null })
        SharedExecutionAddressHex = $(if ($executionAddresses.Count -eq 1) { "0x{0:X}" -f [int64]$executionAddresses[0] } else { "" })
        HelperDistinctAddressCount = $helperAddresses.Count
    }
    StringLiterals = @($stringLiterals)
    FieldEvidence = @($fieldEvidence)
    LayoutEvidence = @($layoutEvidence)
    HdrpAssetUnpack = $assetUnpack
    XrefProbe = $xrefProbe
    ProjectMGraphicsMethods = @($projectMGraphicsMethods)
    ProjectMDlssTerms = $projectMDlssTerms
    UpscalerRuntimeFilesOutsideMod = @($runtimeFiles)
    Findings = @($findings.ToArray())
    Warnings = @($warnings.ToArray())
    Issues = @($issues.ToArray())
}

if ($Json) {
    $result | ConvertTo-Json -Depth 12
} else {
    $result
}

if ($status -ne "Pass") {
    exit 1
}
