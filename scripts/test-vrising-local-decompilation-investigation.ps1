param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$GamePath,
    [switch]$RequireLocalEvidence,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]
$localEvidenceStatus = "NotRun"
$staticRoute = $null
$nativeStubs = $null
$officialContract = $null

function Add-Check {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [AllowEmptyString()]
        [string]$Evidence = "",

        [AllowEmptyString()]
        [string]$Failure = ""
    )

    if (-not $Passed) {
        if ([string]::IsNullOrWhiteSpace($Failure)) {
            [void]$issues.Add($Name)
        } else {
            [void]$issues.Add("${Name}: $Failure")
        }
    }

    [void]$checks.Add([pscustomobject]@{
            Name = $Name
            Status = $(if ($Passed) { "Pass" } else { "Fail" })
            Evidence = $Evidence
        })
}

function Test-ContainsAll {
    param(
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text -notmatch [regex]::Escape($pattern)) {
            return $false
        }
    }

    return $true
}

function Invoke-JsonScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [hashtable]$Arguments
    )

    $output = & $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    if ($exitCode -ne 0) {
        throw "$ScriptPath failed with exit code $exitCode. Output=$text"
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$ScriptPath produced no JSON."
    }

    return $text | ConvertFrom-Json
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

function Get-LayoutByType {
    param(
        [object[]]$Layouts,
        [string]$TypePattern
    )

    return @($Layouts | Where-Object { $_.Found -eq $true -and $_.Type -match $TypePattern } | Select-Object -First 1)
}

$systematicDocPath = Join-Path $resolvedRoot "docs\development\vrising-systematic-local-decompilation-investigation-2026-06-08.md"
$refreshDocPath = Join-Path $resolvedRoot "docs\development\vrising-local-decompilation-boundary-refresh-2026-06-08.md"
$staticRouteScript = Join-Path $resolvedRoot "scripts\inspect-vrising-hdrp-dlss-static-route.ps1"
$assetScript = Join-Path $resolvedRoot "scripts\inspect-vrising-hdrp-assets.ps1"
$nativeStubScript = Join-Path $resolvedRoot "scripts\inspect-vrising-hdrp-dlss-native-stubs.ps1"
$officialContractScript = Join-Path $resolvedRoot "scripts\test-vrising-hdrp-dlss-official-contract.ps1"

foreach ($path in @($systematicDocPath, $refreshDocPath, $staticRouteScript, $assetScript, $nativeStubScript, $officialContractScript)) {
    Add-Check `
        -Name "FileExists:$([System.IO.Path]::GetFileName($path))" `
        -Passed (Test-Path -LiteralPath $path -PathType Leaf) `
        -Evidence $path `
        -Failure "missing $path"
}

if (Test-Path -LiteralPath $systematicDocPath -PathType Leaf) {
    $systematicText = Get-Content -LiteralPath $systematicDocPath -Raw

    Add-Check `
        -Name "SystematicDocHasCleanRoomBoundary" `
        -Passed (Test-ContainsAll -Text $systematicText -Patterns @("Clean-Room Boundary", "Not allowed in release artifacts", "copied decompiled V Rising method bodies")) `
        -Evidence $systematicDocPath `
        -Failure "systematic investigation doc no longer states the clean-room publication boundary"

    Add-Check `
        -Name "SystematicDocSeparatesEvidenceFromInference" `
        -Passed (($systematicText -match "Evidence level:") -and ($systematicText -match "Inference:")) `
        -Evidence "Contains Evidence level and Inference markers." `
        -Failure "systematic investigation doc no longer clearly separates evidence and inference"

    Add-Check `
        -Name "SystematicDocAnswersTargetQuestions" `
        -Passed (Test-ContainsAll -Text $systematicText -Patterns @(
                "Is V Rising's HDRP route consistent with Unity HDRP source?",
                'Does `m_DLSSPass` exist, and when is it initialized?',
                "What are the actual gate values and sources?",
                "Where is the official equivalent evaluate boundary?",
                "V Rising Has Its Own FSR/Dynamic-Resolution Control Layer"
            )) `
        -Evidence "Current Answer To The User's Target Questions section is present." `
        -Failure "systematic investigation doc no longer covers the requested target questions"

    Add-Check `
        -Name "SystematicDocKeepsContractBindNextStep" `
        -Passed (Test-ContainsAll -Text $systematicText -Patterns @("hdrp-dlss-contract-bind-render-scale", "bounded no-write cost proof", "reintroduce NGX evaluate")) `
        -Evidence "Mainline next step remains contract-bind -> no-write cost -> evaluate." `
        -Failure "systematic investigation doc no longer preserves the safe next-step chain"
}

