#!/bin/sh

set -e

PROG_NAME=$0
CSCOPE_EXE=cscope
DB_FILE=cscope.out
PROJECT_ROOT=

ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=cscope]:      The cscope executable to run"
    echo "    -f [file=cscope.out]: The path to the ctags file to update"
    echo "    -p [dir=]:            The path to the project root"
    echo ""
}


while getopts "h?e:f:p:" opt; do
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
trap "rm -f \"$DB_FILE.lock\" \"$DB_FILE.temp\"" 0 3 4 15

PREVIOUS_DIR=$(pwd)
if [ -d "$PROJECT_ROOT" ]; then
    cd "$PROJECT_ROOT"
fi

echo "Running cscope"
echo "$CSCOPE_EXE -R -b -k -f \"$DB_FILE.temp\""
"$CSCOPE_EXE" -R -v -b -k -f "$DB_FILE.temp"

if [ -d "$PROJECT_ROOT" ]; then
    cd "$PREVIOUS_DIR"
fi

echo "Replacing cscope DB file"
echo "mv -f \"$DB_FILE.temp\" \"$DB_FILE\""
mv -f "$DB_FILE.temp" "$DB_FILE"

echo "Unlocking cscope DB file..."
rm -f "$DB_FILE.lock"

echo "Done."
