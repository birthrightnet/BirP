# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- markdownlint-disable MD024 -->

## [Unreleased]

### Added

- Added "modern mode" in-game resolution options while preserving the original "OG mode" option. [#6](https://github.com/Shiryou/BirP/issues/6)
- Added build [scripts](../birp-dev/scripts) to automate building, testing, validating, and packaging the project.

### Changed

- Replace timestamps with build numbers for more reproducible builds. [#7](https://github.com/Shiryou/BirP/issues/7)
- Updated project dependencies to latest versions, including Open Watcom v2.0 and UASM v2.57.
- Reorganized source files and build artifacts.
- Reorganized documentation into `CHANGELOG.md` for developer-facing changelog, `readme.txt` for user-facing instructions and notes on how to use the new version, and `BUILD-OPTIONS.md` for build options documentation.
- Many updates to `MAKE.BAT` to support new build options and targets, and to be the primary build script for the project. See `BUILD-OPTIONS.md` for details on new build options and targets.
- Replaced and unified logging [#8](https://github.com/Shiryou/BirP/issues/8).
- Updated build, deploy, and test scripts to reduce console noise while improving warning/error summaries and visibility.

### Fixed

- Resolved warning-producing code paths in memory manager, selected platform-specific source modules, and SOLAUDIO CUSTMSYS linkage across WIN/DOS and DEBUG/RELEASE builds.
- Removed an unused `_MULTIMONO` `DumpString` prototype in `WINSYS/GMULPLAY.CPP` that produced W014 "no reference to symbol" warnings in WIN and CHARED debug builds.
- Hardened `PrepareBuildDirs` SOLAUDIO/RES staging cleanup with retry logic to reduce intermittent `Access denied` failures while restaging under `build-artifacts`.
- Fixed DOS audio driver detection so `audioDrv` parsing in `resource.cfg` is whitespace-tolerant and falls back to `DACBLAST.DRV` instead of forced silent `DACNONE.DRV` when no valid entry is found.
- Reduced random Adventure Mode crash risk by validating adventure bump indices before dereferencing `mythings[]`, correcting the scene 5 ambient sound table bound, preventing adventure-team joins when breadcrumb path state is missing, hardening team-iterator avatar-handle checks, adding stale enemy-handle guards in follow-player and combat attack routines, hardening scene avatar loops against invalid current-scene/avatar handles, and expanding adventure/environmental sound diagnostics around sound queueing, looping lava audio, stale looping-sound thing indices, and invalid scene/avatar handles. [#4](https://github.com/Shiryou/BirP/issues/4)
- Hardened battle AI enemy/leader handle validation across captain combat flows to prevent stale-handle dereferences during engagements.
- Restored initial menu/adventure music startup and improved suspend/resume handling so music no longer waits for first combat or fails to restart reliably. [#10](https://github.com/Shiryou/BirP/issues/10) [#32](https://github.com/Shiryou/BirP/issues/32)
- Fixed no-CD bypass startup handling so release builds honor explicit `brsetup.cfg` bypass configuration (`[CD]=.` or `[CD_BYPASS]=1`).
- Fixed tome-learned adventure spells being appended to the end of Prepare Magic lists by adding level-aware insertion for new `IC_SPELL` inventory entries (with spell-index tiebreaker), so newly learned spells now appear in their expected level order. [#25](https://github.com/Shiryou/BirP/issues/25)
- Fixed two paths where quantity of consumable items in inventory could be increased by dozens. One path was in adventure prepare screen, the other could come from a numeric cast that could result in a large positive number. [#27](https://github.com/Shiryou/BirP/issues/27)

### Removed

- Removed DirectDraw as a supported display mode and removed related options and hotkeys; GDI is now the only supported rendering path. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the deprecated `Auto Resolution` graphics option. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the debug FPS counter overlay during debug runs.

## [1.4.0.4] - 2025-11-02

### Changed

- Allow calling all files from game directory instead of CD. All files must be copied from CD to the install directory. [#2](https://github.com/Shiryou/BirP/issues/2)

### Fixed

- Custom adventures no longer crash the game when picking up the quest goal item. [#3](https://github.com/Shiryou/BirP/issues/3)
- Fixed many legacy C and C++ errors that were intolerable by our modern Open Watcom toolchain.
