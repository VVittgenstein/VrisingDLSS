param(
    [string]$GamePath,
    [string]$LogPath,
    [switch]$FailOnProblems
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    if ([string]::IsNullOrWhiteSpace($GamePath)) {
        throw "Pass -GamePath or -LogPath."
    }

    $LogPath = Join-Path $GamePath "BepInEx\LogOutput.log"
}

if (-not (Test-Path -LiteralPath $LogPath)) {
    $result = [pscustomobject]@{
        Stage = "Log"
        Status = "Missing"
        Evidence = "Log file not found: $LogPath"
    }
    $result
    if ($FailOnProblems) {
        exit 1
    }
    return
}

$logText = Get-Content -LiteralPath $LogPath -Raw

function Test-ContainsAny {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }

    return $false
}

function Get-FirstMatchingLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($line in ($Text -split "`r?`n")) {
        foreach ($pattern in $Patterns) {
            if ($line.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                return $line.Trim()
            }
        }
    }

    return ""
}

function New-StageResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $true)]
        [string[]]$PassPatterns,

        [string[]]$FailPatterns = @(),
        [string[]]$BlockedPatterns = @(),
        [string[]]$StartedPatterns = @()
    )

    $allFailPatterns = @($FailPatterns)
    if ($allFailPatterns.Count -gt 0 -and (Test-ContainsAny -Text $logText -Patterns $allFailPatterns)) {
        return [pscustomobject]@{
            Stage = $Stage
            Status = "Fail"
            Evidence = Get-FirstMatchingLine -Text $logText -Patterns $allFailPatterns
        }
    }

    $allBlockedPatterns = @($BlockedPatterns)
    if ($allBlockedPatterns.Count -gt 0 -and (Test-ContainsAny -Text $logText -Patterns $allBlockedPatterns)) {
        return [pscustomObject]@{
            Stage = $Stage
            Status = "Blocked"
            Evidence = Get-FirstMatchingLine -Text $logText -Patterns $allBlockedPatterns
        }
    }

    if (Test-ContainsAny -Text $logText -Patterns @($PassPatterns)) {
        return [pscustomobject]@{
            Stage = $Stage
            Status = "Pass"
            Evidence = Get-FirstMatchingLine -Text $logText -Patterns @($PassPatterns)
        }
    }

    if ($StartedPatterns.Count -gt 0 -and (Test-ContainsAny -Text $logText -Patterns $StartedPatterns)) {
        return [pscustomobject]@{
            Stage = $Stage
            Status = "Partial"
            Evidence = Get-FirstMatchingLine -Text $logText -Patterns $StartedPatterns
        }
    }

    [pscustomobject]@{
        Stage = $Stage
        Status = "Missing"
        Evidence = "No matching evidence in $LogPath"
    }
}

$results = New-Object System.Collections.Generic.List[object]

