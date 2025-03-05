#!/bin/bash

# Ensure a directory is provided
DIR="${1:-.}"
OUTPUT_FILE="${2:-output.txt}"

# Clear the output file before writing
> "$OUTPUT_FILE"

# Check if the directory exists
if [ ! -d "$DIR" ]; then
    echo "Error: Directory '$DIR' does not exist!" >&2
    exit 1
fi

# Find all files inside the directory (recursively)
FILES_FOUND=$(find "$DIR" -type f 2>/dev/null | wc -l)

# If no files are found, log a message and exit
if [ "$FILES_FOUND" -eq 0 ]; then
    echo "No files found in directory '$DIR'." | tee -a "$OUTPUT_FILE"
    exit 0
fi

# Process each file found
find "$DIR" -type f 2>/dev/null | while read -r file; do
    RELATIVE_PATH="${file#"$DIR"/}"  # Remove base path for cleaner output
    echo -e "\n===== File: $RELATIVE_PATH =====\n" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo -e "\n========================\n" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
done

echo "File contents written to: $OUTPUT_FILE"
