#!/bin/sh

set -e

PROG_NAME=$0
CTAGS_EXE=ctags
CTAGS_ARGS=
TAGS_FILE=tags
PROJECT_ROOT=
LOG_FILE=
FILE_LIST_CMD=
FILE_LIST_CMD_IS_ABSOLUTE=0
UPDATED_SOURCE=
POST_PROCESS_CMD=
PAUSE_BEFORE_EXIT=0


ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=ctags]: The ctags executable to run"
    echo "    -t [file=tags]: The path to the ctags file to update"
    echo "    -p [dir=]:      The path to the project root"
    echo "    -l [file=]:     The path to a log file"
    echo "    -L [cmd=]:      The file list command to run"
    echo "    -A:             Specifies that the file list command returns "
    echo "                    absolute paths"
    echo "    -s [file=]:     The path to the source file that needs updating"
    echo "    -x [pattern=]:  A pattern of files to exclude"
    echo "    -o [options=]:  An options file to read additional options from"
    echo "    -O [params=]:   Parameters to pass to ctags"
    echo "    -P [cmd=]:      Post process command to run on the tags file"
    echo "    -c:             Ask for confirmation before exiting"
    echo ""
}


while getopts "h?e:x:t:p:l:L:s:o:O:P:cA" opt; do
    case $opt in
        h|\?)
            ShowUsage
            exit 0
            ;;
        e)
            CTAGS_EXE=$OPTARG
            ;;
        x)
            CTAGS_ARGS="$CTAGS_ARGS --exclude=$OPTARG"
            ;;
        t)
            TAGS_FILE=$OPTARG
            ;;
        p)
            PROJECT_ROOT=$OPTARG
            ;;
        l)
            LOG_FILE=$OPTARG
            ;;
        L)
            FILE_LIST_CMD=$OPTARG
            ;;
        A)
            FILE_LIST_CMD_IS_ABSOLUTE=1
            ;;
        s)
            UPDATED_SOURCE=$OPTARG
            ;;
        c)
            PAUSE_BEFORE_EXIT=1
            ;;
        o)
            CTAGS_ARGS="$CTAGS_ARGS --options=$OPTARG"
            ;;
        O)
            CTAGS_ARGS="$CTAGS_ARGS $OPTARG"
            ;;
        P)
            POST_PROCESS_CMD=$OPTARG
            ;;
    esac
done

shift $((OPTIND - 1))

if [ "$1" != "" ]; then
    echo "Invalid Argument: $1"
    exit 1
fi

echo "Locking tags file..."
echo $$ > "$TAGS_FILE.lock"

# Remove lock and temp file if script is stopped unexpectedly.
trap 'errorcode=$?; rm -f "$TAGS_FILE.lock" "$TAGS_FILE.files" "$TAGS_FILE.temp"; exit $errorcode' INT QUIT TERM EXIT

INDEX_WHOLE_PROJECT=1
if [ -f "$TAGS_FILE" ]; then
    if [ "$UPDATED_SOURCE" != "" ]; then
        echo "Removing references to: $UPDATED_SOURCE"
        tab="	"
        cmd="grep --text -Ev '^[^$tab]+$tab$UPDATED_SOURCE$tab' '$TAGS_FILE' > '$TAGS_FILE.temp'"
        echo "$cmd"
        eval "$cmd" || true
        INDEX_WHOLE_PROJECT=0
    fi
fi

if [ $INDEX_WHOLE_PROJECT -eq 1 ]; then
    if [ -n "${FILE_LIST_CMD}" ]; then
        if [ "${PROJECT_ROOT}" = "." ] || [ $FILE_LIST_CMD_IS_ABSOLUTE -eq 1 ]; then
            eval $FILE_LIST_CMD > "${TAGS_FILE}.files"
        else
            # If using a tags cache directory, use absolute paths
            eval $FILE_LIST_CMD | while read -r l; do
                echo "${PROJECT_ROOT%/}/${l}"
            done > "${TAGS_FILE}.files"
        fi
        CTAGS_ARGS="${CTAGS_ARGS} -L ${TAGS_FILE}.files"
    fi
    echo "Running ctags on whole project"
    echo "$CTAGS_EXE -f \"$TAGS_FILE.temp\" $CTAGS_ARGS \"$PROJECT_ROOT\""
    $CTAGS_EXE -f "$TAGS_FILE.temp" $CTAGS_ARGS "$PROJECT_ROOT"
else
    echo "Running ctags on \"$UPDATED_SOURCE\""
    echo "$CTAGS_EXE -f \"$TAGS_FILE.temp\" $CTAGS_ARGS --append \"$UPDATED_SOURCE\""
    $CTAGS_EXE -f "$TAGS_FILE.temp" $CTAGS_ARGS --append "$UPDATED_SOURCE"
fi

if [ "$POST_PROCESS_CMD" != "" ]; then
    echo "Running post process"
    echo "$POST_PROCESS_CMD \"$TAGS_FILE.temp\""
    $POST_PROCESS_CMD "$TAGS_FILE.temp"
fi

echo "Replacing tags file"
echo "mv -f \"$TAGS_FILE.temp\" \"$TAGS_FILE\""
mv -f "$TAGS_FILE.temp" "$TAGS_FILE"

echo "Unlocking tags file..."
rm -f "$TAGS_FILE.lock"

echo "Done."

if [ $PAUSE_BEFORE_EXIT -eq 1 ]; then
    printf "Press ENTER to exit..."
    read -r
fi
