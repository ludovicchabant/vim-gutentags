@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================
rem            PARSE ARGUMENTS
rem ==========================================

set CTAGS_EXE=ctags
set CTAGS_ARGS=
set TAGS_FILE=tags
set PROJECT_ROOT=
set FILE_LIST_CMD=
set FILE_LIST_CMD_IS_ABSOLUTE=0
set UPDATED_SOURCE=
set POST_PROCESS_CMD=
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
if [%1]==[-p] (
    set PROJECT_ROOT=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-L] (
    set FILE_LIST_CMD=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-A] (
    set FILE_LIST_CMD_IS_ABSOLUTE=1
    goto :LoopParseArgs
)
if [%1]==[-s] (
    set UPDATED_SOURCE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-c] (
    set PAUSE_BEFORE_EXIT=1
    goto :LoopParseArgs
)
if [%1]==[-l] (
    set LOG_FILE=%~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-o] (
    set CTAGS_ARGS=%CTAGS_ARGS% --options=%2
    shift
    goto :LoopParseArgs
)
if [%1]==[-O] (
    set CTAGS_ARGS=%CTAGS_ARGS% %~2
    shift
    goto :LoopParseArgs
)
if [%1]==[-P] (
    set POST_PROCESS_CMD=%~2
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

if [%LOG_FILE%]==[] set LOG_FILE=CON

echo Locking tags file... > %LOG_FILE%
echo locked > "%TAGS_FILE%.lock"

set INDEX_WHOLE_PROJECT=1
if exist "%TAGS_FILE%" (
    if not ["%UPDATED_SOURCE%"]==[""] (
        echo Removing references to: %UPDATED_SOURCE% >> %LOG_FILE%
        echo findstr /V /C:"%UPDATED_SOURCE%" "%TAGS_FILE%" ^> "%TAGS_FILE%.temp" >> %LOG_FILE%
        findstr /V /C:"%UPDATED_SOURCE%" "%TAGS_FILE%" > "%TAGS_FILE%.temp"
        set CTAGS_ARGS=%CTAGS_ARGS% --append "%UPDATED_SOURCE%"
        set INDEX_WHOLE_PROJECT=0
    )
)
if ["%INDEX_WHOLE_PROJECT%"]==["1"] (
    set CTAGS_ARGS=%CTAGS_ARGS% "%PROJECT_ROOT%"
    if not ["%FILE_LIST_CMD%"]==[""] (
        echo Running custom file lister >> %LOG_FILE%
        set use_raw_list=0
        if ["%PROJECT_ROOT%"]==["."] set use_raw_list=1
        if ["%FILE_LIST_CMD_IS_ABSOLUTE%"]==["1"] set use_raw_list=1
        rem No idea why we need to use delayed expansion here to make it work :(
        if ["!use_raw_list!"]==["1"] (
            echo call %FILE_LIST_CMD% ^> %TAGS_FILE%.files >> %LOG_FILE%
            call %FILE_LIST_CMD% > %TAGS_FILE%.files
        ) else (
            rem Potentially useful:
            rem http://stackoverflow.com/questions/9749071/cmd-iterate-stdin-piped-from-another-command
            echo call %FILE_LIST_CMD% -- with loop for prepending project root >> %LOG_FILE%
            type NUL > %TAGS_FILE%.files
            for /F "usebackq delims=" %%F in (`%FILE_LIST_CMD%`) do @echo %PROJECT_ROOT%\%%F >> %TAGS_FILE%.files
        )
        set CTAGS_ARGS=%CTAGS_ARGS% -L %TAGS_FILE%.files
    )
)

echo Running ctags >> %LOG_FILE%
echo call "%CTAGS_EXE%" -f "%TAGS_FILE%.temp" %CTAGS_ARGS% >> %LOG_FILE%
call "%CTAGS_EXE%" -f "%TAGS_FILE%.temp" %CTAGS_ARGS% >> %LOG_FILE% 2>&1
if ERRORLEVEL 1 (
    echo ERROR: Ctags executable returned non-zero code. >> %LOG_FILE%
    goto :Unlock
)

if not ["%POST_PROCESS_CMD%"]==[""] (
    echo Running post process >> %LOG_FILE%
    echo call %POST_PROCESS_CMD% %TAGS_FILE%.temp >> %LOG_FILE%
    call %POST_PROCESS_CMD% %TAGS_FILE%.temp >> %LOG_FILE% 2>&1
    if ERRORLEVEL 1 (
        echo ERROR: Post process returned non-zero code. >> %LOG_FILE%
        goto :Unlock
    )
)

echo Replacing tags file >> %LOG_FILE%
echo move /Y "%TAGS_FILE%.temp" "%TAGS_FILE%" >> %LOG_FILE%
move /Y "%TAGS_FILE%.temp" "%TAGS_FILE%" >> %LOG_FILE% 2>&1
if ERRORLEVEL 1 (
    echo ERROR: Unable to rename temp tags file into actual tags file. >> %LOG_FILE%
    goto :Unlock
)

:Unlock
echo Unlocking tags file... >> %LOG_FILE%
del /F "%TAGS_FILE%.files" "%TAGS_FILE%.lock"
if ERRORLEVEL 1 (
    echo ERROR: Unable to remove file lock. >> %LOG_FILE%
)

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
echo    -p [dir=]:      The path to the project root
echo    -L [cmd=]:      The file list command to run
echo    -A:             Specifies that the file list command returns
echo                    absolute paths
echo    -s [file=]:     The path to the source file that needs updating
echo    -l [log=]:      The log file to output to
echo    -o [options=]:  An options file to read additional options from
echo    -c:             Ask for confirmation before exiting
echo.

