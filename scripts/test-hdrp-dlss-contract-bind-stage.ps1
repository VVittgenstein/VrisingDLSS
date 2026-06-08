param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$GamePath,
    [string]$SaveDir,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$stage = "hdrp-dlss-contract-bind-render-scale"
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]

function Convert-BepInExConfigToMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

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
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $map["$section.$key"] = $value
        }
    }

    return $map
}

function Add-ValueCheck {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Expected
    )

    $actual = if ($Map.ContainsKey($Key)) { [string]$Map[$Key] } else { "<missing>" }
    $passed = $actual.Equals($Expected, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $passed) {
        [void]$issues.Add("$Key expected $Expected but was $actual")
    }

    [void]$checks.Add([pscustomobject]@{
            Key = $Key
            Expected = $Expected
            Actual = $actual
            Status = $(if ($passed) { "Pass" } else { "Fail" })
        })
}

$requiredTrue = @(
    "General.EnablePlugin",
    "Diagnostics.EnableRenderGraphPassListProbe",
    "Diagnostics.EnableRenderGraphPassResourceDeclarationProbe",
    "Diagnostics.EnableRenderGraphPassDataSnapshotProbe",
    "Diagnostics.EnableRenderGraphPassRenderFuncMetadataProbe",
    "Diagnostics.EnableRenderGraphCompiledPassInfoProbe",
    "Diagnostics.EnableHdrpPostProcessRenderArgsProbe",
    "Diagnostics.EnableHdrpPostProcessRenderArgsGlobalTextureProbe",
    "Diagnostics.EnableRenderScaleControlProbe",
    "Diagnostics.EnableUpscalerStateProbe"
)

