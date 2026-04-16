<#
.SYNOPSIS
Configures user and current-session environment variables for the Birthright Preservation Patch Open Watcom toolchain.

.DESCRIPTION
Adds required references for Open Watcom v2.0, Windows 95 DDK, DirectX SDK, and UASM to PATH, INCLUDE, and LIB without
creating duplicate entries. Also sets WATCOM, EDPATH, WHTMLHELP, and WIPFC in HKCU\Environment and for the current shell.
Before writing changes, the script creates a timestamped backup in birp-dev\scripts\env-backups.

.PARAMETER Win95DdkRoot
Optional override path for the Windows 95 DDK root. Defaults to birp-dependencies\Windows95DDK.

.PARAMETER DxSdkRoot
Optional override path for the DirectX SDK root. Defaults to birp-dependencies\DirectXSDK.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1 -Win95DdkRoot "D:\SDKs\Windows95DDK" -DxSdkRoot "D:\SDKs\DirectXSDK"

.NOTES
After running this script, validate deduplication with:
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1
#>

param(
    [string]$Win95DdkRoot,
    [string]$DxSdkRoot
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

$owRoot = Join-Path $repoRoot "birp-dependencies\OPENWATCOM-v2_0"
$uasmRoot = Join-Path $repoRoot "birp-dependencies\UASM-v2_57"
if ([string]::IsNullOrWhiteSpace($Win95DdkRoot)) {
    $Win95DdkRoot = Join-Path $repoRoot "birp-dependencies\Windows95DDK"
}
if ([string]::IsNullOrWhiteSpace($DxSdkRoot)) {
    $DxSdkRoot = Join-Path $repoRoot "birp-dependencies\DirectXSDK"
}

$owBinNt64 = Join-Path $owRoot "binnt64"
$owBinNt = Join-Path $owRoot "binnt"
$owH = Join-Path $owRoot "h"
$owHNt = Join-Path $owRoot "h\nt"
$owHNtDx = Join-Path $owRoot "h\nt\directx"
$owHNtDdk = Join-Path $owRoot "h\nt\ddk"
$owLib386 = Join-Path $owRoot "lib386"
$owLib386Nt = Join-Path $owRoot "lib386\nt"
$owEdPath = Join-Path $owRoot "eddat"
$owWHtmlHelp = Join-Path $owRoot "binnt\help"
$owWipfc = Join-Path $owRoot "wipfc"

$win95DdkInclude = Join-Path $Win95DdkRoot "INC32"
$win95DdkLib = Join-Path $Win95DdkRoot "LIB"
$dxSdkInclude = Join-Path $DxSdkRoot "sdk\inc"
$dxSdkLib = Join-Path $DxSdkRoot "sdk\lib"

$requiredPathRefs = @($owBinNt64, $owBinNt, $uasmRoot)
$requiredIncludeRefs = @($owH, $owHNt, $win95DdkInclude, $dxSdkInclude, $owHNtDx, $owHNtDdk)
$requiredLibRefs = @($owLib386, $owLib386Nt, $win95DdkLib, $dxSdkLib)

$requiredScalars = @{
    "WATCOM" = $owRoot
    "EDPATH" = $owEdPath
    "WHTMLHELP" = $owWHtmlHelp
    "WIPFC" = $owWipfc
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

    return @{
        Path = $newPath
        INCLUDE = $newInclude
        LIB = $newLib
    }
}

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

@(
    "Original Path=$origUserPath"
    "Original INCLUDE=$origUserInclude"
    "Original LIB=$origUserLib"
    "Original WATCOM=$origUserWatcom"
    "Original EDPATH=$origUserEdPath"
    "Original WHTMLHELP=$origUserWHtmlHelp"
    "Original WIPFC=$origUserWipfc"
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

Write-Host "This shell was updated for immediate use."
Write-Host "Active toolchain: Open Watcom v2.0"
Write-Host "Recommended verification: powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1"
Write-Host "WIN95DDK=$Win95DdkRoot"
Write-Host "DXSDK=$DxSdkRoot"
Write-Host "UASM=$uasmRoot"
