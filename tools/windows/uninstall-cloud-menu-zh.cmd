@echo off
rem Restore: remove the zh-CN MUI added by this optional tool and restart Explorer.
setlocal
chcp 936 >nul
if /i "%~1"=="elevated" goto run
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList 'elevated'" >nul 2>&1
  exit /b
)
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cloud-menu-zh.ps1" -Uninstall
pause
