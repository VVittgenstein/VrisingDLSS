param(
    [string]$OutputPath,
    [string]$ArtifactLabel,
    [string]$Root,
    [string]$ProcessName = "VRising",
    [ValidateSet("Auto", "PrintWindow", "ScreenCopy")]
    [string]$Method = "Auto",
    [string]$WindowTitlePattern,
    [switch]$AllowConsoleWindow,
    [switch]$KeepConsoleWindows,
    [int]$WaitSeconds = 0,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($WaitSeconds -lt 0) {
    throw "WaitSeconds cannot be negative."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$artifactRoot = Join-Path $resolvedRoot "artifacts\visual-validation"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "vrising-window-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot "$ArtifactLabel.png"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $resolvedRoot $OutputPath
}

$targetPath = [System.IO.Path]::GetFullPath($OutputPath)

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "Capture" })
    ProcessName = $ProcessName
    Method = $Method
    WindowTitlePattern = $WindowTitlePattern
    AllowConsoleWindow = [bool]$AllowConsoleWindow
    KeepConsoleWindows = [bool]$KeepConsoleWindows
    WaitSeconds = $WaitSeconds
    OutputPath = $targetPath
    LaunchesGame = $false
}

if ($DryRun) {
    $plan
    return
}

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class VrisingDlssWindowInfo
{
    public IntPtr Handle { get; set; }
    public string Title { get; set; }
    public string ClassName { get; set; }
    public int Left { get; set; }
    public int Top { get; set; }
    public int Right { get; set; }
    public int Bottom { get; set; }
    public bool Visible { get; set; }
}

public static class VrisingDlssWindowCaptureNative
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiAwarenessContext);

    [DllImport("shcore.dll", SetLastError = true)]
    public static extern int SetProcessDpiAwareness(int value);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetProcessDPIAware();

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

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

    public static string TryEnableProcessDpiAwareness()
    {
        try
        {
            if (SetProcessDpiAwarenessContext(new IntPtr(-4)))
            {
                return "PerMonitorV2";
            }
        }
        catch
        {
        }

        try
        {
            int result = SetProcessDpiAwareness(2);
            if (result == 0)
            {
                return "PerMonitor";
            }

            if (result == unchecked((int)0x80070005))
            {
                return "AlreadySet";
            }
        }
        catch
        {
        }

        try
        {
            if (SetProcessDPIAware())
            {
                return "System";
            }
        }
        catch
        {
        }

        return "Unchanged";
    }

    public static VrisingDlssWindowInfo[] GetTopLevelWindowsForProcess(int processId)
    {
        List<VrisingDlssWindowInfo> windows = new List<VrisingDlssWindowInfo>();

        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            uint ownerProcessId;
            GetWindowThreadProcessId(hWnd, out ownerProcessId);
            if (ownerProcessId != (uint)processId)
            {
                return true;
            }

            RECT rect;
            GetWindowRect(hWnd, out rect);

            int titleLength = GetWindowTextLength(hWnd);
            StringBuilder title = new StringBuilder(Math.Max(titleLength + 1, 256));
            GetWindowText(hWnd, title, title.Capacity);

            StringBuilder className = new StringBuilder(256);
            GetClassName(hWnd, className, className.Capacity);

            windows.Add(new VrisingDlssWindowInfo
            {
                Handle = hWnd,
                Title = title.ToString(),
                ClassName = className.ToString(),
                Left = rect.Left,
                Top = rect.Top,
                Right = rect.Right,
                Bottom = rect.Bottom,
                Visible = IsWindowVisible(hWnd)
            });

            return true;
        }, IntPtr.Zero);

        return windows.ToArray();
    }
}
"@

$dpiAwareness = [VrisingDlssWindowCaptureNative]::TryEnableProcessDpiAwareness()

function Get-TargetProcess {
    param([string]$Name)

    Get-Process -Name $Name -ErrorAction SilentlyContinue |
        Sort-Object StartTime -Descending |
        Select-Object
}