if (Test-Path -LiteralPath $refreshDocPath -PathType Leaf) {
    $refreshText = Get-Content -LiteralPath $refreshDocPath -Raw

    Add-Check `
        -Name "BoundaryRefreshRejectsUnsafeMainlineRoutes" `
        -Passed (Test-ContainsAll -Text $refreshText -Patterns @(
                'forcing or calling `m_DLSSPass`',
                'patching `DLSSPass.Render` directly',
                'broad steady-state `RenderGraphResourceRegistry.GetTexture(TextureHandle&)`',
                "new mod-owned RenderGraph pass injection as the normal route",
                "rerunning the same EASU visible-writeback candidate unchanged"
            )) `
        -Evidence $refreshDocPath `
        -Failure "boundary refresh doc no longer rejects the known unsafe/non-equivalent routes"

    Add-Check `
        -Name "BoundaryRefreshNamesClosestPlausibleBoundary" `
        -Passed (Test-ContainsAll -Text $refreshText -Patterns @("engine-owned postprocess/upscale render-function boundary", "HDRP depth and motion-vector resources", "DoDLSSPass")) `
        -Evidence "Closest plausible runtime boundary is documented." `
        -Failure "boundary refresh doc no longer states the current official-equivalent boundary hypothesis"
}

if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
    $gameFiles = @(
        (Join-Path $resolvedGamePath "VRising.exe"),
        (Join-Path $resolvedGamePath "GameAssembly.dll"),
        (Join-Path $resolvedGamePath "VRising_Data\il2cpp_data\Metadata\global-metadata.dat")
    )

    foreach ($path in $gameFiles) {
        Add-Check `
            -Name "GameEvidenceFileExists:$([System.IO.Path]::GetFileName($path))" `
            -Passed (Test-Path -LiteralPath $path -PathType Leaf) `
            -Evidence $path `
            -Failure "missing local game evidence file"
    }

    try {
        $staticRoute = Invoke-JsonScript -ScriptPath $staticRouteScript -Arguments @{
            Root = $resolvedRoot
            GamePath = $resolvedGamePath
            Json = $true
        }
        $nativeStubs = Invoke-JsonScript -ScriptPath $nativeStubScript -Arguments @{
            Root = $resolvedRoot
            GamePath = $resolvedGamePath
            Json = $true
        }
        $officialContract = Invoke-JsonScript -ScriptPath $officialContractScript -Arguments @{
            Root = $resolvedRoot
            GamePath = $resolvedGamePath
            Json = $true
        }

        $localEvidenceStatus = "Pass"

        Add-Check `
            -Name "StaticRouteAuditPassesWithoutRuntimeSideEffects" `
            -Passed (($staticRoute.Status -eq "Pass") -and (-not [bool]$staticRoute.LaunchesGame) -and (-not [bool]$staticRoute.ModifiesGameFiles)) `
            -Evidence "Status=$($staticRoute.Status); LaunchesGame=$($staticRoute.LaunchesGame); ModifiesGameFiles=$($staticRoute.ModifiesGameFiles)" `
            -Failure "static route audit failed or reported runtime/file side effects"

        $requiredHdrpAnchors = @("SetupDLSSFeature", "SetupDLSSForCameraDataAndDynamicResHandler", "InitializePostProcess", "GetPostprocessUpsampledOutputHandle", "RenderPostProcess", "DoDLSSPasses", "DoDLSSPass", "EdgeAdaptiveSpatialUpsampling", "FinalPass")
        $presentHdrpAnchors = @($staticRoute.HdrpMethodAnchors | Where-Object { $_.Present -eq $true } | ForEach-Object { [string]$_.ShortName })
        Add-Check `
            -Name "LocalHdrpRouteAnchorsPresent" `
            -Passed (Test-HasAll -Actual $presentHdrpAnchors -Required $requiredHdrpAnchors) `
            -Evidence "Present=$($presentHdrpAnchors -join ',')" `
            -Failure "one or more targeted HDRP route anchors are absent"

        $requiredDlssMethods = @("GetViewResources", "CreateCameraResources", "GetCameraResources", "SetupFeature", "Create", "BeginFrame", "SetupDRSScaling", "Render", ".ctor")
        $presentDlssMethods = @($staticRoute.DlssPassMethods | Where-Object { $_.Present -eq $true } | ForEach-Object { [string]$_.ShortName })
        Add-Check `
            -Name "LocalDlssPassMethodsPresent" `
            -Passed (Test-HasAll -Actual $presentDlssMethods -Required $requiredDlssMethods) `
            -Evidence "Present=$($presentDlssMethods -join ',')" `
            -Failure "one or more targeted DLSSPass methods are absent"

        $activation = $staticRoute.XrefProbe.ActivationChain
        Add-Check `
            -Name "LocalDlssActivationChainIsAbsentButContractRemains" `
            -Passed (($activation.DoDLSSPassDeclaresRenderGraphBoundary -eq $true) -and ($activation.ActivateDLSSCallerCount -eq 0) -and ($activation.SetupDLSSFeatureCallsSetupFeature -eq $false) -and ($activation.InitializePostProcessCallsDLSSPassCreate -eq $false)) `
            -Evidence "DoDLSSPassDeclaresRenderGraphBoundary=$($activation.DoDLSSPassDeclaresRenderGraphBoundary); ActivateDLSSCallerCount=$($activation.ActivateDLSSCallerCount); SetupDLSSFeatureCallsSetupFeature=$($activation.SetupDLSSFeatureCallsSetupFeature); InitializePostProcessCallsDLSSPassCreate=$($activation.InitializePostProcessCallsDLSSPassCreate)" `
            -Failure "local xref evidence no longer matches the inert official activation chain"

        $asset = $staticRoute.HdrpAssetUnpack.Summary
        Add-Check `
            -Name "LocalActiveHdrpAssetSelectsRenderGraphEasuNotDlss" `
            -Passed (($asset.UseRenderGraph -eq 1) -and ($asset.DynamicResolutionEnabled -eq 1) -and ($asset.EnableDLSS -eq 0) -and ($asset.DLSSInjectionPointName -eq "BeforePost") -and ($asset.UpsampleFilterName -eq "EdgeAdaptiveScalingUpres")) `
            -Evidence "Active=$($asset.ActiveAssetName); UseRenderGraph=$($asset.UseRenderGraph); DRS=$($asset.DynamicResolutionEnabled); EnableDLSS=$($asset.EnableDLSS); Injection=$($asset.DLSSInjectionPointName); UpsampleFilter=$($asset.UpsampleFilterName)" `
            -Failure "active HDRP asset no longer has the expected EASU/DLSS-off gate values"

        $projectMMethods = @($staticRoute.ProjectMGraphicsMethods | Where-Object { $_.Present -eq $true })
        Add-Check `
            -Name "LocalProjectMHasFsrLayerButNoFocusedDlssLayer" `
            -Passed (($projectMMethods.Count -ge 8) -and ($staticRoute.ProjectMDlssTerms.HitCount -eq 0) -and (@($staticRoute.UpscalerRuntimeFilesOutsideMod).Count -eq 0)) `
            -Evidence "ProjectMGraphicsMethods=$($projectMMethods.Count); ProjectMDlssTermHits=$($staticRoute.ProjectMDlssTerms.HitCount); UpscalerRuntimeFilesOutsideMod=$(@($staticRoute.UpscalerRuntimeFilesOutsideMod).Count)" `
            -Failure "ProjectM/upscaler search no longer supports the FSR-layer/no-focused-DLSS-layer conclusion"

        Add-Check `
            -Name "NativeStubAuditPassesWithoutRuntimeSideEffects" `
            -Passed (($nativeStubs.Status -eq "Pass") -and (-not [bool]$nativeStubs.LaunchesGame) -and (-not [bool]$nativeStubs.ModifiesGameFiles)) `
            -Evidence "Status=$($nativeStubs.Status); LaunchesGame=$($nativeStubs.LaunchesGame); ModifiesGameFiles=$($nativeStubs.ModifiesGameFiles)" `
            -Failure "native-stub audit failed or reported runtime/file side effects"

        $nativeMismatches = @($nativeStubs.Methods | Where-Object { $_.MatchesExpected -ne $true })
        $nativeMethodEvidence = (@($nativeStubs.Methods) | ForEach-Object {
                $shortName = [string]$_.Name -replace '^.*\$\$', ''
                "$shortName=$($_.Classification)"
            }) -join ", "
        Add-Check `
            -Name "NativeEntryBytesMatchExpectedDlssStubShape" `
            -Passed ($nativeMismatches.Count -eq 0) `
            -Evidence "Methods=$nativeMethodEvidence" `
            -Failure "one or more native entry-byte classifications changed"

        Add-Check `
            -Name "OfficialContractGuardPassesWithoutRuntimeSideEffects" `
            -Passed (($officialContract.Status -eq "Pass") -and (-not [bool]$officialContract.LaunchesGame) -and (-not [bool]$officialContract.ModifiesGameFiles)) `
            -Evidence "Status=$($officialContract.Status); Checks=$($officialContract.CheckCount); Boundary=$($officialContract.Summary.BoundaryImplication)" `
            -Failure "official-contract guard failed or reported runtime/file side effects"

        $layouts = @($staticRoute.LayoutEvidence)
        $dlssDataFields = Get-FieldNames -Layout (Get-LayoutByType -Layouts $layouts -TypePattern 'HDRenderPipeline\.DLSSData')
        $easuFields = Get-FieldNames -Layout (Get-LayoutByType -Layouts $layouts -TypePattern 'HDRenderPipeline\.EASUData')
        Add-Check `
            -Name "LocalLayoutStillSplitsOfficialDlssAndEasuContracts" `
            -Passed ((Test-HasAll -Actual $dlssDataFields -Required @("parameters", "resourceHandles", "pass")) -and (Test-HasAll -Actual $easuFields -Required @("inputWidth", "inputHeight", "outputWidth", "outputHeight", "source", "destination")) -and ($easuFields -notcontains "motionVectors") -and ($easuFields -notcontains "biasColorMask")) `
            -Evidence "DLSSData=$($dlssDataFields -join ','); EASUData=$($easuFields -join ',')" `
            -Failure "local layout evidence no longer cleanly separates the DLSS resource contract from EASU source/destination scaling"
    } catch {
        $localEvidenceStatus = "Fail"
        Add-Check `
            -Name "LocalDecompilationEvidenceCanBeRead" `
            -Passed $false `
            -Evidence $_.Exception.Message `
            -Failure "failed to run or parse one of the local evidence scripts"
    }
}

