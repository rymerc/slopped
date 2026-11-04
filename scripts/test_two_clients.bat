@echo off
rem Local multiplayer test: one host (with 2 bots) + one client on this PC.
start "" powershell -ExecutionPolicy Bypass -File "%~dp0run_windows.ps1" -HostGame -Bots 2
timeout /t 4 >nul
start "" powershell -ExecutionPolicy Bypass -File "%~dp0run_windows.ps1" -Join 127.0.0.1
