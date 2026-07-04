<#
    BirP Issue Report Tool
    ----------------------
    Collects a few game data / configuration files and a small report file into a
    single .zip archive that you can send to the BirP developers to help diagnose
    problems. It reads files only; it never modifies your game, saves, or settings.

    Normally you do not run this file directly -- double-click "BirP-Issue-Report.bat"
    in the same folder. That launcher runs this script for you. You are welcome to
    open this file in Notepad to see exactly what it does.

    What it puts in the archive:
      - report-summary.txt  (date/time, install path, BirP executable versions, OS)
      - DOS.LOG, winbr.log, BRSETUP.CFG, STRDAT.DAT  (only the ones that exist)

    Advanced/testing switches (not needed for normal use):
      -InstallDir <path>   Folder to collect from / write the archive to.
                           Defaults to the folder this script lives in.
      -Unattended          Skip the pop-up dialogs; print status to the console
                           and proceed without asking. Useful for support scripts.
#>

param(
    [string]$InstallDir = $PSScriptRoot,
    [switch]$Unattended
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($InstallDir)) {
    $InstallDir = (Get-Location).Path
}

if (-not $Unattended) {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
}

# --- Simple UI helpers (dialog boxes, or console when -Unattended) --------------

function Show-InfoMessage {
    param([string]$Message)
    if ($Unattended) {
        Write-Host $Message
    } else {
        [void][System.Windows.Forms.MessageBox]::Show(
            $Message, 'BirP Issue Report',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
    }
}

function Show-ErrorMessage {
    param([string]$Message)
    if ($Unattended) {
        Write-Host $Message
    } else {
        [void][System.Windows.Forms.MessageBox]::Show(
            $Message, 'BirP Issue Report',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Confirm-Continue {
    param([string]$Message)
    if ($Unattended) {
        Write-Host $Message
        return $true
    }
    return ([System.Windows.Forms.MessageBox]::Show(
        $Message, 'BirP Issue Report',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question) -eq [System.Windows.Forms.DialogResult]::Yes)
}

# --- Version / OS detection -----------------------------------------------------

# WINBR.EXE is a Windows PE executable and carries a real file-version resource.
function Get-WindowsExeVersion {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'NOT FOUND' }
    try {
        $info = (Get-Item -LiteralPath $Path).VersionInfo
        if ($info.FileVersionRaw) { return $info.FileVersionRaw.ToString() }
        if ($info.FileVersion)    { return ($info.FileVersion -replace '\s', '') }
        return 'UNKNOWN'
    } catch {
        return 'UNKNOWN'
    }
}

# NOVA.EXE is a DOS/DOS4GW binary with no PE version resource. The BirP build
# compiles its version in as a plain "1.4.x.x" string (BUILD_VERSION), so we scan
# the image for it. BUILD_MAJOR/BUILD_MINOR are fixed at 1.4 by design. If the
# string is absent (e.g. an unpatched original NOVA.EXE), fall back to a hash.
function Get-DosExeVersion {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'NOT FOUND' }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $text  = [System.Text.Encoding]::ASCII.GetString($bytes)
        $match = [regex]::Match($text, '\b1\.4\.\d+\.\d+\b')
        if ($match.Success) { return $match.Value }
        $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        return "UNKNOWN (SHA-256 $hash)"
    } catch {
        return 'UNKNOWN'
    }
}

function Get-OperatingSystemInfo {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $build = 0
        [void][int]::TryParse([string]$os.BuildNumber, [ref]$build)
        $token = switch ($build) {
            { $_ -ge 22000 } { 'WIN11'; break }
            { $_ -ge 10240 } { 'WIN10'; break }
            { $_ -ge 9600 }  { 'WIN81'; break }
            { $_ -ge 9200 }  { 'WIN8';  break }
            { $_ -ge 7600 }  { 'WIN7';  break }
            default          { 'WIN';   break }
        }
        return "$token ($($os.Caption), $($os.Version))"
    } catch {
        $v = [System.Environment]::OSVersion.Version
        return "WIN$($v.Major).$($v.Minor) (build $($v.Build))"
    }
}

# --- Main -----------------------------------------------------------------------

$timestamp  = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$reportName = "birp-issue-report-$timestamp"
$workDir    = $null

$consent = @"
This tool will archive (zip) several game data and configuration files from your game directory into a file named:

    $reportName.zip

...which you can send to the BirP developers for troubleshooting.

One of these files is a report file that contains the version data of your Birthright executables and operating system, your installation directory path, and the current date and time.

Do you wish to continue?
"@

if (-not (Confirm-Continue $consent)) {
    exit 0
}

try {
    $workDir = Join-Path $InstallDir $reportName
    $zipPath = Join-Path $InstallDir "$reportName.zip"

    New-Item -ItemType Directory -Path $workDir -Force | Out-Null

    $novaVersion  = Get-DosExeVersion     (Join-Path $InstallDir 'NOVA.EXE')
    $winbrVersion = Get-WindowsExeVersion (Join-Path $InstallDir 'WINBR.EXE')
    $osInfo       = Get-OperatingSystemInfo
    $now          = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $summary = @"
Date: $now
Install directory: $InstallDir
NOVA.EXE version: $novaVersion
WINBR.EXE version: $winbrVersion
Operating System: $osInfo
"@
    Set-Content -LiteralPath (Join-Path $workDir 'report-summary.txt') -Value $summary -Encoding ASCII

    foreach ($file in @('DOS.LOG', 'winbr.log', 'BRSETUP.CFG', 'STRDAT.DAT')) {
        $src = Join-Path $InstallDir $file
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $workDir -Force
            if ($Unattended) { Write-Host "Added: $file" }
        }
    }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path $workDir -DestinationPath $zipPath -Force

    Show-InfoMessage @"
Game data has been successfully aggregated and archived and is available at:

$zipPath

Please attach this to a Bug Report on the BirP page here:
https://github.com/Shiryou/BirP

Thank you!
"@
}
catch {
    Show-ErrorMessage @"
An unexpected problem occurred while creating the issue report:

$($_.Exception.Message)

No archive was created. Please try again, or contact the BirP developers.
"@
    exit 1
}
finally {
    # Always remove the working folder, whether we succeeded or hit a problem,
    # so only the .zip (if any) is left behind.
    if ($workDir -and (Test-Path -LiteralPath $workDir)) {
        Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit 0
