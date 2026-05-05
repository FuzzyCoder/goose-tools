---
name: review-pr
description: Review the current branch's open pull request by launching two read-only dimensional reviewer sub-agents (correctness + tests; security + design). Produces a structured markdown report in the conversation only — does not apply fixes, commit, push, or comment on the PR. Use when the user says "review this PR", "review-pr", or "check the pull request".
---

# review-pr

Read-only PR analysis using parallel dimensional sub-agents. The parent agent synthesizes
their findings into a structured report. No files are modified, no commits are made, and no
PR comments are posted.

## When to Use

- User says "review this PR", "review-pr", or "check the pull request"
- Before merging a branch to validate correctness, security, and design
- After a large refactor to catch regressions or design drift
- As the self-review step invoked by `fix-issue` before opening a PR

## Agent-Authored PR Disclosure

Before producing any findings, check whether the PR was authored by Oz:

```bash
# Check commit authors and co-author trailers for goose-agent@block.xyz
git --no-pager log origin/HEAD..HEAD --format="%ae%n%(trailers:key=Co-Authored-By,valueonly)" | grep -i "goose-agent@block.xyz"
```

If the pattern matches, emit this disclosure line at the top of the report:

> **Disclosure:** This PR was authored by Oz (goose-agent@block.xyz); review may share blind
> spots with the author. Stricter scrutiny applied.

Do not skip the review because the PR is agent-authored. Apply the same review standards
as for human-authored code; bias toward stricter findings.

---

## Step 1 — Identify the PR

```bash
# Get current branch and PR info (JSON output disables pager automatically)
gh pr view --json number,title,baseRefName,headRefName,url,author,state
```

If no open PR exists for the current branch, report the error and stop. Do not proceed
with a review against a branch that has no associated PR.

Capture: `number`, `title`, `baseRefName` (base), `headRefName` (head), `url`.

---

## Step 2 — Gather Diff and Context

```bash
# Fetch latest remote state
git --no-pager fetch origin

# Full diff against base branch
git --no-pager diff origin/<baseRefName>...HEAD

# List changed files
git --no-pager diff --name-only origin/<baseRefName>...HEAD

# Commit summary
git --no-pager log origin/<baseRefName>..HEAD --oneline
```

Read the changed files in full using `read_files` to give sub-agents complete context.
Limit reads to files actually changed in the diff — do not bulk-read the entire repo.

---

## Step 3 — Launch Dimensional Reviewer Sub-Agents

Start two sub-agents with `start_agent` (`execution_mode: "local"`). Each sub-agent
owns one review dimension. Start them sequentially (not in parallel) per orchestration
rules.

**Sub-agent A — Correctness + Tests:**

Prompt must include:
- PR number, title, base branch, head branch
- Full diff text (or file paths to read)
- Instruction: analyze correctness (logic errors, edge cases, error handling, data
  integrity) and test coverage (are new behaviors tested? are tests behavior-focused
  or implementation-coupled?). Do NOT apply fixes. Do NOT commit. Report findings with
  severity (P1/blocker, P2/major, P3/minor) and file:line references where available.
- Instruction: send a status update when analysis is complete, then send the full findings
  report as a message.

**Sub-agent B — Security + Design:**

Prompt must include:
- PR number, title, base branch, head branch
- Full diff text (or file paths to read)
- Instruction: analyze security (injection risks, auth bypasses, secret handling, input
  validation) and design (abstraction fit, naming, coupling, adherence to existing
  patterns in the codebase). Do NOT apply fixes. Do NOT commit. Report findings with
  severity (P1/blocker, P2/major, P3/minor) and file:line references where available.
- Instruction: send a status update when analysis is complete, then send the full findings
  report as a message.

Remind both sub-agents to send status updates via the messaging tools (your agent ID is
automatically available to them).

---

## Step 4 — Wait for Sub-Agent Reports

After starting both sub-agents, yield control (end your turn with no tool calls). When
lifecycle events or messages arrive:

- `in_progress` — agent is running; wait.
- `succeeded` — read the agent's completion message via `read_messages_from_agents`.
- `failed` / `errored` — report the failure to the user; do not synthesize a partial review.

Collect both sub-agents' full finding reports before proceeding to synthesis.

---

## Step 5 — Synthesize and Report

Produce a structured markdown report **in the conversation only** (do not write to a file
unless the caller's prompt explicitly supplies an output path).

### Report Format

```
# PR Review: <PR title> (#<number>)

> **Disclosure:** [include only if Oz-authored]

## Summary
<2–4 sentence overall assessment: ship / needs work / blocker present>

## P1 — Blockers
<List each blocker with severity label, file:line reference, and description>
<If none: "None identified.">

## P2 — Major Findings
<List each major finding>
<If none: "None identified.">

## P3 — Minor / Polish
<List each minor finding>
<If none: "None identified.">

## Dimension Reports

### Correctness + Tests
<Sub-agent A findings verbatim or summarized>

### Security + Design
<Sub-agent B findings verbatim or summarized>
```

**Do not:**
- Apply any code fixes
- Edit any files
- Create commits
- Push branches
- Post comments to the PR on GitHub

If the caller is `fix-issue` acting as self-review, report P1/blocker findings clearly
so the parent agent can address them before opening the PR.

---

## Cross-Skill Invocation

`review-pr` is itself a review-style skill. Per D11-resolved, callers invoke it via
`start_agent` (not inline), so reviewers run in an isolated context. When invoked
directly by the user, the user's conversation is the parent context.

Internally, `review-pr` spawns sub-agents A and B via `start_agent` as described above.

---

## Gotchas

- **If no open PR exists for the current branch, stop** — do not proceed with a review against a branch with no PR.
- **Both sub-agents must run in isolated contexts** — use `start_agent` (`execution_mode: "local"`), not inline.
- **Do not post PR comments** — this skill produces a report in the conversation only.
- **Stricter scrutiny for agent-authored PRs** — do not skip the review just because the PR is agent-written.

Last Updated: 2026.05.04 @ 04:15:00
