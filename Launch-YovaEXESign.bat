@echo off
:: ============================================================
::  Launch-SelfSignedPfxGUI.bat
::  Place this .bat in the same folder as the .ps1 file.
:: ============================================================

setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1_FILE=%SCRIPT_DIR%YovaEXESign.ps1"

if not exist "%PS1_FILE%" (
    echo.
    echo  [ERROR] Cannot find: %PS1_FILE%
    echo  Make sure this .bat is in the same folder as the .ps1 file.
    echo.
    pause
    exit /b 1
)

PowerShell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File "%PS1_FILE%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  [ERROR] PowerShell exited with code %ERRORLEVEL%.
    echo  Try right-clicking and selecting "Run as administrator"
    echo  if you chose the LocalMachine certificate store.
    echo.
    pause
)

endlocal
