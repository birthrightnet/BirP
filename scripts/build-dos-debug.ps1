[CmdletBinding()]
param(
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath
)

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'build-helper.ps1'
& $helper -Name 'DOS debug install' -OsTarget 'DOS' -ScenarioTokens @('DOS', '--debug') -ExpectedArtifacts @('build-artifacts\binaries\Debug\DOS\nova.exe') -ExpectCleanStep $true -ExpectBuildExitCodeMarker $true -SkipToolchainCheck:$SkipToolchainCheck -MakeBatPath $MakeBatPath
exit $LASTEXITCODE
