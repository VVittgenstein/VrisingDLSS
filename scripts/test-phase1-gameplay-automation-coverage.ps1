param(
    [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$GamePath,
    [string]$SaveName = "11111",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[string]
$localEvidenceStatus = "NotApplicable"
$saveFixtureReport = $null
$contractBindReport = $null

function Add-Check {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Passed,

        [string]$Evidence = ""
    )

    [void]$checks.Add([pscustomobject]@{
            Name = $Name
            Passed = $Passed
            Evidence = $Evidence
        })

    if (-not $Passed) {
        [void]$issues.Add($Name)
    }
}

function Get-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Join-Path $resolvedRoot $RelativePath
}

function Test-TextPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $path = Get-RepoPath -RelativePath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Check -Name $Description -Passed $false -Evidence "Missing $path"
        return
    }

    $text = Get-Content -LiteralPath $path -Raw
    Add-Check -Name $Description -Passed ($text -match $Pattern) -Evidence $RelativePath
}

function Invoke-JsonScript {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    $output = & $Command
    if ([string]::IsNullOrWhiteSpace([string]$output)) {
        throw "Command produced no JSON output."
    }

    return $output | ConvertFrom-Json
}

$requiredDocs = @(
    "docs\development\gameplay-automation-exploration-2026-06-06.md",
    "docs\development\gameplay-automation-proof-protocol-2026-06-06.md",
    "docs\development\gameplay-continue-ui-navigation-protocol-2026-06-06.md",
    "docs\development\computer-use-vrising-automation-notes-2026-06-06.md",
    "docs\context\current-context.md"
)

foreach ($doc in $requiredDocs) {
    $path = Get-RepoPath -RelativePath $doc
    Add-Check -Name "required Phase 1 document exists: $doc" -Passed (Test-Path -LiteralPath $path -PathType Leaf) -Evidence $path
}

$requiredScripts = @(
    "scripts\run-vrising-automation-proof.ps1",
    "scripts\start-vrising-automation-session.ps1",
    "scripts\stop-vrising-automation-session.ps1",
    "scripts\find-vrising-save-fixture.ps1",
    "scripts\protect-vrising-save.ps1",
    "scripts\test-hdrp-dlss-contract-bind-stage.ps1"
)

foreach ($script in $requiredScripts) {
    $path = Get-RepoPath -RelativePath $script
    Add-Check -Name "required Phase 1 script exists: $script" -Passed (Test-Path -LiteralPath $path -PathType Leaf) -Evidence $path
}

Test-TextPattern `
    -RelativePath "docs\development\gameplay-automation-exploration-2026-06-06.md" `
    -Pattern "automatic gameplay entry is proven[\s\S]*11111|11111[\s\S]*automatic gameplay entry is proven" `
    -Description "exploration doc records automatic gameplay entry for the 11111 fixture"

Test-TextPattern `
    -RelativePath "docs\development\gameplay-automation-exploration-2026-06-06.md" `
    -Pattern "direct-entry[\s\S]*no supported client command-line auto-continue|no supported client command-line auto-continue[\s\S]*direct-entry|do not spend the next runtime loop on blind command-line guesses" `
    -Description "exploration doc records direct-entry command-line route as weak/rejected for now"

Test-TextPattern `
    -RelativePath "docs\development\gameplay-automation-proof-protocol-2026-06-06.md" `
    -Pattern "SetResolution 1920, 1080, fullScreenMode Windowed|WindowMode=3|ClientWindowMode 3" `
    -Description "proof protocol records true 1920x1080 Windowed control"

Test-TextPattern `
    -RelativePath "docs\development\gameplay-automation-proof-protocol-2026-06-06.md" `
    -Pattern "ProtectSave[\s\S]*SaveName 11111|SaveName 11111[\s\S]*ProtectSave" `
    -Description "proof protocol records protected SaveName 11111 session usage"

