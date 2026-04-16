@echo off
rem ---------------------------------------------------------------------------
rem MAKE.BAT
rem
rem Purpose:
rem   Primary build wrapper for this repository.
rem   Runs wmake with standard defaults and always writes a timestamped log.
rem
rem Historical note:
rem   source\MAKE-ORIGINAL.BAT is the script from the recovered/original source.
rem   It is preserved with only minor modifications for reference/compatibility.
rem
rem Usage:
rem   MAKE.BAT [DOS|WIN95] [target] [--debug|--release|--profile] [additional wmake args]
rem
rem Defaults:
rem   DEBUG=ON RELEASE=OFF
rem   target=install when no target is provided
rem   use --debug to force DEBUG=ON RELEASE=OFF
rem   use --release to switch to DEBUG=OFF RELEASE=ON
rem   use --profile to switch to PROFILE=ON
rem   clean-first is always enabled for non-clean targets
rem
rem Logs:
rem   build-artifacts\logs\build-<OS>-<timestamp>.log
rem 
rem Compiled code:
rem   build-artifacts\compiled-code\
rem
rem Compiled binaries:
rem   build-artifacts\binaries\
rem
rem ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion EnableExtensions

set "ROOT_DIR=%~dp0"
set "SOURCE_DIR=%ROOT_DIR%source"
set "BUILD_ARTIFACTS_DIR=%ROOT_DIR%build-artifacts"

if not exist "%SOURCE_DIR%\MAKEFILE" (
    echo Could not find "%SOURCE_DIR%\MAKEFILE".
    echo Ensure source files are located under "%SOURCE_DIR%".
    exit /b 1
)

if "%~1"=="" (
    choice /C:12 /N /M "Press 1 for DOS or 2 for Win95: "
    REM errorlevels must be listed in reverse
    if errorlevel 2 set "OS_TARGET=WIN95"
    if errorlevel 1 set "OS_TARGET=DOS"
) else (
    set "OS_TARGET=%~1"
)

if /I "%OS_TARGET%"=="DOS" (
    set "OS_TARGET=DOS"
) else if /I "%OS_TARGET%"=="WIN95" (
    set "OS_TARGET=WIN95"
) else (
    echo Invalid OS target: %OS_TARGET%
    goto :usage
)

set "BUILD_TARGET=install"
set "BUILD_FLAGS=DEBUG=ON RELEASE=OFF"
set "EXTRA_ARGS="
if not "%~1"=="" shift
:parse_args
if "%~1"=="" goto :after_parse_args

if /I "%~1"=="--release" (
    set "BUILD_FLAGS=DEBUG=OFF RELEASE=ON"
    shift
    goto :parse_args
)

if /I "%~1"=="--debug" (
    set "BUILD_FLAGS=DEBUG=ON RELEASE=OFF"
    shift
    goto :parse_args
)

if /I "%~1"=="--profile" (
    set "BUILD_FLAGS=PROFILE=ON"
    shift
    goto :parse_args
)

set "CURRENT_ARG=%~1"
set "ARG_KEY="
set "ARG_VALUE="
for /f "tokens=1* delims==" %%A in ("!CURRENT_ARG!") do (
    set "ARG_KEY=%%A"
    set "ARG_VALUE=%%B"
)
if defined ARG_VALUE (
    set "EXTRA_ARGS=!EXTRA_ARGS! !CURRENT_ARG!"
    shift
    goto :parse_args
)

set "NEXT_ARG=%~2"
if /I "!NEXT_ARG!"=="ON" (
    set "EXTRA_ARGS=!EXTRA_ARGS! !CURRENT_ARG!=!NEXT_ARG!"
    shift
    shift
    goto :parse_args
)
if /I "!NEXT_ARG!"=="OFF" (
    set "EXTRA_ARGS=!EXTRA_ARGS! !CURRENT_ARG!=!NEXT_ARG!"
    shift
    shift
    goto :parse_args
)

if "%BUILD_TARGET%"=="install" (
    set "BUILD_TARGET=%~1"
) else (
    set "EXTRA_ARGS=!EXTRA_ARGS! %~1"
)

shift
goto :parse_args
:after_parse_args

set "LOG_DIR=%BUILD_ARTIFACTS_DIR%\logs"
if not exist "%BUILD_ARTIFACTS_DIR%" mkdir "%BUILD_ARTIFACTS_DIR%" >nul 2>&1
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

set "STAMP="
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss" 2^>nul') do set "STAMP=%%I"
if not defined STAMP (
    set "STAMP=build"
)

set "LOG_FILE=%LOG_DIR%\build-%OS_TARGET%-%STAMP%.log"
echo Build log: %LOG_FILE%

if /I not "%BUILD_TARGET%"=="clean" (
    echo Running clean step before build...
    pushd "%SOURCE_DIR%" >nul
    wmake -f MAKEFILE OS=%OS_TARGET% %BUILD_FLAGS% clean /l "%LOG_FILE%"
    popd >nul
    set "CLEAN_RC=!ERRORLEVEL!"
    echo Clean step exit code: !CLEAN_RC! >>"%LOG_FILE%"
    if not "!CLEAN_RC!"=="0" (
        echo WARNING: Clean step exited with code !CLEAN_RC! -- continuing build.
    )
)

pushd "%SOURCE_DIR%" >nul
wmake -f MAKEFILE OS=%OS_TARGET% %BUILD_FLAGS% %EXTRA_ARGS% %BUILD_TARGET% /l "%LOG_FILE%"
popd >nul

set "RC=%ERRORLEVEL%"
echo Build exit code: %RC%
echo Build exit code: %RC% >>"%LOG_FILE%"
exit /b %RC%

:usage
echo Usage: MAKE.BAT [DOS^|WIN95] [target] [--debug^|--release^|--profile] [additional wmake args]
echo If OS is omitted, you will be prompted.
echo Add --debug to build with DEBUG=ON RELEASE=OFF.
echo Add --release to build with DEBUG=OFF RELEASE=ON.
echo Add --profile to build with PROFILE=ON.
echo MAKE.BAT always runs clean before non-clean targets.
echo Example: MAKE.BAT WIN95
echo Example: MAKE.BAT WIN95 --debug
echo Example: MAKE.BAT WIN95 clean
echo Example: MAKE.BAT WIN95 --profile
echo Example: MAKE.BAT WIN95 install CHARED=ON
echo Example: MAKE.BAT WIN95 --release
exit /b 1
