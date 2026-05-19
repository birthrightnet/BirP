# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- markdownlint-disable MD024 -->

## [Unreleased]

### Fixed

- Updated assassination reports to include the assassinated unit type, so the report now identifies what unit was lost. [#33](https://github.com/Shiryou/BirP/issues/33)

### Changed

- Updated Lieutenant Action cancel behavior so canceling out of sub-windows no longer exits Lieutenant Action, and pressing Lieutenant Action again now explicitly toggles back to normal regent action. Lieutenant Action button is highlighted during Lieutenant Action to indicate its active state. [#21](https://github.com/Shiryou/BirP/issues/21)

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
