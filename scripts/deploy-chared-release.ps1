<#
.SYNOPSIS
Deploys the WIN (RELEASE, CHARED) executable to BIRTHRT_INSTALL_DIR.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-helper.ps1'

& $helper -Name 'Deploying WIN (RELEASE, CHARED)...' -RelativeSourcePath 'build-artifacts\binaries\Release\Windows\chared.exe' -DestinationFileName 'CHARED.EXE'
exit $LASTEXITCODE
