<#
release-build-package.ps1

Builds all three release binaries with BUILD_BUILD set from the first 2 bytes
of the current git commit (first 4 hex chars), copies resulting exes to the
Installer binaries directory, then builds the installer with iscc.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine repository root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path

# Ensure installer directory exists
$installerDir = Join-Path $repoRoot 'build-artifacts\binaries\Installer'
if (-not (Test-Path $installerDir)) { New-Item -ItemType Directory -Path $installerDir | Out-Null }
Remove-Item -Path "$installerDir\*.exe"
Remove-Item -Path "$installerDir\*.zip"

# Define builds to run: MAKE.BAT args, expected output, and destination name in Installer dir
$builds = @(
    @{ MakeArgs = @('DOS', '--release'); Output = 'build-artifacts\binaries\Release\DOS\nova.exe'; Dest = 'NOVA.EXE' },
    @{ MakeArgs = @('WIN95', '--release'); Output = 'build-artifacts\binaries\Release\Windows\nova95.exe'; Dest = 'WINBR.EXE' },
    @{ MakeArgs = @('WIN95', '--release', 'CHARED=ON'); Output = 'build-artifacts\binaries\Release\Windows\chared.exe'; Dest = 'CHARED.EXE' }
)

$makeBatPath = Join-Path $repoRoot 'MAKE.BAT'
if (-not (Test-Path $makeBatPath)) {
    Write-Error "MAKE.BAT not found at $makeBatPath"
    exit 1
}

foreach ($b in $builds) {
    # Build using build-helper.ps1, passing BUILD_BUILD as an extra argument to MAKE.BAT.
    $scenarioTokens = $b.MakeArgs -join ' '
    
    & "$scriptDir\build-helper.ps1" `
        -Name "Release build: $($b.Dest)" `
        -OsTarget $b.MakeArgs[0] `
        -ScenarioTokens $scenarioTokens `
        -ExpectedArtifacts @($b.Output) `
        -ExpectCleanStep $true `
        -ExpectBuildExitCodeMarker $true `
        -ShowInformationalOutput
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "build-helper failed for $($b.Dest) with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # Copy the expected output into the installer folder
    $outPath = Join-Path $repoRoot $b.Output
    Copy-Item -Force -Path $outPath -Destination (Join-Path $installerDir $b.Dest)
    Write-Host "Copied $outPath -> $installerDir\$($b.Dest)"
}

# Get version from WINBR.EXE
$winbrPath = Join-Path $installerDir 'WINBR.EXE'
$version = (Get-Item $winbrPath).VersionInfo.FileVersion
if ([string]::IsNullOrWhiteSpace($version)) {
    Write-Error "Could not retrieve version from $winbrPath"
    exit 1
}
# Sanitize version string (replace commas with dots, remove spaces)
$version = $version.Replace(',', '.').Replace(' ', '')
$releaseName = "Birthrt-Preservation-Patch-$version"

# Build the installer (Inno Setup Compiler)
Write-Host "Building installer (iscc)..."
Push-Location $repoRoot
try {
    & iscc "/DMyAppSetupFile=$releaseName" "installer\installer.iss"
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
        Write-Error "iscc failed with exit code $rc"
        exit $rc
    }
} finally {
    Pop-Location
}

# Build zip archive
$zipPath = Join-Path $installerDir "$releaseName.zip"
Compress-Archive -Force -Path "$installerDir\CHARED.EXE", "$installerDir\NOVA.EXE", "$installerDir\WINBR.EXE", "$repoRoot\README.txt" -DestinationPath $zipPath

Write-Host "Release package completed successfully."
