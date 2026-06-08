param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$GamePath,
    [string]$SaveName = "11111",
    [switch]$RequirePass,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]
$stageReports = New-Object System.Collections.Generic.List[object]
$sessionDryRuns = New-Object System.Collections.Generic.List[object]
$facts = $null
$contractBindProof = $null
$baselineCaptureDryRun = $null
$runtimeProofPlan = $null

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

function Get-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $resolvedRoot $RelativePath
}

function Convert-BepInExConfigToMap {
    param([Parameter(Mandatory = $true)][string]$Text)

    $map = @{}
    $section = ""
    foreach ($line in ($Text -split "\r?\n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed -match "^\[(.+)\]$") {
            $section = $Matches[1]
            continue
        }

        if ($trimmed -match "^([^=]+?)\s*=\s*(.*)$") {
            $map["$section.$($Matches[1].Trim())"] = $Matches[2].Trim()
        }
    }

    return $map
}

function Get-MapValue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ($Map.ContainsKey($Key)) {
        return [string]$Map[$Key]
    }

    return "<missing>"
}

function Test-MapValue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Expected
    )

    $actual = Get-MapValue -Map $Map -Key $Key
    return $actual.Equals($Expected, [System.StringComparison]::OrdinalIgnoreCase)
}

function Add-ExpectedConfigChecks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Layer,

        [Parameter(Mandatory = $true)]
        [hashtable]$Map,

        [string[]]$RequiredTrue = @(),
        [string[]]$RequiredFalse = @(),
        [string[]]$RequiredEmpty = @()
    )

    foreach ($key in $RequiredTrue) {
        $actual = Get-MapValue -Map $Map -Key $key
        Add-Check `
            -Name "Layer${Layer}ConfigTrue:$key" `
            -Passed (Test-MapValue -Map $Map -Key $key -Expected "true") `
            -Evidence "actual=$actual" `
            -Failure "expected true but was $actual"
    }

    foreach ($key in $RequiredFalse) {
        $actual = Get-MapValue -Map $Map -Key $key
        Add-Check `
            -Name "Layer${Layer}ConfigFalse:$key" `
            -Passed (Test-MapValue -Map $Map -Key $key -Expected "false") `
            -Evidence "actual=$actual" `
            -Failure "expected false but was $actual"
    }

    foreach ($key in $RequiredEmpty) {
        $actual = Get-MapValue -Map $Map -Key $key
        Add-Check `
            -Name "Layer${Layer}ConfigEmpty:$key" `
            -Passed (Test-MapValue -Map $Map -Key $key -Expected "") `
            -Evidence "actual=$actual" `
            -Failure "expected empty but was $actual"
    }
}

function Get-ObjectProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) {
        return $null
    }

    return $Object.PSObject.Properties[$Name].Value
}

