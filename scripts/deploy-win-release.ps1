<#
.SYNOPSIS
Deploys the WIN (RELEASE) executable to BIRTHRT_INSTALL_DIR.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-helper.ps1'

& $helper -Name 'Deploying WIN (RELEASE)...' -RelativeSourcePath 'build-artifacts\binaries\Release\Windows\nova95.exe' -DestinationFileName 'WINBR.EXE'
exit $LASTEXITCODE
