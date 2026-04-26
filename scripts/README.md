# Scripts Overview

This folder contains scripts for helping configure the development environment and for building and deploying the project. For more detailed instructions on setting up your development environment and building the project, please see the [birp-dev/README.md](../README.md).

## Initial Setup Scripts

These scripts are intended to be run once during initial setup to configure your environment variables for the required toolchains. They can also be re-run if you need to update or fix your environment variable configuration. They support optional overrides for SDK paths and other configuration details, but by default they will set up environment variables with repository defaults that should work for most users.

- [setup-env-vars-for-birthright-preservation-patch.ps1](./setup-env-vars-for-birthright-preservation-patch.ps1) - Use this when you want to configure [Open Watcom v2.0](../../birp-dependencies/OPENWATCOM-v2_0). It adds required references for PATH, INCLUDE, LIB, WATCOM, EDPATH, WHTMLHELP, and WIPFC for session and user scopes only. It prevents duplicate entries, creates a timestamped backup of your current user env vars, and includes references to [DirectX 5.0 SDK](../../birp-dependencies/DirectXSDK) and [Windows 95 DDK](../../birp-dependencies/Windows95DDK).
- [check-for-duplicate-env-vars.ps1](./check-for-duplicate-env-vars.ps1) - A validation utility that scans HKCU\Environment for duplicate entries in PATH, INCLUDE, and LIB variables. Useful for verifying that [setup-env-vars-for-birthright-preservation-patch.ps1](./setup-env-vars-for-birthright-preservation-patch.ps1) ran successfully and no duplicates were created. Run this after executing a setup script or whenever you want to verify environment variable integrity. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File check-for-duplicate-env-vars.ps1

## Test Scripts

These scripts validate the expected output of [MAKE.BAT](../MAKE.BAT) for each build scenario, including expected log markers and build artifacts. They support an optional path override to [MAKE.BAT](../MAKE.BAT) and an option to skip the toolchain availability check (useful if you just want to validate the logging and artifact expectations without actually running a build).

- [test-all-builds.ps1](./test-all-builds.ps1) - Build-output validation harness for [MAKE.BAT](../MAKE.BAT). Runs all 4 scenario wrappers (WIN95 and DOS release/debug), aggregates pass/fail status, and supports continue-on-failure behavior.

## Build Scripts

These scripts wrap calls to [MAKE.BAT](../MAKE.BAT) with specific arguments for each build scenario, and they validate the expected log output and build artifacts for each scenario. They also support an optional path override to [MAKE.BAT](../MAKE.BAT) and an option to skip the toolchain availability check (useful if you just want to validate the logging and artifact expectations without actually running a build).

- [build-win-release.ps1](./build-win-release.ps1) - Scenario wrapper for WIN95 release install build output validation.
- [build-win-debug.ps1](./build-win-debug.ps1) - Scenario wrapper for WIN95 debug install build output validation.
- [build-dos-release.ps1](./build-dos-release.ps1) - Scenario wrapper for DOS release install build output validation.
- [build-dos-debug.ps1](./build-dos-debug.ps1) - Scenario wrapper for DOS debug install build output validation.
- [build-helper.ps1](./build-helper.ps1) - Shared scenario runner used by each scenario wrapper. Validates toolchain availability (unless skipped), runs a target [MAKE.BAT](../MAKE.BAT) invocation, verifies expected log markers under `birp-dev\build-artifacts\logs`, and confirms expected output binaries exist.

## Deploy Scripts

These scripts copy a specific built executable from [../build-artifacts/binaries](../build-artifacts/binaries) into `C:\BIRTHRT` for testing. They also support an optional path override to the source executable and validate that the source executable and destination directory exist before copying.

