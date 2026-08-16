<#
    Scenario: adventure-carry-limit  (issue #60)

    A character could carry only 20 different kinds of thing. Quantity was never
    limited, so the limit only ever showed up as shuffling: drop something to
    pick something up, and the rest of the party is full too. The limit is now
    30 kinds.

    Route:
      title/attract -> main menu
        -> Begin New Game -> Adventures Only -> site screen
        -> pick a party -> Done -> adventure scene
        -> F11 -> "Fill the carry limit"                <-- the measurement

    The debug action hands the pick-up character one of every ordinary item kind
    until the game refuses the next one, then reports how many it got. What it
    reports IS the limit in force, so this scenario reads the number rather than
    inferring it from a screen.

    It has to run inside the adventure scene: F11 is registered against the
    screen underneath, and whatever is open on top handles keys instead, so the
    debug window will not open from a menu or a setup screen.

    Run against a DEBUG WIN build - the debug test window is a debug-build
    feature.
#>

. (Join-Path $PSScriptRoot 'adventure-route.ps1')

# DBGWIND_CTL_FILL_CARRY_BTN in DBGWIND.CPP.
$script:DBG_FILL_CARRY_BTN = 4113

# The Ok button on the in-game box a debug action reports its result in. The box
# is a menu, so it takes over key handling while it is up and has to be cleared
# before the adventure's own keys work again.
$script:DEBUG_OK_X = 0.447
$script:DEBUG_OK_Y = 0.394

# Where that box sits. Check this rather than the whole frame: the adventure
# carries on underneath, so a moment later the scene is legitimately different
# whether the box closed or not.
$script:DEBUG_BOX_REGION = @(0.17, 0.21, 0.55, 0.22)

# The inventory screen: its Items category, the list itself, and the list's
# scroll-down arrow.
$script:INV_ITEMS_TAB_X  = 0.256
$script:INV_ITEMS_TAB_Y  = 0.355
$script:INV_LIST_REGION  = @(0.344, 0.325, 0.375, 0.250)
$script:INV_SCROLLDOWN_X = 0.7375
$script:INV_SCROLLDOWN_Y = 0.508

# MAX_ITEMS_IN_LIST in INVNTORY.CPP. Bump both together.
$script:EXPECTED_CARRY_LIMIT = 30

function Invoke-BirpScenario {
    param([Parameter(Mandatory)][hashtable]$Ctx)

    $null = Enter-BirpMainMenu -Ctx $Ctx

    $panel = Open-BirpGameTypePanel -Ctx $Ctx -Label 'game-type'
    if ($null -eq $panel) { & $Ctx.Note "Cannot continue: the game-type panel did not open."; return }

    $site = Enter-BirpAdventuresOnly -Ctx $Ctx
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting the Adventures Only game")) { return }

    $onSite = ((Compare-BirpFrame -PathA $panel -PathB $site) -gt 0.30)
    & $Ctx.Assert $onSite "Adventures Only opened the adventure site screen."
    if (-not $onSite) { & $Ctx.Note "Cannot continue: not on the adventure site screen."; return }

    # Act while the party is still alive. Left to settle on its own, a scene
    # under attack only reaches a stable frame once the party is dead.
    $scene = Start-BirpAdventure -Ctx $Ctx -SceneTimeoutSec 40 -SceneStableFrames 2
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Launching the adventure")) { return }
    if ($null -eq $scene) { & $Ctx.Note "Cannot continue: the adventure scene did not load."; return }

    $mark = Get-Date
    Start-Sleep -Seconds 1      # log timestamps are whole seconds; do not race them

    & $Ctx.Note "Opening the F11 debug test window ..."
    $dbg = Open-BirpDebugWindow -Hwnd $Ctx.Hwnd -TimeoutSec 20
    & $Ctx.Assert ($null -ne $dbg) "The F11 debug test window opened inside the adventure."
    if ($null -eq $dbg) {
        & $Ctx.Note "Cannot continue: no debug window. Is this a DEBUG WIN build?"
        return
    }

    & $Ctx.Note "Filling the carry limit ..."
    $pressed = Invoke-BirpDebugAction -DebugHwnd $dbg -ControlId $script:DBG_FILL_CARRY_BTN
    & $Ctx.Assert $pressed "Pressed the Fill the carry limit button."
    if (-not $pressed) { return }

    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 30
    $resultBox = & $Ctx.Shot 'carry-limit-result'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Filling a character's inventory to the limit")) { return }

    $reported = Get-BirpLogLines -InstallDir $Ctx.InstallDir -SinceTime $mark -Pattern 'DebugFillCarryLimit'
    foreach ($line in $reported) { & $Ctx.Note $line }

    $sawRefusal = $false
    $carried = -1
    foreach ($line in $reported) {
        if ($line -match 'now carrying (\d+), next add (.+)$') {
            $carried = [int]$Matches[1]
            $sawRefusal = ($Matches[2] -match 'refused')
        }
    }

    & $Ctx.Assert ($carried -ge 0) "The debug action reported how many kinds the character ended up carrying."
    & $Ctx.Assert $sawRefusal "The character was filled right up to the limit (the next kind was refused)."
    & $Ctx.Assert ($carried -eq $script:EXPECTED_CARRY_LIMIT) `
        ("The carry limit is {0} kinds (expected {1})." -f $carried, $script:EXPECTED_CARRY_LIMIT)

    & $Ctx.Note "Dismissing the result box ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:DEBUG_OK_X -Fy $script:DEBUG_OK_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $backToScene = & $Ctx.Shot 'back-to-scene'
    $boxGone = Compare-BirpFrameRegion -PathA $resultBox -PathB $backToScene -Region $script:DEBUG_BOX_REGION
    $cleared = ($boxGone -gt 0.20)
    & $Ctx.Assert $cleared ("The result box closed and the adventure came back ({0:P1} change where the box was)." -f $boxGone)
    if (-not $cleared) { & $Ctx.Note "Cannot continue: the result box is still up."; return }

    # A full inventory must still be usable, not just reachable. Open the
    # inventory screen and confirm it came up over the scene. I is the
    # adventure's own inventory key, registered next to F11 on the scene.
    & $Ctx.Note "Opening the inventory on the now-full character ..."
    Send-BirpKey -Hwnd $Ctx.Hwnd -Key 'I'
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $inv = & $Ctx.Shot 'inventory-full'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening the inventory with a full carry list")) { return }

    $opened = Compare-BirpFrame -PathA $backToScene -PathB $inv
    & $Ctx.Assert ($opened -gt 0.20) ("The inventory screen opened over the adventure ({0:P1} frame change)." -f $opened)

    # The list shows five rows at a time, so a full carry list only works if it
    # scrolls. Switch to Items and page down; the rows have to change.
    & $Ctx.Note "Showing the Items category ..."
    Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:INV_ITEMS_TAB_X -Fy $script:INV_ITEMS_TAB_Y
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 20
    $items = & $Ctx.Shot 'inventory-items'

    $listed = Compare-BirpFrameRegion -PathA $inv -PathB $items -Region $script:INV_LIST_REGION
    & $Ctx.Assert ($listed -gt 0.02) ("The Items category listed the carried items ({0:P1} list change)." -f $listed)

    & $Ctx.Note "Scrolling the item list ..."
    for ($i = 0; $i -lt 5; $i++) {
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:INV_SCROLLDOWN_X -Fy $script:INV_SCROLLDOWN_Y
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 10
    }
    $scrolled = & $Ctx.Shot 'inventory-items-scrolled'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Scrolling a full item list")) { return }

    $moved = Compare-BirpFrameRegion -PathA $items -PathB $scrolled -Region $script:INV_LIST_REGION
    & $Ctx.Assert ($moved -gt 0.02) ("The list scrolled past the first five rows ({0:P1} list change)." -f $moved)

    & $Ctx.Note "adventure-carry-limit scenario steps complete."
}
