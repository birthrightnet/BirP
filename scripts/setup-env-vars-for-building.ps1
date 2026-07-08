<#
.SYNOPSIS
Configures user and current-session environment variables for the Birthright Preservation Patch Open Watcom toolchain.
Note that this is not the ONLY way you could set up your environment for working on this project, it's just a convenient script we provide to do it for you.
You can also set up your environment manually if you prefer, or use this script as a reference for what variables and paths need to be set.

.DESCRIPTION
Adds required references for Open Watcom v2.0, Windows 95 DDK, DirectX SDK, UASM, and Inno Setup 6 to PATH, INCLUDE, and LIB without creating duplicate entries.
Also sets WATCOM, EDPATH, WHTMLHELP, WIPFC, and BIRTHRT_INSTALL_DIR in HKCU\Environment and for the current shell.
Before applying any changes, validates that the directory paths it is about to set actually exist.
Validation covers all directories that will be written to PATH/INCLUDE/LIB and all scalar path values (WATCOM, EDPATH, WHTMLHELP, WIPFC, BIRTHRT_INSTALL_DIR).
If validation fails, no backup is written and no environment variables are modified.
When applying values, required references are prepended in stable order and existing entries are preserved, with case-insensitive deduplication.
Before writing changes, the script creates a timestamped backup in birp-dev\scripts\env-backups.

.INPUTS
None. This script does not accept pipeline input.

.PARAMETER Win95DdkRoot
Optional override path for the Windows 95 DDK root. 
Defaults to C:\BirP-Dependencies\Windows95DDK.

.PARAMETER DxSdkRoot
Optional override path for the DirectX SDK root. 
Defaults to C:\BirP-Dependencies\DirectXSDK.

.PARAMETER OpenWatcomRoot
Optional override path for the Open Watcom root.
Defaults to C:\BirP-Dependencies\OPENWATCOM-v2_0.

.PARAMETER UasmRoot
Optional override path for the UASM root.
Defaults to C:\BirP-Dependencies\UASM-v2_57.

.PARAMETER BirthrtInstallDir
Optional override path for the Birthright install directory.
Defaults to C:\SIERRA\BIRTHRT.

.PARAMETER DigitalvIncludeDir
Optional override path for DIGITALV include files.
Defaults to C:\BirP-Dependencies\Windows95DDK-INC16-DIGITALV.

.PARAMETER InnoSetupRoot
Optional override path for the Inno Setup 6 root (the folder containing iscc.exe).
Used to build the release installer via birp-dev\scripts\build-release-package.ps1.
Defaults to C:\BirP-Dependencies\InnoSetup-6.

