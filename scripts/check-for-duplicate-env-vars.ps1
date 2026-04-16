<#
.SYNOPSIS
Validates HKCU\Environment for duplicate entries in PATH, INCLUDE, and LIB.

.DESCRIPTION
Scans HKCU\Environment for duplicate entries in critical build variables and prints
a human-readable validation report.

The script checks three variables:
- PATH: executable search paths
- INCLUDE: C/C++ include directory search paths
- LIB: C/C++ library directory search paths

Each variable is split by semicolon, normalized for empty entries, deduplicated for
comparison, and reported with counts. When duplicates are detected, each duplicate
entry is listed with its occurrence count.

The script also verifies whether the repository's optional MASM-compatible assembler
path (birp-dependencies\UASM-v2_57) is present in PATH.

This utility is read-only: it does not edit registry values.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1

Runs the validation script from the repository root.

.EXAMPLE
Set-Location E:\birthright-preservation-patch
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1

Changes to the repository root and runs the validation script.

.OUTPUTS
Writes a formatted status report to the host stream, including:
- per-variable duplicate status and counts
- optional UASM PATH presence status
- summary pass/fail state

Exit code behavior:
- 0 when script execution completes successfully (regardless of duplicate findings)
- non-zero only for runtime/script errors

.NOTES
Run this utility:
- After executing setup-env-vars-for-birthright-preservation-patch.ps1 to verify deduplication
- Periodically to detect if duplicates have accumulated
- When troubleshooting build environment issues

Expected registry location:
- HKCU\Environment

Companion setup script:
- birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1

See birp-dev\scripts\README.md for more information on environment setup scripts.
#>

Write-Host '=== Checking for Duplicate Environment Variables ===' -ForegroundColor Cyan
Write-Host ''

# Get registry values
$registryPath = 'HKCU:\Environment'

# Check PATH
Write-Host 'PATH:' -ForegroundColor Yellow
$pathValue = (Get-ItemProperty -Path $registryPath -Name Path -EA SilentlyContinue).Path
$paths = $pathValue -split ';' | Where-Object {-not [string]::IsNullOrWhiteSpace($_)}
$uniquePaths = $paths | Sort-Object -Unique
if ($paths.Count -eq $uniquePaths.Count) {
    Write-Host '[OK] No duplicates' -ForegroundColor Green
    Write-Host "  Total entries: $($paths.Count)" -ForegroundColor Cyan
} else {
    Write-Host '[FAIL] Duplicates found!' -ForegroundColor Red
    Write-Host "  Total entries: $($paths.Count), Unique: $($uniquePaths.Count)" -ForegroundColor Red
    $paths | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object {
        Write-Host "    Duplicate ($($_.Count)x): $($_.Name)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host 'INCLUDE:' -ForegroundColor Yellow
$includeValue = (Get-ItemProperty -Path $registryPath -Name INCLUDE -EA SilentlyContinue).INCLUDE
$includes = $includeValue -split ';' | Where-Object {-not [string]::IsNullOrWhiteSpace($_)}
$uniqueIncludes = $includes | Sort-Object -Unique
if ($includes.Count -eq $uniqueIncludes.Count) {
    Write-Host '[OK] No duplicates' -ForegroundColor Green
    Write-Host "  Total entries: $($includes.Count)" -ForegroundColor Cyan
} else {
    Write-Host '[FAIL] Duplicates found!' -ForegroundColor Red
    Write-Host "  Total entries: $($includes.Count), Unique: $($uniqueIncludes.Count)" -ForegroundColor Red
    $includes | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object {
        Write-Host "    Duplicate ($($_.Count)x): $($_.Name)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host 'LIB:' -ForegroundColor Yellow
$libValue = (Get-ItemProperty -Path $registryPath -Name LIB -EA SilentlyContinue).LIB
$libs = $libValue -split ';' | Where-Object {-not [string]::IsNullOrWhiteSpace($_)}
$uniqueLibs = $libs | Sort-Object -Unique
if ($libs.Count -eq $uniqueLibs.Count) {
    Write-Host '[OK] No duplicates' -ForegroundColor Green
    Write-Host "  Total entries: $($libs.Count)" -ForegroundColor Cyan
} else {
    Write-Host '[FAIL] Duplicates found!' -ForegroundColor Red
    Write-Host "  Total entries: $($libs.Count), Unique: $($uniqueLibs.Count)" -ForegroundColor Red
    $libs | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object {
        Write-Host "    Duplicate ($($_.Count)x): $($_.Name)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host '=== Summary ===' -ForegroundColor Cyan
$totalIssues = 0
if ($paths.Count -ne $uniquePaths.Count) { $totalIssues += 1 }
if ($includes.Count -ne $uniqueIncludes.Count) { $totalIssues += 1 }
if ($libs.Count -ne $uniqueLibs.Count) { $totalIssues += 1 }

# Validate that optional MASM-compatible assembler path is available.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$expectedUasmPath = Join-Path $repoRoot "birp-dependencies\UASM-v2_57"
$uasmInPath = $paths | Where-Object { $_.Trim().Equals($expectedUasmPath, [System.StringComparison]::OrdinalIgnoreCase) }
if ($uasmInPath) {
    Write-Host "[OK] UASM path found in PATH: $expectedUasmPath" -ForegroundColor Green
} else {
    Write-Host "! UASM path not found in PATH: $expectedUasmPath" -ForegroundColor Yellow
    Write-Host "  Run birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1 to add it." -ForegroundColor Yellow
}

if ($totalIssues -eq 0) {
    Write-Host '[OK] All environment variables are clean - no duplicates found!' -ForegroundColor Green
} else {
    Write-Host "[FAIL] Found issues in $totalIssues variable(s)" -ForegroundColor Red
}
