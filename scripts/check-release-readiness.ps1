<#
check-release-readiness.ps1

Checks that the tree is ready to be tagged as a release. Everything the release
process expects to be true before the tag is asserted here, so a release is
never tagged with a stale date, a half-curated changelog, or version files that
disagree.

Checks:

  1. Version files  - PVERSION.HXX and README.txt agree at major.minor.patch,
                      and README.txt's Version: line is the four-part form with
                      a trailing zero.
  2. Changelog      - CHANGELOG.md carries a dated "## [X.Y.Z] - YYYY-MM-DD"
                      heading for this version, and nothing is left stranded
                      under "## [Unreleased]".
  3. Player readme  - README.txt's notes carry the matching "X.Y.Z - YYYY-MM-DD"
                      heading, and its header Date: line agrees with it.
  4. Notes content  - the version's changelog section is not empty.
  5. Tag            - vX.Y.Z does not already exist, locally or on the remote.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-release-readiness.ps1
  Options:
    -AllowExistingTag   do not fail when vX.Y.Z already exists. Use when the
                        workflow runs from the tag it is building.
    -SkipTagCheck       skip the tag check entirely (no git remote available).

Writes "version=X.Y.Z" and "tag=vX.Y.Z" to the file named by GITHUB_OUTPUT when
that variable is set, so a workflow can reuse the version it just validated.

Exit code 0 on pass, 1 on any failure.
#>

