# Fork Strategy

This fork of [k1LoW/mo](https://github.com/k1LoW/mo) uses a
**revert-then-repatch** strategy to stay mergeable with upstream while
maintaining custom patches.

## Branch Model

| Branch | Tracks | Purpose |
|--------|--------|---------|
| `main` | Latest upstream release tag | Stable — well-tested patches only |
| `dev.patch` | `upstream/main` (latest dev) | Unstable — experimental patches welcome |
| `feature/*` | Branched from `dev.patch` | Feature development (merged back when stable) |

**Always branch from `dev.patch`**, never from `main`.

## Revert-Then-Repatch

1. **Daily sync** (`sync-upstream-and-fix.yml` at 07:00 UTC):
   - Reverts all `PATCHED_FILES` to upstream's version
   - Merges upstream (fails loudly on non-patched file conflicts)
   - Re-applies all `.patch` files in alphabetical order
   - Commits and pushes

2. **Why not `--strategy-option=theirs`?** It silently drops custom changes.
   Revert-then-repatch guarantees patches are always re-applied and fails
   loudly if upstream changed surrounding code.

## Patch Files

Patches live in `.github/patches/` and are applied in alphabetical order.

| # | Patch | Files |
|---|-------|-------|
| 001 | cross-platform path separator | `internal/server/server.go` |

## PATCHED_FILES

Files modified by patches (must exist in upstream). Listed in:
- `.github/workflows/sync-upstream-and-fix.yml` — `PATCHED_FILES` env var
- `.github/scripts/revert_patched_files.sh` — default value

Only list **modified files**. New files don't need reverting.

## Adding a New Patch

```bash
# 1. Branch from dev.patch
git checkout dev.patch
git checkout -b feature/my-fix

# 2. Make changes, commit on feature branch
# ... edit files ...

# 3. Generate patch (modified upstream files only)
MERGE_BASE=$(git merge-base feature/my-fix dev.patch)
git diff "$MERGE_BASE"..feature/my-fix -- <modified-files> \
    > .github/patches/NNN-description.patch

# 4. Test
git checkout dev.patch
git apply --check .github/patches/NNN-description.patch
git apply .github/patches/NNN-description.patch
git apply --reverse --check .github/patches/NNN-description.patch

# 5. Commit patch + changes
git add .github/patches/NNN-description.patch
git commit -m "feat: integrate <description> via .patch"

# 6. Add modified files to PATCHED_FILES in:
#    - .github/workflows/sync-upstream-and-fix.yml
#    - .github/scripts/revert_patched_files.sh

# 7. Clean up feature branch
git branch -d feature/my-fix
```

## Rules

1. **Always branch from `dev.patch`**
2. **Never edit upstream files directly on `dev.patch`** — use `.patch` files
3. **New files don't need patches** — commit them directly
4. **Test patches before committing** — `git apply --check` + idempotency
5. **Add modified files to `PATCHED_FILES`**
6. **One logical change per `.patch` file**
7. **Name patches with zero-padded numbers** — `NNN-description.patch`
