# Scripts Overview

This folder contains scripts for helping configure the development environment and for building and deploying the project. For more detailed instructions on setting up your development environment and building the project, please see the [birp-dev/README.md](../README.md).

## Initial Setup Scripts

These scripts are intended to be run once during initial setup to configure your environment variables for the required toolchains. They can also be re-run if you need to update or fix your environment variable configuration. They support optional overrides for SDK paths and other configuration details, but by default they set up environment variables using explicit defaults under `C:\BirP-Dependencies` (plus `C:\SIERRA\BIRTHRT` for game install path).

- [setup-env-vars-for-building.ps1](./setup-env-vars-for-building.ps1) - Use this when you want to configure [Open Watcom v2.0](../../birp-dependencies/OPENWATCOM-v2_0). It adds required references for PATH, INCLUDE, LIB, WATCOM, EDPATH, WHTMLHELP, WIPFC, BIRTHRT_INSTALL_DIR, and DIGITALV_INCLUDE_DIR for session and user scopes only. It prevents duplicate entries, creates a timestamped backup of your current user env vars, includes references to [DirectX 5.0 SDK](../../birp-dependencies/DirectXSDK) and [Windows 95 DDK](../../birp-dependencies/Windows95DDK), and supports optional overrides for `-OpenWatcomRoot`, `-UasmRoot`, `-Win95DdkRoot`, `-DxSdkRoot`, `-BirthrtInstallDir`, and `-DigitalvIncludeDir`.
- [check-for-duplicate-env-vars.ps1](./check-for-duplicate-env-vars.ps1) - A validation utility that scans HKCU\Environment for duplicate entries in PATH, INCLUDE, and LIB variables. Useful for verifying that [setup-env-vars-for-building.ps1](./setup-env-vars-for-building.ps1) ran successfully and no duplicates were created. Run this after executing a setup script or whenever you want to verify environment variable integrity. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File check-for-duplicate-env-vars.ps1

## Test Scripts

These scripts validate the expected output of [MAKE.BAT](../MAKE.BAT) for each build scenario, including expected log markers and build artifacts. They support an optional path override to [MAKE.BAT](../MAKE.BAT), an option to skip the toolchain availability check, quiet-by-default terminal output, and diagnostic capture/reporting for warning and error lines.

- [test-all-builds.ps1](./test-all-builds.ps1) - Build-output validation harness for [MAKE.BAT](../MAKE.BAT). Builds all scenarios (WIN, DOS, RELEASE, and DEBUG), aggregates pass/fail status, supports continue-on-failure behavior, supports `-ShowInformationalOutput` to print full build output to the terminal, and supports `-MaxDiagnosticLines` to control how many warning/error lines are retained in the aggregate report.

## Build Scripts

These scripts wrap calls to [MAKE.BAT](../MAKE.BAT) with specific arguments for each build scenario, and they validate the expected log output and build artifacts for each scenario. They also support an optional path override to [MAKE.BAT](../MAKE.BAT), an option to skip the toolchain availability check, and quiet-by-default terminal output. By default, informational compile output is suppressed in terminal while warnings and errors are still shown; use `-ShowInformationalOutput` to restore full terminal output.

- [build-win-release.ps1](./build-win-release.ps1) - Builds the WIN (RELEASE) executable and reports any warnings or errors.
- [build-win-debug.ps1](./build-win-debug.ps1) - Builds the WIN (DEBUG) executable and reports any warnings or errors.
- [build-chared-release.ps1](./build-chared-release.ps1) - Builds the WIN (RELEASE, CHARED) executable and reports any warnings or errors.
- [build-chared-debug.ps1](./build-chared-debug.ps1) - Builds the WIN (DEBUG, CHARED) executable and reports any warnings or errors.
- [build-dos-release.ps1](./build-dos-release.ps1) - Builds the DOS (RELEASE) executable and reports any warnings or errors.
- [build-dos-debug.ps1](./build-dos-debug.ps1) - Builds the DOS (DEBUG) executable and reports any warnings or errors.
- [build-helper.ps1](./build-helper.ps1) - Builds ALL possible WIN, DOS, RELEASE, and DEBUG scenarios. Validates toolchain availability (unless skipped), runs a target [MAKE.BAT](../MAKE.BAT) invocation, captures warning/error lines from terminal output, writes a single-scenario report under `birp-dev\build-artifacts\logs`, verifies expected log markers, and confirms expected output binaries exist.

## Deploy Scripts

