#!/bin/sh

set -e

PROG_NAME=$0
CTAGS_EXE=ctags
CTAGS_ARGS=
TAGS_FILE=tags
PROJECT_ROOT=
FILE_LIST_CMD=
UPDATED_SOURCE=
PAUSE_BEFORE_EXIT=0


ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=ctags]: The ctags executable to run"
    echo "    -t [file=tags]: The path to the ctags file to update"
    echo "    -p [dir=]:      The path to the project root"
    echo "    -L [cmd=]:      The file list command to run"
    echo "    -s [file=]:     The path to the source file that needs updating"
    echo "    -x [pattern=]:  A pattern of files to exclude"
    echo "    -o [options=]:  An options file to read additional options from"
    echo "    -c:             Ask for confirmation before exiting"
    echo ""
}


while getopts "h?e:x:t:p:L:s:o:c" opt; do
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
        L)
            FILE_LIST_CMD=$OPTARG
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
        if [ "${PROJECT_ROOT}" = "." ]; then
            $FILE_LIST_CMD > "${TAGS_FILE}.files"
        else
            # If using a tags cache directory, use absolute paths
            $FILE_LIST_CMD | while read -r l; do
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
