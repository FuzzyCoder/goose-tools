---
name: sync-worktrees
description: Synchronize all git worktrees — commit, push, integrate, rebase — with autonomous conflict resolution and structured reporting. Use when committing and pushing across all worktrees, integrating feature branches into the integration branch, or rebasing all non-integration branches in one coordinated pass. Not for creating or removing worktrees (use manage-worktrees skill instead).
---

# Sync Worktrees

## When to Use
- Committing, pushing, and rebasing across all git worktrees in one coordinated pass
- Integrating feature branches into the integration branch (typically `main`)
- Not for creating or removing worktrees (use `manage-worktrees` skill instead)

## References Structure

- `references/conflict-resolution.md` — conflict detection and resolution protocol
- `references/report-template.md` — completion report format and validation checks

## Quick Start

```bash
# Optional: run a pre-flight analysis script if one exists for this project
# Check for existence first; fall back to direct git commands if absent
[ -f {{SYNC_SCRIPT_PATH}} ] && zsh {{SYNC_SCRIPT_PATH}} || echo "No accelerator script found — proceeding with direct git commands"
```

Then follow the 4-phase protocol: Phase 1 (Commit+Push) → Phase 2 (Integrate) → Phase 3 (Push Integration) → Phase 4 (Rebase).

## Overview

The sync-worktrees skill provides a structured 4-phase protocol for keeping all git worktrees in
sync:

1. **Phase 1 — Commit + Push**: Stage and commit dirty worktrees, push each branch to its remote.
2. **Phase 2 — Integrate**: Merge eligible branches into the integration branch using a configurable
   merge policy.
3. **Phase 3 — Push Integration**: Push the updated integration branch to the remote.
4. **Phase 4 — Rebase**: Rebase all eligible non-integration branches onto the updated integration
   branch.

Phases execute in strict order. A failure in any phase triggers the configured escalation behavior
before proceeding.

**Repo-agnostic design**: The skill operates on any git repository with worktrees. It makes no
assumptions about project layout, language, or toolchain. All configuration is resolved at runtime
during Pre-flight discovery.

**Optional accelerator scripts**: If the project has pre-flight analysis scripts (e.g., divergence
analysis, fast-forward eligibility checks), the skill delegates to them when available and falls
back to direct `git` invocations (documented in
[references/conflict-resolution.md](<./references/conflict-resolution.md>)) when absent.

---

## Behavior Definitions

All escalation in this skill is expressed using exactly three named behaviors. These names are used
verbatim throughout subsequent sections.

**`skip-and-report`**: Skip this item, continue processing remaining items, include in Completion
Report. Use when an individual worktree or branch can be safely bypassed without compromising
overall sync integrity (e.g., dirty submodules, locked worktrees).

**`stop-and-report`**: Halt all remaining phases immediately upon encountering the triggering
condition. Emit a recovery summary containing: (a) the phase and step where the halt occurred,
(b) the error or condition encountered, (c) relevant SHAs at time of halt, and (d) exact next-step
commands the user must run to resume or recover. No further processing occurs after this behavior
is triggered.

**`prompt`**: Pause execution and present the decision to the user with full context (current state,
options, and implications of each choice). Resume processing based on the user's response. Use when
autonomous resolution is unsafe or ambiguous (e.g., stash-bearing worktrees before commit/rebase,
ambiguous remote selection).

---

## Pre-flight / Discovery

Run all pre-flight steps before any mutating operation.

### Step 1 — Fetch

Run the following command before any decisions to ensure all remote-tracking refs are current.
`--no-pager` is a global git option and must precede the subcommand:
```bash
git --no-pager -C <repo_path> fetch <selected_remote> --prune
```
This step requires `selected_remote` to already be resolved (see Step 2).

### Step 2 — Resolve `selected_remote`

Resolve `selected_remote` **before** `integration_branch` to avoid a circular dependency.
`integration_branch` resolution depends on `selected_remote` via
`refs/remotes/<selected_remote>/HEAD`; resolving them simultaneously would create a circular
dependency.

Resolution chain (applied in order):
1. User-specified value (passed as parameter or config).
2. If exactly one remote exists (`git remote` returns a single line), use it automatically.
3. If zero or multiple remotes exist, apply `prompt` to ask the user to select.

### Step 3 — Resolve `integration_branch`

Depends on the resolved `selected_remote`.

Resolution chain (applied in order):
1. User-specified value.
2. Read `refs/remotes/<selected_remote>/HEAD` to determine the default branch.
3. If the HEAD ref is missing, run `git remote set-head <selected_remote> -a` to auto-detect and
   set it, then re-read the ref.
4. If still unresolvable, apply `prompt`.

### Step 4 — Discover Worktrees

