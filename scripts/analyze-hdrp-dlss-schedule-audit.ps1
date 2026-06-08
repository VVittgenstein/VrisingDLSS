param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LogPath)) {
    throw "Log file was not found: $LogPath"
}

$resolvedLogPath = (Resolve-Path -LiteralPath $LogPath).Path
$text = Get-Content -LiteralPath $resolvedLogPath -Raw

function Count-Regex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    return [regex]::Matches(
        $Text,
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count
}

function Get-RegexMatches {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    return [regex]::Matches(
        $Text,
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Convert-GroupInt {
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.RegularExpressions.Group]$Group
    )

    if (-not $Group.Success) {
        return $null
    }

    return [int]::Parse($Group.Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

$uberPassDataPattern = 'RenderGraph pass-data snapshot #[^\r\n]*compile=(?<compile>\d+);[^\r\n]*pass="Uber Post"[^\r\n]*width:value:[^=]+=(?<width>\d+); height:value:[^=]+=(?<height>\d+);[^\r\n]*source:texture:[^;\]]*index=(?<source>\d+); destination:texture:[^;\]]*index=(?<destination>\d+)'
$easuPassDataPattern = 'RenderGraph pass-data snapshot #[^\r\n]*compile=(?<compile>\d+);[^\r\n]*pass="Edge Adaptive Spatial Upsampling"[^\r\n]*inputWidth:value:[^=]+=(?<inputWidth>\d+); inputHeight:value:[^=]+=(?<inputHeight>\d+); outputWidth:value:[^=]+=(?<outputWidth>\d+); outputHeight:value:[^=]+=(?<outputHeight>\d+);[^\r\n]*source:texture:[^;\]]*index=(?<source>\d+); destination:texture:[^;\]]*index=(?<destination>\d+)'
$finalPassDataPattern = 'RenderGraph pass-data snapshot #[^\r\n]*compile=(?<compile>\d+);[^\r\n]*pass="Final Pass"[^\r\n]*source:texture:[^;\]]*index=(?<source>\d+); destination:texture:[^;\]]*index=(?<destination>\d+)'
$easuDeclarationPattern = 'RenderGraph pass declaration #[^\r\n]*compile=(?<compile>\d+);[^\r\n]*pass="Edge Adaptive Spatial Upsampling"[^\r\n]*declarations=\[(?<declarations>[^\r\n]*)\]'
$hdrpPostprocessSnapshotPattern = 'HDRP postprocess render args snapshot #[^\r\n]*camera=\{[^\r\n]*actualWidth=(?<actualWidth>\d+), actualHeight=(?<actualHeight>\d+)[^\r\n]*source=\{[^\r\n]*width=(?<sourceWidth>\d+), height=(?<sourceHeight>\d+)[^\r\n]*globalTextures=\[_CameraDepthTexture=\{[^\r\n]*width=(?<depthWidth>\d+), height=(?<depthHeight>\d+)[^\r\n]*_CameraMotionVectorsTexture=\{[^\r\n]*width=(?<motionWidth>\d+), height=(?<motionHeight>\d+)'

$uberRecords = New-Object System.Collections.Generic.List[object]
$uberByCompile = @{}
foreach ($match in Get-RegexMatches -Text $text -Pattern $uberPassDataPattern) {
    $compile = Convert-GroupInt $match.Groups["compile"]
    $record = [pscustomobject]@{
        Compile = $compile
        Width = Convert-GroupInt $match.Groups["width"]
        Height = Convert-GroupInt $match.Groups["height"]
        SourceIndex = Convert-GroupInt $match.Groups["source"]
        DestinationIndex = Convert-GroupInt $match.Groups["destination"]
    }
    [void]$uberRecords.Add($record)

    if ($null -ne $compile -and -not $uberByCompile.ContainsKey($compile)) {
        $uberByCompile[$compile] = $record
    }
}

$easuRecords = New-Object System.Collections.Generic.List[object]
foreach ($match in Get-RegexMatches -Text $text -Pattern $easuPassDataPattern) {
    $inputWidth = Convert-GroupInt $match.Groups["inputWidth"]
    $inputHeight = Convert-GroupInt $match.Groups["inputHeight"]
    $outputWidth = Convert-GroupInt $match.Groups["outputWidth"]
    $outputHeight = Convert-GroupInt $match.Groups["outputHeight"]
    [void]$easuRecords.Add([pscustomobject]@{
        Compile = Convert-GroupInt $match.Groups["compile"]
        InputWidth = $inputWidth
        InputHeight = $inputHeight
        OutputWidth = $outputWidth
        OutputHeight = $outputHeight
        SourceIndex = Convert-GroupInt $match.Groups["source"]
        DestinationIndex = Convert-GroupInt $match.Groups["destination"]
        IsSuperResolution = ($null -ne $inputWidth -and $null -ne $outputWidth -and $inputWidth -lt $outputWidth) -or ($null -ne $inputHeight -and $null -ne $outputHeight -and $inputHeight -lt $outputHeight)
    })
}

$easuDeclarationRecords = New-Object System.Collections.Generic.List[object]
foreach ($match in Get-RegexMatches -Text $text -Pattern $easuDeclarationPattern) {
    $declarations = $match.Groups["declarations"].Value
    [void]$easuDeclarationRecords.Add([pscustomobject]@{
        Compile = Convert-GroupInt $match.Groups["compile"]
        ReadCount = Count-Regex -Text $declarations -Pattern 'read\['
        WriteCount = Count-Regex -Text $declarations -Pattern 'write\['
        HasNonZeroDepthAttachment = [regex]::IsMatch(
            $declarations,
            'depth:texture:[^;\]]*index=(?!0(?:;|\]))\d+',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    })
}

$hdrpInputRecords = New-Object System.Collections.Generic.List[object]
foreach ($match in Get-RegexMatches -Text $text -Pattern $hdrpPostprocessSnapshotPattern) {
    $actualWidth = Convert-GroupInt $match.Groups["actualWidth"]
    $actualHeight = Convert-GroupInt $match.Groups["actualHeight"]
    $sourceWidth = Convert-GroupInt $match.Groups["sourceWidth"]
    $sourceHeight = Convert-GroupInt $match.Groups["sourceHeight"]
    $depthWidth = Convert-GroupInt $match.Groups["depthWidth"]
    $depthHeight = Convert-GroupInt $match.Groups["depthHeight"]
    $motionWidth = Convert-GroupInt $match.Groups["motionWidth"]
    $motionHeight = Convert-GroupInt $match.Groups["motionHeight"]

    [void]$hdrpInputRecords.Add([pscustomobject]@{
        ActualWidth = $actualWidth
        ActualHeight = $actualHeight
        SourceWidth = $sourceWidth
        SourceHeight = $sourceHeight
        DepthWidth = $depthWidth
        DepthHeight = $depthHeight
        MotionWidth = $motionWidth
        MotionHeight = $motionHeight
        SourceMatchesCamera = $null -ne $actualWidth -and $actualWidth -eq $sourceWidth -and $actualHeight -eq $sourceHeight
        DepthMatchesCamera = $null -ne $actualWidth -and $actualWidth -eq $depthWidth -and $actualHeight -eq $depthHeight
        MotionMatchesCamera = $null -ne $actualWidth -and $actualWidth -eq $motionWidth -and $actualHeight -eq $motionHeight
    })
}

$finalByCompile = @{}
foreach ($match in Get-RegexMatches -Text $text -Pattern $finalPassDataPattern) {
    $compile = Convert-GroupInt $match.Groups["compile"]
    if ($null -eq $compile -or $finalByCompile.ContainsKey($compile)) {
        continue
    }

    $finalByCompile[$compile] = [pscustomobject]@{
        Compile = $compile
        SourceIndex = Convert-GroupInt $match.Groups["source"]
        DestinationIndex = Convert-GroupInt $match.Groups["destination"]
    }
}

$easuFinalChainCount = 0
$uberEasuChainCount = 0
$completeUberEasuFinalChainCount = 0
$completeSuperResolutionChainCount = 0
$superResolutionChainWithHdrpDepthMotionCount = 0
$firstEasuFinalChain = $null
$firstCompleteUberEasuFinalChain = $null
$firstSuperResolutionChainWithHdrpDepthMotion = $null
foreach ($record in $easuRecords) {
    if ($null -eq $record.Compile) {
        continue
    }

    $uberMatchesEasu = $false
    if ($uberByCompile.ContainsKey($record.Compile)) {
        $uberRecord = $uberByCompile[$record.Compile]
        if ($null -ne $uberRecord.DestinationIndex -and $uberRecord.DestinationIndex -eq $record.SourceIndex) {
            $uberMatchesEasu = $true
            $uberEasuChainCount++
        }
    }

    if (-not $finalByCompile.ContainsKey($record.Compile)) {
        continue
    }

    $finalRecord = $finalByCompile[$record.Compile]
    $easuMatchesFinal = $null -ne $record.DestinationIndex -and $record.DestinationIndex -eq $finalRecord.SourceIndex
    if ($easuMatchesFinal) {
        $easuFinalChainCount++
        if ($null -eq $firstEasuFinalChain) {
            $firstEasuFinalChain = "compile=$($record.Compile); easu=$($record.InputWidth)x$($record.InputHeight)->$($record.OutputWidth)x$($record.OutputHeight); easuSource=$($record.SourceIndex); easuDestination/finalSource=$($record.DestinationIndex); finalDestination=$($finalRecord.DestinationIndex)"
        }
    }

    if ($uberMatchesEasu -and $easuMatchesFinal) {
        $completeUberEasuFinalChainCount++
        $matchingHdrpInput = $null
        if ($record.IsSuperResolution) {
            $completeSuperResolutionChainCount++
            $matchingHdrpInput = $hdrpInputRecords |
                Where-Object {
                    $_.SourceMatchesCamera -and
                    $_.DepthMatchesCamera -and
                    $_.MotionMatchesCamera -and
                    $_.ActualWidth -eq $record.InputWidth -and
                    $_.ActualHeight -eq $record.InputHeight
                } |
                Select-Object -First 1
            if ($matchingHdrpInput) {
                $superResolutionChainWithHdrpDepthMotionCount++
            }
        }

        if ($null -eq $firstCompleteUberEasuFinalChain) {
            $firstCompleteUberEasuFinalChain = "compile=$($record.Compile); uberDestination/easuSource=$($record.SourceIndex); easu=$($record.InputWidth)x$($record.InputHeight)->$($record.OutputWidth)x$($record.OutputHeight); easuDestination/finalSource=$($record.DestinationIndex); finalDestination=$($finalRecord.DestinationIndex)"
        }

        if ($null -eq $firstSuperResolutionChainWithHdrpDepthMotion -and $record.IsSuperResolution -and $matchingHdrpInput) {
            $firstSuperResolutionChainWithHdrpDepthMotion = "compile=$($record.Compile); hdrp=$($matchingHdrpInput.ActualWidth)x$($matchingHdrpInput.ActualHeight); easu=$($record.InputWidth)x$($record.InputHeight)->$($record.OutputWidth)x$($record.OutputHeight); depth=$($matchingHdrpInput.DepthWidth)x$($matchingHdrpInput.DepthHeight); motion=$($matchingHdrpInput.MotionWidth)x$($matchingHdrpInput.MotionHeight)"
        }
    }
}

$counts = [ordered]@{
    RenderGraphCompileSnapshots = Count-Regex -Text $text -Pattern "RenderGraph pass-list compile #"
    RenderGraphObservationLines = Count-Regex -Text $text -Pattern "RenderGraph pass-list compile #|RenderGraph pass-data snapshot #|RenderGraph pass declaration #|RenderGraph pass render-func metadata #|RenderGraph compiled-pass-info #"
    RenderGraphFocusedEntries = Count-Regex -Text $text -Pattern "RenderGraph pass-list entry #"
    DeepLearningSuperSamplingPass = Count-Regex -Text $text -Pattern 'pass="Deep Learning Super Sampling"'
    DlssPassCategory = Count-Regex -Text $text -Pattern "category=dlss"
    DlssPassDataSnapshots = Count-Regex -Text $text -Pattern 'RenderGraph pass-data snapshot #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssResourceDeclarations = Count-Regex -Text $text -Pattern 'RenderGraph pass declaration #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssRenderFuncMetadata = Count-Regex -Text $text -Pattern 'RenderGraph pass render-func metadata #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssCompiledPassInfo = Count-Regex -Text $text -Pattern 'RenderGraph compiled-pass-info #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssDestinationMentions = Count-Regex -Text $text -Pattern "DLSS destination"
    EasuPassMentions = Count-Regex -Text $text -Pattern "Edge Adaptive Spatial Upsampling"
    UberPassDataSnapshots = $uberRecords.Count
    EasuPassDataSnapshots = $easuRecords.Count
    EasuSuperResolutionPassDataSnapshots = @($easuRecords | Where-Object { $_.IsSuperResolution }).Count
    EasuResourceDeclarations = Count-Regex -Text $text -Pattern 'RenderGraph pass declaration #[^\r\n]*pass="Edge Adaptive Spatial Upsampling"'
    EasuSingleReadSingleWriteDeclarations = @($easuDeclarationRecords | Where-Object { $_.ReadCount -eq 1 -and $_.WriteCount -eq 1 }).Count
    EasuMultiReadDeclarations = @($easuDeclarationRecords | Where-Object { $_.ReadCount -gt 1 }).Count
    EasuNonZeroDepthAttachmentDeclarations = @($easuDeclarationRecords | Where-Object { $_.HasNonZeroDepthAttachment }).Count
    EasuRenderFuncMetadata = Count-Regex -Text $text -Pattern 'RenderGraph pass render-func metadata #[^\r\n]*pass="Edge Adaptive Spatial Upsampling"'
    EasuCompiledPassInfo = Count-Regex -Text $text -Pattern 'RenderGraph compiled-pass-info #[^\r\n]*pass="Edge Adaptive Spatial Upsampling"'
    UberEasuSourceChains = $uberEasuChainCount
    EasuFinalSourceChains = $easuFinalChainCount
    CompleteUberEasuFinalChains = $completeUberEasuFinalChainCount
    CompleteSuperResolutionChains = $completeSuperResolutionChainCount
    SuperResolutionChainsWithHdrpDepthMotion = $superResolutionChainWithHdrpDepthMotionCount
    FinalPassMentions = Count-Regex -Text $text -Pattern "Final Pass"
    FinalPassDataSnapshots = $finalByCompile.Count
    MotionVectorPassMentions = Count-Regex -Text $text -Pattern 'pass="[^"]*Motion Vectors[^"]*"'
    HdrpPostProcessRenderArgSnapshots = $hdrpInputRecords.Count
    HdrpPostProcessDepthMotionInputMatches = @($hdrpInputRecords | Where-Object { $_.SourceMatchesCamera -and $_.DepthMatchesCamera -and $_.MotionMatchesCamera }).Count
    HdrpEasuCorrelationAdvanced = Count-Regex -Text $text -Pattern "HDRP/EASU input-output correlation advanced:"
    HdrpEasuCorrelationReady = Count-Regex -Text $text -Pattern "HDRP/EASU input-output correlation advanced:[^\r\n]*hdrpCameraMatchesEasuInput=True; hdrpColorMatchesEasuInput=True; hdrpDepthMotionMatchEasuInput=True; easuSourceMatchesEasuInput=True; easuDestinationMatchesEasuOutput=True; easuUpscales=True"
    UpscalerStateSnapshots = Count-Regex -Text $text -Pattern "Upscaler state probe snapshot"
    UpscalerStateCalls = Count-Regex -Text $text -Pattern "Upscaler state probe call #"
    HDCameraIsDLSSEnabledTrue = Count-Regex -Text $text -Pattern "IsDLSSEnabled=True"
    HDCameraIsDLSSEnabledFalse = Count-Regex -Text $text -Pattern "IsDLSSEnabled=False"
    GlobalEnableDLSSTrue = Count-Regex -Text $text -Pattern "enableDLSS=True"
    GlobalEnableDLSSFalse = Count-Regex -Text $text -Pattern "enableDLSS=False"
    AllowDeepLearningSuperSamplingTrue = Count-Regex -Text $text -Pattern "allowDeepLearningSuperSampling=True"
    AllowDeepLearningSuperSamplingFalse = Count-Regex -Text $text -Pattern "allowDeepLearningSuperSampling=False"
    CameraCanRenderDLSSTrue = Count-Regex -Text $text -Pattern "cameraCanRenderDLSS=True"
    CameraCanRenderDLSSFalse = Count-Regex -Text $text -Pattern "cameraCanRenderDLSS=False"
    HdrpDlssScheduleGateLogs = Count-Regex -Text $text -Pattern "HDRP DLSS schedule-gate (prefix|postfix):"
    HdrpDlssScheduleGateForcedCamera = Count-Regex -Text $text -Pattern "cameraCanRenderDLSS=False->True"
    HdrpDlssScheduleGateMissingPass = Count-Regex -Text $text -Pattern "m_DLSSPass=null"
    RenderGraphGetTextureCalls = Count-Regex -Text $text -Pattern "RenderGraph GetTexture call #"
    UserRenderingCandidateStarted = Count-Regex -Text $text -Pattern "DLSS user rendering candidate enabled|Native render-func command-buffer DLSS user-rendering"
    DlssEvaluateSucceeded = Count-Regex -Text $text -Pattern "DLSS .*evaluate succeeded|DLSS user rendering evaluate succeeded"
    AccessViolationIndicators = Count-Regex -Text $text -Pattern "0xc0000005|access violation|coreclr|nvwgf2umx"
}

$boundaryDetails = [pscustomobject]@{
    FirstEasuFinalChain = $firstEasuFinalChain
    FirstCompleteUberEasuFinalChain = $firstCompleteUberEasuFinalChain
    FirstSuperResolutionChainWithHdrpDepthMotion = $firstSuperResolutionChainWithHdrpDepthMotion
}

$officialContractObserved =
    $counts.DeepLearningSuperSamplingPass -gt 0 -and
    $counts.DlssPassDataSnapshots -gt 0 -and
    $counts.DlssResourceDeclarations -gt 0
$engineOwnedChainObserved = $counts.CompleteUberEasuFinalChains -gt 0
$engineOwnedSuperResolutionChainObserved = $counts.CompleteSuperResolutionChains -gt 0
$engineOwnedSuperResolutionChainWithHdrpDepthMotionObserved = $counts.SuperResolutionChainsWithHdrpDepthMotion -gt 0
$easuDeclaresDepthMotion = $counts.EasuMultiReadDeclarations -gt 0 -or $counts.EasuNonZeroDepthAttachmentDeclarations -gt 0

$contractMissing = New-Object System.Collections.Generic.List[string]
if (-not $officialContractObserved) {
    [void]$contractMissing.Add("Official Deep Learning Super Sampling RenderGraph pass/resource contract was not observed.")
}
if (-not $engineOwnedChainObserved) {
    [void]$contractMissing.Add("Engine-owned Uber Post -> EASU -> Final Pass color/output chain was not fully observed.")
}
if ($engineOwnedChainObserved -and -not $engineOwnedSuperResolutionChainObserved) {
    [void]$contractMissing.Add("Observed EASU chain is same-sized in this log; use gameplay/render-scale evidence for SR-sized 960x540 -> 1920x1080 shape.")
}
if ($engineOwnedSuperResolutionChainObserved -and -not $engineOwnedSuperResolutionChainWithHdrpDepthMotionObserved) {
    [void]$contractMissing.Add("No same-log HDRP source/depth/motion input snapshot was matched to the observed Super Resolution-sized EASU chain.")
}
if ($engineOwnedChainObserved -and -not $easuDeclaresDepthMotion) {
    [void]$contractMissing.Add("EASU pass declaration exposes source/destination only, not DLSS depth/motion reads; depth/motion must come from the separate HDRP postprocess/global texture correlation path.")
}
if ($counts.MotionVectorPassMentions -eq 0) {
    [void]$contractMissing.Add("No motion-vector RenderGraph pass evidence was observed in this log.")
}

$contractStatus = if ($officialContractObserved) {
    "OfficialDlssContractObserved"
} elseif ($engineOwnedSuperResolutionChainWithHdrpDepthMotionObserved) {
    "EasuSuperResolutionChainWithHdrpDepthMotionObservedButContractIncomplete"
} elseif ($engineOwnedSuperResolutionChainObserved) {
    "EasuSuperResolutionChainObservedButContractIncomplete"
} elseif ($engineOwnedChainObserved) {
    "EasuChainObservedButContractIncomplete"
} else {
    "InsufficientBoundaryEvidence"
}

$contractDetails = [pscustomobject]@{
    Status = $contractStatus
    OfficialContractObserved = $officialContractObserved
    EngineOwnedChainObserved = $engineOwnedChainObserved
    EngineOwnedSuperResolutionChainObserved = $engineOwnedSuperResolutionChainObserved
    EngineOwnedSuperResolutionChainWithHdrpDepthMotionObserved = $engineOwnedSuperResolutionChainWithHdrpDepthMotionObserved
    EasuDeclaresDepthMotion = $easuDeclaresDepthMotion
    MissingForOfficialEquivalentBoundary = $contractMissing.ToArray()
}

$issues = New-Object System.Collections.Generic.List[string]

if ($counts.AccessViolationIndicators -gt 0) {
    [void]$issues.Add("Crash/access-violation indicators were present in the log.")
}

if ($counts.UserRenderingCandidateStarted -gt 0 -or $counts.DlssEvaluateSucceeded -gt 0) {
    [void]$issues.Add("The schedule log contains user-rendering or DLSS evaluate evidence; this audit/gate stage must not run the native evaluate path.")
}

if ($counts.RenderGraphGetTextureCalls -gt 0) {
    [void]$issues.Add("RenderGraph GetTexture diagnostic calls were logged; the audit stage is expected to keep broad GetTexture discovery disabled.")
}

if ($counts.RenderGraphObservationLines -eq 0) {
    [void]$issues.Add("No RenderGraph CompileRenderGraph observation lines were logged.")
}

if ($counts.UpscalerStateSnapshots -eq 0 -and $counts.UpscalerStateCalls -eq 0) {
    [void]$issues.Add("No upscaler-state snapshots or calls were logged.")
}

$status = if ($issues.Count -gt 0) {
    "Fail"
} elseif ($counts.DeepLearningSuperSamplingPass -gt 0 -or $counts.DlssPassCategory -gt 0) {
    "OfficialDlssPassObserved"
} elseif ($counts.RenderGraphObservationLines -gt 0 -and ($counts.UpscalerStateSnapshots -gt 0 -or $counts.UpscalerStateCalls -gt 0)) {
    "NoOfficialDlssPassObserved"
} else {
    "Incomplete"
}

$nextRecommendation = switch ($status) {
    "OfficialDlssPassObserved" {
        if ($counts.HdrpDlssScheduleGateLogs -gt 0) {
            "The schedule-gate probe made the official Deep Learning Super Sampling pass shell appear. Use the logged DLSSData/resource declaration/render-func metadata to design the next no-native official-equivalent boundary proof; do not patch DLSSPass.Render directly."
        } else {
            "Use the logged DLSSData/resource declaration/render-func metadata to design a no-native official-equivalent boundary proof. Do not patch DLSSPass.Render directly."
        }
    }
    "NoOfficialDlssPassObserved" {
        if ($counts.HdrpDlssScheduleGateLogs -gt 0) {
            "The schedule-gate probe ran but no official Deep Learning Super Sampling pass shell appeared. Treat this as confirmation that camera/dynamic-resolution gates are insufficient; use the local m_DLSSPass xref audit to continue toward a no-native official-equivalent RenderGraph boundary proof."
        } elseif ($contractStatus -eq "EasuSuperResolutionChainWithHdrpDepthMotionObservedButContractIncomplete") {
            "Treat the official HDRP DLSS pass shell as absent under current V Rising settings. This log binds an engine-owned Super Resolution-sized Uber->EASU->Final chain to HDRP source/depth/motion input evidence, but it remains incomplete as an official DLSS RenderGraph contract because EASU still does not declare depth/motion reads. Next work should be a bounded no-write cost proof before any visible DLSS write-back is retried."
        } elseif ($contractStatus -eq "EasuSuperResolutionChainObservedButContractIncomplete") {
            "Treat the official HDRP DLSS pass shell as absent under current V Rising settings. This log observes a Super Resolution-sized Uber->EASU->Final chain, but it does not bind HDRP source/depth/motion input evidence in the same log. Next work should enable the contract-bind stage or equivalent depth/motion correlation before any no-write cost proof."
        } elseif ($contractStatus -eq "EasuChainObservedButContractIncomplete") {
            "Treat the official HDRP DLSS pass shell as absent under current V Rising settings. Existing Uber->EASU->Final RenderGraph color/output chain evidence is present, but this log is not an official-equivalent DLSS contract: EASU is same-sized here and does not declare depth/motion reads. Next work should bind the separate HDRP depth/motion correlation evidence to this engine-owned chain or produce a bounded no-write proof; avoid camera-gate probing and new mod-owned pass injection."
        } elseif ($counts.EasuFinalSourceChains -gt 0 -and $counts.EasuRenderFuncMetadata -gt 0) {
            "Treat the official HDRP DLSS pass shell as absent under current V Rising settings. Existing EASU->Final RenderGraph chain evidence is present; next work should compare this engine-owned upscaler chain against the official DLSS resource contract and avoid both camera-gate probing and new mod-owned pass injection."
        } else {
            "Treat the official HDRP DLSS pass shell as absent under current V Rising settings. The current static evidence points to an absent/inert m_DLSSPass/NVIDIA feature route, so next work should be a no-native official-equivalent RenderGraph boundary proof rather than another camera-gate probe."
        }
    }
    "Fail" {
        "Fix the audit pollution or crash indicator before using this log as boundary evidence."
    }
    default {
        "Rerun hdrp-dlss-schedule-audit in a stable menu or gameplay scene long enough to capture CompileRenderGraph and upscaler-state logs."
    }
}

$result = [pscustomobject]@{
    Status = $status
    LogPath = $resolvedLogPath
    Counts = [pscustomobject]$counts
    Boundary = $boundaryDetails
    Contract = $contractDetails
    Issues = $issues.ToArray()
    NextRecommendation = $nextRecommendation
    LaunchesGame = $false
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}