.PARAMETER BirthrtCdIso
Optional path to the Birthright game CD .iso, used only by the automated test
harness (issue #58) to install the official game content. No default - only set
when provided (or preserved from an existing user value). Validated as a file.

.PARAMETER BirthrtWinIso
Optional path to a Windows OS install .iso, used only by the test harness VM run
mode. No default - only set when provided. Validated as a file. Desktop mode does
not use this.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -Win95DdkRoot "D:\SDKs\Windows95DDK" -DxSdkRoot "D:\SDKs\DirectXSDK"

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -OpenWatcomRoot "D:\SDKs\OPENWATCOM-v2_0"

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -UasmRoot "D:\SDKs\UASM-v2_57"

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -BirthrtInstallDir "D:\Games\BIRTHRT"

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -DigitalvIncludeDir "D:\SDKs\Windows95DDK-INC16-DIGITALV"

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -InnoSetupRoot "D:\SDKs\InnoSetup-6"

.OUTPUTS
Writes human-readable status messages to the host stream, including:
- validation failures and missing directory list (if any)
- backup file location
- confirmation of HKCU\Environment updates
- effective values applied to the current shell

The script writes host output only; it does not emit structured pipeline objects.

Exit behavior:
- success: script completes after updating user and session environment
- failure: throws on path validation or runtime errors; no partial writes occur before validation

.NOTES
After running this script, validate deduplication with:
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1

Validation assumptions:
- Open Watcom directory structure contains: binnt64, binnt, h, h\nt, h\nt\directx, h\nt\ddk, lib386, lib386\nt, eddat, wipfc, and binnt\help
- Windows95DDK directory structure contains: INC32, INC16, and LIB
- DirectXSDK directory structure contains: sdk\inc and sdk\lib
- UASM path resolves to an existing UASM-v2_57 directory
- BIRTHRT_INSTALL_DIR resolves to an existing directory
- DigitalvIncludeDir resolves to an existing directory and is added to INCLUDE
- Inno Setup path resolves to an existing InnoSetup-6 directory (containing iscc.exe) and is added to PATH

Backup details:
- backup files are written to birp-dev\scripts\env-backups
- filename format: HKCU-Environment-YYYYMMDD-HHMMSS.txt
- backup captures pre-change user-level values for Path, INCLUDE, LIB, WATCOM, EDPATH, WHTMLHELP, WIPFC, and BIRTHRT_INSTALL_DIR
#>

param(
    [string]$Win95DdkRoot,
    [string]$DxSdkRoot,
    [string]$OpenWatcomRoot,
    [string]$UasmRoot,
    [string]$BirthrtInstallDir,
    [string]$DigitalvIncludeDir,
    [string]$InnoSetupRoot,
    [string]$BirthrtCdIso,
    [string]$BirthrtWinIso
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-DefaultValue {
    param(
        [string]$Value,
        [string]$Default
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Default
    }

    return $Value
}

$OpenWatcomRoot = Resolve-DefaultValue -Value $OpenWatcomRoot -Default "C:\BirP-Dependencies\OPENWATCOM-v2_0"
$UasmRoot = Resolve-DefaultValue -Value $UasmRoot -Default "C:\BirP-Dependencies\UASM-v2_57"
$Win95DdkRoot = Resolve-DefaultValue -Value $Win95DdkRoot -Default "C:\BirP-Dependencies\Windows95DDK"
$DxSdkRoot = Resolve-DefaultValue -Value $DxSdkRoot -Default "C:\BirP-Dependencies\DirectXSDK"
$BirthrtInstallDir = Resolve-DefaultValue -Value $BirthrtInstallDir -Default "C:\SIERRA\BIRTHRT"
$DigitalvIncludeDir = Resolve-DefaultValue -Value $DigitalvIncludeDir -Default "C:\BirP-Dependencies\Windows95DDK-INC16-DIGITALV"
$InnoSetupRoot = Resolve-DefaultValue -Value $InnoSetupRoot -Default "C:\BirP-Dependencies\InnoSetup-6"

# Optional test-harness image variables (issue #58). These are user-specific .iso
# files with no sensible default, so they are only configured when provided (via
# parameter, or preserved from an existing user value). They are NOT required to
# build; leaving them unset changes nothing.
$BirthrtCdIso = Resolve-DefaultValue -Value $BirthrtCdIso -Default ([Environment]::GetEnvironmentVariable("BIRTHRT_CD_ISO", "User"))
$BirthrtWinIso = Resolve-DefaultValue -Value $BirthrtWinIso -Default ([Environment]::GetEnvironmentVariable("BIRTHRT_WIN_ISO", "User"))

$optionalFileScalars = [ordered]@{}
if (-not [string]::IsNullOrWhiteSpace($BirthrtCdIso)) { $optionalFileScalars["BIRTHRT_CD_ISO"] = $BirthrtCdIso }
if (-not [string]::IsNullOrWhiteSpace($BirthrtWinIso)) { $optionalFileScalars["BIRTHRT_WIN_ISO"] = $BirthrtWinIso }

$owBinNt64 = Join-Path $OpenWatcomRoot "binnt64"
$owBinNt = Join-Path $OpenWatcomRoot "binnt"
$owH = Join-Path $OpenWatcomRoot "h"
$owHNt = Join-Path $OpenWatcomRoot "h\nt"
$owHNtDx = Join-Path $OpenWatcomRoot "h\nt\directx"
$owHNtDdk = Join-Path $OpenWatcomRoot "h\nt\ddk"
$owLib386 = Join-Path $OpenWatcomRoot "lib386"
$owLib386Nt = Join-Path $OpenWatcomRoot "lib386\nt"
$owEdPath = Join-Path $OpenWatcomRoot "eddat"
$owWHtmlHelp = Join-Path $OpenWatcomRoot "binnt\help"
$owWipfc = Join-Path $OpenWatcomRoot "wipfc"

$win95DdkInclude = Join-Path $Win95DdkRoot "INC32"
$win95DdkInclude16 = Join-Path $Win95DdkRoot "INC16"
$win95DdkLib = Join-Path $Win95DdkRoot "LIB"
$dxSdkInclude = Join-Path $DxSdkRoot "sdk\inc"
$dxSdkLib = Join-Path $DxSdkRoot "sdk\lib"

$requiredPathRefs = @($owBinNt64, $owBinNt, $UasmRoot, $InnoSetupRoot)
$requiredIncludeRefs = @($owH, $owHNt, $win95DdkInclude, $win95DdkInclude16, $DigitalvIncludeDir, $dxSdkInclude, $owHNtDx, $owHNtDdk)
$requiredLibRefs = @($owLib386, $owLib386Nt, $win95DdkLib, $dxSdkLib)

$requiredScalars = @{
    "WATCOM" = $OpenWatcomRoot
    "EDPATH" = $owEdPath
    "WHTMLHELP" = $owWHtmlHelp
    "WIPFC" = $owWipfc
    "BIRTHRT_INSTALL_DIR" = $BirthrtInstallDir
}

function Assert-DirectoryPathsExist {
    param(
        [string[]]$Paths,
        [string]$Category,
        [System.Collections.Generic.List[string]]$MissingPaths
    )

    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }

        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            $MissingPaths.Add($Category + ': ' + $path) | Out-Null
        }
    }
}

