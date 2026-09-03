@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  echo Drag a .vcd, .wdb, or .wcfg file onto this BAT.
  pause
  exit /b 1
)
where py >nul 2>nul
if %errorlevel%==0 (set "PY=py -3") else (set "PY=python")
%PY% waveform_converter.py %* --signals
pause
