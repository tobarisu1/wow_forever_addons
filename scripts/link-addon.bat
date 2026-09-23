@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "DEFAULT_CLIENT=_classic_beta_"
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "REPO_ROOT=%CD%"
popd
set "INCLUDE_SKIPPED=0"
set "TARGET="

:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="-h" goto :usage
if "%~1"=="--help" goto :usage
if /I "%~1"=="--all" (
	set "INCLUDE_SKIPPED=1"
	shift
	goto :parse_args
)
if not "%TARGET%"=="" goto :usage
set "TARGET=%~1"
shift
goto :parse_args

:args_done
if not defined WOW_ROOT (
	set "WOW_ROOT=%ProgramFiles(x86)%\World of Warcraft"
	if not exist "%WOW_ROOT%" set "WOW_ROOT=%ProgramFiles%\World of Warcraft"
)

if "%TARGET%"=="" (
	set "TARGET=%DEFAULT_CLIENT%"
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
set "SKIPPED=0"
for /d %%D in ("%REPO_ROOT%\*") do (
	if exist "%%D\%%~nxD.toc" (
		call :maybe_copy "%%D" "%ADDONS_DIR%\%%~nxD"
		if errorlevel 1 exit /b 1
	)
)

if %LINKED%==0 if %SKIPPED%==0 (
	echo No addon folders found in %REPO_ROOT% ^(expected FolderName\FolderName.toc^)
	exit /b 1
)

echo AddOns path: %ADDONS_DIR%
echo.
echo Copied %LINKED% addon^(s^). Re-run this after editing, since the client now has
echo its own copy. Fully restart WoW if the game is open.
exit /b 0

:usage
echo Usage: %~nx0 [--all] [client-folder-or-addons-path]
echo Copies each addon in as a real folder. Linked addons load their Lua but the
echo client never reads back their SavedVariables.
echo Default: %WOW_ROOT%\%DEFAULT_CLIENT%\Interface\AddOns
echo By default BagMaster and SplitChat are not copied ^(and are removed from
echo AddOns if a previous copy is there^). Pass --all to include them.
echo Examples:
echo   %~nx0
echo   %~nx0 --all
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

:maybe_copy
set "SRC=%~1"
set "DEST=%~2"
set "NAME=%~nx1"
if "%INCLUDE_SKIPPED%"=="0" (
	if /I "%NAME%"=="BagMaster" goto :skip_one
	if /I "%NAME%"=="SplitChat" goto :skip_one
)
call :link_one "%SRC%" "%DEST%"
if errorlevel 1 exit /b 1
set /a LINKED+=1
exit /b 0

:skip_one
if exist "%DEST%" (
	rmdir /s /q "%DEST%"
	echo Skipped %NAME% ^(removed from AddOns^). Pass --all to copy.
) else (
	echo Skipped %NAME%. Pass --all to copy.
)
set /a SKIPPED+=1
exit /b 0

:link_one
set "SRC=%~1"
set "DEST=%~2"
set "NAME=%~nx1"
rem Remove a junction or symlink left by an older version of this script. A linked
rem addon folder loads its Lua normally but the client does not read its
rem SavedVariables back, so saved data silently resets on every login.
for %%L in ("%DEST%") do if exist "%DEST%" (
	dir /al /b "%DEST%\.." 2>nul | findstr /I /X "%NAME%" >nul && rmdir "%DEST%" 2>nul
)
rem /MIR mirrors the folder so files deleted from the repo also leave the client.
robocopy "%SRC%" "%DEST%" /MIR /NFL /NDL /NJH /NJS /NP /XD .git /XF .gitignore >nul
if errorlevel 8 (
	echo Failed to copy %NAME% to %DEST%.
	exit /b 1
)
echo Copied %NAME% -^> %DEST%
exit /b 0
