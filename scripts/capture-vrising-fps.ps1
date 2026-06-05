param(
    [string]$OutputPath,
    [string]$SummaryPath,
    [string]$ArtifactLabel,
    [string]$Root,
    [string]$ProcessName = "VRising.exe",
    [int]$ProcessId = 0,
    [int]$Seconds = 30,
    [int]$DelaySeconds = 0,
    [int]$MetricsIntervalMs = 1000,
    [string]$PresentMonPath = "C:\Software\PresentMon\PresentMon-2.4.1-x64.exe",
    [string]$NvidiaSmiPath = "nvidia-smi.exe",
    [string]$MetricsPath,
    [switch]$SkipSystemMetrics,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($Seconds -lt 3) {
    throw "Seconds must be at least 3."
}

if ($DelaySeconds -lt 0) {
    throw "DelaySeconds cannot be negative."
}

if ($ProcessId -lt 0) {
    throw "ProcessId cannot be negative."
}

if ($MetricsIntervalMs -lt 250) {
    throw "MetricsIntervalMs must be at least 250."
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$artifactRoot = Join-Path $resolvedRoot "artifacts\fps-validation"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ArtifactLabel)) {
    $ArtifactLabel = "vrising-fps-$timestamp"
} else {
    $ArtifactLabel = $ArtifactLabel -replace "[^A-Za-z0-9_.-]", "-"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $artifactRoot "$ArtifactLabel.csv"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $resolvedRoot $OutputPath
}

if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
    $SummaryPath = Join-Path $artifactRoot "$ArtifactLabel.txt"
} elseif (-not [System.IO.Path]::IsPathRooted($SummaryPath)) {
    $SummaryPath = Join-Path $resolvedRoot $SummaryPath
}

if ([string]::IsNullOrWhiteSpace($MetricsPath)) {
    $MetricsPath = Join-Path $artifactRoot "$ArtifactLabel.metrics.csv"
} elseif (-not [System.IO.Path]::IsPathRooted($MetricsPath)) {
    $MetricsPath = Join-Path $resolvedRoot $MetricsPath
}

$targetPath = [System.IO.Path]::GetFullPath($OutputPath)
$summaryTargetPath = [System.IO.Path]::GetFullPath($SummaryPath)
$metricsTargetPath = [System.IO.Path]::GetFullPath($MetricsPath)
$presentMonResolved = [System.IO.Path]::GetFullPath($PresentMonPath)
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
    Mode = $(if ($DryRun) { "DryRun" } else { "CaptureFPS" })
    ProcessName = $(if ($ProcessId -gt 0) { "" } else { $ProcessName })
    ProcessId = $ProcessId
    Seconds = $Seconds
    DelaySeconds = $DelaySeconds
    MetricsIntervalMs = $MetricsIntervalMs
    PresentMonPath = $presentMonResolved
    NvidiaSmiPath = $nvidiaSmiResolved
    CsvPath = $targetPath
    MetricsPath = $(if ($SkipSystemMetrics) { "" } else { $metricsTargetPath })
    SummaryPath = $summaryTargetPath
    CapturesSystemMetrics = -not [bool]$SkipSystemMetrics
    LaunchesGame = $false
}

if ($DryRun) {
    $plan
    return
}

if (-not (Test-Path -LiteralPath $presentMonResolved)) {
    throw "PresentMon executable was not found: $presentMonResolved"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath), (Split-Path -Parent $summaryTargetPath), (Split-Path -Parent $metricsTargetPath) | Out-Null

$arguments = New-Object System.Collections.Generic.List[string]
if ($ProcessId -gt 0) {
    $arguments.Add("--process_id")
    $arguments.Add($ProcessId.ToString([Globalization.CultureInfo]::InvariantCulture))
} else {
    if ([string]::IsNullOrWhiteSpace($ProcessName)) {
        throw "ProcessName is required when ProcessId is not provided."
    }
    $arguments.Add("--process_name")
    $arguments.Add($ProcessName)
}
$arguments.Add("--output_file")
$arguments.Add($targetPath)
$arguments.Add("--timed")
$arguments.Add($Seconds.ToString([Globalization.CultureInfo]::InvariantCulture))
$arguments.Add("--terminate_after_timed")
$arguments.Add("--stop_existing_session")
$arguments.Add("--no_console_stats")
if ($DelaySeconds -gt 0) {
    $arguments.Add("--delay")
    $arguments.Add($DelaySeconds.ToString([Globalization.CultureInfo]::InvariantCulture))
}