These scripts copy a specific built executable from [../build-artifacts/binaries](../build-artifacts/binaries) into the path defined by `BIRTHRT_INSTALL_DIR` for testing (with `C:\BIRTHRT` as a fallback if the environment variable is not set). They also support an optional path override to the source executable and validate that the source executable and destination directory exist before copying. To mirror an actual patch installation, each script deploys under the installer/patch file name (`nova95.exe` -> `WINBR.EXE`, `nova.exe` -> `NOVA.EXE`, `chared.exe` -> `CHARED.EXE`) and also copies the freshly built string data as `STRDAT.DAT`.

- [deploy-win-release.ps1](./deploy-win-release.ps1) - Deploys [../build-artifacts/binaries/Release/Windows/nova95.exe](../build-artifacts/binaries/Release/Windows/nova95.exe) to `BIRTHRT_INSTALL_DIR` as `WINBR.EXE`.
- [deploy-win-debug.ps1](./deploy-win-debug.ps1) - Deploys [../build-artifacts/binaries/Debug/Windows/nova95.exe](../build-artifacts/binaries/Debug/Windows/nova95.exe) to `BIRTHRT_INSTALL_DIR` as `WINBR.EXE`.
- [deploy-chared-release.ps1](./deploy-chared-release.ps1) - Deploys [../build-artifacts/binaries/Release/Windows/chared.exe](../build-artifacts/binaries/Release/Windows/chared.exe) to `BIRTHRT_INSTALL_DIR` as `CHARED.EXE`.
- [deploy-chared-debug.ps1](./deploy-chared-debug.ps1) - Deploys [../build-artifacts/binaries/Debug/Windows/chared.exe](../build-artifacts/binaries/Debug/Windows/chared.exe) to `BIRTHRT_INSTALL_DIR` as `CHARED.EXE`.
- [deploy-dos-release.ps1](./deploy-dos-release.ps1) - Deploys [../build-artifacts/binaries/Release/DOS/nova.exe](../build-artifacts/binaries/Release/DOS/nova.exe) to `BIRTHRT_INSTALL_DIR` as `NOVA.EXE`.
- [deploy-dos-debug.ps1](./deploy-dos-debug.ps1) - Deploys [../build-artifacts/binaries/Debug/DOS/nova.exe](../build-artifacts/binaries/Debug/DOS/nova.exe) to `BIRTHRT_INSTALL_DIR` as `NOVA.EXE`.
- [deploy-helper.ps1](./deploy-helper.ps1) - Shared deploy helper that deploys one built executable from [../build-artifacts/binaries](../build-artifacts/binaries) into `BIRTHRT_INSTALL_DIR` (or `C:\BIRTHRT` fallback) after verifying the source executable and destination directory exist. Accepts an optional `-DestinationFileName` to deploy under the patch/installer name, and also copies the built `STRDAT.DAT` and the issue reporting tool (`BirP-Issue-Report.bat`/`.ps1` from [../issue-reporter](../issue-reporter)), mirroring the installer's patch payload.

## Build and Deploy Scripts

These scripts run the above build scenario wrapper and then, if the build succeeds, deploy the resulting executable to `BIRTHRT_INSTALL_DIR` (or `C:\BIRTHRT` fallback). They support optional path overrides to [MAKE.BAT](../MAKE.BAT), optional verbose build output via `-ShowInformationalOutput`, and they validate expected log output, build artifacts, and successful deployment.

- [build-and-deploy-win-release.ps1](./build-and-deploy-win-release.ps1) - Runs [build-win-release.ps1](./build-win-release.ps1) and then [deploy-win-release.ps1](./deploy-win-release.ps1) to build and deploy the WIN (RELEASE) executable.
- [build-and-deploy-win-debug.ps1](./build-and-deploy-win-debug.ps1) - Runs [build-win-debug.ps1](./build-win-debug.ps1) and then [deploy-win-debug.ps1](./deploy-win-debug.ps1) to build and deploy the WIN (DEBUG) executable.
- [build-and-deploy-chared-release.ps1](./build-and-deploy-chared-release.ps1) - Runs [build-chared-release.ps1](./build-chared-release.ps1) and then [deploy-chared-release.ps1](./deploy-chared-release.ps1) to build and deploy the WIN (RELEASE, CHARED) executable.
- [build-and-deploy-chared-debug.ps1](./build-and-deploy-chared-debug.ps1) - Runs [build-chared-debug.ps1](./build-chared-debug.ps1) and then [deploy-chared-debug.ps1](./deploy-chared-debug.ps1) to build and deploy the WIN (DEBUG, CHARED) executable.
- [build-and-deploy-dos-release.ps1](./build-and-deploy-dos-release.ps1) - Runs [build-dos-release.ps1](./build-dos-release.ps1) and then [deploy-dos-release.ps1](./deploy-dos-release.ps1) to build and deploy the DOS (RELEASE) executable.
- [build-and-deploy-dos-debug.ps1](./build-and-deploy-dos-debug.ps1) - Runs [build-dos-debug.ps1](./build-dos-debug.ps1) and then [deploy-dos-debug.ps1](./deploy-dos-debug.ps1) to build and deploy the DOS (DEBUG) executable.
- [build-and-deploy-helper.ps1](./build-and-deploy-helper.ps1) - Shared helper used by each build-and-deploy scenario wrapper. It passes build-related options such as `-SkipToolchainCheck`, `-MakeBatPath`, and `-ShowInformationalOutput` through to the underlying build wrapper.

