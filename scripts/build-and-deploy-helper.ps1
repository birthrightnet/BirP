<#
.SYNOPSIS
Runs one build wrapper and then its matching deploy wrapper.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BuildScript,

    [Parameter(Mandatory = $true)]
    [string]$DeployScript,

    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildPath = Join-Path $scriptDir $BuildScript
$deployPath = Join-Path $scriptDir $DeployScript

if (-not (Test-Path -LiteralPath $buildPath)) {
    throw "Build script not found: $buildPath"
}

if (-not (Test-Path -LiteralPath $deployPath)) {
    throw "Deploy script not found: $deployPath"
}

Write-Host "[RUN] Build:  $BuildScript" -ForegroundColor Yellow

$buildArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $buildPath)
if ($SkipToolchainCheck) {
    $buildArgs += '-SkipToolchainCheck'
}
if (-not [string]::IsNullOrWhiteSpace($MakeBatPath)) {
    $buildArgs += '-MakeBatPath'
    $buildArgs += $MakeBatPath
}

& powershell @buildArgs
$buildExitCode = $LASTEXITCODE

if ($buildExitCode -ne 0) {
    Write-Host "[FAIL] Build script failed: $BuildScript (exit code $buildExitCode)" -ForegroundColor Red
    exit $buildExitCode
}

Write-Host "[RUN] Deploy: $DeployScript" -ForegroundColor Yellow
& powershell -NoProfile -ExecutionPolicy Bypass -File $deployPath
$deployExitCode = $LASTEXITCODE

if ($deployExitCode -ne 0) {
    Write-Host "[FAIL] Deploy script failed: $DeployScript (exit code $deployExitCode)" -ForegroundColor Red
    exit $deployExitCode
}

Write-Host "[OK] Build+deploy completed: $BuildScript + $DeployScript" -ForegroundColor Green
exit 0
