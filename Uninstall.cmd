@echo off
setlocal
echo This removes the BricsCAD V26 edition shortcuts and their generated icons.
choice /M "Continue"
if errorlevel 2 exit /b 0

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-BricsCAD-V26-Shortcuts.ps1"
if errorlevel 1 (
  echo.
  echo Uninstallation failed. See the error above.
  pause
  exit /b 1
)
echo.
echo Uninstallation complete.
pause