$results.Add((New-StageResult `
    -Stage "Stage 1 Loader" `
    -PassPatterns @("VrisingDLSS 0.1.0 loaded.") `
    -FailPatterns @("Plugin disabled by configuration.", "Could not load [VrisingDLSS", "Exception while loading [VrisingDLSS")))

$results.Add((New-StageResult `
    -Stage "Stage 2 Hook Probe" `
    -PassPatterns @("Hook target type found: UnityEngine.Rendering.HighDefinition.CustomVignette", "Hook target type found: CustomVignette") `
    -FailPatterns @("Hook target type not found: UnityEngine.Rendering.HighDefinition.CustomVignette") `
    -StartedPatterns @("Running read-only HDRP hook probe.")))

$results.Add((New-StageResult `
    -Stage "Stage 2B Upscaler State Probe" `
    -PassPatterns @("Upscaler state probe snapshot:", "Upscaler state probe call #") `
    -FailPatterns @("Upscaler state probe failed", "Upscaler state probe postfix failed", "Upscaler state probe snapshot failed") `
    -StartedPatterns @("Running read-only HDRP upscaler state probe.", "Upscaler state probe patched")))

$results.Add((New-StageResult `
    -Stage "Stage 2C Render-Scale Control Probe" `
    -PassPatterns @("Render-scale control prefix #", "Render-scale control postfix #") `
    -FailPatterns @("Render-scale control failed to patch", "Render-scale control prefix failed", "Render-scale control postfix failed") `
    -StartedPatterns @("Render-scale control probe patched", "Render-scale control patched:")))

$results.Add((New-StageResult `
    -Stage "Stage 3 Harmony Call Probe" `
    -PassPatterns @("Harmony probe call #") `
    -FailPatterns @("Harmony runtime was not found", "Harmony runtime shape was not recognized", "Harmony probe failed to patch") `
    -StartedPatterns @("Read-only Harmony call probe patched", "Harmony probe patched:")))

$results.Add((New-StageResult `
    -Stage "Stage 4 Native Bridge" `
    -PassPatterns @("Native bridge API version:") `
    -FailPatterns @("Native bridge not loaded:", "Native bridge export missing:") `
    -StartedPatterns @("Native bridge version:", "Native bridge diagnostic status:")))

$results.Add((New-StageResult `
    -Stage "Stage 5A Render Thread" `
    -PassPatterns @("Native render-thread smoke test event reached the native callback") `
    -FailPatterns @("native render-thread smoke test failed", "Native render-thread smoke test callback did not advance") `
    -StartedPatterns @("Running native render-thread smoke test")))

$results.Add((New-StageResult `
    -Stage "Stage 5B D3D11 Texture" `
    -PassPatterns @("D3D11 texture pointer probe succeeded:") `
    -FailPatterns @("D3D11 texture pointer probe failed:", "Temporary RenderTexture returned a null native pointer") `
    -StartedPatterns @("Running D3D11 texture pointer probe.")))

$results.Add((New-StageResult `
    -Stage "Stage 5C Frame Resources" `
    -PassPatterns @("Frame resource arg", "Frame resource global:_CameraDepthTexture", "Frame resource global:_CameraMotionVectorsTexture") `
    -FailPatterns @("Frame resource probe target type not found", "Frame resource probe failed to patch", "Frame resource probe prefix failed") `
    -StartedPatterns @("Frame resource probe patched", "Frame resource probe call #")))

$results.Add((New-StageResult `
    -Stage "RenderGraph Pass Boundary" `
    -PassPatterns @("RenderGraph pass boundary #") `
    -FailPatterns @("RenderGraph pass-boundary logging failed", "Frame resource RenderGraph execution scope failed to patch") `
    -StartedPatterns @("RenderGraph pass-boundary probe enabled", "Frame resource RenderGraph execution scope patched")))

$results.Add((New-StageResult `
    -Stage "RenderGraph Pass Map" `
    -PassPatterns @("RenderGraph pass map #") `
    -FailPatterns @("RenderGraph pass-map logging failed", "RenderGraph pass-map failed to patch") `
    -StartedPatterns @("RenderGraph pass-map probe enabled", "RenderGraph pass-map patched")))

$results.Add((New-StageResult `
    -Stage "RenderGraph Pass List" `
    -PassPatterns @("RenderGraph pass-list entry #", "RenderGraph pass-list compile #") `
    -FailPatterns @("RenderGraph pass-list logging failed", "RenderGraph pass-list failed to patch", "RenderGraph pass-list target was not found") `
    -StartedPatterns @("RenderGraph pass-list probe enabled", "RenderGraph pass-list patched")))

$results.Add((New-StageResult `
    -Stage "RenderGraph Pass Declarations" `
    -PassPatterns @("RenderGraph pass declaration #") `
    -FailPatterns @("RenderGraph pass-list logging failed", "RenderGraph pass-list failed to patch", "RenderGraph pass-list target was not found") `
    -StartedPatterns @("RenderGraph pass resource-declaration probe enabled", "RenderGraph pass-list patched")))

$results.Add((New-StageResult `
    -Stage "RenderGraph Pass Data" `
    -PassPatterns @("RenderGraph pass-data snapshot #") `
    -FailPatterns @("RenderGraph pass-list logging failed", "RenderGraph pass-list failed to patch", "RenderGraph pass-list target was not found", "RenderGraph pass-data snapshot data=not found") `
    -StartedPatterns @("RenderGraph pass-data snapshot probe enabled", "RenderGraph pass-list patched")))

$results.Add((New-StageResult `
    -Stage "RenderGraph RenderFunc Metadata" `
    -PassPatterns @("RenderGraph pass render-func metadata #") `
    -FailPatterns @("RenderGraph pass-list logging failed", "RenderGraph pass-list failed to patch", "RenderGraph pass-list target was not found", "RenderGraph pass render-func metadata renderFunc=not found", "RenderGraph pass render-func metadata typed read failed") `
    -StartedPatterns @("RenderGraph pass render-func metadata probe enabled", "RenderGraph pass-list patched")))

$results.Add((New-StageResult `
    -Stage "RenderGraph Compiled Pass Info" `
    -PassPatterns @("RenderGraph compiled-pass-info #") `
    -FailPatterns @("RenderGraph pass-list logging failed", "RenderGraph pass-list failed to patch", "RenderGraph pass-list target was not found", "compiledPassInfos=not found") `
    -StartedPatterns @("RenderGraph compiled-pass-info probe enabled", "RenderGraph pass-list patched")))

$results.Add((New-StageResult `
    -Stage "RenderGraph Execute Delegate" `
    -PassPatterns @("RenderGraph execute-delegate #") `
    -FailPatterns @("RenderGraph execute-delegate logging failed", "RenderGraph execute-delegate failed to patch", "RenderGraph execute-delegate target was not found", "RenderGraph execute-delegate pass=not found", "RenderGraph execute-delegate data=not found") `
    -StartedPatterns @("RenderGraph execute-delegate probe enabled", "RenderGraph execute-delegate probe patched")))

$results.Add((New-StageResult `
    -Stage "Stage 5D DLSS Runtime" `
    -PassPatterns @("DLSS runtime probe succeeded:") `
    -FailPatterns @("DLSS runtime probe failed:", "DLSS runtime probe skipped:") `
    -StartedPatterns @("DLSS runtime probe loaded and released runtime")))

$results.Add((New-StageResult `
    -Stage "Stage 6 DLSS Init/Query" `
    -PassPatterns @("DLSS init/query probe succeeded:") `
    -FailPatterns @("DLSS init/query probe failed:", "DLSS init/query probe skipped:") `
    -BlockedPatterns @("DLSS init/query probe blocked:") `
    -StartedPatterns @("Running DLSS init/query probe.")))