function Assert-FilePathsExist {
    param(
        [System.Collections.IDictionary]$NamedPaths,
        [string]$Category,
        [System.Collections.Generic.List[string]]$MissingPaths
    )

    foreach ($name in $NamedPaths.Keys) {
        $path = $NamedPaths[$name]
        if ([string]::IsNullOrWhiteSpace($path)) { continue }

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $MissingPaths.Add($Category + ': ' + $name + ' -> ' + $path) | Out-Null
        }
    }
}

function Validate-ConfiguredPaths {
    $missingPaths = New-Object 'System.Collections.Generic.List[string]'

    Assert-DirectoryPathsExist -Paths $requiredPathRefs -Category 'PATH' -MissingPaths $missingPaths
    Assert-DirectoryPathsExist -Paths $requiredIncludeRefs -Category 'INCLUDE' -MissingPaths $missingPaths
    Assert-DirectoryPathsExist -Paths $requiredLibRefs -Category 'LIB' -MissingPaths $missingPaths
    Assert-DirectoryPathsExist -Paths @($requiredScalars.Values) -Category 'SCALAR' -MissingPaths $missingPaths
    Assert-FilePathsExist -NamedPaths $optionalFileScalars -Category 'FILE' -MissingPaths $missingPaths

    if ($missingPaths.Count -gt 0) {
        Write-Host 'The following required directories do not exist:' -ForegroundColor Red
        foreach ($entry in $missingPaths) {
            Write-Host ('  - ' + $entry) -ForegroundColor Red
        }

        throw 'Path validation failed. Fix missing directories or provide path overrides, then re-run the script.'
    }
}

function Merge-UniqueList {
    param(
        [string]$Existing,
        [string[]]$Required
    )

    $seen = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
    $merged = New-Object "System.Collections.Generic.List[string]"

    foreach ($item in $Required) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        $trimmed = $item.Trim()
        if ($seen.Add($trimmed)) {
            [void]$merged.Add($trimmed)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Existing)) {
        foreach ($entry in ($Existing -split ";")) {
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            $trimmed = $entry.Trim()
            if ($seen.Add($trimmed)) {
                [void]$merged.Add($trimmed)
            }
        }
    }

    return [string]::Join(";", $merged)
}

function Get-RegValue {
    param(
        [string]$RegPath,
        [string]$Name
    )

    try {
        return (Get-ItemProperty -Path $RegPath -Name $Name -ErrorAction SilentlyContinue).$Name
    } catch {
        return $null
    }
}

