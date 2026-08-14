# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- markdownlint-disable MD024 -->

## [Unreleased]

### Added

- Added mouse-wheel support (Windows). Over the realm map, the wheel zooms in and out and keeps the tile under the cursor in place. Over a left-side data panel, it pages that panel's list (tax levels, occupation, payroll, and income) instead of zooming. Over the inventory list, the save/load list, or an action province list (forge ley line, build road, trade route, muster), it scrolls or pages that list. On the battlefield, it zooms the camera. [#16](https://github.com/Shiryou/BirP/issues/16)
- Consolidated debug test actions behind a dedicated F11 test window in DEBUG builds, replacing separate direct debug hotkeys for adventure item grant, realm assassination test, end-of-adventure event trigger, pathfinding test functions, and an animation stress test function.
- Added an F11 "Dump realm units & regents to log" debug action (DEBUG builds) that lists every unit and regent on the realm map and flags "zombie" regents - units a dead regent left behind - to help investigate realm-map problems. [#90](https://github.com/Shiryou/BirP/issues/90)
- Added an F11 "Set up issue 38 battle test" debug action (WIN DEBUG builds) that stages a player stack, an allied NPC stack, and an enemy stack in one province with the diplomacy set up, so the end-of-turn battle resolution can be exercised. Proves that players attack BEFORE allies. [#38](https://github.com/Shiryou/BirP/issues/38)
- Added a "Halt" button to adventure combat that sets every party member to defend. It also makes "defend" their remembered fighting style, so they keep holding when they re-engage. It does nothing outside combat. [#36](https://github.com/Shiryou/BirP/issues/36)
- Added an awareness system. A character becomes "aware" of an opponent for 30 seconds after getting line of sight to it. While aware, the character can path to that opponent even after it moves out of sight (around a corner), as long as it stays close enough. [#36](https://github.com/Shiryou/BirP/issues/36)
- Added new pathfinding algorithms that have reduced instances of "Unable to engage" and your player characters getting stuck on walls by ~90%. New algorithms allow pathfinding around obstacles like tables and even into different rooms, as long as you have awareness of target. [#36](https://github.com/Shiryou/BirP/issues/36)
- Added an issue reporting tool that ships with the patch. A player double-clicks `BirP-Issue-Report.bat` in the game folder and, after a consent prompt, it bundles the useful diagnostic files - the game and Windows versions, the install path, and whichever log and config files are present - into a single timestamped .zip to attach to a bug report. It only reads files and needs no setup. [#104](https://github.com/Shiryou/BirP/issues/104)
- Added an automated installer test suite that runs in CI on every installer change. It compiles the installer, checks that every installer message exists in all three languages, unit tests the path-safety and detection helpers, runs silent Install and Patch runs against seeded folders (including refusing to patch a folder without the game, and proving a re-run changes nothing and never touches saves or settings), and proves an uninstall never deletes anything outside the game folder. It needs no game CD: the suite generates stand-in game files. [#89](https://github.com/Shiryou/BirP/issues/89)[#122](https://github.com/Shiryou/BirP/issues/122)
- Added an F11 "Corrupt advscn.dat" debug action (WIN DEBUG builds) that leaves the Adventures Only progress file the wrong length, the way an older build could, so a tester can confirm the game refuses it and starts over instead of reading it back scrambled. [#133](https://github.com/Shiryou/BirP/issues/133)
- Added a save-and-load test scenario to the game test harness. It loads a saved game from the main menu, checks the realm map comes back and the game menu still works, then loads a second time without quitting and checks again. [#132](https://github.com/Shiryou/BirP/issues/132)
- Added an automated game test harness that launches the deployed Windows build, drives it with real mouse clicks like a player, captures each screen, and reports crashes or log errors. It ships a boot-and-menus smoke scenario that reaches the main menu, walks every options tab, opens and backs out of the game and load dialogs, and quits cleanly, checking each screen against committed reference images. A Desktop run mode works today and a VM run mode is scaffolded. [#58](https://github.com/Shiryou/BirP/issues/58)
- Added a build check that compiles the game on every pull request. It builds all six scenarios - Windows and DOS, release and debug, and the character editor in both - and reports on warnings and errors rather than only on whether the build finished. One broken scenario no longer hides the other five, because the run carries on and reports them all. Before this, a pull request that changed only game source ran no automated checks at all.

### Changed

- Player characters now start combat using fighting styles based on their classes: martials start with 'slow attack 1' and magic users 'defend' (before all classes started with 'defend') [#53](https://github.com/Shiryou/BirP/issues/53)
- Player characters remember their last used fighting style and, upon their current target being defeated, automatically attempt to pathfind to nearest enemy and continue using that attack style against it [#36](https://github.com/Shiryou/BirP/issues/36)[#53](https://github.com/Shiryou/BirP/issues/53)
- Updated assassination reports to include the assassinated unit type, so the report now identifies what unit was lost. [#33](https://github.com/Shiryou/BirP/issues/33)
- Party members now give up chasing a target they cannot reach after about 15 seconds and return to standing by for orders, instead of pursuing indefinitely. [#36](https://github.com/Shiryou/BirP/issues/36)
- Updated Lieutenant Action cancel behavior so canceling out of sub-windows no longer exits Lieutenant Action, and pressing Lieutenant Action again now explicitly toggles back to normal regent action. Lieutenant Action button is highlighted during Lieutenant Action to indicate its active state. [#21](https://github.com/Shiryou/BirP/issues/21)
- Halved the delay before an adventure returns to exploration after combat ends. [#14](https://github.com/Shiryou/BirP/issues/14)
- Improved adventure combat messaging: attacks now name the target and show its armor class, chases show which enemy a character is pursuing, and hit/miss results read more descriptively.
- Build now compiles and deploys `STRDAT.DAT`, allowing in-game text strings (such as the new adventure combat messages) to be changed.
- When you and an AI ally are in the same province as a shared enemy, your troops now attack first. [#38](https://github.com/Shiryou/BirP/issues/38)
- The build and deploy scripts and the release installer now bundle the issue reporting tool alongside the patched game. Building the release installer now needs Inno Setup 6 and the official Patch 1.4 files, both included under `birp-dependencies` and documented there. [#104](https://github.com/Shiryou/BirP/issues/104)
- The game now remembers each magic user's prepared spells and every party member's hotbar layout between adventures, so you no longer have to set them up before every outing. Spellcasters' choices are saved at the adventure preparation screen and martial characters' hotbars when an adventure ends. The remembered settings are kept in a new save file, so existing saves are unaffected. [#24](https://github.com/Shiryou/BirP/issues/24)
- Reworked the installer around two clear choices, Install and Patch, and taught it to find things for you. Install searches your drives for the Birthright CD or USB stick and fills in the location, so you no longer hunt for the path by hand. Patch looks for an existing install in the usual places and points at it. Both flows always apply the official 1.4 patch and the latest preservation patch, so any install ends up fully up to date. The old multi-option component menu is gone. [#89](https://github.com/Shiryou/BirP/issues/89)
- Hardened the installer's uninstall so it only ever removes the game's own folder. It shows that exact folder before removing anything and refuses obviously wrong targets such as a drive root or a system folder. [#89](https://github.com/Shiryou/BirP/issues/89)
- The installer can now run unattended for automated testing. It takes the install mode and the game-files location from command-line switches or environment variables and works with the standard silent-install options. [#122](https://github.com/Shiryou/BirP/issues/122)
- Clearer installer wording, following a hands-on review of every wizard page. The setup title and pages now carry the Preservation Patch name. The Install and Patch choices spell out that both apply the official 1.4 patch and the latest Preservation Patch, and that patching an already-patched game is safe. The Add/Remove Programs entry is listed as "Birthright and Preservation Patch". [#89](https://github.com/Shiryou/BirP/issues/89)[#122](https://github.com/Shiryou/BirP/issues/122)

### Fixed

- Fixed the automated installer test suite failing at the very last check even when every test had passed. It waited for the uninstaller to remove itself by asking whether its file was still there, and while a file is on its way out Windows answers "access denied" rather than "not found". That answer ended the run instead of the wait going round again. The wait now treats an unanswerable path as still present and keeps waiting. [#89](https://github.com/Shiryou/BirP/issues/89)[#122](https://github.com/Shiryou/BirP/issues/122)
- Fixed the game crashing when you start a new game from inside an adventure. Picking Battles Only, a Tutorial, or a Realm Game from the game menu now finishes leaving the adventure before it builds the new game, instead of dismantling the screen while the adventure is still running. This also fixes starting an Expert game that way leaving you on the realm map with no left-hand window, so you could click provinces but never see a regent or a button to start playing. [#12](https://github.com/Shiryou/BirP/issues/12) [#13](https://github.com/Shiryou/BirP/issues/13) [#31](https://github.com/Shiryou/BirP/issues/31)
- Fixed Adventures Only progress being read back scrambled. The file that remembers which sites you have seen and which practice adventurers are alive was stored in a way that could corrupt itself depending on which characters were rolled, which could leave the site screen pointing at a site that does not exist. Progress files that were never affected still load, and a damaged one is now discarded and rebuilt instead of used. [#133](https://github.com/Shiryou/BirP/issues/133)
- Loading a saved game now finishes leaving any adventure that is still running before it builds the loaded game. Loading is only offered from the realm map, so this changes nothing you can see today, but the load no longer relies on that being true. [#132](https://github.com/Shiryou/BirP/issues/132)
- Fixed the game crashing when you pick Adventures Only while an Adventures Only game is already running. The adventure site screen now reloads with a readable party instead of looking up character details that were thrown away when the new game loaded. [#9](https://github.com/Shiryou/BirP/issues/9)
- Fixed uninstalling from Add/Remove Programs silently skipping the confirmation dialog. The uninstall now always shows exactly which folder it will remove and asks first, including the optional choice to also delete saves and settings. Fully automated uninstalls still run unattended. [#89](https://github.com/Shiryou/BirP/issues/89)[#122](https://github.com/Shiryou/BirP/issues/122)
- The uninstaller now also removes the diagnostic files the game writes while playing (crash dumps and memory reports), so an uninstall no longer leaves the game folder behind holding only those. [#89](https://github.com/Shiryou/BirP/issues/89)
- Fixed the battle victory screen reporting an enemy regent among the dead. A regent defeated in a manual battle survives and retreats to a neighboring province by design, so the screen no longer counts them as a lost unit and now notes that the regent escaped. [#78](https://github.com/Shiryou/BirP/issues/78) [#90](https://github.com/Shiryou/BirP/issues/90)
- Fixed music (intro, menu, combat, and realm) breaking into a stuck one-second loop on Windows when the computer had been running for more than about 25 days. The music now plays correctly no matter how long the machine has been on. [#117](https://github.com/Shiryou/BirP/issues/117)
- Fixed domain actions with a very high chance of success always failing instead of nearly always succeeding (for example Agitate on a high-level province with a temple and the Robes of the Masses). The success chance is now capped at 100% before the roll. [#70](https://github.com/Shiryou/BirP/issues/70)
- Fixed a defeated regent with nowhere to retreat becoming permanently stuck on the realm map, where it could not be fought and kept its province engaged forever. A fully surrounded loser is now properly removed instead of being sent to retreat to a border that is not there. Existing affected saves are repaired on load - units stuck "moving to nowhere" are settled - so players do not need to start a new game. [#78](https://github.com/Shiryou/BirP/issues/78) [#90](https://github.com/Shiryou/BirP/issues/90)
- Hostile spells can no longer target your own party members, and single-target projectiles (magic missile, lightning bolt) pass through allies instead of hitting them. A spellcaster can no longer "lock on" to a friendly party member. Area-of-effect spells can still catch your own party in the blast. [#36](https://github.com/Shiryou/BirP/issues/36)
- Melee attacks now require line of sight to the target, so characters no longer attack through walls. Spectres and wraiths phase through walls by design, so they can still attack through a wall and can now be struck back through one. [#36](https://github.com/Shiryou/BirP/issues/36)
- Party members no longer chase enemies onto lava, acid, or deep water. A target standing in dangerous terrain is ignored. [#36](https://github.com/Shiryou/BirP/issues/36)
- Fixed rebelling provinces still paying out. A province in rebellion now earns no tax or regency, and it stays in rebellion until its cause is addressed instead of resetting at the end of the turn. [#76](https://github.com/Shiryou/BirP/issues/76)
- Hardened the transitions in two-part adventures to reduce crashes when moving into part two and handing control back to combat. [#52](https://github.com/Shiryou/BirP/issues/52)
- Fixed a rare adventure-mode animation crash so missing or invalid visual art now degrades gracefully (the affected visual is skipped) instead of crashing to desktop. [#4](https://github.com/Shiryou/BirP/issues/4)
- Fixed DOS DEBUG audio options. Low-memory mode no longer forces Music Volume or Environmental Sounds to Off, and your saved music volume is applied when options load. [#32](https://github.com/Shiryou/BirP/issues/32)
- Fixed a DOS crash caused by long log lines. A very long trace message could overrun the log buffer and crash the game; the buffer is now large enough to hold it. [#57](https://github.com/Shiryou/BirP/issues/57)
- Fixed a DOS DEBUG crash when moving from Collect Taxes to the first realm action. The program ran out of stack room while the AI processed NPC domain turns; it now has enough. Also added a startup marker in the log that makes it easier to trace a DOS crash address back to the code. [#57](https://github.com/Shiryou/BirP/issues/57)
- Fixed the release installer's "Birthright Patch 1.4" option installing only its top-level files and silently skipping the patch's adventure and scene folders. An installer-based install from an unpatched CD was running the 1.4 programs against the original 1.0 game data. The option now installs the complete official patch. (Manual and release-zip installs were unaffected.)
- Fixed background music cutting out when you open an adventurer's Status or Inventory screen during an adventure, where it stayed silent until the next fight. Opening those screens was stopping all sound, including the music, and nothing started it again. The music now keeps playing, and the over-long placeholder sound those screens used on open and close was replaced with the same short sound the other menus use. [#102](https://github.com/Shiryou/BirP/issues/102)
- Fixed law claims being lost when loading a saved game. Provinces you had law claims against are now restored on load instead of being cleared. Loading was also hardened against a possible overflow when a save has a different number of provinces than expected. [#11](https://github.com/Shiryou/BirP/issues/11)

## [1.4.1] - 2026-05-15

### Added

- Added "modern mode" in-game resolution options while preserving the original "OG mode" option. [#6](https://github.com/Shiryou/BirP/issues/6)
- Added build [scripts](../birp-dev/scripts) to automate building, testing, validating, and packaging the project.
- Pressing F11 while in an adventure completes the current quest, for testing purposes. Only works in DEBUG builds. [#35](https://github.com/Shiryou/BirP/issues/35)

### Changed

- Updated auto-battle duel ordering to resolve regular units first, then lieutenants, and only use the regent once no other unit in that stack remains. [#19](https://github.com/Shiryou/BirP/issues/19)
- Replace timestamps with build numbers for more reproducible builds. [#7](https://github.com/Shiryou/BirP/issues/7)
- Replaced and unified logging. [#8](https://github.com/Shiryou/BirP/issues/8)
- Updated project dependencies to latest versions, including Open Watcom v2.0 and UASM v2.57.
- Reorganized source files and build artifacts.
- Reorganized documentation into `CHANGELOG.md` for developer-facing changelog, `readme.txt` for user-facing instructions and notes on how to use the new version, and `BUILD-OPTIONS.md` for build options documentation.
- Many updates to `MAKE.BAT` to support new build options and targets, and to be the primary build script for the project. See `BUILD-OPTIONS.md` for details on new build options and targets.
- Updated build, deploy, and test scripts to reduce console noise while improving warning/error summaries and visibility.
- Removed all warning suppression left by original codebase, exposing all warnings during builds.

### Fixed

- Reduced random Adventure Mode crash risk by validating adventure bump indices before dereferencing `mythings[]`, correcting the scene 5 ambient sound table bound, preventing adventure-team joins when breadcrumb path state is missing, hardening team-iterator avatar-handle checks, adding stale enemy-handle guards in follow-player and combat attack routines, hardening scene avatar loops against invalid current-scene/avatar handles, and expanding adventure/environmental sound diagnostics around sound queueing, looping lava audio, stale looping-sound thing indices, and invalid scene/avatar handles. [#4](https://github.com/Shiryou/BirP/issues/4)
- Hardened battle AI enemy/leader handle validation across captain combat flows to prevent stale-handle dereferences during engagements. [#4](https://github.com/Shiryou/BirP/issues/4)
- Fixed auto-battle resolution so regents and lieutenants on the overwhelmingly stronger side are no longer valid casualties unless they are dueling an opposing regent/lieutenant. [#19](https://github.com/Shiryou/BirP/issues/19)
- Fixed two paths where quantity of consumable items in inventory could be increased by dozens. One path was in adventure prepare screen, the other could come from a numeric cast that could result in a large positive number. [#27](https://github.com/Shiryou/BirP/issues/27)
- Fixed tome-learned adventure spells being appended to the end of Prepare Magic lists by adding level-aware insertion for new `IC_SPELL` inventory entries (with spell-index tiebreaker), so newly learned spells now appear in their expected level order. [#25](https://github.com/Shiryou/BirP/issues/25)
- Hardened `MP_UNITS` access in `MULTIMAP.CPP` by validating unit indices before dereferencing `units[...]` in `DoSetGameData`/`DoGetGameData`, preventing fatal `units[-1]` out-of-bounds crashes during end-of-turn processing. [#30](https://github.com/Shiryou/BirP/issues/30)
- Restored initial menu/adventure music startup and improved suspend/resume handling so music no longer waits for first combat or fails to restart reliably. [#10](https://github.com/Shiryou/BirP/issues/10) [#32](https://github.com/Shiryou/BirP/issues/32)
- Prevented `CheckTheCDMusic` from repeatedly requesting track playback while music is suspended, avoiding large volumes of blocked-track warnings during adventure/combat sessions. [#4](https://github.com/Shiryou/BirP/issues/4)
- Fixed DOS audio driver detection so `audioDrv` parsing in `resource.cfg` is whitespace-tolerant and falls back to `DACBLAST.DRV` instead of forced silent `DACNONE.DRV` when no valid entry is found.
- Added a bounded `CheckTheCDMusic` auto-resume fallback when music remains suspended too long during Adventure-context gameplay, preventing extended no-music states. [#10](https://github.com/Shiryou/BirP/issues/10)
- Fixed adventure music not resuming after combat by forcing music to resume if it remains suspended too long (more than 12 seconds) in Adventure-context gameplay. [#10](https://github.com/Shiryou/BirP/issues/10)
- Fixed adventure quest-goal item flow so victory popup/music transitions preserve and restore intended adventure tracks more reliably, with safer suspended-track deferral/resume handling and fallback behavior when prior track metadata is invalid. [#35](https://github.com/Shiryou/BirP/issues/35)
- Fixed no-CD bypass startup handling so release builds honor explicit `brsetup.cfg` bypass configuration (`[CD]=.` or `[CD_BYPASS]=1`).

### Removed

- Removed DirectDraw as a supported display mode and removed related options and hotkeys; GDI is now the only supported rendering path. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the deprecated `Auto Resolution` graphics option. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the debug FPS counter overlay during debug runs.

## [1.4.0.4] - 2025-11-02

### Changed

- Allow calling all files from game directory instead of CD. All files must be copied from CD to the install directory. [#2](https://github.com/Shiryou/BirP/issues/2)

### Fixed

- Custom adventures no longer crash the game when picking up the quest goal item. [#3](https://github.com/Shiryou/BirP/issues/3)

[unreleased]: https://github.com/Shiryou/birp-dev/compare/v1.4.1...HEAD
[1.4.1]: https://github.com/Shiryou/birp-dev/releases/tag/v1.4.1
[1.4.0.4]: https://github.com/Shiryou/birp-dev/releases/tag/v1.4.0.4