$results.Add((New-StageResult `
    -Stage "Stage 6B DLSS Optimal Settings" `
    -PassPatterns @("DLSS optimal-settings probe succeeded:") `
    -FailPatterns @("DLSS optimal-settings probe failed:", "DLSS optimal-settings probe skipped:") `
    -BlockedPatterns @("DLSS optimal-settings probe blocked:") `
    -StartedPatterns @("Running DLSS optimal-settings probe")))

$results.Add((New-StageResult `
    -Stage "Stage 7 DLSS Feature Create" `
    -PassPatterns @("DLSS feature create probe succeeded:") `
    -FailPatterns @("DLSS feature create probe failed:", "DLSS feature create probe skipped:") `
    -BlockedPatterns @("DLSS feature create probe blocked:") `
    -StartedPatterns @("Running DLSS feature create/release probe.")))

$results.Add((New-StageResult `
    -Stage "Stage 8A DLSS Evaluate Inputs" `
    -PassPatterns @("DLSS evaluate input probe succeeded:", "DLSS evaluate input probe succeeded from RenderGraph diagnostic pass:", "DLSS evaluate input probe succeeded from existing HDRP render-func:", "DLSS evaluate input probe succeeded from RenderGraph materialization:", "DLSS evaluate input probe succeeded from RenderGraph GetTexture:", "DLSS evaluate input probe succeeded from DLSSPass resource helper:") `
    -FailPatterns @("DLSS evaluate input probe failed:", "DLSS evaluate input probe failed from existing HDRP render-func:", "DLSS evaluate input probe failed from RenderGraph materialization:", "DLSS evaluate input probe failed from RenderGraph GetTexture:", "DLSS evaluate input probe failed from DLSSPass resource helper:") `
    -BlockedPatterns @("DLSS evaluate input probe blocked:") `
    -StartedPatterns @("DLSS evaluate input probe enabled.", "RenderGraph diagnostic pass injected", "RenderGraph diagnostic pass configured", "Frame resource existing HDRP render-func probe patched", "Existing HDRP render-func scope", "RenderGraph resource materialization probe enabled.", "Frame resource RenderGraph materialization probe patched", "RenderGraph texture materialization #", "DLSSPass resource helper probe", "DLSSPass resource helper #")))

$results.Add((New-StageResult `
    -Stage "Stage 8B DLSS Evaluate" `
    -PassPatterns @("DLSS evaluate probe succeeded:", "DLSS evaluate probe succeeded from") `
    -FailPatterns @("DLSS evaluate probe failed:", "DLSS evaluate probe failed from", "DLSS evaluate probe skipped:", "DLSS evaluate probe skipped from") `
    -BlockedPatterns @("DLSS evaluate probe blocked:", "DLSS evaluate probe blocked from") `
    -StartedPatterns @("DLSS evaluate probe enabled.", "DLSS evaluate probe candidate #")))

