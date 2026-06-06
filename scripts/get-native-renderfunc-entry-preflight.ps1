param(
    [string]$LogPath,

    [string]$Root,

    [string]$BepInExCorePath = "C:\Software\VRising\BepInEx\core",

    [string]$IlspyCmd = "C:\Software\dotnet-tools\ilspycmd.exe",

    [switch]$DeepInspect,

    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path

function Get-RegexValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $match = [regex]::Match($Text, $Pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value
}

function Get-LatestRenderFuncMetadataLog {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

    $artifactRoot = Join-Path $RepositoryRoot "artifacts"
    if (-not (Test-Path -LiteralPath $artifactRoot)) {
        return ""
    }

    $logs = Get-ChildItem -LiteralPath $artifactRoot -Recurse -File -Filter "LogOutput-rendergraph-renderfunc-metadata*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    $first = @($logs | Select-Object -First 1)
    if ($first.Count -eq 0) {
        return ""
    }

    return $first[0].FullName
}

function Invoke-IlspyType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolPath,

        [Parameter(Mandatory = $true)]
        [string]$AssemblyPath,

        [Parameter(Mandatory = $true)]
        [string]$TypeName
    )

    if (-not (Test-Path -LiteralPath $ToolPath) -or -not (Test-Path -LiteralPath $AssemblyPath)) {
        return ""
    }

    if (Test-Path -LiteralPath "C:\Software\dotnet") {
        $env:DOTNET_ROOT = "C:\Software\dotnet"
        if ($env:PATH -notlike "*C:\Software\dotnet*") {
            $env:PATH = "C:\Software\dotnet;$env:PATH"
        }
    }

    try {
        return (& $ToolPath -t $TypeName $AssemblyPath 2>&1) -join "`n"
    } catch {
        return $_.Exception.Message
    }
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Get-LatestRenderFuncMetadataLog -RepositoryRoot $resolvedRoot
}

$resolvedLogPath = ""
if (-not [string]::IsNullOrWhiteSpace($LogPath) -and (Test-Path -LiteralPath $LogPath)) {
    $resolvedLogPath = (Resolve-Path -LiteralPath $LogPath).Path
}

$entries = New-Object System.Collections.Generic.List[object]
if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath)) {
    Select-String -LiteralPath $resolvedLogPath -Pattern "RenderGraph pass render-func metadata #" |
        ForEach-Object {
            $line = $_.Line
            $pass = Get-RegexValue -Text $line -Pattern 'pass="([^"]+)"'
            $category = Get-RegexValue -Text $line -Pattern 'category=([^;]+);'
            $methodPtr = Get-RegexValue -Text $line -Pattern 'method_ptr=0x([0-9A-Fa-f]+)'
            $invokeImpl = Get-RegexValue -Text $line -Pattern 'invoke_impl=0x([0-9A-Fa-f]+)'
            $methodInfo = Get-RegexValue -Text $line -Pattern ' method=0x([0-9A-Fa-f]+)'
            $methodCode = Get-RegexValue -Text $line -Pattern 'method_code=0x([0-9A-Fa-f]+)'
            $methodName = Get-RegexValue -Text $line -Pattern 'Name=System\.String=([^, ]+)'
            $metadataToken = Get-RegexValue -Text $line -Pattern 'MetadataToken=System\.Int32=([0-9]+)'

            if (-not [string]::IsNullOrWhiteSpace($pass) -and -not [string]::IsNullOrWhiteSpace($methodPtr)) {
                $entries.Add([pscustomobject]@{
                    Pass = $pass
                    Category = $category
                    MethodName = $methodName
                    MetadataToken = $metadataToken
                    MethodPtr = $methodPtr.ToUpperInvariant()
                    InvokeImpl = $invokeImpl.ToUpperInvariant()
                    MethodInfo = $methodInfo.ToUpperInvariant()
                    MethodCode = $methodCode.ToUpperInvariant()
                })
            }
        }
}

$targetPasses = @("Uber Post", "Edge Adaptive Spatial Upsampling", "Final Pass")
$targetSummaries = foreach ($targetPass in $targetPasses) {
    $targetEntries = @($entries | Where-Object { $_.Pass -eq $targetPass })
    $methodPtrs = @($targetEntries | Select-Object -ExpandProperty MethodPtr -Unique)
    $invokeImpls = @($targetEntries | Select-Object -ExpandProperty InvokeImpl -Unique)
    $methodInfos = @($targetEntries | Select-Object -ExpandProperty MethodInfo -Unique)
    $methodCodes = @($targetEntries | Select-Object -ExpandProperty MethodCode -Unique)
    $methodNames = @($targetEntries | Select-Object -ExpandProperty MethodName -Unique)
    $tokens = @($targetEntries | Select-Object -ExpandProperty MetadataToken -Unique)
    $mismatchCount = @($targetEntries | Where-Object { $_.InvokeImpl -ne $_.MethodPtr }).Count

    [pscustomobject]@{
        Pass = $targetPass
        Entries = $targetEntries.Count
        MethodNames = $methodNames
        MetadataTokens = $tokens
        MethodPtrs = $methodPtrs
        InvokeImpls = $invokeImpls
        MethodInfos = $methodInfos
        MethodCodes = $methodCodes
        StableMethodPtr = $targetEntries.Count -gt 0 -and $methodPtrs.Count -eq 1
        StableMethodInfo = $targetEntries.Count -gt 0 -and $methodInfos.Count -eq 1
        InvokeImplMatchesMethodPtr = $targetEntries.Count -gt 0 -and $mismatchCount -eq 0
    }
}