function ConvertTo-CommandArgument {
    param([AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return '""'
    }

    if ($Value -match '^[A-Za-z0-9_./:\\-]+$') {
        return $Value
    }

    '"' + ($Value -replace '"', '\"') + '"'
}

$factsPath = Get-RepoPath -RelativePath "docs\development\experiment-facts.json"
$writeConfigPath = Get-RepoPath -RelativePath "scripts\write-diagnostic-config.ps1"
$startSessionPath = Get-RepoPath -RelativePath "scripts\start-vrising-automation-session.ps1"
$captureFpsPath = Get-RepoPath -RelativePath "scripts\capture-vrising-fps.ps1"
$contractBindProofPath = Get-RepoPath -RelativePath "scripts\get-contract-bind-gameplay-proof.ps1"

foreach ($path in @($factsPath, $writeConfigPath, $startSessionPath, $captureFpsPath, $contractBindProofPath)) {
    Add-Check `
        -Name "FileExists:$([System.IO.Path]::GetFileName($path))" `
        -Passed (Test-Path -LiteralPath $path -PathType Leaf) `
        -Evidence $path `
        -Failure "missing $path"
}

if (Test-Path -LiteralPath $factsPath -PathType Leaf) {
    try {
        $facts = Get-Content -LiteralPath $factsPath -Raw | ConvertFrom-Json
        Add-Check `
            -Name "ExperimentFactsIsNoRuntimeNoModify" `
            -Passed ((-not [bool]$facts.launchesGame) -and (-not [bool]$facts.modifiesGameFiles)) `
            -Evidence "launchesGame=$($facts.launchesGame); modifiesGameFiles=$($facts.modifiesGameFiles)" `
            -Failure "experiment facts must remain no-runtime/no-modify"
    } catch {
        Add-Check -Name "ExperimentFactsJsonParse" -Passed $false -Evidence $_.Exception.Message -Failure $_.Exception.Message
    }
}

if (Test-Path -LiteralPath $contractBindProofPath -PathType Leaf) {
    try {
        $contractBindProofJson = & $contractBindProofPath -Root $resolvedRoot -Json
        if (-not [string]::IsNullOrWhiteSpace([string]$contractBindProofJson)) {
            $contractBindProof = $contractBindProofJson | ConvertFrom-Json
        }

        Add-Check `
            -Name "ContractBindGameplayProofPassedBeforeMatrix" `
            -Passed ($contractBindProof -and [string]$contractBindProof.Status -eq "Pass" -and (-not [bool]$contractBindProof.LaunchesGame) -and (-not [bool]$contractBindProof.ModifiesGameFiles)) `
            -Evidence "Status=$($contractBindProof.Status); Source=$($contractBindProof.Source); Artifact=$($contractBindProof.ArtifactLabel); LaunchesGame=$($contractBindProof.LaunchesGame); ModifiesGameFiles=$($contractBindProof.ModifiesGameFiles)" `
            -Failure "B/C/D cost isolation requires the protected contract-bind gameplay proof first"
    } catch {
        Add-Check -Name "ContractBindGameplayProofReadable" -Passed $false -Evidence $_.Exception.Message -Failure $_.Exception.Message
    }
}

if (Test-Path -LiteralPath $captureFpsPath -PathType Leaf) {
    try {
        $baselineCaptureDryRun = & $captureFpsPath `
            -Root $resolvedRoot `
            -ArtifactLabel "bounded-no-write-cost-matrix-baseline-dryrun" `
            -Seconds 30 `
            -DryRun

        Add-Check `
            -Name "BaselinePerformanceCaptureDryRunIsNoLaunch" `
            -Passed ((-not [bool]$baselineCaptureDryRun.LaunchesGame) -and [bool]$baselineCaptureDryRun.CapturesSystemMetrics -and [bool]$baselineCaptureDryRun.CapturesSystemSnapshots) `
            -Evidence "LaunchesGame=$($baselineCaptureDryRun.LaunchesGame); CapturesSystemMetrics=$($baselineCaptureDryRun.CapturesSystemMetrics); CapturesSystemSnapshots=$($baselineCaptureDryRun.CapturesSystemSnapshots)" `
            -Failure "baseline capture must keep system metrics and before/after snapshots"
    } catch {
        Add-Check -Name "BaselinePerformanceCaptureDryRun" -Passed $false -Evidence $_.Exception.Message -Failure $_.Exception.Message
    }
}

$commonForbidden = @(
    "Diagnostics.EnableD3D11TextureProbe",
    "Diagnostics.EnableFrameResourceProbe",
    "Diagnostics.EnableDlssRuntimeProbe",
    "Diagnostics.EnableDlssInitQueryProbe",
    "Diagnostics.EnableDlssOptimalSettingsProbe",
    "Diagnostics.EnableDlssFeatureCreateProbe",
    "Diagnostics.EnableDlssEvaluateInputProbe",
    "Diagnostics.EnableDlssSuperResolutionInputProbe",
    "Diagnostics.EnableDlssSuperResolutionEvaluateProbe",
    "Diagnostics.EnableDlssSuperResolutionPersistentEvaluateProbe",
    "Diagnostics.EnableDlssSuperResolutionFrameSequenceEvaluateProbe",
    "Diagnostics.EnableDlssVisibleWritebackProbe",
    "Diagnostics.KeepDlssVisibleWritebackProbeRunning",
    "Diagnostics.EnableDlssEvaluateProbe",
    "Diagnostics.EnableDlssPersistentEvaluateProbe",
    "Diagnostics.EnableRenderGraphDiagnosticPass",
    "Diagnostics.EnableExistingRenderFuncProbe",
    "Diagnostics.EnableResourceMaterializationProbe",
    "Diagnostics.EnableRenderGraphPassBoundaryProbe",
    "Diagnostics.EnableRenderGraphPassMapProbe",
    "Diagnostics.EnableRenderGraphExecuteDelegateProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssFeatureCreateProbe",
    "Diagnostics.EnableCustomPostProcessRegistrationProbe",
    "Diagnostics.EnableCustomPostProcessRenderEntryProbe",
    "Diagnostics.EnableHdrpPostProcessBoundaryProbe",
    "Diagnostics.EnableRenderGraphGetTextureProbe",
    "Diagnostics.EnableDlssPassResourceProbe",
    "Diagnostics.EnableHdrpDlssScheduleGateProbe",
    "Diagnostics.EnableDlssUserRenderingNoEvaluateProbe",
    "Diagnostics.EnableDlssCachedTupleDriverProbe",
    "Diagnostics.EnableHookProbe",
    "Diagnostics.EnableHarmonyCallProbe",
    "DLSS.EnableDLSS"
)

$nativeForbiddenForB = @(
    "Diagnostics.EnableNativeBridgeSmokeTest",
    "Diagnostics.EnableRenderThreadSmokeTest",
    "Diagnostics.EnableNativeRenderFuncEntryProbe",
    "Diagnostics.EnableNativeRenderFuncArgumentProbe",
    "Diagnostics.EnableNativeRenderFuncContextProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferEventProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferPayloadProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe",
    "Diagnostics.EnableNativeRenderFuncResourceIdentityProbe",
    "Diagnostics.EnableNativeRenderFuncResourceTupleProbe",
    "Diagnostics.EnableNativeRenderFuncResourceResolveProbe",
    "Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe",
    "Diagnostics.EnableNativeRenderFuncResourceD3D11Probe"
)

$heavyRenderGraphForbiddenForB = @(
    "Diagnostics.EnableRenderGraphPassListProbe",
    "Diagnostics.EnableRenderGraphPassResourceDeclarationProbe",
    "Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe",
    "Diagnostics.EnableRenderGraphCompiledPassInfoProbe"
)

$layers = @(
    [pscustomobject]@{
        Layer = "B"
        Id = "easu-carrier-only-cost"
        Stage = "easu-carrier-only-cost-render-scale"
        Description = "Focused engine-owned EASU carrier evidence only; no native, no evaluate, no broad GetTexture."
        RequiredTrue = @(
            "General.EnablePlugin",
            "Diagnostics.EnableRenderGraphPassDataSnapshotProbe",
            "Diagnostics.EnableHdrpPostProcessRenderArgsProbe",
            "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe",
            "Diagnostics.EnableRenderScaleControlProbe",
            "Diagnostics.EnableUpscalerStateProbe"
        )
        RequiredFalse = @($commonForbidden + $nativeForbiddenForB + $heavyRenderGraphForbiddenForB)
        RequiredEmpty = @("DLSS.DlssRuntimePath")
    },
    [pscustomobject]@{
        Layer = "C"
        Id = "native-desc-validate-only"
        Stage = "native-renderfunc-commandbuffer-frame-descriptor-d3d11-render-scale"
        Description = "Same-device D3D11 resource desc audit; no NGX init, no evaluate."
        RequiredTrue = @(
            "General.EnablePlugin",
            "Diagnostics.EnableNativeBridgeSmokeTest",
            "Diagnostics.EnableNativeRenderFuncEntryProbe",
            "Diagnostics.EnableNativeRenderFuncArgumentProbe",
            "Diagnostics.EnableNativeRenderFuncContextProbe",
            "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe",
            "Diagnostics.EnableNativeRenderFuncResourceIdentityProbe",
            "Diagnostics.EnableNativeRenderFuncResourceTupleProbe",
            "Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe",
            "Diagnostics.EnableHdrpPostProcessRenderArgsProbe",
            "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe",
            "Diagnostics.EnableRenderScaleControlProbe",
            "Diagnostics.EnableUpscalerStateProbe"
        )
        RequiredFalse = @($commonForbidden + @(
                "Diagnostics.EnableRenderThreadSmokeTest",
                "Diagnostics.EnableRenderGraphPassListProbe",
                "Diagnostics.EnableRenderGraphPassResourceDeclarationProbe",
                "Diagnostics.EnableRenderGraphPassDataSnapshotProbe",
                "Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe",
                "Diagnostics.EnableRenderGraphCompiledPassInfoProbe",
                "Diagnostics.EnableNativeRenderFuncCommandBufferEventProbe",
                "Diagnostics.EnableNativeRenderFuncCommandBufferPayloadProbe",
                "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe",
                "Diagnostics.EnableNativeRenderFuncResourceResolveProbe",
                "Diagnostics.EnableNativeRenderFuncResourceD3D11Probe"
            ))
        RequiredEmpty = @("DLSS.DlssRuntimePath")
    },
    [pscustomobject]@{
        Layer = "D"
        Id = "empty-plugin-event-callback"
        Stage = "native-renderfunc-commandbuffer-event-render-scale"
        Description = "Issue one existing command-buffer plugin event with an empty native callback."
        RequiredTrue = @(
            "General.EnablePlugin",
            "Diagnostics.EnableNativeBridgeSmokeTest",
            "Diagnostics.EnableNativeRenderFuncEntryProbe",
            "Diagnostics.EnableNativeRenderFuncArgumentProbe",
            "Diagnostics.EnableNativeRenderFuncContextProbe",
            "Diagnostics.EnableNativeRenderFuncCommandBufferEventProbe",
            "Diagnostics.EnableNativeRenderFuncResourceIdentityProbe",
            "Diagnostics.EnableNativeRenderFuncResourceTupleProbe",
            "Diagnostics.EnableRenderScaleControlProbe",
            "Diagnostics.EnableUpscalerStateProbe"
        )
        RequiredFalse = @($commonForbidden + @(
                "Diagnostics.EnableRenderThreadSmokeTest",
                "Diagnostics.EnableRenderGraphPassListProbe",
                "Diagnostics.EnableRenderGraphPassResourceDeclarationProbe",
                "Diagnostics.EnableRenderGraphPassDataSnapshotProbe",
                "Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe",
                "Diagnostics.EnableRenderGraphCompiledPassInfoProbe",
                "Diagnostics.EnableNativeRenderFuncCommandBufferPayloadProbe",
                "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe",
                "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe",
                "Diagnostics.EnableNativeRenderFuncResourceResolveProbe",
                "Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe",
                "Diagnostics.EnableNativeRenderFuncResourceD3D11Probe",
                "Diagnostics.EnableHdrpPostProcessRenderArgsProbe",
                "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe"
            ))
        RequiredEmpty = @("DLSS.DlssRuntimePath")
    }
)

if ($facts) {
    $matrixByLayer = @{}
    foreach ($entry in @($facts.boundaryCostMatrix)) {
        $matrixByLayer[[string]$entry.layer] = $entry
    }

    foreach ($layer in $layers) {
        $fact = $matrixByLayer[[string]$layer.Layer]
        $criteria = Get-ObjectProperty -Object $fact -Name "passCriteria"
        Add-Check `
            -Name "Layer$($layer.Layer)ExperimentFactMatchesStagePlan" `
            -Passed ($fact -and [string]$fact.id -eq [string]$layer.Id -and $criteria) `
            -Evidence "id=$($fact.id); stage=$($layer.Stage); criteriaPresent=$($null -ne $criteria)" `
            -Failure "experiment facts must contain layer $($layer.Layer) id=$($layer.Id) with pass criteria"

        if ($criteria) {
            Add-Check `
                -Name "Layer$($layer.Layer)NearBaselineThresholds" `
                -Passed ([double]$criteria.averageFpsRatioMin -ge 0.98 -and [double]$criteria.p95FrameMsDeltaMax -le 0.5 -and [double]$criteria.p99FrameMsDeltaMax -le 1.0 -and [bool]$criteria.forbidGpuUtilPowerCollapse) `
                -Evidence "averageFpsRatioMin=$($criteria.averageFpsRatioMin); p95Max=$($criteria.p95FrameMsDeltaMax); p99Max=$($criteria.p99FrameMsDeltaMax); forbidGpuUtilPowerCollapse=$($criteria.forbidGpuUtilPowerCollapse)" `
                -Failure "B/C/D must keep the near-baseline cost thresholds"
        }
    }
}

foreach ($layer in $layers) {
    try {
        $configDryRun = & $writeConfigPath `
            -Stage $layer.Stage `
            -OutputPath (Join-Path $resolvedRoot "artifacts\dryrun\VrisingDLSS-$($layer.Stage).cfg") `
            -DryRun

        $configMap = Convert-BepInExConfigToMap -Text ([string]$configDryRun.Config)
        Add-Check `
            -Name "Layer$($layer.Layer)ConfigDryRunNoLaunch:$($layer.Stage)" `
            -Passed ([string]$configDryRun.Stage -eq [string]$layer.Stage -and (-not [bool]$configDryRun.LaunchesGame)) `
            -Evidence "Stage=$($configDryRun.Stage); LaunchesGame=$($configDryRun.LaunchesGame)" `
            -Failure "write-diagnostic-config dry-run must not launch game"

        Add-ExpectedConfigChecks `
            -Layer $layer.Layer `
            -Map $configMap `
            -RequiredTrue ([string[]]$layer.RequiredTrue) `
            -RequiredFalse ([string[]]$layer.RequiredFalse) `
            -RequiredEmpty ([string[]]$layer.RequiredEmpty)

        [void]$stageReports.Add([pscustomobject]@{
                Layer = $layer.Layer
                Id = $layer.Id
                Stage = $layer.Stage
                Description = $layer.Description
                RequiredTrueCount = @($layer.RequiredTrue).Count
                RequiredFalseCount = @($layer.RequiredFalse).Count
                ConfigDryRunLaunchesGame = [bool]$configDryRun.LaunchesGame
                UsesNativeBridge = (Test-MapValue -Map $configMap -Key "Diagnostics.EnableNativeBridgeSmokeTest" -Expected "true")
                EnablesDlssRuntime = (Test-MapValue -Map $configMap -Key "Diagnostics.EnableDlssRuntimeProbe" -Expected "true")
                EnablesDlssEvaluate = ((Test-MapValue -Map $configMap -Key "Diagnostics.EnableDlssEvaluateProbe" -Expected "true") -or (Test-MapValue -Map $configMap -Key "Diagnostics.EnableDlssSuperResolutionEvaluateProbe" -Expected "true"))
                EnablesVisibleWrite = ((Test-MapValue -Map $configMap -Key "Diagnostics.EnableDlssVisibleWritebackProbe" -Expected "true") -or (Test-MapValue -Map $configMap -Key "Diagnostics.EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe" -Expected "true"))
                EnablesBroadGetTexture = (Test-MapValue -Map $configMap -Key "Diagnostics.EnableRenderGraphGetTextureProbe" -Expected "true")
            })
    } catch {
        Add-Check -Name "Layer$($layer.Layer)ConfigDryRun:$($layer.Stage)" -Passed $false -Evidence $_.Exception.Message -Failure $_.Exception.Message
    }

    if (-not [string]::IsNullOrWhiteSpace($GamePath) -and (Test-Path -LiteralPath $startSessionPath -PathType Leaf)) {
        try {
            $sessionDryRun = & $startSessionPath `
                -Root $resolvedRoot `
                -GamePath $GamePath `
                -Stage $layer.Stage `
                -ArtifactLabel "bounded-no-write-$($layer.Layer.ToLowerInvariant())-$($layer.Stage)-dryrun" `
                -SetClientResolution `
                -SetClientWindowMode `
                -ClientWindowMode 3 `
                -Width 1920 `
                -Height 1080 `
                -ProtectSave `
                -SaveName $SaveName `
                -DryRun

            $sessionPassed = [string]$sessionDryRun.Stage -eq [string]$layer.Stage `
                -and (-not [bool]$sessionDryRun.LaunchesGame) `
                -and (-not [bool]$sessionDryRun.LeavesGameRunning) `
                -and (-not [bool]$sessionDryRun.UseSdkWrapperNative) `
                -and [bool]$sessionDryRun.ProtectSave `
                -and [bool]$sessionDryRun.RestoresProtectedSave `
                -and [bool]$sessionDryRun.SaveFixtureResolved `
                -and [int]$sessionDryRun.SaveFixtureMatchCount -eq 1 `
                -and [bool]$sessionDryRun.SetClientResolution `
                -and [bool]$sessionDryRun.SetClientWindowMode `
                -and [int]$sessionDryRun.ClientWindowMode -eq 3

            Add-Check `
                -Name "Layer$($layer.Layer)SessionDryRunProtects1080pWindowedSave:$($layer.Stage)" `
                -Passed $sessionPassed `
                -Evidence "Stage=$($sessionDryRun.Stage); LaunchesGame=$($sessionDryRun.LaunchesGame); UseSdkWrapperNative=$($sessionDryRun.UseSdkWrapperNative); ProtectSave=$($sessionDryRun.ProtectSave); RestoresProtectedSave=$($sessionDryRun.RestoresProtectedSave); SaveFixtureMatchCount=$($sessionDryRun.SaveFixtureMatchCount); SetClientResolution=$($sessionDryRun.SetClientResolution); SetClientWindowMode=$($sessionDryRun.SetClientWindowMode); ClientWindowMode=$($sessionDryRun.ClientWindowMode)" `
                -Failure "session dry-run must preserve 1920x1080 Windowed protected SaveName=$SaveName and no SDK-wrapper"

            [void]$sessionDryRuns.Add([pscustomobject]@{
                    Layer = $layer.Layer
                    Stage = $layer.Stage
                    LaunchesGame = [bool]$sessionDryRun.LaunchesGame
                    LeavesGameRunning = [bool]$sessionDryRun.LeavesGameRunning
                    ProtectSave = [bool]$sessionDryRun.ProtectSave
                    RestoresProtectedSave = [bool]$sessionDryRun.RestoresProtectedSave
                    SaveName = [string]$sessionDryRun.SaveName
                    SaveFixtureResolved = [bool]$sessionDryRun.SaveFixtureResolved
                    SaveFixtureMatchCount = $sessionDryRun.SaveFixtureMatchCount
                    SaveFixtureSaveId = [string]$sessionDryRun.SaveFixtureSaveId
                    SetClientResolution = [bool]$sessionDryRun.SetClientResolution
                    SetClientWindowMode = [bool]$sessionDryRun.SetClientWindowMode
                    ClientWindowMode = $sessionDryRun.ClientWindowMode
                })
        } catch {
            Add-Check -Name "Layer$($layer.Layer)SessionDryRun:$($layer.Stage)" -Passed $false -Evidence $_.Exception.Message -Failure $_.Exception.Message
        }
    }
}

$runtimeLayers = @()
foreach ($layer in $layers) {
    $runtimeLayers += [pscustomobject]@{
        Layer = $layer.Layer
        Id = $layer.Id
        Stage = $layer.Stage
        Description = $layer.Description
        ArtifactLabel = "bounded-no-write-$($layer.Layer.ToLowerInvariant())-$($layer.Stage)-1080p-<date>-r1"
        RequiresComputerUse = $true
        MovementKeysAllowed = $false
        StartCommand = if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
            "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-vrising-automation-session.ps1 -GamePath $(ConvertTo-CommandArgument -Value $GamePath) -Stage $($layer.Stage) -ArtifactLabel bounded-no-write-$($layer.Layer.ToLowerInvariant())-$($layer.Stage)-1080p-<date>-r1 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -Width 1920 -Height 1080 -ProtectSave -SaveName $(ConvertTo-CommandArgument -Value $SaveName)"
        } else {
            "Pass -GamePath to materialize this protected runtime command."
        }
    }
}

