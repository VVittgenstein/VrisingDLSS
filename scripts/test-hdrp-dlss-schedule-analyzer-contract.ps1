param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$analyzerPath = Join-Path $resolvedRoot "scripts\analyze-hdrp-dlss-schedule-audit.ps1"

if (-not (Test-Path -LiteralPath $analyzerPath -PathType Leaf)) {
    throw "Analyzer script is missing: $analyzerPath"
}

function New-TempLog {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )

    $dir = Join-Path $resolvedRoot "artifacts\dryrun"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $path = Join-Path $dir $Name
    Set-Content -LiteralPath $path -Value ($Lines -join [Environment]::NewLine) -Encoding UTF8
    return $path
}

function Invoke-Analyzer {
    param([Parameter(Mandatory = $true)][string]$Path)

    $jsonText = & $analyzerPath -LogPath $Path -Json
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw "Analyzer failed for $Path"
    }

    return $jsonText | ConvertFrom-Json
}

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [string]$Evidence = ""
    )

    [void]$Checks.Add([pscustomobject]@{
        Name = $Name
        Passed = $Passed
        Evidence = $Evidence
    })
}

$checks = New-Object System.Collections.Generic.List[object]

$contractLogPath = New-TempLog -Name "AnalyzerContractBindSynthetic.log" -Lines @(
    '[Info   :VrisingDLSS] Upscaler state probe snapshot: reason=synthetic; HDCamera.IsDLSSEnabled=False; GlobalDynamicResolutionSettings.enableDLSS=False',
    '[Info   :VrisingDLSS] RenderGraph pass-list compile #1: method=UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraph.CompileRenderGraph(Int32 graphHash) -> Void; passCount=80; enumerated=80; focusCount=6; args=[arg0=1]',
    '[Info   :VrisingDLSS] RenderGraph pass-data snapshot #1: compile=1; ordinal=70; pass="Uber Post"; category=postprocess; passType=UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphPass; dataType=UnityEngine.Rendering.HighDefinition.HDRenderPipeline+UberPostPassData; memberCount=7; members=[width:value:System.Int32=960; height:value:System.Int32=540; viewCount:value:System.Int32=1; source:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=60; destination:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78; logLut:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=77; bloomTexture:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=76]',
    '[Info   :VrisingDLSS] RenderGraph pass declaration #1: compile=1; ordinal=73; pass="Edge Adaptive Spatial Upsampling"; category=upscale; declarations=[read[0]:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78; write[0]:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79]',
    '[Info   :VrisingDLSS] RenderGraph pass-data snapshot #2: compile=1; ordinal=73; pass="Edge Adaptive Spatial Upsampling"; category=upscale; passType=UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphPass; dataType=UnityEngine.Rendering.HighDefinition.HDRenderPipeline+EASUData; memberCount=7; members=[inputWidth:value:System.Int32=960; inputHeight:value:System.Int32=540; outputWidth:value:System.Int32=1920; outputHeight:value:System.Int32=1080; viewCount:value:System.Int32=1; source:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=78; destination:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79]',
    '[Info   :VrisingDLSS] RenderGraph pass-data snapshot #3: compile=1; ordinal=75; pass="Final Pass"; category=final; passType=UnityEngine.Experimental.Rendering.RenderGraphModule.RenderGraphPass; dataType=UnityEngine.Rendering.HighDefinition.HDRenderPipeline+FinalPassData; memberCount=9; members=[performUpsampling:value:System.Boolean=True; dynamicResIsOn:value:System.Boolean=True; dynamicResFilter:value:UnityEngine.Rendering.DynamicResUpscaleFilter=EdgeAdaptiveScalingUpres; source:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=79; destination:texture:UnityEngine.Experimental.Rendering.RenderGraphModule.ResourceHandle type=Texture index=13]',
    '[Info   :VrisingDLSS] RenderGraph pass render-func metadata #1: compile=1; ordinal=73; pass="Edge Adaptive Spatial Upsampling"; category=upscale; renderFunc=UnityEngine.Experimental.Rendering.RenderGraphModule.RenderFunc`1[[UnityEngine.Rendering.HighDefinition.HDRenderPipeline+EASUData, Unity.RenderPipelines.HighDefinition.Runtime]]',
    '[Info   :VrisingDLSS] HDRP postprocess render args snapshot #1: camera={name=CameraParent,actualWidth=960, actualHeight=540}; source={name=CameraColor,width=960, height=540}; globalTextures=[_CameraDepthTexture={name=CameraDepthStencil,width=960, height=540}; _CameraMotionVectorsTexture={name=Motion Vectors,width=960, height=540}]'
)

$contractResult = Invoke-Analyzer -Path $contractLogPath

Add-Check -Checks $checks `
    -Name "contract-bind synthetic status" `
    -Passed ($contractResult.Status -eq "NoOfficialDlssPassObserved") `
    -Evidence "Status=$($contractResult.Status)"
Add-Check -Checks $checks `
    -Name "contract-bind synthetic contract verdict" `
    -Passed ($contractResult.Contract.Status -eq "EasuSuperResolutionChainWithHdrpDepthMotionObservedButContractIncomplete") `
    -Evidence "Contract=$($contractResult.Contract.Status)"
Add-Check -Checks $checks `
    -Name "contract-bind synthetic binds HDRP depth/motion" `
    -Passed ($contractResult.Contract.EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved -eq $true) `
    -Evidence "Count=$($contractResult.Counts.SuperResolutionChainsWithHdrpDepthMotion)"
Add-Check -Checks $checks `
    -Name "contract-bind synthetic keeps EASU incomplete" `
    -Passed ($contractResult.Contract.EasuDeclaresDepthMotion -eq $false) `
    -Evidence "EasuDeclaresDepthMotion=$($contractResult.Contract.EasuDeclaresDepthMotion)"
Add-Check -Checks $checks `
    -Name "contract-bind synthetic has no issues" `
    -Passed (@($contractResult.Issues).Count -eq 0) `
    -Evidence "Issues=$(@($contractResult.Issues) -join ' | ')"

$pollutedLogPath = New-TempLog -Name "AnalyzerContractBindSyntheticPolluted.log" -Lines @(
    (Get-Content -LiteralPath $contractLogPath),
    '[Info   :VrisingDLSS] DLSS user rendering evaluate succeeded: sequenceSuccesses=1'
)

$pollutedResult = Invoke-Analyzer -Path $pollutedLogPath
Add-Check -Checks $checks `
    -Name "polluted synthetic evaluate is rejected" `
    -Passed ($pollutedResult.Status -eq "Fail" -and @($pollutedResult.Issues | Where-Object { $_ -like "*evaluate*" }).Count -gt 0) `
    -Evidence "Status=$($pollutedResult.Status); Issues=$(@($pollutedResult.Issues) -join ' | ')"

$failedChecks = @($checks.ToArray() | Where-Object { -not $_.Passed })
$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    ContractLogPath = $contractLogPath
    PollutedLogPath = $pollutedLogPath
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Checks = @($checks.ToArray())
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}

if ($failedChecks.Count -gt 0) {
    exit 1
}
