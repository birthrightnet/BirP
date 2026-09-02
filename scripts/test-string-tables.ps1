<#
test-string-tables.ps1

Checks the menu string tables against the string number list the game compiles
against. Needs no game data and no game run.

Checks:

  1. Enum in step   - regenerating the string numbers from STRDAT.TXT produces
                      exactly the committed STRENUM.H. A committed list that
                      does not match the text file is either hand-edited or
                      stale, and the build silently replaces it.
  2. Same keys      - the English, French and German files define the same keys
                      in the same order. The menus pick a word by counting on
                      from the first choice in a group, so a group ordered
                      differently in one language shows the wrong word there.

Menus that count on from a base string are the reason order matters. A group
listed in the wrong order sends the count past the end of the group, and the
game then shows an unrelated string in its place.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-string-tables.ps1
  Options:
    -StrmakePath <path>  explicit path to strmake.exe (default: source\strmake.exe)

Check 1 needs strmake.exe, which the build produces. Run a build first, or pass
one in. Check 2 always runs.

Exit code 0 on pass, 1 on any failure.
#>

param(
    [string]$StrmakePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$sourceDir = Join-Path $repoRoot 'source'

$script:Failures = New-Object System.Collections.Generic.List[string]

function Write-Check([string]$Title) {
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        $script:Failures.Add($Message)
    }
}

# --- Check 1: the committed string numbers match the text file ---

Write-Check 'Check 1: string numbers in step with STRDAT.TXT'

if (-not $StrmakePath) { $StrmakePath = Join-Path $sourceDir 'strmake.exe' }

if (-not (Test-Path -LiteralPath $StrmakePath)) {
    Write-Host "  [SKIP] strmake.exe not found at $StrmakePath" -ForegroundColor Yellow
    Write-Host '         Run a build first, or pass -StrmakePath. Check 2 still runs.' -ForegroundColor Yellow
} else {
    $work = Join-Path $repoRoot 'build-artifacts\string-table-check'
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    # strmake reads strdat.txt from the working directory and writes the
    # regenerated list beside it as strenum.new.
    Copy-Item -LiteralPath (Join-Path $sourceDir 'STRDAT.TXT') -Destination (Join-Path $work 'strdat.txt') -Force
    Copy-Item -LiteralPath $StrmakePath -Destination (Join-Path $work 'strmake.exe') -Force

    Push-Location $work
    try {
        & '.\strmake.exe' | Out-Null
    } finally {
        Pop-Location
    }

    # strmake writes strenum.new, then renames it to strenum.h when no list is
    # already there to compare against. The working directory starts empty, so
    # the freshly generated list always lands as strenum.h.
    $generated = Join-Path $work 'strenum.h'
    Assert-True (Test-Path -LiteralPath $generated) 'strmake produced a string number list'

    if (Test-Path -LiteralPath $generated) {
        $want = (Get-Content -LiteralPath $generated) -join "`n"
        $have = (Get-Content -LiteralPath (Join-Path $sourceDir 'STRENUM.H')) -join "`n"
        $match = ($want -eq $have)
        Assert-True $match 'STRENUM.H matches what STRDAT.TXT generates'

        if (-not $match) {
            $wantLines = $want -split "`n"
            $haveLines = $have -split "`n"
            $shown = 0
            for ($i = 0; $i -lt [Math]::Max($wantLines.Count, $haveLines.Count); $i++) {
                $w = if ($i -lt $wantLines.Count) { $wantLines[$i] } else { '<missing>' }
                $h = if ($i -lt $haveLines.Count) { $haveLines[$i] } else { '<missing>' }
                if ($w -ne $h) {
                    Write-Host "         line $($i + 1): committed '$($h.Trim())' but STRDAT.TXT gives '$($w.Trim())'" -ForegroundColor Yellow
                    $shown++
                    if ($shown -ge 10) { Write-Host '         ...' -ForegroundColor Yellow; break }
                }
            }
            Write-Host '         Rebuild to regenerate it, and commit the result.' -ForegroundColor Yellow
        }
    }
}

# --- Check 2: the three languages agree ---

Write-Check 'Check 2: the three languages define the same keys in the same order'

function Get-StringKeys([string]$Path) {
    $keys = New-Object System.Collections.Generic.List[string]
    # latin-1 round-trips every byte, so the accented French and German text is
    # read without being mangled or rejected.
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::GetEncoding('iso-8859-1'))) {
        $t = $line.Trim()
        if ($t -eq '') { continue }
        if ($t.StartsWith('//')) { continue }
        if ($t -eq 'END' -or $t -eq 'NEWBLOCK') { continue }
        $m = [regex]::Match($t, '^([A-Za-z_][A-Za-z0-9_]*)\s')
        if ($m.Success) { $keys.Add($m.Groups[1].Value) }
    }
    return $keys
}

$langs = @(
    @{ Name = 'English'; Path = Join-Path $sourceDir 'STRDAT.TXT' },
    @{ Name = 'French';  Path = Join-Path $sourceDir 'STRDAT-F.TXT' },
    @{ Name = 'German';  Path = Join-Path $sourceDir 'STRDAT-G.TXT' }
)

$baseline = $null
foreach ($lang in $langs) {
    if (-not (Test-Path -LiteralPath $lang.Path)) {
        Assert-True $false "$($lang.Name) string file present"
        continue
    }

    $keys = Get-StringKeys $lang.Path
    Write-Host "  $($lang.Name): $($keys.Count) keys"

    if ($null -eq $baseline) {
        $baseline = @{ Name = $lang.Name; Keys = $keys }
        continue
    }

    Assert-True ($keys.Count -eq $baseline.Keys.Count) "$($lang.Name) defines the same number of keys as $($baseline.Name) ($($keys.Count) vs $($baseline.Keys.Count))"

    $limit = [Math]::Min($keys.Count, $baseline.Keys.Count)
    $firstDiff = -1
    for ($i = 0; $i -lt $limit; $i++) {
        if ($keys[$i] -ne $baseline.Keys[$i]) { $firstDiff = $i; break }
    }

    $ordered = ($firstDiff -lt 0)
    $detail = ''
    if (-not $ordered) {
        $detail = " (entry $($firstDiff + 1): $($baseline.Name) has $($baseline.Keys[$firstDiff]), $($lang.Name) has $($keys[$firstDiff]))"
    }
    Assert-True $ordered "$($lang.Name) lists the same keys in the same order as $($baseline.Name)$detail"
}

# --- Summary ---

Write-Check 'Summary'

if ($script:Failures.Count -gt 0) {
    Write-Host "$($script:Failures.Count) check(s) failed:" -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}

Write-Host 'String tables are consistent.' -ForegroundColor Green
exit 0
