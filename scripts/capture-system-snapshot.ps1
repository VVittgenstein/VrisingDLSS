param(
    [string]$OutputPath,
    [string]$ArtifactLabel,
    [string]$Root,
    [string]$ProcessName = "VRising.exe",
    [int]$ProcessId = 0,
    [string]$NvidiaSmiPath = "nvidia-smi.exe",
    [int]$TopProcessCount = 25,
    [int]$SampleMilliseconds = 1000,
    [string]$Reason = "snapshot",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($ProcessId -lt 0) {
    throw "ProcessId cannot be negative."
}

if ($TopProcessCount -lt 1) {
    throw "TopProcessCount must be at least 1."
}

if ($SampleMilliseconds -lt 250) {
    throw "SampleMilliseconds must be at least 250."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$snapshotRoot = Join-Path $resolvedRoot "artifacts\system-snapshots"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "system-snapshot-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $snapshotRoot "$ArtifactLabel.json"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $resolvedRoot $OutputPath
}

$targetPath = [System.IO.Path]::GetFullPath($OutputPath)
$nvidiaSmiResolved = $NvidiaSmiPath
if (-not [System.IO.Path]::IsPathRooted($nvidiaSmiResolved)) {
    $nvidiaCommand = Get-Command $NvidiaSmiPath -ErrorAction SilentlyContinue
    if ($nvidiaCommand) {
        $nvidiaSmiResolved = $nvidiaCommand.Source
    }
} else {
    $nvidiaSmiResolved = [System.IO.Path]::GetFullPath($nvidiaSmiResolved)
}

$plan = [pscustomobject]@{
    Mode = $(if ($DryRun) { "DryRun" } else { "CaptureSystemSnapshot" })
    Reason = $Reason
    ProcessName = $(if ($ProcessId -gt 0) { "" } else { $ProcessName })
    ProcessId = $ProcessId
    TopProcessCount = $TopProcessCount
    SampleMilliseconds = $SampleMilliseconds
    NvidiaSmiPath = $nvidiaSmiResolved
    OutputPath = $targetPath
    LaunchesGame = $false
}

if ($DryRun) {
    $plan
    return
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null

$culture = [Globalization.CultureInfo]::InvariantCulture
$logicalProcessorCount = [Environment]::ProcessorCount

function Convert-NullableDouble {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq "NA" -or $Value -eq "[N/A]") {
        return $null
    }

    $trimmed = $Value.Trim()
    $parsed = 0.0
    if ([double]::TryParse($trimmed, [Globalization.NumberStyles]::Float, $culture, [ref]$parsed)) {
        return $parsed
    }

    return $null
}

function Round-Nullable {
    param(
        $Value,
        [int]$Digits = 3
    )

    if ($null -eq $Value) {
        return $null
    }

    $number = [double]$Value
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
        return $null
    }

    return [Math]::Round($number, $Digits)
}

function Get-ProcessPathMap {
    $map = @{}
    try {
        foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
            $map[[int]$process.ProcessId] = [pscustomobject]@{
                Path = [string]$process.ExecutablePath
                ParentProcessId = [int]$process.ParentProcessId
            }
        }
    } catch {
        Write-Warning "Process path query failed: $($_.Exception.Message)"
    }

    return $map
}

function Get-ProcessSamples {
    $samples = @{}
    foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
        $cpuSeconds = $null
        try {
            if ($null -ne $process.TotalProcessorTime) {
                $cpuSeconds = $process.TotalProcessorTime.TotalSeconds
            }
        } catch {
            $cpuSeconds = $null
        }

        $samples[[int]$process.Id] = [pscustomobject]@{
            Id = [int]$process.Id
            Name = [string]$process.ProcessName
            CpuSeconds = $cpuSeconds
            WorkingSet64 = [int64]$process.WorkingSet64
            PrivateMemorySize64 = [int64]$process.PrivateMemorySize64
            MainWindowTitle = [string]$process.MainWindowTitle
            StartTime = $(try { $process.StartTime.ToString("o") } catch { "" })
        }
    }

    return $samples
}

