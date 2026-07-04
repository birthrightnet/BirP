<#
.SYNOPSIS
Validates toolchain-related HKCU\Environment variables for duplicates, required entries, and path existence.

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

The script also verifies whether an expected MASM-compatible assembler path
for UASM is present in PATH (default or repository-local), checks that
key scalar toolchain variables written by the setup script are present,
and validates that required toolchain directories exist on disk.

Validation scope includes:
- duplicate checks for PATH, INCLUDE, and LIB
- presence checks for WATCOM, EDPATH, WHTMLHELP, WIPFC, and BIRTHRT_INSTALL_DIR
- existence checks for required Open Watcom, Windows95DDK, DirectXSDK, UASM, and Inno Setup 6 directories referenced by PATH/INCLUDE/LIB/scalar values

This script reads registry values only and never writes or modifies HKCU\Environment.

This utility is read-only: it does not edit registry values.

.INPUTS
None. This script does not accept pipeline input.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1

Runs the validation script from the repository root.

.EXAMPLE
Set-Location E:\birthright-preservation-patch
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1

Changes to the repository root and runs the validation script.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1; $LASTEXITCODE

Runs validation and prints the resulting process exit code (0 for success, 1 when validation issues are found).

.OUTPUTS
Writes a formatted status report to the host stream, including:
- per-variable duplicate status and counts
- optional UASM PATH presence status
- scalar toolchain variable presence status
- required toolchain path existence status
- summary pass/fail state

The script writes host output only; it does not emit structured pipeline objects.

Exit code behavior:
- 0 when no validation issues are found
- 1 when validation issues are found
- non-zero for runtime/script errors

.NOTES
Run this utility:
- After executing setup-env-vars-for-building.ps1 to verify deduplication
- Periodically to detect if duplicates have accumulated
- When troubleshooting build environment issues

Assumptions for expected path patterns:
- Open Watcom paths include OPENWATCOM-v2_0
- Windows 95 DDK paths include Windows95DDK
- DirectX paths include DirectXSDK\sdk\inc and DirectXSDK\sdk\lib
- UASM path ends with UASM-v2_57

Expected registry location:
- HKCU\Environment

