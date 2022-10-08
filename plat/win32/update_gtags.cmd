@echo off

setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================
rem PARSE ARGUMENTS
rem ==========================================
set "GTAGS_EXE=gtags"
set "GTAGS_ARGS="
set "FILE_LIST_CMD="

if [%1]==[] goto :Usage

:ParseArgs
if [%1]==[] goto :DoneParseArgs
if [%1]==[-e] (
	set GTAGS_EXE=%~2
	shift /1
	shift /1
	goto :ParseArgs
)
if [%1]==[-L] (
	set FILE_LIST_CMD=%~2
	shift /1
	shift /1
	goto :ParseArgs
)
set "GTAGS_ARGS=%GTAGS_ARGS% %1"
shift /1
goto :ParseArgs

:DoneParseArgs
rem ==========================================
rem GENERATE GTAGS
rem ==========================================
set "GTAGS_CMD=%GTAGS_EXE% %GTAGS_ARGS%"
if /i not "%FILE_LIST_CMD%"=="" (
	set "GTAGS_CMD=%FILE_LIST_CMD% | %GTAGS_EXE% -f- %GTAGS_ARGS%"
)
echo Running gtags:
echo "%GTAGS_CMD%"
call %GTAGS_CMD%
echo Done.
goto :EOF
rem ==========================================
rem USAGE
rem ==========================================

:Usage
echo Usage:
echo %~n0 ^<options^>
echo.
echo -e [exe=gtags]: The gtags executable to run.
echo -L [cmd=]: The file list command to run
echo.

