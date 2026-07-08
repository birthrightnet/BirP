<#
test-installer.ps1

Automated installer tests (issues #89 / #122; CI plan in
bugs-and-enhancement-requests/docs-89-*.md). Layers, cheapest first:

  1. Compile gate       - stage placeholder payloads, compile installer.iss and
                          selftests.iss with iscc, gate on the exit code.
  2. String lint        - every {cm:X} / CustomMessage('X') reference in the
                          .iss sources must exist in all three isl files, and
                          the three isl files must define the same key set.
  3. Self-tests         - run the compiled selftests.exe over fixture folders
                          (pure helpers: DirHasGame, IsDangerousPath, ...).
  5. CD auto-detect     - subst a drive letter to a fake CD folder so DetectCD
                          has a real drive root to find (part of the self-test
                          run; no ISO or physical disc needed).
  4. Scenario matrix    - run the compiled installer silently against seeded
                          directory states (fresh INSTALL, PATCH over an
                          existing game, PATCH refusal on an empty dir,
                          idempotent re-PATCH) and assert the results.
  6. Uninstall safety   - uninstall silently and assert only the game directory
                          is touched: a sentinel in the parent survives, and
                          saves/config survive unless deletion is requested.

Needs no game data, no ISO, and no elevation: installer runs use /CURRENTUSER.
All work happens under build-artifacts\installer-tests (not source controlled).

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-installer.ps1
  Options:
    -IsccPath <path>   explicit path to ISCC.exe (default: PATH, then known
                       install locations)
    -SkipScenarios     run only layers 1-3/5 (no installer executions)

Exit code 0 on pass, 1 on any failure.
#>

param(
    [string]$IsccPath,
    [switch]$SkipScenarios
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$installerDir = Join-Path $repoRoot 'installer'
$stagedBinDir = Join-Path $repoRoot 'build-artifacts\binaries\Installer'
$patch1004Dir = (Join-Path $repoRoot '..\birp-dependencies\Patch1004')
$workspace = Join-Path $repoRoot 'build-artifacts\installer-tests'
$outDir = Join-Path $workspace 'out'

$script:Failures = New-Object System.Collections.Generic.List[string]
$script:AssertCount = 0

function Write-Layer([string]$Title) {
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Assert-True([bool]$Condition, [string]$Message) {
    $script:AssertCount++
    if ($Condition) {
        Write-Host "  PASS $Message"
    } else {
        Write-Host "  FAIL $Message" -ForegroundColor Red
        $script:Failures.Add($Message)
    }
}

function Get-FileHashHex([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Wait-Until([scriptblock]$Condition, [int]$TimeoutSec, [string]$What) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) { return $true }
        Start-Sleep -Milliseconds 500
    }
    Write-Host "  timed out after ${TimeoutSec}s waiting for: $What" -ForegroundColor Yellow
    return $false
}

# Run an exe with a controlled set of BIRTHRT_*/BIRP_* environment variables.
# Variables not named in $EnvVars are cleared for the child so scenarios cannot
# leak state into each other.
$managedEnvNames = @('BIRTHRT_CD_PATH', 'BIRTHRT_MODE', 'BIRTHRT_DELETE_SETTINGS',
                     'BIRP_SELFTEST_DIR', 'BIRP_SELFTEST_OUT', 'BIRP_SELFTEST_EXPECT_CD')
function Invoke-WithEnv([string]$Exe, [string[]]$Arguments, [hashtable]$EnvVars) {
    $saved = @{}
    foreach ($name in $managedEnvNames) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name, $null)
    }
    try {
        if ($null -ne $EnvVars) {
            foreach ($key in $EnvVars.Keys) {
                [Environment]::SetEnvironmentVariable($key, $EnvVars[$key])
            }
        }
        $proc = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru -WindowStyle Hidden
        # A hung silent run (e.g. an unsuppressed message box) must fail the
        # suite, not wedge it.
        if (-not $proc.WaitForExit(180000)) {
            Write-Host "  timeout: killing $([System.IO.Path]::GetFileName($Exe)) after 180s" -ForegroundColor Yellow
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Exe)
            Get-Process | Where-Object { $_.Name -like "$baseName*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            return -999
        }
        return $proc.ExitCode
    } finally {
        foreach ($name in $managedEnvNames) {
            [Environment]::SetEnvironmentVariable($name, $saved[$name])
        }
    }
}

