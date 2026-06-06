param(
    [string]$GamePath = "",
    [string]$ProcessName = "VRising",
    [string]$WindowTitlePattern = "^V Rising$|VRising",
    [switch]$SearchGamePathProcesses,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class VrisingDlssVisibilityWindowInfo
{
    public IntPtr Handle { get; set; }
    public string Title { get; set; }
    public string ClassName { get; set; }
    public bool Visible { get; set; }
}

public static class VrisingDlssVisibilityNative
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    public static VrisingDlssVisibilityWindowInfo[] GetTopLevelWindowsForProcess(int processId)
    {
        List<VrisingDlssVisibilityWindowInfo> windows = new List<VrisingDlssVisibilityWindowInfo>();

        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            uint ownerProcessId;
            GetWindowThreadProcessId(hWnd, out ownerProcessId);
            if (ownerProcessId != (uint)processId)
            {
                return true;
            }

            int titleLength = GetWindowTextLength(hWnd);
            StringBuilder title = new StringBuilder(Math.Max(titleLength + 1, 256));
            GetWindowText(hWnd, title, title.Capacity);

            StringBuilder className = new StringBuilder(256);
            GetClassName(hWnd, className, className.Capacity);

            windows.Add(new VrisingDlssVisibilityWindowInfo
            {
                Handle = hWnd,
                Title = title.ToString(),
                ClassName = className.ToString(),
                Visible = IsWindowVisible(hWnd)
            });

            return true;
        }, IntPtr.Zero);

        return windows.ToArray();
    }
}
"@

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

    $windows = @()
    foreach ($window in [VrisingDlssVisibilityNative]::GetTopLevelWindowsForProcess($Process.Id)) {
        $handle = 0L
        try {
            $handle = $window.Handle.ToInt64()
        } catch {
        }

        $windowIsConsole = $window.ClassName -eq "ConsoleWindowClass" -or $window.Title -match "BepInEx|console"
        $windowTitleMatches = -not [string]::IsNullOrWhiteSpace($WindowTitlePattern) -and $window.Title -match $WindowTitlePattern
        $windowLooksLikeGame = [bool]$window.Visible -and -not $windowIsConsole -and (
            $window.ClassName -match "Unity" -or
            $windowTitleMatches -or
            $window.Title -match "^V Rising$|VRising"
        )

        if ($windowLooksLikeGame) {
            $looksLikeGameWindow = $true
        }

        $windows += [pscustomobject]@{
            Handle = ("0x{0:X}" -f $handle)
            Title = [string]$window.Title
            ClassName = [string]$window.ClassName
            Visible = [bool]$window.Visible
            IsConsoleLikeWindow = $windowIsConsole
            MatchesTitlePattern = $windowTitleMatches
            LooksLikeGameWindow = $windowLooksLikeGame
        }
    }

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
        TopLevelWindows = @($windows)
    }
}

$processInfos = @()
foreach ($process in @(Get-CandidateProcesses)) {
    $processInfos += Convert-ProcessInfo -Process $process
}

$selected = $processInfos |
    Where-Object { $_.LooksLikeGameWindow } |
    Select-Object -First 1

$selectedWindow = $null
if ($selected) {
    $selectedWindow = @($selected.TopLevelWindows | Where-Object { $_.LooksLikeGameWindow } | Select-Object -First 1)
    if ($selectedWindow.Count -gt 0) {
        $selectedWindow = $selectedWindow[0]
    } else {
        $selectedWindow = $null
    }
}

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
    SelectedWindow = $(if ($selectedWindow) { $selectedWindow } else { $null })
    Issues = $issues.ToArray()
    LaunchesGame = $false
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result
}
