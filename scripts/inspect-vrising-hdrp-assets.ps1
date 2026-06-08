param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath,

    [string]$Root,

    [string]$PythonPath,

    [string]$DummyDllPath,

    [switch]$Json
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path "$PSScriptRoot\..").Path
} else {
    $Root = (Resolve-Path -LiteralPath $Root).Path
}

if ([string]::IsNullOrWhiteSpace($PythonPath)) {
    $preferredPython = "C:\Software\Python314\python.exe"
    if (Test-Path -LiteralPath $preferredPython) {
        $PythonPath = $preferredPython
    } else {
        $command = Get-Command python -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            throw "Python was not found. Pass -PythonPath or install Python."
        }

        $PythonPath = $command.Source
    }
}

if (-not (Test-Path -LiteralPath $PythonPath)) {
    throw "PythonPath does not exist: $PythonPath"
}

if ([string]::IsNullOrWhiteSpace($DummyDllPath)) {
    $DummyDllPath = Join-Path $Root "ref\decompilation-vrising-2026-06-08\il2cpp-dumper\DummyDll"
}

if (-not (Test-Path -LiteralPath $DummyDllPath)) {
    throw "DummyDllPath does not exist: $DummyDllPath"
}

$helperPath = Join-Path $PSScriptRoot "inspect_vrising_hdrp_assets.py"
if (-not (Test-Path -LiteralPath $helperPath)) {
    throw "Helper script not found: $helperPath"
}

$arguments = @(
    $helperPath,
    "--game-path",
    (Resolve-Path -LiteralPath $GamePath).Path,
    "--dummy-dll-path",
    (Resolve-Path -LiteralPath $DummyDllPath).Path
)

if ($Json) {
    $arguments += "--json"
}

& $PythonPath @arguments
exit $LASTEXITCODE
