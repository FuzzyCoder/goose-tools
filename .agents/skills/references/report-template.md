# Completion Report Template

## Report Fields

All seven categories are required.

**1. Worktrees committed**

| Field | Description |
|---|---|
| `branch_name` | Branch checked out in the worktree |
| `pre_sha` | SHA captured before `git add -A` |
| `post_sha` | SHA captured after commit |

**2. Branches pushed**

| Field | Description |
|---|---|
| `branch_name` | Branch name |
| `remote` | The `selected_remote` value used |
| `newly_created` | Boolean — true if remote branch did not exist before push |

**3. Integration merges**

| Field | Description |
|---|---|
| `branch_name` | Branch merged |
| `merge_type` | `FF` (fast-forward) or `merge-commit` |
| `merge_order` | Integer sequence position (1st, 2nd, …) |
| `resulting_sha` | SHA of HEAD on integration branch after merge |

**4. Rebases completed**

| Field | Description |
|---|---|
| `branch_name` | Branch rebased |
| `post_rebase_sha` | SHA of branch HEAD after rebase |
| `lockfile_sync_commands` | Array of commands run (empty array if none) |

**5. Conflicts resolved**

| Field | Description |
|---|---|
| `file_path` | Path of the conflicted file |
| `conflict_type` | e.g., `lockfile`, `content`, `rename-delete` |
| `resolution_method` | One of: `lockfile-auto`, `safe-merge`, `user-resolved` |

**6. Stash entries detected**

| Field | Description |
|---|---|
| `worktree_path` | Filesystem path of the worktree |
| `stash_count` | Integer count from `git stash list` |
| `stash_refs` | Array of stash ref strings (e.g., `["stash@{0}", "stash@{1}"]`) |

**7. Branches skipped / requiring user decision / policy blockers**

| Field | Description |
|---|---|
| `branch_name` | Branch name |
| `reason` | Human-readable explanation |
| `escalation_behavior` | One of: `skip-and-report`, `stop-and-report`, `prompt` |

## Final Validation

After all four phases complete, re-run the [Fallback Analysis](conflict-resolution.md#fallback-analysis)
protocol across all worktrees to capture current divergence, cleanliness, and upstream status. This
re-run is mandatory and not skipped even if no errors occurred.

**Three concrete checks**:

**(a) Clean check** — All committed worktrees must have zero uncommitted changes:
```
git --no-pager -C <path> status --short
```
Pass condition: empty output. Deviation example: `3 uncommitted files`.

**(b) No-unpushed check** — All pushed branches must have zero local-ahead commits:
```
git --no-pager -C <path> rev-list --count <remote>/<branch>..<branch>
```
Pass condition: output equals `0`. Deviation example: `2 commits ahead of remote`.

**(c) Up-to-date check** — All rebased branches must have zero commits behind the integration
branch:
```
git --no-pager -C <path> rev-list --count <branch>..<integration_head>
```
Pass condition: output equals `0`. Deviation example: `1 commit behind integration branch`.

Applicability: the clean check applies to committed worktrees; the no-unpushed check to pushed
branches; the up-to-date check to rebased branches. Worktrees not in a given scope are exempt.

## Validation Outcome

**PASS**: All worktrees satisfy all applicable checks. Record `validation_result: PASS` with a
timestamp.

**FAIL**: One or more worktrees fail one or more applicable checks. Record `validation_result: FAIL`
and include per-worktree discrepancy details:

| Field | Description |
|---|---|
| `worktree_path` | Filesystem path of the failing worktree |
| `branch_name` | Branch checked out |
| `failed_check` | One of: `clean`, `no-unpushed`, `up-to-date` |
| `deviation` | Human-readable deviation string (formats below) |
| `git_command_output` | Raw output of the failing git command for auditability |

Deviation string formats:
- For `clean`: `N uncommitted files` (e.g., `3 uncommitted files`)
- For `no-unpushed`: `N commits ahead of remote` (e.g., `2 commits ahead of remote`)
- For `up-to-date`: `N commits behind integration branch` (e.g., `1 commit behind integration branch`)

FAIL is a **reporting-only** outcome — no automatic remediation is attempted. All discrepancies
must be listed (not just the first).

Example FAIL output:
```yaml
validation_result: FAIL
discrepancies:
  - worktree_path: /repo/feature-a
    branch_name: feature-a
    failed_check: no-unpushed
    deviation: "2 commits ahead of remote"
    git_command_output: "2"
  - worktree_path: /repo/feature-b
    branch_name: feature-b
    failed_check: up-to-date
    deviation: "1 commit behind integration branch"
    git_command_output: "1"
```
