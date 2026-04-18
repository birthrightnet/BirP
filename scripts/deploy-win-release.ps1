<#
.SYNOPSIS
Deploys the WIN95 release executable to C:\BIRTHRT.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-helper.ps1'

& $helper -Name 'WIN95 release deploy' -RelativeSourcePath 'build-artifacts\binaries\Release\Windows\nova95.exe'
exit $LASTEXITCODE
