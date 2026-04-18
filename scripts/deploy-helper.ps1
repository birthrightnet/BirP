<#
.SYNOPSIS
Copies one built executable from birp-dev\build-artifacts\binaries to C:\BIRTHRT.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$RelativeSourcePath,

    [string]$DestinationDirectory = 'C:\BIRTHRT'
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$sourcePath = Join-Path $repoRoot (Join-Path 'birp-dev' $RelativeSourcePath)

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Built executable not found: $sourcePath"
}

if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
    throw "Destination directory not found: $DestinationDirectory"
}

$destinationPath = Join-Path $DestinationDirectory (Split-Path -Leaf $sourcePath)

Write-Host "[RUN] $Name" -ForegroundColor Yellow
Write-Host "Source      : $sourcePath" -ForegroundColor Cyan
Write-Host "Destination : $destinationPath" -ForegroundColor Cyan

Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force

Write-Host "[OK] Deployed: $destinationPath" -ForegroundColor Green
