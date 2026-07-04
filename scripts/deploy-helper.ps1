<#
.SYNOPSIS
Copies one built executable from birp-dev\build-artifacts\binaries to BIRTHRT_INSTALL_DIR (or C:\BIRTHRT fallback).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$RelativeSourcePath,

    [string]$DestinationDirectory,

    # Optional destination file name. When omitted, the source file name is used.
    # Used to deploy under the patch/installer name (e.g. nova95.exe -> WINBR.EXE)
    # so the deployed layout matches an actual patch installation.
    [string]$DestinationFileName
)

$ErrorActionPreference = 'Stop'

function Resolve-InstallDirectory {
    $scopes = @('Process', 'User', 'Machine')
    foreach ($scope in $scopes) {
        $value = [Environment]::GetEnvironmentVariable('BIRTHRT_INSTALL_DIR', $scope)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return 'C:\BIRTHRT'
}

if ([string]::IsNullOrWhiteSpace($DestinationDirectory)) {
    $DestinationDirectory = Resolve-InstallDirectory
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$sourcePath = Join-Path $repoRoot (Join-Path 'birp-dev' $RelativeSourcePath)

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Built executable not found: $sourcePath"
}

if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
    throw "Destination directory not found: $DestinationDirectory"
}

if ([string]::IsNullOrWhiteSpace($DestinationFileName)) {
    $destinationLeaf = Split-Path -Leaf $sourcePath
} else {
    $destinationLeaf = $DestinationFileName
}
$destinationPath = Join-Path $DestinationDirectory $destinationLeaf

Write-Host "[RUN] $Name" -ForegroundColor Yellow
Write-Host "Source      : $sourcePath" -ForegroundColor Cyan
Write-Host "Destination : $destinationPath" -ForegroundColor Cyan

Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force

Write-Host "[OK] Deployed: $destinationPath" -ForegroundColor Green

$strdatSource = Join-Path $repoRoot 'birp-dev\source\strdat.dat'
if (Test-Path -LiteralPath $strdatSource) {
    $strdatDest = Join-Path $DestinationDirectory 'STRDAT.DAT'
    Write-Host "Source      : $strdatSource" -ForegroundColor Cyan
    Write-Host "Destination : $strdatDest" -ForegroundColor Cyan
    Copy-Item -LiteralPath $strdatSource -Destination $strdatDest -Force
    Write-Host "[OK] Deployed: $strdatDest" -ForegroundColor Green
} else {
    Write-Warning "strdat.dat not found at '$strdatSource'. Run a WIN95 build to regenerate it."
}

# Deploy the issue reporting tool (issue #104) alongside the patch, mirroring the
# installer's oldpatch\patch component so a local deploy matches an install.
$issueToolDir = Join-Path $repoRoot 'birp-dev\issue-reporter'
foreach ($toolFile in @('BirP-Issue-Report.bat', 'BirP-Issue-Report.ps1')) {
    $toolSource = Join-Path $issueToolDir $toolFile
    if (Test-Path -LiteralPath $toolSource) {
        $toolDest = Join-Path $DestinationDirectory $toolFile
        Write-Host "Source      : $toolSource" -ForegroundColor Cyan
        Write-Host "Destination : $toolDest" -ForegroundColor Cyan
        Copy-Item -LiteralPath $toolSource -Destination $toolDest -Force
        Write-Host "[OK] Deployed: $toolDest" -ForegroundColor Green
    } else {
        Write-Warning "Issue report tool file not found at '$toolSource'."
    }
}