Run `git worktree list --porcelain`. Parse the following fields:
- `worktree`: absolute path
- `HEAD`: current commit SHA
- `branch`: full ref (e.g., `refs/heads/main`)
- Flags: `bare`, `detached`, `locked`, `prunable`

### Step 5 — Define Eligible Worktrees

An **eligible worktree** is one that is attached (not bare) and has a normal local branch (not
detached HEAD).

Automatically **exclude** worktrees that are bare, detached, locked, or prunable **unless** the
user explicitly overrides the exclusion for a specific worktree via parameter or prompt response.

### Step 6 — Detect Stashes per Worktree

Run `git --no-pager stash list` and filter entries matching either pattern:
- `WIP on <branch>:`
- `On <branch>:`

If a stash is detected for a worktree's branch, apply `prompt` before committing or rebasing in
that worktree. Present the stash list and ask the user to confirm intent.

### Step 7 — Detect Protected Branches

Detect protected branches via three-tier hierarchy (applied in order):

**(a)** If `gh` CLI is available, query:
```
gh api repos/{owner}/{repo}/branches/{branch}/protection
```
A 200 response means the branch is protected.

**(b)** Well-known names: `main`, `master`, `develop`, `release/*` are treated as protected for
rewrite operations (rebase, force-push).

**(c)** If `.agents/config/protected-branches` file exists, read it as a newline-delimited list of
branch names/patterns and treat matches as protected.

Default when `gh` is unavailable and no config file exists: apply well-known names only.

### Step 8 — Dirty Submodules and Nested Repos

If any worktree contains dirty submodules or nested git repositories (detected via
`git submodule status` showing `+` or `-` prefix, or presence of nested `.git` directories with
uncommitted changes), apply `skip-and-report` for that worktree.

---

## Scope Rules

### commit/push scope

All **eligible worktrees** for this sync execution, as defined in Pre-flight/Discovery.

**File handling rules**:
- `git add -A` includes untracked files on tracked paths.
- Ignored files (`.gitignore`) are **never** added.
- Dirty submodules: `skip-and-report`.

### merge scope

All eligible non-integration worktree branches that are **safely integratable**. A branch is safely
integratable if it meets **ALL** three conditions:

**(a) Merge-base check**: The branch shares a merge-base with the integration branch. Evaluated via:
```
git --no-pager merge-base --is-ancestor <integration_head> <branch_head>
```
Exit code 0 = FF is possible (integration head is ancestor of branch head).

**(b) Divergence check**:
remote. Evaluated via:
```
git --no-pager rev-list --left-right --count <branch>...<remote>/<branch>
```
where the remote-ahead count must be 0.

**(c) Policy block check**: The branch does not trigger known policy blocks, including protected
branch rules, required signing enforcement, hook failures, or pre-receive rejections.

If **any** condition fails, apply `prompt` rather than silently skipping or halting.

### rebase scope

Eligible non-integration worktrees remaining after Phase 3 that are safe to rewrite history on.
Protected branches (per Pre-flight detection) are `skip-and-report` by default. Override with
`--allow-rewrite <branch1> [<branch2> ...]`.

**Scope boundary**: Only worktrees remaining after Phase 3 are candidates — branches already merged
or skipped in Phase 3 are excluded from rebase scope evaluation.

---

## Phase 1 — Commit + Push All

For each dirty worktree in commit/push scope, execute the following steps sequentially. Steps are
NOT parallelized.

### Per-Worktree Commit Flow

1. Capture pre-SHA: `git --no-pager -C <path> rev-parse HEAD`
2. Stage all changes: `git -C <path> add -A`
3. Commit using the exact command:
   ```
   git -C <path> commit -m "chore(sync): pre-sync snapshot [automated]" \
     --trailer "Co-Authored-By: Oz <oz-agent@warp.dev>"
   ```
   The `--trailer` flag MUST be used (not embedding the trailer in `-m`) to ensure proper git
   trailer formatting.
4. Capture post-SHA: `git --no-pager -C <path> rev-parse HEAD`
5. Proceed to push (see Safety Gates below).

### Safety Gates

**Stash Gate**: Before committing, check if Pre-flight (Step 6) detected stashes matching
`WIP on <branch>:` or `On <branch>:` patterns. If present, apply `prompt` — pause and inform the
user, allowing them to pop the stash first. Do NOT auto-pop stashes.

**No-Upstream Gate**: Before pushing, verify the remote branch exists:
```
git --no-pager ls-remote --heads <remote> <branch>
```
If the command returns no output (remote branch does not exist), apply `prompt`. Do NOT silently
create a new remote branch.

