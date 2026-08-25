#!/usr/bin/env bash
# revert_patched_files.sh — revert patched files to upstream version
#
# Used by the sync workflow before merging upstream.
# This ensures patched files are clean so the merge doesn't conflict.
#
# Usage: revert_patched_files.sh <upstream_sha> <merge_ref>
set -euo pipefail

UPSTREAM_SHA="${1:?Usage: revert_patched_files.sh <upstream_sha> <merge_ref>}"
MERGE_REF="${2:?}"

# PATCHED_FILES: space-separated list of files that are modified by patches.
# Only list files that exist in upstream (not new files).
PATCHED_FILES="${PATCHED_FILES:-internal/server/server.go}"

if [ -z "$PATCHED_FILES" ]; then
    echo "No patched files to revert"
    exit 0
fi

for file in $PATCHED_FILES; do
    if [ -f "$file" ]; then
        echo "Reverting $file to upstream $MERGE_REF"
        git checkout "$UPSTREAM_SHA" -- "$file" 2>/dev/null || {
            echo "⚠️  $file not found in upstream — it may have been removed or renamed"
        }
    fi
done

git commit -m "chore: revert patched files to upstream $MERGE_REF before merge [skip ci]" 2>/dev/null || true

echo "All patched files reverted"