# Prefer the real install locations over whatever is on PATH: chocolatey (CI)
# puts a shim iscc.exe in its bin folder, and the string lint needs the real
# install directory to find the compiler's built-in language files.
function Find-Iscc {
    if ($IsccPath) {
        if (Test-Path -LiteralPath $IsccPath) { return $IsccPath }
        throw "ISCC.exe not found at -IsccPath '$IsccPath'"
    }
    $candidates = @(
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    $cmd = Get-Command 'iscc' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'ISCC.exe (Inno Setup 6 compiler) not found. Install Inno Setup 6 or pass -IsccPath.'
}

# The directory holding the compiler's built-in Default.isl and Languages\.
# Falls back to the known install locations when the iscc in use is a shim.
function Find-InnoLanguageDir([string]$IsccExe) {
    $candidates = @(
        (Split-Path -Parent $IsccExe),
        'C:\Program Files (x86)\Inno Setup 6',
        'C:\Program Files\Inno Setup 6',
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $c 'Default.isl')) { return $c }
    }
    return $null
}

function New-PlaceholderFile([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding Ascii -NoNewline
}

# --- Setup: workspace, iscc, staged payloads ---

Write-Layer 'Setup'

$iscc = Find-Iscc
Write-Host "  iscc: $iscc"

if (Test-Path -LiteralPath $workspace) {
    Remove-Item -LiteralPath $workspace -Recurse -Force
}
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# Stage BirP release binaries the installer packs. Placeholders only where the
# real files are absent (a real release staging is never overwritten).
foreach ($name in @('CHARED.exe', 'NOVA.exe', 'WINBR.exe', 'STRDAT.DAT')) {
    $staged = Join-Path $stagedBinDir $name
    if (-not (Test-Path -LiteralPath $staged)) {
        New-PlaceholderFile $staged "BIRP-PLACEHOLDER $name"
        Write-Host "  staged placeholder: $staged"
    }
}

# Stage the installer icon. The original Sierra assets under source\RES are
# deliberately not committed (only .keep is tracked), so a fresh CI checkout has
# no BR4.ICO. iscc needs a valid icon file, so write a minimal 1x1 one.
$iconPath = Join-Path $repoRoot 'source\RES\BR4.ICO'
if (-not (Test-Path -LiteralPath $iconPath)) {
    $iconBytes = [byte[]](
        0, 0, 1, 0, 1, 0,                                                       # ICONDIR: 1 image
        1, 1, 0, 0, 1, 0, 32, 0, 48, 0, 0, 0, 22, 0, 0, 0,                      # ICONDIRENTRY: 1x1, 32bpp
        40, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 32, 0, 0, 0, 0, 0,           # BITMAPINFOHEADER
        8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        255, 0, 0, 255,                                                         # 1 XOR pixel
        0, 0, 0, 0                                                              # AND mask row
    )
    [System.IO.File]::WriteAllBytes($iconPath, $iconBytes)
    Write-Host "  staged placeholder icon: $iconPath"
}

# Stage the official 1.4 patch payload. On a dev machine the real payload exists
# in birp-dependencies; on a CI runner it does not, so create a small stand-in.
if (-not (Test-Path -LiteralPath $patch1004Dir)) {
    foreach ($name in @('WINBR.EXE', 'NOVA.EXE', 'STRDAT.DAT', 'README.TXT', 'SIERRA.INF', 'WADS\PATCH.WAD')) {
        New-PlaceholderFile (Join-Path $patch1004Dir $name) "PATCH1004-PLACEHOLDER $name"
    }
    Write-Host "  staged placeholder Patch1004 payload: $patch1004Dir"
}
$patch1004Dir = (Resolve-Path -LiteralPath $patch1004Dir).Path

# --- Layer 1: compile gate ---

Write-Layer 'Layer 1: compile gate (iscc)'

$setupExe = Join-Path $outDir 'BirpSetup-CI.exe'
$selftestsExe = Join-Path $outDir 'BirpInstallerSelfTests.exe'

& $iscc /Qp "/DMyAppVersion=v0.0.0.0" "/DMyAppSetupFile=BirpSetup-CI" "/O$outDir" (Join-Path $installerDir 'installer.iss')
Assert-True ($LASTEXITCODE -eq 0) 'installer.iss compiles'
& $iscc /Qp "/O$outDir" (Join-Path $installerDir 'selftests.iss')
Assert-True ($LASTEXITCODE -eq 0) 'selftests.iss compiles'
if ($script:Failures.Count -gt 0) {
    Write-Host 'Compile gate failed; skipping the remaining layers.' -ForegroundColor Red
    exit 1
}

# --- Layer 2: localized-string completeness lint ---

Write-Layer 'Layer 2: localized-string lint'

function Get-IslKeys([string]$Path) {
    $keys = New-Object System.Collections.Generic.HashSet[string]
    $section = ''
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        if ($section -eq 'CustomMessages' -and $trimmed -match '^([A-Za-z0-9_]+)=') {
            [void]$keys.Add($Matches[1])
        }
    }
    return , $keys
}