$runtimeProofPlan = [pscustomobject]@{
    Question = "Which no-write boundary layer first causes the known low-GPU-utilization performance regression?"
    Hypothesis = "If the official-equivalent EASU boundary is cheap, B/C/D should remain near the same-run FSR Off baseline before NGX create/evaluate or visible write-back is reintroduced."
    RequiresComputerUse = $true
    MovementKeysAllowed = $false
    Fixture = "V Rising FSR Off, true 1920x1080 Windowed, protected SaveName=$SaveName, Computer Use Continue/11111 click once, no movement keys, save restore ChangeCount=0."
    Baseline = [pscustomobject]@{
        Layer = "A"
        Stage = "baseline-fsr-off"
        Capture = "PresentMon plus GPU/system metrics and before/after system snapshots."
        RequiredDryRun = if ($baselineCaptureDryRun) {
            [pscustomobject]@{
                CapturesSystemMetrics = [bool]$baselineCaptureDryRun.CapturesSystemMetrics
                CapturesSystemSnapshots = [bool]$baselineCaptureDryRun.CapturesSystemSnapshots
                LaunchesGame = [bool]$baselineCaptureDryRun.LaunchesGame
            }
        } else {
            $null
        }
    }
    Layers = $runtimeLayers
    PassCriteria = [pscustomobject]@{
        AverageFpsRatioMin = 0.98
        P95FrameMsDeltaMax = 0.5
        P99FrameMsDeltaMax = 1.0
        ForbidGpuUtilPowerCollapse = $true
    }
    PassSignals = @(
        "Average FPS ratio >= 0.98 versus same-run baseline for each B/C/D layer.",
        "P95 frame-time delta <= 0.5 ms and P99 delta <= 1.0 ms.",
        "No GPU utilization or power collapse relative to baseline.",
        "No NGX/DLSS runtime load, feature create, evaluate, visible write-back, broad RenderGraph.GetTexture loop, crash, or save drift.",
        "Cleanup reports SaveRestored=True, SaveAfterRestoreChangeCount=0, and RemainingVRisingProcessCount=0 after each run."
    )
    FailSignals = @(
        "Any B/C/D layer reproduces the low-GPU-utilization collapse.",
        "Any DLSS runtime/evaluate/visible-write signal appears before B/C/D pass.",
        "Computer Use unavailable before launch; defer rather than using foreground key/mouse automation.",
        "Any save restore failure, crash/WER, or residual V Rising process."
    )
}

$failedChecks = @($checks.ToArray() | Where-Object { $_.Status -ne "Pass" })
$status = if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" }

$result = [pscustomobject]@{
    Status = $status
    LaunchesGame = $false
    ModifiesGameFiles = $false
    GamePath = $GamePath
    SaveName = $SaveName
    ContractBindGameplayProofStatus = if ($contractBindProof) { [string]$contractBindProof.Status } else { "" }
    StageCount = $stageReports.Count
    StageReports = @($stageReports.ToArray())
    SessionDryRuns = @($sessionDryRuns.ToArray())
    RuntimeProofPlan = $runtimeProofPlan
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Checks = @($checks.ToArray())
    Issues = @($issues.ToArray())
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result
}

if ($RequirePass -and $status -ne "Pass") {
    throw "Bounded no-write cost matrix guard status=$status; Issues=$(@($issues) -join ' | ')"
}