$logicalProcessorCount = [Environment]::ProcessorCount
$metricsJob = $null
if (-not $SkipSystemMetrics) {
    $metricsJob = Start-Job -ScriptBlock {
        param(
            [string]$JobProcessName,
            [int]$JobProcessId,
            [int]$JobSeconds,
            [int]$JobDelaySeconds,
            [int]$JobIntervalMs,
            [string]$JobNvidiaSmiPath,
            [string]$JobMetricsPath,
            [int]$JobLogicalProcessorCount
        )

        $ErrorActionPreference = "SilentlyContinue"
        $rows = New-Object System.Collections.Generic.List[object]
        if ($JobDelaySeconds -gt 0) {
            Start-Sleep -Seconds $JobDelaySeconds
        }

        $processLookupName = $JobProcessName
        if ($processLookupName.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase)) {
            $processLookupName = [System.IO.Path]::GetFileNameWithoutExtension($processLookupName)
        }

        $lastCpuSeconds = $null
        $lastTimestamp = $null
        $endTime = (Get-Date).AddSeconds($JobSeconds)

        while ((Get-Date) -lt $endTime) {
            $now = Get-Date
            $process = $null
            if ($JobProcessId -gt 0) {
                $process = Get-Process -Id $JobProcessId -ErrorAction SilentlyContinue
            } elseif (-not [string]::IsNullOrWhiteSpace($processLookupName)) {
                $process = Get-Process -Name $processLookupName -ErrorAction SilentlyContinue |
                    Sort-Object StartTime -Descending |
                    Select-Object -First 1
            }

            $processIdValue = ""
            $processCpuPercent = ""
            $workingSetMb = ""
            $privateMb = ""
            if ($process) {
                $processIdValue = $process.Id
                $workingSetMb = [Math]::Round($process.WorkingSet64 / 1MB, 1)
                $privateMb = [Math]::Round($process.PrivateMemorySize64 / 1MB, 1)

                $cpuSeconds = $process.TotalProcessorTime.TotalSeconds
                if ($null -ne $lastCpuSeconds -and $null -ne $lastTimestamp) {
                    $elapsed = ($now - $lastTimestamp).TotalSeconds
                    if ($elapsed -gt 0 -and $JobLogicalProcessorCount -gt 0) {
                        $processCpuPercent = [Math]::Round((($cpuSeconds - $lastCpuSeconds) / $elapsed) / $JobLogicalProcessorCount * 100.0, 3)
                    }
                }

                $lastCpuSeconds = $cpuSeconds
                $lastTimestamp = $now
            }

            $gpuUtilPercent = ""
            $gpuMemoryUtilPercent = ""
            $gpuMemoryUsedMb = ""
            $gpuMemoryTotalMb = ""
            $gpuPowerW = ""
            $gpuTemperatureC = ""
            if (-not [string]::IsNullOrWhiteSpace($JobNvidiaSmiPath) -and (Test-Path -LiteralPath $JobNvidiaSmiPath)) {
                $gpuLine = & $JobNvidiaSmiPath --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,temperature.gpu --format=csv,noheader,nounits 2>$null |
                    Select-Object -First 1
                if (-not [string]::IsNullOrWhiteSpace($gpuLine)) {
                    $parts = @($gpuLine -split "," | ForEach-Object { $_.Trim() })
                    if ($parts.Count -ge 6) {
                        $gpuUtilPercent = $parts[0]
                        $gpuMemoryUtilPercent = $parts[1]
                        $gpuMemoryUsedMb = $parts[2]
                        $gpuMemoryTotalMb = $parts[3]
                        $gpuPowerW = $parts[4]
                        $gpuTemperatureC = $parts[5]
                    }
                }
            }

            $rows.Add([pscustomobject]@{
                Timestamp = $now.ToString("o")
                ProcessId = $processIdValue
                ProcessCpuPercent = $processCpuPercent
                ProcessWorkingSetMb = $workingSetMb
                ProcessPrivateMb = $privateMb
                GpuUtilPercent = $gpuUtilPercent
                GpuMemoryUtilPercent = $gpuMemoryUtilPercent
                GpuMemoryUsedMb = $gpuMemoryUsedMb
                GpuMemoryTotalMb = $gpuMemoryTotalMb
                GpuPowerW = $gpuPowerW
                GpuTemperatureC = $gpuTemperatureC
            })

            Start-Sleep -Milliseconds $JobIntervalMs
        }

        $rows | Export-Csv -LiteralPath $JobMetricsPath -NoTypeInformation -Encoding UTF8
    } -ArgumentList $ProcessName, $ProcessId, $Seconds, $DelaySeconds, $MetricsIntervalMs, $nvidiaSmiResolved, $metricsTargetPath, $logicalProcessorCount
}

& $presentMonResolved @arguments | Out-Host
try {
    if ($LASTEXITCODE -ne 0) {
        throw "PresentMon exited with code $LASTEXITCODE."
    }
} finally {
    if ($metricsJob) {
        Wait-Job -Job $metricsJob | Out-Null
        Receive-Job -Job $metricsJob | Out-Null
        Remove-Job -Job $metricsJob -Force
    }
}

