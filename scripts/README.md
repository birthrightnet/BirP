# Build Scripts

This folder contains scripts for helping configure the development environment and for building the project. For more detailed instructions on setting up your development environment and building the project, please see the [birp-dev/README.md](../README.md).

## Scripts

- [setup-env-vars-for-birthright-preservation-patch.ps1](./setup-env-vars-for-birthright-preservation-patch.ps1) - Use this when you want to configure [Open Watcom v2.0](../../birp-dependencies/OPENWATCOM-v2_0). It adds required references for PATH, INCLUDE, LIB, WATCOM, EDPATH, WHTMLHELP, and WIPFC for session and user scopes only. It prevents duplicate entries, creates a timestamped backup of your current user env vars, and includes references to [DirectX 5.0 SDK](../../birp-dependencies/DirectXSDK) and [Windows 95 DDK](../../birp-dependencies/Windows95DDK).
- [check-for-duplicate-env-vars.ps1](./check-for-duplicate-env-vars.ps1) - A validation utility that scans HKCU\Environment for duplicate entries in PATH, INCLUDE, and LIB variables. Useful for verifying that [setup-env-vars-for-birthright-preservation-patch.ps1](./setup-env-vars-for-birthright-preservation-patch.ps1) ran successfully and no duplicates were created. Run this after executing a setup script or whenever you want to verify environment variable integrity. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File check-for-duplicate-env-vars.ps1
- [create-birp-package.ps1](./create-birp-package.ps1) - Creates a timestamped `birp-package-<date-time>.7z` archive containing the repository's packaging inputs: [../../.github](../../.github), [../../birp-dependencies](../../birp-dependencies), [../scripts](../scripts), [../../.gitignore](../../.gitignore), [../../.markdownlint-cli2.yaml](../../.markdownlint-cli2.yaml), [../../package.json](../../package.json), and [../../package-lock.json](../../package-lock.json). Requires 7-Zip in PATH or installed in the default `C:\Program Files\7-Zip` location.
- [deploy-build-output-helper.ps1](./deploy-build-output-helper.ps1) - Shared deploy helper that copies one built executable from [../build-artifacts/binaries](../build-artifacts/binaries) into `C:\BIRTHRT` after verifying the source executable and destination directory exist.
- [deploy-build-output-win95-release.ps1](./deploy-build-output-win95-release.ps1) - Copies [../build-artifacts/binaries/Release/Windows/nova95.exe](../build-artifacts/binaries/Release/Windows/nova95.exe) to `C:\BIRTHRT`.
- [deploy-build-output-win95-debug.ps1](./deploy-build-output-win95-debug.ps1) - Copies [../build-artifacts/binaries/Debug/Windows/nova95.exe](../build-artifacts/binaries/Debug/Windows/nova95.exe) to `C:\BIRTHRT`.
- [deploy-build-output-dos-release.ps1](./deploy-build-output-dos-release.ps1) - Copies [../build-artifacts/binaries/Release/DOS/nova.exe](../build-artifacts/binaries/Release/DOS/nova.exe) to `C:\BIRTHRT`.
- [deploy-build-output-dos-debug.ps1](./deploy-build-output-dos-debug.ps1) - Copies [../build-artifacts/binaries/Debug/DOS/nova.exe](../build-artifacts/binaries/Debug/DOS/nova.exe) to `C:\BIRTHRT`.
- [test-all-build-outputs.ps1](./test-all-build-outputs.ps1) - Build-output validation harness for [MAKE.BAT](../MAKE.BAT). Runs all 8 scenario wrappers (WIN95 and DOS default/release/debug/profile), aggregates pass/fail status, and supports continue-on-failure behavior.
- [test-build-output-helper.ps1](./test-build-output-helper.ps1) - Shared scenario runner used by each scenario wrapper. Validates toolchain availability (unless skipped), runs a target [MAKE.BAT](../MAKE.BAT) invocation, verifies expected log markers under `birp-dev\build-artifacts\logs`, and confirms expected output binaries exist.
- [test-build-output-win95-default.ps1](./test-build-output-win95-default.ps1) - Scenario wrapper for WIN95 default install build output validation.
- [test-build-output-win95-release.ps1](./test-build-output-win95-release.ps1) - Scenario wrapper for WIN95 release install build output validation.
- [test-build-output-win95-debug.ps1](./test-build-output-win95-debug.ps1) - Scenario wrapper for WIN95 debug install build output validation.
- [test-build-output-win95-profile.ps1](./test-build-output-win95-profile.ps1) - Scenario wrapper for WIN95 profile install build output validation.
- [test-build-output-dos-default.ps1](./test-build-output-dos-default.ps1) - Scenario wrapper for DOS default install build output validation.
- [test-build-output-dos-release.ps1](./test-build-output-dos-release.ps1) - Scenario wrapper for DOS release install build output validation.
- [test-build-output-dos-debug.ps1](./test-build-output-dos-debug.ps1) - Scenario wrapper for DOS debug install build output validation.
- [test-build-output-dos-profile.ps1](./test-build-output-dos-profile.ps1) - Scenario wrapper for DOS profile install build output validation.
- [MAKE.BAT](../../birp-dev/MAKE.BAT) - The main build script. It uses the active environment variables to determine which toolchain to use, so make sure to run one of the setup scripts first to configure your environment. It also accepts various arguments for controlling the build process, such as target platform, build configuration, and specific components to build. Run `make /?` for usage details.

## Recommended Usage

Run setup with repository defaults:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1`

Create the timestamped packaging archive:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\create-birp-package.ps1`

Deploy the WIN95 release executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-build-output-win95-release.ps1`

Deploy the WIN95 debug executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-build-output-win95-debug.ps1`

Deploy the DOS release executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-build-output-dos-release.ps1`

Deploy the DOS debug executable to `C:\BIRTHRT`:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\deploy-build-output-dos-debug.ps1`

Optional overrides:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\setup-env-vars-for-birthright-preservation-patch.ps1 -Win95DdkRoot "D:\SDKs\Windows95DDK" -DxSdkRoot "D:\SDKs\DirectXSDK"`

Validate that PATH/INCLUDE/LIB were deduplicated:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\check-for-duplicate-env-vars.ps1`

Run MAKE.BAT output smoke tests:

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-build-outputs.ps1`

Run the full MAKE.BAT output suite (continues after failures):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-all-build-outputs.ps1 -ContinueOnFailure`

Run a single scenario (example: WIN95 release):

`powershell -NoProfile -ExecutionPolicy Bypass -File birp-dev\scripts\test-build-output-win95-release.ps1`
