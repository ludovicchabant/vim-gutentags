#!/bin/sh

set -e

PROG_NAME=$0
CTAGS_EXE=ctags
CTAGS_ARGS=
TAGS_FILE=tags
UPDATED_SOURCE=
PAUSE_BEFORE_EXIT=0


ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=ctags]: The ctags executable to run"
    echo "    -t [file=tags]: The path to the ctags file to update"
    echo "    -s [file=]:     The path to the source file that needs updating"
    echo "    -x [pattern=]:  A pattern of files to exclude"
    echo ""
}


while getopts "h?e:x:t:s:" opt; do
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
        s)
            UPDATED_SOURCE=$OPTARG
            ;;
        p)
            PAUSE_BEFORE_EXIT=1
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ "$1" -ne "" ]]; then
    echo "Invalid Argument: $1"
    exit 1
fi

echo "Locking tags file..."
echo $$ > "$TAGS_FILE.lock"

if [[ -f "$TAGS_FILE" ]]; then
    if [[ "$UPDATED_SOURCE" != "" ]]; then
        echo "Removing references to: $UPDATED_SOURCE"
        echo "grep -v $UPDATED_SOURCE \"$TAGS_FILE\" > \"$TAGS_FILE.filter\""
        grep -v $UPDATED_SOURCE "$TAGS_FILE" > "$TAGS_FILE.filter"
        mv "$TAGS_FILE.filter" "$TAGS_FILE"
        CTAGS_ARGS="$CTAGS_ARGS --append $UPDATED_SOURCE"
    fi
fi

echo "Running ctags"
echo "$CTAGS_EXE -R -f \"$TAGS_FILE\" $CTAGS_ARGS"
$CTAGS_EXE -R -f "$TAGS_FILE" $CTAGS_ARGS

echo "Unlocking tags file..."
rm -f "$TAGS_FILE.lock"

echo "Done."

if [[ $PAUSE_BEFORE_EXIT -eq 1 ]]; then
    read -p "Press ENTER to exit..."
fi

