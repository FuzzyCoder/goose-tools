---
name: review-and-fix-pr
description: Autonomously review and fix the current branch's open pull request. Invokes review-pr for analysis, then addresses accepted findings, runs validation, commits, pushes, and optionally posts PR comments. Trigger gates: only file edits, commits, pushes, and PR comments when invoked via "review and fix this PR", "review-and-fix-pr", or "fix PR review findings". If invoked without these phrases, stops after producing a review report and directs the user to review-pr.
---

# review-and-fix-pr

Autonomous review-then-fix workflow. The review phase runs via a `review-pr` sub-agent
for context isolation. The fix phase applies accepted findings, validates the changes, and
commits and pushes them. PR comments are optional and gated on explicit invocation.

## When to Use

- User says exactly: "review and fix this PR", "review-and-fix-pr", or "fix PR review findings"
- After a `fix-issue` workflow when the user wants autonomous patching of review findings
- When the user wants a single command to both identify and resolve PR issues

**If the user says "review this PR" or "check the pull request" without the fix-specific
trigger phrases above**, do NOT enter the fix phase. Stop after delivering the review
report and direct the user to the `review-pr` skill.

---

## Agent-Authored PR Disclosure

Apply the same agent-authored PR disclosure as `review-pr`:

- Check for `goose-agent@block.xyz` in commit authors and `Co-Authored-By` trailers.
- If matched, emit the disclosure at the top of the review report.
- When fixing findings on an agent-authored PR, apply the same code-quality and review-order
  rules as a fresh implementation. Do not relax standards because the original was
  agent-written.

---

## Autonomy Gates

The following actions are authorized **only** when this skill is invoked via one of its
explicit trigger phrases:

| Action | Gate |
|---|---|
| Edit files | Authorized by trigger phrase |
| Commit changes | Authorized by trigger phrase |
| Push to remote | Authorized by trigger phrase; regular push only (no `--force`) |
| Post PR comments | Authorized by trigger phrase; use `gh pr comment` |

Use `git push` (not `git push --force` or `git push --force-with-lease`) unless the user
explicitly requests otherwise.

All commits must include `Co-Authored-By: Goose <goose-agent@block.xyz>` in a new line at the
end of the commit message.

---

## Phase 1 — Review (via sub-agent)

Start a `review-pr` sub-agent via `start_agent` (`execution_mode: "local"`):

```
Prompt: Run the review-pr skill for PR on branch <HEAD>. Base branch: <base>.
        Send the full review report as a message when complete.
```

Wait for the sub-agent to complete (via lifecycle events and `read_messages_from_agents`).

If the sub-agent fails or errors, report the failure to the user and stop. Do not proceed
to the fix phase with incomplete review information.

Collect the structured report (P1/P2/P3 findings + dimension reports).

---

## Phase 2 — Triage Findings

Classify findings by fixability:

- **P1 / Blockers** — must fix before pushing. If a P1 cannot be fixed confidently, halt
  and report to the user rather than guessing.
- **P2 / Major** — fix if the fix is unambiguous from the finding description. If
  ambiguous, report to the user and skip that finding.
- **P3 / Minor** — apply straightforward fixes; skip anything requiring design judgment.

Do not fix findings that require user decisions (e.g., API design choices, breaking
changes, architectural trade-offs). Mark those as "deferred to user" in the commit message.

---

## Phase 3 — Apply Fixes

For each accepted finding, apply the fix using `edit_files`. After all fixes are applied:

1. **Run the `run-quality-checks` skill inline** — read
   `.agents/skills/run-quality-checks/SKILL.md` and follow its commands in the current
   context. Do not re-list ruff/ty commands here; follow what the skill specifies.

2. **Run the test suite:**
   ```bash
   uv run pytest tests/
   ```
   If tests fail after your fixes, either resolve the failure or revert the specific fix
   that broke tests and note it as "deferred to user".

3. If all checks pass, proceed to commit.

---

## Phase 4 — Commit and Push

Stage and commit all accepted fixes in a single commit:

```bash
git --no-pager add -p    # or git add <specific files>
git commit -m "fix: address PR review findings

Fixes applied:
- <finding 1 summary> (P<severity>)
- <finding 2 summary> (P<severity>)

Deferred to user:
- <finding N summary> (requires design decision)

Co-Authored-By: Goose <goose-agent@block.xyz>"
```

Then push:

```bash
git --no-pager push origin HEAD
```

Do not force-push unless the user explicitly requests it.

---

## Phase 5 — Optionally Comment on PR

If the user's invocation phrase included a request to post a summary comment (e.g.,
"review and fix this PR and post a summary"), post a PR comment:

```bash
gh pr comment --body "## Oz Review + Fix Summary

**Findings addressed:** <list>
**Deferred to user:** <list (if any)>

Co-Authored-By: Goose <goose-agent@block.xyz>"
```

Otherwise, report the summary in the conversation only.

---

## Phase 6 — Report

After pushing, provide the user with:
- Link to the PR (`gh pr view --json url --jq .url`)
- List of findings addressed and deferred
- Any remaining manual actions needed

---

## Gotchas

- **Do not force-push** unless the user explicitly requests it.
- **If the sub-agent review fails, stop** — do not proceed to the fix phase with incomplete review information.
- **"review this PR" without fix trigger phrases stops after the report** — do not enter the fix phase.
- **Never relax quality standards for agent-authored PRs** — apply the same rules as fresh implementation.

Last Updated: 2026.05.04 @ 04:15:00
