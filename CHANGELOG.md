# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Descriptive [README](README.md) and this CHANGELOG.

### Changed

- Allow calling all files form game directory instead of CD (game and `CHARED.EXE`). (#2)  
  (All files must be copied from the CD to the game directory before launching with this option.)
- Replace timestamps with build numbers for more reproducible builds. (#7)
- Replace the two existing logging mechanisms with something more robust. (#8)

### Fixed

- Custom adventures no longer crash the game when picking up the quest goal item. (#3)
