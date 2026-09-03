@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "NO_PAUSE=0"
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"
cd /d "%~dp0"
title Vivado WDB Waveform Converter 2.0.1 - Windows Build

echo ============================================================
echo Vivado WDB Waveform Converter 2.0.1
echo Standalone Windows x64 build
echo ============================================================
echo.

if not exist "waveform_converter.py" (
  echo ERROR: waveform_converter.py was not found.
  if "%NO_PAUSE%"=="0" pause
  exit /b 2
)
if not exist "LICENSE" (
  echo ERROR: LICENSE was not found.
  if "%NO_PAUSE%"=="0" pause
  exit /b 2
)

set "PYEXE="
where py >nul 2>nul && set "PYEXE=py -3"
if not defined PYEXE (
  where python >nul 2>nul && set "PYEXE=python"
)
if not defined PYEXE (
  echo ERROR: Python 3.10 or newer is required to build the executable.
  if "%NO_PAUSE%"=="0" pause
  exit /b 2
)

%PYEXE% -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3.10 or newer is required to build the executable.
  if "%NO_PAUSE%"=="0" pause
  exit /b 2
)

echo [1/6] Creating build environment...
if exist ".exe-build-venv" rmdir /s /q ".exe-build-venv"
%PYEXE% -m venv .exe-build-venv
if errorlevel 1 goto :fail
call .exe-build-venv\Scripts\activate.bat

echo [2/6] Installing build dependencies...
python -m pip install --disable-pip-version-check --upgrade pip
if errorlevel 1 goto :fail
python -m pip install --disable-pip-version-check pyinstaller openpyxl
if errorlevel 1 goto :fail

echo [3/6] Checking source...
python -m py_compile waveform_converter.py vcd_converter.py
if errorlevel 1 goto :fail
python waveform_converter.py --version > _version_check.txt 2>&1
if errorlevel 1 goto :fail
findstr /C:"2.0.1" _version_check.txt >nul
if errorlevel 1 (
  echo ERROR: source version check failed.
  type _version_check.txt
  goto :fail
)
del /q _version_check.txt >nul 2>nul

> _version_info.txt echo VSVersionInfo(
>>_version_info.txt echo   ffi=FixedFileInfo(filevers=(2,0,1,0), prodvers=(2,0,1,0), mask=0x3f, flags=0x0, OS=0x40004, fileType=0x1, subtype=0x0, date=(0,0)),
>>_version_info.txt echo   kids=[StringFileInfo([StringTable('040904B0', [
>>_version_info.txt echo     StringStruct('CompanyName', 'Roshan Tripathy'),
>>_version_info.txt echo     StringStruct('FileDescription', 'Vivado WDB Waveform Converter'),
>>_version_info.txt echo     StringStruct('FileVersion', '2.0.1'),
>>_version_info.txt echo     StringStruct('InternalName', 'VivadoWDBWaveformConverter'),
>>_version_info.txt echo     StringStruct('OriginalFilename', 'VivadoWDBWaveformConverter.exe'),
>>_version_info.txt echo     StringStruct('ProductName', 'Vivado WDB Waveform Converter'),
>>_version_info.txt echo     StringStruct('ProductVersion', '2.0.1')
>>_version_info.txt echo   ])]), VarFileInfo([VarStruct('Translation', [1033, 1200])])]
>>_version_info.txt echo )

echo [4/6] Building one-file executable...
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist
if exist VivadoWDBWaveformConverter.spec del /q VivadoWDBWaveformConverter.spec

pyinstaller --noconfirm --clean --onefile --windowed ^
  --name VivadoWDBWaveformConverter ^
  --version-file _version_info.txt ^
  --collect-all openpyxl ^
  --hidden-import tkinter ^
  --hidden-import tkinter.ttk ^
  --hidden-import tkinter.filedialog ^
  --hidden-import tkinter.messagebox ^
  waveform_converter.py
if errorlevel 1 goto :fail

if not exist "dist\VivadoWDBWaveformConverter.exe" (
  echo ERROR: build completed without producing the executable.
  goto :fail
)

echo [5/6] Packaging Windows release...
if exist "release" rmdir /s /q "release"
mkdir "release"
copy /y "dist\VivadoWDBWaveformConverter.exe" "release\VivadoWDBWaveformConverter-v2.0.1.exe" >nul
copy /y "LICENSE" "release\LICENSE.txt" >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='release\VivadoWDBWaveformConverter-v2.0.1.exe';" ^
  "$h=(Get-FileHash -Algorithm SHA256 $p).Hash.ToLower();" ^
  "Set-Content -Encoding ascii 'release\VivadoWDBWaveformConverter-v2.0.1.exe.sha256' ($h+'  VivadoWDBWaveformConverter-v2.0.1.exe');" ^
  "Compress-Archive -Force -Path 'release\VivadoWDBWaveformConverter-v2.0.1.exe','release\VivadoWDBWaveformConverter-v2.0.1.exe.sha256','release\LICENSE.txt' -DestinationPath 'VivadoWDBWaveformConverter-v2.0.1-Windows-x64.zip'"
if errorlevel 1 goto :fail

echo [6/6] Cleaning build files...
call deactivate >nul 2>nul
rmdir /s /q ".exe-build-venv" >nul 2>nul
rmdir /s /q "build" >nul 2>nul
del /q "VivadoWDBWaveformConverter.spec" >nul 2>nul
del /q "_version_info.txt" >nul 2>nul

echo.
echo ============================================================
echo BUILD COMPLETE
echo ============================================================
echo Executable:
echo   %CD%\release\VivadoWDBWaveformConverter-v2.0.1.exe
echo.
echo Release archive:
echo   %CD%\VivadoWDBWaveformConverter-v2.0.1-Windows-x64.zip
echo ============================================================
if "%NO_PAUSE%"=="0" pause
exit /b 0

:fail
echo.
echo ============================================================
echo BUILD FAILED
echo ============================================================
echo Review the error above and run the builder again after correcting it.
echo ============================================================
if "%NO_PAUSE%"=="0" pause
exit /b 1
