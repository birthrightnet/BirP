# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- markdownlint-disable MD024 -->

## [Unreleased]

### Added

- Added mouse-wheel support (Windows). Scrolling the wheel over the realm map zooms in and out, keeping the tile under the cursor anchored under the cursor. Scrolling while the cursor is over a left-side data panel pages that panel's list (tax levels, occupation, payroll, and maintenance/income province lists) instead of zooming the map, the same as the on-screen Previous/Next Page buttons. Scrolling the wheel over the inventory item list, the save/load game list, or an action-detail province list (forge ley line, build road, trade route, muster) scrolls or pages it, the same as the on-screen scroll/page buttons. On the tactical battlefield, the wheel zooms the camera in and out. This is part of broader scroll-wheel support. [#16](https://github.com/Shiryou/BirP/issues/16)
- Consolidated debug test actions behind a dedicated F11 test window in DEBUG builds, replacing separate direct debug hotkeys for adventure item grant, realm assassination test, end-of-adventure event trigger, pathfinding test functions, and an animation stress test function.
- Added an F11 "Dump realm units & regents to log" debug action (DEBUG builds) that logs every occupied unit slot and live regent-table entry and flags "zombie" regent units, to aid realm-map state investigations. [#90](https://github.com/Shiryou/BirP/issues/90)
- Added a "Halt" button to adventure combat that sets every party member to defend; pressing it also makes "defend" their remembered fighting style so they keep holding when re-engaging. It does nothing outside combat. [#36](https://github.com/Shiryou/BirP/issues/36)
- Added an awareness system: Characters gain "awareness" of an opponent for 30 seconds if they get LOS on the opponent. Awareness of an enemy allows the character to pathfind to it, even if it has left LOS (around a corner), as long as the target is close enough. [#36](https://github.com/Shiryou/BirP/issues/36)
- Added new pathfinding algorithms that have reduced instances of "Unable to engage" and your player characters getting stuck on walls by ~90%. New algorithms allow pathfinding around obstacles like tables and even into different rooms, as long as you have awareness of target. [#36](https://github.com/Shiryou/BirP/issues/36)

### Changed

- Player characters now start combat using fighting styles based on their classes: martials start with 'slow attack 1' and magic users 'defend' (before all classes started with 'defend') [#53](https://github.com/Shiryou/BirP/issues/53)
- Player characters remember their last used fighting style and, upon their current target being defeated, automatically attempt to pathfind to nearest enemy and continue using that attack style against it [#36](https://github.com/Shiryou/BirP/issues/36)[#53](https://github.com/Shiryou/BirP/issues/53)
- Updated assassination reports to include the assassinated unit type, so the report now identifies what unit was lost. [#33](https://github.com/Shiryou/BirP/issues/33)
- Party members now give up chasing a target they cannot reach after about 15 seconds and return to standing by for orders, instead of pursuing indefinitely. [#36](https://github.com/Shiryou/BirP/issues/36)
- Updated Lieutenant Action cancel behavior so canceling out of sub-windows no longer exits Lieutenant Action, and pressing Lieutenant Action again now explicitly toggles back to normal regent action. Lieutenant Action button is highlighted during Lieutenant Action to indicate its active state. [#21](https://github.com/Shiryou/BirP/issues/21)
- Halved the delay before an adventure returns to exploration after combat ends. [#14](https://github.com/Shiryou/BirP/issues/14)
- Improved adventure combat messaging: attacks now name the target and show its armor class, chases show which enemy a character is pursuing, and hit/miss results read more descriptively.
- Build now compiles and deploys `STRDAT.DAT`, allowing in-game text strings (such as the new adventure combat messages) to be changed.

### Fixed

- Fixed domain actions failing when their success chance was pushed above 100% (e.g. Agitate with a high-level province, a temple, and the Robes of the Masses). The shared success roll took an unsigned `Chance`, so a below-1 target number (an above-100% chance) wrapped to a large value the `1d20` roll could never meet, turning a near-certain action into a guaranteed failure. The effective chance is now clamped to a 100% ceiling before the roll. [#70](https://github.com/Shiryou/BirP/issues/70)
- Fixed a defeated regent with no province to retreat to becoming permanently stuck on the realm map: `WithdrawLosingUnit`/`CheckWithdrawPath` could pick an empty border slot (`NO_PROVINCE`) as a phantom retreat target, leaving the regent flagged mid-move to nowhere and keeping the province engaged forever. Border scans now skip empty slots so a fully-encircled loser is properly destroyed. Existing affected saves are also repaired on load (stuck "moving to nowhere" units are settled), so players do not need to start a new game. [#90](https://github.com/Shiryou/BirP/issues/90)
- Hostile spells can no longer target your own party members and single-target projectiles (magic missile, lightning bolt) pass through allies instead of hitting them. This also means a spellcaster can no longer "lock on" to a friendly PC. Area-of-effect spells can still catch your own party in the blast. [#36](https://github.com/Shiryou/BirP/issues/36)
- Melee attacks require LOS on target, preventing instances where characters would attack through walls. Spectres and wraiths phase through walls by design, so they may still attack through a wall and may now be struck back through a wall. [#36](https://github.com/Shiryou/BirP/issues/36)
- Party members no longer chase enemies onto lava, acid, or deep water; a target standing in dangerous terrain is ignored. [#36](https://github.com/Shiryou/BirP/issues/36)
- Fixed rebellions so that no tax or regency is earned while loyalty is 0 (rebellion), and it does not reset at end of turn if the conditions for that rebellion are not addressed (which was a bug). [#76](https://github.com/Shiryou/BirP/issues/76)
- Hardened Adventure/Combat transition flows for two-part adventures to reduce crash risk during part-two progression and combat UI/control handoffs. [#52](https://github.com/Shiryou/BirP/issues/52)
- Fixed a rare adventure-mode animation crash so missing or invalid visual art now degrades gracefully (the affected visual is skipped) instead of crashing to desktop. [#4](https://github.com/Shiryou/BirP/issues/4)
- Fixed DOS DEBUG audio options so low-memory mode no longer forces Music Volume to `Off` or Environmental Sounds to `Off`, and saved music volume is now applied during option-load initialization. [#32](https://github.com/Shiryou/BirP/issues/32)
- Increased log message buffer size from 256 to 2048 bytes to prevent stack overflow when long TURN TRACE format strings exceeded the original buffer, which caused a divide-by-zero fault in the DOS protected-mode runtime. [#57](https://github.com/Shiryou/BirP/issues/57)
- Fixed a DOS DEBUG crash when transitioning from Collect Taxes to the first realm action: the 32 KB link stack overflowed during NPC domain-turn AI processing and corrupted adjacent globals. The DOS DEBUG link stack is now 128 KB. Also added a startup `CODE ANCHOR` log line that lets DOS/4G fault addresses be resolved to functions via `nova.map`. [#57](https://github.com/Shiryou/BirP/issues/57)

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
