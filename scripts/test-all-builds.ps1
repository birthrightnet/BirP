<#
.SYNOPSIS
Runs all MAKE.BAT build scenario tests by executing each scenario build script and summarizing the results.

.DESCRIPTION
Invokes 6 scenario-specific build tests and aggregates pass/fail results.

.PARAMETER ContinueOnFailure
Continue executing all scenarios after a failure. By default, execution stops on first failed scenario.

.PARAMETER SkipToolchainCheck
Skips checking for required toolchain commands (wmake/wcc386/wpp386) in each scenario script.

.PARAMETER MakeBatPath
Optional path override to MAKE.BAT. Defaults to birp-dev\MAKE.BAT from repository root.

.PARAMETER MaxDiagnosticLines
Maximum warning/error lines captured per scenario for the aggregate report.
Use 0 to keep counts only, or a negative value to disable truncation.

.PARAMETER ShowInformationalOutput
When set, prints all scenario output lines to the terminal. By default, only warnings/errors and harness summary lines are shown.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-builds.ps1
#>

[CmdletBinding()]
param(
    [switch]$ContinueOnFailure,
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath,
    [int]$MaxDiagnosticLines = 200,
    [switch]$ShowInformationalOutput
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
    'build-win-release.ps1',
    'build-win-debug.ps1',
    'build-chared-release.ps1',
    'build-chared-debug.ps1',
    'build-dos-release.ps1',
    'build-dos-debug.ps1'
)

Write-Host '===============================================================================' -ForegroundColor Cyan
Write-Host '==        Test all scenarios (WIN, DOS, RELEASE, DEBUG, CHARED)              ==' -ForegroundColor Cyan
Write-Host '===============================================================================' -ForegroundColor Cyan
if (-not [string]::IsNullOrWhiteSpace($MakeBatPath)) {
    Write-Host "MAKE.BAT override: $MakeBatPath" -ForegroundColor Cyan
}
Write-Host "Build scripts to test: $($scenarioScripts.Count)" -ForegroundColor Cyan
Write-Host ''
Write-Host 'Please be patient - the Gorgon demands it!' -ForegroundColor Yellow
Write-Host ''

$results = New-Object 'System.Collections.Generic.List[object]'

