@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "DEFAULT_CLIENT=_classic_beta_"
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "REPO_ROOT=%CD%"
popd

if not defined WOW_ROOT (
	set "WOW_ROOT=%ProgramFiles(x86)%\World of Warcraft"
	if not exist "%WOW_ROOT%" set "WOW_ROOT=%ProgramFiles%\World of Warcraft"
)

if "%~1"=="-h" goto :usage
if "%~1"=="--help" goto :usage
if not "%~2"=="" goto :usage

if "%~1"=="" (
	set "TARGET=%DEFAULT_CLIENT%"
) else (
	set "TARGET=%~1"
)

call :ends_with_addons "%TARGET%"
if "!IS_ADDONS!"=="1" (
	set "ADDONS_DIR=%TARGET%"
	for %%P in ("%TARGET%\..\..") do set "CLIENT_DIR=%%~fP"
) else (
	echo %TARGET%| findstr ":" >nul
	if not errorlevel 1 (
		set "CLIENT_DIR=%TARGET%"
	) else (
		set "CLIENT_DIR=%WOW_ROOT%\%TARGET%"
	)
	set "ADDONS_DIR=!CLIENT_DIR!\Interface\AddOns"
)

if not exist "%CLIENT_DIR%\" (
	echo Client folder not found: %CLIENT_DIR%
	call :list_clients
	exit /b 1
)

if not exist "%ADDONS_DIR%\" mkdir "%ADDONS_DIR%"

set "LINKED=0"
for /d %%D in ("%REPO_ROOT%\*") do (
	if exist "%%D\%%~nxD.toc" (
		call :link_one "%%D" "%ADDONS_DIR%\%%~nxD"
		if errorlevel 1 exit /b 1
		set /a LINKED+=1
	)
)

if %LINKED%==0 (
	echo No addon folders found in %REPO_ROOT% ^(expected FolderName\FolderName.toc^)
	exit /b 1
)

echo AddOns path: %ADDONS_DIR%
exit /b 0

:usage
echo Usage: %~nx0 [client-folder-or-addons-path]
echo Default: %WOW_ROOT%\%DEFAULT_CLIENT%\Interface\AddOns
echo Examples:
echo   %~nx0
echo   %~nx0 %DEFAULT_CLIENT%
echo   %~nx0 "%WOW_ROOT%\%DEFAULT_CLIENT%\Interface\AddOns"
echo   set WOW_ROOT=D:\Games\World of Warcraft
echo   %~nx0
exit /b 1

:list_clients
echo Client folders in %WOW_ROOT%:
set "FOUND=0"
for /d %%D in ("%WOW_ROOT%\_*") do (
	echo   %%~nxD
	set "FOUND=1"
)
if "!FOUND!"=="0" echo   ^(none found^)
exit /b 0

:ends_with_addons
set "IS_ADDONS=0"
set "CHECK=%~1"
if /I "!CHECK:~-15!"=="Interface\AddOns" set "IS_ADDONS=1"
if /I "!CHECK:~-16!"=="Interface\AddOns\" set "IS_ADDONS=1"
exit /b 0

:link_one
set "SRC=%~1"
set "DEST=%~2"
set "NAME=%~nx1"
if exist "%DEST%" (
	rmdir "%DEST%" 2>nul
	if exist "%DEST%" (
		echo Cannot replace existing folder: %DEST%
		echo Move it aside, then run this script again.
		exit /b 1
	)
)
mklink /J "%DEST%" "%SRC%" >nul 2>&1
if not errorlevel 1 (
	echo Linked %NAME% -^> %DEST%
	exit /b 0
)
mklink /D "%DEST%" "%SRC%" >nul 2>&1
if not errorlevel 1 (
	echo Linked %NAME% -^> %DEST%
	exit /b 0
)
echo Failed to link %NAME%.
echo Run Command Prompt as Administrator, or enable Developer Mode:
echo Settings ^> System ^> For developers ^> Developer Mode
exit /b 1
