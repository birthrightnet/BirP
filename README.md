# Birthright Preservation Patch

The Birthright Preservation Patch is an enhancement for the Windows version of Birthright: The Gorgon's Alliance. Its primary goal is to address bugs within the game while also enhancing existing features for a better overall experience.

This repository is for **developers** of the Birthright Preservation Patch, and mirrors the [https://github.com/Shiryou/birp-dev](https://github.com/Shiryou/birp-dev). The **player** repository with installation instructions can be found at [https://github.com/Shiryou/BirP](https://github.com/Shiryou/BirP).

## Getting started

Follow these steps to get started developing and building this project.

### Install the original game + patch it

Install the original Birthright: The Gorgon's Alliance and apply the official Patch 1.4 already installed. Follow [Kiran's Installation Guide](https://www.kiranwelle.com/birthright/).

### Install the project toolchain and dependencies

This birp-dev repository does NOT contain the required toolchain, packages, and resources that you will require to build the game. You need to install them in the correct folder structure so that the project build files, like [MAKE.BAT](MAKE.BAT), can use them to build the project.

Follow these steps to set up your project toolchain and dependencies:

### 1) Setting up the `birp-dependencies` folder

Unpack the `birp-dependencies.7z`, which contains a folder called `birp-dependencies` to a sibling folder to `birp-dev`. The resulting folder structure should look like this:

```text
SomeParentFolder/
|-- birp-dev/
|-- birp-dependencies/
```

### 2) Set up your environment variables for building

Run [setup-env-vars-for-birthright-preservation-patch.ps1](./scripts/setup-env-vars-for-birthright-preservation-patch.ps1) to setup the required environment variables for [Open Watcom 2.0](../birp-dependencies/OPENWATCOM-v2_0/), [DirectX 5 SDK](../birp-dependencies/DirectXSDK/), [Windows 95 DDK](../birp-dependencies/Windows95DDK/) and [UASM 2.57](../birp-dependencies/UASM-v2_57/).

You can run it with:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1`

### 3) Validate your environment variables

Run [check-for-duplicate-env-vars.ps1](./scripts/check-for-duplicate-env-vars.ps1) to validate that your environment variables are set up correctly.

You can run it with:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1`

## Toolchain Notes

* The default developer toolchain was Watcom 10.6. It was removed from this repository after persistent WLINK memory access issues.
* [Open Watcom v2.0](../birp-dependencies/OPENWATCOM-v2_0/) is the active compiler toolchain.
* [UASM v2.57](../birp-dependencies/UASM-v2_57/) is the MASM-compatible assembler used for legacy `*.ASM` modules where Watcom `wasm` compatibility is limited.
* Setup and validation scripts are documented in [./scripts/README.md](./scripts/README.md).

## Building the game

You are now ready to compile the Windows version of Birthright, which runs on operating systems up to Windows 11

TLDR, run:

`MAKE.BAT WIN95`

.. and your project should build to the [build-artifacts/binaries](build-artifacts/binaries) folder. Skip to the [next section](#installing-your-build-and-testing) to learn how to install and test your build.

### Advanced build options

You can customize your build with many options. See [BUILD-OPTIONS.md](./BUILD-OPTIONS.md) for details on available build options, including build modes, feature flags, and targets.

### Other build information

For historical reference, [`MAKE-ORIGINAL.BAT`](./source/MAKE-ORIGINAL.BAT) is also included. This is the make script used in the original source tree, retained with only minor modifications in this repository.

## Installing your build and testing

Simply copy your built files from your [build-artifacts/binaries](build-artifacts/binaries) folder into your installed game directory (e.g. `C:\BIRTHRT`) and run the EXE you deployed there.

## Logging

You can find the log files in the game directory (e.g. `C:\BIRTHRT`) after running the game. These logs can be useful for troubleshooting and debugging issues with the game.

The following log messages are created at the beginning of each session:

* `DOS.LOG` - The DOS version of the game.
* `WINBR.LOG` - The Windows version of the game.
* `CHARED.LOG` - The Character Editor.

When trying to gather information on a reproducible bug, it can be useful to increase the game's logging. This can be done by opening `BRSETUP.CFG` and adding the following lines:

```text
[LOG_LEVEL]
TRACE
```

The available logging levels are listed below. Each logging level will log messages at the specified level and below (i.e. DEBUG will include DEBUG, INFO, WARN, and FATAL messages).

* `TRACE`: Log all messages.
* `DEBUG`: Resource information, networking status calls, or more verbose messages useful for basic troubleshooting.
* `INFO`: General information on what the game is doing (i.e. actions, adventures, battles, etc).
* `WARN`: Errors or things that didn't go as expected, but aren't a major problem.
* `FATAL`: Errors that break the game and will cause a crash.

## Changelog

The [Changelog](./CHANGELOG.md) contains a log of changes made to the project, including bug fixes and new features.

Keep this file up to date with any notable changes you make to the project. Follow the existing format there when updating it.

### Updating Version Numbers

Internal version numbers are set in `VERSION.CPP`. These should only be updated when functionality changes might cause issues in multiplayer. The patch version numbers are set in `PVERSION.H`.

## Technologies and languages, and Code Styles

This project uses several legacy technologies together:

* C (`*.C`) and C++ (`*.CPP`) across the game engine, UI, gameplay, and AI.
* Header variants (`*.H`, `*.HXX`) for mixed C/C++ interfaces.
* Assembly (`*.ASM`) for some low-level/audio routines (including MASM-style legacy sources).
* Windows resources (`*.RC`) and dialog definitions (`*.DLG`).
* Watcom `wmake` makefiles plus batch wrappers (`MAKE.BAT`, `source/MAKEFILE`) for DOS/WIN95 builds.
* Legacy SDK dependencies (DirectX 5 SDK and Windows 95 DDK).

Common style patterns in this codebase:

* Legacy compatibility-first approach: avoid behavior changes unless needed.
* Macro-heavy and conditional compilation patterns (`_WINDOWS`, `AUDIO_LIB`, etc.).
* Mixed procedural C and object-oriented C++ style.
* Historically stable uppercase file naming and minimal-diff maintenance.

At-a-glance matrix:

| Area | Primary language/tech | Typical files | Example directories | Notes |
| --- | --- | --- | --- | --- |
| Core engine/runtime | C | `*.C`, `*.H` | `source/`, `source/WINSYS/` | Low-level systems and shared runtime behavior. |
| Gameplay and UI | C++ | `*.CPP`, `*.HXX` | `source/`, `source/WINSYS/` | Domain logic, menus, AI, and game flow. |
| Audio codecs/helpers | Assembly + C/C++ | `*.ASM`, `SOLAUDIO/SOURCE/WIN/*` | `source/SOLAUDIO/SOURCE/WIN/`, `source/SOLAUDIO/SOURCE/DOS/` | Legacy MASM-style assembly sources exist in audio paths. |
| Windows resources | RC/DLG scripts | `*.RC`, `*.DLG` | `source/`, `source/WINSYS/` | Menus, dialogs, and resource definitions. |
| Build orchestration | Watcom make + batch | `source/MAKEFILE`, `MAKE.BAT` | `source/`, `source/SOLAUDIO/SOURCE/WIN/` | Multi-target DOS/WIN95 builds via `wmake`. |
| External SDK integration | Win95 DDK + DirectX 5 SDK | Include/lib paths in env vars | `../birp-dependencies/`, `scripts/` | Required headers/libs for legacy platform compatibility. |

## Contributing

Keep all your changes in a branch and submit a pull request (PR) when your changes are ready to be reviewed and merged.

Squash your commits into large commits to keep the commit history clean. For example, if you are working on a bug fix, you might have several commits as you work on the fix, but when you submit your PR, you should squash those commits into a single commit that describes the bug fix.

Please communicate with Kiran before starting work to ensure it aligns with the vision of the project.

## Disclaimer

This patch aims to enhance and fix bugs in **Birthright: The Gorgon's Alliance**, originally developed by **Synergistic Software** for **Sierra On-Line, Inc.** All rights to the original game and its assets remain with the original creators. The patch is not endorsed or supported by the original developers or the current license holders. The legality of using this source code may vary by jurisdiction.

This patch is provided free of charge and is not intended for commercial use. Any distribution of this patch must not be for profit. It is provided 'as-is' without any warranty. The creator(s) are not responsible for any issues that may arise from using this patch, including data loss, game crashes, or other unintended consequences.

The patch is developed as a community effort. The original developers retain their rights to the original source code. Where permissable by law, modifications to the original source code are provided under the MIT license. Feedback and contributions are welcome, but please honor the rights of the original creators.
