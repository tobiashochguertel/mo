#!/usr/bin/env bash
# apply_patches.sh — apply all .patch files in alphabetical order
#
# Used by the sync workflow after merging upstream.
# Each patch is applied with `git apply` and checked for idempotency.
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "$0")/.." && pwd)/patches"

if [ ! -d "$PATCH_DIR" ]; then
    echo "No patches directory found at $PATCH_DIR"
    exit 0
fi

PATCHES=$(find "$PATCH_DIR" -name '*.patch' | sort)

if [ -z "$PATCHES" ]; then
    echo "No .patch files found"
    exit 0
fi

FAILED=0
for patch in $PATCHES; do
    name=$(basename "$patch")
    echo "Applying $name..."

    # Check if already applied (reverse check)
    if git apply --reverse --check "$patch" 2>/dev/null; then
        echo "  Already applied — skipping"
        continue
    fi

    # Apply
    if git apply --check "$patch" 2>/dev/null && git apply "$patch"; then
        echo "  Applied successfully"
    else
        echo "  FAILED to apply"
        FAILED=$((FAILED + 1))
    fi
done

if [ "$FAILED" -gt 0 ]; then
    echo "$FAILED patch(es) failed to apply"
    exit 1
fi

echo "All patches applied"
