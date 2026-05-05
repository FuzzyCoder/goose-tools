---
name: fix-issue
description: Given a GitHub issue number or URL, research the issue, create a goose-tools plan, implement the fix on a quality/<issue-number>-<slug> branch, run self-review via review-pr sub-agent, and open a PR. Trigger gates authorize issue research, plan creation, implementation, branch creation, commits, and PR creation when invoked via "fix issue", "fix-issue", or "implement issue #N".
---

# fix-issue

End-to-end GitHub issue resolution: research → plan → implement → self-review → PR.
The `manage-plans` skill is invoked inline (procedural). The `review-pr` self-review step
runs as a sub-agent for context isolation.

## When to Use

- User says "fix issue", "fix-issue", or "implement issue #N"
- User provides a GitHub issue number or URL

## Autonomy Gates

The trigger phrases above authorize all of the following actions in one invocation:

| Action | Authorization |
|---|---|
| `gh issue view` (research) | Authorized by trigger |
| Create a goose-tools plan | Authorized by trigger |
| Create branch `quality/<N>-<slug>` | Authorized by trigger |
| Edit and create files | Authorized by trigger |
| Commit to the branch | Authorized by trigger |
| Open a PR | Authorized by trigger |

Commits must include `Co-Authored-By: Goose <goose-agent@block.xyz>` in a new line at the end
of every commit message.

---

## Step 1 — Research the Issue

```bash
# Fetch issue details (JSON output; no pager)
gh issue view <N> --json number,title,body,labels,assignees,linkedPullRequests,url

# Follow linked PRs/issues if present
gh pr view <linked-pr> --json title,body,state
```

Read any files mentioned in the issue body using `read_files`. Do not read entire
directories speculatively — limit reads to files the issue directly references.

Extract from the issue: issue number, title, description, reproduction steps, expected
behavior, and any explicit file/function references.

---

## Step 2 — Check for Duplicate Plan

Before creating a plan, follow the `manage-plans` duplicate-title heuristic:

1. Read `~/goose-agent-plans.md` (if it exists).
2. Scan Active Plans for a title that closely resembles
   `"Fix issue #<N>: <issue-title>"` — ignoring capitalisation, backticks, and minor
   wording differences.
3. If a close match exists, offer to resume the existing plan via `direct file read` rather
   than creating a duplicate row. Wait for user direction.
4. If no close match, proceed to Step 3.

---

## Step 3 — Draft and Create a Plan

Inline-invoke the `manage-plans` skill:

1. Read `.agents/skills/manage-plans/SKILL.md` and follow its steps in the current context.
2. Create a plan titled `"Fix issue #<N>: <issue-title>"` with a concise implementation spec:
   - Problem statement (from the issue)
   - Affected files (from research)
   - Proposed changes (concrete, scoped to fixing the issue — no scope creep)
   - Acceptance criteria
3. The `manage-plans` skill will call `uuidgen`, capture the `plan_id`, and append a
   row to `~/goose-agent-plans.md`. Follow the skill's steps exactly.

---

## Step 4 — Create a Branch

Determine the repository's default branch:

```bash
git --no-pager symbolic-ref refs/remotes/origin/HEAD --short | sed 's|origin/||'
```

If the issue explicitly references a feature or release branch, use that as the base
instead of the default branch.

Generate the branch slug:
- Derive a ≤32-character lowercase-hyphenated slug from the issue title
- Remove special characters; replace spaces and underscores with hyphens
- Example: issue #123 "Fix retry logic timeout" → `quality/123-fix-retry-logic-timeout`

```bash
git --no-pager fetch origin
git checkout -b quality/<N>-<slug> origin/<default-branch>
```

---

## Step 5 — Implement

Read the plan (`direct file read`) and implement the fix.

Follow the project's `AGENTS.md` conventions (HARD_QUALITY_LIMITS, ZERO_WARNINGS_POLICY,
etc.). After implementation:

1. **Run the `run-quality-checks` skill inline** — read
   `.agents/skills/run-quality-checks/SKILL.md` and follow its commands. Do not re-list
   ruff/ty commands here.
2. Fix any ruff, ty, or pytest issues before proceeding.

Commit after successful checks:

```bash
git --no-pager add <changed files>
git commit -m "fix(#<N>): <concise description>

Closes #<N>

Co-Authored-By: Goose <goose-agent@block.xyz>"
```

Push the branch:

```bash
git --no-pager push origin quality/<N>-<slug>
```

---

## Step 6 — Self-Review

After pushing, invoke `review-pr` as a sub-agent for context isolation:

```bash
# The sub-agent reviews the pushed branch against the default base branch
start_agent(
  name="review-pr: fix-issue self-review #<N>",
  execution_mode="local",
  prompt="""
Run the review-pr skill.
Current branch: quality/<N>-<slug>
Base branch: <default-branch>
This is a self-review before opening a PR. Report all P1/blocker findings clearly.
Send the full review report as a message when complete.
"""
)
```

Wait for the sub-agent to complete (lifecycle events + `read_messages_from_agents`).

**Address P1/blocker findings** from the review report before opening the PR:
- Apply the fix inline (this is implementation work, not a separate review-and-fix cycle).
- Re-run quality checks.
- Commit and push the fix.

Do **not** auto-invoke `review-and-fix-pr` — that skill's own gates govern when it is
used. The user can invoke it independently after the PR is open if desired.

P2/P3 findings: note them in the PR description. Do not block PR creation on minor findings.

---

## Step 7 — Open the PR

```bash
gh pr create \
  --title "fix(#<N>): <issue-title>" \
  --base <default-branch> \
  --head quality/<N>-<slug> \
  --body "## Summary

Fixes #<N>: <issue-title>

## Changes

<brief description of what was changed and why>

## Testing

<describe how the fix was tested>

## Review Notes

<any P2/P3 findings from self-review that were not addressed>

---
When this PR merges, archive the plan via the manage-plans skill (plan_id: <UUID>).

Co-Authored-By: Goose <goose-agent@block.xyz>"
```

Report the PR URL to the user.

---

## Branch Naming Convention

`quality/<issue-number>-<short-slug>`

- `<issue-number>` — the GitHub issue number (integer)
- `<short-slug>` — lowercase, hyphenated, ≤32 characters derived from the issue title
- Examples:
  - Issue #42 "Add config flag for retries" → `quality/42-add-config-flag-retries`
  - Issue #99 "Fix authentication token expiry" → `quality/99-fix-auth-token-expiry`

---

## Plan Archive Reminder

The PR description **must** include this line (with the actual plan UUID substituted):

```
When this PR merges, archive the plan via the manage-plans skill (plan_id: <UUID>).
```

Manual archive is the user's responsibility after merge. There is no automatic detection.
To archive: use the `manage-plans` skill or the `plan-workflow` Step 07 commands.

---

Last Updated: 2026.05.01 @ 00:04:37
