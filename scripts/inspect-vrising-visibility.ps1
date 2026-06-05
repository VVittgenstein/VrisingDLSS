param(
    [string]$GamePath = "",
    [string]$ProcessName = "VRising",
    [string]$WindowTitlePattern = "^V Rising$|VRising",
    [switch]$SearchGamePathProcesses,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedGamePath = ""
$expectedExePath = ""
if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
    $expectedExePath = Join-Path $resolvedGamePath "VRising.exe"
}

function Get-CandidateProcesses {
    $ids = New-Object System.Collections.Generic.HashSet[int]
    $processes = @()

    foreach ($process in @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)) {
        if ($ids.Add([int]$process.Id)) {
            $processes += $process
        }
    }

    if ($SearchGamePathProcesses -and -not [string]::IsNullOrWhiteSpace($resolvedGamePath)) {
        $cimNames = @($ProcessName, "$ProcessName.exe") |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
        foreach ($name in $cimNames) {
            $escapedName = $name.Replace("'", "''")
            foreach ($cim in @(Get-CimInstance Win32_Process -Filter "Name = '$escapedName'" -ErrorAction SilentlyContinue | Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and
                        $_.ExecutablePath.StartsWith($resolvedGamePath, [StringComparison]::OrdinalIgnoreCase)
                    })) {
                $process = Get-Process -Id $cim.ProcessId -ErrorAction SilentlyContinue
                if ($process -and $ids.Add([int]$process.Id)) {
                    $processes += $process
                }
            }
        }
    }

    $processes |
        Sort-Object StartTime -Descending -ErrorAction SilentlyContinue
}

function Convert-ProcessInfo {
    param([System.Diagnostics.Process]$Process)

    $path = ""
    try {
        $path = [string]$Process.Path
    } catch {
    }

    $startTime = ""
    try {
        $startTime = $Process.StartTime.ToString("o")
    } catch {
    }

    $responding = $false
    try {
        $responding = [bool]$Process.Responding
    } catch {
    }

    $mainWindowHandle = 0L
    try {
        $mainWindowHandle = $Process.MainWindowHandle.ToInt64()
    } catch {
    }

    $mainWindowTitle = ""
    try {
        $mainWindowTitle = [string]$Process.MainWindowTitle
    } catch {
    }

    $hasMainWindow = $mainWindowHandle -ne 0
    $isConsoleLike = $mainWindowTitle -match "BepInEx|console"
    $titleMatches = -not [string]::IsNullOrWhiteSpace($WindowTitlePattern) -and $mainWindowTitle -match $WindowTitlePattern
    $looksLikeGameWindow = $hasMainWindow -and -not $isConsoleLike -and ($titleMatches -or -not [string]::IsNullOrWhiteSpace($mainWindowTitle))

    [pscustomobject]@{
        Id = $Process.Id
        ProcessName = $Process.ProcessName
        Path = $path
        StartTime = $startTime
        MainWindowHandle = ("0x{0:X}" -f $mainWindowHandle)
        MainWindowTitle = $mainWindowTitle
        Responding = $responding
        HasMainWindow = $hasMainWindow
        IsConsoleLikeWindow = $isConsoleLike
        MatchesTitlePattern = $titleMatches
        LooksLikeGameWindow = $looksLikeGameWindow
    }
}

$processInfos = @()
foreach ($process in @(Get-CandidateProcesses)) {
    $processInfos += Convert-ProcessInfo -Process $process
}

$selected = $processInfos |
    Where-Object { $_.LooksLikeGameWindow } |
    Select-Object -First 1

$issues = New-Object System.Collections.Generic.List[string]
$status = "Missing"
if ($selected) {
    $status = "VisibleGameWindow"
} elseif ($processInfos.Count -gt 0) {
    $status = "ProcessOnly"
    $issues.Add("VRising process exists, but its main window does not look like the game window.")
    if (@($processInfos | Where-Object { $_.IsConsoleLikeWindow }).Count -gt 0) {
        $issues.Add("The visible main window appears to be console/BepInEx-like.")
    }
} else {
    $issues.Add("No VRising process was found.")
}

$result = [pscustomobject]@{
    Status = $status
    GamePath = $resolvedGamePath
    ExpectedExePath = $expectedExePath
    ProcessName = $ProcessName
    WindowTitlePattern = $WindowTitlePattern
    SearchGamePathProcesses = [bool]$SearchGamePathProcesses
    ProcessCount = $processInfos.Count
    Processes = @($processInfos)
    SelectedProcess = $(if ($selected) { $selected } else { $null })
    Issues = $issues.ToArray()
    LaunchesGame = $false
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}
