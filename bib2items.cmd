@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Extract-Bibitems.ps1"
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inject-Bibitems.ps1"

endlocal