Test-TextPattern `
    -RelativePath "docs\development\gameplay-continue-ui-navigation-protocol-2026-06-06.md" `
    -Pattern "exactly one click[\s\S]*11111|11111[\s\S]*exactly one click" `
    -Description "continue protocol records one bounded Computer Use Continue action"

Test-TextPattern `
    -RelativePath "docs\development\gameplay-continue-ui-navigation-protocol-2026-06-06.md" `
    -Pattern "ChangeCount=0|ChangeCount = 0|ChangeCount`=0" `
    -Description "continue protocol records save restore ending at ChangeCount=0"

Test-TextPattern `
    -RelativePath "docs\development\computer-use-vrising-automation-notes-2026-06-06.md" `
    -Pattern "Computer Use has no relationship to the DLSS mod implementation|not part of the DLSS mod" `
    -Description "Computer Use note preserves the product boundary"

Test-TextPattern `
    -RelativePath "docs\development\computer-use-vrising-automation-notes-2026-06-06.md" `
    -Pattern "Windows computer-use client is closed[\s\S]*deferred|deferred[\s\S]*Windows computer-use client is closed" `
    -Description "Computer Use note records deferral instead of fallback input when unavailable"

Test-TextPattern `
    -RelativePath "docs\development\computer-use-vrising-automation-notes-2026-06-06.md" `
    -Pattern "Never send movement|no movement|movement keys" `
    -Description "Computer Use note records no-movement-key discipline for protected gameplay"

Test-TextPattern `
    -RelativePath "docs\context\current-context.md" `
    -Pattern "Phase 1 automatic gameplay entry is now proven[\s\S]*11111|11111[\s\S]*Phase 1 automatic gameplay entry is now proven" `
    -Description "durable context records Phase 1 route A for the 11111 fixture"

