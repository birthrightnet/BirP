<#
.SYNOPSIS
Deploys the WIN95 debug executable to C:\BIRTHRT.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-build-output-helper.ps1'

& $helper -Name 'WIN95 debug deploy' -RelativeSourcePath 'build-artifacts\binaries\Debug\Windows\nova95.exe'
exit $LASTEXITCODE
