# Conflict Resolution Protocol and Fallback Analysis

This protocol is invoked by Phase 2 (merge operations) and Phase 4 (rebase operations) of the
sync-worktrees skill. See the main SKILL.md for the phase workflows that call into these steps.

## Conflict Resolution Protocol

### Step 1 — Detect Conflicts

Run `git --no-pager diff --name-only --diff-filter=U` to list unmerged files.

Check short-status codes:

| Code | Meaning |
|---|---|
| `UU` | Both modified |
| `AA` | Both added |
| `DD` | Both deleted |
| `AU` | Added by us |
| `UA` | Added by them |
| `DU` | Deleted by us |
| `UD` | Deleted by them |

Record: (a) the full list of conflicted file paths, and (b) the in-progress operation type (merge
or rebase).

### Step 2 — Lockfile Conflicts

Identify lockfiles by matching conflicted filenames against the manifest pairing table (same table
as Phase 4 Post-rebase lockfile sync in the main SKILL.md).

**Resolution sequence**:
1. `git checkout --theirs <lockfile>` — accept integration-branch version
2. `git add <lockfile>` — stage it
3. Run the paired regenerate command (e.g., `uv sync --locked`)

**Fallback**: If the manifest file is missing from the working tree OR the regeneration tool is
unavailable, apply `prompt` instead of attempting auto-resolution.

### Step 3 — Code/Config Conflicts

Applies to non-lockfile conflicted files.

1. Read both sides (ours and theirs) of each conflicted file.
2. **Safe-merge attempt**: Apply non-overlapping hunks automatically and stage resolved files with
   `git add`. Only hunks with no overlap between ours and theirs are applied automatically;
   overlapping hunks escalate to Step 4.
3. Continue operation:
   - For in-progress merge: `GIT_MERGE_AUTOEDIT=no git -C <path> merge --continue`
     (on some platforms `--no-edit` with `--continue` is not supported; `GIT_MERGE_AUTOEDIT=no`
     is a portable alternative)
   - For in-progress rebase: `git -C <path> rebase --continue`
4. Any commit produced MUST include the trailer `Co-Authored-By: Oz <oz-agent@warp.dev>` (inject
   via `--trailer` flag or by pre-populating `MERGE_MSG`/`COMMIT_EDITMSG`).

### Step 4 — Unresolvable Conflicts

Triggered when Step 3's safe-merge attempt cannot resolve a hunk (overlapping changes), or when
Step 2's fallback condition is met.

Apply `prompt` with all four required context elements:
- **(a)** Specific file path of the conflicted file
- **(b)** Conflict type from the git status code (e.g., `UU`, `AA`)
- **(c)** Both sides of the conflict (ours and theirs content)
- **(d)** Decision options: accept ours / accept theirs / manual edit / abort

**Decision outcomes**:
- Accept ours: `git checkout --ours <file> && git add <file>`
- Accept theirs: `git checkout --theirs <file> && git add <file>`
- Manual edit: open file for editing, then `git add <file>`
- Abort: `git merge --abort` or `git rebase --abort` depending on in-progress operation

---

## Fallback Analysis

Used when accelerator scripts are absent or detection fails. All commands must be run from within
the repo or using `-C <path>`. All commands include `--no-pager` to suppress interactive pager
output.

**Cleanliness per worktree**:
```
git --no-pager -C <path> status --short
```
Non-empty output = dirty. Empty output = clean.

**Divergence per branch**:
```
git --no-pager rev-list --left-right --count <local>...<remote>/<branch>
```
Outputs `<ahead>\t<behind>`. Ahead > 0 = unpushed commits. Behind > 0 = remote has commits not
in local.

**FF eligibility**:
```
git --no-pager merge-base --is-ancestor <integration_head> <branch_head>
```
Exit code 0 = integration head is ancestor of branch head = FF merge is possible. Non-zero = FF
not possible.

**Push candidacy / upstream config**:
```
git --no-pager config branch.<name>.remote
git --no-pager config branch.<name>.merge
```
Non-empty output = configured upstream remote and tracking ref. Empty = no upstream set.

**Merge-base existence**:
```
git --no-pager merge-base <integration_head> <branch_head>
```
Non-empty output (valid SHA) = shared history exists. Empty or non-zero exit = no common ancestor.
