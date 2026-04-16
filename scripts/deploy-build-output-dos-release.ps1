<#
.SYNOPSIS
Deploys the DOS release executable to C:\BIRTHRT.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-build-output-helper.ps1'

& $helper -Name 'DOS release deploy' -RelativeSourcePath 'build-artifacts\binaries\Release\DOS\nova.exe'
exit $LASTEXITCODE
