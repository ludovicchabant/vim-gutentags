#!/bin/sh

set -e

PROG_NAME=$0
CSCOPE_EXE=cscope
CSCOPE_ARGS=
DB_FILE=cscope.out
PROJECT_ROOT=
FILE_LIST_CMD=

ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=cscope]:      The cscope executable to run"
    echo "    -f [file=cscope.out]: The path to the ctags file to update"
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
trap 'rm -f "$DB_FILE.lock" "$DB_FILE.files" "$DB_FILE.temp"' INT QUIT TERM EXIT

PREVIOUS_DIR=$(pwd)
if [ -d "$PROJECT_ROOT" ]; then
    cd "$PROJECT_ROOT"
fi

if [ -n "${FILE_LIST_CMD}" ]; then
    if [ "${PROJECT_ROOT}" = "." ]; then
        $FILE_LIST_CMD > "${DB_FILE}.files"
    else
        # If using a tags cache directory, use absolute paths
        $FILE_LIST_CMD | while read -r l; do
            echo "${PROJECT_ROOT%/}/${l}"
        done > "${DB_FILE}.files"
    fi
else
    find . -type f > "${DB_FILE}.files"
fi
CSCOPE_ARGS="${CSCOPE_ARGS} -i ${DB_FILE}.files"

echo "Running cscope"
echo "$CSCOPE_EXE $CSCOPE_ARGS -b -k -f \"$DB_FILE.temp\""
"$CSCOPE_EXE" $CSCOPE_ARGS -v -b -k -f "$DB_FILE.temp"

if [ -d "$PROJECT_ROOT" ]; then
    cd "$PREVIOUS_DIR"
fi

echo "Replacing cscope DB file"
echo "mv -f \"$DB_FILE.temp\" \"$DB_FILE\""
mv -f "$DB_FILE.temp" "$DB_FILE"

echo "Unlocking cscope DB file..."
rm -f "$DB_FILE.lock"

echo "Done."
