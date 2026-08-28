<#
smoke-test-release-package.ps1

Installs the real release package and checks the game files land. This is the
check that the thing being shipped works, as opposed to test-installer.ps1,
which proves the installer's logic against stand-in payloads. Here the payload
is the actual built game, so it also catches a package built from the wrong
commit or stamped with the wrong version.

Checks:

  1. Assets       - exactly one installer and one zip, both naming the same
                    version, and that version agrees with PVERSION.HXX.
  2. Build number - the fourth part of the version is the current commit, so a
                    package built from a different checkout than the tag fails
                    here instead of shipping.
  3. Patch run    - a silent PATCH over a seeded game folder lands the real
                    binaries, and player saves and settings survive.
  4. Re-run       - patching again changes nothing and still leaves saves alone.
  5. Uninstall    - saves survive an uninstall that was not asked to remove
                    them, and nothing outside the game folder is touched.
  6. Zip          - the archive carries the same binaries as the installer,
                    byte for byte, plus the readme and the issue reporter.

Runs entirely under build-artifacts\release-smoke with /CURRENTUSER, so it needs
no elevation and no game data. A tripwire fails the run if any real install
location changes while it works.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\smoke-test-release-package.ps1
  Options:
    -InstallerPath <path>  explicit installer .exe (default: the one in
                           build-artifacts\binaries\Installer)
    -ZipPath <path>        explicit release .zip (same default)
    -SkipCommitCheck       do not require the build number to match HEAD. Use
                           when deliberately smoke testing a package built
                           somewhere else.
    -KeepWorkspace         leave build-artifacts\release-smoke in place

Exit code 0 on pass, 1 on any failure.
#>