$results.Add((New-StageResult `
    -Stage "Stage 8C DLSS Output Follow-up" `
    -PassPatterns @("DLSS evaluate output follow-up #") `
    -FailPatterns @("DLSS evaluate output follow-up failed #") `
    -StartedPatterns @("DLSS evaluate probe succeeded:", "DLSS evaluate probe succeeded from")))

$results.Add((New-StageResult `
    -Stage "Stage 8D DLSS Persistent Evaluate" `
    -PassPatterns @("DLSS persistent evaluate probe succeeded:", "DLSS persistent evaluate probe succeeded from") `
    -FailPatterns @("DLSS persistent evaluate probe failed:", "DLSS persistent evaluate probe failed from", "DLSS persistent evaluate probe skipped:", "DLSS persistent evaluate probe skipped from") `
    -BlockedPatterns @("DLSS persistent evaluate probe blocked:", "DLSS persistent evaluate probe blocked from") `
    -StartedPatterns @("DLSS persistent evaluate probe enabled.", "DLSS persistent evaluate probe candidate #")))

$results.Add((New-StageResult `
    -Stage "Stage 8E DLSS Super Resolution Inputs" `
    -PassPatterns @("DLSS super-resolution input probe succeeded:", "DLSS super-resolution input probe succeeded from") `
    -FailPatterns @("DLSS super-resolution input probe failed:", "DLSS super-resolution input probe failed from") `
    -BlockedPatterns @("DLSS super-resolution input probe blocked:", "DLSS super-resolution input probe blocked from") `
    -StartedPatterns @("DLSS super-resolution input probe enabled.", "DLSS super-resolution input probe candidate #", "DLSS super-resolution input probe not accepted from")))