function Get-ClientBounds {
    param(
        [IntPtr]$Handle,
        [string]$Label
    )

    $rect = New-Object VrisingDlssWindowCaptureNative+RECT
    if (-not [VrisingDlssWindowCaptureNative]::GetClientRect($Handle, [ref]$rect)) {
        throw "GetClientRect failed for $Label."
    }

    $origin = New-Object VrisingDlssWindowCaptureNative+POINT
    $origin.X = $rect.Left
    $origin.Y = $rect.Top
    if (-not [VrisingDlssWindowCaptureNative]::ClientToScreen($Handle, [ref]$origin)) {
        throw "ClientToScreen failed for $Label."
    }

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) {
        throw "Target window has invalid client bounds for ${Label}: ${width}x${height}."
    }

    [pscustomobject]@{
        X = $origin.X
        Y = $origin.Y
        Width = $width
        Height = $height
    }
}

function Get-ProcessWindows {
    param([System.Diagnostics.Process]$Process)

    $windows = @()
    foreach ($window in [VrisingDlssWindowCaptureNative]::GetTopLevelWindowsForProcess($Process.Id)) {
        if (-not $window.Visible) {
            continue
        }

        $label = "pid=$($Process.Id) hwnd=0x$($window.Handle.ToInt64().ToString('X'))"
        try {
            $bounds = Get-ClientBounds -Handle $window.Handle -Label $label
        } catch {
            continue
        }

        $area = $bounds.Width * $bounds.Height
        if ($area -le 0) {
            continue
        }

        $isConsoleCandidate = (
            $window.ClassName -eq "ConsoleWindowClass" -or
            $window.Title -match "BepInEx"
        )
        $isUnityCandidate = (
            $window.ClassName -match "Unity" -or
            $window.Title -match "^V Rising$|VRising"
        )
        $score = [double]$area
        if ($isUnityCandidate) {
            $score += 1000000000000
        }
        if ($isConsoleCandidate) {
            $score -= 1000000000000
        }

        $windows += [pscustomobject]@{
            Process = $Process
            Handle = $window.Handle
            WindowTitle = $window.Title
            WindowClass = $window.ClassName
            Bounds = $bounds
            Area = $area
            IsConsoleCandidate = $isConsoleCandidate
            IsUnityCandidate = $isUnityCandidate
            Score = $score
        }
    }

    $windows
}

function Select-TargetWindow {
    param(
        [array]$Windows,
        [string]$TitlePattern,
        [bool]$AllowConsole
    )

    $filtered = @($Windows)
    if (-not $AllowConsole) {
        $filtered = @($filtered | Where-Object { -not $_.IsConsoleCandidate })
    }

    if (-not [string]::IsNullOrWhiteSpace($TitlePattern)) {
        $byTitle = @($filtered | Where-Object { $_.WindowTitle -match $TitlePattern })
        if ($byTitle.Count -gt 0) {
            $filtered = $byTitle
        }
    }

    $selected = $filtered |
        Sort-Object @{ Expression = "Score"; Descending = $true }, @{ Expression = "Area"; Descending = $true } |
        Select-Object -First 1

    if (-not $selected) {
        $selected = $Windows |
            Sort-Object @{ Expression = "Area"; Descending = $true } |
            Select-Object -First 1
    }

    $selected
}

