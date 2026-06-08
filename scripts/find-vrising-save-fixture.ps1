param(
    [string]$SaveName = "11111",
    [string]$CloudSavesRoot,
    [switch]$RequireOne,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CloudSavesRoot)) {
    $CloudSavesRoot = Join-Path $env:USERPROFILE "AppData\LocalLow\Stunlock Studios\VRising\CloudSaves"
}

$fixtureMatches = @()
$issues = New-Object System.Collections.Generic.List[string]
$resolvedRoot = ""
$status = "Missing"

try {
    if (-not (Test-Path -LiteralPath $CloudSavesRoot)) {
        [void]$issues.Add("CloudSavesRoot does not exist: $CloudSavesRoot")
    } else {
        $resolvedRoot = (Resolve-Path -LiteralPath $CloudSavesRoot).Path
        $rootWithSlash = $resolvedRoot.TrimEnd('\') + '\'
        $hostFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Filter ServerHostSettings.json -File -ErrorAction Stop)
        foreach ($hostFile in $hostFiles) {
            try {
                $hostSettings = Get-Content -LiteralPath $hostFile.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
                $name = [string]$hostSettings.Name
                if (-not [string]::IsNullOrWhiteSpace($SaveName) -and -not $name.Equals($SaveName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }

                $saveDir = Split-Path -Parent $hostFile.FullName
                $relative = [System.IO.Path]::GetFullPath($saveDir).Substring($rootWithSlash.Length)
                $relativeParts = $relative -split "\\"
                $serverGameSettingsPath = Join-Path $saveDir "ServerGameSettings.json"
                $autoSaves = @(Get-ChildItem -LiteralPath $saveDir -Filter "AutoSave_*.save.gz" -File -ErrorAction SilentlyContinue)
                $latestAutoSave = @($autoSaves | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
                $hasServerGameSettings = Test-Path -LiteralPath $serverGameSettingsPath
                $isUsable = $hasServerGameSettings -and $autoSaves.Count -gt 0

                $fixtureMatches += [pscustomobject]@{
                        Name = $name
                        SaveDir = [System.IO.Path]::GetFullPath($saveDir)
                        SteamId = $(if ($relativeParts.Count -ge 1) { $relativeParts[0] } else { "" })
                        SaveVersion = $(if ($relativeParts.Count -ge 2) { $relativeParts[1] } else { "" })
                        SaveId = Split-Path -Leaf $saveDir
                        HostSettingsPath = $hostFile.FullName
                        HasServerGameSettings = [bool]$hasServerGameSettings
                        AutoSaveCount = $autoSaves.Count
                        LatestAutoSave = $(if ($latestAutoSave.Count -gt 0) { $latestAutoSave[0].Name } else { "" })
                        LatestAutoSaveUtc = $(if ($latestAutoSave.Count -gt 0) { $latestAutoSave[0].LastWriteTimeUtc.ToString("o") } else { "" })
                        Usable = [bool]$isUsable
                    }
            } catch {
                [void]$issues.Add("Failed to read $($hostFile.FullName): $($_.Exception.Message)")
            }
        }

        if ($fixtureMatches.Count -eq 1) {
            if ([bool]$fixtureMatches[0].Usable) {
                $status = "Pass"
            } else {
                $status = "Fail"
                [void]$issues.Add("Matched save fixture is missing ServerGameSettings.json or autosave files.")
            }
        } elseif ($fixtureMatches.Count -gt 1) {
            $status = "Ambiguous"
            [void]$issues.Add("More than one save fixture matched SaveName=$SaveName.")
        } else {
            $status = "Missing"
            [void]$issues.Add("No save fixture matched SaveName=$SaveName.")
        }
    }
} catch {
    $status = "Fail"
    [void]$issues.Add($_.Exception.Message)
}

$result = [pscustomobject]@{
    Status = $status
    LaunchesGame = $false
    ModifiesGameFiles = $false
    SaveName = $SaveName
    CloudSavesRoot = $resolvedRoot
    MatchCount = $fixtureMatches.Count
    SelectedSaveDir = $(if ($status -eq "Pass") { [string]$fixtureMatches[0].SaveDir } else { "" })
    Matches = @($fixtureMatches)
    Issues = @($issues)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    $result
}

if ($RequireOne -and $status -ne "Pass") {
    throw "V Rising save fixture resolver status=$status; Issues=$(@($issues) -join ' | ')"
}
