<#
.SYNOPSIS
Builds and deploys the WIN (RELEASE) executable.

.PARAMETER SkipToolchainCheck
Passes -SkipToolchainCheck to the build script.

.PARAMETER MakeBatPath
Optional path override to MAKE.BAT. Passed to the build script.

.PARAMETER ShowInformationalOutput
When set, prints informational build output from the build step to the terminal.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-win-release.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath,
    [switch]$ShowInformationalOutput
)

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'build-and-deploy-helper.ps1'

& $helper -BuildScript 'build-win-release.ps1' -DeployScript 'deploy-win-release.ps1' -SkipToolchainCheck:$SkipToolchainCheck -MakeBatPath $MakeBatPath -ShowInformationalOutput:$ShowInformationalOutput
exit $LASTEXITCODE
