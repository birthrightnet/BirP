<#
get-release-notes.ps1

Prints one version's section of CHANGELOG.md, so the published release notes are
the notes that were already curated rather than a third hand-written list.

The section runs from the "## [X.Y.Z] - YYYY-MM-DD" heading to the next "## "
heading. The heading itself is left out: the release is already titled with its
version.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\get-release-notes.ps1 -Version 1.4.2
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\get-release-notes.ps1 -Version v1.4.2 -OutFile notes.md

  -Version   the version to extract. A leading "v" is accepted and ignored, so a
             tag name works directly.
  -OutFile   write to this file instead of standard output.

Exit code 0 when the section was found and is not empty, 1 otherwise.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'

if (-not (Test-Path -LiteralPath $changelogPath)) {
    Write-Error "CHANGELOG.md not found at $changelogPath"
    exit 1
}

# A tag name is an acceptable version. Trim the leading v.
$wanted = $Version.Trim()
if ($wanted -match '^[vV](.+)$') { $wanted = $Matches[1] }

$changelog = Get-Content -LiteralPath $changelogPath -Raw
$escaped = [regex]::Escape($wanted)

$match = [regex]::Match($changelog, "(?ms)^##\s*\[$escaped\](?:\s*-[^\r\n]*)?\r?\n(.*?)(?=^##\s|\z)")
if (-not $match.Success) {
    Write-Error "CHANGELOG.md has no section for version $wanted"
    exit 1
}

$body = $match.Groups[1].Value.Trim("`r", "`n", ' ')

if ([string]::IsNullOrWhiteSpace($body)) {
    Write-Error "The $wanted section of CHANGELOG.md is empty"
    exit 1
}

if ($OutFile) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutFile -Value $body -Encoding utf8
    Write-Host "Wrote the $wanted release notes to $OutFile"
} else {
    Write-Output $body
}

exit 0
