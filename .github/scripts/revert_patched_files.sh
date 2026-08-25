#!/usr/bin/env bash
# revert_patched_files.sh — revert patched files to upstream version
#
# Used by the sync workflow before merging upstream.
# This ensures patched files are clean so the merge doesn't conflict.
set -euo pipefail

# PATCHED_FILES: space-separated list of files that are modified by patches.
# Only list files that exist in upstream (not new files).
PATCHED_FILES="${PATCHED_FILES:-internal/server/server.go}"

if [ -z "$PATCHED_FILES" ]; then
    echo "No patched files to revert"
    exit 0
fi

for file in $PATCHED_FILES; do
    if [ -f "$file" ]; then
        echo "Reverting $file to HEAD..."
        git checkout HEAD -- "$file"
    fi
done

echo "All patched files reverted"
