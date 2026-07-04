<#
.SYNOPSIS
Deploys the WIN debug executable to BIRTHRT_INSTALL_DIR.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-helper.ps1'

& $helper -Name 'Deploying WIN (DEBUG)...' -RelativeSourcePath 'build-artifacts\binaries\Debug\Windows\nova95.exe' -DestinationFileName 'WINBR.EXE'
exit $LASTEXITCODE
