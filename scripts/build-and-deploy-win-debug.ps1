<#
.SYNOPSIS
Builds and deploys the WIN95 debug executable.

.PARAMETER SkipToolchainCheck
Passes -SkipToolchainCheck to the build script.

.PARAMETER MakeBatPath
Optional path override to MAKE.BAT. Passed to the build script.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-win-debug.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath
)

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'build-and-deploy-helper.ps1'

& $helper -BuildScript 'build-win-debug.ps1' -DeployScript 'deploy-win-debug.ps1' -SkipToolchainCheck:$SkipToolchainCheck -MakeBatPath $MakeBatPath
exit $LASTEXITCODE
