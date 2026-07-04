@echo off
rem ===========================================================================
rem  BirP Issue Report
rem  ---------------------------------------------------------------------------
rem  Double-click this file to create a diagnostic .zip you can send to the BirP
rem  developers. It only reads files -- it does not change your game or saves.
rem
rem  This launcher simply runs the PowerShell script next to it. You can open
rem  "BirP-Issue-Report.ps1" in Notepad to see exactly what it does.
rem ===========================================================================
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BirP-Issue-Report.ps1"

if errorlevel 1 (
    echo.
    echo There was a problem creating the report. Please see the message above.
    echo.
    pause
)

endlocal