$issFiles = Get-ChildItem -LiteralPath $installerDir -Filter '*.iss' | ForEach-Object { $_.FullName }
$referenced = New-Object System.Collections.Generic.HashSet[string]
foreach ($file in $issFiles) {
    foreach ($line in (Get-Content -LiteralPath $file)) {
        foreach ($m in [regex]::Matches($line, "CustomMessage\(\s*'([A-Za-z0-9_]+)'")) {
            [void]$referenced.Add($m.Groups[1].Value)
        }
        foreach ($m in [regex]::Matches($line, '\{cm:([A-Za-z0-9_]+)')) {
            [void]$referenced.Add($m.Groups[1].Value)
        }
    }
}
Write-Host "  referenced custom-message keys: $($referenced.Count)"
Assert-True ($referenced.Count -gt 0) 'found custom-message references to lint'

# Built-in keys ship with the compiler (NameAndVersion, UninstallProgram, ...).
$innoDir = Find-InnoLanguageDir $iscc
Assert-True ($null -ne $innoDir) 'found the compiler language files (Default.isl)'
if ($null -eq $innoDir) { $innoDir = Split-Path -Parent $iscc }
$builtinIsl = @{
    'Default.isl' = (Join-Path $innoDir 'Default.isl')
    'French.isl'  = (Join-Path $innoDir 'Languages\French.isl')
    'German.isl'  = (Join-Path $innoDir 'Languages\German.isl')
}
$projectKeySets = @{}
foreach ($isl in @('Default.isl', 'French.isl', 'German.isl')) {
    $projectPath = Join-Path $installerDir "CustomMessages\$isl"
    $projectKeys = Get-IslKeys $projectPath
    $projectKeySets[$isl] = $projectKeys
    $allowed = [System.Collections.Generic.HashSet[string]]::new([string[]]@($projectKeys))
    $builtinPath = $builtinIsl[$isl]
    if (Test-Path -LiteralPath $builtinPath) {
        foreach ($k in (Get-IslKeys $builtinPath)) { [void]$allowed.Add($k) }
    } else {
        Write-Host "  note: compiler language file missing: $builtinPath" -ForegroundColor Yellow
    }
    $missing = @($referenced | Where-Object { -not $allowed.Contains($_) })
    Assert-True ($missing.Count -eq 0) "$isl defines every referenced key$(if ($missing.Count) { ' (missing: ' + ($missing -join ', ') + ')' })"
}

# The three project files must define the same keys, so a string added to
# Default.isl cannot silently ship untranslated.
$defaultKeys = $projectKeySets['Default.isl']
foreach ($isl in @('French.isl', 'German.isl')) {
    $theirs = $projectKeySets[$isl]
    $notTranslated = @($defaultKeys | Where-Object { -not $theirs.Contains($_) })
    $extra = @($theirs | Where-Object { -not $defaultKeys.Contains($_) })
    Assert-True ($notTranslated.Count -eq 0 -and $extra.Count -eq 0) "$isl key set matches Default.isl$(if ($notTranslated.Count) { ' (untranslated: ' + ($notTranslated -join ', ') + ')' })$(if ($extra.Count) { ' (extra: ' + ($extra -join ', ') + ')' })"
}

