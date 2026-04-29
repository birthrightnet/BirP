<#
.SYNOPSIS
Deploys the DOS debug executable to BIRTHRT_INSTALL_DIR.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-helper.ps1'

& $helper -Name 'Deploying DOS (DEBUG)...' -RelativeSourcePath 'build-artifacts\binaries\Debug\DOS\nova.exe'
exit $LASTEXITCODE
