@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Create-DesktopShortcut.ps1"
if errorlevel 1 goto failed
pause
endlocal
exit /b 0

:failed
echo.
echo SIBIR could not create the desktop shortcut. Read the error above.
pause
endlocal
exit /b 1
