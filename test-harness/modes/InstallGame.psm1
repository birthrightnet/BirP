<#
    InstallGame.psm1 - fresh install of the game from the CD image via our installer.

    Shared by Desktop mode (-Install) and (later) VM mode. Mounts the Birthright CD
    image, then runs our Inno Setup installer non-interactively to lay down the
    official game content plus the patch into a target directory.

    This relies on the installer honoring the BIRTHRT_CD_PATH environment variable
    for the CD path (added to installer.iss for issue #58). The installer reads a
    PATH (a mounted drive or folder), not an .iso - the harness owns the .iso and
    mounts it, then hands the resulting drive to the installer via BIRTHRT_CD_PATH.

    Safety: point -InstallDir at a throwaway directory. This performs a real install
    and will overwrite the target.
#>

Set-StrictMode -Version Latest

function Find-BirpInstaller {
    <# Return the newest built BirP installer .exe, or $null. #>
    param([Parameter(Mandatory)][string]$HarnessDir)
    $artifacts = Join-Path $HarnessDir '..\build-artifacts'
    if (-not (Test-Path $artifacts)) { return $null }
    return Get-ChildItem -Path $artifacts -Recurse -Filter 'BirPSetup*.exe' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Install-BirpGameFromCd {
    param(
        [Parameter(Mandatory)][string]$CdIso,
        [Parameter(Mandatory)][string]$InstallDir,
        [Parameter(Mandatory)][string]$HarnessDir,
        [string]$LogPath
    )

    # Hardening: locate the built installer first, before touching anything.
    $installer = Find-BirpInstaller -HarnessDir $HarnessDir
    if (-not $installer) {
        throw "No built installer found under build-artifacts (BirPSetup*.exe). Build it first with scripts\build-release-package.ps1, then retry -Install."
    }

    Write-Host "Install-from-CD:"
    Write-Host ("  Birthright CD image : {0}" -f $CdIso)
    Write-Host ("  Installer           : {0}" -f $installer.FullName)
    Write-Host ("  Target dir          : {0}" -f $InstallDir)

    if (-not $LogPath) { $LogPath = Join-Path ([System.IO.Path]::GetTempPath()) ("birp-install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date)) }

    $mounted = $false
    $priorCdPath = $env:BIRTHRT_CD_PATH
    try {
        # Mount the CD image and hand its drive to the installer via BIRTHRT_CD_PATH.
        $cdRoot = Mount-BirpIso -IsoPath $CdIso
        $mounted = $true
        Write-Host ("  Mounted CD at       : {0}" -f $cdRoot)

        # Hardening: confirm this really is the Birthright CD root.
        if (-not (Test-Path -LiteralPath (Join-Path $cdRoot 'INSTALL.EXE'))) {
            throw "Mounted image $CdIso (at $cdRoot) does not contain INSTALL.EXE - it does not look like the Birthright CD."
        }

        $env:BIRTHRT_CD_PATH = $cdRoot
        Write-Host ("  BIRTHRT_CD_PATH     : {0}  (passed to the installer)" -f $env:BIRTHRT_CD_PATH)

        # Run the installer silently. Inno: /VERYSILENT hides UI, /SUPPRESSMSGBOXES
        # answers dialogs, /NORESTART, /DIR sets the target, /LOG captures a log.
        $args = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$InstallDir`"", "/LOG=`"$LogPath`"")
        Write-Host ("  Running: {0} {1}" -f (Split-Path -Leaf $installer.FullName), ($args -join ' '))
        $p = Start-Process -FilePath $installer.FullName -ArgumentList $args -Wait -PassThru
        Write-Host ("  Installer exit code : {0}" -f $p.ExitCode)

        if ($p.ExitCode -ne 0) {
            if (Test-Path $LogPath) { Write-Host "--- installer log (tail) ---"; Get-Content $LogPath -Tail 20 | ForEach-Object { Write-Host "  $_" } }
            throw "Installer exited with code $($p.ExitCode). See log: $LogPath"
        }

        # Hardening: confirm the patched game actually landed.
        $winbr = Join-Path $InstallDir 'WINBR.EXE'
        if (-not (Test-Path $winbr)) {
            throw "Install reported success but WINBR.EXE is missing from $InstallDir. See log: $LogPath"
        }
        Write-Host ("  Verified            : {0} present." -f $winbr)
        Write-Host "Install-from-CD complete."
    }
    finally {
        # Restore prior BIRTHRT_CD_PATH and dismount.
        $env:BIRTHRT_CD_PATH = $priorCdPath
        if ($mounted) { Dismount-BirpIso -IsoPath $CdIso }
    }
}

Export-ModuleMember -Function Install-BirpGameFromCd, Find-BirpInstaller
