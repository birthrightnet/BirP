<#
    Shared route helpers for the "start a new game from inside a running game"
    scenarios (issues #9, #12, #13).

    Dot-sourced by those scenarios; it is not a scenario itself (it defines no
    Invoke-BirpScenario).

    Coordinates are fractions of the client area, derived from the menu tables in
    GAMEMENU.H and MENUDATA.H against the game's 640x480 logical screen. A menu's
    button 0 gives the panel origin and the other buttons are offsets from it, so
    for example Adventures Only is panel (200,75) + button (48,174) with size
    (152,20), centre (324,259), which is (0.506, 0.540).
#>

# --- Main menu ------------------------------------------------------------------
# Click Begin New Game near the LEFT end of its row, at logical x 198. One physical
# click can be dispatched twice: the menu handler opens the game-type panel and
# then runs the menu loop again while the click is still pending, so a second
# dispatch lands on whatever the new panel put under the cursor. The game-type
# panel's buttons start at logical x 248, so clicking left of that leaves nothing
# for the second dispatch to hit. The menu row itself spans x 176..466.
$script:MENU_X            = 0.31
$script:MENU_NEWGAME_Y    = 0.587
$script:MENU_ITEMS_REGION = @(0.28, 0.55, 0.34, 0.35)

# --- Begin New Game: the game-type select panel (GameSelMenu) --------------------
$script:TYPE_X            = 0.5063
$script:TYPE_TUTORIAL_Y   = 0.4563   # SelectGameType 1
$script:TYPE_ADVENTURE_Y  = 0.5396   # SelectGameType 3
$script:TYPE_BATTLE_Y     = 0.5813   # SelectGameType 4
$script:TYPE_CANCEL_X     = 0.497
$script:TYPE_CANCEL_Y     = 0.710

# --- Tutorial complexity panel (GameCmplxMenu) ----------------------------------
$script:CMPLX_BASIC_X     = 0.5031   # SelectGameType 10
$script:CMPLX_BASIC_Y     = 0.5313

# --- Description pages shown on first entry to a mode (DescribeMenu) ------------
# Adventures Only shows NUM_ADVENTURE_SCREENS (2) pages, dismissed by one button.
$script:DESCRIBE_BTN_X    = 0.5
$script:DESCRIBE_BTN_Y    = 0.7667

# --- The game button, top right, opens the main menu in game ---------------------
$script:GAMEBTN_X         = 0.9641
$script:GAMEBTN_Y         = 0.0479

# --- Adventures Only site screen (BuildAdv panel, full 640x480) -----------------
# Party check boxes are added by RunAdvOnly at x 160..190, y 273 + 15*i, height 14.
$script:PARTY_CHECK_X     = 0.2734
$script:PARTY_CHECK_Y     = @(0.5875, 0.6188, 0.6500)
$script:ADV_DONE_X        = 0.1625
$script:ADV_DONE_Y        = 0.9542

# Launching an adventure stops at a Prepare Magic screen for every spellcaster in
# the party, one after another. Its Done button is the inventory panel's, at panel
# (100,50) + (300,312) size 84x28, so centre (442,376) in logical coordinates. The
# region below covers that button and is used to tell whether the screen is still
# up, since each caster's screen has identical chrome there.
$script:PREPMAGIC_DONE_X  = 0.6906
$script:PREPMAGIC_DONE_Y  = 0.7833
$script:PREPMAGIC_REGION  = @(0.625, 0.754, 0.131, 0.058)

# The committed main-menu baseline lives with the boot-and-menus scenario; reuse it
# rather than duplicating a 450 KB image per scenario.
$script:MAIN_MENU_REF = Join-Path $PSScriptRoot '..\references\boot-and-menus\main-menu.png'

function Test-BirpAlive {
    <#
      Is the game still healthy? Records a pass/fail step and returns $true/$false.
      Call after every click that could crash, so the report names the step that
      died and the scenario can stop instead of clicking blindly into a dead
      process or a modal fatal-error box.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Ctx,
        [Parameter(Mandatory)][string]$What
    )
    Start-Sleep -Milliseconds 750     # let a fatal path finish writing Fatal.err
    $dead = $null
    if ($Ctx.Process.HasExited) {
        $dead = "process exited (code $($Ctx.Process.ExitCode))"
    } else {
        $fatal = Join-Path $Ctx.InstallDir 'Fatal.err'
        if ((Test-Path $fatal) -and ((Get-Item $fatal).LastWriteTime -ge $Ctx.StartTime)) {
            $dead = "Fatal.err written"
        }
    }
    if ($dead) {
        & $Ctx.Assert $false "$What - game survived (FAILED: $dead)"
        return $false
    }
    & $Ctx.Assert $true "$What - game survived."
    return $true
}

