@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================
rem            PARSE ARGUMENTS
rem ==========================================

set GTAGS_EXE=gtags
set GTAGS_ARGS=%~4
set INCREMENTAL=

:ParseArgs
if [%1]==[] goto :DoneParseArgs
if [%1]==[-e] (
    set GTAGS_EXE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[--incremental] (
    set INCREMENTAL=--incremental
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

echo Running gtags:
echo call %GTAGS_EXE% %INCREMENTAL% %GTAGS_ARGS%
call %GTAGS_EXE% %INCREMENTAL% %GTAGS_ARGS%
echo Done.

goto :EOF


rem ==========================================
rem                 USAGE
rem ==========================================

:Usage
echo Usage:
echo    %~n0 ^<options^>
echo.
echo    -e [exe=gtags]: The gtags executable to run.
echo    -L [cmd=]:      The file list command to run
echo.

