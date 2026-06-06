param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root,
    [string]$ArtifactLabel,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$WaitForWindowSeconds = 90,
    [int]$WaitForNonBlankScreenshotSeconds = 60,
    [int]$ScreenshotRetrySeconds = 3,
    [int]$ObservationSeconds = 10,
    [ValidateSet("Auto", "PrintWindow", "ScreenCopy")]
    [string]$ScreenshotMethod = "Auto",
    [switch]$SendHarmlessInput,
    [ValidateSet("Escape", "Enter", "Space")]
    [string]$HarmlessInputKey = "Escape",
    [int]$PostInputWaitSeconds = 3,
    [switch]$SetClientResolution,
    [switch]$SkipInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($Width -lt 640 -or $Height -lt 480) {
    throw "Width/Height are too small for a useful V Rising automation proof."
}

if ($WaitForWindowSeconds -lt 5) {
    throw "WaitForWindowSeconds must be at least 5."
}

if ($ObservationSeconds -lt 0) {
    throw "ObservationSeconds cannot be negative."
}

if ($WaitForNonBlankScreenshotSeconds -lt 0) {
    throw "WaitForNonBlankScreenshotSeconds cannot be negative."
}

if ($ScreenshotRetrySeconds -lt 1) {
    throw "ScreenshotRetrySeconds must be at least 1."
}

if ($PostInputWaitSeconds -lt 0) {
    throw "PostInputWaitSeconds cannot be negative."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
$exePath = Join-Path $resolvedGamePath "VRising.exe"
$logPath = Join-Path $resolvedGamePath "BepInEx\LogOutput.log"
$artifactRoot = Join-Path $resolvedRoot "artifacts\gameplay-automation"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "automation-proof-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "VRising.exe was not found: $exePath"
}

function Get-VRisingProcess {
    Get-Process VRising -ErrorAction SilentlyContinue
}

function Close-VRisingProcess {
    param([System.Diagnostics.Process]$Process)

    $closed = $false
    if (-not $Process) {
        return $closed
    }

    $live = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
    if (-not $live) {
        return $closed
    }

    try {
        [void]$live.CloseMainWindow()
    } catch {
        Write-Warning "CloseMainWindow failed: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 8
    $live = Get-Process -Id $Process.Id -ErrorAction SilentlyContinue
    if ($live) {
        Stop-Process -Id $live.Id -Force
        Start-Sleep -Seconds 2
    }

    return $true
}

function Get-PlayerLogResolutionInfo {
    param([string]$Path)

    $info = [ordered]@{
        Width = $null
        Height = $null
        FullScreenMode = ""
        SetResolutionLine = ""
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]$info
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match "SetResolution\s+(\d+),\s*(\d+),\s*fullScreenMode\s+(\S+)") {
            $info.Width = [int]$Matches[1]
            $info.Height = [int]$Matches[2]
            $info.FullScreenMode = [string]$Matches[3]
            $info.SetResolutionLine = [string]$line
        }
    }

    [pscustomobject]$info
}

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class VrisingDlssInputProofNative
{
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint type;
        public InputUnion u;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion
    {
        [FieldOffset(0)]
        public MOUSEINPUT mi;

        [FieldOffset(0)]
        public KEYBDINPUT ki;

        [FieldOffset(0)]
        public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    public static int GetLastWin32Error()
    {
        return Marshal.GetLastWin32Error();
    }

    public static int GetInputStructSize()
    {
        return Marshal.SizeOf(typeof(INPUT));
    }

    public static uint SendVirtualKey(ushort virtualKey)
    {
        const uint INPUT_KEYBOARD = 1;
        const uint KEYEVENTF_KEYUP = 0x0002;

        INPUT[] inputs = new INPUT[2];
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].u.ki.wVk = virtualKey;
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].u.ki.wVk = virtualKey;
        inputs[1].u.ki.dwFlags = KEYEVENTF_KEYUP;

        return SendInput((uint)inputs.Length, inputs, GetInputStructSize());
    }
}
"@

function Convert-HexHandleToIntPtr {
    param([string]$Handle)

    if ([string]::IsNullOrWhiteSpace($Handle)) {
        return [IntPtr]::Zero
    }

    $normalized = $Handle.Trim()
    if ($normalized.StartsWith("0x", [StringComparison]::OrdinalIgnoreCase)) {
        $normalized = $normalized.Substring(2)
    }

    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return [IntPtr]::Zero
    }

    [IntPtr]::new([Convert]::ToInt64($normalized, 16))
}

