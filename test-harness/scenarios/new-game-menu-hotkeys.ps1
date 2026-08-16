<#
    Scenario: new-game-menu-hotkeys  (issue #54)

    Every line on the Begin New Game panel underlines the letter you can press
    instead of clicking it. "Adventures Only" underlines its A, but pressing A did
    nothing - the panel listened for V there. The other lines all worked, so the
    one dead letter looked like a keyboard problem rather than a wrong letter.

    Route:
      title/attract -> main menu
        -> Begin New Game -> press C  -> back to the main menu   (the control)
        -> Begin New Game -> press A  -> Adventures Only         (the report)

    The C step is there to prove the game is reading keys at all. Without it, a
    failure on A cannot be told apart from a test that never delivered the key.

    Keys are posted to the game window rather than typed at the desktop, because
    typing needs the window to hold real keyboard focus and a test cannot count on
    that. The game reads them from the same place either way.
#>

. (Join-Path $PSScriptRoot 'adventure-route.ps1')

# The Begin New Game panel itself: (200,75) size 351x371 on the 640x480 screen.
# Comparing only this rectangle answers "did the panel react", with none of the
# map that scrolls continuously behind it.
$script:GAMESEL_REGION = @(0.3125, 0.1563, 0.5484, 0.7729)

function Invoke-BirpScenario {
    param([Parameter(Mandatory)][hashtable]$Ctx)

    $mainMenu = Enter-BirpMainMenu -Ctx $Ctx

    # --- Control: Cancel answers to its own underlined letter --------------------
    $panel = Open-BirpGameTypePanel -Ctx $Ctx -Label 'hotkey-control-panel'
    if ($null -eq $panel) { & $Ctx.Note "Cannot continue: the game-type panel did not open."; return }

    & $Ctx.Note "Pressing C for Cancel ..."
    Send-BirpKey -Hwnd $Ctx.Hwnd -Key 'C'
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
    $afterCancel = & $Ctx.Shot 'after-cancel-key'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Pressing C on the Begin New Game panel")) { return }

    $backOnMenu = $false
    if (Test-Path $script:MAIN_MENU_REF) {
        $vsMenu = Compare-BirpFrameRegion -PathA $script:MAIN_MENU_REF -PathB $afterCancel `
            -Region $script:MENU_ITEMS_REGION
        $backOnMenu = ($vsMenu -lt 0.10)
        & $Ctx.Assert $backOnMenu ("C closed the panel and returned to the main menu ({0:P1} from the baseline)." -f $vsMenu)
    }
    else {
        $vsMenu = Compare-BirpFrameRegion -PathA $panel -PathB $afterCancel -Region $script:GAMESEL_REGION
        $backOnMenu = ($vsMenu -gt 0.20)
        & $Ctx.Assert $backOnMenu ("C closed the panel ({0:P1} panel change; no baseline to confirm the menu)." -f $vsMenu)
    }
    if (-not $backOnMenu) {
        & $Ctx.Note "Cannot continue: keys are not reaching the game, so A proves nothing."
        return
    }

    # --- The report: A must open Adventures Only ---------------------------------
    $panel2 = Open-BirpGameTypePanel -Ctx $Ctx -Label 'hotkey-adventure-panel'
    if ($null -eq $panel2) { & $Ctx.Note "Cannot continue: the game-type panel did not reopen."; return }

    & $Ctx.Note "Pressing A for Adventures Only - this is the issue #54 failure point ..."
    Send-BirpKey -Hwnd $Ctx.Hwnd -Key 'A'
    $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 30
    $afterA = & $Ctx.Shot 'after-adventure-key'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Pressing A on the Begin New Game panel")) { return }

    $reacted = Compare-BirpFrameRegion -PathA $panel2 -PathB $afterA -Region $script:GAMESEL_REGION
    $acted = ($reacted -gt 0.20)
    & $Ctx.Assert $acted ("A was answered - the panel gave way ({0:P1} panel change)." -f $reacted)
    if (-not $acted) {
        & $Ctx.Note "A did nothing. This is the reported bug."
        return
    }

    # Adventures Only shows its description pages on first entry; clear them and
    # confirm the site screen underneath, so a stray dialog cannot pass for the
    # mode having started.
    & $Ctx.Note "Dismissing the Adventures Only description pages ..."
    for ($i = 0; $i -lt 2; $i++) {
        Invoke-BirpClick -Hwnd $Ctx.Hwnd -Fx $script:DESCRIBE_BTN_X -Fy $script:DESCRIBE_BTN_Y
        $null = Wait-BirpStable -Hwnd $Ctx.Hwnd -TimeoutSec 15
    }
    $site = & $Ctx.Shot 'adventure-site-screen'
    if (-not (Test-BirpAlive -Ctx $Ctx -What "Entering Adventures Only by hot key")) { return }

    $vsMainMenu = Compare-BirpFrame -PathA $mainMenu -PathB $site
    & $Ctx.Assert ($vsMainMenu -gt 0.50) ("A reached the adventure site screen ({0:P1} from the main menu)." -f $vsMainMenu)

    & $Ctx.Note "new-game-menu-hotkeys scenario steps complete."
}
