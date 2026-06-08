param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path "$PSScriptRoot\..").Path
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$inspectorPath = Join-Path $resolvedRoot "scripts\inspect-vrising-hdrp-dlss-static-route.ps1"

if (-not (Test-Path -LiteralPath $inspectorPath -PathType Leaf)) {
    throw "Static route inspector is missing: $inspectorPath"
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

function Get-Layout {
    param(
        [Parameter(Mandatory = $true)][object[]]$Layouts,
        [Parameter(Mandatory = $true)][string]$TypeRegex
    )

    return @($Layouts | Where-Object { $_.Found -eq $true -and $_.Type -match $TypeRegex } | Select-Object -First 1)
}

function Get-FieldNames {
    param([object]$Layout)

    if ($null -eq $Layout) {
        return @()
    }

    return @($Layout.Fields | ForEach-Object { [string]$_.Name })
}

function Test-HasAll {
    param(
        [string[]]$Actual,
        [string[]]$Required
    )

    foreach ($name in $Required) {
        if ($Actual -notcontains $name) {
            return $false
        }
    }

    return $true
}

function Test-HasNone {
    param(
        [string[]]$Actual,
        [string[]]$Rejected
    )

    foreach ($name in $Rejected) {
        if ($Actual -contains $name) {
            return $false
        }
    }

    return $true
}

$inspectJson = & $inspectorPath -Root $resolvedRoot -GamePath $GamePath -Json
if ([string]::IsNullOrWhiteSpace($inspectJson)) {
    throw "Static route inspector produced no JSON."
}

$report = $inspectJson | ConvertFrom-Json
$checks = New-Object System.Collections.Generic.List[object]

$layouts = @($report.LayoutEvidence)
$dlssData = Get-Layout -Layouts $layouts -TypeRegex 'HDRenderPipeline\.DLSSData'
$easuData = Get-Layout -Layouts $layouts -TypeRegex 'HDRenderPipeline\.EASUData'
$finalPassData = Get-Layout -Layouts $layouts -TypeRegex 'HDRenderPipeline\.FinalPassData'
$viewResourceHandles = Get-Layout -Layouts $layouts -TypeRegex 'DLSSPass\.ViewResourceHandles'
$parameters = Get-Layout -Layouts $layouts -TypeRegex 'DLSSPass\.Parameters'

$dlssDataFields = Get-FieldNames -Layout $dlssData
$easuFields = Get-FieldNames -Layout $easuData
$finalPassFields = Get-FieldNames -Layout $finalPassData
$viewResourceFields = Get-FieldNames -Layout $viewResourceHandles
$parameterFields = Get-FieldNames -Layout $parameters

$anchors = @($report.HdrpMethodAnchors)
$doDlssPass = @($anchors | Where-Object { $_.ShortName -eq "DoDLSSPass" } | Select-Object -First 1)
$requiredAnchors = @(
    "RenderPostProcess",
    "DoDLSSPasses",
    "DoDLSSPass",
    "GetPostprocessUpsampledOutputHandle",
    "EdgeAdaptiveSpatialUpsampling",
    "FinalPass"
)
$presentAnchors = @($anchors | Where-Object { $_.Present -eq $true } | ForEach-Object { [string]$_.ShortName })

Add-Check -Checks $checks `
    -Name "inspector is no-launch and no-modify" `
    -Passed ($report.Status -eq "Pass" -and -not [bool]$report.LaunchesGame -and -not [bool]$report.ModifiesGameFiles) `
    -Evidence "Status=$($report.Status); LaunchesGame=$($report.LaunchesGame); ModifiesGameFiles=$($report.ModifiesGameFiles)"

Add-Check -Checks $checks `
    -Name "official HDRP pass anchors are present" `
    -Passed (Test-HasAll -Actual $presentAnchors -Required $requiredAnchors) `
    -Evidence "Present=$($presentAnchors -join ',')"

Add-Check -Checks $checks `
    -Name "DoDLSSPass signature carries color depth motion and bias handles" `
    -Passed ($doDlssPass.Count -gt 0 -and $doDlssPass.Signature -match 'source' -and $doDlssPass.Signature -match 'depthBuffer' -and $doDlssPass.Signature -match 'motionVectors' -and $doDlssPass.Signature -match 'biasColorMask') `
    -Evidence "Signature=$($doDlssPass.Signature)"

Add-Check -Checks $checks `
    -Name "DLSSData binds pass parameters and camera resources" `
    -Passed (Test-HasAll -Actual $dlssDataFields -Required @("parameters", "resourceHandles", "pass")) `
    -Evidence "DLSSData=$($dlssDataFields -join ',')"

Add-Check -Checks $checks `
    -Name "DLSS view resources include source output depth motion and bias" `
    -Passed (Test-HasAll -Actual $viewResourceFields -Required @("source", "output", "depth", "motionVectors", "biasColorMask")) `
    -Evidence "ViewResourceHandles=$($viewResourceFields -join ',')"

Add-Check -Checks $checks `
    -Name "DLSS parameters include reset history pre exposure camera and DRS settings" `
    -Passed (Test-HasAll -Actual $parameterFields -Required @("resetHistory", "preExposure", "hdCamera", "drsSettings")) `
    -Evidence "Parameters=$($parameterFields -join ',')"

Add-Check -Checks $checks `
    -Name "EASU contract is color-only source destination scaling" `
    -Passed ((Test-HasAll -Actual $easuFields -Required @("inputWidth", "inputHeight", "outputWidth", "outputHeight", "source", "destination")) -and (Test-HasNone -Actual $easuFields -Rejected @("depth", "motionVectors", "biasColorMask", "parameters", "resourceHandles", "pass"))) `
    -Evidence "EASUData=$($easuFields -join ',')"

Add-Check -Checks $checks `
    -Name "FinalPass consumes dynamic-resolution source to destination" `
    -Passed (Test-HasAll -Actual $finalPassFields -Required @("performUpsampling", "dynamicResIsOn", "dynamicResFilter", "source", "destination")) `
    -Evidence "FinalPassData=$($finalPassFields -join ',')"

$asset = $report.HdrpAssetUnpack.Summary
Add-Check -Checks $checks `
    -Name "active HDRP asset selects RenderGraph EASU and disables official DLSS" `
    -Passed ($asset.UseRenderGraph -eq 1 -and $asset.DynamicResolutionEnabled -eq 1 -and $asset.EnableDLSS -eq 0 -and $asset.DLSSInjectionPointName -eq "BeforePost" -and $asset.UpsampleFilterName -eq "EdgeAdaptiveScalingUpres") `
    -Evidence "UseRenderGraph=$($asset.UseRenderGraph); DRS=$($asset.DynamicResolutionEnabled); EnableDLSS=$($asset.EnableDLSS); DLSSInjectionPoint=$($asset.DLSSInjectionPointName); UpsampleFilter=$($asset.UpsampleFilterName)"

$activation = $report.XrefProbe.ActivationChain
Add-Check -Checks $checks `
    -Name "DLSS activation chain is absent while DoDLSSPass RenderGraph contract remains" `
    -Passed ($activation.DoDLSSPassDeclaresRenderGraphBoundary -eq $true -and $activation.ActivateDLSSCallerCount -eq 0 -and $activation.SetupDLSSFeatureCallsSetupFeature -eq $false -and $activation.InitializePostProcessCallsDLSSPassCreate -eq $false) `
    -Evidence "DoDLSSPassDeclaresRenderGraphBoundary=$($activation.DoDLSSPassDeclaresRenderGraphBoundary); ActivateDLSSCallerCount=$($activation.ActivateDLSSCallerCount); SetupDLSSFeatureCallsSetupFeature=$($activation.SetupDLSSFeatureCallsSetupFeature); InitializePostProcessCallsDLSSPassCreate=$($activation.InitializePostProcessCallsDLSSPassCreate)"

$execution = $report.DlssPassExecutionShape
Add-Check -Checks $checks `
    -Name "DLSSPass runtime implementation is inert but helpers remain distinct" `
    -Passed ($execution.ExecutionSharesOneAddress -eq $true -and $execution.HelperDistinctAddressCount -ge 4) `
    -Evidence "ExecutionSharesOneAddress=$($execution.ExecutionSharesOneAddress); SharedExecutionAddress=$($execution.SharedExecutionAddressHex); HelperDistinctAddressCount=$($execution.HelperDistinctAddressCount)"

$failedChecks = @($checks.ToArray() | Where-Object { -not $_.Passed })
$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    GamePath = (Resolve-Path -LiteralPath $GamePath).Path
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Checks = @($checks.ToArray())
    Summary = [pscustomobject]@{
        OfficialDlssResourceContract = "source/output/depth/motionVectors/biasColorMask plus resetHistory/preExposure/DRS settings"
        ActiveGameUpscalerContract = "EASU source/destination scaling followed by FinalPass"
        BoundaryImplication = "Use DoDLSSPass as a clean-room resource-order contract; EASU ctx.cmd alone is not a complete DLSS-equivalent payload."
    }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result
}

if ($failedChecks.Count -gt 0) {
    exit 1
}