param(
    [string]$InstallerPath,
    [string]$ZipPath,
    [switch]$SkipCommitCheck,
    [switch]$KeepWorkspace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$stagedBinDir = Join-Path $repoRoot 'build-artifacts\binaries\Installer'
$workspace = Join-Path $repoRoot 'build-artifacts\release-smoke'

$script:Failures = New-Object System.Collections.Generic.List[string]
$script:AssertCount = 0

function Write-Layer([string]$Title) {
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Assert-True([bool]$Condition, [string]$Message) {
    $script:AssertCount++
    if ($Condition) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        $script:Failures.Add($Message)
    }
}

function Get-FileHashHex([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# Test-Path throws "Access is denied" against a file the uninstaller is midway
# through deleting. Treat that as gone rather than as an error.
function Test-PathPresent([string]$Path) {
    try {
        return (Test-Path -LiteralPath $Path)
    } catch {
        return $false
    }
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

function New-SeedFile([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -Encoding ascii
}

function Invoke-Silent([string]$Exe, [string[]]$Arguments) {
    $proc = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    if (-not $proc.WaitForExit(300000)) {
        Write-Host "  timeout: killing $([System.IO.Path]::GetFileName($Exe)) after 300s" -ForegroundColor Yellow
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Exe)
        Get-Process | Where-Object { $_.Name -like "$baseName*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        return -999
    }
    return $proc.ExitCode
}

# --- Layer 1: the assets ---

Write-Layer 'Layer 1: release assets'

if (-not $InstallerPath) {
    $found = @(Get-ChildItem -Path $stagedBinDir -Filter 'Birthrt-Preservation-Patch-*.exe' -File -ErrorAction SilentlyContinue)
    Assert-True ($found.Count -eq 1) "exactly one installer in $stagedBinDir (found $($found.Count))"
    if ($found.Count -ne 1) { exit 1 }
    $InstallerPath = $found[0].FullName
}
if (-not $ZipPath) {
    $found = @(Get-ChildItem -Path $stagedBinDir -Filter 'Birthrt-Preservation-Patch-*.zip' -File -ErrorAction SilentlyContinue)
    Assert-True ($found.Count -eq 1) "exactly one release zip in $stagedBinDir (found $($found.Count))"
    if ($found.Count -ne 1) { exit 1 }
    $ZipPath = $found[0].FullName
}

$InstallerPath = (Resolve-Path -LiteralPath $InstallerPath).Path
$ZipPath = (Resolve-Path -LiteralPath $ZipPath).Path
Write-Host "  installer: $InstallerPath"
Write-Host "  zip:       $ZipPath"

function Get-PackageVersion([string]$Path) {
    $m = [regex]::Match([System.IO.Path]::GetFileNameWithoutExtension($Path), 'Birthrt-Preservation-Patch-(\d+\.\d+\.\d+\.\d+)$')
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value
}

$exeVersion = Get-PackageVersion $InstallerPath
$zipVersion = Get-PackageVersion $ZipPath
Assert-True ($null -ne $exeVersion) "installer name carries a four-part version (got $([System.IO.Path]::GetFileName($InstallerPath)))"
Assert-True ($exeVersion -eq $zipVersion) "installer and zip name the same version ($exeVersion vs $zipVersion)"
if ($null -eq $exeVersion) { exit 1 }

# The package version must agree with the version in source.
$pversion = Get-Content -LiteralPath (Join-Path $repoRoot 'source\PVERSION.HXX') -Raw
$parts = @()
foreach ($name in @('BUILD_MAJOR', 'BUILD_MINOR', 'BUILD_PATCH')) {
    $m = [regex]::Match($pversion, "(?m)^\s*#define\s+$name\s+(\d+)\s*$")
    if ($m.Success) { $parts += $m.Groups[1].Value }
}
$sourceVersion = $parts -join '.'
$packageBase = ($exeVersion -split '\.')[0..2] -join '.'
Assert-True ($packageBase -eq $sourceVersion) "package version $packageBase matches PVERSION.HXX ($sourceVersion)"

# --- Layer 2: the build number identifies this commit ---

Write-Layer 'Layer 2: build number'

$buildNumber = [int](($exeVersion -split '\.')[3])
Assert-True ($buildNumber -ne 0) "build number is stamped (got $buildNumber)"

if ($SkipCommitCheck) {
    Write-Host '  commit check skipped (-SkipCommitCheck)'
} else {
    Push-Location $repoRoot
    try {
        $shortHex = (& git rev-parse --short=4 HEAD 2>$null)
    } finally {
        Pop-Location
    }
    if ([string]::IsNullOrWhiteSpace(($shortHex -join ''))) {
        Write-Host '  no git commit available; commit check skipped' -ForegroundColor Yellow
    } else {
        $shortHex = ("$shortHex".Trim()).Substring(0, 4)
        $expected = [Convert]::ToInt32($shortHex, 16)
        Assert-True ($buildNumber -eq $expected) "build number $buildNumber is this commit ($shortHex = $expected)"
    }
}

# --- Layer 3: silent patch over a seeded game folder ---

Write-Layer 'Layer 3: silent patch'

# Tripwire: nothing here may reach a real install. The list mirrors
# DetectExistingInstallDir in installer\common.iss.
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
foreach ($dir in $protectedDirs) { $protectedBefore[$dir] = Get-DirFingerprint $dir }

if (Test-Path -LiteralPath $workspace) { Remove-Item -LiteralPath $workspace -Recurse -Force }
New-Item -ItemType Directory -Path $workspace -Force | Out-Null

# A sentinel beside the game folder proves the installer stays inside {app}.
$sentinel = Join-Path $workspace 'SENTINEL-DO-NOT-DELETE.txt'
New-SeedFile $sentinel 'still here'

# Seed a game folder the way a player's looks: an old binary, settings, a save.
$gameDir = Join-Path $workspace 'game'
New-SeedFile (Join-Path $gameDir 'WINBR.EXE') 'OLD RETAIL GAME BINARY'
New-SeedFile (Join-Path $gameDir 'GAMEOPT.DAT') 'PLAYER OPTIONS - MUST SURVIVE'
New-SeedFile (Join-Path $gameDir 'RLMSTART.DAT') 'PLAYER REALM START - MUST SURVIVE'
New-SeedFile (Join-Path $gameDir 'SAVEGAME\SLOT0.SAV') 'PLAYER SAVE - MUST SURVIVE'
New-SeedFile (Join-Path $gameDir 'BRSETUP.CFG') "[INSTALL_TYPE]`r`n3`r`n[CD]`r`nQ`r`n"

$preserved = @{}
foreach ($rel in @('GAMEOPT.DAT', 'RLMSTART.DAT', 'SAVEGAME\SLOT0.SAV')) {
    $preserved[$rel] = Get-FileHashHex (Join-Path $gameDir $rel)
}

$silentArgs = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER')
$uninstallKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{450F762A-A08D-4CC0-A089-CBC642716DAD}_is1'

$exitCode = Invoke-Silent $InstallerPath ($silentArgs + @('/MODE=PATCH', "/DIR=$gameDir", "/LOG=$workspace\patch.log"))
Assert-True ($exitCode -eq 0) "patch - exit code 0 (got $exitCode)"

# The real binaries must be the ones on disk afterwards.
$shipped = @('WINBR.EXE', 'NOVA.EXE', 'CHARED.EXE', 'STRDAT.DAT')
foreach ($name in $shipped) {
    $staged = Join-Path $stagedBinDir $name
    $dest = Join-Path $gameDir $name
    $ok = (Test-Path -LiteralPath $staged) -and ((Get-FileHashHex $dest) -eq (Get-FileHashHex $staged))
    Assert-True $ok "patch - $name is the built release copy"
}
Assert-True (Test-Path -LiteralPath (Join-Path $gameDir 'README.txt')) 'patch - the player readme is installed'
Assert-True (Test-Path -LiteralPath (Join-Path $gameDir 'BirP-Issue-Report.bat')) 'patch - the issue reporting tool is installed'

# The installed game binary must report the version the package claims.
$installedVersion = (Get-Item (Join-Path $gameDir 'WINBR.EXE')).VersionInfo.FileVersion
if ($installedVersion) { $installedVersion = $installedVersion.Replace(',', '.').Replace(' ', '') }
Assert-True ($installedVersion -eq $exeVersion) "patch - installed WINBR.EXE reports $exeVersion (got $installedVersion)"

foreach ($rel in $preserved.Keys) {
    Assert-True ((Get-FileHashHex (Join-Path $gameDir $rel)) -eq $preserved[$rel]) "patch - player file untouched: $rel"
}
Assert-True (Test-Path -LiteralPath (Join-Path $gameDir 'unins000.exe')) 'patch - uninstaller created'

# --- Layer 4: patching again changes nothing ---

Write-Layer 'Layer 4: re-run'

$exitCode = Invoke-Silent $InstallerPath ($silentArgs + @('/MODE=PATCH', "/DIR=$gameDir", "/LOG=$workspace\patch-again.log"))
Assert-True ($exitCode -eq 0) "re-run - exit code 0 (got $exitCode)"
foreach ($name in $shipped) {
    $ok = (Get-FileHashHex (Join-Path $gameDir $name)) -eq (Get-FileHashHex (Join-Path $stagedBinDir $name))
    Assert-True $ok "re-run - $name still the built release copy"
}
foreach ($rel in $preserved.Keys) {
    Assert-True ((Get-FileHashHex (Join-Path $gameDir $rel)) -eq $preserved[$rel]) "re-run - player file untouched: $rel"
}

# --- Layer 5: uninstall ---

Write-Layer 'Layer 5: uninstall'

# The uninstaller relaunches itself from a temp copy, so the process we wait on
# exits before the uninstall finishes; poll for the result instead.
$unins = Join-Path $gameDir 'unins000.exe'
if (Test-Path -LiteralPath $unins) {
    Invoke-Silent $unins @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') | Out-Null
    $done = Wait-Until { -not (Test-PathPresent (Join-Path $gameDir 'unins000.exe')) } 90 'uninstall to finish'
    Assert-True $done 'uninstall - completed'
    Start-Sleep -Seconds 2  # let the final RemoveDir and self-delete settle

    Assert-True (Test-Path -LiteralPath $sentinel) 'uninstall - the sentinel outside the game folder survives'
    Assert-True (Test-Path -LiteralPath (Join-Path $gameDir 'SAVEGAME\SLOT0.SAV')) 'uninstall - saves survive when removal was not requested'
    Assert-True (Test-Path -LiteralPath (Join-Path $gameDir 'GAMEOPT.DAT')) 'uninstall - player settings survive'
    Assert-True (-not (Test-PathPresent $uninstallKeyPath)) 'uninstall - the uninstall registry key is removed'
}

# --- Layer 6: the zip matches the installer ---

Write-Layer 'Layer 6: release zip'

$unzipDir = Join-Path $workspace 'zip'
Expand-Archive -LiteralPath $ZipPath -DestinationPath $unzipDir -Force

foreach ($name in $shipped) {
    $fromZip = Join-Path $unzipDir $name
    $staged = Join-Path $stagedBinDir $name
    $ok = (Test-Path -LiteralPath $fromZip) -and ((Get-FileHashHex $fromZip) -eq (Get-FileHashHex $staged))
    Assert-True $ok "zip - $name matches the installer's copy"
}
foreach ($name in @('README.txt', 'BirP-Issue-Report.bat', 'BirP-Issue-Report.ps1')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $unzipDir $name)) "zip - carries $name"
}

# --- Tripwire ---

Write-Layer 'Tripwire'

foreach ($dir in $protectedDirs) {
    $after = Get-DirFingerprint $dir
    Assert-True ($after -eq $protectedBefore[$dir]) "real install location untouched: $dir (before: $($protectedBefore[$dir]); after: $after)"
}

# --- Summary ---

Write-Layer 'Summary'
Write-Host "  $script:AssertCount checks, $($script:Failures.Count) failures"

if (-not $KeepWorkspace -and $script:Failures.Count -eq 0) {
    Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'Failed checks:' -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host "Workspace kept for inspection: $workspace" -ForegroundColor Yellow
    exit 1
}

Write-Host "Release package $exeVersion installs and uninstalls correctly." -ForegroundColor Green
exit 0
