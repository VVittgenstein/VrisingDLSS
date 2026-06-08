param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$ScheduleAuditLog = "artifacts\runtime-logs\LogOutput-hdrp-dlss-schedule-audit-1080p-menu-20260608-r1.log",
    [string]$DiagnosticPassCrashLog = "artifacts\runtime-logs\LogOutput-stage8a-rendergraph-diagnostic-pass-crash-gameplay-2026-06-05-083418.log",
    [string]$DiagnosticPassCrashWer = "artifacts\runtime-logs\WER-stage8a-rendergraph-diagnostic-pass-crash-gameplay-2026-06-05-083423.wer",
    [switch]$RequirePass,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path $resolvedRoot $Path)
}

function Add-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [AllowEmptyString()][string]$Evidence = "",
        [AllowEmptyString()][string]$Failure = ""
    )

    if (-not $Passed) {
        if ([string]::IsNullOrWhiteSpace($Failure)) {
            [void]$issues.Add("$Name failed")
        } else {
            [void]$issues.Add("$Name failed: $Failure")
        }
    }

    [void]$checks.Add([pscustomobject]@{
            Name = $Name
            Status = $(if ($Passed) { "Pass" } else { "Fail" })
            Evidence = $Evidence
        })
}

function Test-TextContains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    return ($Text -match [regex]::Escape($Pattern))
}

$status = "Pass"
$sourcePath = Join-Path $resolvedRoot "src\VrisingDLSS.Plugin\RenderGraphDiagnosticPass.cs"
$modConfigPath = Join-Path $resolvedRoot "src\VrisingDLSS.Plugin\ModConfig.cs"
$packageValidatorPath = Join-Path $resolvedRoot "scripts\validate-thunderstore-package.ps1"
$contractGuardPath = Join-Path $resolvedRoot "scripts\test-hdrp-dlss-contract-bind-stage.ps1"
$analyzerPath = Join-Path $resolvedRoot "scripts\analyze-hdrp-dlss-schedule-audit.ps1"
$resolvedScheduleAuditLog = Resolve-RepoPath -Path $ScheduleAuditLog
$resolvedDiagnosticPassCrashLog = Resolve-RepoPath -Path $DiagnosticPassCrashLog
$resolvedDiagnosticPassCrashWer = Resolve-RepoPath -Path $DiagnosticPassCrashWer

$analyzer = $null
$contractGuard = $null

