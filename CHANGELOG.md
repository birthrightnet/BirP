# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- markdownlint-disable MD024 -->

## [Unreleased]

### Added

- Added "modern mode" in-game resolution options with support for `800x600`, `1024x768`, `1280x960`, `1400x1050`, `1600x1200`, and `1920x1440` while preserving the original "OG mode" option. [#6](https://github.com/Shiryou/BirP/issues/6)
- Added many scripts in the [scripts](../birp-dev/scripts) folder to automate common development tasks such as building, testing, validating, and packaging the project.

### Changed

- Allow calling all files from game directory instead of CD. All files must be copied from CD to the install directory. [#2](https://github.com/Shiryou/BirP/issues/2)  
- Replace timestamps with build numbers for more reproducible builds. [#7](https://github.com/Shiryou/BirP/issues/7)
- Updated project dependencies to latest versions, including Open Watcom v2.0 and UASM v2.57.
- Migrated source code into the [source](../birp-dev/source) folder.
- Migrated all build artifacts such as compiled binaries, intermediate object files, and logs into the [build-artifacts](../birp-dev/build-artifacts) folder, which is not source controlled and is ignored by Git.
- Broke documentation into several key files: `CHANGELOG.md` for developer-facing changelog, `readme.txt` for user-facing instructions and notes on how to use the new version, and [BUILD-OPTIONS.md](../birp-dev/BUILD-OPTIONS.md) for build options documentation.
- Many updates to [MAKE.BAT](../birp-dev/MAKE.BAT) to support new build options and targets, and to be the primary build script for the project. See [BUILD-OPTIONS.md](../birp-dev/BUILD-OPTIONS.md) for details on new build options and targets.
- Throttled repeated debug log messages to reduce noise and potential performance impact.
- Standardized source/editor encoding handling for Windows-1252 text consistency.

### Removed

- Removed DirectDraw as a supported display mode and removed related options and hotkeys; GDI is now the only supported rendering path. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the deprecated `Auto Resolution` graphics option. [#6](https://github.com/Shiryou/BirP/issues/6)
- Removed the debug FPS counter overlay during debug runs.

### Fixed

- Fixed game window position resetting after restart by persisting last moved coordinates between sessions. [#6](https://github.com/Shiryou/BirP/issues/6)

## [1.4.0.4] - 2025-11-02

### Changed

- Allow calling all files from game directory instead of CD; the CD is no longer required in this mode (all files must first be copied from the CD to the game directory). [#2](https://github.com/Shiryou/BirP/issues/2)

### Fixed

- Custom adventures no longer crash the game when picking up the quest goal item. [#3](https://github.com/Shiryou/BirP/issues/3)
