#!/bin/sh

set -e

PROG_NAME=$0
PYCSCOPE_EXE=pycscope
PYCSCOPE_ARGS=
DB_FILE=pycscope.out
# Note that we keep the same name
PROJECT_ROOT=
FILE_LIST_CMD=

ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=pycscope]:      The pycscope executable to run"
    echo "    -f [file=pycscope.out]: The path to the ctags file to update"
    echo "    -p [dir=]:            The path to the project root"
    echo "    -L [cmd=]:            The file list command to run"
    echo ""
}


while getopts "h?e:f:p:L:" opt; do
    case $opt in
        h|\?)
            ShowUsage
            exit 0
            ;;
        e)
            PYCSCOPE_EXE=$OPTARG
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
    esac
done

shift $((OPTIND - 1))

if [ "$1" != "" ]; then
    echo "Invalid Argument: $1"
    exit 1
fi

echo "Locking pycscope DB file..."
echo $$ > "$DB_FILE.lock"

# Remove lock and temp file if script is stopped unexpectedly.
trap 'rm -f "$DB_FILE.lock" "$DB_FILE.files" "$DB_FILE.temp"' INT QUIT TERM EXIT

PREVIOUS_DIR=$(pwd)
if [ -d "$PROJECT_ROOT" ]; then
    cd "$PROJECT_ROOT"
fi

if [ -n "${FILE_LIST_CMD}" ]; then
    if [ "${PROJECT_ROOT}" = "." ]; then
        eval "$FILE_LIST_CMD" > "${DB_FILE}.files"
    else
        # If using a tags cache directory, use absolute paths
        eval "$FILE_LIST_CMD" | while read -r l; do
            echo "${PROJECT_ROOT%/}/${l}"
        done > "${DB_FILE}.files"
    fi
else
    find . -type f > "${DB_FILE}.files"
fi
PYCSCOPE_ARGS="${PYCSCOPE_ARGS} -i ${DB_FILE}.files"

echo "Running pycscope"
echo "$PYCSCOPE_EXE -f \"$DB_FILE.temp\" "$PYCSCOPE_ARGS
"$PYCSCOPE_EXE" -f "$DB_FILE.temp" $PYCSCOPE_ARGS

if [ -d "$PROJECT_ROOT" ]; then
    cd "$PREVIOUS_DIR"
fi

echo "Replacing pycscope DB file"
echo "mv -f \"$DB_FILE.temp\" \"$DB_FILE\""
mv -f "$DB_FILE.temp" "$DB_FILE"

echo "Unlocking pycscope DB file..."
rm -f "$DB_FILE.lock"

echo "Done."
