param(
    [ValidateSet("Off", "UltraQuality", "Quality", "Balanced", "Performance")]
    [string]$Mode,

    [string]$SettingsPath,

    [string]$Root,

    [switch]$NoBackup,

    [switch]$AllowRunningGame,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path

if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
    $SettingsPath = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\Settings\v4\ClientSettings.json"
} elseif (-not [System.IO.Path]::IsPathRooted($SettingsPath)) {
    $SettingsPath = Join-Path $resolvedRoot $SettingsPath
}

$resolvedSettingsPath = [System.IO.Path]::GetFullPath($SettingsPath)

$modeValues = @{
    Off = 0
    UltraQuality = 1
    Quality = 2
    Balanced = 3
    Performance = 4
}

function Get-FsrModeName {
    param([int]$Value)

    foreach ($entry in $modeValues.GetEnumerator()) {
        if ($entry.Value -eq $Value) {
            return $entry.Key
        }
    }

    return "Unknown($Value)"
}

if ([string]::IsNullOrWhiteSpace($Mode)) {
    throw "Pass -Mode Off, UltraQuality, Quality, Balanced, or Performance."
}

if (-not (Test-Path -LiteralPath $resolvedSettingsPath)) {
    throw "V Rising ClientSettings.json was not found: $resolvedSettingsPath"
}

if (-not $AllowRunningGame -and (Get-Process VRising -ErrorAction SilentlyContinue)) {
    throw "VRising.exe is running. Close the game before changing ClientSettings.json, or pass -AllowRunningGame if this is intentional."
}

$jsonText = Get-Content -LiteralPath $resolvedSettingsPath -Raw
$settings = $jsonText | ConvertFrom-Json

if (-not $settings.GraphicSettings) {
    $settings | Add-Member -MemberType NoteProperty -Name GraphicSettings -Value ([pscustomobject]@{})
}

$graphicSettings = $settings.GraphicSettings
$previousValue = if ($null -ne $graphicSettings.FsrQualityMode) { [int]$graphicSettings.FsrQualityMode } else { 0 }
$newValue = [int]$modeValues[$Mode]

$backupPath = ""
if (-not $NoBackup) {
    $backupRoot = Join-Path $resolvedRoot "artifacts\local\client-settings-backups"
    $backupName = "ClientSettings-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss")
    $backupPath = Join-Path $backupRoot $backupName
}

if ($DryRun) {
    [pscustomobject]@{
        Mode = "DryRun"
        SettingsPath = $resolvedSettingsPath
        PreviousFsrQualityMode = $previousValue
        PreviousFsrQualityName = Get-FsrModeName -Value $previousValue
        NewFsrQualityMode = $newValue
        NewFsrQualityName = $Mode
        BackupPath = $backupPath
        LaunchesGame = $false
    }
    return
}

if (-not $NoBackup) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
    Copy-Item -LiteralPath $resolvedSettingsPath -Destination $backupPath -Force
}

if ($null -eq $graphicSettings.FsrQualityMode) {
    $graphicSettings | Add-Member -MemberType NoteProperty -Name FsrQualityMode -Value $newValue
} else {
    $graphicSettings.FsrQualityMode = $newValue
}

$settings |
    ConvertTo-Json -Depth 32 |
    Set-Content -LiteralPath $resolvedSettingsPath -Encoding UTF8

[pscustomobject]@{
    Mode = "Updated"
    SettingsPath = $resolvedSettingsPath
    PreviousFsrQualityMode = $previousValue
    PreviousFsrQualityName = Get-FsrModeName -Value $previousValue
    NewFsrQualityMode = $newValue
    NewFsrQualityName = $Mode
    BackupPath = $backupPath
    LaunchesGame = $false
}