function Get-HarmlessInputVirtualKey {
    param([string]$Key)

    switch ($Key) {
        "Escape" { return 0x1B }
        "Enter" { return 0x0D }
        "Space" { return 0x20 }
        default { throw "Unsupported harmless input key: $Key" }
    }
}

function Send-HarmlessInputToWindow {
    param(
        [string]$Handle,
        [string]$Key
    )

    $windowHandle = Convert-HexHandleToIntPtr -Handle $Handle
    if ($windowHandle -eq [IntPtr]::Zero) {
        throw "SelectedWindow handle was not available for harmless input proof."
    }

    $swRestore = 9
    [void][VrisingDlssInputProofNative]::ShowWindow($windowHandle, $swRestore)
    $foregrounded = [VrisingDlssInputProofNative]::SetForegroundWindow($windowHandle)
    Start-Sleep -Milliseconds 300

    $virtualKey = [UInt16](Get-HarmlessInputVirtualKey -Key $Key)
    $sentCount = [VrisingDlssInputProofNative]::SendVirtualKey($virtualKey)
    $lastError = $(if ($sentCount -eq 2) { 0 } else { [VrisingDlssInputProofNative]::GetLastWin32Error() })

    [pscustomobject]@{
        WindowHandle = ("0x{0:X}" -f $windowHandle.ToInt64())
        Key = $Key
        VirtualKey = ("0x{0:X2}" -f $virtualKey)
        Foregrounded = $foregrounded
        InputStructSize = [VrisingDlssInputProofNative]::GetInputStructSize()
        SendInputCount = [int]$sentCount
        SendInputLastWin32Error = [int]$lastError
        SendInputSucceeded = $sentCount -eq 2
        LaunchesGame = $false
    }
}

$playerLogArtifact = Join-Path $artifactRoot "Player-$ArtifactLabel.log"
$bepInExLogArtifact = Join-Path $artifactRoot "LogOutput-$ArtifactLabel.log"
$visibilityArtifact = Join-Path $artifactRoot "Visibility-$ArtifactLabel.json"
$screenshotArtifact = Join-Path $artifactRoot "Screenshot-$ArtifactLabel.png"
$afterInputScreenshotArtifact = Join-Path $artifactRoot "AfterInput-$ArtifactLabel.png"
$resultArtifact = Join-Path $artifactRoot "Result-$ArtifactLabel.json"
$werArtifact = Join-Path $artifactRoot "WER-$ArtifactLabel.txt"
$clientSettingsPath = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Settings\v4\ClientSettings.json"
$clientSettingsBackupArtifact = Join-Path $artifactRoot "ClientSettings-$ArtifactLabel.before.json"

