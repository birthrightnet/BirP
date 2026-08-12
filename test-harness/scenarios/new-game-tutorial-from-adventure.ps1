<#
    Scenario: new-game-tutorial-from-adventure  (issue #13)

    Starting a Tutorial game from inside a running adventure used to stop the game
    with "pop_regions. Popping too many times." The screen regions were wiped
    before the adventure was released, so the adventure's own teardown gave back a
    region stack level that no longer existed.

    Route:
      title/attract -> main menu
        -> Begin New Game -> Adventures Only -> site screen
        -> pick a party -> Done -> adventure scene
        -> game button -> Begin New Game -> Tutorial -> Basic   <-- the crash point
        -> tutorial realm map, still alive

    The failure is a debug-build fatal, so run this against a DEBUG build: a release
    build ignores the bad pop and carries on with a mismatched region stack instead.
    The harness fails the run on the FATAL log line either way.
#>

. (Join-Path $PSScriptRoot 'adventure-route.ps1')

function Invoke-BirpScenario {
    param([Parameter(Mandatory)][hashtable]$Ctx)

    $null = Enter-BirpMainMenu -Ctx $Ctx

    # 1. Get into a running adventure.
    $panel = Open-BirpGameTypePanel -Ctx $Ctx -Label 'game-type'
    if ($null -eq $panel) { & $Ctx.Note "Cannot continue: the game-type panel did not open."; return }

    $site = Enter-BirpAdventuresOnly -Ctx $Ctx
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting the Adventures Only game")) { return }

    $onSite = ((Compare-BirpFrame -PathA $panel -PathB $site) -gt 0.30)
    & $Ctx.Assert $onSite "Adventures Only opened the adventure site screen."
    if (-not $onSite) { & $Ctx.Note "Cannot continue: not on the adventure site screen."; return }

    $scene = Start-BirpAdventure -Ctx $Ctx
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Launching the adventure")) { return }
    if ($null -eq $scene) { & $Ctx.Note "Cannot continue: the adventure scene did not load."; return }

    # 2. Start a Tutorial game from inside the adventure.
    $typePanel = Open-BirpGameTypePanel -Ctx $Ctx -FromInGame -Label 'tutorial-game-type'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening Begin New Game from inside the adventure")) { return }
    if ($null -eq $typePanel) { & $Ctx.Note "Cannot continue: the game-type panel did not open in the adventure."; return }

    & $Ctx.Note "Choosing Tutorial ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:TYPE_X -Fy $script:TYPE_TUTORIAL_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $cmplx = & $Ctx.Shot 'tutorial-complexity'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening the tutorial complexity panel")) { return }
    $cmplxOpened = ((Compare-BirpFrame -PathA $typePanel -PathB $cmplx) -gt 0.02)
    & $Ctx.Assert $cmplxOpened "Tutorial opened the complexity panel (Basic / Advanced / Expert)."
    if (-not $cmplxOpened) { & $Ctx.Note "Cannot continue: the complexity panel did not open."; return }

    & $Ctx.Note "Choosing the Basic tutorial - this is the issue #13 crash point ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:CMPLX_BASIC_X -Fy $script:CMPLX_BASIC_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 90 -RequiredStableFrames 4
    $tutorial = & $Ctx.Shot 'tutorial-loaded'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting a Tutorial game from inside an adventure")) { return }

    # 3. The tutorial realm map should have replaced the adventure.
    $left = Compare-BirpFrame -PathA $scene -PathB $tutorial
    & $Ctx.Assert ($left -gt 0.30) ("The tutorial replaced the adventure ({0:P1} frame change)." -f $left)

    # 4. Prove the UI still responds after the rebuild. A mismatched region stack
    #    shows up as buttons that no longer do anything, so open the game menu and
    #    confirm it appears.
    & $Ctx.Note "Checking the game menu still opens after the rebuild ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:GAMEBTN_X -Fy $script:GAMEBTN_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
    $menu = & $Ctx.Shot 'tutorial-game-menu'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening the game menu in the new tutorial")) { return }
    $menuOpened = Compare-BirpFrame -PathA $tutorial -PathB $menu
    & $Ctx.Assert ($menuOpened -gt 0.05) ("The game button still opens the menu after the rebuild ({0:P1} frame change)." -f $menuOpened)

    & $Ctx.Note "new-game-tutorial-from-adventure scenario steps complete."
}
