<#
.SYNOPSIS
Creates a timestamped 7-Zip archive containing selected repository files and folders.

.DESCRIPTION
Packages the repository items needed for a distributable dependency/configuration bundle
into a single .7z archive named birp-package-<date-time>.7z.

 The archive contents are fixed to these filesystem paths at the repository root:
 - .github
 - birp-dependencies
 - birp-dev/scripts
 - .gitignore
 - .markdownlint-cli2.yaml
 - package.json
 - package-lock.json

The script resolves the repository root from its own location, verifies that each required
path exists, locates a usable 7-Zip executable, and writes the archive to the repository root
unless an alternate output directory is provided.

.PARAMETER OutputDirectory
Optional destination directory for the generated archive. Defaults to the repository root.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\create-birp-package.ps1

Creates birp-package-<date-time>.7z in the repository root.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\create-birp-package.ps1 -OutputDirectory C:\Archives

Creates the archive in C:\Archives.

.OUTPUTS
Writes progress and the final archive path to the host stream.

Exit code behavior:
- 0 when the archive is created successfully
- non-zero when prerequisites are missing or 7-Zip fails

.NOTES
This script requires 7-Zip. It checks PATH first, then common default install locations.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

function Get-SevenZipExecutable {
    $commands = @('7z.exe', '7za.exe')
    foreach ($commandName in $commands) {
        $command = Get-Command -Name $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    $defaultPaths = @(
        'C:\Program Files\7-Zip\7z.exe',
        'C:\Program Files (x86)\7-Zip\7z.exe'
    )

    foreach ($candidatePath in $defaultPaths) {
        if (Test-Path -LiteralPath $candidatePath) {
            return $candidatePath
        }
    }

    throw '7-Zip executable not found. Install 7-Zip or add 7z.exe to PATH.'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = $repoRoot
}

$resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $resolvedOutputDirectory)) {
    throw "Output directory does not exist: $resolvedOutputDirectory"
}

$pathsToArchive = @(
    '.github',
    'birp-dependencies',
    'birp-dev/scripts',
    '.gitignore',
    '.markdownlint-cli2.yaml',
    'package.json',
    'package-lock.json'
)

$missingPaths = @()
foreach ($relativePath in $pathsToArchive) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $missingPaths += $relativePath
    }
}

if ($missingPaths.Count -gt 0) {
    throw "Required path(s) not found: $($missingPaths -join ', ')"
}

$sevenZipExecutable = Get-SevenZipExecutable
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archiveName = "birp-package-$timestamp.7z"
$archivePath = Join-Path $resolvedOutputDirectory $archiveName

Write-Host '=== Creating BIRP Package ===' -ForegroundColor Cyan
Write-Host "Repository root : $repoRoot" -ForegroundColor Yellow
Write-Host "Output archive  : $archivePath" -ForegroundColor Yellow
Write-Host "7-Zip executable: $sevenZipExecutable" -ForegroundColor Yellow
Write-Host ''

Push-Location $repoRoot
try {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    $archiveArguments = @(
        'a',
        '-t7z',
        $archivePath
    ) + $pathsToArchive

    & $sevenZipExecutable @archiveArguments
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host "[OK] Package created: $archivePath" -ForegroundColor Green