# --- Fake CD folder, generated from the [Files] section ---
# Parse installer.iss for every {code:GetCDPath} source so the fake CD always
# matches what the installer actually reads, even after future edits.

$fakeCd = Join-Path $workspace 'fakecd'
$cdRelPaths = @()
foreach ($line in (Get-Content -LiteralPath (Join-Path $installerDir 'installer.iss'))) {
    if ($line -match '^Source:\s*"\{code:GetCDPath\}\\([^"]+)"') {
        $cdRelPaths += $Matches[1]
    }
}
Assert-True ($cdRelPaths.Count -gt 0) 'parsed game-from-CD entries out of installer.iss'
foreach ($rel in $cdRelPaths) {
    $target = $rel -replace '\*', 'TEST'
    New-PlaceholderFile (Join-Path $fakeCd $target) "FAKECD $target"
}
Write-Host "  fake CD staged with $($cdRelPaths.Count) entries: $fakeCd"

# --- Layers 3 + 5: pure-logic self-tests, with a subst drive for DetectCD ---

Write-Layer 'Layers 3+5: self-tests (selftests.iss) with subst CD drive'

$fixtures = Join-Path $workspace 'selftest-fixtures'
New-PlaceholderFile (Join-Path $fixtures 'hasgame-winbr\WINBR.EXE') 'fixture'
New-PlaceholderFile (Join-Path $fixtures 'hasgame-nova\NOVA.EXE') 'fixture'
New-Item -ItemType Directory -Path (Join-Path $fixtures 'hasgame-empty') -Force | Out-Null

