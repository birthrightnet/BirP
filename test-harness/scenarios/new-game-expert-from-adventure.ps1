<#
    Scenario: new-game-expert-from-adventure  (issue #31)

    Starting an Expert Full Game while a scene was still running left the player on
    the realm map able to click provinces but with no left-hand window: no regent,
    no realm information, and no button to start the game. The reporter's log ends
    with the same region stack fatal as issue #13.

    Both come from the same place. The new game was built while the previous one
    was still running, so the character selection setup refused to run at all
    (it is guarded on being at the map level) and the running scene was released
    after the screen regions had already been wiped.

    Route:
      title/attract -> main menu
        -> Begin New Game -> Adventures Only -> site screen
        -> pick a party -> Done -> adventure scene
        -> game button -> Begin New Game -> Full Game -> Expert   <-- the failure point
        -> realm map in character selection, with its left window

    The reporter reached the running scene through Battles Only combat rather than
    an adventure. Either way the precondition is the same - a scene is live when
    Full Game is picked - and this route reaches it reliably, where driving Battles
    Only into combat depends on when the enemy closes.

    Run against a DEBUG build: the region stack fatal is a debug-build check.
#>

. (Join-Path $PSScriptRoot 'adventure-route.ps1')

# --- Begin New Game: Full Game (GameSelMenu, SelectGameType 2) -------------------
# Panel (200,75) + button (48,154) size 152x20, centre (324,239).
$script:TYPE_FULLGAME_Y = 0.4979

# --- Complexity panel: Expert (GameCmplxMenu, SelectGameType 12) -----------------
# Panel (202,136) + button (44,149) size 152x20, centre (322,295).
$script:CMPLX_EXPERT_X  = 0.5031
$script:CMPLX_EXPERT_Y  = 0.6146

# The left data area, which is what goes missing. In character selection the map is
# narrowed to make room for it, so this strip is panel rather than map terrain.
$script:LEFT_PANEL_REGION = @(0.0, 0.12, 0.20, 0.76)

# Alamie, near the middle of the map as it is framed when realm selection opens.
# It is a playable realm, so clicking it must fill the left panel with regent
# choices. That is the half of the report an empty-but-present panel would miss.
$script:REALM_ALAMIE_X    = 0.572
$script:REALM_ALAMIE_Y    = 0.567

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

    # Act while the party is still alive. Left to settle on its own, a scene under
    # attack only reaches a stable frame once the party is dead and the Defeat
    # screen is up, and then there is no running scene left to test with.
    $scene = Start-BirpAdventure -Ctx $Ctx -SceneTimeoutSec 40 -SceneStableFrames 2
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Launching the adventure")) { return }
    if ($null -eq $scene) { & $Ctx.Note "Cannot continue: the adventure scene did not load."; return }

    # 2. Start a Full Game from inside the adventure.
    $typePanel = Open-BirpGameTypePanel -Ctx $Ctx -FromInGame -Label 'expert-game-type'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening Begin New Game from inside the adventure")) { return }
    if ($null -eq $typePanel) { & $Ctx.Note "Cannot continue: the game-type panel did not open in the adventure."; return }

    & $Ctx.Note "Choosing Full Game ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:TYPE_X -Fy $script:TYPE_FULLGAME_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $cmplx = & $Ctx.Shot 'expert-complexity'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening the game complexity panel")) { return }
    $cmplxOpened = ((Compare-BirpFrame -PathA $typePanel -PathB $cmplx) -gt 0.02)
    & $Ctx.Assert $cmplxOpened "Full Game opened the complexity panel (Basic / Advanced / Expert)."
    if (-not $cmplxOpened) { & $Ctx.Note "Cannot continue: the complexity panel did not open."; return }

    & $Ctx.Note "Choosing Expert - this is the issue #31 failure point ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:CMPLX_EXPERT_X -Fy $script:CMPLX_EXPERT_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 120 -RequiredStableFrames 4
    $charsel = & $Ctx.Shot 'expert-character-selection'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting an Expert Full Game from inside an adventure")) { return }

    # 3. The character selection screen should have replaced the adventure.
    $left = Compare-BirpFrame -PathA $scene -PathB $charsel
    & $Ctx.Assert ($left -gt 0.30) ("The new game replaced the adventure ({0:P1} frame change)." -f $left)

    # 4. The left window is the whole point of the report: the player could click
    #    provinces but had no regent, no realm information and no start button.
    #    It is a panel when the setup ran and bare map when it did not, so compare
    #    the strip against the same strip of the adventure scene, which is also
    #    bare rendered scene. A missing panel leaves far less change here than a
    #    present one.
    $panelChange = Compare-BirpFrameRegion -PathA $scene -PathB $charsel -Region $script:LEFT_PANEL_REGION
    & $Ctx.Note ("Left data area change against the adventure scene: {0:P1}." -f $panelChange)
    & $Ctx.Assert ($panelChange -gt 0.30) ("The left data area was rebuilt for character selection ({0:P1} change)." -f $panelChange)

    # 5. The rest of the report: provinces could be clicked but no regent choices
    #    ever appeared and there was no way to start. Click a playable realm and
    #    confirm the left panel fills in.
    & $Ctx.Note "Clicking Alamie to bring up its regent choices ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:REALM_ALAMIE_X -Fy $script:REALM_ALAMIE_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $regents = & $Ctx.Shot 'expert-regent-choices'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Selecting a realm in character selection")) { return }

    $filled = Compare-BirpFrameRegion -PathA $charsel -PathB $regents -Region $script:LEFT_PANEL_REGION
    & $Ctx.Assert ($filled -gt 0.10) ("Clicking a realm filled the left window with regent choices ({0:P1} panel change)." -f $filled)

    # The game button is deliberately hidden during character selection, so do not
    # check the game menu here - its absence is correct, not a broken region stack.

    & $Ctx.Note "new-game-expert-from-adventure scenario steps complete."
}
