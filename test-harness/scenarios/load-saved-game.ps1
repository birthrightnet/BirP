<#
    Scenario: load-saved-game  (issue #132)

    Loading a saved game now finishes leaving any running scene before the save
    data replaces the game state and before the screen regions are wiped. Loading
    is only offered at the map level, where there is no scene, so the change is
    inert on every route a player can take - which is exactly what this scenario
    checks. It is a regression test for the load path, not a reproduction.

    Route:
      title/attract -> main menu
        -> Load Saved Game -> pick the first save -> Load
        -> realm map, still alive, game menu still opens
        -> Load Saved Game again -> pick the first save -> Load
        -> realm map again, still alive

    The second load matters: the load path tears down and rebuilds the domain
    turn, and a region stack left one level out after the first load shows up as
    a dead game button or a fatal on the second pass rather than the first.

    Needs at least one saved game in <install>\SaveGame. The run is skipped with
    a clear note if the save list looks empty.
#>

. (Join-Path $PSScriptRoot 'adventure-route.ps1')

# --- Main menu: Load Saved Game -------------------------------------------------
# Clicked at the same left-end x as Begin New Game (see adventure-route.ps1): one
# physical click can be dispatched twice, and logical x 198 is left of everything
# the load dialog puts on screen, so the second dispatch has nothing to hit. The
# dialog's save rows start at logical x 248 and would otherwise catch it.
$script:MENU_LOAD_Y = 0.645

# --- The load file dialog (LoadOurMenu) -----------------------------------------
# Panel origin (200,80), size 236x296. PaintLoadSaveMenu adds a region per save row
# at panel + (48, 113 + 20*i), size 168x20, so row 0 centres on logical (332,203).
# Load is panel + (120,260) size 84x28, centre (362,354). Cancel is (278,354).
$script:LOAD_ROW_X      = 0.5188
$script:LOAD_ROW0_Y     = 0.4229
$script:LOAD_BTN_X      = 0.5656
$script:LOAD_BTN_Y      = 0.7375

# The map behind the menu shield scrolls continuously, so transition checks look
# only at the map-free interior of the dialog.
$script:DIALOG_REGION   = @(0.33, 0.34, 0.30, 0.32)

function Invoke-BirpLoadFirstSave {
    <#
      From a screen showing the main menu, open Load Saved Game, select the first
      save and load it. Returns the loaded frame path, or $null if any step did
      not take. $Label distinguishes the screenshots between passes.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Ctx,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$MenuShot
    )

    & $Ctx.Note "Opening Load Saved Game ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:MENU_X -Fy $script:MENU_LOAD_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $dialog = & $Ctx.Shot "$Label-load-dialog"
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening the load dialog ($Label)")) { return $null }

    $opened = Compare-BirpFrameRegion -PathA $MenuShot -PathB $dialog -Region $script:DIALOG_REGION
    $isOpen = ($opened -gt 0.05)
    & $Ctx.Assert $isOpen ("Load Saved Game opened the load dialog ({0:P1} dialog change)." -f $opened)
    if (-not $isOpen) { return $null }

    # Selecting a save highlights its row. The Load button does nothing at all
    # until something is selected, so a failure here means the rest is pointless.
    & $Ctx.Note "Selecting the first saved game in the list ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:LOAD_ROW_X -Fy $script:LOAD_ROW0_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
    $selected = & $Ctx.Shot "$Label-save-selected"
    $picked = Compare-BirpFrameRegion -PathA $dialog -PathB $selected -Region $script:DIALOG_REGION
    $isPicked = ($picked -gt 0.002)
    & $Ctx.Assert $isPicked ("The first saved game highlighted on click ({0:P2} dialog change)." -f $picked)
    if (-not $isPicked) {
        & $Ctx.Note "Cannot continue: no save was selected. Is <install>\SaveGame empty?"
        return $null
    }

    # The load itself: reads the save, rebuilds the realm map and the domain turn.
    & $Ctx.Note "Clicking Load - this reads the save and rebuilds the realm map ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:LOAD_BTN_X -Fy $script:LOAD_BTN_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 120 -RequiredStableFrames 4
    $loaded = & $Ctx.Shot "$Label-loaded"
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Loading a saved game ($Label)")) { return $null }

    # The dialog must be gone and the realm map up in its place.
    $left = Compare-BirpFrame -PathA $selected -PathB $loaded
    $done = ($left -gt 0.20)
    & $Ctx.Assert $done ("The loaded game replaced the load dialog ({0:P1} frame change)." -f $left)
    if (-not $done) { return $null }
    return $loaded
}

function Test-BirpGameMenuResponds {
    <#
      Open the game menu with the game button and confirm it appears, then close
      it again with Return to Game. A region stack left out of balance by the load
      shows up here as a button that no longer does anything.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Ctx,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$LoadedShot
    )

    & $Ctx.Note "Checking the game button still opens the menu after the load ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:GAMEBTN_X -Fy $script:GAMEBTN_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $menu = & $Ctx.Shot "$Label-game-menu"
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening the game menu after the load ($Label)")) { return $null }

    $opened = Compare-BirpFrame -PathA $LoadedShot -PathB $menu
    $isOpen = ($opened -gt 0.05)
    & $Ctx.Assert $isOpen ("The game button still opens the menu after the load ({0:P1} frame change)." -f $opened)
    if (-not $isOpen) { return $null }
    return $menu
}

function Invoke-BirpScenario {
    param([Parameter(Mandatory)][hashtable]$Ctx)

    $null = Enter-BirpMainMenu -Ctx $Ctx

    # A load needs something to load. Say so plainly rather than failing on a
    # click that could never have worked.
    $saveDir = Join-Path $Ctx.InstallDir 'SaveGame'
    $saves = @()
    if (Test-Path $saveDir) {
        $saves = @(Get-ChildItem -Path $saveDir -Filter '*.SAV' -ErrorAction SilentlyContinue)
    }
    & $Ctx.Assert ($saves.Count -gt 0) "Found $($saves.Count) saved game(s) in $saveDir to load."
    if ($saves.Count -eq 0) {
        & $Ctx.Note "Cannot continue: no saved games to load. Save a game first, then re-run."
        return
    }

    # 1. First load, straight from the boot main menu.
    $menuShot = & $Ctx.Shot 'main-menu-before-load'
    $loaded = Invoke-BirpLoadFirstSave -Ctx $Ctx -Label 'first' -MenuShot $menuShot
    if ($null -eq $loaded) { & $Ctx.Note "Cannot continue: the first load did not complete."; return }

    # 2. The rebuilt realm UI has to still work.
    $menu = Test-BirpGameMenuResponds -Ctx $Ctx -Label 'first' -LoadedShot $loaded
    if ($null -eq $menu) { & $Ctx.Note "Cannot continue: the game menu did not open after the first load."; return }

    # 3. Load again without quitting, from the menu that is already up. This is
    #    the pass that catches a region stack or domain turn left out of balance.
    $loaded2 = Invoke-BirpLoadFirstSave -Ctx $Ctx -Label 'second' -MenuShot $menu
    if ($null -eq $loaded2) { & $Ctx.Note "Cannot continue: the second load did not complete."; return }

    $null = Test-BirpGameMenuResponds -Ctx $Ctx -Label 'second' -LoadedShot $loaded2

    & $Ctx.Note "load-saved-game scenario steps complete."
}