if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "PresentMon did not create a CSV file: $targetPath"
}

$culture = [Globalization.CultureInfo]::InvariantCulture

function Convert-NullableDouble {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq "NA") {
        return $null
    }

    return [double]::Parse($Value, $culture)
}

function Get-Percentile {
    param(
        [double[]]$Values,
        [double]$Percentile
    )

    if (-not $Values -or $Values.Count -eq 0) {
        return $null
    }

    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 1) {
        return $sorted[0]
    }

    $rank = ($sorted.Count - 1) * $Percentile
    $lower = [int][Math]::Floor($rank)
    $upper = [int][Math]::Ceiling($rank)
    if ($lower -eq $upper) {
        return $sorted[$lower]
    }

    $weight = $rank - $lower
    return ($sorted[$lower] * (1.0 - $weight)) + ($sorted[$upper] * $weight)
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

$rows = @(Import-Csv -LiteralPath $targetPath)
$frameTimes = New-Object System.Collections.Generic.List[double]
$gpuTimes = New-Object System.Collections.Generic.List[double]
$presentModes = @{}
$runtimeNames = @{}
$processIds = @{}

foreach ($row in $rows) {
    $frameTime = Convert-NullableDouble -Value $row.MsBetweenPresents
    if ($null -ne $frameTime -and $frameTime -gt 0) {
        $frameTimes.Add($frameTime)
    }

    $gpuTime = Convert-NullableDouble -Value $row.MsGPUTime
    if ($null -ne $gpuTime -and $gpuTime -gt 0) {
        $gpuTimes.Add($gpuTime)
    }

    if (-not [string]::IsNullOrWhiteSpace($row.PresentMode)) {
        $presentModes[$row.PresentMode] = 1 + [int]($presentModes[$row.PresentMode])
    }
    if (-not [string]::IsNullOrWhiteSpace($row.PresentRuntime)) {
        $runtimeNames[$row.PresentRuntime] = 1 + [int]($runtimeNames[$row.PresentRuntime])
    }
    if (-not [string]::IsNullOrWhiteSpace($row.ProcessID)) {
        $processIds[$row.ProcessID] = 1 + [int]($processIds[$row.ProcessID])
    }
}

if ($frameTimes.Count -eq 0) {
    throw "PresentMon CSV did not contain usable MsBetweenPresents samples."
}

$frameTimeArray = $frameTimes.ToArray()
$averageFrameMs = ($frameTimeArray | Measure-Object -Average).Average
$p50FrameMs = Get-Percentile -Values $frameTimes.ToArray() -Percentile 0.50
$p95FrameMs = Get-Percentile -Values $frameTimes.ToArray() -Percentile 0.95
$p99FrameMs = Get-Percentile -Values $frameTimes.ToArray() -Percentile 0.99
$minFrameMs = ($frameTimeArray | Measure-Object -Minimum).Minimum
$maxFrameMs = ($frameTimeArray | Measure-Object -Maximum).Maximum

$gpuTimeArray = $gpuTimes.ToArray()
$averageGpuMs = if ($gpuTimes.Count -gt 0) { ($gpuTimeArray | Measure-Object -Average).Average } else { $null }
$p95GpuMs = if ($gpuTimes.Count -gt 0) { Get-Percentile -Values $gpuTimes.ToArray() -Percentile 0.95 } else { $null }

$metricRows = @()
$cpuValues = New-Object System.Collections.Generic.List[double]
$workingSetValues = New-Object System.Collections.Generic.List[double]
$privateValues = New-Object System.Collections.Generic.List[double]
$gpuUtilValues = New-Object System.Collections.Generic.List[double]
$gpuMemoryUsedValues = New-Object System.Collections.Generic.List[double]
$gpuPowerValues = New-Object System.Collections.Generic.List[double]
$gpuTemperatureValues = New-Object System.Collections.Generic.List[double]

if (-not $SkipSystemMetrics -and (Test-Path -LiteralPath $metricsTargetPath)) {
    $metricRows = @(Import-Csv -LiteralPath $metricsTargetPath)
    foreach ($row in $metricRows) {
        $value = Convert-NullableDouble -Value $row.ProcessCpuPercent
        if ($null -ne $value) {
            $cpuValues.Add($value)
        }
        $value = Convert-NullableDouble -Value $row.ProcessWorkingSetMb
        if ($null -ne $value) {
            $workingSetValues.Add($value)
        }
        $value = Convert-NullableDouble -Value $row.ProcessPrivateMb
        if ($null -ne $value) {
            $privateValues.Add($value)
        }
        $value = Convert-NullableDouble -Value $row.GpuUtilPercent
        if ($null -ne $value) {
            $gpuUtilValues.Add($value)
        }
        $value = Convert-NullableDouble -Value $row.GpuMemoryUsedMb
        if ($null -ne $value) {
            $gpuMemoryUsedValues.Add($value)
        }
        $value = Convert-NullableDouble -Value $row.GpuPowerW
        if ($null -ne $value) {
            $gpuPowerValues.Add($value)
        }
        $value = Convert-NullableDouble -Value $row.GpuTemperatureC
        if ($null -ne $value) {
            $gpuTemperatureValues.Add($value)
        }
    }
}

