@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================
rem            PARSE ARGUMENTS
rem ==========================================

set CSCOPE_EXE=cscope
set DB_FILE=cscope.out

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
echo Invalid Argument: %1
goto :Usage

:LoopParseArgs
shift
goto :ParseArgs

:DoneParseArgs


rem ==========================================
rem             GENERATE DATABASE
rem ==========================================

echo Locking db file
echo locked > "%DB_FILE%.lock"

echo Running cscope
"%CSCOPE_EXE%" -R -b -k -f "%DB_FILE%"
if ERRORLEVEL 1 (
    echo ERROR: Cscope executable returned non-zero code.
)

echo Unlocking db file
del /F "%DB_FILE%.lock"
if ERRORLEVEL 1 (
    echo ERROR: Unable to remove file lock.
)

echo Done.

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
echo.