$launchArgs = @(
    "-windowed",
    "-screen-width", "$Width",
    "-screen-height", "$Height",
    "-screen-fullscreen", "0",
    "-force-d3d11",
    "-single-instance",
    "-logFile", $playerLogArtifact
)

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "Run" })
    Question = "Can Codex launch V Rising in a controlled $Width`x$Height no-DLSS loader state, detect the real game window, capture a valid screenshot, and cleanly restore state without human input? If Unity presents FullScreenWindow, record that separately from true windowed mode."
    Hypothesis = "Official Unity/V Rising launch options plus existing visibility/capture helpers are enough for a first automation proof-of-control."
    ExpectedEvidence = @(
        "VisibleGameWindow status from inspect-vrising-visibility.ps1",
        "A nonblank screenshot artifact with captured client size recorded",
        $(if ($SendHarmlessInput) { "One harmless key sent to the selected UnityWndClass window plus an after-input screenshot" } else { "" }),
        "Player.log SetResolution line parsed into game-reported resolution and fullScreenMode",
        "Player and BepInEx logs archived under artifacts/gameplay-automation",
        "No VRising process remains after cleanup",
        "Loader config restored"
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    PassSignal = $(if ($SendHarmlessInput) { "VisibleGameWindow plus nonblank before screenshot plus SendInput success plus nonblank after screenshot plus cleanup with CrashEventCount=0." } else { "VisibleGameWindow plus nonblank screenshot plus requested capture size plus cleanup with CrashEventCount=0." })
    PartialSignal = "Automation control succeeds and the game reports the requested resolution, but fullscreen-window behavior makes the captured client size differ from the requested windowed test shape."
    FailSignal = "No visible game window, invalid screenshot, crash event, early process exit, missing requested game resolution, or cleanup failure."
    CleanupPath = "CloseMainWindow, then force-stop if needed; restore loader config; archive logs/WER/result."
    GamePath = $resolvedGamePath
    LaunchArgs = $launchArgs
    Width = $Width
    Height = $Height
    WaitForWindowSeconds = $WaitForWindowSeconds
    WaitForNonBlankScreenshotSeconds = $WaitForNonBlankScreenshotSeconds
    ScreenshotRetrySeconds = $ScreenshotRetrySeconds
    ObservationSeconds = $ObservationSeconds
    SendHarmlessInput = [bool]$SendHarmlessInput
    HarmlessInputKey = $(if ($SendHarmlessInput) { $HarmlessInputKey } else { "" })
    PostInputWaitSeconds = $(if ($SendHarmlessInput) { $PostInputWaitSeconds } else { 0 })
    SkipInstall = [bool]$SkipInstall
    SetClientResolution = [bool]$SetClientResolution
    ClientSettingsPath = $clientSettingsPath
    ClientSettingsBackupArtifact = $(if ($SetClientResolution) { $clientSettingsBackupArtifact } else { "" })
    ScreenshotMethod = $ScreenshotMethod
    ArtifactLabel = $ArtifactLabel
    ArtifactRoot = $artifactRoot
    PlayerLogArtifact = $playerLogArtifact
    BepInExLogArtifact = $bepInExLogArtifact
    VisibilityArtifact = $visibilityArtifact
    ScreenshotArtifact = $screenshotArtifact
    AfterInputScreenshotArtifact = $(if ($SendHarmlessInput) { $afterInputScreenshotArtifact } else { "" })
    ResultArtifact = $resultArtifact
    RestoresLoaderConfig = $true
    LaunchesGame = -not [bool]$DryRun
}

if ($DryRun) {
    $plan
    return
}

$existing = Get-VRisingProcess | Select-Object -First 1
if ($existing) {
    throw "VRising is already running (pid=$($existing.Id)). Close it before running automation proof."
}

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null

$runStart = Get-Date
$process = $null
$visibility = $null
$screenshotCreated = $false
$screenshotAccepted = $false
$screenshotNonBlank = $false
$windowSizeMatchesRequested = $false
$captureClientSizeMatchesRequested = $false
$captureResult = $null
$afterInputCaptureResult = $null
$inputAttempted = $false
$inputResult = $null
$inputSent = $false
$inputAfterScreenshotCreated = $false
$inputAfterScreenshotNonBlank = $false
$inputProofReady = $false
$playerLogResolutionInfo = $null
$gameReportedWidth = $null
$gameReportedHeight = $null
$gameReportedFullScreenMode = ""
$gameReportedSetResolutionLine = ""
$gameResolutionMatchesRequested = $false
$gameModeIsWindowed = $false
$gameModeIsFullScreenWindow = $false
$windowedModeReady = $false
$automationControlReady = $false
$closedByScript = $false
$restoredLoaderConfig = $false
$restoredClientSettings = -not [bool]$SetClientResolution
$crashEvents = @()
$status = "Failed"
$failureReason = ""