# DriveInfo lists every assigned letter, including optical drives with no media
# that Test-Path would misreport as free.
$usedLetters = @([System.IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpper() })
$substDrive = $null
foreach ($letter in @('B', 'M', 'N', 'O', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z')) {
    if ($usedLetters -notcontains $letter) { $substDrive = "${letter}:"; break }
}
Assert-True ($null -ne $substDrive) 'found a free drive letter for subst'

try {
    if ($substDrive) {
        subst $substDrive $fakeCd | Out-Null
        Write-Host "  subst $substDrive -> $fakeCd"
    }

    # Expected DetectCD result: the first drive root A..Z that holds WINBR.EXE
    # (normally the subst drive; computed the same way DetectCD scans, so a dev
    # machine with a real disc mounted still passes).
    $expectCd = ''
    foreach ($c in ([char]'A')..([char]'Z')) {
        $root = "$([char]$c):\"
        # Plain concatenation: Join-Path errors out on drive letters that do not exist.
        if (Test-Path -LiteralPath "${root}WINBR.EXE") { $expectCd = $root; break }
    }
    Assert-True ($expectCd -ne '') 'a drive root with WINBR.EXE exists for DetectCD'

    $selftestOut = Join-Path $workspace 'selftest-results.txt'
    $selftestEnv = @{
        'BIRP_SELFTEST_DIR'       = $fixtures
        'BIRP_SELFTEST_OUT'       = $selftestOut
        'BIRP_SELFTEST_EXPECT_CD' = $expectCd
        'BIRTHRT_MODE'            = 'patch'                                  # lowercase on purpose
        'BIRTHRT_CD_PATH'         = "  $(Join-Path $fixtures 'hasgame-winbr')  " # padded on purpose
    }
    # Exit code is always nonzero (setup is aborted on purpose); the results file
    # is the verdict.
    Invoke-WithEnv $selftestsExe @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/SELFTESTPARAM=hello') $selftestEnv | Out-Null

    Assert-True (Test-Path -LiteralPath $selftestOut) 'self-tests wrote a results file'
    if (Test-Path -LiteralPath $selftestOut) {
        $results = Get-Content -LiteralPath $selftestOut
        foreach ($line in $results) { Write-Host "    $line" }
        $failLines = @($results | Where-Object { $_ -like 'FAIL *' })
        $resultLine = @($results | Where-Object { $_ -like 'RESULT *' })
        Assert-True ($failLines.Count -eq 0) 'no failing self-tests'
        Assert-True ($resultLine.Count -eq 1 -and $resultLine[0] -like 'RESULT PASS*') 'self-test run completed with RESULT PASS'
    }
} finally {
    if ($substDrive -and (Test-Path -LiteralPath "$substDrive\")) {
        subst $substDrive /d | Out-Null
    }
}

if ($SkipScenarios) {
    Write-Layer 'Summary'
    Write-Host "  $script:AssertCount checks, $($script:Failures.Count) failures (scenario layers skipped)"
    if ($script:Failures.Count -gt 0) { exit 1 } else { exit 0 }
}

# --- Layer 4: silent scenario matrix ---

Write-Layer 'Layer 4: silent scenario matrix'

# Tripwire: fingerprint every directory the installer's detection could find a
# real game in. If any of them changes during the scenario runs, the suite
# fails - a regression must never leak out of the test workspace onto a real
# install (the curated list mirrors DetectExistingInstallDir in common.iss).
$protectedDirs = @(
    'C:\SIERRA\BIRTHRT',
    "$env:SystemDrive\SIERRA\BIRTHRT",
    "$env:ProgramFiles\Sierra\BIRTHRT",
    "${env:ProgramFiles(x86)}\Sierra\BIRTHRT",
    "$env:ProgramFiles\Sierra\Birthright",
    "${env:ProgramFiles(x86)}\Sierra\Birthright"
)
if ($env:BIRTHRT_INSTALL_DIR) { $protectedDirs += $env:BIRTHRT_INSTALL_DIR }
$protectedDirs = @($protectedDirs | Sort-Object -Unique)

function Get-DirFingerprint([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return 'absent' }
    $files = @(Get-ChildItem -LiteralPath $Dir -Recurse -File)
    $newest = ($files | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
    return "$($files.Count) files, newest $newest"
}

$protectedBefore = @{}
foreach ($dir in $protectedDirs) {
    $protectedBefore[$dir] = Get-DirFingerprint $dir
}

$silentArgs = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER')
$uninstallKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{450F762A-A08D-4CC0-A089-CBC642716DAD}_is1'

# Files where the BirP payload must win over the official 1.4 patch payload.
$birpOverlap = @('WINBR.EXE', 'NOVA.EXE', 'CHARED.EXE', 'STRDAT.DAT', 'README.TXT')
$patch1004Files = @(Get-ChildItem -LiteralPath $patch1004Dir -Recurse -File)

function Assert-PatchPayloadPresent([string]$Dir, [string]$Label) {
    $missing = @()
    $mismatched = @()
    foreach ($f in $patch1004Files) {
        $rel = $f.FullName.Substring($patch1004Dir.Length).TrimStart('\')
        $dest = Join-Path $Dir $rel
        if (-not (Test-Path -LiteralPath $dest)) { $missing += $rel; continue }
        if ($birpOverlap -notcontains $f.Name.ToUpper()) {
            if ((Get-FileHashHex $dest) -ne (Get-FileHashHex $f.FullName)) { $mismatched += $rel }
        }
    }
    Assert-True ($missing.Count -eq 0) "$Label - official 1.4 payload complete ($($patch1004Files.Count) files)$(if ($missing.Count) { ' (missing: ' + (($missing | Select-Object -First 5) -join ', ') + ')' })"
    Assert-True ($mismatched.Count -eq 0) "$Label - official 1.4 payload contents intact$(if ($mismatched.Count) { ' (mismatched: ' + (($mismatched | Select-Object -First 5) -join ', ') + ')' })"
}

function Assert-BirpPayloadWins([string]$Dir, [string]$Label) {
    foreach ($name in @('WINBR.exe', 'NOVA.exe', 'CHARED.exe', 'STRDAT.DAT')) {
        $staged = Join-Path $stagedBinDir $name
        $dest = Join-Path $Dir $name
        $ok = (Test-Path -LiteralPath $dest) -and ((Get-FileHashHex $dest) -eq (Get-FileHashHex $staged))
        Assert-True $ok "$Label - BirP $name is the final copy"
    }
}

# Scenario: fresh INSTALL driven only by BIRTHRT_CD_PATH (the issue-58 harness
# convention: no /MODE flag, a CD path implies INSTALL).
$installDir = Join-Path $workspace 'game-install'
$exitCode = Invoke-WithEnv $setupExe ($silentArgs + @("/DIR=$installDir", "/LOG=$workspace\install-fresh.log")) @{ 'BIRTHRT_CD_PATH' = $fakeCd }
Assert-True ($exitCode -eq 0) "install-fresh - exit code 0 (got $exitCode)"
Assert-True ((Get-FileHashHex (Join-Path $installDir 'GAMEOPT.DAT')) -eq (Get-FileHashHex (Join-Path $fakeCd 'GAMEOPT.DAT'))) 'install-fresh - game files copied from the CD (GAMEOPT.DAT)'
Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'GRAPHICS\TEST')) 'install-fresh - CD subfolders copied (GRAPHICS)'
Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'SAVEGAME\TEST')) 'install-fresh - SAVEGAME seeded from the CD'
Assert-PatchPayloadPresent $installDir 'install-fresh'
Assert-BirpPayloadWins $installDir 'install-fresh'
$cfgPath = Join-Path $installDir 'BRSETUP.CFG'
$cfg = ''
if (Test-Path -LiteralPath $cfgPath) { $cfg = (Get-Content -LiteralPath $cfgPath -Raw) }
$cdDriveLetter = (Split-Path -Qualifier $fakeCd).Substring(0, 1)
Assert-True ($cfg -match "\[CD\]\r?\n$cdDriveLetter") "install-fresh - BRSETUP.CFG records the CD drive ($cdDriveLetter)"
Assert-True ($cfg -match '\[CD_BYPASS\]\r?\n1') 'install-fresh - BRSETUP.CFG sets CD_BYPASS'
Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'unins000.exe')) 'install-fresh - uninstaller created'
$uninstallString = ''
if (Test-Path -LiteralPath $uninstallKeyPath) {
    $uninstallString = (Get-ItemProperty -LiteralPath $uninstallKeyPath).UninstallString
}
Assert-True ($uninstallString -like '*/SILENT') 'install-fresh - UninstallString rewritten with /SILENT'

