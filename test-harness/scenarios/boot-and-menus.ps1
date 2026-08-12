<#
    Scenario: boot-and-menus

    The first milestone (issue #58): prove the harness can boot the game, reach the
    main menu, walk the top-level menu screens, screenshot each state, verify the
    transitions happened, detect no crash, and quit cleanly from the menu.

    Route:
      title/attract -> main menu
        -> Options (walk all six settings tabs) -> back to menu
        -> Help submenu -> back to menu
        -> Quit -> confirm dialog -> Yes (clean exit)

    Coordinates are expressed as fractions of the client area so they hold across
    resolutions (the layout is 4:3 at every preset, so the same fractions land). They
    were read off captures at 1024x768 and 1600x1200. The reference images, by
    contrast, are resolution-specific - re-capture them with -UpdateReferences if the
    game runs at a different client size (see the harness README).

    Contract: define Invoke-BirpScenario -Ctx <hashtable>. The orchestrator provides
    $Ctx with: Hwnd, Process, InstallDir, RunDir, and script-block helpers
    Shot/Assert/Note/ExpectExit. Module functions (Wait-BirpStable, Invoke-BirpClick,
    Compare-BirpFrame, Compare-BirpFrameRegion) are already imported.

    Note on transition checks: the map behind the menu shield scrolls continuously,
    so any check region that includes the map will show a few percent of diff even
    when nothing changed. All open/close checks therefore compare only the map-free
    dialog interior (the centered shield/panel), never the frame edges.
#>

# --- Main-menu item click points (fractions of the client area) -----------------
# The menu items sit in the centered shield; x ~0.46 hits the middle of each label.
$MENU_X          = 0.46
$MENU_NEWGAME_Y  = 0.587
$MENU_LOAD_Y     = 0.645
$MENU_OPTIONS_Y  = 0.75
$MENU_HELP_Y     = 0.855
$MENU_QUIT_Y     = 0.90

# Multiplayer (main-menu item ~0.804) is intentionally not walked here: from the
# boot menu it either does nothing (it is gated to the in-game map level) or tears
# the menu down into multiplayer connection setup, which is hard to back out of and
# may touch comms hardware. It belongs to a later in-game scenario reached via the
# planned DBGWIND jump seam.

# --- Begin New Game: the game-type select panel (Cancel returns to the menu) -----
# First-pass Cancel position (read off the game-type panel capture).
$NEWGAME_CANCEL_X = 0.497
$NEWGAME_CANCEL_Y = 0.71

# --- Load Saved Game: the load file dialog (Cancel returns to the menu) -----------
# The dialog lists saved games with Delete / Cancel / Load buttons; Cancel is the
# lower-left button (read off a 1600x1200 capture).
$LOAD_CANCEL_X    = 0.43
$LOAD_CANCEL_Y    = 0.74

# The static menu-items region of the shield (map-free). Used to confirm we are back
# on the main menu after backing out of a branch, so a failed back-out cannot cascade
# into the next branch (e.g. accidentally starting a game).
$MENU_ITEMS_REGION = @(0.28, 0.55, 0.34, 0.35)

# --- Options screen: left settings tabs (x) and their row centers (y) -----------
$OPT_TAB_X       = 0.334
$OPT_TABS = @(
    @{ Name = 'battle-settings';    Y = 0.465 }
    @{ Name = 'adventure-settings'; Y = 0.516 }
    @{ Name = 'music-and-sound';    Y = 0.565 }
    @{ Name = 'screen-settings';    Y = 0.616 }
    @{ Name = 'game-speed';         Y = 0.665 }
)
# Options bottom buttons (we close with Cancel so no change is persisted).
$OPT_CANCEL_X    = 0.493
$OPT_BUTTONS_Y   = 0.744

# The Options content panel (right of the tabs) is what changes per tab. Reference-
# check only that panel so the scrolling map behind the dialog is ignored.
$OPT_PANEL_REGION = @(0.46, 0.33, 0.32, 0.32)

# --- Help submenu ---------------------------------------------------------------
# The Help submenu opens over the shield; its Done button (mouse-only close, since
# keyboard focus is not reliable for a polled-input GDI game) sits mid-dialog.
$HELP_DONE_X     = 0.494
$HELP_DONE_Y     = 0.66

# --- Quit confirmation dialog (D_QUESTION3): Yes / Cancel / Credits --------------
# The three buttons sit in a row across the dialog; Yes is the left one. Read off a
# 1600x1200 capture.
$QUIT_YES_X      = 0.345
$QUIT_BTN_Y      = 0.44

# Map-free interior of the centered shield/dialog. Used for every open/close check
# so the scrolling map at the frame edges cannot fake a transition.
$DIALOG_REGION   = @(0.33, 0.34, 0.30, 0.32)

function Invoke-BirpScenario {
    param([Parameter(Mandatory)][hashtable]$Ctx)

    $hwnd = $Ctx.Hwnd

    # 1. Title / attract screen: let it settle, screenshot, sanity-check the window.
    & $Ctx.Note "Waiting for the title screen to settle ..."
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 20
    $titleShot = & $Ctx.Shot 'title-screen'
    $sz = Get-BirpClientSize -Hwnd $hwnd
    & $Ctx.Assert (($sz.Width -ge 600) -and ($sz.Height -ge 400)) "Game window has a usable client area ($($sz.Width)x$($sz.Height))."

    # 2. Advance the attract loop to the main menu. The title is an attract loop that
    #    cycles title art with an intro animation (a flaming Gorgon, logos, etc.), so
    #    "click until something changed" is not enough - it can settle on an attract
    #    frame that merely differs from the title. Instead click center until the
    #    menu-items region matches the committed main-menu reference, so we stop only
    #    when the real menu is up. Center clicks are safe on the menu (its items sit
    #    lower and to the left, not under the center emblem). If no baseline exists yet
    #    (first -UpdateReferences run) or it does not match (e.g. a different
    #    resolution), fall back to click-until-changed.
    & $Ctx.Note "Clicking through the attract loop until the main menu appears ..."
    $mainMenuRef = Join-Path $Ctx.RefDir 'main-menu.png'
    # 40 clicks of headroom: the attract loop is longer than it looks - a launch on a
    # debug build measured 17 clicks to the menu, so the old limit of 16 fell one
    # short and dropped through to the fallback, which then settled on an attract
    # frame and failed every screen check after it.
    $reached = Invoke-BirpClickUntilReference -Hwnd $hwnd -Fx 0.5 -Fy 0.5 -ReferencePath $mainMenuRef -Region $MENU_ITEMS_REGION -MaxClicks 40 -MatchThreshold 0.10
    if ($null -eq $reached) {
        & $Ctx.Note "No matching main-menu baseline; falling back to click-until-changed."
        $reached = Invoke-BirpClickUntilChanged -Hwnd $hwnd -Fx 0.5 -Fy 0.5 -BaselinePath $titleShot -MaxClicks 8 -ChangeThreshold 0.20
    }
    & $Ctx.Assert ($null -ne $reached) "Clicking advanced through the attract loop to the main menu."
    # The menu shield is static but the map behind it scrolls, so reference-check
    # only the menu-items region of the shield (kept clear of the glowing emblem
    # above and the map to the right).
    $menuShot = & $Ctx.Shot 'main-menu' $true $MENU_ITEMS_REGION

    # 2b. Begin New Game -> the game-type select panel (Quick Summary / Tutorial /
    #     Full Game / Adventures Only / Battles Only / Historical Background). Open
    #     it, screenshot it, then back out with Cancel WITHOUT choosing a type - we
    #     only want to prove the screen. Confirm we returned to the main menu before
    #     doing anything else, so a missed Cancel cannot cascade into the next click
    #     landing on a game-type and starting a real game.
    & $Ctx.Note "Opening Begin New Game (game-type select) ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $MENU_X -Fy $MENU_NEWGAME_Y
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
    $newGameShot = & $Ctx.Shot 'new-game-select' $true $DIALOG_REGION
    $menuToNew = Compare-BirpFrameRegion -PathA $menuShot -PathB $newGameShot -Region $DIALOG_REGION
    & $Ctx.Assert ($menuToNew -gt 0.05) "Selecting Begin New Game opened the game-type select panel."

    & $Ctx.Note "Backing out of Begin New Game (Cancel) ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $NEWGAME_CANCEL_X -Fy $NEWGAME_CANCEL_Y
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
    $afterNewShot = & $Ctx.Shot 'menu-after-new-game'
    $backAtMenuNew = Compare-BirpFrameRegion -PathA $menuShot -PathB $afterNewShot -Region $MENU_ITEMS_REGION
    & $Ctx.Assert ($backAtMenuNew -le 0.10) "Cancel returned to the main menu from Begin New Game (menu items match)."
    $atMenu = ($backAtMenuNew -le 0.10)

    # 2c. Load Saved Game -> the load file dialog. Only attempt if we are safely back
    #     on the main menu (guard against a cascade from a failed Cancel above).
    if ($atMenu) {
        & $Ctx.Note "Opening Load Saved Game (load file dialog) ..."
        Invoke-BirpClick -Hwnd $hwnd -Fx $MENU_X -Fy $MENU_LOAD_Y
        $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
        $loadShot = & $Ctx.Shot 'load-dialog' $true $DIALOG_REGION
        $menuToLoad = Compare-BirpFrameRegion -PathA $afterNewShot -PathB $loadShot -Region $DIALOG_REGION
        & $Ctx.Assert ($menuToLoad -gt 0.05) "Selecting Load Saved Game opened the load file dialog."

        & $Ctx.Note "Backing out of Load Saved Game (Cancel) ..."
        Invoke-BirpClick -Hwnd $hwnd -Fx $LOAD_CANCEL_X -Fy $LOAD_CANCEL_Y
        $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
        $afterLoadShot = & $Ctx.Shot 'menu-after-load'
        $backAtMenuLoad = Compare-BirpFrameRegion -PathA $menuShot -PathB $afterLoadShot -Region $MENU_ITEMS_REGION
        & $Ctx.Assert ($backAtMenuLoad -le 0.10) "Cancel returned to the main menu from Load Saved Game (menu items match)."
    } else {
        & $Ctx.Note "Skipping Load Saved Game: not safely back on the main menu after Begin New Game."
    }

    # 3. Open the Options screen from the main menu. "Options" is an enabled (bright)
    #    item ~75% down. ("Return to Game" and "Save Current Game" are disabled with
    #    no game in progress, so they are not reliable targets.)
    & $Ctx.Note "Opening the Options screen from the main menu ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $MENU_X -Fy $MENU_OPTIONS_Y
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 15
    # The Options dialog is an opaque panel; reference-check its interior.
    $optionsShot = & $Ctx.Shot 'options-screen' $true @(0.24, 0.22, 0.52, 0.52)
    $menuToOptions = Compare-BirpFrame -PathA $menuShot -PathB $optionsShot
    & $Ctx.Note ("Main menu -> Options frame change: {0:P1}" -f $menuToOptions)
    & $Ctx.Assert ($menuToOptions -gt 0.05) "Selecting Options opened a different screen."

    # 4. Walk each Options settings tab. Game Settings is already shown; click the
    #    remaining tabs (Battle, Adventure, Music & Sound, Screen, Game Speed) and
    #    confirm each one swaps the content panel, screenshotting each panel.
    $prevPanel = $optionsShot
    foreach ($tab in $OPT_TABS) {
        & $Ctx.Note "Opening Options tab: $($tab.Name) ..."
        Invoke-BirpClick -Hwnd $hwnd -Fx $OPT_TAB_X -Fy $tab.Y
        $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
        $panelShot = & $Ctx.Shot $tab.Name $true $OPT_PANEL_REGION
        $changed = Compare-BirpFrameRegion -PathA $prevPanel -PathB $panelShot -Region $OPT_PANEL_REGION
        & $Ctx.Note ("Options panel change into $($tab.Name): {0:P1}" -f $changed)
        & $Ctx.Assert ($changed -gt 0.03) "Selecting the $($tab.Name) tab changed the Options content panel."
        $prevPanel = $panelShot
    }

    # 5. Close the Options screen (Cancel discards any accidental change) and confirm
    #    we are back on the main menu.
    & $Ctx.Note "Closing the Options screen (Cancel) ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $OPT_CANCEL_X -Fy $OPT_BUTTONS_Y
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 15
    $backShot = & $Ctx.Shot 'menu-after-options'
    $optionsToMenu = Compare-BirpFrameRegion -PathA $optionsShot -PathB $backShot -Region @(0.24, 0.22, 0.52, 0.52)
    & $Ctx.Assert ($optionsToMenu -gt 0.05) "Closing Options returned to a different screen (the main menu)."

    # 6. Open the Help submenu, screenshot it, then back out with its Done button.
    #    (ESC would be simpler but keyboard focus is unreliable for this polled-input
    #    GDI game, so we click Done - the proven mouse-only path.)
    & $Ctx.Note "Opening the Help submenu ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $MENU_X -Fy $MENU_HELP_Y
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
    $helpShot = & $Ctx.Shot 'help-menu' $true $DIALOG_REGION
    $menuToHelp = Compare-BirpFrameRegion -PathA $backShot -PathB $helpShot -Region $DIALOG_REGION
    & $Ctx.Assert ($menuToHelp -gt 0.05) "Selecting Help opened a different screen (the Help submenu)."

    & $Ctx.Note "Closing the Help submenu (Done) ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $HELP_DONE_X -Fy $HELP_DONE_Y
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
    $afterHelpShot = & $Ctx.Shot 'menu-after-help'
    $helpClosed = Compare-BirpFrameRegion -PathA $helpShot -PathB $afterHelpShot -Region $DIALOG_REGION
    & $Ctx.Assert ($helpClosed -gt 0.05) "Done closed the Help submenu (returned to the main menu)."

    # 7. Open the Quit confirmation dialog and verify it appears (Yes / Cancel /
    #    Credits, "Are you sure you want to quit?").
    & $Ctx.Note "Opening the Quit confirmation dialog ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $MENU_X -Fy $MENU_QUIT_Y
    $null = Wait-BirpStable -Hwnd $hwnd -TimeoutSec 12
    $quitShot = & $Ctx.Shot 'quit-confirm' $true $DIALOG_REGION
    $menuToQuit = Compare-BirpFrameRegion -PathA $afterHelpShot -PathB $quitShot -Region $DIALOG_REGION
    & $Ctx.Assert ($menuToQuit -gt 0.05) "Selecting Quit opened the confirmation dialog."

    # 8. Confirm the quit (Yes). The game exits; tell the orchestrator this exit is
    #    expected so it is scored as a clean quit, not a crash.
    & $Ctx.Note "Confirming Quit (Yes) - the game should exit cleanly ..."
    Invoke-BirpClick -Hwnd $hwnd -Fx $QUIT_YES_X -Fy $QUIT_BTN_Y
    & $Ctx.ExpectExit

    & $Ctx.Note "boot-and-menus scenario steps complete."
}