if ($RequireLocalEvidence -and $localEvidenceStatus -ne "Pass") {
    [void]$issues.Add("RequireLocalEvidence was set but LocalEvidenceStatus=$localEvidenceStatus")
}

$failedChecks = @($checks.ToArray() | Where-Object { $_.Status -ne "Pass" })
$status = if ($failedChecks.Count -eq 0 -and (-not $RequireLocalEvidence -or $localEvidenceStatus -eq "Pass")) {
    "Pass"
} else {
    "Fail"
}

$result = [pscustomobject]@{
    Status = $status
    LaunchesGame = $false
    ModifiesGameFiles = $false
    GamePath = $GamePath
    LocalEvidenceStatus = $localEvidenceStatus
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Issues = @($issues.ToArray())
    Summary = [pscustomobject]@{
        CleanRoomBoundary = "Records method names, RVAs, entry-byte shapes, xref summaries, asset values, and resource-contract summaries only; no decompiled game bodies or assets are release artifacts."
        OfficialContract = "Use DoDLSSPass as the resource-order/lifecycle contract; local DLSSPass execution is inert in this build."
        ActiveGameRoute = "Active HDRP asset selects RenderGraph EASU/FSR, with official HDRP DLSS disabled."
        NextBoundary = "Protected hdrp-dlss-contract-bind-render-scale proof, then bounded no-write cost proof before NGX evaluate returns."
    }
    Evidence = [pscustomobject]@{
        SystematicDoc = $systematicDocPath
        BoundaryRefreshDoc = $refreshDocPath
        StaticRouteStatus = if ($staticRoute) { $staticRoute.Status } else { $null }
        NativeStubStatus = if ($nativeStubs) { $nativeStubs.Status } else { $null }
        OfficialContractStatus = if ($officialContract) { $officialContract.Status } else { $null }
    }
    Checks = @($checks.ToArray())
}

if ($Json) {
    $result | ConvertTo-Json -Depth 7
} else {
    $result
}

if ($status -ne "Pass") {
    exit 1
}