# Scenario: INSTALL via explicit command-line overrides (/MODE=, /CDPATH=).
$installDir2 = Join-Path $workspace 'game-install2'
$exitCode = Invoke-WithEnv $setupExe ($silentArgs + @('/MODE=INSTALL', "/CDPATH=$fakeCd", "/DIR=$installDir2", "/LOG=$workspace\install-cmdline.log")) @{}
Assert-True ($exitCode -eq 0) "install-cmdline - exit code 0 (got $exitCode)"
Assert-True (Test-Path -LiteralPath (Join-Path $installDir2 'GAMEOPT.DAT')) 'install-cmdline - game files copied via /CDPATH='
Assert-BirpPayloadWins $installDir2 'install-cmdline'

# Scenario: PATCH over an existing install. Seed the field state: an old game
# binary, player config, a save, and a customized BRSETUP.CFG.
$patchDir = Join-Path $workspace 'game-patch'
New-PlaceholderFile (Join-Path $patchDir 'WINBR.EXE') 'OLD RETAIL GAME BINARY'
New-PlaceholderFile (Join-Path $patchDir 'GAMEOPT.DAT') 'PLAYER OPTIONS - MUST SURVIVE'
New-PlaceholderFile (Join-Path $patchDir 'RLMSTART.DAT') 'PLAYER REALM START - MUST SURVIVE'
New-PlaceholderFile (Join-Path $patchDir 'SAVEGAME\SLOT0.SAV') 'PLAYER SAVE - MUST SURVIVE'
New-PlaceholderFile (Join-Path $patchDir 'BRSETUP.CFG') "[INSTALL_TYPE]`r`n3`r`n[CD]`r`nQ`r`n"
$preserved = @{}
foreach ($rel in @('GAMEOPT.DAT', 'RLMSTART.DAT', 'SAVEGAME\SLOT0.SAV')) {
    $preserved[$rel] = Get-FileHashHex (Join-Path $patchDir $rel)
}
$exitCode = Invoke-WithEnv $setupExe ($silentArgs + @('/MODE=PATCH', "/DIR=$patchDir", "/LOG=$workspace\patch-existing.log")) @{}
Assert-True ($exitCode -eq 0) "patch-existing - exit code 0 (got $exitCode)"
Assert-PatchPayloadPresent $patchDir 'patch-existing'
Assert-BirpPayloadWins $patchDir 'patch-existing'
foreach ($rel in $preserved.Keys) {
    Assert-True ((Get-FileHashHex (Join-Path $patchDir $rel)) -eq $preserved[$rel]) "patch-existing - $rel untouched"
}
Assert-True (-not (Test-Path -LiteralPath (Join-Path $patchDir 'GRAPHICS'))) 'patch-existing - no game-from-CD payload pulled (GRAPHICS absent)'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $patchDir 'BTLSCN.DAT'))) 'patch-existing - no game-from-CD payload pulled (BTLSCN.DAT absent)'
$cfg = Get-Content -LiteralPath (Join-Path $patchDir 'BRSETUP.CFG') -Raw
Assert-True ($cfg -match '\[CD\]\r?\nQ') 'patch-existing - BRSETUP.CFG keeps the player CD drive (Q)'
Assert-True ($cfg -match '\[CD_BYPASS\]\r?\n1') 'patch-existing - BRSETUP.CFG gains CD_BYPASS'

