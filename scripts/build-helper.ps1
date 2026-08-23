<#
.SYNOPSIS
Runs one MAKE.BAT build-output validation scenario.

.DESCRIPTION
Shared helper used by scenario wrappers to run a MAKE.BAT scenario, capture
terminal output, validate expected markers/artifacts, and emit a single-scenario
report under birp-dev\build-artifacts\logs.

.PARAMETER Name
Display name for the scenario.

.PARAMETER OsTarget
OS token used to locate scenario build logs (for example, WIN95 or DOS).

.PARAMETER ScenarioTokens
Arguments passed to MAKE.BAT for the scenario.

.PARAMETER ExpectedArtifacts
Relative artifact paths that must exist after a successful run.

.PARAMETER ExpectCleanStep
When true, requires a clean-step marker in the build log.

.PARAMETER ExpectBuildExitCodeMarker
When true, requires a build exit code marker in the build log.

.PARAMETER SkipToolchainCheck
Skips required toolchain command checks (wmake/wcc386/wpp386).

.PARAMETER MakeBatPath
Optional path override to MAKE.BAT.

.PARAMETER ShowInformationalOutput
When set, prints informational build output to the terminal.
By default, only warnings and errors are printed.

.EXAMPLE
& .\build-helper.ps1 -Name 'WIN95 release install' -OsTarget 'WIN95' -ScenarioTokens @('WIN95','--release') -ExpectedArtifacts @('build-artifacts\binaries\Release\Windows\nova95.exe') -ExpectCleanStep $true -ExpectBuildExitCodeMarker $true
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$OsTarget,

    [Parameter(Mandatory = $true)]
    [string[]]$ScenarioTokens,

    [Parameter(Mandatory = $true)]
    [string[]]$ExpectedArtifacts,

    [Parameter(Mandatory = $true)]
    [bool]$ExpectCleanStep,

    [Parameter(Mandatory = $true)]
    [bool]$ExpectBuildExitCodeMarker,

    [switch]$SkipToolchainCheck,

    [string]$MakeBatPath,

    [switch]$ShowInformationalOutput
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$birpDevRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$buildLogsDir = Join-Path $birpDevRoot 'build-artifacts\logs'

if ([string]::IsNullOrWhiteSpace($MakeBatPath)) {
    $MakeBatPath = Join-Path $birpDevRoot 'MAKE.BAT'
}

if (-not (Test-Path -LiteralPath $MakeBatPath)) {
    throw "MAKE.BAT not found: $MakeBatPath"
}

if (-not (Test-Path -LiteralPath $buildLogsDir)) {
    New-Item -ItemType Directory -Path $buildLogsDir -Force | Out-Null
}

if (-not $SkipToolchainCheck) {
    $requiredCommands = @('wmake', 'wcc386', 'wpp386')
    $missing = @()
    foreach ($cmd in $requiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $missing += $cmd
        }
    }

    if ($missing.Count -gt 0) {
        throw "Missing required toolchain commands in PATH: $($missing -join ', '). Run birp-dev\scripts\setup-env-vars-for-building.ps1 first."
    }
}

function Get-LogSnapshot {
    param([string]$ScenarioOsTarget)

    $snapshot = @{}
    $pattern = "build-$ScenarioOsTarget-*.log"
    $files = Get-ChildItem -Path $buildLogsDir -Filter $pattern -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $snapshot[$file.FullName.ToLowerInvariant()] = [PSCustomObject]@{
            LastWriteTimeUtcTicks = $file.LastWriteTimeUtc.Ticks
            Length = $file.Length
        }
    }

    return $snapshot
}

Write-Host "[RUN] $Name" -ForegroundColor Yellow

