# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Created the project [README](README.md) and this [CHANGELOG](CHANGELOG.md).
- Added `MAKE.BAT` build wrapper that always captures a timestamped `wmake` log under `build-artifacts\logs\`.
- Added tracked `MAKE-ORIGINAL.BAT` (original-source make helper retained with only minor modifications) and documented its purpose.
- Added `birp-dev\scripts\test-all-build-outputs.ps1`, a build-output validation harness for `MAKE.BAT` covering common WIN95/DOS debug, release, profile, clean, and CHARED scenarios with log and artifact checks.

### Changed

- Allow calling all files from game directory instead of CD. (#2)  
  (All files must be copied from the CD to the game directory before launching with this option.)
- Replace timestamps with build numbers for more reproducible builds. (#7)
- Replaced broken and poor logging with new logging mechanism. (#8)
- Forced building of [RESUTIL](source/RESUTIL/) and [SOLAUDIO](source/SOLAUDIO/) dependencies during start of [MAKE.BAT](MAKE.BAT).
- Force `_RANDLOG` and `_LOGCOMMENT` flags on in during [MAKE.BAT](MAKE.BAT) builds force consistent logging across all build types.
- Added many build, environment setup, test, deployment, and other opterational scripts into [scripts](scripts/README.md).
- Updated [source/birp.cbp](source/birp.cbp) to match the current makefile-driven build matrix, including DOS output paths, CHARED release flags, and PROFILE target support.

### Fixed

- Custom adventures no longer crash the game when picking up the quest goal item. (#3)
- Fixed many legacy C and C++ errors that were intolerable by our modern Open Watcom toolchain.

### Developed but Untested

- Fix a random Adventure Mode crash related to bump state (checks if unit is too close to another unit). There were several possible crash scenarios related to bump checking, AI searching, and moving units towards each other. See: [known-issue-adventure-mode-random-crash.md](known-issue-adventure-mode-random-crash.md).
