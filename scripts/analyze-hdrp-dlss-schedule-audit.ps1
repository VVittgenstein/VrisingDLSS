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

$counts = [ordered]@{
    RenderGraphCompileSnapshots = Count-Regex -Text $text -Pattern "RenderGraph pass-list compile #"
    RenderGraphObservationLines = Count-Regex -Text $text -Pattern "RenderGraph pass-list compile #|RenderGraph pass-data snapshot #|RenderGraph pass declaration #|RenderGraph pass render-func metadata #|RenderGraph compiled-pass info #"
    RenderGraphFocusedEntries = Count-Regex -Text $text -Pattern "RenderGraph pass-list entry #"
    DeepLearningSuperSamplingPass = Count-Regex -Text $text -Pattern 'pass="Deep Learning Super Sampling"'
    DlssPassCategory = Count-Regex -Text $text -Pattern "category=dlss"
    DlssPassDataSnapshots = Count-Regex -Text $text -Pattern 'RenderGraph pass-data snapshot #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssResourceDeclarations = Count-Regex -Text $text -Pattern 'RenderGraph pass declaration #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssRenderFuncMetadata = Count-Regex -Text $text -Pattern 'RenderGraph pass render-func metadata #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssCompiledPassInfo = Count-Regex -Text $text -Pattern 'RenderGraph compiled-pass info #[^\r\n]*pass="Deep Learning Super Sampling"'
    DlssDestinationMentions = Count-Regex -Text $text -Pattern "DLSS destination"
    EasuPassMentions = Count-Regex -Text $text -Pattern "Edge Adaptive Spatial Upsampling"
    FinalPassMentions = Count-Regex -Text $text -Pattern "Final Pass"
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
            "The schedule-gate probe ran but no official Deep Learning Super Sampling pass shell appeared. Treat camera/dynamic-resolution gates as insufficient and inspect whether m_DLSSPass/DLSSPass.Create/NVIDIA module availability is the remaining blocker."
        } else {
            "Treat the official HDRP DLSS pass shell as absent under current V Rising settings. Next probe should explain which state gates it off, preferably through read-only HDCamera/GlobalDynamicResolutionSettings evidence before any state-changing patch."
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
    Issues = $issues.ToArray()
    NextRecommendation = $nextRecommendation
    LaunchesGame = $false
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}
