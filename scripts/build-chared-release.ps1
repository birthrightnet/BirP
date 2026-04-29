<#
.SYNOPSIS
Builds the WIN (RELEASE, CHARED) executable.

.DESCRIPTION
Builds the WIN (RELEASE, CHARED) executable, validates expected
build log markers and artifacts, and writes a single-scenario report under
birp-dev\build-artifacts\logs.

.PARAMETER SkipToolchainCheck
Skips required toolchain command checks (wmake/wcc386/wpp386).

.PARAMETER MakeBatPath
Optional path override to MAKE.BAT.

.PARAMETER ShowInformationalOutput
When set, prints informational build output to the terminal.
By default, only warnings and errors are printed.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-chared-release.ps1

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-chared-release.ps1 -ShowInformationalOutput
#>
[CmdletBinding()]
param(
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath,
    [switch]$ShowInformationalOutput
)

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'build-helper.ps1'
& $helper -Name 'WIN (RELEASE, CHARED)' -OsTarget 'WIN95' -ScenarioTokens @('WIN95', '--release', 'CHARED=ON') -ExpectedArtifacts @('build-artifacts\binaries\Release\Windows\chared.exe') -ExpectCleanStep $true -ExpectBuildExitCodeMarker $true -SkipToolchainCheck:$SkipToolchainCheck -MakeBatPath $MakeBatPath -ShowInformationalOutput:$ShowInformationalOutput
exit $LASTEXITCODE
