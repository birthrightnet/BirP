<#
.SYNOPSIS
Deploys the WIN (DEBUG, CHARED) executable to BIRTHRT_INSTALL_DIR.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-helper.ps1'

& $helper -Name 'Deploying WIN (DEBUG, CHARED)...' -RelativeSourcePath 'build-artifacts\binaries\Debug\Windows\chared.exe' -DestinationFileName 'CHARED.EXE'
exit $LASTEXITCODE
