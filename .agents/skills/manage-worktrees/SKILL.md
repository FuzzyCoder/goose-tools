---
name: manage-worktrees
description: Create, navigate, and manage git worktrees using native git worktree commands. Use when creating, listing, or removing git worktrees; setting up linked worktrees for feature branches; or pruning stale worktree metadata. Not for committing/pushing across worktrees (use sync-worktrees skill instead).
---

# Manage Git Worktrees

## When to Use
- Creating, navigating, or removing git worktrees in any git repository
- Setting up branch-aligned worktrees for parallel feature development
- Pruning stale worktree metadata after directory removal
- Not for committing/pushing across worktrees (use `sync-worktrees` skill instead)

## Quick Start

```bash
git worktree list                        # list all worktrees
git worktree add ../<branch> <branch>    # create worktree for existing branch
git worktree add -b <branch> ../<branch> # create worktree with new branch
git worktree remove <path>               # remove a clean worktree
git worktree prune                       # prune stale metadata
```

## Overview

A **branch-aligned worktree model** gives each branch its own directory, enabling true
parallel development without stashing or switching branches:

```text
<repo-parent>/
  main/           ← primary worktree (or wherever the repo was cloned)
  feature-a/      ← linked worktree
  feature-b/      ← linked worktree
  hotfix-123/     ← linked worktree
```

All linked worktrees share the same `.git` object store. Commits in one worktree are
immediately visible to others.

---

## Inspect Worktrees

**List all worktrees:**

```bash
git --no-pager worktree list
```

**Detailed view with HEAD and branch info:**

```bash
git --no-pager worktree list --porcelain
```

**Check status across all worktrees** (run from any worktree in the repo):

```bash
# Manually inspect each worktree path from worktree list
for wt in $(git --no-pager worktree list --porcelain | grep "^worktree " | awk '{print $2}'); do
  echo "=== $wt ==="
  git --no-pager -C "$wt" status --short
done
```

---

## Create Worktrees

### New branch from current HEAD

```bash
git worktree add -b <branch-name> ../<branch-name>
```

### New branch from a specific base

```bash
git worktree add -b <branch-name> ../<branch-name> main
git worktree add -b <branch-name> ../<branch-name> origin/main
```

### Existing local branch

```bash
git worktree add ../<branch-name> <branch-name>
```

### Remote-only branch (creates a local tracking branch)

```bash
git fetch origin
git worktree add ../<branch-name> origin/<branch-name>
```

### Manual post-creation setup

After creating any worktree, run the following from within it:

```bash
cd ../<branch-name>

# Copy environment config from primary worktree (if applicable)
cp ../main/.envrc .envrc    # adapt path as needed
cp ../main/.env .env        # if secrets file exists

# Sync the locked virtualenv (uv-managed projects)
uv sync --locked
```

---

## Remove Worktrees

**Safe removal — checks for uncommitted changes:**

```bash
git worktree remove ../<branch-name>
```

If the worktree has uncommitted work, commit or stash it first:

```bash
git -C ../<branch-name> status                         # review uncommitted changes
git -C ../<branch-name> stash push -m "pre-removal"    # or commit
git worktree remove ../<branch-name>                   # now safe to remove
```

### Force / Complete Removal

`git worktree remove --force` will fail with **"Directory not empty"** when the
worktree contains gitignored files (e.g., `.venv/`, build artifacts, log files).
When this error occurs, git has **already deregistered** the worktree from its internal
metadata. The directory just needs manual deletion.

**Step-by-step complete removal:**

```bash
# 1. Deregister from git (may print "Directory not empty" — that's OK)
git --no-pager worktree remove --force /path/to/worktree/<branch-name>

# 2. Verify git no longer tracks it
git --no-pager worktree list

# 3. Remove the physical directory
#    On macOS, .venv may have immutable flags — clear them first if rm -rf fails
chflags -R nouchg /path/to/worktree/<branch-name> 2>/dev/null || true
rm -rf /path/to/worktree/<branch-name>

# 4. Prune any remaining stale metadata
git --no-pager worktree prune -v
```

**To also delete the branches (full cleanup):**

```bash
# Delete local branch
git --no-pager branch -D <branch-name>

# Delete remote branch
git --no-pager push origin --delete <branch-name>
```

> **Note:** `rm -rf` on a worktree directory is safe **only after** git has deregistered it
> (step 1 above). Running `rm -rf` before that leaves orphaned `.git/worktrees/<name>/`
> metadata and blocks future creation with the same name.

---

## Sync and Rebase

After upstream changes land, bring a feature branch up to date:

```bash
git --no-pager fetch origin
git -C ../<branch-name> rebase origin/main    # or the appropriate base branch
uv sync --locked                               # required: lockfile may have changed
```

`uv sync --locked` is always needed after a rebase because the `uv.lock` file may differ
between branches.

> **Automated full-repo sync**: Use the `sync-worktrees` skill to commit, push, integrate,
> and rebase all worktrees in a single autonomous run.

---

## Prune Metadata

**Clean up stale worktree metadata:**

```bash
git --no-pager worktree prune -v
```

Run after a worktree directory has been removed by other means, or when
`git worktree list` shows entries for directories that no longer exist.

---

## Safety Warnings

⚠️ **Never `rm -rf` a worktree directory without first deregistering it from git**

- Always create with `git worktree add`
- For clean worktrees: use `git worktree remove`
- For worktrees with gitignored files: use `git worktree remove --force` first, then `rm -rf`
  (see "Force / Complete Removal" above)
- Skipping git deregistration leaves `.git/worktrees/<name>/` metadata orphaned,
  causing stale entries in `git worktree list` and blocking future creation with the same name

⚠️ **Check for uncommitted changes before removal**

- Run `git -C <path> status --short` to verify the worktree is clean
- Commit or stash any work in progress before removing

⚠️ **Optional-group detection for uv sync after rebase**

When the project uses uv optional dependency groups (e.g., `[tool.uv] optional-dependencies`
or `[dependency-groups]`), bare `uv sync --locked` syncs only default groups and silently
removes any optional groups that were previously installed. Before running `uv sync --locked`:

1. Read `pyproject.toml` `[dependency-groups]` to identify declared groups
2. Build the `--group` flag list for groups needed in this worktree
3. Run: `uv sync --locked --group <g1> --group <g2> ...`

## Gotchas

- **`rm -rf` before deregistration leaves orphaned metadata** — always use `git worktree remove --force` first.
- **`.venv/` on macOS may have immutable flags** — clear with `chflags -R nouchg` before removal.
- **`uv sync --locked` is required after rebase** — the lockfile may differ between branches.

Last Updated: 2026.05.04 @ 04:15:00
