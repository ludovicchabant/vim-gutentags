@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================
rem            PARSE ARGUMENTS
rem ==========================================

set CTAGS_EXE=ctags
set CTAGS_ARGS=
set TAGS_FILE=tags
set UPDATED_SOURCE=
set PAUSE_BEFORE_EXIT=0
set LOG_FILE=

:ParseArgs
if [%1]==[] goto :DoneParseArgs
if [%1]==[-e] (
    set CTAGS_EXE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-x] (
    set CTAGS_ARGS=%CTAGS_ARGS% --exclude=%2
    shift
    goto :LoopParseArgs
)
if [%1]==[-t] (
    set TAGS_FILE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-s] (
    set UPDATED_SOURCE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-p] (
    set PAUSE_BEFORE_EXIT=1
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
rem               GENERATE TAGS
rem ==========================================

set CTAGS_ARGS=
if [%LOG_FILE%]==[] set LOG_FILE=CON

echo Locking tags file... > %LOG_FILE%
echo locked > "%TAGS_FILE%.lock"

if exist "%TAGS_FILE%" (
    if not [%UPDATED_SOURCE%]==[] (
        echo Removing references to: %UPDATED_SOURCE% >> %LOG_FILE%
        echo type "%TAGS_FILE%" ^| findstr /V /C:"%UPDATED_SOURCE%" ^> "%TAGS_FILE%.filter" >> %LOG_FILE%
        findstr /V /C:"%UPDATED_SOURCE%" "%TAGS_FILE%" > "%TAGS_FILE%.filter"
        echo move /Y "%TAGS_FILE%.filter" "%TAGS_FILE%" >> %LOG_FILE%
        move /Y "%TAGS_FILE%.filter" "%TAGS_FILE%"
        set CTAGS_ARGS=--append %UPDATED_SOURCE%
    )
)

echo Running ctags >> %LOG_FILE%
echo "%CTAGS_EXE%" -R -f "%TAGS_FILE%" %CTAGS_ARGS% >> %LOG_FILE%
"%CTAGS_EXE%" -R -f "%TAGS_FILE%" %CTAGS_ARGS%

echo Unlocking tags file... >> %LOG_FILE%
del /F "%TAGS_FILE%.lock"

echo Done. >> %LOG_FILE%
if [%PAUSE_BEFORE_EXIT%]==[1] (
    pause
)

goto :EOF


rem ==========================================
rem                 USAGE
rem ==========================================

:Usage
echo Usage:
echo    %~n0 ^<options^>
echo.
echo    -e [exe=ctags]: The ctags executable to run
echo    -t [file=tags]: The path to the ctags file to update
echo    -s [file=]:     The path to the source file that needs updating
echo    -l [log=]:      The log file to output to
echo.

