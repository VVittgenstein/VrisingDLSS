param(
    [string]$Root,
    [string]$SourcePath = "docs\chatlog\chat-log-codex-2026-06-04-c2222419.md",
    [string]$ReconstructionPath = "docs\context\chatlog-2026-06-04-reconstruction.md",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path "$PSScriptRoot\..").Path
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $resolvedRoot $Path
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

$sourceFile = Resolve-RepoPath -Path $SourcePath
$reconstructionFile = Resolve-RepoPath -Path $ReconstructionPath
$checks = New-Object System.Collections.Generic.List[object]

$sourceExists = Test-Path -LiteralPath $sourceFile -PathType Leaf
$reconstructionExists = Test-Path -LiteralPath $reconstructionFile -PathType Leaf
Add-Check -Checks $checks -Name "source chatlog exists" -Passed $sourceExists -Evidence $sourceFile
Add-Check -Checks $checks -Name "reconstruction document exists" -Passed $reconstructionExists -Evidence $reconstructionFile

$sourceMessages = @()
$chunks = @()

if ($sourceExists) {
    $sourceMessages = @(Select-String -LiteralPath $sourceFile -Pattern '^###\s+(?<Index>[0-9]+)\.\s+(?<Role>.+?)\s+-\s+(?<Timestamp>.+?)$' | ForEach-Object {
            [pscustomobject]@{
                Index = [int]$_.Matches[0].Groups["Index"].Value
                Role = $_.Matches[0].Groups["Role"].Value.Trim()
                Timestamp = $_.Matches[0].Groups["Timestamp"].Value.Trim()
                LineNumber = $_.LineNumber
            }
        })
}

$sourceMax = if ($sourceMessages.Count -gt 0) { ($sourceMessages | Measure-Object -Property Index -Maximum).Maximum } else { 0 }
$sourceMin = if ($sourceMessages.Count -gt 0) { ($sourceMessages | Measure-Object -Property Index -Minimum).Minimum } else { 0 }
Add-Check -Checks $checks `
    -Name "source chatlog has numbered messages" `
    -Passed ($sourceMessages.Count -gt 0 -and $sourceMin -eq 1 -and $sourceMax -eq $sourceMessages.Count) `
    -Evidence "Count=$($sourceMessages.Count); Min=$sourceMin; Max=$sourceMax"

if ($reconstructionExists) {
    $lines = @(Get-Content -LiteralPath $reconstructionFile)
    $chunkStarts = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^## Chunk\s+(?<Chunk>[0-9]+)\b') {
            [void]$chunkStarts.Add($i)
        }
    }

    for ($chunkIndex = 0; $chunkIndex -lt $chunkStarts.Count; $chunkIndex++) {
        $startLine = $chunkStarts[$chunkIndex]
        $endLine = if ($chunkIndex + 1 -lt $chunkStarts.Count) { $chunkStarts[$chunkIndex + 1] - 1 } else { $lines.Count - 1 }
        $sectionLines = @($lines[$startLine..$endLine])
        $header = $sectionLines[0]
        $rangeLine = @($sectionLines | Where-Object { $_ -match '^Message/time range:' } | Select-Object -First 1)
        $chunkNumber = if ($header -match '^## Chunk\s+(?<Chunk>[0-9]+)\b') { [int]$Matches.Chunk } else { 0 }
        $messageStart = 0
        $messageEnd = 0
        $timeRange = ""
        if ($rangeLine.Count -gt 0 -and $rangeLine[0] -match '^Message/time range:\s+`(?<Start>[0-9]+)-(?<End>[0-9]+)`,\s+(?<Time>.+?)\.$') {
            $messageStart = [int]$Matches.Start
            $messageEnd = [int]$Matches.End
            $timeRange = $Matches.Time
        }

        $chunks += [pscustomobject]@{
            Chunk = $chunkNumber
            Header = $header
            MessageStart = $messageStart
            MessageEnd = $messageEnd
            TimeRange = $timeRange
            Lines = $sectionLines
        }
    }
}

$requiredChunkLabels = @(
    "Message/time range:",
    "User instructions/follow-up/corrections:",
    "Technical decisions:",
    "Implemented changes:",
    "Evidence:",
    "Failures/rejected routes:",
    "Open blockers:",
    "Next step:"
)

$missingLabelReports = New-Object System.Collections.Generic.List[string]
foreach ($chunk in $chunks) {
    foreach ($label in $requiredChunkLabels) {
        if (-not @($chunk.Lines | Where-Object { $_ -eq $label }).Count -and $label -ne "Message/time range:") {
            [void]$missingLabelReports.Add("Chunk $($chunk.Chunk) missing $label")
        } elseif ($label -eq "Message/time range:" -and -not @($chunk.Lines | Where-Object { $_ -match '^Message/time range:' }).Count) {
            [void]$missingLabelReports.Add("Chunk $($chunk.Chunk) missing $label")
        }
    }
}

Add-Check -Checks $checks `
    -Name "reconstruction has required chunk labels" `
    -Passed ($chunks.Count -gt 0 -and $missingLabelReports.Count -eq 0) `
    -Evidence "ChunkCount=$($chunks.Count); Missing=$($missingLabelReports -join ' | ')"

