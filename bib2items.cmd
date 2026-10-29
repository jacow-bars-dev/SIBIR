@echo off
setlocal
set "paper=%~1"
if not defined paper set "paper=."

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Extract-Bibitems.ps1" -PaperPath "%paper%"
if errorlevel 1 goto failed
echo.
echo Copy and review the complete extraction block in Adobe Acrobat before continuing.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inject-Bibitems.ps1" -PaperPath "%paper%"
if errorlevel 1 goto failed
echo.
echo Review and compile the generated -final-bibitems.tex paper.
pause
endlocal
exit /b 0

:failed
echo.
echo SIBIR stopped. Read the error above, correct the issue, and run it again.
pause
endlocal
exit /b 1
