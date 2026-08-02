@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\Setup-Center.ps1"
set "SetupCenterExitCode=%ERRORLEVEL%"
if not "%SetupCenterExitCode%"=="0" (
  echo.
  echo Setup Center exited abnormally. Exit code: %SetupCenterExitCode%
  echo The output above can be used for troubleshooting.
  echo Press any key to close this window.
  pause >nul
)
exit /b %SetupCenterExitCode%
