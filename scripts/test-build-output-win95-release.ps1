[CmdletBinding()]
param(
    [switch]$SkipToolchainCheck,
    [string]$MakeBatPath
)

$helper = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'test-build-output-helper.ps1'
& $helper -Name 'WIN95 release install' -OsTarget 'WIN95' -ScenarioTokens @('WIN95', '--release') -ExpectedArtifacts @('build-artifacts\binaries\Release\Windows\nova95.exe') -ExpectCleanStep $true -ExpectBuildExitCodeMarker $true -SkipToolchainCheck:$SkipToolchainCheck -MakeBatPath $MakeBatPath
exit $LASTEXITCODE
