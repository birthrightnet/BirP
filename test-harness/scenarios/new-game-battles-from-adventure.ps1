<#
    Scenario: new-game-battles-from-adventure  (issue #12)

    Starting a Battles Only game from inside a running adventure used to die with
    "MEMMANAGE ERROR! Block ... has been free'd." The adventure was released before
    the game type was switched, so returning to the map reopened the adventure
    setup screen, which wrote a full save out of avatar and inventory blocks the
    release had just freed.

    Route:
      title/attract -> main menu
        -> Begin New Game -> Adventures Only -> site screen
        -> pick a party -> Done -> adventure scene
        -> game button -> Begin New Game -> Battles Only   <-- the crash point
        -> battle setup screen, still alive

    The reported repro is from adventure combat; this drives it from exploration,
    which reaches the same code with far less to go wrong. Both go through the same
    scene release.
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

    # 2. Start a Battles Only game from inside the adventure.
    $typePanel = Open-BirpGameTypePanel -Ctx $Ctx -FromInGame -Label 'battles-game-type'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening Begin New Game from inside the adventure")) { return }
    if ($null -eq $typePanel) { & $Ctx.Note "Cannot continue: the game-type panel did not open in the adventure."; return }

    & $Ctx.Note "Choosing Battles Only - this is the issue #12 crash point ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:TYPE_X -Fy $script:TYPE_BATTLE_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 90 -RequiredStableFrames 4
    $battles = & $Ctx.Shot 'battles-setup'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting a Battles Only game from inside an adventure")) { return }

    # 3. The battle setup screen should have replaced the adventure. If the old
    #    adventure setup screen were reopened underneath, this is where it would
    #    show up as the wrong screen.
    $left = Compare-BirpFrame -PathA $scene -PathB $battles
    & $Ctx.Assert ($left -gt 0.30) ("The battle setup screen replaced the adventure ({0:P1} frame change)." -f $left)

    $notSiteScreen = Compare-BirpFrame -PathA $site -PathB $battles
    & $Ctx.Assert ($notSiteScreen -gt 0.10) ("The battle setup screen is not the adventure site screen ({0:P1} differs)." -f $notSiteScreen)

    # 4. Battles Only opens with its own description, three pages, over the setup
    #    screen. Clear it before touching anything else - it covers the game button.
    & $Ctx.Note "Dismissing the Battles Only description pages ..."
    for ($i = 0; $i -lt 3; $i++) {
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:DESCRIBE_BTN_X -Fy $script:DESCRIBE_BTN_Y
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
    }
    $battles = & $Ctx.Shot 'battles-setup-clear'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Clearing the Battles Only description")) { return }

    # 5. Prove the UI still responds after the rebuild.
    & $Ctx.Note "Checking the game menu still opens after the rebuild ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:GAMEBTN_X -Fy $script:GAMEBTN_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
    $menu = & $Ctx.Shot 'battles-game-menu'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening the game menu in the new Battles Only game")) { return }
    $menuOpened = Compare-BirpFrame -PathA $battles -PathB $menu
    & $Ctx.Assert ($menuOpened -gt 0.05) ("The game button still opens the menu after the rebuild ({0:P1} frame change)." -f $menuOpened)

    & $Ctx.Note "new-game-battles-from-adventure scenario steps complete."
}
