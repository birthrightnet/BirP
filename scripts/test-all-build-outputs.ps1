<#
.SYNOPSIS
Runs all MAKE.BAT build-output scenario tests.

.DESCRIPTION
Invokes 8 scenario-specific build-output tests and aggregates pass/fail results.

.PARAMETER ContinueOnFailure
Continue executing all scenarios after a failure. By default, execution stops on first failed scenario.

.PARAMETER SkipToolchainCheck
Skips checking for required toolchain commands (wmake/wcc386/wpp386) in each scenario script.

.PARAMETER MakeBatPath
Optional path override to MAKE.BAT. Defaults to birp-dev\MAKE.BAT from repository root.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-build-outputs.ps1
#>

[CmdletBinding()]
param(
    [switch]$ContinueOnFailure,
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$birpDevRoot = Join-Path $repoRoot 'birp-dev'
$buildLogsDir = Join-Path $birpDevRoot 'build-artifacts\logs'

if (-not (Test-Path -LiteralPath $buildLogsDir)) {
    New-Item -ItemType Directory -Path $buildLogsDir -Force | Out-Null
}

$scenarioScripts = @(
    'test-build-output-win95-default.ps1',
    'test-build-output-win95-release.ps1',
    'test-build-output-win95-debug.ps1',
    'test-build-output-win95-profile.ps1',
    'test-build-output-dos-default.ps1',
    'test-build-output-dos-release.ps1',
    'test-build-output-dos-debug.ps1',
    'test-build-output-dos-profile.ps1'
)

Write-Host '=== MAKE.BAT build-output test harness (all scenarios) ===' -ForegroundColor Cyan
Write-Host "MAKE.BAT override: $MakeBatPath" -ForegroundColor Cyan
Write-Host "Cases: $($scenarioScripts.Count)" -ForegroundColor Cyan
Write-Host ''

$results = New-Object 'System.Collections.Generic.List[object]'

foreach ($scriptName in $scenarioScripts) {
    $scriptPath = Join-Path $scriptDir $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $msg = "Missing scenario script: $scriptPath"
        Write-Host "[FAIL] $scriptName" -ForegroundColor Red
        Write-Host "       - $msg" -ForegroundColor Red

        [void]$results.Add([PSCustomObject]@{
            Name = $scriptName
            Status = 'FAIL'
            ExitCode = 1
            Issues = $msg
        })

        if (-not $ContinueOnFailure) {
            break
        }

        Write-Host ''
        continue
    }

    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    if ($SkipToolchainCheck) {
        $args += '-SkipToolchainCheck'
    }
    if (-not [string]::IsNullOrWhiteSpace($MakeBatPath)) {
        $args += '-MakeBatPath'
        $args += $MakeBatPath
    }

    $output = @(& powershell @args)
    $exitCode = $LASTEXITCODE

    foreach ($line in $output) {
        Write-Host $line
    }

    $status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
    if ($status -eq 'PASS') {
        Write-Host "[PASS] $scriptName" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $scriptName" -ForegroundColor Red
    }

    [void]$results.Add([PSCustomObject]@{
        Name = $scriptName
        Status = $status
        ExitCode = $exitCode
        Issues = if ($exitCode -eq 0) { '' } else { "Exit code was $exitCode" }
    })

    if (($status -eq 'FAIL') -and (-not $ContinueOnFailure)) {
        Write-Host ''
        Write-Host 'Stopping on first failure. Use -ContinueOnFailure to run all scenarios.' -ForegroundColor Yellow
        break
    }

    Write-Host ''
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $buildLogsDir ("make-bat-test-report-" + $stamp + ".txt")

$summaryLines = New-Object 'System.Collections.Generic.List[string]'
$summaryLines.Add('MAKE.BAT test report') | Out-Null
$summaryLines.Add(("Timestamp: " + (Get-Date).ToString('s'))) | Out-Null
$summaryLines.Add(("MAKE.BAT: " + $MakeBatPath)) | Out-Null
$summaryLines.Add('') | Out-Null

$passCount = ($results | Where-Object { $_.Status -eq 'PASS' } | Measure-Object).Count
$failCount = ($results | Where-Object { $_.Status -eq 'FAIL' } | Measure-Object).Count
$summaryLines.Add(("Results: PASS=" + $passCount + " FAIL=" + $failCount)) | Out-Null
$summaryLines.Add('') | Out-Null

foreach ($item in $results) {
    $summaryLines.Add(("[" + $item.Status + "] " + $item.Name)) | Out-Null
    $summaryLines.Add(("  ExitCode: " + $item.ExitCode)) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($item.Issues)) {
        $summaryLines.Add(("  Issues: " + $item.Issues)) | Out-Null
    }
    $summaryLines.Add('') | Out-Null
}

Set-Content -Path $reportPath -Value $summaryLines -Encoding ASCII

Write-Host '=== Summary ===' -ForegroundColor Cyan
Write-Host "PASS: $passCount" -ForegroundColor Green
Write-Host "FAIL: $failCount" -ForegroundColor Red
Write-Host "Report: $reportPath" -ForegroundColor Cyan

if ($failCount -gt 0) {
    exit 1
}

exit 0
