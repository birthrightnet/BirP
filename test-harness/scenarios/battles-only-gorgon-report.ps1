<#
    Scenario: battles-only-gorgon-report  (issue #55)

    Every Battles Only scenario used to stamp the opposing army as Ghoere,
    whoever was actually fighting, because the scenario file lists unit types
    and nothing else. The battle report names the losing side's realm, so
    winning the Gorgon battle congratulated you on beating the forces of
    Ghoere.

    The opposing side now takes its realm from the scenario's named leader
    where there is one, so the Gorgon battle fields Gorgon's Crown.

    Route:
      title/attract -> main menu
        -> Begin New Game -> Battles Only -> battle setup screen
        -> pick scenario 30, Defeat the Gorgon
        -> Fight -> the battle resolves
        -> battle report, which must name Gorgon's Crown and not Ghoere

    The report is read from the captured screen rather than asserted on, since
    the harness cannot read text. The run proves the route is reachable and the
    battle resolves; the screenshot proves the name.

    Either outcome works. The winning text names the beaten realm and the
    losing text names whose battlefield control beat yours, and both come from
    the same realm.
#>

. (Join-Path $PSScriptRoot 'adventure-route.ps1')

# --- Battles Only setup screen (BuildArmys panel, full 640x480) -----------------
# The scenario list is shown first; its regions are added by AddScenariosRegions
# at x 170 and x 340, starting at y 219 and stepping 12, 130x10 each. Scenario 30
# is the last of the right-hand column, so y = 219 + 14*12 = 387, centre (405,392).
$script:SCENARIO30_X = 0.6328
$script:SCENARIO30_Y = 0.8167

# Scenario 1, first row of the left-hand column, centre (235,224). The game
# remembers the scenario you last picked between sessions, so the run starts by
# selecting this one. Otherwise a run that begins already on scenario 30 cannot
# tell a successful click from a click that missed.
$script:SCENARIO1_X  = 0.3672
$script:SCENARIO1_Y  = 0.4667

# Fight is panel (484,444) size 144x28, centre (556,458).
$script:FIGHT_X      = 0.8688
$script:FIGHT_Y      = 0.9542

# Each scenario has its own preview picture across the top middle of the screen
# (ui\btlscn\btlscnNN.pcx). That is the clearest sign a scenario click landed:
# the selected row itself is a single thin line of text and barely moves the
# frame at all.
$script:SCENPREVIEW_REGION = @(0.26, 0.01, 0.48, 0.22)

# Retreat, on the battlefield control bar, and the OK button of the "Surrender
# this battle?" confirmation (Question2 panel (142,120), button (28,76) 100x28).
$script:RETREAT_X    = 0.3875
$script:RETREAT_Y    = 0.9690
$script:CONFIRM_X    = 0.3438
$script:CONFIRM_Y    = 0.4375

function Invoke-BirpScenario {
    param([Parameter(Mandatory)][hashtable]$Ctx)

    $null = Enter-BirpMainMenu -Ctx $Ctx

    # 1. Battles Only from the main menu.
    $panel = Open-BirpGameTypePanel -Ctx $Ctx -Label 'game-type'
    if ($null -eq $panel) { & $Ctx.Note "Cannot continue: the game-type panel did not open."; return }

    & $Ctx.Note "Choosing Battles Only ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:TYPE_X -Fy $script:TYPE_BATTLE_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 30

    # Battles Only shows description pages on entry, and then the instructor
    # has his say over the setup screen. All are dismissed by a button in the
    # same place. Keep clicking until a click stops changing anything, rather
    # than guessing how many pages there are - the count differs between the
    # first visit and later ones.
    & $Ctx.Note "Dismissing the Battles Only description and instructor pages ..."
    $before = & $Ctx.Shot 'describe-0'
    for ($i = 1; $i -le 8; $i++) {
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:DESCRIBE_BTN_X -Fy $script:DESCRIBE_BTN_Y
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
        $after = & $Ctx.Shot "describe-$i"
        $moved = Compare-BirpFrame -PathA $before -PathB $after
        $before = $after
        if ($moved -lt 0.01) {
            & $Ctx.Note ("Page {0} produced no change; the dialogs are clear." -f $i)
            break
        }
    }

    $setup = & $Ctx.Shot 'battle-setup'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting the Battles Only game")) { return }
    $onSetup = ((Compare-BirpFrame -PathA $panel -PathB $setup) -gt 0.30)
    & $Ctx.Assert $onSetup "Battles Only opened the battle setup screen."
    if (-not $onSetup) { & $Ctx.Note "Cannot continue: not on the battle setup screen."; return }

    # 2. Move to scenario 1 first, so the move to 30 is a real change whatever
    #    the game remembered from last time, then pick the Gorgon scenario.
    & $Ctx.Note "Selecting scenario 1 as a known starting point ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:SCENARIO1_X -Fy $script:SCENARIO1_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $first = & $Ctx.Shot 'scenario-1-selected'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Selecting the first scenario")) { return }

    & $Ctx.Note "Selecting scenario 30, Defeat the Gorgon ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:SCENARIO30_X -Fy $script:SCENARIO30_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $picked = & $Ctx.Shot 'gorgon-scenario-selected'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Selecting the Gorgon scenario")) { return }

    $changed = Compare-BirpFrameRegion -PathA $first -PathB $picked -Region $script:SCENPREVIEW_REGION
    & $Ctx.Assert ($changed -gt 0.10) ("Selecting the Gorgon scenario brought up its own preview ({0:P1} change)." -f $changed)

    # 3. Fight. The battle plays itself out if we do nothing, which is enough:
    #    the report names the opposing realm whichever way it goes.
    & $Ctx.Note "Clicking Fight - the battle then resolves on its own ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:FIGHT_X -Fy $script:FIGHT_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 120 -RequiredStableFrames 3
    $field = & $Ctx.Shot 'battlefield'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting the Gorgon battle")) { return }

    $onField = ((Compare-BirpFrame -PathA $picked -PathB $field) -gt 0.30)
    & $Ctx.Assert $onField ("The battle loaded ({0:P1} from the setup screen)." -f (Compare-BirpFrame -PathA $picked -PathB $field))
    if (-not $onField) { & $Ctx.Note "Cannot continue: the battle did not load."; return }

    # 4. Neither side advances unless commanded, so the battle will sit there
    #    all day. Retreat instead: the defeat report names the realm whose
    #    battlefield control beat yours, which is the same name the victory
    #    report would use and is exactly what this issue is about.
    & $Ctx.Note "Retreating to bring up the battle report ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:RETREAT_X -Fy $script:RETREAT_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $confirm = & $Ctx.Shot 'surrender-confirm'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Asking to retreat")) { return }

    $asked = Compare-BirpFrame -PathA $field -PathB $confirm
    & $Ctx.Assert ($asked -gt 0.01) ("Retreat asked for confirmation ({0:P1} frame change)." -f $asked)

    & $Ctx.Note "Confirming the retreat ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:CONFIRM_X -Fy $script:CONFIRM_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 90 -RequiredStableFrames 4
    $null = & $Ctx.Shot 'battle-report'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Ending the Gorgon battle")) { return }

    & $Ctx.Note "Read battle-report.png: it must name Gorgon's Crown, not Ghoere."
    & $Ctx.Note "battles-only-gorgon-report scenario steps complete."
}