try {
    foreach ($path in @($sourcePath, $modConfigPath, $packageValidatorPath, $contractGuardPath, $analyzerPath, $resolvedScheduleAuditLog, $resolvedDiagnosticPassCrashLog, $resolvedDiagnosticPassCrashWer)) {
        Add-Check -Name "FileExists:$([System.IO.Path]::GetFileName($path))" -Passed (Test-Path -LiteralPath $path -PathType Leaf) -Evidence $path -Failure "missing $path"
    }

    $sourceText = Get-Content -LiteralPath $sourcePath -Raw
    $modConfigText = Get-Content -LiteralPath $modConfigPath -Raw
    $packageValidatorText = Get-Content -LiteralPath $packageValidatorPath -Raw
    $crashLogText = Get-Content -LiteralPath $resolvedDiagnosticPassCrashLog -Raw
    $werText = Get-Content -LiteralPath $resolvedDiagnosticPassCrashWer -Raw

    Add-Check `
        -Name "ModOwnedPassCanBeConstructedInSource" `
        -Passed ((Test-TextContains -Text $sourceText -Pattern "renderGraph.AddRenderPass") -and (Test-TextContains -Text $sourceText -Pattern "builder.SetRenderFunc")) `
        -Evidence "RenderGraphDiagnosticPass.cs contains AddRenderPass and SetRenderFunc calls." `
        -Failure "source no longer contains the expected AddRenderPass/SetRenderFunc proof path"

    Add-Check `
        -Name "DiagnosticPassConfiguredWithRenderFuncBeforeCrash" `
        -Passed ((Test-TextContains -Text $crashLogText -Pattern "RenderGraph diagnostic pass configured") -and (Test-TextContains -Text $crashLogText -Pattern "hasRenderFunc=True") -and (Test-TextContains -Text $crashLogText -Pattern "allowPassCulling=False")) `
        -Evidence "Archived crash log shows configured diagnostic pass with hasRenderFunc=True and allowPassCulling=False." `
        -Failure "archived crash log does not show configured diagnostic pass evidence"

    Add-Check `
        -Name "DiagnosticPassDeclaredColorDepthMotion" `
        -Passed ((Test-TextContains -Text $crashLogText -Pattern "color=CameraColor") -and (Test-TextContains -Text $crashLogText -Pattern "depth=CameraDepthStencil") -and (Test-TextContains -Text $crashLogText -Pattern "motion=Motion Vectors")) `
        -Evidence "Archived crash log shows CameraColor, CameraDepthStencil, and Motion Vectors declarations." `
        -Failure "archived crash log does not show all color/depth/motion declarations"

    Add-Check `
        -Name "NoDiagnosticPassRenderFuncReachedBeforeCrash" `
        -Passed (-not (Test-TextContains -Text $crashLogText -Pattern "DLSS evaluate input probe RenderGraph diagnostic pass candidate") -and -not (Test-TextContains -Text $crashLogText -Pattern "RenderGraph diagnostic pass render #")) `
        -Evidence "Archived crash log has configured/injected lines but no diagnostic-pass render-function lines." `
        -Failure "archived crash log now contains diagnostic-pass render-function evidence; reassess the route"

    Add-Check `
        -Name "WerShowsCoreClrAccessViolation" `
        -Passed ((Test-TextContains -Text $werText -Pattern "NsAppName=VRising.exe") -and (Test-TextContains -Text $werText -Pattern "Sig[3].Value=coreclr.dll") -and (Test-TextContains -Text $werText -Pattern "Sig[6].Value=c0000005")) `
        -Evidence "WER records VRising.exe -> coreclr.dll -> c0000005." `
        -Failure "WER no longer proves the coreclr c0000005 crash"

    Add-Check `
        -Name "ModConfigKeepsHighRiskRoutesDefaultFalse" `
        -Passed (($modConfigText -match 'EnableRenderGraphDiagnosticPass\s*=\s*config\.Bind\("Diagnostics",\s*"EnableRenderGraphDiagnosticPass",\s*false') -and ($modConfigText -match 'EnableExistingRenderFuncProbe\s*=\s*config\.Bind\("Diagnostics",\s*"EnableExistingRenderFuncProbe",\s*false')) `
        -Evidence "ModConfig defaults EnableRenderGraphDiagnosticPass and EnableExistingRenderFuncProbe to false." `
        -Failure "high-risk RenderGraph route defaults changed"

    Add-Check `
        -Name "PackageValidatorRequiresHighRiskRoutesFalse" `
        -Passed ((Test-TextContains -Text $packageValidatorText -Pattern "EnableRenderGraphDiagnosticPass = false") -and (Test-TextContains -Text $packageValidatorText -Pattern "EnableExistingRenderFuncProbe = false")) `
        -Evidence "Thunderstore package validator requires both high-risk flags false." `
        -Failure "package validator no longer guards high-risk RenderGraph flags"

    $contractGuard = & $contractGuardPath -Root $resolvedRoot -RequirePass -Json | ConvertFrom-Json
    Add-Check `
        -Name "ContractBindGuardPassesWithoutLaunch" `
        -Passed (($contractGuard.Status -eq "Pass") -and (-not [bool]$contractGuard.LaunchesGame) -and (-not [bool]$contractGuard.ModifiesGameFiles)) `
        -Evidence "test-hdrp-dlss-contract-bind-stage reports Status=$($contractGuard.Status), LaunchesGame=$($contractGuard.LaunchesGame), ModifiesGameFiles=$($contractGuard.ModifiesGameFiles)." `
        -Failure "contract-bind guard did not pass or reported side effects"

    $analyzer = & $analyzerPath -LogPath $resolvedScheduleAuditLog -Json | ConvertFrom-Json
    Add-Check `
        -Name "ScheduleAnalyzerUsesEngineOwnedEasuChain" `
        -Passed (($analyzer.Status -eq "NoOfficialDlssPassObserved") -and ($analyzer.Contract.EngineOwnedChainObserved -eq $true) -and ($analyzer.Counts.CompleteUberEasuFinalChains -gt 0)) `
        -Evidence "Analyzer status=$($analyzer.Status), contract=$($analyzer.Contract.Status), completeChains=$($analyzer.Counts.CompleteUberEasuFinalChains)." `
        -Failure "schedule analyzer did not observe the expected engine-owned EASU chain"

    Add-Check `
        -Name "ScheduleAnalyzerRejectsOfficialEquivalentContractForMenuLog" `
        -Passed (($analyzer.Contract.Status -eq "EasuChainObservedButContractIncomplete") -and ($analyzer.Contract.OfficialContractObserved -eq $false) -and ($analyzer.Counts.RenderGraphGetTextureCalls -eq 0) -and ($analyzer.Counts.AccessViolationIndicators -eq 0)) `
        -Evidence "Analyzer contract=$($analyzer.Contract.Status), GetTexture=$($analyzer.Counts.RenderGraphGetTextureCalls), accessViolations=$($analyzer.Counts.AccessViolationIndicators)." `
        -Failure "menu log no longer has the expected incomplete-contract/no-pollution shape"
} catch {
    $status = "Blocked"
    [void]$issues.Add($_.Exception.Message)
}

if ($status -eq "Pass" -and $issues.Count -gt 0) {
    $status = "Fail"
}

$result = [pscustomobject]@{
    Status = $status
    LaunchesGame = $false
    ModifiesGameFiles = $false
    RouteDecision = "RejectedAsNormalRoute"
    Route = "mod-owned RenderGraph AddRenderPass/SetRenderFunc or broad generated render-func patching"
    RecommendedNextRoute = "Protected hdrp-dlss-contract-bind-render-scale proof on the engine-owned Uber->EASU->Final chain, then a bounded no-write cost proof if that binds HDRP depth/motion."
    CheckCount = $checks.Count
    FailedChecks = @($checks | Where-Object { $_.Status -ne "Pass" })
    Evidence = [pscustomobject]@{
        DiagnosticPassCrashLog = $resolvedDiagnosticPassCrashLog
        DiagnosticPassCrashWer = $resolvedDiagnosticPassCrashWer
        ScheduleAuditLog = $resolvedScheduleAuditLog
        ContractGuardStatus = if ($contractGuard) { $contractGuard.Status } else { $null }
        AnalyzerStatus = if ($analyzer) { $analyzer.Status } else { $null }
        AnalyzerContractStatus = if ($analyzer) { $analyzer.Contract.Status } else { $null }
        CompleteUberEasuFinalChains = if ($analyzer) { $analyzer.Counts.CompleteUberEasuFinalChains } else { $null }
    }
    Issues = @($issues)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}

if ($RequirePass -and $result.Status -ne "Pass") {
    exit 1
}
