[CmdletBinding()]
param(
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath
)

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'build-helper.ps1'
& $helper -Name 'DOS release install' -OsTarget 'DOS' -ScenarioTokens @('DOS', '--release') -ExpectedArtifacts @('build-artifacts\binaries\Release\DOS\nova.exe') -ExpectCleanStep $true -ExpectBuildExitCodeMarker $true -SkipToolchainCheck:$SkipToolchainCheck -MakeBatPath $MakeBatPath
exit $LASTEXITCODE