function Convert-ProcessRow {
    param(
        [Parameter(Mandatory = $true)]
        $Sample,
        [hashtable]$BeforeSamples,
        [double]$ElapsedSeconds,
        [hashtable]$PathMap
    )

    $cpuPercent = $null
    if ($BeforeSamples.ContainsKey($Sample.Id)) {
        $before = $BeforeSamples[$Sample.Id]
        if ($null -ne $Sample.CpuSeconds -and $null -ne $before.CpuSeconds -and $ElapsedSeconds -gt 0 -and $logicalProcessorCount -gt 0) {
            $cpuPercent = (($Sample.CpuSeconds - $before.CpuSeconds) / $ElapsedSeconds) / $logicalProcessorCount * 100.0
        }
    }

    $pathInfo = $null
    if ($PathMap.ContainsKey($Sample.Id)) {
        $pathInfo = $PathMap[$Sample.Id]
    }

    [pscustomobject]@{
        Id = $Sample.Id
        Name = $Sample.Name
        CpuPercent = Round-Nullable -Value $cpuPercent
        WorkingSetMb = Round-Nullable -Value ($Sample.WorkingSet64 / 1MB) -Digits 1
        PrivateMb = Round-Nullable -Value ($Sample.PrivateMemorySize64 / 1MB) -Digits 1
        MainWindowTitle = $Sample.MainWindowTitle
        Path = $(if ($pathInfo) { $pathInfo.Path } else { "" })
        ParentProcessId = $(if ($pathInfo) { $pathInfo.ParentProcessId } else { $null })
        StartTime = $Sample.StartTime
    }
}

function Get-TargetProcessRow {
    param(
        [hashtable]$AfterSamples,
        [hashtable]$BeforeSamples,
        [double]$ElapsedSeconds,
        [hashtable]$PathMap
    )

    $target = $null
    if ($ProcessId -gt 0 -and $AfterSamples.ContainsKey($ProcessId)) {
        $target = $AfterSamples[$ProcessId]
    } elseif (-not [string]::IsNullOrWhiteSpace($ProcessName)) {
        $lookupName = $ProcessName
        if ($lookupName.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase)) {
            $lookupName = [System.IO.Path]::GetFileNameWithoutExtension($lookupName)
        }

        $target = @($AfterSamples.Values | Where-Object {
                [string]::Equals($_.Name, $lookupName, [StringComparison]::OrdinalIgnoreCase)
            } | Sort-Object StartTime -Descending | Select-Object -First 1)
        if ($target.Count -gt 0) {
            $target = $target[0]
        } else {
            $target = $null
        }
    }

    if (-not $target) {
        return $null
    }

    return Convert-ProcessRow -Sample $target -BeforeSamples $BeforeSamples -ElapsedSeconds $ElapsedSeconds -PathMap $PathMap
}

function Get-MemorySummary {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalMb = [double]$os.TotalVisibleMemorySize / 1024.0
        $freeMb = [double]$os.FreePhysicalMemory / 1024.0
        [pscustomobject]@{
            TotalPhysicalMb = Round-Nullable -Value $totalMb -Digits 1
            FreePhysicalMb = Round-Nullable -Value $freeMb -Digits 1
            UsedPhysicalMb = Round-Nullable -Value ($totalMb - $freeMb) -Digits 1
            UsedPhysicalPercent = $(if ($totalMb -gt 0) { Round-Nullable -Value ((($totalMb - $freeMb) / $totalMb) * 100.0) } else { $null })
        }
    } catch {
        [pscustomobject]@{
            TotalPhysicalMb = $null
            FreePhysicalMb = $null
            UsedPhysicalMb = $null
            UsedPhysicalPercent = $null
            Error = $_.Exception.Message
        }
    }
}

function Get-CpuSummary {
    $totalCpuPercent = $null
    try {
        $counter = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
        $totalCpuPercent = [double]$counter.PercentProcessorTime
    } catch {
        $totalCpuPercent = $null
    }

    $processor = $null
    try {
        $processor = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    } catch {
        $processor = $null
    }

    [pscustomobject]@{
        Name = $(if ($processor) { [string]$processor.Name } else { "" })
        LogicalProcessorCount = $logicalProcessorCount
        TotalCpuPercent = Round-Nullable -Value $totalCpuPercent
    }
}