# Get first 2 bytes (4 hex chars) of current commit and convert to int
# Must run in birp-dev, not the caller's working directory. The parent workspace is
# its own git repository, so building from there stamped the build number with the
# parent's commit instead of the game source commit.
try {
    Push-Location $birpDevRoot
    $shortHex = (& git rev-parse --short=4 HEAD 2>$null).Trim()
    Pop-Location
} catch {
    Pop-Location -ErrorAction SilentlyContinue
    Write-Error "Failed to get git commit hash. Ensure git is installed and this is a git repo."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($shortHex) -or $shortHex.Length -lt 1) {
    Write-Error "Unexpected git short hash: '$shortHex'"
    exit 1
}

# git --short=4 may return a longer prefix to avoid ambiguity; truncate to the first 4 hex chars (first 2 bytes)
if ($shortHex.Length -gt 4) {
    Write-Host "Note: git returned a longer short hash '$shortHex'; truncating to first 4 chars"
    $shortHex = $shortHex.Substring(0,4)
}

if ($shortHex.Length -lt 4) {
    Write-Error "Unexpected git short hash length after truncation: '$shortHex'"
    exit 1
}

try {
    $buildBuild = [Convert]::ToInt32($shortHex, 16)
} catch {
    Write-Error "Failed to convert hex '$shortHex' to int: $_"
    exit 1
}

$beforeLogs = Get-LogSnapshot -ScenarioOsTarget $OsTarget
$quotedMakeBat = '"' + $MakeBatPath + '"'
$scenarioText = ($ScenarioTokens | ForEach-Object { $_ }) -join ' '
$cmdLine = "$quotedMakeBat $scenarioText ""BUILD_BUILD=$buildBuild"""

