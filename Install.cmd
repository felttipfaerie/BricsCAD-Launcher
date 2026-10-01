@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-BricsCAD-V26-Shortcuts.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. See the error above.
  pause
  exit /b 1
)
echo.
echo Installation complete.
pause