function Set-WindowReadyForCapture {
    param(
        [pscustomobject]$Target,
        [bool]$KeepConsole
    )

    $minimizedConsoleCount = 0
    if (-not $KeepConsole) {
        foreach ($window in @(Get-ProcessWindows -Process $Target.Process)) {
            if ($window.Handle -eq $Target.Handle) {
                continue
            }
            if ($window.IsConsoleCandidate) {
                $swMinimize = 6
                [void][VrisingDlssWindowCaptureNative]::ShowWindow($window.Handle, $swMinimize)
                $minimizedConsoleCount++
            }
        }
    }

    $swRestore = 9
    $swpNoSize = 0x0001
    $swpNoMove = 0x0002
    $swpShowWindow = 0x0040
    $flags = $swpNoSize -bor $swpNoMove -bor $swpShowWindow
    $hwndTopMost = [IntPtr]::new(-1)
    $hwndNoTopMost = [IntPtr]::new(-2)

    [void][VrisingDlssWindowCaptureNative]::ShowWindow($Target.Handle, $swRestore)
    [void][VrisingDlssWindowCaptureNative]::SetWindowPos($Target.Handle, $hwndTopMost, 0, 0, 0, 0, $flags)
    [void][VrisingDlssWindowCaptureNative]::SetForegroundWindow($Target.Handle)
    Start-Sleep -Milliseconds 200
    [void][VrisingDlssWindowCaptureNative]::SetWindowPos($Target.Handle, $hwndNoTopMost, 0, 0, 0, 0, $flags)
    [void][VrisingDlssWindowCaptureNative]::SetForegroundWindow($Target.Handle)

    return $minimizedConsoleCount
}

function Wait-ForTargetWindow {
    param(
        [string]$Name,
        [int]$Seconds,
        [string]$TitlePattern,
        [bool]$AllowConsole
    )

    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        foreach ($candidateProcess in Get-TargetProcess -Name $Name) {
            $windows = @(Get-ProcessWindows -Process $candidateProcess)
            if ($windows.Count -eq 0) {
                continue
            }

            $selected = Select-TargetWindow -Windows $windows -TitlePattern $TitlePattern -AllowConsole $AllowConsole
            if ($selected) {
                $selected | Add-Member -NotePropertyName CandidateWindowCount -NotePropertyValue $windows.Count -Force
                return $selected
            }
        }

        if ($Seconds -le 0) {
            break
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    return $null
}

function New-PrintWindowBitmap {
    param(
        [IntPtr]$Handle,
        [int]$Width,
        [int]$Height
    )

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $hdc = [IntPtr]::Zero

    try {
        $hdc = $graphics.GetHdc()
        $pwClientOnly = 1
        $ok = [VrisingDlssWindowCaptureNative]::PrintWindow($Handle, $hdc, $pwClientOnly)
    } finally {
        if ($hdc -ne [IntPtr]::Zero) {
            $graphics.ReleaseHdc($hdc)
        }
        $graphics.Dispose()
    }

    if (-not $ok) {
        $bitmap.Dispose()
        return $null
    }

    return $bitmap
}

function New-ScreenCopyBitmap {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.CopyFromScreen($X, $Y, 0, 0, $bitmap.Size)
    } finally {
        $graphics.Dispose()
    }

    return $bitmap
}

function Get-BitmapStats {
    param([System.Drawing.Bitmap]$Bitmap)

    $maxSamples = 200000
    $pixelCount = [double]($Bitmap.Width * $Bitmap.Height)
    $step = [Math]::Max(1, [int][Math]::Ceiling([Math]::Sqrt($pixelCount / $maxSamples)))
    $samples = 0
    $nearBlack = 0
    $nearWhite = 0
    $sumLuma = 0.0
    $sumR = 0.0
    $sumG = 0.0
    $sumB = 0.0

    for ($y = 0; $y -lt $Bitmap.Height; $y += $step) {
        for ($x = 0; $x -lt $Bitmap.Width; $x += $step) {
            $color = $Bitmap.GetPixel($x, $y)
            $luma = (0.2126 * $color.R) + (0.7152 * $color.G) + (0.0722 * $color.B)
            $sumLuma += $luma
            $sumR += $color.R
            $sumG += $color.G
            $sumB += $color.B
            if ($color.R -lt 8 -and $color.G -lt 8 -and $color.B -lt 8) {
                $nearBlack++
            }
            if ($color.R -gt 247 -and $color.G -gt 247 -and $color.B -gt 247) {
                $nearWhite++
            }
            $samples++
        }
    }

    [pscustomobject]@{
        Samples = $samples
        AverageR = [Math]::Round($sumR / $samples, 3)
        AverageG = [Math]::Round($sumG / $samples, 3)
        AverageB = [Math]::Round($sumB / $samples, 3)
        AverageLuma = [Math]::Round($sumLuma / $samples, 3)
        NearBlackRatio = [Math]::Round($nearBlack / $samples, 6)
        NearWhiteRatio = [Math]::Round($nearWhite / $samples, 6)
    }
}