function Set-RegValue {
    param(
        [string]$RegPath,
        [string]$Name,
        [string]$Value,
        [ValidateSet("String", "ExpandString")]
        [string]$Type = "String"
    )

    New-ItemProperty -Path $RegPath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Write-UserVars {
    $regPath = "HKCU:\Environment"

    $existingPath = Get-RegValue -RegPath $regPath -Name "Path"
    $existingInclude = Get-RegValue -RegPath $regPath -Name "INCLUDE"
    $existingLib = Get-RegValue -RegPath $regPath -Name "LIB"

    $newPath = Merge-UniqueList -Existing $existingPath -Required $requiredPathRefs
    $newInclude = Merge-UniqueList -Existing $existingInclude -Required $requiredIncludeRefs
    $newLib = Merge-UniqueList -Existing $existingLib -Required $requiredLibRefs

    Set-RegValue -RegPath $regPath -Name "Path" -Value $newPath -Type "ExpandString"
    Set-RegValue -RegPath $regPath -Name "INCLUDE" -Value $newInclude -Type "ExpandString"
    Set-RegValue -RegPath $regPath -Name "LIB" -Value $newLib -Type "ExpandString"

    foreach ($name in $requiredScalars.Keys) {
        Set-RegValue -RegPath $regPath -Name $name -Value $requiredScalars[$name] -Type "String"
    }

    foreach ($name in $optionalFileScalars.Keys) {
        Set-RegValue -RegPath $regPath -Name $name -Value $optionalFileScalars[$name] -Type "String"
    }
}

Validate-ConfiguredPaths

$backupDir = Join-Path $scriptDir "env-backups"
if (-not (Test-Path -LiteralPath $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = Join-Path $backupDir ("HKCU-Environment-" + $stamp + ".txt")
$origUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$origUserInclude = [Environment]::GetEnvironmentVariable("INCLUDE", "User")
$origUserLib = [Environment]::GetEnvironmentVariable("LIB", "User")
$origUserWatcom = [Environment]::GetEnvironmentVariable("WATCOM", "User")
$origUserEdPath = [Environment]::GetEnvironmentVariable("EDPATH", "User")
$origUserWHtmlHelp = [Environment]::GetEnvironmentVariable("WHTMLHELP", "User")
$origUserWipfc = [Environment]::GetEnvironmentVariable("WIPFC", "User")
$origUserBirthrtInstallDir = [Environment]::GetEnvironmentVariable("BIRTHRT_INSTALL_DIR", "User")
$origUserBirthrtCdIso = [Environment]::GetEnvironmentVariable("BIRTHRT_CD_ISO", "User")
$origUserBirthrtWinIso = [Environment]::GetEnvironmentVariable("BIRTHRT_WIN_ISO", "User")

@(
    "Original Path=$origUserPath"
    "Original INCLUDE=$origUserInclude"
    "Original LIB=$origUserLib"
    "Original WATCOM=$origUserWatcom"
    "Original EDPATH=$origUserEdPath"
    "Original WHTMLHELP=$origUserWHtmlHelp"
    "Original WIPFC=$origUserWipfc"
    "Original BIRTHRT_INSTALL_DIR=$origUserBirthrtInstallDir"
    "Original BIRTHRT_CD_ISO=$origUserBirthrtCdIso"
    "Original BIRTHRT_WIN_ISO=$origUserBirthrtWinIso"
) | Set-Content -Path $backupFile -Encoding ascii

[void](Write-UserVars)
Write-Host "Backup created: $backupFile"
Write-Host "User environment variables updated in HKCU\Environment."

$sessionPath = Merge-UniqueList -Existing $env:Path -Required $requiredPathRefs
$sessionInclude = Merge-UniqueList -Existing $env:INCLUDE -Required $requiredIncludeRefs
$sessionLib = Merge-UniqueList -Existing $env:LIB -Required $requiredLibRefs

$env:Path = $sessionPath
$env:INCLUDE = $sessionInclude
$env:LIB = $sessionLib
foreach ($name in $requiredScalars.Keys) {
    Set-Item -Path ("Env:" + $name) -Value $requiredScalars[$name]
}
foreach ($name in $optionalFileScalars.Keys) {
    Set-Item -Path ("Env:" + $name) -Value $optionalFileScalars[$name]
}

Write-Host "This shell was updated for immediate use."
Write-Host "Recommended verification: powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1"
Write-Host "Current effective environment variables for this shell:" -ForegroundColor Cyan
Write-Host "WIN95DDK=$Win95DdkRoot"
Write-Host "DXSDK=$DxSdkRoot"
Write-Host "OPENWATCOM_ROOT=$OpenWatcomRoot"
Write-Host "UASM=$UasmRoot"
Write-Host "INNOSETUP=$InnoSetupRoot"
Write-Host "BIRTHRT_INSTALL_DIR=$BirthrtInstallDir"
Write-Host "DIGITALV include path in INCLUDE=$DigitalvIncludeDir"
if ($optionalFileScalars.Contains("BIRTHRT_CD_ISO")) { Write-Host "BIRTHRT_CD_ISO=$($optionalFileScalars['BIRTHRT_CD_ISO'])" } else { Write-Host "BIRTHRT_CD_ISO=(not set - optional, test harness only)" }
if ($optionalFileScalars.Contains("BIRTHRT_WIN_ISO")) { Write-Host "BIRTHRT_WIN_ISO=$($optionalFileScalars['BIRTHRT_WIN_ISO'])" } else { Write-Host "BIRTHRT_WIN_ISO=(not set - optional, test harness VM mode only)" }