# Scenario: PATCH must refuse an empty directory and write nothing.
$emptyDir = Join-Path $workspace 'game-empty'
New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
$exitCode = Invoke-WithEnv $setupExe ($silentArgs + @('/MODE=PATCH', "/DIR=$emptyDir", "/LOG=$workspace\patch-refuse.log")) @{}
Assert-True ($exitCode -ne 0) "patch-refuse - nonzero exit code (got $exitCode)"
$emptyDirFiles = @()
if (Test-Path -LiteralPath $emptyDir) {
    $emptyDirFiles = @(Get-ChildItem -LiteralPath $emptyDir -Recurse -File)
}
Assert-True ($emptyDirFiles.Count -eq 0) "patch-refuse - nothing written into the empty dir (found $($emptyDirFiles.Count) files)"

# Scenario: a second PATCH over the same install is idempotent, and never
# touches saves or config (hashes and mtimes).
$beforeHashes = @{}
foreach ($f in (Get-ChildItem -LiteralPath $patchDir -Recurse -File | Where-Object { $_.Name -notlike 'unins*' })) {
    $beforeHashes[$f.FullName] = Get-FileHashHex $f.FullName
}
$beforeTimes = @{}
foreach ($rel in @('GAMEOPT.DAT', 'RLMSTART.DAT', 'SAVEGAME\SLOT0.SAV')) {
    $beforeTimes[$rel] = (Get-Item -LiteralPath (Join-Path $patchDir $rel)).LastWriteTimeUtc
}
$exitCode = Invoke-WithEnv $setupExe ($silentArgs + @('/MODE=PATCH', "/DIR=$patchDir", "/LOG=$workspace\patch-idempotent.log")) @{}
Assert-True ($exitCode -eq 0) "patch-idempotent - exit code 0 (got $exitCode)"
$changed = @()
foreach ($path in $beforeHashes.Keys) {
    if (-not (Test-Path -LiteralPath $path) -or ((Get-FileHashHex $path) -ne $beforeHashes[$path])) { $changed += $path }
}
Assert-True ($changed.Count -eq 0) "patch-idempotent - re-run is content-identical$(if ($changed.Count) { ' (changed: ' + (($changed | Select-Object -First 5) -join ', ') + ')' })"
foreach ($rel in $beforeTimes.Keys) {
    $after = (Get-Item -LiteralPath (Join-Path $patchDir $rel)).LastWriteTimeUtc
    Assert-True ($after -eq $beforeTimes[$rel]) "patch-idempotent - $rel not rewritten (mtime unchanged)"
}