$requiredFalse = @(
    "Diagnostics.EnableNativeBridgeSmokeTest",
    "Diagnostics.EnableRenderThreadSmokeTest",
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
    "Diagnostics.EnableNativeRenderFuncEntryProbe",
    "Diagnostics.EnableNativeRenderFuncArgumentProbe",
    "Diagnostics.EnableNativeRenderFuncContextProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferEventProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferPayloadProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferFrameDescriptorD3D11Probe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssScratchEvaluateProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssPersistentScratchEvaluateProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssVisibleWritebackProbe",
    "Diagnostics.EnableNativeRenderFuncCommandBufferDlssFeatureCreateProbe",
    "Diagnostics.EnableNativeRenderFuncResourceIdentityProbe",
    "Diagnostics.EnableNativeRenderFuncResourceTupleProbe",
    "Diagnostics.EnableNativeRenderFuncResourceResolveProbe",
    "Diagnostics.EnableNativeRenderFuncResourceNativePointerProbe",
    "Diagnostics.EnableNativeRenderFuncResourceD3D11Probe",
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

$status = "Pass"
$configDryRun = $null
$diagnosticDryRun = $null
$sessionDryRun = $null

try {
    $configDryRun = & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") `
        -Stage $stage `
        -OutputPath (Join-Path $resolvedRoot "artifacts\dryrun\VrisingDLSS-hdrp-dlss-contract-bind-render-scale.cfg") `
        -DryRun

    if ($configDryRun.Stage -ne $stage) {
        [void]$issues.Add("write-diagnostic-config returned unexpected stage: $($configDryRun.Stage)")
    }
    if ([bool]$configDryRun.LaunchesGame) {
        [void]$issues.Add("write-diagnostic-config dry-run unexpectedly reports LaunchesGame=True")
    }

    $configMap = Convert-BepInExConfigToMap -Text ([string]$configDryRun.Config)
    foreach ($key in $requiredTrue) {
        Add-ValueCheck -Map $configMap -Key $key -Expected "true"
    }
    foreach ($key in $requiredFalse) {
        Add-ValueCheck -Map $configMap -Key $key -Expected "false"
    }
    Add-ValueCheck -Map $configMap -Key "DLSS.DlssRuntimePath" -Expected ""
    Add-ValueCheck -Map $configMap -Key "Advanced.RenderScaleOverride" -Expected "0"

    if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
        $diagnosticDryRun = & (Join-Path $resolvedRoot "scripts\run-vrising-diagnostic.ps1") `
            -Root $resolvedRoot `
            -GamePath $GamePath `
            -Stage $stage `
            -DurationSeconds 75 `
            -SetClientResolution `
            -SetClientWindowMode `
            -ClientWindowMode 3 `
            -Width 1920 `
            -Height 1080 `
            -DryRun

        if ($diagnosticDryRun.Stage -ne $stage) {
            [void]$issues.Add("run-vrising-diagnostic dry-run returned unexpected stage: $($diagnosticDryRun.Stage)")
        }
        if ([bool]$diagnosticDryRun.LaunchesGame) {
            [void]$issues.Add("run-vrising-diagnostic dry-run unexpectedly reports LaunchesGame=True")
        }
        if ([bool]$diagnosticDryRun.UseSdkWrapperNative) {
            [void]$issues.Add("run-vrising-diagnostic dry-run unexpectedly requests UseSdkWrapperNative=True")
        }
        if ([bool]$diagnosticDryRun.RestoresReleaseSafeNative) {
            [void]$issues.Add("run-vrising-diagnostic dry-run should not require native restore for this stage")
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($GamePath) -and -not [string]::IsNullOrWhiteSpace($SaveDir)) {
        $sessionDryRun = & (Join-Path $resolvedRoot "scripts\start-vrising-automation-session.ps1") `
            -Root $resolvedRoot `
            -GamePath $GamePath `
            -Stage $stage `
            -ArtifactLabel "hdrp-dlss-contract-bind-render-scale-dryrun" `
            -SetClientResolution `
            -SetClientWindowMode `
            -ClientWindowMode 3 `
            -Width 1920 `
            -Height 1080 `
            -ProtectSave `
            -SaveDir $SaveDir `
            -DryRun

        if ($sessionDryRun.Stage -ne $stage) {
            [void]$issues.Add("start-vrising-automation-session dry-run returned unexpected stage: $($sessionDryRun.Stage)")
        }
        if ([bool]$sessionDryRun.LaunchesGame -or [bool]$sessionDryRun.LeavesGameRunning) {
            [void]$issues.Add("start-vrising-automation-session dry-run unexpectedly reports a game launch or live game")
        }
        if (-not [bool]$sessionDryRun.ProtectSave -or -not [bool]$sessionDryRun.RestoresProtectedSave) {
            [void]$issues.Add("start-vrising-automation-session dry-run did not preserve protected-save intent")
        }
        if ([bool]$sessionDryRun.UseSdkWrapperNative) {
            [void]$issues.Add("start-vrising-automation-session dry-run unexpectedly requests UseSdkWrapperNative=True")
        }
    }
} catch {
    $status = "Blocked"
    [void]$issues.Add($_.Exception.Message)
}

if ($status -eq "Pass" -and $issues.Count -gt 0) {
    $status = "Fail"
}

$result = [pscustomobject]@{
    Status = $status
    Stage = $stage
    LaunchesGame = $false
    ModifiesGameFiles = $false
    RequiredTrueCount = $requiredTrue.Count
    RequiredFalseCount = $requiredFalse.Count
    CheckCount = $checks.Count
    FailedChecks = @($checks | Where-Object { $_.Status -ne "Pass" })
    DiagnosticDryRun = if ($diagnosticDryRun) {
        [pscustomobject]@{
            LaunchesGame = [bool]$diagnosticDryRun.LaunchesGame
            UseSdkWrapperNative = [bool]$diagnosticDryRun.UseSdkWrapperNative
            RestoresReleaseSafeNative = [bool]$diagnosticDryRun.RestoresReleaseSafeNative
            SetClientResolution = [bool]$diagnosticDryRun.SetClientResolution
            SetClientWindowMode = [bool]$diagnosticDryRun.SetClientWindowMode
            ClientWindowMode = $diagnosticDryRun.ClientWindowMode
        }
    } else {
        $null
    }
    SessionDryRun = if ($sessionDryRun) {
        [pscustomobject]@{
            LaunchesGame = [bool]$sessionDryRun.LaunchesGame
            LeavesGameRunning = [bool]$sessionDryRun.LeavesGameRunning
            ProtectSave = [bool]$sessionDryRun.ProtectSave
            RestoresProtectedSave = [bool]$sessionDryRun.RestoresProtectedSave
            UseSdkWrapperNative = [bool]$sessionDryRun.UseSdkWrapperNative
        }
    } else {
        $null
    }
    Issues = @($issues)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}
