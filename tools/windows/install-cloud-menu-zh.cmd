@echo off
rem Optional: localize Windows Explorer cloud-files context menu (Windows component).
rem This modifies a Windows system resource file (adds a zh-CN MUI). Needs admin.
setlocal
chcp 936 >nul
if /i "%~1"=="elevated" goto run
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList 'elevated'" >nul 2>&1
  exit /b
)
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cloud-menu-zh.ps1" -Install
pause
