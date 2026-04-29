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
- Hardened `PrepareBuildDirs` SOLAUDIO/RES staging cleanup with retry logic to reduce intermittent `Access denied` failures while restaging under `build-artifacts`.
- Fixed DOS audio driver detection so `audioDrv` parsing in `resource.cfg` is whitespace-tolerant and falls back to `DACBLAST.DRV` instead of forced silent `DACNONE.DRV` when no valid entry is found.

### Removed

- Removed DirectDraw as a supported display mode and removed related options and hotkeys; GDI is now the only supported rendering path. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the deprecated `Auto Resolution` graphics option. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the debug FPS counter overlay during debug runs.

## [1.4.0.4] - 2025-11-02

### Changed

- Allow calling all files from game directory instead of CD. All files must be copied from CD to the install directory. [#2](https://github.com/Shiryou/BirP/issues/2)

### Fixed

- Custom adventures no longer crash the game when picking up the quest goal item. [#3](https://github.com/Shiryou/BirP/issues/3)
