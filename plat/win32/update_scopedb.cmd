@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================
rem            PARSE ARGUMENTS
rem ==========================================

set CSCOPE_EXE=cscope
set CSCOPE_ARGS=
set DB_FILE=cscope.out
set FILE_LIST_CMD=
set LOG_FILE=

:ParseArgs
if [%1]==[] goto :DoneParseArgs
if [%1]==[-e] (
    set CSCOPE_EXE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-f] (
    set DB_FILE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-p] (
    set PROJ_ROOT=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-L] (
    set FILE_LIST_CMD=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-l] (
    set LOG_FILE=%~2
    shift
    goto :LoopParseArgs
)
echo Invalid Argument: %1
goto :Usage

:LoopParseArgs
shift
goto :ParseArgs

:DoneParseArgs


rem ==========================================
rem             GENERATE DATABASE
rem ==========================================

if [%LOG_FILE%]==[] set LOG_FILE=CON

echo Locking db file > %LOG_FILE%
echo locked > "%DB_FILE%.lock"

echo Running cscope >> %LOG_FILE%
if NOT ["%FILE_LIST_CMD%"]==[""] (
    if ["%PROJECT_ROOT%"]==["."] (
        call %FILE_LIST_CMD% > %DB_FILE%.files
    ) else (
        rem Potentially useful:
        rem http://stackoverflow.com/questions/9749071/cmd-iterate-stdin-piped-from-another-command
        %FILE_LIST_CMD% | for /F "usebackq delims=" %%F in (`findstr "."`) do @echo %PROJECT_ROOT%\%%F > %DB_FILE%.files
    )
    set CSCOPE_ARGS=%CSCOPE_ARGS% -i %TAGS_FILE%.files
) ELSE (
    set CSCOPE_ARGS=%CSCOPE_ARGS% -R
)
"%CSCOPE_EXE%" %CSCOPE_ARGS% -b -k -f "%DB_FILE%"
if ERRORLEVEL 1 (
    echo ERROR: Cscope executable returned non-zero code. >> %LOG_FILE%
)

echo Unlocking db file >> %LOG_FILE%
del /F "%DB_FILE%.files" "%DB_FILE%.lock"
if ERRORLEVEL 1 (
    echo ERROR: Unable to remove file lock. >> %LOG_FILE%
)

echo Done. >> %LOG_FILE%

goto :EOF


rem ==========================================
rem                 USAGE
rem ==========================================

:Usage
echo Usage:
echo    %~n0 ^<options^>
echo.
echo    -e [exe=cscope]:     The cscope executable to run
echo    -f [file=scope.out]: The path to the database file to create
echo    -p [dir=]:           The path to the project root
echo    -L [cmd=]:           The file list command to run
echo    -l [log=]:           The log file to output to
echo.

