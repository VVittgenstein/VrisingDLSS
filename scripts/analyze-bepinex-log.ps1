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
    -Stage "HDRP DLSS Schedule Audit" `
    -PassPatterns @("RenderGraph pass-list compile #", "Upscaler state probe snapshot", "Upscaler state probe call #") `
    -FailPatterns @("RenderGraph pass-list logging failed", "RenderGraph pass-list failed to patch", "RenderGraph pass-list target was not found", "DLSS user rendering evaluate succeeded from", "Native render-func command-buffer DLSS user-rendering") `
    -StartedPatterns @("RenderGraph pass-list probe enabled", "RenderGraph pass-data snapshot probe enabled", "RenderGraph pass render-func metadata probe enabled", "RenderGraph compiled-pass-info probe enabled", "Upscaler state probe snapshot")))

$results.Add((New-StageResult `
    -Stage "HDRP DLSS Schedule Gate" `
    -PassPatterns @("HDRP DLSS schedule-gate prefix:", "HDRP DLSS schedule-gate postfix:", "HDRP DLSS schedule-gate probe patched") `
    -FailPatterns @("HDRP DLSS schedule-gate failed to patch", "HDRP DLSS schedule-gate prefix failed", "HDRP DLSS schedule-gate postfix failed", "HDRP DLSS schedule-gate member write did not stick", "DLSS user rendering evaluate succeeded from", "Native render-func command-buffer DLSS user-rendering", "RenderGraph GetTexture call #") `
    -StartedPatterns @("HDRP DLSS schedule-gate probe enabled", "HDRP DLSS schedule-gate patched:")))

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
    -Stage "Native RenderFunc Entry" `
    -PassPatterns @("Native render-func entry count advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:") `
    -StartedPatterns @("Native render-func entry no-op probe enabled", "Native render-func entry candidate observed", "Native render-func entry detour installed:", "Native render-func entry status #")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc Args" `
    -PassPatterns @("Native render-func argument sample advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:") `
    -StartedPatterns @("Native render-func argument preflight enabled", "Native render-func argument status #", "Native render-func entry detour installed:")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc Context" `
    -PassPatterns @("Native render-func context advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "RenderGraph pass-list logging failed") `
    -StartedPatterns @("Native render-func context preflight enabled", "Native render-func context status #", "Native render-func entry detour installed:")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer Event" `
    -PassPatterns @("Native render-func command-buffer event advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer event failed:", "RenderGraph pass-list logging failed") `
    -StartedPatterns @("Native render-func command-buffer event preflight enabled", "Native render-func command-buffer event status #")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer Payload" `
    -PassPatterns @("Native render-func command-buffer payload advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer payload set failed:", "Native render-func command-buffer payload event failed:", "render event texture payload set failed:", "render event texture payload consume failed:", "RenderGraph pass-list logging failed") `
    -StartedPatterns @("Native render-func command-buffer payload preflight enabled", "Native render-func command-buffer payload status #", "Native render-func command-buffer payload set advanced:")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer Frame Descriptor" `
    -PassPatterns @("Native render-func command-buffer frame descriptor advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer frame descriptor set failed:", "Native render-func command-buffer frame descriptor event failed:", "render event frame descriptor payload set failed:", "render event frame descriptor payload consume failed:", "RenderGraph pass-list logging failed") `
    -StartedPatterns @("Native render-func command-buffer frame-descriptor preflight enabled", "Native render-func command-buffer frame descriptor status #", "Native render-func command-buffer frame descriptor set advanced:")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer Frame Descriptor D3D11" `
    -PassPatterns @("Native render-func command-buffer frame descriptor D3D11 advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer frame descriptor D3D11 set failed:", "Native render-func command-buffer frame descriptor D3D11 event failed:", "render event frame descriptor payload set failed:", "render event frame descriptor payload consume failed:", "D3D11 validation failed:", "RenderGraph pass-list logging failed") `
    -StartedPatterns @("Native render-func command-buffer frame-descriptor D3D11 preflight enabled", "Native render-func command-buffer frame descriptor D3D11 status #", "Native render-func command-buffer frame descriptor D3D11 set advanced:")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer DLSS Scratch Evaluate" `
    -PassPatterns @("Native render-func command-buffer DLSS scratch evaluate advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer DLSS scratch evaluate set failed:", "Native render-func command-buffer DLSS scratch evaluate event failed:", "render event frame descriptor payload set failed:", "render event frame descriptor payload consume failed:", "DLSS scratch evaluate failed", "RenderGraph pass-list logging failed") `
    -BlockedPatterns @("DLSS scratch evaluate blocked", "native bridge was built without NVIDIA SDK wrapper integration", "runtime path was empty") `
    -StartedPatterns @("Native render-func command-buffer DLSS scratch-evaluate preflight enabled", "Native render-func command-buffer DLSS scratch evaluate status #", "Native render-func command-buffer DLSS scratch evaluate set advanced:", "render event frame descriptor DLSS scratch evaluate pending")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer DLSS Persistent Scratch Evaluate" `
    -PassPatterns @("Native render-func command-buffer DLSS persistent scratch evaluate advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer DLSS persistent scratch evaluate set failed:", "Native render-func command-buffer DLSS persistent scratch evaluate event failed:", "render event frame descriptor payload set failed:", "render event frame descriptor payload consume failed:", "DLSS persistent scratch evaluate failed", "RenderGraph pass-list logging failed") `
    -BlockedPatterns @("DLSS scratch evaluate blocked", "native bridge was built without NVIDIA SDK wrapper integration", "runtime path was empty") `
    -StartedPatterns @("Native render-func command-buffer DLSS persistent scratch-evaluate preflight enabled", "Native render-func command-buffer DLSS persistent scratch evaluate status #", "Native render-func command-buffer DLSS persistent scratch evaluate set advanced:", "render event frame descriptor DLSS persistent scratch evaluate pending")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer DLSS Visible Write-back" `
    -PassPatterns @("Native render-func command-buffer DLSS visible write-back advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer DLSS visible write-back set failed:", "Native render-func command-buffer DLSS visible write-back event failed:", "render event frame descriptor payload set failed:", "render event frame descriptor payload consume failed:", "DLSS visible write-back failed", "RenderGraph pass-list logging failed") `
    -BlockedPatterns @("DLSS visible write-back blocked", "native bridge was built without NVIDIA SDK wrapper integration", "runtime path was empty") `
    -StartedPatterns @("Native render-func command-buffer DLSS visible write-back preflight enabled", "Native render-func command-buffer DLSS visible write-back status #", "Native render-func command-buffer DLSS visible write-back set advanced:", "render event frame descriptor DLSS visible write-back pending")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer DLSS User Rendering" `
    -PassPatterns @("Native render-func command-buffer DLSS user rendering advanced:", "DLSS user rendering evaluate succeeded from native command-buffer") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer DLSS user rendering set failed:", "Native render-func command-buffer DLSS user rendering event failed:", "render event frame descriptor payload set failed:", "render event frame descriptor payload consume failed:", "DLSS visible write-back failed", "DLSS user rendering evaluate failed", "RenderGraph pass-list logging failed") `
    -BlockedPatterns @("DLSS visible write-back blocked", "DLSS user rendering evaluate blocked", "native bridge was built without NVIDIA SDK wrapper integration", "runtime path was empty") `
    -StartedPatterns @("Native render-func command-buffer DLSS user-rendering candidate enabled", "Native render-func command-buffer DLSS user rendering status #", "Native render-func command-buffer DLSS user rendering set advanced:")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc CommandBuffer DLSS Feature Create" `
    -PassPatterns @("Native render-func command-buffer DLSS feature-create advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "Native render-func command-buffer DLSS feature-create set failed:", "Native render-func command-buffer DLSS feature-create event failed:", "render event DLSS feature-create payload set failed:", "render event DLSS feature-create payload consume failed:", "render event DLSS feature-create payload create failed:", "RenderGraph pass-list logging failed") `
    -BlockedPatterns @("native bridge was built without NVIDIA SDK wrapper integration", "runtime path was empty") `
    -StartedPatterns @("Native render-func command-buffer DLSS feature-create preflight enabled", "Native render-func command-buffer DLSS feature-create status #", "Native render-func command-buffer DLSS feature-create set advanced:")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc Resource Identity" `
    -PassPatterns @("Native render-func resource identity advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "RenderGraph pass-list logging failed", "Native render-func resource identity data=not found") `
    -StartedPatterns @("Native render-func resource identity preflight enabled", "Native render-func resource identity status #")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc Resource Tuple" `
    -PassPatterns @("Native render-func resource tuple advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "RenderGraph pass-list logging failed", "Native render-func resource tuple data=not found") `
    -StartedPatterns @("Native render-func resource tuple preflight enabled", "Native render-func resource tuple status #")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc Resource Resolve" `
    -PassPatterns @("Native render-func resource resolve advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "RenderGraph pass-list logging failed", "Native render-func resource resolve data=not found") `
    -StartedPatterns @("Native render-func resource resolve preflight enabled", "Native render-func resource resolve status #")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc Resource Native Pointer" `
    -PassPatterns @("Native render-func resource native-pointer advanced:") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "RenderGraph pass-list logging failed", "Native render-func resource native-pointer data=not found") `
    -StartedPatterns @("Native render-func resource native-pointer preflight enabled", "Native render-func resource native-pointer target armed:", "Native render-func resource native-pointer status #")))

$results.Add((New-StageResult `
    -Stage "Native RenderFunc Resource D3D11" `
    -PassPatterns @("Native render-func resource D3D11 pair advanced:") `
    -FailPatterns @("Native render-func resource D3D11 pair failed:", "D3D11 texture pair probe rejected:", "Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "RenderGraph pass-list logging failed") `
    -StartedPatterns @("Native render-func resource D3D11 preflight enabled", "Native render-func resource native-pointer target armed:", "Native render-func resource native-pointer status #")))

$results.Add((New-StageResult `
    -Stage "HDRP/EASU Input Output Correlation" `
    -PassPatterns @("easuSourceMatchesEasuInput=True; easuDestinationMatchesEasuOutput=True") `
    -FailPatterns @("Native render-func entry probe failed:", "Native render-func entry detour dispose failed:", "RenderGraph pass-list logging failed", "Native render-func resource native-pointer data=not found", "HDRP postprocess render args probe failed to patch", "HDRP postprocess render args probe prefix failed:", "HDRP postprocess render args probe uninstall failed:") `
    -BlockedPatterns @("HDRP postprocess render args probe blocked:", "_CameraDepthTexture=null", "_CameraMotionVectorsTexture=null") `
    -StartedPatterns @("HDRP/EASU input-output correlation status #", "HDRP postprocess render args probe installed:", "Native render-func resource native-pointer target armed:")))

$results.Add((New-StageResult `
    -Stage "HDRP Custom PostProcess Registration" `
    -PassPatterns @("Custom post-process registration probe installed:") `
    -FailPatterns @("Custom post-process registration probe failed:", "Custom post-process registration probe uninstall failed:") `
    -BlockedPatterns @("Custom post-process registration probe blocked:") `
    -StartedPatterns @("Custom post-process registration probe IL2CPP type registered.", "Custom post-process registration probe inactive volume created:")))

$results.Add((New-StageResult `
    -Stage "HDRP Custom PostProcess Render Entry" `
    -PassPatterns @("Custom post-process render-entry probe Render #") `
    -FailPatterns @("Custom post-process render-entry probe failed:", "Custom post-process render-entry probe copy failed", "Custom post-process render-entry probe uninstall failed:") `
    -BlockedPatterns @("Custom post-process render-entry probe blocked:") `
    -StartedPatterns @("Custom post-process render-entry probe IL2CPP type registered.", "Custom post-process render-entry probe global settings registered:", "Custom post-process render-entry probe volume mounted:", "Custom post-process render-entry probe installed:")))

$results.Add((New-StageResult `
    -Stage "HDRP PostProcess Boundary" `
    -PassPatterns @("HDRP postprocess boundary probe call #") `
    -FailPatterns @("HDRP postprocess boundary probe failed to patch", "HDRP postprocess boundary probe prefix failed:", "HDRP postprocess boundary probe uninstall failed:") `
    -BlockedPatterns @("HDRP postprocess boundary probe blocked:") `
    -StartedPatterns @("HDRP postprocess boundary probe patched:", "HDRP postprocess boundary probe installed:")))

$results.Add((New-StageResult `
    -Stage "HDRP PostProcess Render Args" `
    -PassPatterns @("HDRP postprocess render args snapshot #") `
    -FailPatterns @("HDRP postprocess render args probe failed to patch", "HDRP postprocess render args probe prefix failed:", "HDRP postprocess render args probe uninstall failed:") `
    -BlockedPatterns @("HDRP postprocess render args probe blocked:") `
    -StartedPatterns @("HDRP postprocess render args probe patched:", "HDRP postprocess render args probe installed:")))

$results.Add((New-StageResult `
    -Stage "HDRP PostProcess Render Args Global Textures" `
    -PassPatterns @("HDRP postprocess render args global textures advanced:") `
    -FailPatterns @("HDRP postprocess render args probe failed to patch", "HDRP postprocess render args probe prefix failed:", "HDRP postprocess render args probe uninstall failed:") `
    -BlockedPatterns @("HDRP postprocess render args probe blocked:", "_CameraDepthTexture=null", "_CameraMotionVectorsTexture=null") `
    -StartedPatterns @("globalTextureSnapshot=True")))

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