**Rejected Push Recovery**: On push rejection (non-fast-forward error):
1. Fetch latest: `git -C <path> fetch <remote>`
2. Attempt non-force reconciliation: `git -C <path> rebase <remote>/<branch>` (preferred);
   fall back to merge if rebase is inappropriate. Conflict resolution follows the
   [Conflict Resolution Protocol](<./references/conflict-resolution.md>).
3. Retry push: `git -C <path> push <remote> <branch>`
4. If still rejected, apply `prompt` before any force-push. Use `--force-with-lease` only,
   never bare `--force`.

### Clean Worktrees

A worktree is considered clean if `git -C <path> status --porcelain` returns empty output. Clean
worktrees are immediately skipped — no add, commit, or push is attempted.

Record in Completion Report: status `skipped`, reason `already clean`.

---

## Phase 2 — Integrate

See also: [Conflict Resolution Protocol](<./references/conflict-resolution.md>)

### Missing Integration Worktree Guard

Before any other Phase 2 work, check whether a local worktree for `integration_branch` exists.
If absent:
1. Apply `skip-and-report` for both Phase 2 **and** Phase 3.
2. Record in the Completion Report under 'Skipped Phases':
   `Phase 2–3 skipped: no local worktree found for integration_branch <name>`.
3. Set the Phase 4 rebase target to `<selected_remote>/<integration_branch>` instead of a local
   integration HEAD.

This guard is evaluated before any analysis refresh or merge ordering. The rest of Phase 2 is
entirely bypassed when triggered.

### Analysis Refresh

After Phase 1 completes (and if the worktree guard did not trigger), re-run fallback analysis
to capture updated SHAs from Phase 1 commits/pushes. Use the refreshed candidate list for
all subsequent merge ordering and eligibility checks.

### Topological Merge Order

For each candidate branch in merge scope, compute commits-ahead:
```
git --no-pager rev-list --count <integration_head>..<branch_head>
```

Sort candidates **ascending** by commits-ahead count (fewest first = closest to integration HEAD).
Use alphabetical tiebreak on branch name when counts are equal.

### Merge Policy

Controlled by `--merge-policy` (default: `ff-then-merge`):

**`ff-then-merge` (default)**:
1. Attempt: `git -C <integration_path> merge --ff-only <branch>`
2. If FF succeeds: record merge type as 'FF' in Completion Report.
3. If FF fails: `git -C <integration_path> merge <branch> --no-edit`
4. Immediately amend after a non-FF merge:
   ```
   git -C <integration_path> commit --amend --no-edit \
     --trailer "Co-Authored-By: Oz <oz-agent@warp.dev>"
   ```
5. Record merge type as 'merge commit' in Completion Report.

**`ff-only`**:
1. Attempt: `git -C <integration_path> merge --ff-only <branch>`
2. If FF is impossible: apply `skip-and-report` for that branch; continue to next candidate.

**`prompt`**:
1. Attempt FF as above.
2. If FF fails: apply `prompt` before proceeding with merge.
3. If operator declines: apply `skip-and-report` for that branch.
4. If operator approves: proceed with merge and amend+trailer.

### Policy Blocks

Default: apply `stop-and-report` — halt Phase 2 execution.

Override with `--on-policy-block=prompt`: Apply `prompt` only when user action could
meaningfully unblock the situation. For non-actionable blocks even under `--on-policy-block=prompt`:
fall back to `stop-and-report`.

---

## Phase 3 — Push Integration

1. Capture before-SHA: `git --no-pager -C <integration_path> rev-parse HEAD`
2. Push: `git -C <integration_path> push <selected_remote> <integration_branch>`
3. Capture after-SHA: `git --no-pager -C <integration_path> rev-parse HEAD`
4. **Rejected push recovery**: same protocol as Phase 1 Rejected Push Recovery.

---

## Phase 4 — Rebase Remaining Worktrees

### Analysis Refresh

After Phase 3 completes (or after Phase 1 if Phases 2–3 were skipped), refresh worktree state
analysis to get current branch HEADs, stash lists, and rebase-scope membership.

**Rebase target selection**:
- **Normal path** (Phases 2–3 ran): `rebase_target` = integration branch local HEAD (just pushed).
- **Skipped path** (Phases 2–3 were skipped): `rebase_target` =
  `<selected_remote>/<integration_branch>`.

### Per-Worktree Rebase Loop

Execute sequentially — **no parallel writes** to avoid index/lock conflicts.

For each branch in rebase scope:

**(a) Stash gate**: Run `git --no-pager -C <path> stash list`. If stashes are detected, apply
`prompt` before proceeding.

**(b) Pre-rebase SHA capture**: `git --no-pager -C <path> rev-parse HEAD`

**(c) Rebase**: `git -C <path> rebase <rebase_target>`

**Fast-forward note**: When a branch's commits are all already ancestors of the rebase target
(e.g., after the branch was merged in Phase 2), `git rebase` will fast-forward the branch tip
to the integration tip. The pre-SHA and post-SHA will differ. This is correct behaviour.

