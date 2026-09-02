<#
test-options-migration.ps1

Checks that upgrading an older options file keeps every setting it held. This is
the check that would have caught a mis-mapped field silently shifting everything
stored after it, writing the wrong values back, and leaving nothing to notice
afterwards.

For each older file version the game still accepts, the script writes a file in
that version's layout, starts the game, lets it read and upgrade the file, then
compares what came back against what went in. Settings that version never held
are expected to take their defaults and are not compared.

It also checks that a file whose version the game does not know is refused and
the settings reset, rather than read with a layout that cannot be trusted.

Needs a deployed Windows build. It uses the game directory named by
BIRTHRT_INSTALL_DIR, or C:\Sierra\BIRTHRT. The existing options file is saved
first and put back at the end, including after a failure.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-options-migration.ps1
  Options:
    -InstallDir <path>   game directory (default: BIRTHRT_INSTALL_DIR)
    -LaunchSeconds <n>   how long to let the game run before closing it
                         (default 20)

Exit code 0 on pass, 1 on any failure.
#>

param(
    [string]$InstallDir,
    [int]$LaunchSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path

if (-not $InstallDir) { $InstallDir = $env:BIRTHRT_INSTALL_DIR }
if (-not $InstallDir) { $InstallDir = 'C:\Sierra\BIRTHRT' }

$optionsFile = Join-Path $InstallDir 'gameopt.dat'
$logFile = Join-Path $InstallDir 'winbr.log'
$gameExe = Join-Path $InstallDir 'WINBR.EXE'
$work = Join-Path $repoRoot 'build-artifacts\options-migration'

$script:Failures = New-Object System.Collections.Generic.List[string]

function Write-Layer([string]$Title) {
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

# The options file, field by field, in the order it is written. SinceVersion is
# the first file version that carries the field. OnlyVersion marks a field that
# exists in exactly one version and was dropped afterwards.
#
# Sizes are what the compiler produces today: the settings kept as lists of
# choices take one byte, and the yes/no settings take four. The total size check
# below fails if that ever stops being true, rather than letting this drift
# quietly out of step with the game.
$KnownVersions = @(0x3102, 0x3103, 0x3104)
$Layout = @(
    @{ Name = 'version';                 Size = 4;  Since = 0 },
    @{ Name = 'game_difficulty';         Size = 1;  Since = 0 },
    @{ Name = 'battle_difficulty';       Size = 1;  Since = 0 },
    @{ Name = 'battle_speed';            Size = 1;  Since = 0 },
    @{ Name = 'adventure_difficulty';    Size = 1;  Since = 0 },
    @{ Name = 'twitch';                  Size = 4;  Since = 0 },
    @{ Name = 'combat_speed';            Size = 2;  Since = 0 },
    @{ Name = 'sfxchan';                 Size = 2;  Since = 0 },
    @{ Name = 'musvol';                  Size = 2;  Since = 0 },
    @{ Name = 'sfxvol';                  Size = 2;  Since = 0 },
    @{ Name = 'sfxenv';                  Size = 1;  Since = 0 },
    @{ Name = 'selected_screen_size';    Size = 2;  Since = 0 },
    @{ Name = 'legacy_auto_resolution';  Size = 4;  Since = 0x3102; OnlyVersion = 0x3102 },
    @{ Name = 'combat_firstperson_view'; Size = 4;  Since = 0 },
    @{ Name = 'sitecount';               Size = 52; Since = 0 },
    @{ Name = 'screen_mode';             Size = 2;  Since = 0 },
    @{ Name = 'mundane_descriptions';    Size = 4;  Since = 0 },
    @{ Name = 'resolution_mode';         Size = 2;  Since = 0x3103 },
    @{ Name = 'resolution_preset';       Size = 2;  Since = 0x3103 },
    @{ Name = 'resolution_scale';        Size = 2;  Since = 0x3103 },
    @{ Name = 'pause_when_inactive';     Size = 4;  Since = 0x3104 },
    @{ Name = 'lSavedX';                 Size = 4;  Since = 0; Runtime = $true },
    @{ Name = 'lSavedY';                 Size = 4;  Since = 0; Runtime = $true }
)

function Get-FieldsForVersion([int]$Version) {
    $fields = @()
    foreach ($f in $Layout) {
        if ($f.ContainsKey('OnlyVersion')) {
            if ($f.OnlyVersion -ne $Version) { continue }
        } elseif ($Version -lt $f.Since) {
            continue
        }
        $fields += $f
    }
    return $fields
}

function Get-Offsets([int]$Version) {
    $offsets = @{}
    $pos = 0
    foreach ($f in Get-FieldsForVersion $Version) {
        $offsets[$f.Name] = @{ Offset = $pos; Size = $f.Size }
        $pos += $f.Size
    }
    $offsets['__total'] = @{ Offset = $pos; Size = 0 }
    return $offsets
}

# Build a file in an older version's layout from a current-version file, keeping
# every value the older version can hold.
function New-OlderFile([byte[]]$Current, [int]$Version, [int]$AutoResValue) {
    $from = Get-Offsets $currentVersion
    $to = Get-Offsets $Version
    $out = New-Object byte[] $to['__total'].Offset

    [Array]::Copy([BitConverter]::GetBytes([uint32]$Version), 0, $out, 0, 4)

    foreach ($f in Get-FieldsForVersion $Version) {
        if ($f.Name -eq 'version') { continue }
        if ($f.Name -eq 'legacy_auto_resolution') {
            [Array]::Copy([BitConverter]::GetBytes([int32]$AutoResValue), 0, $out, $to[$f.Name].Offset, 4)
            continue
        }
        [Array]::Copy($Current, $from[$f.Name].Offset, $out, $to[$f.Name].Offset, $f.Size)
    }

    return $out
}

function Get-FieldBytes([byte[]]$Data, [hashtable]$Offsets, [string]$Name) {
    $o = $Offsets[$Name]
    return $Data[$o.Offset..($o.Offset + $o.Size - 1)]
}

function Format-Field([byte[]]$Bytes) {
    return ($Bytes | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Invoke-Game() {
    if (Test-Path -LiteralPath $logFile) { Remove-Item -LiteralPath $logFile -Force }
    $p = Start-Process -FilePath $gameExe -WorkingDirectory $InstallDir -PassThru
    Start-Sleep -Seconds $LaunchSeconds
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
    Start-Sleep -Seconds 2
}

# --- Setup ---

Write-Layer 'Setup'

if (-not (Test-Path -LiteralPath $gameExe)) {
    Write-Host "  [FAIL] no deployed game at $gameExe" -ForegroundColor Red
    Write-Host '         Deploy a Windows build first: scripts\build-and-deploy-win-debug.ps1' -ForegroundColor Yellow
    exit 1
}
Write-Host "  game: $gameExe"

if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

$savedOptions = $null
if (Test-Path -LiteralPath $optionsFile) {
    $savedOptions = Join-Path $work 'gameopt-saved.dat'
    Copy-Item -LiteralPath $optionsFile -Destination $savedOptions -Force
    Write-Host "  saved the existing options file to $savedOptions"
}

try {
    # A current-version file to derive the older ones from. Running the game once
    # produces one whatever state the directory started in.
    Invoke-Game
    Assert-True (Test-Path -LiteralPath $optionsFile) 'the game wrote an options file'
    if (-not (Test-Path -LiteralPath $optionsFile)) { throw 'no options file to work from' }

    $current = [System.IO.File]::ReadAllBytes($optionsFile)
    Copy-Item -LiteralPath $optionsFile -Destination (Join-Path $work 'gameopt-current.dat') -Force

    # Take the version from the build under test rather than assuming one, so
    # this runs against any branch. Older versions are then whatever this test
    # knows that comes before it.
    $currentVersion = [int][BitConverter]::ToUInt32($current, 0)
    Write-Host ("  the game writes version 0x{0:X8}" -f $currentVersion)

    Assert-True ($KnownVersions -contains $currentVersion) ("this test knows the layout of version 0x{0:X8}" -f $currentVersion)
    if ($KnownVersions -notcontains $currentVersion) {
        Write-Host '  The game writes a version this test has never been told about.' -ForegroundColor Yellow
        Write-Host '  Add it to $KnownVersions and $Layout alongside the change in GAMEOPT.CPP.' -ForegroundColor Yellow
        throw 'unknown current version'
    }

    $expectedSize = (Get-Offsets $currentVersion)['__total'].Offset
    Assert-True ($current.Length -eq $expectedSize) "the options file is $expectedSize bytes, matching the layout this test knows (got $($current.Length))"

    $olderVersions = @($KnownVersions | Where-Object { $_ -lt $currentVersion })
    Write-Host "  older versions to check: $(($olderVersions | ForEach-Object { '0x{0:X4}' -f $_ }) -join ', ')"

    if ($script:Failures.Count -gt 0) {
        Write-Host '  The file layout this test describes no longer matches the game.' -ForegroundColor Yellow
        Write-Host '  Update $Layout in this script alongside whatever changed in GAMEOPT.CPP.' -ForegroundColor Yellow
        throw 'layout mismatch'
    }

    # --- Each older version upgrades without losing anything ---

    foreach ($version in $olderVersions) {
        Write-Layer ("Upgrading from 0x{0:X8}" -f $version)

        $older = New-OlderFile $current $version 1
        $olderPath = Join-Path $work ("gameopt-{0:x4}-in.dat" -f $version)
        [System.IO.File]::WriteAllBytes($olderPath, $older)
        Write-Host "  wrote $($older.Length) bytes: $olderPath"

        Copy-Item -LiteralPath $olderPath -Destination $optionsFile -Force
        Invoke-Game

        $after = [System.IO.File]::ReadAllBytes($optionsFile)
        Copy-Item -LiteralPath $optionsFile -Destination (Join-Path $work ("gameopt-{0:x4}-out.dat" -f $version)) -Force

        Assert-True ([BitConverter]::ToUInt32($after, 0) -eq $currentVersion) ("upgraded to 0x{0:X8}" -f $currentVersion)
        Assert-True ($after.Length -eq $expectedSize) "upgraded file is $expectedSize bytes (got $($after.Length))"

        if ($after.Length -ne $expectedSize) { continue }

        # Every field the older version held must survive unchanged.
        $currentOffsets = Get-Offsets $currentVersion
        $afterOffsets = Get-Offsets $currentVersion
        foreach ($f in Get-FieldsForVersion $version) {
            if ($f.Name -eq 'version') { continue }
            if ($f.Name -eq 'legacy_auto_resolution') { continue }
            # The window position is where the player last left the window, not a
            # setting. The game moves it as it runs, so it is expected to differ.
            if ($f.ContainsKey('Runtime')) { continue }

            $want = Get-FieldBytes $current $currentOffsets $f.Name
            $got = Get-FieldBytes $after $afterOffsets $f.Name
            $same = -not (Compare-Object $want $got)
            $detail = ''
            if (-not $same) { $detail = " (was $(Format-Field $want), became $(Format-Field $got))" }
            Assert-True $same "$($f.Name) survived the upgrade$detail"
        }

        # Release builds compile the informational log lines out, so only assert
        # on them when this build writes them at all. The comparison above is
        # the real check either way.
        if (Test-Path -LiteralPath $logFile) {
            if (Select-String -Path $logFile -Pattern 'ReadOptionSettings loaded' -Quiet) {
                $migrated = Select-String -Path $logFile -Pattern 'migrating.*options format' -Quiet
                Assert-True $migrated 'the log records the upgrade'
            } else {
                Write-Host '  [SKIP] this build does not write informational log lines' -ForegroundColor Yellow
            }
        }
    }

    # --- An unknown version is refused, not guessed at ---

    Write-Layer 'A version the game does not know'

    $bogus = [byte[]]::new($current.Length)
    [Array]::Copy($current, $bogus, $current.Length)
    [Array]::Copy([BitConverter]::GetBytes([uint32]0x3199), 0, $bogus, 0, 4)
    [System.IO.File]::WriteAllBytes($optionsFile, $bogus)
    Invoke-Game

    $after = [System.IO.File]::ReadAllBytes($optionsFile)
    Assert-True ([BitConverter]::ToUInt32($after, 0) -eq $currentVersion) 'the file was rewritten in the current version'
    if (Test-Path -LiteralPath $logFile) {
        $reset = Select-String -Path $logFile -Pattern 'version mismatch' -Quiet
        Assert-True $reset 'the log records the file being refused and reset'
    }
}
finally {
    if ($savedOptions -and (Test-Path -LiteralPath $savedOptions)) {
        Copy-Item -LiteralPath $savedOptions -Destination $optionsFile -Force
        Write-Host ''
        Write-Host "  put the original options file back" -ForegroundColor Cyan
    }
}

# --- Summary ---

Write-Layer 'Summary'

if ($script:Failures.Count -gt 0) {
    Write-Host "$($script:Failures.Count) check(s) failed:" -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host "Files kept for inspection: $work" -ForegroundColor Yellow
    exit 1
}

Write-Host 'Older options files upgrade with every setting intact.' -ForegroundColor Green
exit 0