function Get-GpuSummary {
    if ([string]::IsNullOrWhiteSpace($nvidiaSmiResolved) -or -not (Test-Path -LiteralPath $nvidiaSmiResolved)) {
        return [pscustomobject]@{
            NvidiaSmiPath = $nvidiaSmiResolved
            Available = $false
            Error = "nvidia-smi was not found."
        }
    }

    try {
        $gpuLine = & $nvidiaSmiResolved --query-gpu=name,driver_version,pstate,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,temperature.gpu,clocks.sm,clocks.mem --format=csv,noheader,nounits 2>$null |
            Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($gpuLine)) {
            throw "nvidia-smi returned no GPU row."
        }

        $parts = @($gpuLine -split "," | ForEach-Object { $_.Trim() })
        [pscustomobject]@{
            NvidiaSmiPath = $nvidiaSmiResolved
            Available = $true
            Name = $(if ($parts.Count -ge 1) { $parts[0] } else { "" })
            DriverVersion = $(if ($parts.Count -ge 2) { $parts[1] } else { "" })
            PState = $(if ($parts.Count -ge 3) { $parts[2] } else { "" })
            GpuUtilPercent = $(if ($parts.Count -ge 4) { Convert-NullableDouble -Value $parts[3] } else { $null })
            GpuMemoryUtilPercent = $(if ($parts.Count -ge 5) { Convert-NullableDouble -Value $parts[4] } else { $null })
            GpuMemoryUsedMb = $(if ($parts.Count -ge 6) { Convert-NullableDouble -Value $parts[5] } else { $null })
            GpuMemoryTotalMb = $(if ($parts.Count -ge 7) { Convert-NullableDouble -Value $parts[6] } else { $null })
            GpuPowerW = $(if ($parts.Count -ge 8) { Convert-NullableDouble -Value $parts[7] } else { $null })
            GpuTemperatureC = $(if ($parts.Count -ge 9) { Convert-NullableDouble -Value $parts[8] } else { $null })
            SmClockMHz = $(if ($parts.Count -ge 10) { Convert-NullableDouble -Value $parts[9] } else { $null })
            MemoryClockMHz = $(if ($parts.Count -ge 11) { Convert-NullableDouble -Value $parts[10] } else { $null })
        }
    } catch {
        [pscustomobject]@{
            NvidiaSmiPath = $nvidiaSmiResolved
            Available = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-GpuProcessSummary {
    if ([string]::IsNullOrWhiteSpace($nvidiaSmiResolved) -or -not (Test-Path -LiteralPath $nvidiaSmiResolved)) {
        return @()
    }

    try {
        $rows = @(& $nvidiaSmiResolved --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader,nounits 2>$null)
        foreach ($row in $rows) {
            if ([string]::IsNullOrWhiteSpace($row)) {
                continue
            }

            $parts = @($row -split "," | ForEach-Object { $_.Trim() })
            if ($parts.Count -ge 3) {
                $pid = 0
                if (-not [int]::TryParse($parts[0], [ref]$pid)) {
                    continue
                }

                [pscustomobject]@{
                    Id = $pid
                    Name = $parts[1]
                    UsedGpuMemoryMb = Convert-NullableDouble -Value $parts[2]
                }
            }
        }
    } catch {
        @()
    }
}

$startedAt = Get-Date
$beforeSamples = Get-ProcessSamples
Start-Sleep -Milliseconds $SampleMilliseconds
$endedAt = Get-Date
$afterSamples = Get-ProcessSamples
$elapsedSeconds = [Math]::Max(($endedAt - $startedAt).TotalSeconds, 0.001)
$pathMap = Get-ProcessPathMap

$processRows = @($afterSamples.Values | ForEach-Object {
        Convert-ProcessRow -Sample $_ -BeforeSamples $beforeSamples -ElapsedSeconds $elapsedSeconds -PathMap $pathMap
    })

$topCpuProcesses = @($processRows |
    Where-Object { $null -ne $_.CpuPercent } |
    Sort-Object CpuPercent -Descending |
    Select-Object -First $TopProcessCount)

$topMemoryProcesses = @($processRows |
    Sort-Object WorkingSetMb -Descending |
    Select-Object -First $TopProcessCount)

$result = [pscustomobject]@{
    Mode = "SystemSnapshot"
    Reason = $Reason
    Timestamp = (Get-Date).ToString("o")
    SampleStartedAt = $startedAt.ToString("o")
    SampleEndedAt = $endedAt.ToString("o")
    SampleMilliseconds = $SampleMilliseconds
    LogicalProcessorCount = $logicalProcessorCount
    ProcessName = $(if ($ProcessId -gt 0) { "" } else { $ProcessName })
    ProcessId = $ProcessId
    TargetProcess = Get-TargetProcessRow -AfterSamples $afterSamples -BeforeSamples $beforeSamples -ElapsedSeconds $elapsedSeconds -PathMap $pathMap
    Cpu = Get-CpuSummary
    Memory = Get-MemorySummary
    Gpu = Get-GpuSummary
    GpuProcesses = @(Get-GpuProcessSummary)
    TopCpuProcesses = $topCpuProcesses
    TopMemoryProcesses = $topMemoryProcesses
    OutputPath = $targetPath
    LaunchesGame = $false
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $targetPath -Encoding UTF8
$result
