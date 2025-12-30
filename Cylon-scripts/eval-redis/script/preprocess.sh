#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <input_file> ../raw/<dirname> <log_name>"
    echo "Example: $0 logdata.txt zipfian-local 1t"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found!"
    exit 1
fi

mkdir -p "../raw/$2"

READ_LOG="../raw/$2/$3-read.log"
CLEAN_LOG="../raw/$2/$3-clean.log"

> "$READ_LOG"
> "$CLEAN_LOG"

echo "Processing $INPUT_FILE..."
echo "Extracting READ operations..."
grep "^READ," "$INPUT_FILE" | cut -d',' -f2,3 >> "$READ_LOG"
echo "Extracting CLEANUP operations..."
grep "^CLEANUP," "$INPUT_FILE" | cut -d',' -f2,3 >> "$CLEAN_LOG"

READ_COUNT=$(wc -l < "$READ_LOG")
CLEAN_COUNT=$(wc -l < "$CLEAN_LOG")

echo "Done!"
echo "READ operations: $READ_COUNT entries -> $READ_LOG"
echo "CLEANUP operations: $CLEAN_COUNT entries -> $CLEAN_LOG"
echo ""
echo "Sample READ entries:"
head -5 "$READ_LOG"
echo ""
echo "Sample CLEANUP entries:"
head -5 "$CLEAN_LOG"
