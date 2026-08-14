# BirP test harness

An automated smoke-test harness for the Windows build ([issue #58](https://github.com/Shiryou/BirP/issues/58)).
It launches the deployed game, drives it with real mouse clicks like a player,
captures each screen, checks that screens change as expected, and reports crashes
or log errors.

## What it does today

- Launches `WINBR.EXE` from the install dir and waits for the game window.
- Captures the game's screen to PNG at each step.
- Clicks the window (real cursor moves and button presses, because the game reads
  the mouse by polling, not by window messages).
- Compares screens to confirm a click actually changed something.
- Watches `winbr.log` for errors and `Fatal.err` for crashes.
- Writes a per-run folder with screenshots, a run log, and a pass/fail report.

The first scenario, `boot-and-menus`, boots the game to the title screen, advances
through the attract loop to the main menu, then walks the top-level menu screens: it
opens Begin New Game (the game-type select panel) and backs out, opens Load Saved
Game (the load dialog) and backs out, opens Options and steps through all six
settings tabs (Game, Battle, Adventure, Music & Sound, Screen, Game Speed), opens and
closes the Help submenu, and finally quits from the menu through the confirmation
dialog - screenshotting and verifying each transition, and checking that the game
exits cleanly. (Multiplayer is skipped: from the boot menu it either does nothing or
drops into connection setup that is hard to back out of; it belongs to a later
in-game scenario.)

Four more scenarios cover the failures that happen when a new game is started
while one is already running (issues #9, #12, #13, #31). They share
`scenarios\adventure-route.ps1`, which knows how to reach the main menu, open the
game-type panel, enter Adventures Only, and launch an adventure:

- `new-game-adventures-only` - Adventures Only started from an Adventures Only
  game (#9). Menu-only and quick. **Only reproduces on an install with no
  `advscn.dat`**: with that file present the game reconnects the party list and
  the bug is hidden. Delete `advscn.dat` and `advinv.dat` first to test it.
- `new-game-tutorial-from-adventure` - a Tutorial started from inside a running
  adventure (#13).
- `new-game-battles-from-adventure` - Battles Only started from inside a running
  adventure (#12). **Only reproduces while combat is live.** The scenario opens
  the game menu from exploration, so whether the party is engaged depends on when
  the enemies reach it; run it more than once.
- `new-game-expert-from-adventure` - an Expert Full Game started from inside a
  running adventure ([#31](https://github.com/Shiryou/BirP/issues/31)). Also
  checks the left window comes back, by clicking a playable realm and confirming
  the regent choices fill it in. It shortens the wait for the adventure scene so
  it acts while the party is still alive: left to settle on its own, a scene
  under attack only reaches a stable frame once the party is dead.

A fifth scenario, `load-saved-game`, is a regression test for the load path
([issue #132](https://github.com/Shiryou/BirP/issues/132)). It loads the first
saved game from the main menu, checks the realm map came up and the game button
still works, then loads a second time without quitting and checks the same
things again. The second load is the point: a screen region left unbalanced by
the first load shows up on the second pass, not the first. It needs at least one
file in `<install>\SaveGame` and says so plainly if there is none.

All four of the new-game scenarios are written to fail loudly at the step that breaks: they check the
process is alive and no fresh `Fatal.err` exists after every risky click, and stop
rather than clicking on blindly into a dead game.

## Two run modes

- **Desktop** (default) - runs on this machine's own desktop. It works and is
  proven, but while a run is in progress it moves the real cursor and takes focus,
  so do not use the machine until it finishes.
- **VM** - runs the whole test inside a throwaway Windows virtual machine so your
  desktop is never touched. It provisions a guest from a Windows OS image, installs
  the game (official CD content + our patch) from the CD image via our installer,
  runs the scenario in the guest, and collects the results. **Not yet enabled** -
  deferred on host disk space and on making our installer scriptable. Running
  `-Mode VM` prints exactly what is still needed.

Both modes install/use the official game from the Birthright CD image. Only VM
mode needs the Windows OS image. See the working notes in
[bugs-and-enhancement-requests/docs-58-feature-automated-test-harness.md](../../bugs-and-enhancement-requests/docs-58-feature-automated-test-harness.md).

## Environment variables

Set these the same way as the build dependencies (user environment variables):

- `BIRTHRT_CD_ISO` - path to your Birthright game CD `.iso`. Used by both modes to
  install the official game content. Required for `-Install` and for VM mode.
- `BIRTHRT_WIN_ISO` - path to a Windows OS install `.iso`. VM mode only. Desktop
  mode ignores it.
- `BIRTHRT_INSTALL_DIR` - existing variable; the game install dir Desktop mode
  tests against (default `C:\Sierra\BIRTHRT`).

## Requirements

- Windows with the game deployed (build and deploy first, e.g.
  `.\birp-dev\scripts\build-and-deploy-win-debug.ps1`).
- Windows PowerShell 5.1 or later. No other dependencies - the Win32 capture and
  input code compiles inline via `Add-Type`.

## Usage

From the `birp-dev\test-harness` folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File run-smoke-tests.ps1
```

Options:

- `-Mode <Desktop|VM>` - run mode (default `Desktop`).
- `-Scenario <name>` - run `scenarios\<name>.ps1` (default `boot-and-menus`).
- `-Install` - Desktop mode: install the game fresh from `BIRTHRT_CD_ISO` via our
  installer before testing (requires the scriptable installer - see docs-58).
- `-InstallDir <path>` - override the install dir (default: `BIRTHRT_INSTALL_DIR`
  env var, else `C:\Sierra\BIRTHRT`).
- `-CdIso <path>` / `-WinIso <path>` - override the CD / Windows images (default:
  the env vars above).
- `-ArtifactsRoot <path>` - where per-run folders go (default
  `..\build-artifacts\test-harness`).
- `-UpdateReferences` - capture/refresh the committed reference images instead of
  checking against them (see below).
- `-ReferenceThreshold <0..1>` - allowed fraction of differing pixels for a
  reference match (default `0.05`).
- `-KeepGame` - leave the game running after the scenario.

The exit code is `0` on pass, `1` on fail (`2` if a mode is not yet enabled).

## Reference images

A scenario can verify that a **static** screen still looks right, not just that it
changed. Such screens are captured as committed baselines under
`references\<scenario>\<screen>.png` and compared on each run (a mismatch beyond
`-ReferenceThreshold` fails the run). Only reference-check static screens - do not
baseline the animated attract/title loop.

- Create or refresh baselines: run once with `-UpdateReferences`, review the
  images under `references\`, and commit them.
- Reference images are resolution- and content-specific. They capture the game at
  the resolution and state it was in when created; a different resolution will not
  match. Refresh them when a screen legitimately changes.

## Layout

- `run-smoke-tests.ps1` - entry point: mode dispatch, launch, run a scenario,
  write the report.
- `HarnessCore.psm1` - reusable primitives (env-var resolution, ISO mount, launch,
  find window, capture, wait-until-stable, click, compare, log/crash checks).
- `modes\VmMode.psm1` - VM run mode (scaffolded / deferred).
- `modes\InstallGame.psm1` - fresh install from the CD image via our installer
  (scaffolded / gated on a scriptable installer).
- `scenarios\*.ps1` - one scenario per file. Each defines
  `Invoke-BirpScenario -Ctx`.
- `references\<scenario>\*.png` - committed baseline images for static screens.

## Writing a scenario

A scenario is a script under `scenarios\` that defines one function:

```powershell
function Invoke-BirpScenario {
    param([hashtable]$Ctx)
    # $Ctx.Hwnd, $Ctx.Process, $Ctx.InstallDir, $Ctx.RunDir
    # Helpers: & $Ctx.Shot 'name' [$true] [@(fx,fy,fw,fh)]  |  & $Ctx.Assert $cond 'message'
    #          & $Ctx.Note 'text'  |  & $Ctx.ExpectExit
    #   Shot's 2nd arg $true also checks the shot against references\<scenario>\name.png;
    #     the optional 3rd arg limits that check to a sub-rectangle (fractions of the frame).
    #   ExpectExit tells the harness the scenario is about to quit the game on purpose,
    #     so a clean process exit is scored as a pass, not a crash.
    # Module functions: Wait-BirpStable, Invoke-BirpClick, Compare-BirpFrame,
    #                   Compare-BirpFrameRegion, Get-BirpClientSize
}
```

Prefer fraction-based clicks (`-Fx`/`-Fy`, 0..1) so coordinates survive different
resolutions, and use `Wait-BirpStable` after an action instead of fixed sleeps -
the game runs at about 18 frames per second and screens take a moment to settle.

Three things learned bringing up the menu walk:

- **Reach a known screen by matching its reference, not by "did it change."** The
  title is an attract loop (title art, logos, a flaming-Gorgon intro). Clicking until
  the screen merely differs from the title can settle on an intermediate attract
  frame. `Invoke-BirpClickUntilReference` instead clicks until a region matches the
  committed screen (e.g. the main menu), so it stops only on the real target.
- **Back out of a submenu by clicking its own button (e.g. Help's Done or a dialog's
  Cancel), not by sending a key.** The game reads the mouse by polling, so injected
  clicks always land, but it needs real keyboard focus for keys and that is not
  reliable here - an injected ESC is silently dropped.
- **Only compare the map-free interior of a dialog when checking a transition.** The
  map behind the menu shield scrolls continuously, so a check region that includes
  it shows a few percent of diff even when nothing changed - enough to fake a
  transition that did not happen. Also guard multi-step branch walks: only proceed to
  the next branch once you have confirmed you are back on the menu, so a missed
  back-out cannot cascade (e.g. a stray click starting a real game).

## Planned

- A virtual-machine run mode so a test never touches your desktop, including a
  from-clean install of the official game plus the patch via our own installer.
- Deeper scenarios reached via a planned DEBUG WIN debug-window jump seam: the
  in-game realm screens (status, inventory, reports, actions, atlas), Multiplayer
  (only reachable in a game), adventures, and battles.
