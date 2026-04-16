[CmdletBinding()]
param(
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath
)

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'test-build-output-helper.ps1'
& $helper -Name 'DOS profile install' -OsTarget 'DOS' -ScenarioTokens @('DOS', '--profile') -ExpectedArtifacts @('build-artifacts\binaries\Debug\DOS\nova.exe') -ExpectCleanStep $true -ExpectBuildExitCodeMarker $true -SkipToolchainCheck:$SkipToolchainCheck -MakeBatPath $MakeBatPath
exit $LASTEXITCODE