$bepInExCoreResolved = ""
if (-not [string]::IsNullOrWhiteSpace($BepInExCorePath) -and (Test-Path -LiteralPath $BepInExCorePath)) {
    $bepInExCoreResolved = (Resolve-Path -LiteralPath $BepInExCorePath).Path
}

$runtimeDetourPath = if ($bepInExCoreResolved) { Join-Path $bepInExCoreResolved "MonoMod.RuntimeDetour.dll" } else { "" }
$runtimePath = if ($bepInExCoreResolved) { Join-Path $bepInExCoreResolved "Il2CppInterop.Runtime.dll" } else { "" }
$harmonySupportPath = if ($bepInExCoreResolved) { Join-Path $bepInExCoreResolved "Il2CppInterop.HarmonySupport.dll" } else { "" }

$deepEvidence = [pscustomobject]@{
    Ran = [bool]$DeepInspect
    NativeDetourIntPtrConstructor = $false
    MethodInfoHasMethodPointer = $false
    HarmonyBackendDetoursMethodPointer = $false
}

if ($DeepInspect) {
    $nativeDetourText = Invoke-IlspyType -ToolPath $IlspyCmd -AssemblyPath $runtimeDetourPath -TypeName "MonoMod.RuntimeDetour.NativeDetour"
    $methodInfoText = Invoke-IlspyType -ToolPath $IlspyCmd -AssemblyPath $runtimePath -TypeName "Il2CppInterop.Runtime.Runtime.VersionSpecific.MethodInfo.NativeMethodInfoStructHandler_24_0"
    $harmonyText = Invoke-IlspyType -ToolPath $IlspyCmd -AssemblyPath $harmonySupportPath -TypeName "Il2CppInterop.HarmonySupport.Il2CppDetourMethodPatcher"

    $deepEvidence = [pscustomobject]@{
        Ran = $true
        NativeDetourIntPtrConstructor = $nativeDetourText -match "NativeDetour\(IntPtr from, IntPtr to"
        MethodInfoHasMethodPointer = $methodInfoText -match "MethodPointer"
        HarmonyBackendDetoursMethodPointer = $harmonyText -match "originalNativeMethodInfo\.MethodPointer" -and $harmonyText -match "OriginalTrampoline"
    }
}

$missingTargets = @($targetSummaries | Where-Object { $_.Entries -eq 0 } | Select-Object -ExpandProperty Pass)
$unstableTargets = @($targetSummaries | Where-Object { -not $_.StableMethodPtr -or -not $_.StableMethodInfo -or -not $_.InvokeImplMatchesMethodPtr } | Select-Object -ExpandProperty Pass)

$status = if ([string]::IsNullOrWhiteSpace($resolvedLogPath)) {
    "Blocked_NoRenderFuncMetadataLog"
} elseif ($entries.Count -eq 0) {
    "Blocked_NoRenderFuncMetadataEntries"
} elseif ($missingTargets.Count -gt 0) {
    "Blocked_MissingFocusedPassMetadata"
} elseif ($unstableTargets.Count -gt 0) {
    "Blocked_UnstableFocusedMethodPointers"
} elseif ($DeepInspect -and (-not $deepEvidence.NativeDetourIntPtrConstructor -or -not $deepEvidence.MethodInfoHasMethodPointer -or -not $deepEvidence.HarmonyBackendDetoursMethodPointer)) {
    "Blocked_MissingNativeDetourEvidence"
} else {
    "PreflightPass_DesignOnly"
}

$result = [pscustomobject]@{
    Status = $status
    LogPath = $resolvedLogPath
    EntryCount = $entries.Count
    Targets = $targetSummaries
    MissingTargets = $missingTargets
    UnstableTargets = $unstableTargets
    CoreEvidence = [pscustomobject]@{
        BepInExCorePath = $bepInExCoreResolved
        MonoModRuntimeDetourDll = (Test-Path -LiteralPath $runtimeDetourPath)
        Il2CppInteropRuntimeDll = (Test-Path -LiteralPath $runtimePath)
        Il2CppHarmonySupportDll = (Test-Path -LiteralPath $harmonySupportPath)
        IlspyCmd = if (Test-Path -LiteralPath $IlspyCmd) { (Resolve-Path -LiteralPath $IlspyCmd).Path } else { "" }
    }
    DeepEvidence = $deepEvidence
    Decision = "This is preflight evidence only. It does not install a detour, start V Rising, touch resources, read command buffers, or evaluate DLSS."
    NextRecommendation = "If this passes, use the separately implemented native-renderfunc-entry stage for the first menu-only runtime proof. It should increment counters only and immediately call the original trampoline. Do not patch generated render funcs through Harmony."
    LaunchesGame = $false
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result
}
