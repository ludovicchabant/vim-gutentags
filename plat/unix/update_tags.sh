#!/bin/sh

set -e

PROG_NAME=$0
CTAGS_EXE=ctags
CTAGS_ARGS=
TAGS_FILE=tags
PROJECT_ROOT=
UPDATED_SOURCE=
PAUSE_BEFORE_EXIT=0
RECURSIVE_FLAG="-R"


ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=ctags]: The ctags executable to run"
    echo "    -t [file=tags]: The path to the ctags file to update"
    echo "    -p [dir=]:      The path to the project root"
    echo "    -s [file=]:     The path to the source file that needs updating"
    echo "    -x [pattern=]:  A pattern of files to exclude"
    echo "    -o [options=]:  An options file to read additional options from" 
    echo "    -c:             Ask for confirmation before exiting"
    echo ""
}


while getopts "h?e:x:t:p:s:o:c" opt; do
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
        s)
            UPDATED_SOURCE=$OPTARG
            ;;
        c)
            PAUSE_BEFORE_EXIT=1
            ;;
        o)
            CTAGS_ARGS="$CTAGS_ARGS --options=$OPTARG"
            # No recursive flag when options file is present.
            RECURSIVE_FLAG=""
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
trap "errorcode=$?; rm -f \"$TAGS_FILE.lock\" \"$TAGS_FILE.temp\"; exit $errorcode" INT TERM EXIT

if [ -f "$TAGS_FILE" ]; then
    if [ "$UPDATED_SOURCE" != "" ]; then
        echo "Removing references to: $UPDATED_SOURCE"
        echo "grep -v "$UPDATED_SOURCE" \"$TAGS_FILE\" > \"$TAGS_FILE.temp\""
        grep -v "$UPDATED_SOURCE" "$TAGS_FILE" > "$TAGS_FILE.temp"
        CTAGS_ARGS="$CTAGS_ARGS --append \"$UPDATED_SOURCE\""
    fi
fi

echo "Running ctags"
echo "$CTAGS_EXE -f \"$TAGS_FILE.temp\" $RECURSIVE_FLAG $CTAGS_ARGS \"$PROJECT_ROOT\""
$CTAGS_EXE -f "$TAGS_FILE.temp" $RECURSIVE_FLAG $CTAGS_ARGS "$PROJECT_ROOT"

echo "Replacing tags file"
echo "mv -f \"$TAGS_FILE.temp\" \"$TAGS_FILE\""
mv -f "$TAGS_FILE.temp" "$TAGS_FILE"

echo "Unlocking tags file..."
rm -f "$TAGS_FILE.lock"

echo "Done."

if [ $PAUSE_BEFORE_EXIT -eq 1 ]; then
    read -p "Press ENTER to exit..."
fi