# Scenario: a bad BIRTHRT_CD_PATH must fail loudly and install nothing.
$badDir = Join-Path $workspace 'game-badcd'
$exitCode = Invoke-WithEnv $setupExe ($silentArgs + @("/DIR=$badDir", "/LOG=$workspace\install-badcd.log")) @{ 'BIRTHRT_CD_PATH' = (Join-Path $workspace 'no-such-cd') }
Assert-True ($exitCode -ne 0) "install-badcd - nonzero exit for a missing CD path (got $exitCode)"
Assert-True (-not (Test-Path -LiteralPath $badDir)) 'install-badcd - nothing installed'
$noGameCd = Join-Path $workspace 'cd-without-game'
New-Item -ItemType Directory -Path $noGameCd -Force | Out-Null
$exitCode = Invoke-WithEnv $setupExe ($silentArgs + @("/DIR=$badDir", "/LOG=$workspace\install-nogamecd.log")) @{ 'BIRTHRT_CD_PATH' = $noGameCd }
Assert-True ($exitCode -ne 0) "install-badcd - nonzero exit for a CD path without the game (got $exitCode)"

# --- Layer 6: uninstall safety ---

Write-Layer 'Layer 6: uninstall safety'

# The uninstaller relaunches itself from a temp copy, so the process we wait on
# exits before the uninstall finishes; poll for the result instead.
function Invoke-Uninstall([string]$Dir, [hashtable]$EnvVars, [string]$Label) {
    $unins = Join-Path $Dir 'unins000.exe'
    Assert-True (Test-Path -LiteralPath $unins) "$Label - uninstaller present"
    if (-not (Test-Path -LiteralPath $unins)) { return }
    Invoke-WithEnv $unins @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') $EnvVars | Out-Null
    $done = Wait-Until { -not (Test-Path -LiteralPath (Join-Path $Dir 'unins000.exe')) } 90 "$Label uninstall to finish"
    Assert-True $done "$Label - uninstall completed"
    Start-Sleep -Seconds 2  # let the final RemoveDir and self-delete settle
}

# A sentinel next to the game dir proves nothing outside {app} is deleted.
$sentinel = Join-Path $workspace 'SENTINEL-DO-NOT-DELETE.txt'
New-PlaceholderFile $sentinel 'still here'

# Uninstall the fresh install with settings deletion requested: everything goes,
# including saves, and the now-empty dir is removed.
Invoke-Uninstall $installDir @{ 'BIRTHRT_DELETE_SETTINGS' = '1' } 'uninstall-full'
Assert-True (Test-Path -LiteralPath $sentinel) 'uninstall-full - sentinel outside the game dir survives'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir 'WINBR.exe'))) 'uninstall-full - game files removed'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir 'SAVEGAME'))) 'uninstall-full - saves removed when deletion requested'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir 'BRSETUP.CFG'))) 'uninstall-full - config removed when deletion requested'
Assert-True (-not (Test-Path -LiteralPath $installDir)) 'uninstall-full - empty game dir removed'

# Uninstall the patched install without settings deletion: saves and config
# survive, tracked patch files are removed, and the dir stays.
Invoke-Uninstall $patchDir @{} 'uninstall-keep'
Assert-True (Test-Path -LiteralPath (Join-Path $patchDir 'SAVEGAME\SLOT0.SAV')) 'uninstall-keep - saves survive'
Assert-True (Test-Path -LiteralPath (Join-Path $patchDir 'GAMEOPT.DAT')) 'uninstall-keep - player config survives'
Assert-True (Test-Path -LiteralPath (Join-Path $patchDir 'BRSETUP.CFG')) 'uninstall-keep - BRSETUP.CFG survives'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $patchDir 'SIERRA.INF'))) 'uninstall-keep - tracked patch files removed'

# Uninstall the command-line install to leave the machine clean, then confirm
# the registry key is gone.
Invoke-Uninstall $installDir2 @{ 'BIRTHRT_DELETE_SETTINGS' = '1' } 'uninstall-cleanup'
Assert-True (-not (Test-Path -LiteralPath $uninstallKeyPath)) 'uninstall-cleanup - uninstall registry key removed'

# Tripwire check: no scenario may have touched a real install location.
foreach ($dir in $protectedDirs) {
    $after = Get-DirFingerprint $dir
    Assert-True ($after -eq $protectedBefore[$dir]) "tripwire - real install location untouched: $dir (before: $($protectedBefore[$dir]); after: $after)"
}

# --- Summary ---

Write-Layer 'Summary'
Write-Host "  $script:AssertCount checks, $($script:Failures.Count) failures"
if ($script:Failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Failed checks:' -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
exit 0