try {
    if (-not $SkipInstall) {
        & (Join-Path $resolvedRoot "scripts\install-local-package.ps1") -GamePath $resolvedGamePath | Out-Host
    }

    & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") -GamePath $resolvedGamePath -Stage loader | Out-Host

    if ($SetClientResolution) {
        if (-not (Test-Path -LiteralPath $clientSettingsPath)) {
            throw "ClientSettings.json was not found: $clientSettingsPath"
        }

        Copy-Item -LiteralPath $clientSettingsPath -Destination $clientSettingsBackupArtifact -Force
        $settings = Get-Content -LiteralPath $clientSettingsPath -Raw | ConvertFrom-Json
        if (-not $settings.GraphicSettings -or -not $settings.GraphicSettings.Resolution) {
            throw "ClientSettings.json does not contain GraphicSettings.Resolution."
        }

        $settings.GraphicSettings.Resolution.x = $Width
        $settings.GraphicSettings.Resolution.y = $Height
        $settings | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $clientSettingsPath -Encoding UTF8
        Write-Host "Temporarily set ClientSettings GraphicSettings.Resolution to ${Width}x${Height}."
    }

    Write-Host "AutomationProofStart=$($runStart.ToString('o'))"
    Write-Host "ArtifactLabel=$ArtifactLabel"
    Write-Host "LaunchArgs=$($launchArgs -join ' ')"

    $process = Start-Process -FilePath $exePath -WorkingDirectory $resolvedGamePath -ArgumentList $launchArgs -PassThru
    Write-Host "Started VRising pid=$($process.Id)"

    $deadline = (Get-Date).AddSeconds($WaitForWindowSeconds)
    do {
        if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
            $failureReason = "VRising exited before a visible game window was detected."
            break
        }

        $visibilityJson = & (Join-Path $resolvedRoot "scripts\inspect-vrising-visibility.ps1") `
            -GamePath $resolvedGamePath `
            -SearchGamePathProcesses `
            -Json
        $visibilityJson | Set-Content -LiteralPath $visibilityArtifact -Encoding UTF8
        $visibility = $visibilityJson | ConvertFrom-Json

        if ($visibility.Status -eq "VisibleGameWindow") {
            break
        }

        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    if (-not $visibility -or $visibility.Status -ne "VisibleGameWindow") {
        if ([string]::IsNullOrWhiteSpace($failureReason)) {
            $failureReason = "VisibleGameWindow was not detected before timeout."
        }
    } else {
        $screenshotDeadline = (Get-Date).AddSeconds($WaitForNonBlankScreenshotSeconds)
        do {
            $captureOutput = & (Join-Path $resolvedRoot "scripts\capture-vrising-window.ps1") `
                -OutputPath $screenshotArtifact `
                -ArtifactLabel "$ArtifactLabel-window" `
                -Method $ScreenshotMethod `
                -WaitSeconds 0
            $captureOutput | Out-Host
            $captureResult = @($captureOutput)[-1]
            $screenshotCreated = Test-Path -LiteralPath $screenshotArtifact

            if ($screenshotCreated -and $captureResult) {
                $nearBlack = [double]$captureResult.NearBlackRatio
                $nearWhite = [double]$captureResult.NearWhiteRatio
                $averageLuma = [double]$captureResult.AverageLuma
                $captureWidth = [int]$captureResult.Width
                $captureHeight = [int]$captureResult.Height
                $captureClientSizeMatchesRequested = ($captureWidth -eq $Width -and $captureHeight -eq $Height)
                $windowSizeMatchesRequested = $captureClientSizeMatchesRequested
                $screenshotNonBlank = ($nearBlack -lt 0.98 -and $nearWhite -lt 0.98 -and $averageLuma -gt 1.0)
                $screenshotAccepted = $screenshotNonBlank
                if ($screenshotAccepted) {
                    break
                }

                Write-Host "Screenshot not accepted yet: Width=${captureWidth} Height=${captureHeight} NearBlackRatio=$nearBlack NearWhiteRatio=$nearWhite AverageLuma=$averageLuma"
            }

            if ((Get-Date) -ge $screenshotDeadline) {
                break
            }

            Start-Sleep -Seconds $ScreenshotRetrySeconds
        } while ($true)

        if ($ObservationSeconds -gt 0) {
            Start-Sleep -Seconds $ObservationSeconds
        }

        if ($screenshotCreated -and $screenshotAccepted) {
            Write-Host "Accepted nonblank screenshot. CaptureClientSizeMatchesRequested=$captureClientSizeMatchesRequested"

            if ($SendHarmlessInput) {
                $inputAttempted = $true
                $selectedWindowHandle = ""
                if ($visibility.SelectedWindow -and $visibility.SelectedWindow.Handle) {
                    $selectedWindowHandle = [string]$visibility.SelectedWindow.Handle
                }

                Write-Host "Sending harmless input key '$HarmlessInputKey' to selected window $selectedWindowHandle."
                $inputResult = Send-HarmlessInputToWindow -Handle $selectedWindowHandle -Key $HarmlessInputKey
                $inputSent = [bool]$inputResult.SendInputSucceeded

                if ($PostInputWaitSeconds -gt 0) {
                    Start-Sleep -Seconds $PostInputWaitSeconds
                }

                $afterInputCaptureOutput = & (Join-Path $resolvedRoot "scripts\capture-vrising-window.ps1") `
                    -OutputPath $afterInputScreenshotArtifact `
                    -ArtifactLabel "$ArtifactLabel-after-input" `
                    -Method $ScreenshotMethod `
                    -WaitSeconds 0
                $afterInputCaptureOutput | Out-Host
                $afterInputCaptureResult = @($afterInputCaptureOutput)[-1]
                $inputAfterScreenshotCreated = Test-Path -LiteralPath $afterInputScreenshotArtifact

                if ($inputAfterScreenshotCreated -and $afterInputCaptureResult) {
                    $afterNearBlack = [double]$afterInputCaptureResult.NearBlackRatio
                    $afterNearWhite = [double]$afterInputCaptureResult.NearWhiteRatio
                    $afterAverageLuma = [double]$afterInputCaptureResult.AverageLuma
                    $inputAfterScreenshotNonBlank = ($afterNearBlack -lt 0.98 -and $afterNearWhite -lt 0.98 -and $afterAverageLuma -gt 1.0)
                }
            }
        } elseif ($screenshotCreated) {
            $failureReason = "Screenshot artifact was created but remained blank/invalid before timeout."
        } else {
            $failureReason = "Screenshot artifact was not created."
        }
    }
} catch {
    $failureReason = $_.Exception.Message
    throw
} finally {
    $runEnd = Get-Date

    if ($process) {
        $closedByScript = Close-VRisingProcess -Process $process
    }

    try {
        if (Test-Path -LiteralPath $logPath) {
            Copy-Item -LiteralPath $logPath -Destination $bepInExLogArtifact -Force
        }
    } catch {
        Write-Warning "BepInEx log archive failed: $($_.Exception.Message)"
    }

    try {
        $defaultPlayerLog = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Player.log"
        if (-not (Test-Path -LiteralPath $playerLogArtifact) -and (Test-Path -LiteralPath $defaultPlayerLog)) {
            Copy-Item -LiteralPath $defaultPlayerLog -Destination $playerLogArtifact -Force
        }
    } catch {
        Write-Warning "Player log archive failed: $($_.Exception.Message)"
    }

    try {
        $crashEvents = @(Get-WinEvent -FilterHashtable @{
                ProviderName = "Application Error"
                StartTime = $runStart.AddSeconds(-5)
                EndTime = $runEnd.AddSeconds(10)
            } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match "VRising|UnityPlayer|coreclr|VrisingDLSS" } |
            Select-Object TimeCreated, Id, ProviderName, Message)

        if ($crashEvents.Count -gt 0) {
            $crashEvents | Format-List | Out-String -Width 220 | Set-Content -LiteralPath $werArtifact -Encoding UTF8
            $status = "Failed"
            if ([string]::IsNullOrWhiteSpace($failureReason)) {
                $failureReason = "Windows Application Error event was recorded."
            }
        }
    } catch {
        Write-Warning "WER archive failed: $($_.Exception.Message)"
    }

    try {
        if ($SetClientResolution -and (Test-Path -LiteralPath $clientSettingsBackupArtifact)) {
            Copy-Item -LiteralPath $clientSettingsBackupArtifact -Destination $clientSettingsPath -Force
            $restoredClientSettings = $true
        }

        & (Join-Path $resolvedRoot "scripts\write-diagnostic-config.ps1") -GamePath $resolvedGamePath -Stage loader | Out-Host
        $restoredLoaderConfig = $true
    } catch {
        Write-Warning "Restoring client settings or loader config failed: $($_.Exception.Message)"
        $status = "Failed"
        if ([string]::IsNullOrWhiteSpace($failureReason)) {
            $failureReason = "Client settings or loader config restore failed."
        }
    }

    $remainingProcessCount = @(Get-VRisingProcess).Count
    if ($remainingProcessCount -gt 0) {
        $status = "Failed"
        if ([string]::IsNullOrWhiteSpace($failureReason)) {
            $failureReason = "VRising process remained after cleanup."
        }
    }

    $playerLogResolutionInfo = Get-PlayerLogResolutionInfo -Path $playerLogArtifact
    if ($playerLogResolutionInfo) {
        $gameReportedWidth = $playerLogResolutionInfo.Width
        $gameReportedHeight = $playerLogResolutionInfo.Height
        $gameReportedFullScreenMode = $playerLogResolutionInfo.FullScreenMode
        $gameReportedSetResolutionLine = $playerLogResolutionInfo.SetResolutionLine
        $gameResolutionMatchesRequested = ($gameReportedWidth -eq $Width -and $gameReportedHeight -eq $Height)
        $gameModeIsWindowed = $gameReportedFullScreenMode -eq "Windowed"
        $gameModeIsFullScreenWindow = $gameReportedFullScreenMode -eq "FullScreenWindow"
    }

    $automationControlReady = (
        $visibility -and
        $visibility.Status -eq "VisibleGameWindow" -and
        $screenshotCreated -and
        $screenshotAccepted -and
        $crashEvents.Count -eq 0 -and
        $remainingProcessCount -eq 0 -and
        $restoredLoaderConfig -and
        ($restoredClientSettings -or -not [bool]$SetClientResolution)
    )
    $windowedModeReady = ($automationControlReady -and $captureClientSizeMatchesRequested -and ($gameModeIsWindowed -or [string]::IsNullOrWhiteSpace($gameReportedFullScreenMode)))
    $inputProofReady = ($automationControlReady -and [bool]$SendHarmlessInput -and $inputAttempted -and $inputSent -and $inputAfterScreenshotCreated -and $inputAfterScreenshotNonBlank)

    if ([string]::IsNullOrWhiteSpace($failureReason)) {
        if (-not $visibility -or $visibility.Status -ne "VisibleGameWindow") {
            $status = "Failed"
            $failureReason = "VisibleGameWindow was not detected before timeout."
        } elseif (-not $screenshotCreated) {
            $status = "Failed"
            $failureReason = "Screenshot artifact was not created."
        } elseif (-not $screenshotAccepted) {
            $status = "Failed"
            $failureReason = "Screenshot artifact was created but remained blank/invalid before timeout."
        } elseif ($SendHarmlessInput -and $inputProofReady) {
            $status = "Pass"
        } elseif ($SendHarmlessInput -and -not $inputAttempted) {
            $status = "Failed"
            $failureReason = "Harmless input proof was requested but no input was attempted."
        } elseif ($SendHarmlessInput -and -not $inputSent) {
            $status = "Failed"
            $failureReason = "Harmless input SendInput did not report a full key down/up pair."
        } elseif ($SendHarmlessInput -and (-not $inputAfterScreenshotCreated -or -not $inputAfterScreenshotNonBlank)) {
            $status = "Failed"
            $failureReason = "Harmless input was sent, but the after-input screenshot was missing or blank/invalid."
        } elseif ($windowedModeReady) {
            $status = "Pass"
        } elseif ($automationControlReady -and $gameResolutionMatchesRequested -and $gameModeIsFullScreenWindow -and -not $captureClientSizeMatchesRequested) {
            $status = "Partial"
            $failureReason = "Automation control succeeded and Player.log reported the requested resolution, but Unity used FullScreenWindow and the captured client size did not match the requested windowed test shape."
        } elseif ($automationControlReady -and $gameResolutionMatchesRequested) {
            $status = "Partial"
            $failureReason = "Automation control succeeded and Player.log reported the requested resolution, but the windowed capture shape is still not proven."
        } elseif ($automationControlReady -and $captureClientSizeMatchesRequested) {
            $status = "Partial"
            $failureReason = "Automation control succeeded at the requested capture size, but Player.log did not report the requested game resolution."
        } else {
            $status = "Failed"
            $failureReason = "Automation control did not reach a supported pass or partial signal."
        }
    }

    $result = [pscustomobject]@{
        Mode = "Completed"
        Status = $status
        FailureReason = $failureReason
        GamePath = $resolvedGamePath
        ArtifactLabel = $ArtifactLabel
        StartedAt = $runStart.ToString("o")
        EndedAt = $runEnd.ToString("o")
        Width = $Width
        Height = $Height
        LaunchArgs = $launchArgs
        VisibilityStatus = $(if ($visibility) { $visibility.Status } else { "" })
        ScreenshotCreated = $screenshotCreated
        ScreenshotAccepted = $screenshotAccepted
        ScreenshotNonBlank = $screenshotNonBlank
        CaptureClientSizeMatchesRequested = $captureClientSizeMatchesRequested
        WindowSizeMatchesRequested = $windowSizeMatchesRequested
        ScreenshotWidth = $(if ($captureResult) { [int]$captureResult.Width } else { $null })
        ScreenshotHeight = $(if ($captureResult) { [int]$captureResult.Height } else { $null })
        ScreenshotNearBlackRatio = $(if ($captureResult) { [double]$captureResult.NearBlackRatio } else { $null })
        ScreenshotNearWhiteRatio = $(if ($captureResult) { [double]$captureResult.NearWhiteRatio } else { $null })
        ScreenshotAverageLuma = $(if ($captureResult) { [double]$captureResult.AverageLuma } else { $null })
        ScreenshotArtifact = $(if (Test-Path -LiteralPath $screenshotArtifact) { $screenshotArtifact } else { "" })
        SendHarmlessInput = [bool]$SendHarmlessInput
        HarmlessInputKey = $(if ($SendHarmlessInput) { $HarmlessInputKey } else { "" })
        InputAttempted = $inputAttempted
        InputWindowHandle = $(if ($inputResult) { [string]$inputResult.WindowHandle } else { "" })
        InputVirtualKey = $(if ($inputResult) { [string]$inputResult.VirtualKey } else { "" })
        InputForegrounded = $(if ($inputResult) { [bool]$inputResult.Foregrounded } else { $false })
        InputStructSize = $(if ($inputResult) { [int]$inputResult.InputStructSize } else { 0 })
        InputSendInputCount = $(if ($inputResult) { [int]$inputResult.SendInputCount } else { 0 })
        InputSendInputLastWin32Error = $(if ($inputResult) { [int]$inputResult.SendInputLastWin32Error } else { 0 })
        InputSent = $inputSent
        InputAfterScreenshotCreated = $inputAfterScreenshotCreated
        InputAfterScreenshotNonBlank = $inputAfterScreenshotNonBlank
        InputAfterScreenshotWidth = $(if ($afterInputCaptureResult) { [int]$afterInputCaptureResult.Width } else { $null })
        InputAfterScreenshotHeight = $(if ($afterInputCaptureResult) { [int]$afterInputCaptureResult.Height } else { $null })
        InputAfterScreenshotNearBlackRatio = $(if ($afterInputCaptureResult) { [double]$afterInputCaptureResult.NearBlackRatio } else { $null })
        InputAfterScreenshotNearWhiteRatio = $(if ($afterInputCaptureResult) { [double]$afterInputCaptureResult.NearWhiteRatio } else { $null })
        InputAfterScreenshotAverageLuma = $(if ($afterInputCaptureResult) { [double]$afterInputCaptureResult.AverageLuma } else { $null })
        InputAfterScreenshotArtifact = $(if (Test-Path -LiteralPath $afterInputScreenshotArtifact) { $afterInputScreenshotArtifact } else { "" })
        InputProofReady = $inputProofReady
        PlayerLogArtifact = $(if (Test-Path -LiteralPath $playerLogArtifact) { $playerLogArtifact } else { "" })
        BepInExLogArtifact = $(if (Test-Path -LiteralPath $bepInExLogArtifact) { $bepInExLogArtifact } else { "" })
        VisibilityArtifact = $(if (Test-Path -LiteralPath $visibilityArtifact) { $visibilityArtifact } else { "" })
        WerArtifact = $(if (Test-Path -LiteralPath $werArtifact) { $werArtifact } else { "" })
        CrashEventCount = $crashEvents.Count
        ClosedByScript = $closedByScript
        RestoredLoaderConfig = $restoredLoaderConfig
        SetClientResolution = [bool]$SetClientResolution
        RestoredClientSettings = $restoredClientSettings
        ClientSettingsBackupArtifact = $(if (Test-Path -LiteralPath $clientSettingsBackupArtifact) { $clientSettingsBackupArtifact } else { "" })
        GameReportedWidth = $gameReportedWidth
        GameReportedHeight = $gameReportedHeight
        GameReportedFullScreenMode = $gameReportedFullScreenMode
        GameReportedSetResolutionLine = $gameReportedSetResolutionLine
        GameResolutionMatchesRequested = $gameResolutionMatchesRequested
        GameModeIsWindowed = $gameModeIsWindowed
        GameModeIsFullScreenWindow = $gameModeIsFullScreenWindow
        WindowedModeReady = $windowedModeReady
        AutomationControlReady = $automationControlReady
        RemainingVRisingProcessCount = $remainingProcessCount
        LaunchesGame = $true
    }

    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultArtifact -Encoding UTF8
    $result
}