$target = Wait-ForTargetWindow -Name $ProcessName -Seconds $WaitSeconds -TitlePattern $WindowTitlePattern -AllowConsole ([bool]$AllowConsoleWindow)
if (-not $target) {
    throw "No visible $ProcessName window was found."
}

$process = $target.Process
$bounds = $target.Bounds
$minimizedConsoleCount = Set-WindowReadyForCapture -Target $target -KeepConsole ([bool]$KeepConsoleWindows)
Start-Sleep -Milliseconds 250

$selectedMethod = $Method
$fallbackReason = ""
$bitmap = $null

if ($Method -eq "Auto" -or $Method -eq "PrintWindow") {
    $bitmap = New-PrintWindowBitmap -Handle $target.Handle -Width $bounds.Width -Height $bounds.Height
    if ($bitmap) {
        $stats = Get-BitmapStats -Bitmap $bitmap
        if ($Method -eq "Auto" -and $stats.AverageLuma -lt 4 -and $stats.NearBlackRatio -gt 0.985) {
            $fallbackReason = "PrintWindow returned a near-black image."
            $bitmap.Dispose()
            $bitmap = $null
        } elseif ($Method -eq "Auto" -and $stats.AverageLuma -gt 252 -and $stats.NearWhiteRatio -gt 0.985) {
            $fallbackReason = "PrintWindow returned a near-white image."
            $bitmap.Dispose()
            $bitmap = $null
        } elseif ($Method -eq "Auto" -and ($stats.NearBlackRatio + $stats.NearWhiteRatio) -gt 0.985) {
            $fallbackReason = "PrintWindow returned a near-binary black/white image."
            $bitmap.Dispose()
            $bitmap = $null
        } else {
            $selectedMethod = "PrintWindow"
        }
    } elseif ($Method -eq "PrintWindow") {
        throw "PrintWindow capture failed."
    } else {
        $fallbackReason = "PrintWindow failed."
    }
}

if (-not $bitmap) {
    $bitmap = New-ScreenCopyBitmap -X $bounds.X -Y $bounds.Y -Width $bounds.Width -Height $bounds.Height
    $selectedMethod = "ScreenCopy"
    $stats = Get-BitmapStats -Bitmap $bitmap
}

try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
    $bitmap.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $bitmap.Dispose()
}

$hash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash

[pscustomobject]@{
    Mode = "Captured"
    Path = $targetPath
    Method = $selectedMethod
    FallbackReason = $fallbackReason
    DpiAwareness = $dpiAwareness
    ProcessId = $process.Id
    WindowHandle = ("0x{0:X}" -f $target.Handle.ToInt64())
    WindowTitle = $target.WindowTitle
    WindowClass = $target.WindowClass
    CandidateWindowCount = $target.CandidateWindowCount
    MinimizedConsoleWindowCount = $minimizedConsoleCount
    Width = $bounds.Width
    Height = $bounds.Height
    Samples = $stats.Samples
    AverageR = $stats.AverageR
    AverageG = $stats.AverageG
    AverageB = $stats.AverageB
    AverageLuma = $stats.AverageLuma
    NearBlackRatio = $stats.NearBlackRatio
    NearWhiteRatio = $stats.NearWhiteRatio
    Sha256 = $hash
    LaunchesGame = $false
}
