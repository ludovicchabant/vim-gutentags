#!/usr/bin/env bash

set -e

PROG_NAME=$0
GTAGS_EXE=gtags
FILE_LIST_CMD=

ShowUsage() {
    echo "Usage:"
    echo "    $PROG_NAME <options>"
    echo ""
    echo "    -e [exe=gtags]:       The gtags executable to run."
    echo "    -L [cmd=]:            The file list command to run."
    echo ""
}

while [[ $# -ne 0 ]]; do
  case "$1" in
    -h)
      ShowUsage
      exit 0
      ;;
    -e)
      GTAGS_EXE=$2
      shift 2
      ;;
    -L)
      FILE_LIST_CMD=$2
      shift 2
      ;;
    *)
      GTAGS_ARGS="$GTAGS_ARGS $1"
      shift
      ;;
  esac
done

if [ -n "$FILE_LIST_CMD" ]; then
  CMD="$FILE_LIST_CMD | $GTAGS_EXE -f- $GTAGS_ARGS"
else
  CMD="$GTAGS_EXE $GTAGS_ARGS"
fi

echo "Running gtags:"
echo "$CMD"
eval "$CMD"
echo "Done."