**(d) Post-rebase SHA capture**: `git --no-pager -C <path> rev-parse HEAD`

**(e) Post-rebase lockfile sync**: Detect toolchain markers and run the paired sync command:

| Lockfile | Manifest | Sync Command |
|---|---|---|
| `uv.lock` | `pyproject.toml` | see uv group detection below |
| `package-lock.json` | `package.json` | `npm ci` |
| `yarn.lock` | `package.json` | `yarn install --frozen-lockfile` |
| `Gemfile.lock` | `Gemfile` | `bundle install` |

**uv optional-group detection**: Bare `uv sync --locked` syncs only default dependency groups
and **silently removes** any optional groups that were previously installed. Before running
`uv sync --locked` for a worktree:
1. Read `<worktree>/pyproject.toml` `[dependency-groups]` to identify all declared groups.
2. Check local AGENTS.md files for any `uv sync --group <name>` prerequisites.
3. Build the `--group` flag list from required groups not in conflict.
4. Run: `uv sync --locked --group <g1> --group <g2> ...`

If group detection is ambiguous, apply `prompt` before running the lockfile sync step.

**(f) Push if SHA changed**: If `post_sha != pre_sha`, push immediately:
```bash
git -C <path> push <selected_remote> <branch>
```
Apply Phase 1 Rejected Push Recovery on rejection.

### Protected Branches in Rebase Scope

Default: `skip-and-report` — record the branch as skipped with reason 'protected branch'.

Override with `--allow-rewrite`: protected branches are included in the rebase loop and processed
normally. Note: `--allow-rewrite` does NOT bypass the stash gate.

---

## Conflict Resolution Protocol

→ See [references/conflict-resolution.md](<./references/conflict-resolution.md>) for conflict detection
steps, lockfile conflict resolution, code/config conflict handling, and fallback git analysis commands.

---

## Failure / Recovery Policy

### Stop-and-Report Template

On any non-recoverable failure, apply `stop-and-report` and emit all four required elements:

**(a) Phase and step that failed**: e.g., `Phase 2, merge of branch feature/foo`.

**(b) Exact error message from Git**: verbatim stderr/stdout output from the failing git command.

**(c) Pre- and post-SHAs for all completed operations**: a list of every operation that succeeded
before the failure, each with its before-SHA and after-SHA.

**(d) Concrete next-step commands**: specific, copy-pasteable git commands the user can run to
recover (e.g., `git -C <path> merge --abort`, `git -C <path> reset --hard <pre-SHA>`).

### SHA Capture Discipline

Before and after SHAs MUST be captured for every mutating operation:
```bash
pre_sha=$(git --no-pager -C <path> rev-parse HEAD)
# ... operation ...
post_sha=$(git --no-pager -C <path> rev-parse HEAD)
```

### Idempotent Recovery Posture

Re-running from scratch is the sole recovery path. The skill is safe to re-run because:
- **Phase 1**: Already-clean worktrees are skipped.
- **Phase 2**: Already-merged branches produce `Already up to date.`
- **Phase 3**: Already-pushed SHAs produce no-op pushes.
- **Phase 4**: Already-up-to-date branches skip the rebase.

---

## Completion Report

→ See [references/report-template.md](<./references/report-template.md>) for the seven report field
categories, final validation checks (clean/no-unpushed/up-to-date), and validation outcome format.

---

## Optional Local Accelerators

Accelerator scripts are **read-only analysis tools**. All mutations (commits, pushes, merges,
rebases) are always performed by the skill's own git commands — never delegated to helper scripts.

### Detection Mechanism

Check file existence before use:
```bash
[ -f {{SYNC_SCRIPT_PATH}} ] && <use_script> || <use_fallback>
```
Detection is purely file-existence based (`-f` flag). Absence of accelerators is a normal,
supported operating mode — not a degraded state.

When any accelerator script is absent, the skill falls back to the direct git commands in
[Fallback Analysis](<./references/conflict-resolution.md#fallback-analysis>).

---

## Confirmed Defaults and Invocation Parameters

→ See [references/defaults-and-invocation.md](references/defaults-and-invocation.md) for parameter defaults and the invocation summary table.

## Gotchas

- **`--trailer` flag must be used for co-author lines** — embedding in `-m` breaks git trailer formatting.
- **Clean worktrees are skipped** — no add, commit, or push is attempted if `git status --porcelain` returns empty.
- **Protected branches cannot be rewritten** — use `--allow-rewrite` to override for rebase operations.
- **Phase 2-3 are skipped entirely if integration worktree is absent** — Phase 4 rebase targets remote instead of local.

Last Updated: 2026.05.04 @ 04:15:00
