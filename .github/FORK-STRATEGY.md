# Fork Maintenance Strategy

This fork of [k1LoW/mo](https://github.com/k1LoW/mo) is kept
mergeable with upstream using a **revert-then-repatch** strategy.

## Branch model

| Branch | Tracks | Purpose |
|--------|--------|---------|
| `main` | Latest upstream release tag (e.g. `v1.6.7`) | Stable — well-tested patches only |
| `dev.patch` | `upstream/main` (latest development) | Unstable — experimental patches welcome |

## What lives where

### Source patches (in this repo)

Actual changes to upstream source files. Each patch has:

1. **A `.patch` file** in `.github/patches/` (named `NNN-description.patch`)
2. **An entry in `PATCHED_FILES`** in the sync workflow env var (modified files only — new files don't need listing)

Patches are applied by `.github/scripts/apply_patches.sh`, which loops over
all `.patch` files in `.github/patches/` in alphabetical order.

Current patches:

| Patch | Patch file | Files | Branch |
|-------|-----------|-------|--------|
| cross-platform path separator | `001-cross-platform-path-separator.patch` | `internal/server/server.go` | `main` + `dev.patch` |

## How the sync works

The `sync-upstream-and-fix.yml` workflow runs daily at 07:00 UTC (or manually).
It syncs both branches in parallel — `main` from the latest upstream release
tag, `dev.patch` from `upstream/main`.

### The revert-then-repatch sequence

For each branch, the workflow executes these steps:

```bash
# 1. Fetch upstream
git remote add upstream https://github.com/k1LoW/mo.git
git fetch upstream --tags --quiet

# 2. Determine what to merge
#    main:       latest upstream release tag (e.g. v1.6.7)
#    dev.patch:  upstream/main

# 3. Skip if already up to date
git merge-base --is-ancestor "$UPSTREAM_SHA" HEAD  # → nothing to do

# 4. Revert all PATCHED_FILES to upstream's version, then commit
.github/scripts/revert_patched_files.sh "$UPSTREAM_SHA" "$MERGE_REF"

# 5. Merge upstream (normal merge, no strategy override)
git merge "$MERGE_REF" --no-edit -m "chore: merge upstream …"
#    If this conflicts on non-patched files → FAIL LOUDLY

# 6. Re-apply all patches via apply_patches.sh
.github/scripts/apply_patches.sh

# 7. Commit the re-applied patches
git add internal/
git commit -m "fix: re-apply custom patches after upstream merge …"

# 8. Push
git push origin <branch>
```

### Why revert-then-repatch instead of `--strategy-option=theirs`?

`--strategy-option=theirs` silently lets upstream overwrite custom patches.
The revert-then-repatch approach:

- **Guarantees patches are always re-applied** on the latest upstream code
- **Fails loudly** if upstream changed the surrounding code (`git apply` fails)
- **Fails loudly** if there are conflicts on files we don't patch
- **Never silently drops** a custom change

### Helper scripts

| Script | Purpose |
|--------|---------|
| `.github/scripts/revert_patched_files.sh` | Checks out each `PATCHED_FILES` entry from the upstream SHA, commits the revert |
| `.github/scripts/apply_patches.sh` | Loops over `.github/patches/*.patch`, applies each with idempotency check |
| `.github/scripts/validate-patches.py` | Validates all patches: applies cleanly OR already applied, idempotent, modified files in PATCHED_FILES |

## Adding a new patch

### 1. Branch from dev.patch and make changes

```bash
git checkout dev.patch
git checkout -b feature/my-fix
# ... edit files ...
git commit -m "fix: my fix"
```

### 2. Generate the `.patch` file

```bash
MERGE_BASE=$(git merge-base feature/my-fix dev.patch)
git diff "$MERGE_BASE"..feature/my-fix -- <modified-files-only> \
    > .github/patches/NNN-description.patch
```

### 3. Test the patch

```bash
git checkout dev.patch
git apply --check .github/patches/NNN-description.patch
git apply .github/patches/NNN-description.patch
git apply --reverse --check .github/patches/NNN-description.patch

# Validate with the script
uv run .github/scripts/validate-patches.py --repo . --verbose
```

### 4. Add modified files to `PATCHED_FILES`

In `.github/workflows/sync-upstream-and-fix.yml`, add each **modified** file
to the `PATCHED_FILES` env var:

```yaml
env:
  PATCHED_FILES: |
    internal/server/server.go
    path/to/new/modified/file.go   # ← add here
```

### 5. Update the workflow commit message

Add the new patch to the "Commit patches" step message and the summary step.

### 6. Commit and push

```bash
git add -A
git commit -m "feat: integrate <description> via .patch"
git push origin dev.patch
```

## Rules

- **Never edit upstream files directly** — always via a `.patch` file
- **Never use `--strategy-option=theirs`** — it silently drops changes
- **Keep patches minimal** — one logical change per `.patch` file
- **Name patches with zero-padded numbers** — `NNN-description.patch` (applied in alphabetical order)
- **Only list modified files in `PATCHED_FILES`** — new files don't need reverting
- **Test locally** before pushing: `git apply --check`, `go build ./...`
- **Verify idempotency** — `git apply --reverse --check` must pass
