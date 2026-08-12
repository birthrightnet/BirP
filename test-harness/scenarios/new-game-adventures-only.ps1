<#
    Scenario: new-game-adventures-only  (issue #9)

    Starting an Adventures Only game while one is already running used to crash on
    the adventure site screen. Loading the new game's files frees every character's
    stats block, and the party list still pointed at the old blocks.

    Route:
      title/attract -> main menu
        -> Begin New Game -> Adventures Only -> description pages -> site screen
        -> game button -> Begin New Game -> Adventures Only   <-- the crash point
        -> site screen again, still alive

    No adventure is launched here: the reported repro never enters one, and keeping
    the scenario menu-only makes it quick and hard to make flaky.
#>

. (Join-Path $PSScriptRoot 'adventure-route.ps1')

function Invoke-BirpScenario {
    param([Parameter(Mandatory)][hashtable]$Ctx)

    $null = Enter-BirpMainMenu -Ctx $Ctx

    # 1. First Adventures Only game.
    $panel = Open-BirpGameTypePanel -Ctx $Ctx -Label 'first-game-type'
    if ($null -eq $panel) { & $Ctx.Note "Cannot continue: the game-type panel did not open."; return }

    $firstSite = Enter-BirpAdventuresOnly -Ctx $Ctx -Label 'first-site-screen'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting the first Adventures Only game")) { return }

    # The site screen is a full-screen panel, so it should look nothing like the
    # menu we came from. This also guards the rest of the run: if we are not on the
    # site screen, the game button click below would land somewhere unknown.
    $menuToSite = Compare-BirpFrame -PathA $panel -PathB $firstSite
    $onSite = ($menuToSite -gt 0.30)
    & $Ctx.Assert $onSite ("Adventures Only opened the adventure site screen ({0:P1} frame change)." -f $menuToSite)
    if (-not $onSite) { & $Ctx.Note "Cannot continue: not on the adventure site screen."; return }

    # 2. Second Adventures Only game, started from the first one. This is the
    #    reported crash.
    $panel2 = Open-BirpGameTypePanel -Ctx $Ctx -FromInGame -Label 'second-game-type'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Opening Begin New Game from the adventure site screen")) { return }
    if ($null -eq $panel2) { & $Ctx.Note "Cannot continue: the second game-type panel did not open."; return }

    & $Ctx.Note "Choosing Adventures Only a second time - this is the issue #9 crash point ..."
    # The description pages only ever show once per process, so skip them here.
    $secondSite = Enter-BirpAdventuresOnly -Ctx $Ctx -Label 'second-site-screen' -SkipDescription
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Starting Adventures Only from an Adventures Only game")) { return }

    # 3. We should be back on a working site screen, not a blank or frozen one.
    $sameScreen = Compare-BirpFrame -PathA $firstSite -PathB $secondSite
    & $Ctx.Assert ($sameScreen -lt 0.60) ("The adventure site screen came back after the restart ({0:P1} differs from the first)." -f $sameScreen)

    # 4. Prove the rebuilt screen still responds, which is what a stale party list
    #    would break: the party check boxes read through the character stats.
    #    Try several rows and accept any one of them responding - the game refuses
    #    to tick a dead character or a fifth party member (TogglePartyCheck), so a
    #    single row is not a reliable probe.
    & $Ctx.Note "Checking the rebuilt site screen still responds ..."
    $prev = $secondSite
    $responded = $false
    for ($row = 0; $row -lt $script:PARTY_CHECK_Y.Count; $row++) {
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:PARTY_CHECK_X -Fy $script:PARTY_CHECK_Y[$row]
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 12
        $shot = & $Ctx.Shot "second-site-party-row$row"
        if (-not (Test-BirpAlive -Ctx $Ctx -What "Ticking party row $row on the rebuilt site screen")) { return }
        $d = Compare-BirpFrame -PathA $prev -PathB $shot
        & $Ctx.Note ("Party row $row click: {0:P2} frame change." -f $d)
        if ($d -gt 0.0005) { $responded = $true; break }
        $prev = $shot
    }
    & $Ctx.Assert $responded "The rebuilt site screen responded to a party click."

    & $Ctx.Note "new-game-adventures-only scenario steps complete."
}
