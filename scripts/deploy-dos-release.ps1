<#
.SYNOPSIS
Deploys the DOS (RELEASE) executable to BIRTHRT_INSTALL_DIR.
#>

[CmdletBinding()]
param()

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'deploy-helper.ps1'

& $helper -Name 'Deploying DOS (RELEASE)...' -RelativeSourcePath 'build-artifacts\binaries\Release\DOS\nova.exe'
exit $LASTEXITCODE
