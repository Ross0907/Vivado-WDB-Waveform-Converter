@echo off
setlocal
cd /d "%~dp0"

if "%~1"=="" (
  if exist "VivadoWaveformConverter.exe" (
    start "" "VivadoWaveformConverter.exe"
    exit /b 0
  )
)

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py -3"
) else (
  where python >nul 2>nul
  if not %errorlevel%==0 (
    echo ERROR: Python 3.10 or newer was not found.
    echo Install standard Python for Windows with the Python Launcher enabled.
    pause
    exit /b 2
  )
  set "PY=python"
)

if "%~1"=="" (
  %PY% waveform_converter.py --gui
  exit /b %errorlevel%
)

%PY% waveform_converter.py %*
set "RC=%errorlevel%"
if not "%RC%"=="0" pause
exit /b %RC%
