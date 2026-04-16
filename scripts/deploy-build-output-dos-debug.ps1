<#
.SYNOPSIS
Deploys the DOS debug executable to C:\BIRTHRT.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-build-output-helper.ps1'

& $helper -Name 'DOS debug deploy' -RelativeSourcePath 'build-artifacts\binaries\Debug\DOS\nova.exe'
exit $LASTEXITCODE