function Enter-BirpMainMenu {
    <# Boot past the attract loop to the main menu. Returns the menu frame path. #>
    param([Parameter(Mandatory)][hashtable]$Ctx)

    & $Ctx.Note "Waiting for the title screen to settle ..."
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $titleShot = & $Ctx.Shot 'title-screen'

    # The attract loop is long - measured at 17 clicks from launch to the menu on a
    # debug build - so allow generous headroom. Stop only on a match with the
    # committed main-menu baseline: "click until something changed" settles on an
    # intermediate attract frame, and every later step here clicks fixed positions,
    # so starting from the wrong screen would click blindly into the game.
    & $Ctx.Note "Clicking through the attract loop until the main menu appears ..."
    $reached = $null
    if (Test-Path $script:MAIN_MENU_REF) {
        $reached = Invoke-BirpClickUntilReference -Hwnd $Ctx.Hwnd -Fx 0.5 -Fy 0.5 `
            -ReferencePath $script:MAIN_MENU_REF -Region $script:MENU_ITEMS_REGION `
            -MaxClicks 40 -MatchThreshold 0.10
        & $Ctx.Assert ($null -ne $reached) "Reached the main menu from the attract loop."
    }
    else {
        # No baseline to aim at; fall back, but say so - the run is on thin ice.
        & $Ctx.Note "No main-menu baseline found; falling back to click-until-changed."
        $reached = Invoke-BirpClickUntilChanged -Hwnd $Ctx.Hwnd -Fx 0.5 -Fy 0.5 `
            -BaselinePath $titleShot -MaxClicks 40 -ChangeThreshold 0.20
        & $Ctx.Assert ($null -ne $reached) "Left the title screen (no baseline to confirm the main menu)."
    }
    return (& $Ctx.Shot 'main-menu')
}

function Open-BirpGameTypePanel {
    <#
      Open Begin New Game and confirm the game-type panel appeared. $FromInGame
      opens the main menu with the game button first, which is the route the bug
      reports take. Returns the panel frame path, or $null if it did not open.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Ctx,
        [switch]$FromInGame,
        [string]$Label = 'game-type-select'
    )
    if ($FromInGame) {
        & $Ctx.Note "Opening the game menu with the game button ..."
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:GAMEBTN_X -Fy $script:GAMEBTN_Y
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
        $null = & $Ctx.Shot "$Label-menu"
    }

    & $Ctx.Note "Selecting Begin New Game ..."
    $before = & $Ctx.Shot "$Label-before"
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:MENU_X -Fy $script:MENU_NEWGAME_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
    $panel = & $Ctx.Shot $Label

    $changed = Compare-BirpFrame -PathA $before -PathB $panel
    $opened = ($changed -gt 0.03)
    & $Ctx.Assert $opened ("Begin New Game opened the game-type panel ({0:P1} frame change)." -f $changed)
    if (-not $opened) { return $null }
    return $panel
}

function Enter-BirpAdventuresOnly {
    <#
      From the game-type panel, pick Adventures Only and settle on the adventure
      site screen, dismissing the description pages shown on first entry.
      Returns the site-screen frame path.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Ctx,
        [string]$Label = 'adventure-site-screen',
        [switch]$SkipDescription
    )
    & $Ctx.Note "Choosing Adventures Only ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:TYPE_X -Fy $script:TYPE_ADVENTURE_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 30

    if (-not $SkipDescription) {
        # The Adventures Only description is two pages, and only ever appears once
        # per process (DESCRIBE.CPP keeps a have_seen flag), so clicking its button
        # a couple of times is harmless if it is not up: the site screen has no
        # control at that spot.
        & $Ctx.Note "Dismissing the Adventures Only description pages ..."
        for ($i = 0; $i -lt 2; $i++) {
            Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:DESCRIBE_BTN_X -Fy $script:DESCRIBE_BTN_Y
            $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
        }
    }
    return (& $Ctx.Shot $Label)
}

function Start-BirpAdventure {
    <#
      From the adventure site screen, put a few characters in the party and launch
      the adventure. Returns the loaded-scene frame path, or $null if the scene
      never loaded.

      The wait for the scene is bounded rather than open-ended, because a live
      adventure only settles into a stable frame once nothing is moving. If the
      party is attacked on the way in, the first stable frame can be the Defeat
      screen several minutes later, by which time the adventure is over and a
      scenario that needed it running has nothing to work with. Callers that must
      act while the party is alive should shorten these.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Ctx,
        [int]$SceneTimeoutSec = 120,
        [int]$SceneStableFrames = 4
    )

    & $Ctx.Note "Selecting party members ..."
    $beforeParty = & $Ctx.Shot 'party-before'
    foreach ($fy in $script:PARTY_CHECK_Y) {
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:PARTY_CHECK_X -Fy $fy
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 10
    }
    $afterParty = & $Ctx.Shot 'party-selected'
    $ticked = Compare-BirpFrame -PathA $beforeParty -PathB $afterParty
    & $Ctx.Assert ($ticked -gt 0.001) ("Party check boxes responded ({0:P2} frame change)." -f $ticked)

    & $Ctx.Note "Launching the adventure (Go on Adventure) ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:ADV_DONE_X -Fy $script:ADV_DONE_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 30
    $prep = & $Ctx.Shot 'prepare-magic'

    # Clear the Prepare Magic screen once per spellcaster. Stop as soon as the Done
    # button is no longer where it was, which means the last one has closed.
    for ($n = 0; $n -lt 6; $n++) {
        $stillUp = Compare-BirpFrameRegion -PathA $prep -PathB (Save-BirpFrame -Hwnd $Ctx.Hwnd `
            -Path (Join-Path $Ctx.RunDir "prep-probe-$n.png")) -Region $script:PREPMAGIC_REGION
        if ($stillUp -gt 0.15) { break }
        & $Ctx.Note "Prepare Magic screen $($n + 1) is up; clicking Done ..."
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:PREPMAGIC_DONE_X -Fy $script:PREPMAGIC_DONE_Y
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 30
    }

    & $Ctx.Note "Waiting for the adventure scene to load - this is slow ..."
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec $SceneTimeoutSec -RequiredStableFrames $SceneStableFrames
    $scene = & $Ctx.Shot 'adventure-scene'

    # The scene must differ from both the site screen and the Prepare Magic screen,
    # so neither of them still being up can pass as a loaded adventure.
    $vsSite = Compare-BirpFrame -PathA $afterParty -PathB $scene
    $vsPrep = Compare-BirpFrame -PathA $prep -PathB $scene
    $ok = (($vsSite -gt 0.30) -and ($vsPrep -gt 0.30))
    & $Ctx.Assert $ok ("The adventure scene loaded ({0:P1} from the site screen, {1:P1} from Prepare Magic)." -f $vsSite, $vsPrep)
    if (-not $ok) { return $null }
    return $scene
}
