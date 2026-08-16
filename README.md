# Birthright Preservation Patch

The Birthright Preservation Patch (BirP) is an enhancement for the Windows version of Birthright: The Gorgon's Alliance. The primary goals of the project are to fix bugs, restore functionality that was never completed, and introduce quality of life features to make the game more enjoyable for new and old players alike.

This repository is for **developers** of the Birthright Preservation Patch, and mirrors the [https://github.com/Shiryou/birp-dev](https://github.com/Shiryou/birp-dev). The **player** repository with installation instructions can be found at [https://github.com/Shiryou/BirP](https://github.com/Shiryou/BirP).

## Table of Contents

- [Getting started building the project](#getting-started-building-the-project)
- [One-time development environment setup](#one-time-development-environment-setup)
  - [1) Install the original game + patch it](#1-install-the-original-game--patch-it)
  - [2) Install the project toolchain and dependencies](#2-install-the-project-toolchain-and-dependencies)
  - [3) Creating a folder for DIGITALV.H](#3-creating-a-folder-for-digitalvh)
  - [4) Set up your environment variables for building](#4-set-up-your-environment-variables-for-building)
  - [5) Validate your environment variables](#5-validate-your-environment-variables)
- [Building the game](#building-the-game)
- [Building, Testing, and Deploying](#building-testing-and-deploying)
  - [Install-directory executables](#install-directory-executables)
  - [Installer tests](#installer-tests)
- [Testing In-Game](#testing-in-game)
  - [Automated game tests](#automated-game-tests)
- [Logging](#logging)
- [Team standards and contribution guidelines](#team-standards-and-contribution-guidelines)
  - [Coding style](#coding-style)
  - [Git and commit hygiene](#git-and-commit-hygiene)
  - [Pull Requests (PRs)](#pull-requests-prs)
  - [Documentation](#documentation)
  - [Use of AI](#use-of-ai)
- [Technologies and tools](#technologies-and-tools)
  - [Toolchain and dependencies](#toolchain-and-dependencies)
  - [Technologies and languages](#technologies-and-languages)
- [Disclaimer](#disclaimer)

## Getting started building the project

Welcome to the project! The first thing you'll want to do is setup your development environment so that you can build the project yourselves. This will require you to complete the [one-time development environment setup](#one-time-development-environment-setup) steps. After that, you can follow the [building the game](#building-the-game) instructions to build and deploy the app to your game installation.

If you run into any issues during setup or building, please let us know!

## One-time development environment setup

Follow these one-time steps to setup your development environment for building the project. You only need to do this once, and then you can skip to the [Building the game](#building-the-game) section for future builds.

### 1) Install the original game + patch it

Install the original Birthright: The Gorgon's Alliance and apply the official Patch 1.4 (the last patch to ever be released by the original developers). Follow [Kiran's Installation Guide](https://www.kiranwelle.com/birthright/) to get these installed properly.

    Keep note of your installed game directory (e.g. `C:\SIERRA\BIRTHRT`), you will need it when you configure your build and deploy environment variables.

### 2) Install the project toolchain and dependencies

This `birp-dev` repository does NOT contain the required toolchain, packages, and resources that you will require to build the game. You need to install them in your development environment and use environment variables to point to them so that the project build files, like [MAKE.BAT](MAKE.BAT), can use them to build the project.

Install the following dependencies in your development environment:

- [Open Watcom 2.0](https://www.openwatcom.org/)
- [DirectX 5 SDK](https://archive.org/details/DX5ENG)
- [Windows 95 DDK](https://archive.org/details/win95-win32-sdk)
- [UASM 2.57](https://github.com/Terraspace/UASM)
- [Inno Setup 6](https://jrsoftware.org/isdl.php) (only required to build the release installer, not for normal source builds)

    Keep note of the paths to all of these folders, you will need them when you configure your build environment variables.

### 3) Creating a folder for DIGITALV.H

You will need to copy the `DIGITALV.H` file from your now-installed [Windows 95 DDK](https://archive.org/details/win95-win32-sdk) INC16 folder into a new folder that contains nothing but this one `DIGITALV.H` file. For example, if you installed the Windows 95 DDK to `C:\BirP-Dependencies\Windows95DDK`, you would copy `C:\BirP-Dependencies\Windows95DDK\INC16\DIGITALV.H` to a new folder like `C:\BirP-Dependencies\Windows95DDK-INC16-DIGITALV\DIGITALV.H`.

    Keep note of the path to this new folder, you will need it when you configure your build environment variables.

### 4) Set up your environment variables for building

Run [setup-env-vars-for-building.ps1](./scripts/setup-env-vars-for-building.ps1) to setup the required environment variables for [Open Watcom 2.0](https://www.openwatcom.org/), [DirectX 5 SDK](https://archive.org/details/DX5ENG), [Windows 95 DDK](https://archive.org/details/win95-win32-sdk), [UASM 2.57](https://github.com/Terraspace/UASM), [Inno Setup 6](https://jrsoftware.org/isdl.php), `BIRTHRT_INSTALL_DIR`, and `DIGITALV_INCLUDE_DIR`.

By default, this script uses these paths when overrides are NOT provided:

- `C:\SIERRA\BIRTHRT` (from step #1)
- `C:\BirP-Dependencies\OPENWATCOM-v2_0` (from step #2)
- `C:\BirP-Dependencies\UASM-v2_57` (from step #2)
- `C:\BirP-Dependencies\Windows95DDK` (from step #2)
- `C:\BirP-Dependencies\DirectXSDK` (from step #2)
- `C:\BirP-Dependencies\InnoSetup-6` (from step #2)
- `C:\BirP-Dependencies\Windows95DDK-INC16-DIGITALV` (from step #3)

If you installed the dependencies and toolchain to different paths than the defaults, use must the overrides on the [setup-env-vars-for-building.ps1](./scripts/setup-env-vars-for-building.ps1) script, such as `-OpenWatcomRoot`, `-UasmRoot`, `-Win95DdkRoot`, `-DxSdkRoot`, `-InnoSetupRoot`, `-BirthrtInstallDir`, and `-DigitalvIncludeDir`.

Examples of how to use the [setup-env-vars-for-building.ps1](./scripts/setup-env-vars-for-building.ps1) script with and without overrides:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1` (for default paths)

or

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -OpenWatcomRoot "C:\CustomPath\OPENWATCOM-v2_0" -UasmRoot "C:\CustomPath\UASM-v2_57" -Win95DdkRoot "C:\CustomPath\Windows95DDK" -DxSdkRoot "C:\CustomPath\DirectXSDK" -InnoSetupRoot "C:\CustomPath\InnoSetup-6" -BirthrtInstallDir "C:\CustomPath\BIRTHRT" -DigitalvIncludeDir "C:\CustomPath\Windows95DDK-INC16-DIGITALV"`

Alternatively, you can set these environment variables manually in your system settings, but using the script is recommended to avoid typos and ensure all variables are set correctly. You can reference the script for the exact variable names and expected values.

### 5) Validate your environment variables

Run [check-for-duplicate-env-vars.ps1](./scripts/check-for-duplicate-env-vars.ps1) to validate that your environment variables are set up correctly.

You can run it with:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1`

## Building the game

Assuming you have completed all of the previous steps, You are now ready to build the project for Windows or DOS. The first step is to run the [MAKE.BAT](MAKE.BAT) script, which is the most direct entry point for building the project. This script is a wrapper around the `wmake` build system used by [Open Watcom](https://www.openwatcom.org/).

For your first run, open a terminal/shell and navigate to the root of this repository (birp-dev) and run:

`MAKE.BAT WIN95`

.. and your project should build to the [build-artifacts/binaries](build-artifacts/binaries) folder. If it has, congratulations, your environment variables are set up correctly! If you want to continue building this way, check out [BUILD-OPTIONS.md](./BUILD-OPTIONS.md) for details on available build options, including build modes, feature flags, and targets.

A faster and more convienient way to build is to use the various scripts found in the [scripts folder](./scripts). There you will find PowerShell scripts that wraap around the [MAKE.BAT](MAKE.BAT) and automate building, deploying, and testing all scenarios (WIN|DOS, RELEASE|DEBUG, CHARED). These scripts also summarize warnings and errors found in the build process and give you a PASS/FAIL result for each scenario.

Some examples:

- build-win-release.ps1: builds the Windows version of the game in RELEASE mode.
- build-and-deploy-dos-debug.ps1: builds the DOS version of the game in DEBUG mode and deploys it to your installed game directory (set by env vars earlier).
- test-all-builds.ps1: builds ALL scenarios (WIN|DOS, RELEASE|DEBUG, CHARED) and summarizes all results together.
- build-chared-release.ps1: builds the Character Editor in RELEASE mode (only available on WIN, not DOS).

## Building, Testing, and Deploying

To deploy the application after building, you can either manually copy the compiled binaries from the [build-artifacts/binaries](build-artifacts/binaries) folder into your installed game directory (e.g. `C:\SIERRA\BIRTHRT`), or run one of the various `build-and-deploy-*.ps1` scripts from the [scripts folder](./scripts).

For WIN builds you are looking for `nova95.exe`. For DOS builds you are looking for `nova.exe`. For the Character Editor builds you are looking for `chared.exe`.

### Install-directory executables

The build-artifact names above are **not** the names used in a player's install directory (e.g. `C:\SIERRA\BIRTHRT`). The deploy scripts and installer rename each build to its patch/installer name (for example, the Windows build `nova95.exe` is deployed **over** `WINBR.EXE`). The table below lists every executable we're aware of in the install directory, which ones we build, and what we build them from.

| EXE in install dir | What it is | Do we build it? | Build artifact | How it gets there |
|---|---|---|---|---|
| `WINBR.EXE` | Windows game executable (the main game on Windows) | **Yes** | `nova95.exe` | Patched build deployed/installed **over** `WINBR.EXE`; also ships from CD as stock in a fresh `game` install |
| `NOVA.EXE` | DOS (DOS4GW) game executable, patched | **Yes** | `nova.exe` | Patched build installed as `NOVA.EXE`; stock version also on CD |
| `CHARED.EXE` | Character editor (Windows) | **Yes** | `chared.exe` | Built and shipped **only** in the patch (`oldpatch\patch` component) |
| `BR.EXE` | Original 1996 Sierra **DOS** executable (stock, unpatched) | No | n/a | From CD only (`game` component); never patched/replaced |
| `DOS4GW.EXE` | DOS/4GW DOS extender runtime (loads the DOS game) | No | n/a | From CD only |
| `HAVEVESA.EXE` | VESA-support detection utility | No | n/a | From CD only |
| `VESATEST.EXE` | VESA test utility | No | n/a | From CD only |

Notes:

- We build and replace **exactly three** executables: `WINBR.EXE` (from `nova95.exe`), `NOVA.EXE` (from `nova.exe`), and `CHARED.EXE` (from `chared.exe`). Everything else is stock CD content we leave untouched.
- `WINBR.EXE` and `NOVA.EXE` are sourced from **both** the from-CD entries and the patch (our-build) entries in [installer/installer.iss](./installer/installer.iss); on a fresh Install the patched build wins. `CHARED.EXE` is patch-only.
- The build still **outputs** `nova95.exe`/`nova.exe`/`chared.exe` under those names in [build-artifacts/binaries](build-artifacts/binaries); only the deploy/install step renames them.

It's highly recommended that you run the [test-all-builds.ps1](./scripts/test-all-builds.ps1) script as you commit changes to ensure that all build scenarios are working properly and to catch any issues early on. This script will build and deploy all scenarios (WIN|DOS, RELEASE|DEBUG, CHARED) and give you a summary of the results, including any warnings or errors that were found during the build process.

### Installer tests

If you change anything under [installer/](./installer), run [test-installer.ps1](./scripts/test-installer.ps1). It compiles the installer, lints the localized strings, unit tests the path-safety helpers, runs silent Install/Patch/uninstall runs against generated stand-in game files, and exits 0 on pass. It needs Inno Setup 6 but no game CD and no elevation, and it never touches a real game install. The same suite runs in CI ([installer-tests.yml](./.github/workflows/installer-tests.yml)) on every installer change.

Every pull request that touches the game source, the build scripts, `MAKE.BAT`, or a workflow file also gets a build check ([build-check.yml](./.github/workflows/build-check.yml)). It runs [test-all-builds.ps1](./scripts/test-all-builds.ps1) on the runner, so all six scenarios have to compile before the change can merge, and it reports every scenario rather than stopping at the first failure. Run the same script locally before you push and you will see the same result. It needs no Inno Setup, because nothing in a plain build uses `iscc`.

## Testing In-Game

A custom test window is available in DEBUG builds that can be opened with the `F11` key. This window contains various buttons that trigger test actions in the game, such as granting items, triggering events, and simulating realm actions. This can be a useful tool for testing your changes in-game without having to go through the normal gameplay flow to trigger certain actions or events.

The code for this can be found in the [DBGWIND.CPP](./source/DBGWIND.CPP) ("Debug Window") file. You can add new buttons and test actions to this window as needed to help with your testing.

`F11` only answers where nothing is open over the game. Every menu, panel, and message box takes over key handling while it is showing, so the window opens from inside a running adventure or battle scene but not from a menu, a setup screen, or while a dialog is up. The same rule applies to every other key the game listens for, and it is the usual reason a hot key looks dead. If you need an action on a screen where `F11` cannot reach, close what is open first.

### Automated game tests

A smoke-test harness drives the deployed Windows build with real mouse clicks and keystrokes, captures each screen, and reports crashes or log errors. It covers booting to the menus, starting a new game from inside a running one, loading a saved game, the Battles Only battle report, the Begin New Game hot keys, and the adventure carry limit. Some scenarios drive the `F11` test window and read the result back out of the log.

Run it from [test-harness/](./test-harness):

`powershell -NoProfile -ExecutionPolicy Bypass -File run-smoke-tests.ps1 -Scenario boot-and-menus`

Read [test-harness/README.md](./test-harness/README.md) before writing a scenario. It records the run modes, the reference-image workflow, and the things that catch people out - the game reads the mouse by polling, keys go to whatever is open on top, and a scene keeps moving underneath any dialog you are checking.

## Logging

You can find the log files in the game directory (e.g. `C:\BIRTHRT`) after running the game. These logs can be useful for troubleshooting and debugging issues with the game.

The following log messages are created at the beginning of each session:

- `DOS.LOG` - The DOS version of the game.
- `WINBR.LOG` - The Windows version of the game.
- `CHARED.LOG` - The Character Editor.

The available logging levels are listed below. Each logging level will log messages at the specified level and below (i.e. DEBUG will include DEBUG, INFO, WARN, and FATAL messages).

- `TRACE`: Log all messages.
- `DEBUG`: Resource information, networking status calls, or more verbose messages useful for basic troubleshooting.
- `INFO`: General information on what the game is doing (i.e. actions, adventures, battles, etc).
- `WARN`: Errors or things that didn't go as expected, but aren't a major problem.
- `FATAL`: Errors that break the game and will cause a crash.

You can control the logging level by modifying `BRSETUP.CFG` and adding the following lines:

    [LOG_LEVEL]
    TRACE

Note that when building the DEBUG mode for WIN, DOS, or CHARED, the game will automatically log `DEBUG` level messages and above and you do not need to update the `BRSETUP.CFG` file to see these messages. However, if you want to see `TRACE` level messages, you will need to update the `BRSETUP.CFG` file as described above.

When building for RELEASE mode, the game will log `WARN` level messages and above by default, so you will need to update the `BRSETUP.CFG` file to see `DEBUG` or `TRACE` level messages.

If you inject code to utilize our new logging system, please remove the old logging code to keep the code clean. For example, if you add a new `LOG_INFO` message, please remove the old `printf` or `OutputDebugString` message that was there before.

## Team standards and contribution guidelines

The following are team standards that we have agreed to adopt and enforce throughout the codebase. Try as best you can to follow these standards when contributing to the project. If you have any questions about these standards or want to propose changes to them, please bring them up in the discussions.

### Coding style

- This is a legacy codebase that was originally developed in the 90s. Please keep the coding style consistent with the original codebase and keep diffs to a minimum.
- Do not introduce change just to update style or formatting. Again, keep diffs to a minimum and only change what you need to change to reach our project goals of fixing bugs, restoring functionality, and introducing quality of life features.
- If you have a change in mind that might be contenious, please raise it with the team first.
- If you inject code to utilize our new logging system, please remove the old logging code to keep the code clean. For example, if you add a new `LOG_INFO` message, please remove the old `printf` or `OutputDebugString` message that was there before.

### Git and commit hygiene

- Minimize number of commits and keep commit history clean. Squash your commits into large commits that describe the overall change you made, rather than having many small commits that describe individual steps you took to reach that change. For example, if you are working on a bug fix, you might have several commits as you work on the fix, but when you submit your PR, you should squash those commits into a single commit that describes the bug fix.
- Use rebase rather than merge when pulling changes from the main branch into your feature branch. This will help keep the commit history clean and linear.
- Ensure your commit message is descriptive and follows the standard format of `type(scope): description`, where:
  - `type` is one of `feat`, `fix`, `docs`, `style`, `refactor`, `test`, or `chore`
  - `scope` is the area of the codebase that your change affects (e.g. `audio`, `ui`, `gameplay`, etc)
  - For example, a commit message for a bug fix in the audio system might be: `fix(audio): resolve memory leak in audio buffer management`, followed by a description of the changes made.

### Pull Requests (PRs)

- Perform all work in branches and submit a PR when you are ready for your changes to be reviewed and merged into the main branch. Do not commit directly to the main branch.
- Ensure that you have tested your PR in all build scenarios (WIN|DOS, RELEASE|DEBUG, CHARED), and identify this in the PR description
- Ensure that you link to any relevant GitHub issues that your PR addresses in your PR description (and even name).
- Provide a clear summary of the commits in the PR, as well as any context or notes that would make it easier for reviewers to understand and review your changes.

### Documentation

Several files should be kept updated as the project evolves. This includes:

- The [Developer CHANGELOG.md](./CHANGELOG.md) file, which contains a log of changes made to the project, including bug fixes and new features. The standard format we follow is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). If a changelog line matches a GitHub Issue from the `https://github.com/Shiryou/BirP/issues` repository, it should include a hyperlink to the corresponding issue.
- This [Project README.md](./README.md) file, which contains an overview of the project, instructions for getting started, and other important information for developers and users.
- The [Player README.txt](./README.txt) file, which contains user-facing instructions and notes on how to use the new version of the patch. This should be kept in sync with the [Developer CHANGELOG.md](./CHANGELOG.md) file, but should be focused on the user experience and should not include changes relevant only to developers (scripting, refactoring, logging, dependencies, etc).
- The [PVERSION.HXX](./source/PVERSION.HXX) file, which contains the version information for the project. This should be updated only at release time according to the versioning rules outlined in the comments there.
- The [BUILD-OPTIONS.md](./BUILD-OPTIONS.md) file, which contains documentation on the various build options available for the project, including how to use them and what they do. Keep this updated if you modify or add build options.

### Use of AI

- AI tools are allowed for use in this project, but please keep individual AI prompts and instructions out of this repository.
- Do not allow AI-generated code to be commited in Git without your review and approval. You are responsible for all code that you commit, regardless of whether it was generated by you or an AI tool.
- If you are planning on using AI please do so responsibly and ensure that your agents follow the same team standards and guidelines that the developers follow.

## Technologies and tools

### Toolchain and dependencies

- The default developer toolchain was Watcom 10.6. It was removed from this repository after persistent WLINK memory access issues.
- [Open Watcom v2.0](https://www.openwatcom.org/) is the active compiler toolchain.
- [UASM v2.57](https://github.com/Terraspace/UASM) is the MASM-compatible assembler used for legacy `*.ASM` modules where Watcom `wasm` compatibility is limited.
- [mem.asm](source/MEM.ASM) is a legacy TASM-style assembly file that is not compatible with UASM or Open Watcom WASM. We link against a pre-assembled `mem.obj` to work around this issue. We are looking to assemble this file with Borland Turbo Assembler 5.x in the future.
- [DirectX 5 SDK](https://archive.org/details/DX5ENG) is required for Windows builds.
- [Windows 95 DDK](https://archive.org/details/win95-win32-sdk) is required for Windows builds.

### Technologies and languages

This project uses several legacy technologies together:

- C (`*.C`) and C++ (`*.CPP`) across the game engine, UI, gameplay, and AI.
- Header variants (`*.H`, `*.HXX`) for mixed C/C++ interfaces.
- Assembly (`*.ASM`) for some low-level/audio routines (including MASM-style  and TASM-style legacy sources).
- Windows resources (`*.RC`) and dialog definitions (`*.DLG`).
- Watcom `wmake` makefiles plus batch wrappers (`MAKE.BAT`, `source/MAKEFILE`) for DOS/WIN95 builds.
- Legacy SDK dependencies (DirectX 5 SDK and Windows 95 DDK).
- PowerShell scripts for build automation and environment setup.

At-a-glance matrix:

| Area | Primary language/tech | Typical files | Example directories | Notes |
| --- | --- | --- | --- | --- |
| Core engine/runtime | C | `*.C`, `*.H` | `source/`, `source/WINSYS/` | Low-level systems and shared runtime behavior. |
| Gameplay and UI | C++ | `*.CPP`, `*.HXX` | `source/`, `source/WINSYS/` | Domain logic, menus, AI, and game flow. |
| Audio codecs/helpers | Assembly + C/C++ | `*.ASM`, `SOLAUDIO/SOURCE/WIN/*` | `source/SOLAUDIO/SOURCE/WIN/`, `source/SOLAUDIO/SOURCE/DOS/` | Legacy MASM-style assembly sources exist in audio paths. |
| Windows resources | RC/DLG scripts | `*.RC`, `*.DLG` | `source/`, `source/WINSYS/` | Menus, dialogs, and resource definitions. |
| Build orchestration | Watcom make + batch | `source/MAKEFILE`, `MAKE.BAT` | `source/`, `source/SOLAUDIO/SOURCE/WIN/` | Multi-target DOS/WIN95 builds via `wmake`. |
| External SDK integration | Win95 DDK + DirectX 5 SDK | Include/lib paths in env vars | `../birp-dependencies/`, `scripts/` | Required headers/libs for legacy platform compatibility. |

## Disclaimer

This patch aims to enhance and fix bugs in **Birthright: The Gorgon's Alliance**, originally developed by **Synergistic Software** for **Sierra On-Line, Inc.** All rights to the original game and its assets remain with the original creators. The patch is not endorsed or supported by the original developers or the current license holders. The legality of using this source code may vary by jurisdiction.

This patch is provided free of charge and is not intended for commercial use. Any distribution of this patch must not be for profit. It is provided 'as-is' without any warranty. The creator(s) are not responsible for any issues that may arise from using this patch, including data loss, game crashes, or other unintended consequences.

The patch is developed as a community effort. The original developers retain their rights to the original source code. Where permissable by law, modifications to the original source code are provided under the MIT license. Feedback and contributions are welcome, but please honor the rights of the original creators.