if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $vrisingExe = Join-Path $GamePath "VRising.exe"
    Add-Check -Name "local GamePath contains VRising.exe" -Passed (Test-Path -LiteralPath $vrisingExe -PathType Leaf) -Evidence $vrisingExe

    try {
        $saveFixtureReport = Invoke-JsonScript -Command {
            & (Get-RepoPath -RelativePath "scripts\find-vrising-save-fixture.ps1") -SaveName $SaveName -RequireOne -Json
        }

        Add-Check `
            -Name "save fixture resolver finds exactly one usable target" `
            -Passed ($saveFixtureReport.Status -eq "Pass" -and $saveFixtureReport.MatchCount -eq 1 -and -not [bool]$saveFixtureReport.LaunchesGame -and -not [bool]$saveFixtureReport.ModifiesGameFiles) `
            -Evidence "Status=$($saveFixtureReport.Status); SaveName=$($saveFixtureReport.SaveName); MatchCount=$($saveFixtureReport.MatchCount); LaunchesGame=$($saveFixtureReport.LaunchesGame); ModifiesGameFiles=$($saveFixtureReport.ModifiesGameFiles)"
    } catch {
        Add-Check -Name "save fixture resolver finds exactly one usable target" -Passed $false -Evidence $_.Exception.Message
    }

    try {
        $contractBindReport = Invoke-JsonScript -Command {
            & (Get-RepoPath -RelativePath "scripts\test-hdrp-dlss-contract-bind-stage.ps1") -Root $resolvedRoot -GamePath $GamePath -SaveName $SaveName -Json
        }

        $runtimeProofPlan = $contractBindReport.RuntimeProofPlan
        $sessionDryRun = $contractBindReport.SessionDryRun
        Add-Check `
            -Name "contract-bind stage dry-run is protected, no-native, and no-launch" `
            -Passed ($contractBindReport.Status -eq "Pass" -and -not [bool]$contractBindReport.LaunchesGame -and -not [bool]$contractBindReport.ModifiesGameFiles -and $null -ne $sessionDryRun -and -not [bool]$sessionDryRun.LaunchesGame -and [bool]$sessionDryRun.ProtectSave -and [bool]$sessionDryRun.RestoresProtectedSave -and -not [bool]$sessionDryRun.UseSdkWrapperNative -and [bool]$sessionDryRun.SaveFixtureResolved) `
            -Evidence "Status=$($contractBindReport.Status); SessionLaunchesGame=$($sessionDryRun.LaunchesGame); ProtectSave=$($sessionDryRun.ProtectSave); RestoresProtectedSave=$($sessionDryRun.RestoresProtectedSave); UseSdkWrapperNative=$($sessionDryRun.UseSdkWrapperNative); SaveFixtureResolved=$($sessionDryRun.SaveFixtureResolved)"

        Add-Check `
            -Name "next runtime proof plan requires Computer Use and disallows movement keys" `
            -Passed ($null -ne $runtimeProofPlan -and [bool]$runtimeProofPlan.RequiresComputerUse -and -not [bool]$runtimeProofPlan.MovementKeysAllowed -and [string]$runtimeProofPlan.StartCommand -match "ClientWindowMode 3" -and [string]$runtimeProofPlan.StartCommand -match "ProtectSave" -and [string]$runtimeProofPlan.StartCommand -match "SaveName") `
            -Evidence "RequiresComputerUse=$($runtimeProofPlan.RequiresComputerUse); MovementKeysAllowed=$($runtimeProofPlan.MovementKeysAllowed); StartCommand=$($runtimeProofPlan.StartCommand)"
    } catch {
        Add-Check -Name "contract-bind stage dry-run is protected, no-native, and no-launch" -Passed $false -Evidence $_.Exception.Message
    }

    $localEvidenceStatus = if (@($checks | Where-Object { -not $_.Passed }).Count -eq 0) { "Pass" } else { "Fail" }
}

$failedChecks = @($checks | Where-Object { -not $_.Passed })
$status = if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" }
$allChecksArray = [object[]]@($checks.ToArray())
$failedChecksArray = [object[]]@($failedChecks)
$issuesArray = [string[]]@($issues.ToArray())

$saveFixtureSummary = $null
if ($saveFixtureReport) {
    $saveFixtureSummary = [pscustomobject]@{
        Status = $saveFixtureReport.Status
        MatchCount = $saveFixtureReport.MatchCount
        SelectedSaveDir = $saveFixtureReport.SelectedSaveDir
        LaunchesGame = [bool]$saveFixtureReport.LaunchesGame
        ModifiesGameFiles = [bool]$saveFixtureReport.ModifiesGameFiles
    }
}

$contractBindSummary = $null
if ($contractBindReport) {
    $contractBindSummary = [pscustomobject]@{
        Status = $contractBindReport.Status
        Stage = $contractBindReport.Stage
        LaunchesGame = [bool]$contractBindReport.LaunchesGame
        ModifiesGameFiles = [bool]$contractBindReport.ModifiesGameFiles
        RequiresComputerUse = [bool]$contractBindReport.RuntimeProofPlan.RequiresComputerUse
        MovementKeysAllowed = [bool]$contractBindReport.RuntimeProofPlan.MovementKeysAllowed
    }
}

$result = New-Object psobject
$result | Add-Member -MemberType NoteProperty -Name "Status" -Value $status
$result | Add-Member -MemberType NoteProperty -Name "Phase1Status" -Value "AutomaticGameplayEntryProvenFor11111"
$result | Add-Member -MemberType NoteProperty -Name "LaunchesGame" -Value $false
$result | Add-Member -MemberType NoteProperty -Name "ModifiesGameFiles" -Value $false
$result | Add-Member -MemberType NoteProperty -Name "GamePath" -Value $GamePath
$result | Add-Member -MemberType NoteProperty -Name "SaveName" -Value $SaveName
$result | Add-Member -MemberType NoteProperty -Name "LocalEvidenceStatus" -Value $localEvidenceStatus
$result | Add-Member -MemberType NoteProperty -Name "CheckCount" -Value $checks.Count
$result | Add-Member -MemberType NoteProperty -Name "FailedChecks" -Value $failedChecksArray
$result | Add-Member -MemberType NoteProperty -Name "Checks" -Value $allChecksArray
$result | Add-Member -MemberType NoteProperty -Name "SaveFixture" -Value $saveFixtureSummary
$result | Add-Member -MemberType NoteProperty -Name "ContractBindStage" -Value $contractBindSummary
$result | Add-Member -MemberType NoteProperty -Name "Issues" -Value $issuesArray

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    $result
}

if ($status -ne "Pass") {
    exit 1
}
