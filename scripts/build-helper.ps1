<#
.SYNOPSIS
Runs one MAKE.BAT build-output validation scenario.
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

    [string]$MakeBatPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$birpDevRoot = Join-Path $repoRoot 'birp-dev'
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
        throw "Missing required toolchain commands in PATH: $($missing -join ', '). Run birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1 first."
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

$beforeLogs = Get-LogSnapshot -ScenarioOsTarget $OsTarget
$quotedMakeBat = '"' + $MakeBatPath + '"'
$scenarioText = ($ScenarioTokens | ForEach-Object { $_ }) -join ' '
$cmdLine = "$quotedMakeBat $scenarioText"

Push-Location $birpDevRoot
try {
    $cmdOutput = @(& cmd.exe /c $cmdLine)
    $exitCode = $LASTEXITCODE
    foreach ($line in $cmdOutput) {
        Write-Host $line
    }
}
finally {
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
$reportPath = Join-Path $buildLogsDir ("make-bat-test-report-" + $scenarioSlug + "-" + $stamp + ".txt")

$summaryLines = New-Object 'System.Collections.Generic.List[string]'
$summaryLines.Add('MAKE.BAT single-scenario test report') | Out-Null
$summaryLines.Add(("Timestamp: " + (Get-Date).ToString('s'))) | Out-Null
$summaryLines.Add(("Scenario: " + $Name)) | Out-Null
$summaryLines.Add(("MAKE.BAT: " + $MakeBatPath)) | Out-Null
$summaryLines.Add(("Status: " + $status)) | Out-Null
$summaryLines.Add(("ExitCode: " + $exitCode)) | Out-Null
$summaryLines.Add(("LogFile: " + $selectedLog)) | Out-Null
if ($errors.Count -gt 0) {
    $summaryLines.Add(("Issues: " + [string]::Join('; ', $errors))) | Out-Null
}

Set-Content -Path $reportPath -Value $summaryLines -Encoding ASCII
Write-Host "Report: $reportPath" -ForegroundColor Cyan

if ($status -eq 'FAIL') {
    exit 1
}

exit 0