$results.Add((New-StageResult `
    -Stage "Stage 8F DLSS Super Resolution Evaluate" `
    -PassPatterns @("DLSS super-resolution evaluate probe succeeded:", "DLSS super-resolution evaluate probe succeeded from") `
    -FailPatterns @("DLSS super-resolution evaluate probe failed:", "DLSS super-resolution evaluate probe failed from", "DLSS super-resolution evaluate probe skipped:", "DLSS super-resolution evaluate probe skipped from") `
    -BlockedPatterns @("DLSS super-resolution evaluate probe blocked:", "DLSS super-resolution evaluate probe blocked from") `
    -StartedPatterns @("DLSS super-resolution evaluate probe enabled.", "DLSS super-resolution evaluate probe candidate #")))

$results.Add((New-StageResult `
    -Stage "Stage 8G DLSS Super Resolution Persistent Evaluate" `
    -PassPatterns @("DLSS super-resolution persistent evaluate probe succeeded:", "DLSS super-resolution persistent evaluate probe succeeded from") `
    -FailPatterns @("DLSS super-resolution persistent evaluate probe failed:", "DLSS super-resolution persistent evaluate probe failed from", "DLSS super-resolution persistent evaluate probe skipped:", "DLSS super-resolution persistent evaluate probe skipped from") `
    -BlockedPatterns @("DLSS super-resolution persistent evaluate probe blocked:", "DLSS super-resolution persistent evaluate probe blocked from") `
    -StartedPatterns @("DLSS super-resolution persistent evaluate probe enabled.", "DLSS super-resolution persistent evaluate probe candidate #")))

$results.Add((New-StageResult `
    -Stage "Stage 9A DLSS Super Resolution Frame Sequence Evaluate" `
    -PassPatterns @("DLSS super-resolution frame-sequence evaluate probe succeeded:", "DLSS super-resolution frame-sequence evaluate probe succeeded from") `
    -FailPatterns @("DLSS super-resolution frame-sequence evaluate probe failed:", "DLSS super-resolution frame-sequence evaluate probe failed from", "DLSS super-resolution frame-sequence evaluate probe skipped:", "DLSS super-resolution frame-sequence evaluate probe skipped from", "DLSS super-resolution frame-sequence shutdown failed:") `
    -BlockedPatterns @("DLSS super-resolution frame-sequence evaluate probe blocked:", "DLSS super-resolution frame-sequence evaluate probe blocked from") `
    -StartedPatterns @("DLSS super-resolution frame-sequence evaluate probe enabled.", "DLSS super-resolution frame-sequence evaluate probe candidate #")))

$results.Add((New-StageResult `
    -Stage "Stage 10A DLSS Visible Write-back" `
    -PassPatterns @("DLSS visible write-back probe succeeded:", "DLSS visible write-back probe succeeded from") `
    -FailPatterns @("DLSS visible write-back probe failed:", "DLSS visible write-back probe failed from", "DLSS visible write-back probe skipped:", "DLSS visible write-back probe skipped from", "DLSS visible write-back shutdown failed:") `
    -BlockedPatterns @("DLSS visible write-back probe blocked:", "DLSS visible write-back probe blocked from") `
    -StartedPatterns @("DLSS visible write-back probe enabled.", "DLSS visible write-back probe candidate #")))

$results.Add((New-StageResult `
    -Stage "DLSS User Rendering Candidate" `
    -PassPatterns @("DLSS user rendering evaluate succeeded from", "DLSS user rendering no-evaluate accepted from") `
    -FailPatterns @("DLSS user rendering evaluate failed from", "DLSS user rendering evaluate skipped from", "DLSS user rendering shutdown failed:") `
    -BlockedPatterns @("DLSS user rendering evaluate blocked from") `
    -StartedPatterns @("DLSS user rendering candidate enabled.", "DLSS user rendering no-evaluate diagnostic enabled.", "DLSS cached tuple driver diagnostic enabled.", "DLSS cached tuple driver no-evaluate diagnostic enabled.", "DLSS cached tuple driver armed from", "DLSS user rendering candidate #", "DLSS cached tuple driver invoked from")))

$results

if ($FailOnProblems) {
    $problem = $results | Where-Object { $_.Status -in @("Fail", "Blocked", "Partial", "Missing") } | Select-Object -First 1
    if ($problem) {
        exit 1
    }
}
