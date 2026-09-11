@echo off
setlocal
title Dixit Motors Management App - Windows Release Build

cd /d "%~dp0"

echo.
echo ============================================================
echo   DIXIT MOTORS MANAGEMENT APP - WINDOWS RELEASE BUILDER
echo ============================================================
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: Flutter was not found in PATH.
  echo Open a new PowerShell/Command Prompt after installing/configuring Flutter.
  pause
  exit /b 1
)

echo [1/5] Closing any running Dixit Motors app...
taskkill /F /IM dixit_motors_management_app.exe >nul 2>&1

echo [2/5] Getting packages...
call flutter pub get
if errorlevel 1 goto :failed

echo [3/5] Formatting Dart source...
call dart format lib
if errorlevel 1 goto :failed

echo [4/5] Checking project...
call flutter analyze
if errorlevel 1 goto :failed

echo [5/5] Building Windows RELEASE...
call flutter build windows --release
if errorlevel 1 goto :failed

echo.
echo ============================================================
echo BUILD SUCCESSFUL
echo ============================================================
echo EXE:
echo %CD%\build\windows\x64\runner\Release\dixit_motors_management_app.exe
echo.
echo The complete Release folder is:
echo %CD%\build\windows\x64\runner\Release\
echo.
echo You can copy that entire Release folder to the laptop.
echo ============================================================
pause
exit /b 0

:failed
echo.
echo ============================================================
echo BUILD STOPPED - an actual Flutter/Dart error was reported.
echo The error above is the exact error to fix.
echo ============================================================
pause
exit /b 1