foreach ($scriptName in $scenarioScripts) {
    $scenarioStartMessage = "[RUN] $scriptName"
    Write-Host $scenarioStartMessage -ForegroundColor Cyan

    $scriptPath = Join-Path $scriptDir $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $msg = "Missing build script: $scriptPath"
        Write-Host "[FAIL] $scriptName" -ForegroundColor Red
        Write-Host "       - $msg" -ForegroundColor Red

        [void]$results.Add([PSCustomObject]@{
            Name = $scriptName
            StartMessage = $scenarioStartMessage
            Status = 'FAIL'
            ExitCode = 1
            WarningCount = 0
            ErrorCount = 1
            WarningLines = @()
            ErrorLines = @($msg)
            Issues = $msg
        })

        if (-not $ContinueOnFailure) {
            break
        }

        Write-Host ''
        continue
    }

    $scriptArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    if ($SkipToolchainCheck) {
        $scriptArgs += '-SkipToolchainCheck'
    }
    if (-not [string]::IsNullOrWhiteSpace($MakeBatPath)) {
        $scriptArgs += '-MakeBatPath'
        $scriptArgs += $MakeBatPath
    }

    $outputRaw = @(& powershell @scriptArgs *>&1)
    $output = @($outputRaw | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE

    $scenarioReportPath = $null
    foreach ($line in $output) {
        if ($line -match '^Report:\s*(.+)$') {
            $scenarioReportPath = $matches[1].Trim()
        }
    }

    $allWarningLines = @($output | Where-Object { $_ -match 'Warning!|Warning\(' })
    $allErrorLines = @($output | Where-Object { $_ -match 'Error!|Error\(' })

    $warningCount = $allWarningLines.Count
    $errorCount = $allErrorLines.Count

    $warningLines = $allWarningLines
    $errorLines = $allErrorLines

    if ($MaxDiagnosticLines -ge 0) {
        $warningLines = @($warningLines | Select-Object -First $MaxDiagnosticLines)
        $errorLines = @($errorLines | Select-Object -First $MaxDiagnosticLines)
    }

    foreach ($line in $output) {
        if ($ShowInformationalOutput -or ($line -match 'Warning!|Warning\(|Error!|Error\(')) {
            Write-Host $line
        }
    }

    $status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
    if ($status -eq 'PASS') {
        Write-Host "[PASS] $scriptName" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $scriptName" -ForegroundColor Red
    }

    $diagColor = if ($warningCount -gt 0 -or $errorCount -gt 0) { 'Yellow' } else { 'DarkCyan' }
    Write-Host "       - Diagnostics: warnings=$warningCount errors=$errorCount" -ForegroundColor $diagColor

    $issues = New-Object 'System.Collections.Generic.List[string]'
    if ($exitCode -ne 0) {
        $issues.Add("Exit code was $exitCode") | Out-Null
    }
    if ($warningCount -gt 0 -or $errorCount -gt 0) {
        $issues.Add("Diagnostics: warnings=$warningCount errors=$errorCount") | Out-Null
    }

    [void]$results.Add([PSCustomObject]@{
        Name = $scriptName
        StartMessage = $scenarioStartMessage
        Status = $status
        ExitCode = $exitCode
        WarningCount = $warningCount
        ErrorCount = $errorCount
        WarningLines = $warningLines
        ErrorLines = $errorLines
            ScenarioReportPath = $scenarioReportPath
        Issues = [string]::Join('; ', $issues)
    })

    if (($status -eq 'FAIL') -and (-not $ContinueOnFailure)) {
        Write-Host ''
        Write-Host 'Stopping on first failure. Use -ContinueOnFailure to run all scenarios.' -ForegroundColor Yellow
        break
    }

    Write-Host ''
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $buildLogsDir ("build-report-" + $stamp + ".txt")

$summaryLines = New-Object 'System.Collections.Generic.List[string]'
$summaryLines.Add('Test all MAKE.BAT scenarios report') | Out-Null
$summaryLines.Add(("Timestamp: " + (Get-Date).ToString('s'))) | Out-Null
$summaryLines.Add(("MAKE.BAT: " + $MakeBatPath)) | Out-Null
$summaryLines.Add('') | Out-Null

$passCount = ($results | Where-Object { $_.Status -eq 'PASS' } | Measure-Object).Count
$failCount = ($results | Where-Object { $_.Status -eq 'FAIL' } | Measure-Object).Count
$summaryLines.Add(("Results: PASS=" + $passCount + " FAIL=" + $failCount)) | Out-Null
$summaryLines.Add('') | Out-Null

foreach ($item in $results) {
    if (-not [string]::IsNullOrWhiteSpace($item.StartMessage)) {
        $summaryLines.Add($item.StartMessage) | Out-Null
    }
    $summaryLines.Add(("[" + $item.Status + "] " + $item.Name)) | Out-Null
    $summaryLines.Add(("  ExitCode: " + $item.ExitCode)) | Out-Null
    $summaryLines.Add(("  Warnings: " + $item.WarningCount)) | Out-Null
    $summaryLines.Add(("  Errors: " + $item.ErrorCount)) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($item.Issues)) {
        $summaryLines.Add(("  Issues: " + $item.Issues)) | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($item.ScenarioReportPath)) {
        $summaryLines.Add(("  ScenarioReport: " + $item.ScenarioReportPath)) | Out-Null
    }
    else {
        $summaryLines.Add('  ScenarioReport: <not found in scenario output>') | Out-Null
    }

    if ($item.WarningLines -and $item.WarningLines.Count -gt 0) {
        $summaryLines.Add('  WarningLines:') | Out-Null
        foreach ($line in $item.WarningLines) {
            $summaryLines.Add(("    - " + $line)) | Out-Null
        }
    }

    if ($item.ErrorLines -and $item.ErrorLines.Count -gt 0) {
        $summaryLines.Add('  ErrorLines:') | Out-Null
        foreach ($line in $item.ErrorLines) {
            $summaryLines.Add(("    - " + $line)) | Out-Null
        }
    }

    $summaryLines.Add('') | Out-Null
}

Set-Content -Path $reportPath -Value $summaryLines -Encoding ASCII

Write-Host '=== Summary ===' -ForegroundColor Cyan
Write-Host "PASS: $passCount" -ForegroundColor Green
Write-Host "FAIL: $failCount" -ForegroundColor Red
Write-Host "Report: $reportPath" -ForegroundColor Cyan
Write-Host 'Detailed scenario reports:' -ForegroundColor Cyan
foreach ($item in $results) {
    if (-not [string]::IsNullOrWhiteSpace($item.ScenarioReportPath)) {
        Write-Host "  - $($item.Name): $($item.ScenarioReportPath)" -ForegroundColor Cyan
    }
    else {
        Write-Host "  - $($item.Name): <not found in scenario output>" -ForegroundColor DarkYellow
    }
}

if ($failCount -gt 0) {
    exit 1
}

exit 0