$rangeIssues = New-Object System.Collections.Generic.List[string]
if ($chunks.Count -gt 0) {
    for ($i = 0; $i -lt $chunks.Count; $i++) {
        $expectedChunk = $i + 1
        if ($chunks[$i].Chunk -ne $expectedChunk) {
            [void]$rangeIssues.Add("Expected chunk $expectedChunk but found $($chunks[$i].Chunk)")
        }
        if ($chunks[$i].MessageStart -le 0 -or $chunks[$i].MessageEnd -lt $chunks[$i].MessageStart) {
            [void]$rangeIssues.Add("Chunk $($chunks[$i].Chunk) has invalid range $($chunks[$i].MessageStart)-$($chunks[$i].MessageEnd)")
        }
        if ($i -eq 0 -and $chunks[$i].MessageStart -ne 1) {
            [void]$rangeIssues.Add("First chunk starts at $($chunks[$i].MessageStart), expected 1")
        }
        if ($i -gt 0) {
            $expectedStart = $chunks[$i - 1].MessageEnd + 1
            if ($chunks[$i].MessageStart -ne $expectedStart) {
                [void]$rangeIssues.Add("Chunk $($chunks[$i].Chunk) starts at $($chunks[$i].MessageStart), expected $expectedStart")
            }
        }
    }
    if ($sourceMax -gt 0 -and $chunks[-1].MessageEnd -ne $sourceMax) {
        [void]$rangeIssues.Add("Last chunk ends at $($chunks[-1].MessageEnd), source max is $sourceMax")
    }
}

Add-Check -Checks $checks `
    -Name "reconstruction chunk ranges cover source messages contiguously" `
    -Passed ($chunks.Count -gt 0 -and $rangeIssues.Count -eq 0) `
    -Evidence "ChunkCount=$($chunks.Count); SourceMax=$sourceMax; First=$($chunks[0].MessageStart); Last=$($chunks[-1].MessageEnd); Issues=$($rangeIssues -join ' | ')"

$failedChecks = @($checks.ToArray() | Where-Object { -not $_.Passed })
$roleCounts = @{}
foreach ($group in @($sourceMessages | Group-Object Role)) {
    $roleCounts[$group.Name] = $group.Count
}

$result = [pscustomobject]@{
    Status = $(if ($failedChecks.Count -eq 0) { "Pass" } else { "Fail" })
    LaunchesGame = $false
    ModifiesGameFiles = $false
    SourcePath = $sourceFile
    ReconstructionPath = $reconstructionFile
    SourceMessageCount = $sourceMessages.Count
    SourceFirstMessage = $sourceMin
    SourceLastMessage = $sourceMax
    RoleCounts = [pscustomobject]$roleCounts
    ChunkCount = $chunks.Count
    ChunkRanges = @($chunks | Select-Object Chunk, MessageStart, MessageEnd, TimeRange)
    CheckCount = $checks.Count
    FailedChecks = $failedChecks
    Checks = @($checks.ToArray())
}

if ($Json) {
    $result | ConvertTo-Json -Depth 7
} else {
    $result
}

if ($failedChecks.Count -gt 0) {
    exit 1
}