## Misc Scripts

These scripts don't fit into the above categories but are still important for development and maintenance.

- [create-birp-package.ps1](./create-birp-package.ps1) - Creates a timestamped `birp-package-<date-time>.7z` archive containing the repository's packaging inputs: [../../.github](../../.github), [../../birp-dependencies](../../birp-dependencies), [../scripts](../scripts), [../../.gitignore](../../.gitignore), [../../.markdownlint-cli2.yaml](../../.markdownlint-cli2.yaml), [../../package.json](../../package.json), and [../../package-lock.json](../../package-lock.json). Requires 7-Zip in PATH or installed in the default `C:\Program Files\7-Zip` location.

## Other Important Files

- [MAKE.BAT](../../birp-dev/MAKE.BAT) - The main build script. It uses the active environment variables to determine which toolchain to use, so make sure to run one of the setup scripts first to configure your environment. It also accepts various arguments for controlling the build process, such as target platform, build configuration, and specific components to build. Run `make /?` for usage details.

## Recommended Usage

Run setup with default paths (`C:\BirP-Dependencies\...` and `C:\SIERRA\BIRTHRT`):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1`

Create the timestamped packaging archive:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\create-birp-package.ps1`

Deploy the WIN (RELEASE) executable to `BIRTHRT_INSTALL_DIR`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-win-release.ps1`

Deploy the WIN (DEBUG) executable to `BIRTHRT_INSTALL_DIR`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-win-debug.ps1`

Deploy the WIN (RELEASE, CHARED) executable to `BIRTHRT_INSTALL_DIR`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-chared-release.ps1`

Deploy the WIN (DEBUG, CHARED) executable to `BIRTHRT_INSTALL_DIR`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-chared-debug.ps1`

Deploy the DOS (RELEASE) executable to `BIRTHRT_INSTALL_DIR`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-dos-release.ps1`

Deploy the DOS (DEBUG) executable to `BIRTHRT_INSTALL_DIR`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-dos-debug.ps1`

Optional overrides:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -Win95DdkRoot "D:\SDKs\Windows95DDK" -DxSdkRoot "D:\SDKs\DirectXSDK"`

Set all optional override paths:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-building.ps1 -OpenWatcomRoot "D:\SDKs\OPENWATCOM-v2_0" -UasmRoot "D:\SDKs\UASM-v2_57" -Win95DdkRoot "D:\SDKs\Windows95DDK" -DxSdkRoot "D:\SDKs\DirectXSDK" -BirthrtInstallDir "D:\Games\BIRTHRT" -DigitalvIncludeDir "D:\SDKs\Windows95DDK\INC16"`

Validate that PATH/INCLUDE/LIB were deduplicated:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1`

Run MAKE.BAT output smoke tests:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-builds.ps1`

Run MAKE.BAT output smoke tests with full informational terminal output:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-builds.ps1 -ShowInformationalOutput`

Run MAKE.BAT output smoke tests while limiting stored warning/error lines per scenario:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-builds.ps1 -MaxDiagnosticLines 50`

Run the full MAKE.BAT output suite (continues after failures):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-builds.ps1 -ContinueOnFailure`

Run a single scenario (example: WIN RELEASE):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-win-release.ps1`

Run a single scenario with full informational terminal output:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-win-release.ps1 -ShowInformationalOutput`

Run a single scenario for the Character Editor (WIN RELEASE CHARED):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-chared-release.ps1`

Run a single debug scenario for the Character Editor (WIN DEBUG CHARED):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-chared-debug.ps1`

Build and deploy WIN (RELEASE):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-win-release.ps1`

Build and deploy WIN (RELEASE) with full informational build output:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-win-release.ps1 -ShowInformationalOutput`

Build and deploy WIN (DEBUG):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-win-debug.ps1`

Build and deploy WIN (RELEASE, CHARED):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-chared-release.ps1`

Build and deploy WIN (DEBUG, CHARED):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-chared-debug.ps1`

Build and deploy DOS (RELEASE):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-dos-release.ps1`

Build and deploy DOS (DEBUG):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-dos-debug.ps1`