param(
    [switch]$AllowExistingTag,
    [switch]$SkipTagCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path

$pversionPath = Join-Path $repoRoot 'source\PVERSION.HXX'
$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
$readmePath = Join-Path $repoRoot 'README.txt'

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

# --- Check 1: version files agree ---

Write-Check 'Check 1: version files'

foreach ($p in @($pversionPath, $changelogPath, $readmePath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host "  [FAIL] missing: $p" -ForegroundColor Red
        exit 1
    }
}

$pversion = Get-Content -LiteralPath $pversionPath -Raw

function Get-VersionDefine([string]$Text, [string]$Name) {
    $m = [regex]::Match($Text, "(?m)^\s*#define\s+$Name\s+(\d+)\s*$")
    if (-not $m.Success) { return $null }
    return [int]$m.Groups[1].Value
}

$major = Get-VersionDefine $pversion 'BUILD_MAJOR'
$minor = Get-VersionDefine $pversion 'BUILD_MINOR'
$patch = Get-VersionDefine $pversion 'BUILD_PATCH'

Assert-True ($null -ne $major -and $null -ne $minor -and $null -ne $patch) 'PVERSION.HXX declares BUILD_MAJOR, BUILD_MINOR and BUILD_PATCH'
if ($script:Failures.Count -gt 0) {
    Write-Host 'Cannot read the version; stopping.' -ForegroundColor Red
    exit 1
}

$version = "$major.$minor.$patch"
$tag = "v$version"
Write-Host "  version from PVERSION.HXX: $version"

$readme = Get-Content -LiteralPath $readmePath -Raw

$versionLine = [regex]::Match($readme, '(?m)^Version:\s*(\S+)\s*$')
Assert-True $versionLine.Success 'README.txt has a Version: line'
if ($versionLine.Success) {
    $readmeVersion = $versionLine.Groups[1].Value
    Assert-True ($readmeVersion -eq "$version.0") "README.txt Version: reads $version.0 (got $readmeVersion)"
}

# --- Check 2: the changelog is curated and dated ---

Write-Check 'Check 2: changelog'

$changelog = Get-Content -LiteralPath $changelogPath -Raw

$escapedVersion = [regex]::Escape($version)
$versionHeading = [regex]::Match($changelog, "(?m)^##\s*\[$escapedVersion\]\s*-\s*(\d{4}-\d{2}-\d{2})\s*$")
Assert-True $versionHeading.Success "CHANGELOG.md has a dated heading '## [$version] - YYYY-MM-DD'"

$releaseDate = $null
if ($versionHeading.Success) {
    $releaseDate = $versionHeading.Groups[1].Value
    Write-Host "  release date: $releaseDate"

    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact($releaseDate, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)
    Assert-True $ok "release date $releaseDate is a real date"
    if ($ok) {
        Assert-True ($parsed -le (Get-Date).Date.AddDays(1)) "release date $releaseDate is not in the future"
    }
}

# Nothing may be left under Unreleased. The heading itself may stay as an empty
# placeholder for the next release, but entries under it mean the changelog was
# never curated for this one.
$unreleased = [regex]::Match($changelog, '(?ms)^##\s*\[Unreleased\]\s*$(.*?)(?=^##\s|\z)')
if ($unreleased.Success) {
    $stranded = @(
        $unreleased.Groups[1].Value -split "`r?`n" |
            Where-Object { $_.Trim() -ne '' -and $_.Trim() -notmatch '^###\s' }
    )
    $detail = ''
    if ($stranded.Count -gt 0) { $detail = " ($($stranded.Count) lines, first: $($stranded[0].Trim()))" }
    Assert-True ($stranded.Count -eq 0) "CHANGELOG.md leaves no entries under [Unreleased]$detail"
} else {
    Write-Host '  [PASS] CHANGELOG.md has no [Unreleased] section' -ForegroundColor Green
}

# --- Check 3: the player readme ---

Write-Check 'Check 3: player readme'

$readmeHeading = [regex]::Match($readme, "(?m)^$escapedVersion\s*-\s*(\d{4}-\d{2}-\d{2})\s*$")
Assert-True $readmeHeading.Success "README.txt notes carry the heading '$version - YYYY-MM-DD'"

if ($readmeHeading.Success -and $releaseDate) {
    Assert-True ($readmeHeading.Groups[1].Value -eq $releaseDate) "README.txt notes heading is dated $releaseDate, matching the changelog (got $($readmeHeading.Groups[1].Value))"
}

$dateLine = [regex]::Match($readme, '(?m)^Date:\s*(\S+)\s*$')
Assert-True $dateLine.Success 'README.txt has a Date: line'
if ($dateLine.Success -and $releaseDate) {
    Assert-True ($dateLine.Groups[1].Value -eq $releaseDate) "README.txt Date: reads $releaseDate (got $($dateLine.Groups[1].Value))"
}

# The player notes must not still be headed Unreleased.
$readmeUnreleased = [regex]::Match($readme, '(?m)^Unreleased\s*$')
Assert-True (-not $readmeUnreleased.Success) 'README.txt notes are not still headed "Unreleased"'

# --- Check 4: the notes say something ---

Write-Check 'Check 4: release notes content'

# A missing or empty section is a finding to report, not a reason to stop, so
# the remaining checks still run and the summary lists everything at once.
$notesScript = Join-Path $scriptDir 'get-release-notes.ps1'
$notes = @()
$notesOk = $false
if (Test-Path -LiteralPath $notesScript) {
    try {
        $notes = @(& $notesScript -Version $version -ErrorAction SilentlyContinue 2>$null)
        $notesOk = ($LASTEXITCODE -eq 0) -and -not [string]::IsNullOrWhiteSpace(($notes -join "`n"))
    } catch {
        $notesOk = $false
    }
}
Assert-True $notesOk "the $version changelog section has content to publish as release notes"
if ($notesOk) {
    $bullets = @(($notes -join "`n") -split "`r?`n" | Where-Object { $_ -match '^\s*-\s' })
    Write-Host "  $($bullets.Count) entries"
}

# --- Check 5: the tag is free ---

if ($SkipTagCheck) {
    Write-Check 'Check 5: tag (skipped)'
} else {
    Write-Check 'Check 5: tag'

    Push-Location $repoRoot
    try {
        $localTag = & git tag --list $tag 2>$null
        $exists = -not [string]::IsNullOrWhiteSpace(($localTag -join ''))

        # Check every remote rather than a fixed name: a developer clone calls
        # the GitHub remote "github", a runner's clone calls it "origin".
        if (-not $exists) {
            foreach ($remote in @(& git remote 2>$null)) {
                if ([string]::IsNullOrWhiteSpace($remote)) { continue }
                $remoteTag = & git ls-remote --tags $remote.Trim() "refs/tags/$tag" 2>$null
                if (-not [string]::IsNullOrWhiteSpace(($remoteTag -join ''))) {
                    $exists = $true
                    break
                }
            }
        }

        if ($AllowExistingTag) {
            Write-Host "  [PASS] $tag exists: $exists (not checked; -AllowExistingTag)" -ForegroundColor Green
        } else {
            Assert-True (-not $exists) "$tag does not exist yet"
        }
    } finally {
        Pop-Location
    }
}

# --- Summary ---

Write-Check 'Summary'

if ($env:GITHUB_OUTPUT) {
    "version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "tag=$tag" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

if ($script:Failures.Count -gt 0) {
    Write-Host "$($script:Failures.Count) check(s) failed:" -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'See docs/release-process.md for what each step expects.' -ForegroundColor Yellow
    exit 1
}

Write-Host "Ready to release $tag." -ForegroundColor Green
exit 0
