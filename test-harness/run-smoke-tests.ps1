<#
.SYNOPSIS
    Runs a BirP smoke-test scenario against the Windows game (issue #58).

.DESCRIPTION
    Two run modes:

      Desktop (default) - runs on THIS machine's desktop. Launches WINBR.EXE from
        the install dir, runs the scenario, and writes a report. A run moves the
        real mouse and takes focus, so do not use the machine during a run.

      VM - runs everything inside a throwaway Windows virtual machine so your
        desktop is untouched: provision a guest from the Windows OS image, install
        the game (official CD content + our patch) from the CD image via our
        installer, run the scenario in the guest, and collect results. (Deferred -
        see docs-58: needs host disk space and a non-interactive installer.)

    Both modes install/use the official game from the Birthright CD image
    (BIRTHRT_CD_ISO). VM mode additionally needs the Windows OS image
    (BIRTHRT_WIN_ISO); Desktop mode does not.

.PARAMETER Mode
    Desktop (default) or VM.

.PARAMETER Scenario
    Scenario name (file .\scenarios\<name>.ps1). Default: boot-and-menus.

.PARAMETER Install
    Desktop mode: before testing, install the game fresh from the CD image
    (BIRTHRT_CD_ISO) via our installer into the install dir, instead of testing the
    already-deployed game. (Requires the non-interactive installer - see docs-58.)

.PARAMETER InstallDir
    Game install dir. Default: BIRTHRT_INSTALL_DIR env var, else C:\Sierra\BIRTHRT.
    With -Install, this is where the fresh install is written.

.PARAMETER CdIso
    Path to the Birthright CD .iso. Default: BIRTHRT_CD_ISO env var.

.PARAMETER WinIso
    VM mode only: path to the Windows OS .iso. Default: BIRTHRT_WIN_ISO env var.

.PARAMETER ArtifactsRoot
    Where per-run folders are written. Default: ..\build-artifacts\test-harness.

.PARAMETER KeepGame
    Leave the game running after the scenario (default: terminate it).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File run-smoke-tests.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File run-smoke-tests.ps1 -Mode Desktop -Scenario boot-and-menus

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File run-smoke-tests.ps1 -Mode VM
#>
[CmdletBinding()]
param(
    [ValidateSet('Desktop', 'VM')]
    [string]$Mode = 'Desktop',
    [string]$Scenario = 'boot-and-menus',
    [switch]$Install,
    [string]$InstallDir,
    [string]$CdIso,
    [string]$WinIso,
    [string]$ArtifactsRoot,
    [int]$WindowTimeoutSec = 90,
    [switch]$KeepGame,
    [switch]$UpdateReferences,
    [double]$ReferenceThreshold = 0.05
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here 'HarnessCore.psm1') -Force

if ($Mode -eq 'VM') {
    # VM mode is scaffolded but not yet enabled (deferred on host disk space; see
    # docs-58 Q11). The install step is now scriptable via BIRTHRT_CD_PATH (Q14).
    Import-Module (Join-Path $here 'modes\VmMode.psm1') -Force
    Invoke-BirpVmMode -Scenario $Scenario -CdIso $CdIso -WinIso $WinIso -HarnessDir $here
    exit 2
}

# ----------------------------- Desktop mode --------------------------------
$InstallDir = Get-BirpInstallDir -InstallDir $InstallDir

if ($Install) {
    # Fresh install from the CD image via our installer (installer honors
    # BIRTHRT_CD_PATH, see docs-58 Q14). Needs the installer built under
    # build-artifacts. -InstallDir should be a throwaway path: this overwrites it.
    Import-Module (Join-Path $here 'modes\InstallGame.psm1') -Force
    Install-BirpGameFromCd -CdIso (Get-BirpCdIso -CdIso $CdIso) -InstallDir $InstallDir -HarnessDir $here
}
$scenarioFile = Join-Path $here "scenarios\$Scenario.ps1"
if (-not (Test-Path $scenarioFile)) { throw "Scenario not found: $scenarioFile" }
if (-not $ArtifactsRoot) { $ArtifactsRoot = Join-Path $here '..\build-artifacts\test-harness' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $ArtifactsRoot "$Scenario-$stamp"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

# Committed per-scenario reference images (baselines for Q3 visual checks).
$refDir = Join-Path $here "references\$Scenario"

# ---- run state + recorder helpers (closed over by the $ctx script blocks) ----
$Run = [ordered]@{
    Scenario   = $Scenario
    InstallDir = $InstallDir
    RunDir     = $runDir
    StartTime  = Get-Date
    Steps      = New-Object System.Collections.ArrayList
    Passed     = $true
    ShotIndex  = 0
    ExpectExit = $false   # set by a scenario that intentionally quits the game
}

function Write-RunLog([string]$msg) {
    $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $msg
    Write-Host $line
    Add-Content -Path (Join-Path $runDir 'run.log') -Value $line
}

$ctx = @{
    InstallDir = $InstallDir
    RunDir     = $runDir
    RefDir     = $refDir
    Process    = $null
    Hwnd       = [IntPtr]::Zero
    StartTime  = $Run.StartTime

    # Capture a labelled screenshot into the run folder; returns its path.
    # Pass -Reference $true on a STATIC screen to also check it against (or, with
    # -UpdateReferences, refresh) the committed baseline. Do not reference-check
    # animated screens (e.g. the attract/title loop).
    Shot = {
        param([string]$Name, [bool]$Reference = $false, [double[]]$Region = $null)
        $Run.ShotIndex++
        $safe = ($Name -replace '[^\w\-]', '_')
        $file = Join-Path $runDir ('{0:D2}-{1}.png' -f $Run.ShotIndex, $safe)
        Save-BirpFrame -Hwnd $ctx.Hwnd -Path $file | Out-Null
        Write-RunLog "shot: $Name -> $(Split-Path -Leaf $file)"

        if ($Reference) {
            $refFile = Join-Path $refDir ($safe + '.png')
            if ($UpdateReferences) {
                if (-not (Test-Path $refDir)) { New-Item -ItemType Directory -Path $refDir -Force | Out-Null }
                Copy-Item $file $refFile -Force
                Write-RunLog "reference updated: $safe.png"
                [void]$Run.Steps.Add([pscustomobject]@{ Type = 'note'; Ok = $true; Message = "Reference captured: $safe.png" })
            }
            elseif (Test-Path $refFile) {
                # Compare only the static region when one is given (avoids animated
                # backdrops like the scrolling menu map); otherwise the full frame.
                if ($Region) { $diff = Compare-BirpFrameRegion -PathA $refFile -PathB $file -Region $Region }
                else { $diff = Compare-BirpFrame -PathA $refFile -PathB $file }
                $where = if ($Region) { " region [$($Region -join ',')]" } else { '' }
                $ok = ($diff -le $ReferenceThreshold)
                [void]$Run.Steps.Add([pscustomobject]@{ Type = 'assert'; Ok = $ok; Message = ("Screen '$Name'$where matches reference ({0:P1} diff, threshold {1:P0})" -f $diff, $ReferenceThreshold) })
                if ($ok) { Write-RunLog ("PASS: '$Name' matches reference ({0:P1} diff)" -f $diff) }
                else { $Run.Passed = $false; Write-RunLog ("FAIL: '$Name' differs from reference ({0:P1} diff > {1:P0})" -f $diff, $ReferenceThreshold) }
            }
            else {
                Write-RunLog "note: no reference for '$Name' (run with -UpdateReferences to create one)"
                [void]$Run.Steps.Add([pscustomobject]@{ Type = 'note'; Ok = $true; Message = "No reference baseline for '$Name' (run -UpdateReferences to create)" })
            }
        }
        return $file
    }
    # Record a pass/fail check.
    Assert = {
        param([bool]$Condition, [string]$Message)
        $ok = [bool]$Condition
        [void]$Run.Steps.Add([pscustomobject]@{ Type = 'assert'; Ok = $ok; Message = $Message })
        if ($ok) { Write-RunLog "PASS: $Message" }
        else { $Run.Passed = $false; Write-RunLog "FAIL: $Message" }
    }
    # Free-form note in the report.
    Note = {
        param([string]$Message)
        [void]$Run.Steps.Add([pscustomobject]@{ Type = 'note'; Ok = $true; Message = $Message })
        Write-RunLog $Message
    }
    # Signal that the scenario is about to quit the game on purpose (e.g. via the
    # menu's Quit -> Yes). The post-run health check then treats a clean process
    # exit as the expected outcome instead of flagging it as a crash.
    ExpectExit = {
        $Run.ExpectExit = $true
        Write-RunLog "Scenario expects the game to quit now (clean exit expected)."
    }
}

Write-RunLog "Scenario '$Scenario'  install='$InstallDir'  run='$runDir'"
Write-Host "NOTE: this run controls the real mouse/keyboard. Do not touch the machine until it finishes." -ForegroundColor Yellow

$proc = $null
try {
    Write-RunLog "Launching WINBR.EXE ..."
    $proc = Start-BirpGame -InstallDir $InstallDir
    $ctx.Process = $proc
    Write-RunLog "PID $($proc.Id). Waiting for game window (up to ${WindowTimeoutSec}s; load is slow) ..."
    $ctx.Hwnd = Wait-BirpWindow -Process $proc -TimeoutSec $WindowTimeoutSec
    $sz = Get-BirpClientSize -Hwnd $ctx.Hwnd
    Write-RunLog "Window up: client $($sz.Width)x$($sz.Height)."

    # ---- run the scenario ----
    . $scenarioFile
    if (-not (Get-Command Invoke-BirpScenario -ErrorAction SilentlyContinue)) {
        throw "Scenario '$Scenario' does not define Invoke-BirpScenario."
    }
    Invoke-BirpScenario -Ctx $ctx

    # ---- post-run health checks ----
    if ($Run.ExpectExit) {
        # The scenario quit the game on purpose. A clean exit is the expected
        # outcome: the process should end within a short window and no Fatal.err
        # should appear. Do not treat the exit itself as a crash.
        $exited = $proc.WaitForExit(15000)
        if (-not $exited) {
            $Run.Passed = $false; Write-RunLog "FAIL: game did not exit after the scenario asked it to quit."
            [void]$Run.Steps.Add([pscustomobject]@{ Type='assert'; Ok=$false; Message='Game did not exit after Quit.' })
        } else {
            Write-RunLog "PASS: game quit cleanly (exit code $($proc.ExitCode))."
            [void]$Run.Steps.Add([pscustomobject]@{ Type='assert'; Ok=$true; Message="Game quit cleanly (exit code $($proc.ExitCode))." })
        }
        # Still check for a crash dump, but pass no process so the exit is not itself flagged.
        $crash = Test-BirpCrash -InstallDir $InstallDir -Process $null -SinceTime $Run.StartTime
    } else {
        $crash = Test-BirpCrash -InstallDir $InstallDir -Process $proc -SinceTime $Run.StartTime
    }
    if ($crash) { $Run.Passed = $false; Write-RunLog "FAIL: $crash" ; [void]$Run.Steps.Add([pscustomobject]@{ Type='assert'; Ok=$false; Message=$crash }) }
    else { Write-RunLog "PASS: no crash / Fatal.err during run." }

    $issues = Get-BirpLogIssues -InstallDir $InstallDir -SinceTime $Run.StartTime
    if ($issues.Count -gt 0) {
        Set-Content -Path (Join-Path $runDir 'log-issues.txt') -Value $issues
        Write-RunLog "WARN: $($issues.Count) ERROR/WARN/FATAL log line(s) during run (see log-issues.txt)."
        # ERROR/FATAL fail the run; WARN is recorded but non-fatal.
        $hard = $issues | Where-Object { $_ -match '\](\s*)(ERROR|FATAL)' }
        if ($hard.Count -gt 0) { $Run.Passed = $false; [void]$Run.Steps.Add([pscustomobject]@{ Type='assert'; Ok=$false; Message="$($hard.Count) ERROR/FATAL log line(s)" }) }
    } else {
        Write-RunLog "PASS: no ERROR/WARN/FATAL log lines during run."
    }
}
catch {
    $Run.Passed = $false
    Write-RunLog "EXCEPTION: $($_.Exception.Message)"
    [void]$Run.Steps.Add([pscustomobject]@{ Type = 'assert'; Ok = $false; Message = "Exception: $($_.Exception.Message)" })
    # Best-effort crash screenshot.
    try { if ($ctx.Hwnd -ne [IntPtr]::Zero) { Save-BirpFrame -Hwnd $ctx.Hwnd -Path (Join-Path $runDir '99-exception.png') | Out-Null } } catch {}
}
finally {
    if (-not $KeepGame) { Stop-BirpGame -Process $proc; Write-RunLog "Game terminated." }
    else { Write-RunLog "Left game running (-KeepGame)." }
}

# ---- write report ----
$elapsed = [int]((Get-Date) - $Run.StartTime).TotalSeconds
$summary = if ($Run.Passed) { 'PASS' } else { 'FAIL' }
$report = New-Object System.Collections.ArrayList
[void]$report.Add("BirP smoke test report")
[void]$report.Add("======================")
[void]$report.Add("Scenario : $Scenario")
[void]$report.Add("Result   : $summary")
[void]$report.Add("When     : $($Run.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))  (${elapsed}s)")
[void]$report.Add("Install  : $InstallDir")
[void]$report.Add("Run dir  : $runDir")
[void]$report.Add("")
[void]$report.Add("Steps:")
foreach ($s in $Run.Steps) {
    $tag = switch ($s.Type) { 'assert' { if ($s.Ok) { '[PASS]' } else { '[FAIL]' } } default { '[note]' } }
    [void]$report.Add("  $tag $($s.Message)")
}
$reportPath = Join-Path $runDir 'report.txt'
Set-Content -Path $reportPath -Value $report

Write-Host ""
Write-Host "===== $summary =====" -ForegroundColor ($(if ($Run.Passed) { 'Green' } else { 'Red' }))
Write-Host "Report: $reportPath"
Write-Host "Artifacts: $runDir"

exit ($(if ($Run.Passed) { 0 } else { 1 }))