Companion setup script:
- birp-dev\scripts\setup-env-vars-for-building.ps1

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
$openWatcomRoot = (Get-ItemProperty -Path $registryPath -Name WATCOM -EA SilentlyContinue).WATCOM
$repoRelativeUasmPath = Join-Path $repoRoot "birp-dependencies\UASM-v2_57"
$defaultUasmPath = "C:\BirP-Dependencies\UASM-v2_57"
$uasmInPath = $paths | Where-Object {
    $candidate = $_.Trim()
    $candidate.Equals($repoRelativeUasmPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $candidate.Equals($defaultUasmPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    ($candidate -match '(?i)\\UASM-v2_57\\?$')
}
if ($uasmInPath -and $uasmInPath.Count -gt 0) {
    Write-Host "[OK] UASM path found in PATH:" -ForegroundColor Green
    Write-Host "  $($uasmInPath[0])" -ForegroundColor Cyan
} else {
    $totalIssues += 1
    Write-Host "! UASM path not found in PATH." -ForegroundColor Yellow
    Write-Host "  Expected one of:" -ForegroundColor Yellow
    Write-Host "    - $repoRelativeUasmPath" -ForegroundColor DarkYellow
    Write-Host "    - $defaultUasmPath" -ForegroundColor DarkYellow
    Write-Host "    - or a custom path ending with \\UASM-v2_57" -ForegroundColor DarkYellow
    Write-Host "  Run birp-dev\scripts\setup-env-vars-for-building.ps1 to add it." -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'SCALAR VARIABLES:' -ForegroundColor Yellow
$requiredScalarVars = @(
    'WATCOM',
    'EDPATH',
    'WHTMLHELP',
    'WIPFC',
    'BIRTHRT_INSTALL_DIR'
)

$missingScalarVars = New-Object 'System.Collections.Generic.List[string]'
$scalarPathVars = New-Object 'System.Collections.Generic.Dictionary[string,string]'
foreach ($varName in $requiredScalarVars) {
    $value = (Get-ItemProperty -Path $registryPath -Name $varName -EA SilentlyContinue).$varName
    if ([string]::IsNullOrWhiteSpace($value)) {
        $missingScalarVars.Add($varName) | Out-Null
        Write-Host "[FAIL] $varName is missing or empty" -ForegroundColor Red
    } else {
        $scalarPathVars[$varName] = $value
        Write-Host "[OK] $varName=$value" -ForegroundColor Green
    }
}

if ($missingScalarVars.Count -gt 0) {
    $totalIssues += $missingScalarVars.Count
}

Write-Host ''
Write-Host 'REQUIRED PATHS EXISTENCE:' -ForegroundColor Yellow

function Test-RequiredPath {
    param(
        [string]$Label,
        [string]$PathValue,
        [ref]$IssueCounter
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        $IssueCounter.Value += 1
        Write-Host "[FAIL] $Label is empty" -ForegroundColor Red
        return
    }

    if (Test-Path -LiteralPath $PathValue -PathType Container) {
        Write-Host "[OK] $Label=$PathValue" -ForegroundColor Green
    } else {
        $IssueCounter.Value += 1
        Write-Host "[FAIL] Missing: $Label=$PathValue" -ForegroundColor Red
    }
}

$pathIssues = 0

$requiredPathFromPath = @(
    [PSCustomObject]@{ Name = 'OpenWatcom binnt64'; Pattern = '(?i)\\OPENWATCOM-v2_0\\binnt64\\?$' },
    [PSCustomObject]@{ Name = 'OpenWatcom binnt'; Pattern = '(?i)\\OPENWATCOM-v2_0\\binnt\\?$' },
    [PSCustomObject]@{ Name = 'UASM-v2_57'; Pattern = '(?i)\\UASM-v2_57\\?$' },
    [PSCustomObject]@{ Name = 'InnoSetup-6'; Pattern = '(?i)\\InnoSetup-6\\?$' }
)

foreach ($req in $requiredPathFromPath) {
    $match = $paths | Where-Object { $_.Trim() -match $req.Pattern } | Select-Object -First 1
    if ($match) {
        Test-RequiredPath -Label ("PATH " + $req.Name) -PathValue $match.Trim() -IssueCounter ([ref]$pathIssues)
    } else {
        $pathIssues += 1
        Write-Host "[FAIL] Missing required PATH reference: $($req.Name)" -ForegroundColor Red
    }
}

$requiredIncludePatterns = @(
    [PSCustomObject]@{ Name = 'OpenWatcom h'; Pattern = '(?i)\\OPENWATCOM-v2_0\\h\\?$' },
    [PSCustomObject]@{ Name = 'OpenWatcom h\\nt'; Pattern = '(?i)\\OPENWATCOM-v2_0\\h\\nt\\?$' },
    [PSCustomObject]@{ Name = 'OpenWatcom h\\nt\\directx'; Pattern = '(?i)\\OPENWATCOM-v2_0\\h\\nt\\directx\\?$' },
    [PSCustomObject]@{ Name = 'OpenWatcom h\\nt\\ddk'; Pattern = '(?i)\\OPENWATCOM-v2_0\\h\\nt\\ddk\\?$' },
    [PSCustomObject]@{ Name = 'Windows95DDK INC32'; Pattern = '(?i)\\Windows95DDK\\INC32\\?$' },
    [PSCustomObject]@{ Name = 'Windows95DDK INC16'; Pattern = '(?i)\\Windows95DDK\\INC16\\?$' },
    [PSCustomObject]@{ Name = 'DirectXSDK sdk\\inc'; Pattern = '(?i)\\DirectXSDK\\sdk\\inc\\?$' }
)

foreach ($req in $requiredIncludePatterns) {
    $match = $includes | Where-Object { $_.Trim() -match $req.Pattern } | Select-Object -First 1
    if ($match) {
        Test-RequiredPath -Label ("INCLUDE " + $req.Name) -PathValue $match.Trim() -IssueCounter ([ref]$pathIssues)
    } else {
        $pathIssues += 1
        Write-Host "[FAIL] Missing required INCLUDE reference: $($req.Name)" -ForegroundColor Red
    }
}

$digitalvIncludeMatch = $includes | Where-Object {
    $candidate = $_.Trim()
    -not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath (Join-Path $candidate 'digitalv.h') -PathType Leaf)
} | Select-Object -First 1

if ($digitalvIncludeMatch) {
    Test-RequiredPath -Label 'INCLUDE DIGITALV.H parent directory' -PathValue $digitalvIncludeMatch.Trim() -IssueCounter ([ref]$pathIssues)
}
else {
    $pathIssues += 1
    Write-Host '[FAIL] Missing required INCLUDE reference containing DIGITALV.H' -ForegroundColor Red
}

$requiredLibPatterns = @(
    [PSCustomObject]@{ Name = 'OpenWatcom lib386'; Pattern = '(?i)\\OPENWATCOM-v2_0\\lib386\\?$' },
    [PSCustomObject]@{ Name = 'OpenWatcom lib386\\nt'; Pattern = '(?i)\\OPENWATCOM-v2_0\\lib386\\nt\\?$' },
    [PSCustomObject]@{ Name = 'Windows95DDK LIB'; Pattern = '(?i)\\Windows95DDK\\LIB\\?$' },
    [PSCustomObject]@{ Name = 'DirectXSDK sdk\\lib'; Pattern = '(?i)\\DirectXSDK\\sdk\\lib\\?$' }
)

foreach ($req in $requiredLibPatterns) {
    $match = $libs | Where-Object { $_.Trim() -match $req.Pattern } | Select-Object -First 1
    if ($match) {
        Test-RequiredPath -Label ("LIB " + $req.Name) -PathValue $match.Trim() -IssueCounter ([ref]$pathIssues)
    } else {
        $pathIssues += 1
        Write-Host "[FAIL] Missing required LIB reference: $($req.Name)" -ForegroundColor Red
    }
}

Test-RequiredPath -Label 'SCALAR WATCOM' -PathValue $openWatcomRoot -IssueCounter ([ref]$pathIssues)

$edpath = $null
$whtmlhelp = $null
$wipfc = $null
if ($openWatcomRoot) {
    $edpath = Join-Path $openWatcomRoot 'eddat'
    $whtmlhelp = Join-Path $openWatcomRoot 'binnt\help'
    $wipfc = Join-Path $openWatcomRoot 'wipfc'
}

Test-RequiredPath -Label 'SCALAR EDPATH' -PathValue $edpath -IssueCounter ([ref]$pathIssues)
Test-RequiredPath -Label 'SCALAR WHTMLHELP' -PathValue $whtmlhelp -IssueCounter ([ref]$pathIssues)
Test-RequiredPath -Label 'SCALAR WIPFC' -PathValue $wipfc -IssueCounter ([ref]$pathIssues)

$birthrtInstallDir = $null
if ($scalarPathVars.ContainsKey('BIRTHRT_INSTALL_DIR')) {
    $birthrtInstallDir = $scalarPathVars['BIRTHRT_INSTALL_DIR']
}
Test-RequiredPath -Label 'SCALAR BIRTHRT_INSTALL_DIR' -PathValue $birthrtInstallDir -IssueCounter ([ref]$pathIssues)

if ($pathIssues -gt 0) {
    $totalIssues += $pathIssues
}

if ($totalIssues -eq 0) {
    Write-Host '[OK] All environment variables are clean - no duplicates found!' -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] Found issues in $totalIssues variable(s)" -ForegroundColor Red
    exit 1
}