Push-Location $birpDevRoot
try {
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $cmdOutputRaw = @(& cmd.exe /c $cmdLine *>&1)
    $ErrorActionPreference = $savedErrorActionPreference
    $cmdOutput = @($cmdOutputRaw | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE

    $warningLines = @($cmdOutput | Where-Object { $_ -match 'Warning!|Warning\(' })
    $errorLines = @($cmdOutput | Where-Object { $_ -match 'Error!|Error\(' })
    $informationalLines = @($cmdOutput | Where-Object { $_ -notmatch 'Warning!|Warning\(|Error!|Error\(' })

    foreach ($line in $cmdOutput) {
        if ($ShowInformationalOutput -or ($line -match 'Warning!|Warning\(|Error!|Error\(')) {
            Write-Host $line
        }
    }
}
finally {
    $ErrorActionPreference = $savedErrorActionPreference
    Pop-Location
}

$emittedLog = $null
foreach ($line in $cmdOutput) {
    if ($line -match '^Build log:\s*(.+)$') {
        $emittedLog = $matches[1].Trim()
        break
    }
}

$afterCandidates = Get-ChildItem -Path $buildLogsDir -Filter ("build-" + $OsTarget + "-*.log") -File -ErrorAction SilentlyContinue
$newOrUpdatedLogs = @(
    $afterCandidates | Where-Object {
        $key = $_.FullName.ToLowerInvariant()
        if (-not $beforeLogs.ContainsKey($key)) {
            return $true
        }

        $beforeMeta = $beforeLogs[$key]
        return ($beforeMeta.LastWriteTimeUtcTicks -ne $_.LastWriteTimeUtc.Ticks) -or ($beforeMeta.Length -ne $_.Length)
    } | Sort-Object LastWriteTime -Descending
)

$selectedLog = $null
if (-not [string]::IsNullOrWhiteSpace($emittedLog) -and (Test-Path -LiteralPath $emittedLog)) {
    $selectedLog = $emittedLog
}
elseif ($newOrUpdatedLogs.Count -gt 0) {
    $selectedLog = $newOrUpdatedLogs[0].FullName
}
elseif ($afterCandidates.Count -gt 0) {
    $selectedLog = ($afterCandidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

$errors = New-Object 'System.Collections.Generic.List[string]'

if ($exitCode -ne 0) {
    [void]$errors.Add("Exit code was $exitCode")
}

if ([string]::IsNullOrWhiteSpace($selectedLog)) {
    [void]$errors.Add('No build log was found for this case')
}

if ($selectedLog) {
    $logText = Get-Content -Path $selectedLog -Raw -Encoding ASCII

    if ($ExpectBuildExitCodeMarker -and ($logText -notmatch 'Build exit code:')) {
        [void]$errors.Add('Build exit code marker was not found in build log')
    }

    $hasCleanMarker = $logText -match 'Clean step exit code:'
    if ($ExpectCleanStep -and (-not $hasCleanMarker)) {
        [void]$errors.Add('Expected clean-step marker was not found in build log')
    }
    if ((-not $ExpectCleanStep) -and $hasCleanMarker) {
        [void]$errors.Add('Clean-step marker was found unexpectedly in build log')
    }
}

foreach ($artifact in $ExpectedArtifacts) {
    $artifactPath = Join-Path $birpDevRoot $artifact
    if (-not (Test-Path -LiteralPath $artifactPath)) {
        [void]$errors.Add("Expected artifact not found: $artifact")
    }
}

$status = if ($errors.Count -eq 0) { 'PASS' } else { 'FAIL' }
if ($status -eq 'PASS') {
    Write-Host "[PASS] $Name" -ForegroundColor Green
}
else {
    Write-Host "[FAIL] $Name" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "       - $err" -ForegroundColor Red
    }

    if ($selectedLog -and (Test-Path -LiteralPath $selectedLog)) {
        Write-Host "       Log: $selectedLog" -ForegroundColor DarkYellow
        $tail = Get-Content -Path $selectedLog -Tail 10 -ErrorAction SilentlyContinue
        if ($tail) {
            Write-Host '       Log tail:' -ForegroundColor DarkYellow
            foreach ($line in $tail) {
                Write-Host "         $line" -ForegroundColor DarkYellow
            }
        }
    }
}

$scenarioSlug = ($Name.ToLowerInvariant() -replace '[^a-z0-9]+', '-') -replace '(^-+|-+$)', ''
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $buildLogsDir ("build-report-" + $scenarioSlug + "-" + $stamp + ".txt")

$summaryLines = New-Object 'System.Collections.Generic.List[string]'
$summaryLines.Add('MAKE.BAT single-scenario test report') | Out-Null
$summaryLines.Add(("Timestamp: " + (Get-Date).ToString('s'))) | Out-Null
$summaryLines.Add(("Scenario: " + $Name)) | Out-Null
$summaryLines.Add(("MAKE.BAT: " + $MakeBatPath)) | Out-Null
$summaryLines.Add(("Status: " + $status)) | Out-Null
$summaryLines.Add(("ExitCode: " + $exitCode)) | Out-Null
$summaryLines.Add(("LogFile: " + $selectedLog)) | Out-Null
$summaryLines.Add(("Warnings: " + $warningLines.Count)) | Out-Null
$summaryLines.Add(("Errors: " + $errorLines.Count)) | Out-Null
$summaryLines.Add(("Informational: " + $informationalLines.Count)) | Out-Null
if ($errors.Count -gt 0) {
    $summaryLines.Add(("Issues: " + [string]::Join('; ', $errors))) | Out-Null
}

if ($informationalLines.Count -gt 0) {
    $summaryLines.Add('InformationalLines:') | Out-Null
    foreach ($line in $informationalLines) {
        $summaryLines.Add(("  - " + $line)) | Out-Null
    }
}

if ($warningLines.Count -gt 0) {
    $summaryLines.Add('WarningLines:') | Out-Null
    foreach ($line in $warningLines) {
        $summaryLines.Add(("  - " + $line)) | Out-Null
    }
}

if ($errorLines.Count -gt 0) {
    $summaryLines.Add('ErrorLines:') | Out-Null
    foreach ($line in $errorLines) {
        $summaryLines.Add(("  - " + $line)) | Out-Null
    }
}

Set-Content -Path $reportPath -Value $summaryLines -Encoding ASCII
Write-Host "Report: $reportPath" -ForegroundColor Cyan

if ($status -eq 'FAIL') {
    exit 1
}

exit 0
