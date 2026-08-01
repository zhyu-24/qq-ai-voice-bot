@echo off
chcp 65001 >nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\Setup-Center.ps1"
set "SetupCenterExitCode=%ERRORLEVEL%"
if not "%SetupCenterExitCode%"=="0" (
  echo.
  echo 配置中心异常退出，退出码：%SetupCenterExitCode%
  echo 上方内容可用于排查；按任意键关闭此窗口。
  pause >nul
)
exit /b %SetupCenterExitCode%
