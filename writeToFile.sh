#!/bin/bash

# --- Configuration ---
# Default directory is current directory
DEFAULT_DIR="."
# Default output file name
DEFAULT_OUTPUT_FILE="out.log"

# --- Argument Parsing ---
DIR="${1:-$DEFAULT_DIR}"
OUTPUT_FILE="${2:-$DEFAULT_OUTPUT_FILE}"

# --- Pre-checks ---
# Resolve the directory path to an absolute, canonical path (no trailing slash unless root)
# The '-s' avoids resolving symlinks for the final component, use '-m' if you need full canonical physical paths
if ! DIR_REAL=$(realpath -s "$DIR"); then
    echo "Error: Failed to resolve path for '$DIR'." >&2
    exit 1
fi

# Check if the resolved directory exists
if [ ! -d "$DIR_REAL" ]; then
    echo "Error: Directory '$DIR_REAL' (resolved from '$DIR') does not exist!" >&2
    exit 1
fi

# --- Initialization ---
# Clear the output file before writing
> "$OUTPUT_FILE"
echo "Starting log process for directory: $DIR_REAL" | tee -a "$OUTPUT_FILE"
echo "Output will be written to: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"

# Use counters to track progress
files_processed=0
files_skipped=0
files_found=0

# --- Main Processing Loop ---
# Use find with -print0 and process substitution with read -d $'\0'
# This is the safest way to handle filenames with special characters (spaces, newlines, etc.)
while IFS= read -r -d $'\0' file; do
    files_found=$((files_found + 1))
    # Calculate relative path based on the resolved directory path
    RELATIVE_PATH="${file#"$DIR_REAL"/}"
    # Handle the case where the file is directly in the DIR_REAL (no subdirectory)
    if [[ "$file" == "$DIR_REAL/"* ]]; then
         RELATIVE_PATH="${file#"$DIR_REAL"/}"
    else
        # If file path doesn't start with DIR_REAL/, it might be the directory itself (e.g. if DIR=".")
        # In this case, the relative path is just the filename part.
        # This case shouldn't happen with '-type f' starting from DIR_REAL, but being safe.
        RELATIVE_PATH=$(basename "$file")
        # A more robust relative path might use other tools if needed, but this covers common cases.
    fi


    # Check file type using MIME type
    # '-b' prevents printing the filename itself
    mime_type=$(file -b --mime-type "$file")

    # Log content only for text files or handle empty files
    if [[ "$mime_type" == text/* ]]; then
        echo -e "\n===== File: $RELATIVE_PATH =====\n" >> "$OUTPUT_FILE"
        # Attempt to cat the file; redirect cat's stderr to /dev/null and check exit status
        if cat "$file" >> "$OUTPUT_FILE" 2>/dev/null; then
             : # Successfully cat'ed
        else
            echo "[Error reading file content for $RELATIVE_PATH]" >> "$OUTPUT_FILE"
        fi
        echo -e "\n========================\n" >> "$OUTPUT_FILE"
        files_processed=$((files_processed + 1))
    elif [[ "$mime_type" == inode/x-empty ]]; then
        echo -e "\n===== File: $RELATIVE_PATH (Empty) =====\n" >> "$OUTPUT_FILE"
        echo "[File is empty]" >> "$OUTPUT_FILE"
        echo -e "\n========================\n" >> "$OUTPUT_FILE"
        files_processed=$((files_processed + 1)) # Count empty files as processed
    else
        # Skip non-text files but log that they were skipped
        echo -e "\n===== Skipping non-text file: $RELATIVE_PATH (Type: $mime_type) =====\n" >> "$OUTPUT_FILE"
        files_skipped=$((files_skipped + 1))
    fi

done < <(find "$DIR_REAL" -type f -print0 2>/dev/null) # Find files, print null-separated, redirect find errors

# --- Final Summary ---
echo "---" >> "$OUTPUT_FILE"
echo "Log process finished." | tee -a "$OUTPUT_FILE"

if [ "$files_found" -eq 0 ]; then
    echo "No files found in directory '$DIR_REAL'." | tee -a "$OUTPUT_FILE"
else
    summary="Found $files_found file(s): $files_processed file(s) content logged, $files_skipped file(s) skipped (non-text)."
    echo "$summary" | tee -a "$OUTPUT_FILE"
    echo "Full log written to: $OUTPUT_FILE"
fi

exit 0