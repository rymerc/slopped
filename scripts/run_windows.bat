@echo off
rem Double-click to play. Pass -Editor, -HostGame, or -Join <ip> for other modes.
powershell -ExecutionPolicy Bypass -File "%~dp0run_windows.ps1" %*
