#!/bin/sh

set -e

PROG_NAME=$0
CSCOPE_EXE=cscope
CSCOPE_ARGS=
DB_FILE=cscope.out
PROJECT_ROOT=
FILE_LIST_CMD=
BUILD_INVERTED_INDEX=0

ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=cscope]:      The cscope executable to run"
    echo "    -f [file=cscope.out]: The path to the ctags file to update"
    echo "    -p [dir=]:            The path to the project root"
    echo "    -L [cmd=]:            The file list command to run"
    echo "    -I:                   Builds an inverted index"
    echo ""
}


while getopts "h?e:f:p:L:I" opt; do
    case $opt in
        h|\?)
            ShowUsage
            exit 0
            ;;
        e)
            CSCOPE_EXE=$OPTARG
            ;;
        f)
            DB_FILE=$OPTARG
            ;;
        p)
            PROJECT_ROOT=$OPTARG
            ;;
        L)
            FILE_LIST_CMD=$OPTARG
            ;;
        I)
            BUILD_INVERTED_INDEX=1
            ;;
    esac
done

shift $((OPTIND - 1))

if [ "$1" != "" ]; then
    echo "Invalid Argument: $1"
    exit 1
fi

echo "Locking cscope DB file..."
echo $$ > "$DB_FILE.lock"

# Remove lock and temp file if script is stopped unexpectedly.
CleanUp() {
    rm -f "$DB_FILE.lock" "$DB_FILE.files" "$DB_FILE.temp"
    if [ "$BUILD_INVERTED_INDEX" -eq 1 ]; then
        rm -f "$DB_FILE.temp.in" "$DB_FILE.temp.po"
    fi
}

trap CleanUp INT QUIT TERM EXIT

PREVIOUS_DIR=$(pwd)
if [ -d "$PROJECT_ROOT" ]; then
    cd "$PROJECT_ROOT"
fi

if [ -n "${FILE_LIST_CMD}" ]; then
    if [ "${PROJECT_ROOT}" = "." ]; then
        eval "$FILE_LIST_CMD" | while read -r l; do
            echo "\"${l}\""
        done > "${DB_FILE}.files"
    else
        # If using a tags cache directory, use absolute paths
        eval "$FILE_LIST_CMD" | while read -r l; do
            echo "\"${PROJECT_ROOT%/}/${l}\""
        done > "${DB_FILE}.files"
    fi
else
    find . -type f ! -name ${DB_FILE} | while read -r l; do
        echo "\"${l}\""
    done > "${DB_FILE}.files"
fi

if [ ! -s "${DB_FILE}.files" ]; then
    echo "There is no files to generate cscope DB"
    exit
fi

CSCOPE_ARGS="${CSCOPE_ARGS} -i ${DB_FILE}.files"

if [ "$BUILD_INVERTED_INDEX" -eq 1 ]; then
    CSCOPE_ARGS="$CSCOPE_ARGS -q"
fi

echo "Running cscope"
echo "$CSCOPE_EXE $CSCOPE_ARGS -b -k -f \"$DB_FILE.temp\""
"$CSCOPE_EXE" $CSCOPE_ARGS -v -b -k -f "$DB_FILE.temp"

if [ -d "$PROJECT_ROOT" ]; then
    cd "$PREVIOUS_DIR"
fi

echo "Replacing cscope DB file"
if [ "$BUILD_INVERTED_INDEX" -eq 1 ]; then
    echo "mv -f \"$DB_FILE.temp.in\" \"$DB_FILE.in\""
    mv -f "$DB_FILE.temp.in" "$DB_FILE.in"
    echo "mv -f \"$DB_FILE.temp.po\" \"$DB_FILE.po\""
    mv -f "$DB_FILE.temp.po" "$DB_FILE.po"
fi
echo "mv -f \"$DB_FILE.temp\" \"$DB_FILE\""
mv -f "$DB_FILE.temp" "$DB_FILE"

echo "Unlocking cscope DB file..."
rm -f "$DB_FILE.lock"

echo "Done."