- [deploy-win-release.ps1](./deploy-win-release.ps1) - Copies [../build-artifacts/binaries/Release/Windows/nova95.exe](../build-artifacts/binaries/Release/Windows/nova95.exe) to `C:\BIRTHRT`.
- [deploy-win-debug.ps1](./deploy-win-debug.ps1) - Copies [../build-artifacts/binaries/Debug/Windows/nova95.exe](../build-artifacts/binaries/Debug/Windows/nova95.exe) to `C:\BIRTHRT`.
- [deploy-dos-release.ps1](./deploy-dos-release.ps1) - Copies [../build-artifacts/binaries/Release/DOS/nova.exe](../build-artifacts/binaries/Release/DOS/nova.exe) to `C:\BIRTHRT`.
- [deploy-dos-debug.ps1](./deploy-dos-debug.ps1) - Copies [../build-artifacts/binaries/Debug/DOS/nova.exe](../build-artifacts/binaries/Debug/DOS/nova.exe) to `C:\BIRTHRT`.
- [deploy-helper.ps1](./deploy-helper.ps1) - Shared deploy helper that copies one built executable from [../build-artifacts/binaries](../build-artifacts/binaries) into `C:\BIRTHRT` after verifying the source executable and destination directory exist.

## Build and Deploy Scripts

These scripts run the above build scenario wrapper and then, if the build succeeds, deploys the resulting executable to `C:\BIRTHRT`. They support optional path overrides to [MAKE.BAT](../MAKE.BAT) and the source executable, and they validate expected log output, build artifacts, and successful deployment.

- [build-and-deploy-win-release.ps1](./build-and-deploy-win-release.ps1) - Runs [build-win-release.ps1](./build-win-release.ps1) and then [deploy-win-release.ps1](./deploy-win-release.ps1).
- [build-and-deploy-win-debug.ps1](./build-and-deploy-win-debug.ps1) - Runs [build-win-debug.ps1](./build-win-debug.ps1) and then [deploy-win-debug.ps1](./deploy-win-debug.ps1).
- [build-and-deploy-dos-release.ps1](./build-and-deploy-dos-release.ps1) - Runs [build-dos-release.ps1](./build-dos-release.ps1) and then [deploy-dos-release.ps1](./deploy-dos-release.ps1).
- [build-and-deploy-dos-debug.ps1](./build-and-deploy-dos-debug.ps1) - Runs [build-dos-debug.ps1](./build-dos-debug.ps1) and then [deploy-dos-debug.ps1](./deploy-dos-debug.ps1).
- [build-and-deploy-helper.ps1](./build-and-deploy-helper.ps1) - Shared helper used by each build-and-deploy scenario wrapper.

## Misc Scripts

These scripts don't fit into the above categories but are still important for development and maintenance.

- [create-birp-package.ps1](./create-birp-package.ps1) - Creates a timestamped `birp-package-<date-time>.7z` archive containing the repository's packaging inputs: [../../.github](../../.github), [../../birp-dependencies](../../birp-dependencies), [../scripts](../scripts), [../../.gitignore](../../.gitignore), [../../.markdownlint-cli2.yaml](../../.markdownlint-cli2.yaml), [../../package.json](../../package.json), and [../../package-lock.json](../../package-lock.json). Requires 7-Zip in PATH or installed in the default `C:\Program Files\7-Zip` location.

## Other Important Files

- [MAKE.BAT](../../birp-dev/MAKE.BAT) - The main build script. It uses the active environment variables to determine which toolchain to use, so make sure to run one of the setup scripts first to configure your environment. It also accepts various arguments for controlling the build process, such as target platform, build configuration, and specific components to build. Run `make /?` for usage details.

## Recommended Usage

Run setup with repository defaults:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1`

Create the timestamped packaging archive:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\create-birp-package.ps1`

Deploy the WIN95 release executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-win-release.ps1`

Deploy the WIN95 debug executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-win-debug.ps1`

Deploy the DOS release executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-dos-release.ps1`

Deploy the DOS debug executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-dos-debug.ps1`

Optional overrides:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1 -Win95DdkRoot "D:\SDKs\Windows95DDK" -DxSdkRoot "D:\SDKs\DirectXSDK"`

Validate that PATH/INCLUDE/LIB were deduplicated:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1`

Run MAKE.BAT output smoke tests:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-builds.ps1`

Run the full MAKE.BAT output suite (continues after failures):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-builds.ps1 -ContinueOnFailure`

Run a single scenario (example: WIN95 release):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-win-release.ps1`

Run WIN95 release build and deploy:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-win-release.ps1`

Run WIN95 debug build and deploy:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-win-debug.ps1`

Run DOS release build and deploy:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-dos-release.ps1`

Run DOS debug build and deploy:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\build-and-deploy-dos-debug.ps1`