$result = [pscustomobject]@{
    Mode = "CapturedFPS"
    CsvPath = $targetPath
    MetricsPath = $(if (-not $SkipSystemMetrics -and (Test-Path -LiteralPath $metricsTargetPath)) { $metricsTargetPath } else { "" })
    SummaryPath = $summaryTargetPath
    PresentMonPath = $presentMonResolved
    NvidiaSmiPath = $nvidiaSmiResolved
    RequestedSeconds = $Seconds
    DelaySeconds = $DelaySeconds
    MetricsIntervalMs = $MetricsIntervalMs
    RowCount = $rows.Count
    FrameCount = $frameTimes.Count
    MetricsSampleCount = $metricRows.Count
    ProcessIds = ($processIds.Keys | Sort-Object) -join ","
    PresentRuntimes = ($runtimeNames.Keys | Sort-Object) -join ","
    PresentModes = ($presentModes.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join "; "
    AverageFrameMs = Round-Nullable -Value $averageFrameMs
    P50FrameMs = Round-Nullable -Value $p50FrameMs
    P95FrameMs = Round-Nullable -Value $p95FrameMs
    P99FrameMs = Round-Nullable -Value $p99FrameMs
    MinFrameMs = Round-Nullable -Value $minFrameMs
    MaxFrameMs = Round-Nullable -Value $maxFrameMs
    AverageFps = Round-Nullable -Value (1000.0 / $averageFrameMs)
    P50Fps = Round-Nullable -Value (1000.0 / $p50FrameMs)
    FivePercentLowFps = Round-Nullable -Value (1000.0 / $p95FrameMs)
    OnePercentLowFps = Round-Nullable -Value (1000.0 / $p99FrameMs)
    AverageGpuMs = Round-Nullable -Value $averageGpuMs
    P95GpuMs = Round-Nullable -Value $p95GpuMs
    AverageProcessCpuPercent = $(if ($cpuValues.Count -gt 0) { Round-Nullable -Value (($cpuValues.ToArray() | Measure-Object -Average).Average) } else { $null })
    P95ProcessCpuPercent = $(if ($cpuValues.Count -gt 0) { Round-Nullable -Value (Get-Percentile -Values $cpuValues.ToArray() -Percentile 0.95) } else { $null })
    AverageWorkingSetMb = $(if ($workingSetValues.Count -gt 0) { Round-Nullable -Value (($workingSetValues.ToArray() | Measure-Object -Average).Average) } else { $null })
    MaxWorkingSetMb = $(if ($workingSetValues.Count -gt 0) { Round-Nullable -Value (($workingSetValues.ToArray() | Measure-Object -Maximum).Maximum) } else { $null })
    AveragePrivateMb = $(if ($privateValues.Count -gt 0) { Round-Nullable -Value (($privateValues.ToArray() | Measure-Object -Average).Average) } else { $null })
    AverageGpuUtilPercent = $(if ($gpuUtilValues.Count -gt 0) { Round-Nullable -Value (($gpuUtilValues.ToArray() | Measure-Object -Average).Average) } else { $null })
    P95GpuUtilPercent = $(if ($gpuUtilValues.Count -gt 0) { Round-Nullable -Value (Get-Percentile -Values $gpuUtilValues.ToArray() -Percentile 0.95) } else { $null })
    AverageGpuMemoryUsedMb = $(if ($gpuMemoryUsedValues.Count -gt 0) { Round-Nullable -Value (($gpuMemoryUsedValues.ToArray() | Measure-Object -Average).Average) } else { $null })
    MaxGpuMemoryUsedMb = $(if ($gpuMemoryUsedValues.Count -gt 0) { Round-Nullable -Value (($gpuMemoryUsedValues.ToArray() | Measure-Object -Maximum).Maximum) } else { $null })
    AverageGpuPowerW = $(if ($gpuPowerValues.Count -gt 0) { Round-Nullable -Value (($gpuPowerValues.ToArray() | Measure-Object -Average).Average) } else { $null })
    AverageGpuTemperatureC = $(if ($gpuTemperatureValues.Count -gt 0) { Round-Nullable -Value (($gpuTemperatureValues.ToArray() | Measure-Object -Average).Average) } else { $null })
    LaunchesGame = $false
}

$result | Format-List | Out-String -Width 220 | Set-Content -LiteralPath $summaryTargetPath -Encoding UTF8
$result
