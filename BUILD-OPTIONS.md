# Build Options Reference

This document lists the available build options for `MAKE.BAT` and `source/MAKEFILE`.

## Scope and precedence

- [MAKE.BAT](./MAKE.BAT) is the primary wrapper and defines defaults.
- [source/MAKEFILE](./source/MAKEFILE) provides the full macro and target surface.
- Wrapper arguments are forwarded to `wmake` in the [Open Watcom v2.0](../birp-dependencies/OPENWATCOM-v2_0/) dependency after wrapper-set defaults.

Command shape:

- `MAKE.BAT [DOS|WIN95] [target] [--release|--profile] [additional wmake macros/args]`
- `MAKE.BAT [DOS|WIN95] [target] [--debug|--release|--profile] [additional wmake macros/args]`

## Build target/OS options

- `WIN95`: Builds the Windows executable (`nova95.exe`) and uses Win32/DirectX build settings.
- `DOS`: Builds the DOS executable (`nova.exe`) and uses DOS toolchain/link settings.

## Build mode options

- Release mode via `--release`: `DEBUG=OFF RELEASE=ON`
  - Enables optimized production settings and `_RELEASE` define.

- Debug mode via `--debug`: `DEBUG=ON RELEASE=OFF`
  - Forces debug-oriented compiler/link options.
  - Enables memory/vector check defines in makefile (`MEMORY_CHK`, `_VECTOR_CHK`).

- Profile mode via `--profile`: `PROFILE=ON`
  - Selects makefile profiling configuration and profiling output directories.
  - Haven't tested this.

- Default mode (when no mode switch is provided): `DEBUG=ON RELEASE=OFF`

## Build feature flag options

These build feature flags (set these as additional macro arguments, for example `MAKE.BAT WIN95 install CHARED=ON`) are ones we use sometimes:

- Always enabled (not configurable):
  - `_RANDLOG`
  - `_LOGCOMMENT`

- `CHARED=ON`
  - Adds `_CHARED` define.
  - Changes main output target from game EXE to `chared.exe`.
  - Uses CHARED resource/compiler variants and object output subfolder.

These options exist but have not been tested, use with caution:

- `FRENCH=ON`
  - Adds `_FRENCHVER` and `_FOREIGNVER` defines.
  - Switches text/input localization behavior for French build variants.

- `GERMAN=ON`
  - Adds `_GERMANVER` and `_FOREIGNVER` defines.
  - Switches text/input localization behavior for German build variants.

- `DEMO=ON`
  - Adds `_DEMO` define for demo-limited gameplay/UI flows.

- `NETDEMO=ON`
  - Adds `_NETDEMO` define for network demo behaviors.

- `JUNEDEMO=ON`
  - Adds `_JUNEDEMO` define for June demo behavior gates.

- `NETJUNEDEMO=ON`
  - Adds `_JUNEDEMO` and `_NETJUNEDEMO` defines.

- `MULTIPLAY=ON`
  - Adds `_MULTIPLAY_ONLY` define.
  - Also changes resource compiler flags to `_MULTIPLAY_ONLY`.

- `CRCCHECK=ON`
  - Adds `CRC_CHK` define for resource CRC checking paths.

- `STATUS=ON`
  - Adds `_STATUS` define for additional status/debug code paths compiled behind this macro.

- `WADBUILDERS=ON`
  - Adds `_WADBUILDERS` define for editor/wad-builder related code paths.

- `DEBUGLINK=ON`
  - Forces production linker settings to include debug/map/symbol options.

- `PREPROCESS` (any non-empty value)
  - Switches compile rules to preprocessing-oriented options (`-pcl`) instead of normal object generation tuning.

- `LIBRARIES="..."`
  - Overrides default linker libraries assembled by makefile.

## Build type options

User-facing targets:

- `install`
  - Main build target.
  - Builds required dependencies, ensures output dirs exist, and links final executable.
- `clean`
  - Cleans objects and target output files for the current active configuration.
- `clean_all`
  - Cleans objects and binaries across DOS/WIN95 and debug/release/profiling dirs.

Convenience wrappers (equivalent compositions):

- `CleanCompile` = `clean` + `install`
- `CleanAllCompile` = `clean_all` + `install`

Internal dependency targets (normally reached through `install`):

- `SyncWinResources`
  - WIN95-only copy of cursor/icon resources into local `source/RES`.
- `CleanVersion`
  - Deletes `version.obj` so version prompts/changes are not hidden by stale objects.
- `PrepareBuildDirs`
  - Creates current object, binary, and log directories under `../build-artifacts/` if missing.
  - Stages SOLAUDIO source and headers under `../build-artifacts/SOLAUDIO/`.
  - Stages top-level resource files under `../build-artifacts/RES/`.
  - Rebuilds SOLAUDIO libs from staged sources under `../build-artifacts/SOLAUDIO/LIB/...`.
  - Links game targets against the staged SOLAUDIO libraries.

Optional or legacy utility targets:

- `CreateBrowser`
  - Browser DB target hook; depends on browser database rules that are currently commented out in makefile.
- `CleanBrowser`
  - Removes browser `.mbr` files.
- `MakeDirs`
  - Creates a broad set of output directories for multiple configurations.
  - Mostly superseded in normal flow by `PrepareBuildDirs`.

Direct executable targets in the makefile:

- `$(BIND)/nova.exe`: DOS game executable link target.
- `$(BIND)/nova95.exe`: WIN95 game executable link target.
- `$(BIND)/chared.exe`: Character editor executable link target (`CHARED=ON`).

## Wrapper behavior options

Wrapper switches:

- `--release`
  - Sets `DEBUG=OFF RELEASE=ON`.
- `--debug`
  - Sets `DEBUG=ON RELEASE=OFF`.
- `--profile`
  - Sets `PROFILE=ON`.

Wrapper behavior:

- If OS is omitted, wrapper prompts for DOS or WIN95.
- If target is omitted, default target is `install`.
- Any argument in `KEY=VALUE` form is treated as a passthrough make macro argument, not as a target.
- For compatibility with cmd.exe/batch tokenization, split `KEY VALUE` pairs where `VALUE` is `ON` or `OFF` are normalized to `KEY=VALUE`.
- Clean-first always runs and executes `clean` unless requested target is `clean`.
- Additional arguments are passed through to `wmake` after wrapper arguments are parsed.
- The wrapper forwards passthrough macro arguments before the final target so `KEY=VALUE` is consistently interpreted as a macro assignment.

## Common invocations

- `MAKE.BAT WIN95`
- `MAKE.BAT WIN95 --release`
- `MAKE.BAT WIN95 --debug`
- `MAKE.BAT WIN95 --profile`
- `MAKE.BAT DOS`
- `MAKE.BAT DOS` `--release`
- `MAKE.BAT DOS --debug`
- `MAKE.BAT DOS --profile`

## Notes

- Not every flag combination is meaningful.
- Some combinations are mutually incompatible or produce specialized builds intended for specific workflows.
- For broad validation, use a constrained test matrix rather than full combinatorial expansion.
