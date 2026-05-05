---
name: quality-remediator
description: >-
  Sub-agent contract for iteratively fixing a single rule's slop violations
  within an explicit, read-only-elsewhere file scope. Read access to full repo,
  write access only to assigned files. Returns a structured Markdown summary
  on completion. Triggers: invoked by `quality-remediate` orchestrator; do not
  invoke directly.
---
# quality-remediator
## When to Use
- Invoked by the `quality-remediate` orchestrator skill as a local sub-agent
- Tasked with one slop rule + one explicit file ownership list

Do NOT invoke this skill directly from a top-level user request — use the
`quality-remediate` skill as the entry point.

## Contract
- **Read scope:** full repository (read-only).
- **Write scope:** ONLY the files in the explicit `assigned_files` list passed in the
  invocation prompt. Editing any other file is a contract violation.
- **Rule scope:** one slop rule per invocation (e.g. `halstead.volume`); processes all
  violations for that rule within the assigned file scope.

## Procedure
1. Run `slop lint --root . --output json`. Filter to the assigned rule + assigned files.
2. Order targets by `severity=error` first, then by violation value descending.
3. For each target: apply the canonical playbook from the corresponding `fix-*` skill.
   Read that skill's SKILL.md before editing.
4. After each file edit: run `slop check <rule> --root . --output json` and the
   `run-quality-checks` skill (`uv run ruff check <touched-paths>` and
   `uv run ty check <touched-paths>`).
5. If any test that was passing before the edit now fails: revert the edit, log the
   failure, and move to the next target.
6. Stop when all assigned violations are resolved OR when the targeted slop check stops
   improving for two consecutive edits on the same file.

## Reporting
Return a Markdown summary with:
- **Files touched:** absolute paths edited.
- **Violations resolved per file:** rule + symbol + before/after metric value.
- **Violations left and why:** remaining violations in scope and the reason (e.g.
  hotspot quarantined, two-pass exhausted, test regression on revert).
- **Validation results:** outcome of `slop check`, ruff, ty, and pytest for each touched
  file.

## Gotchas

- **Never edit a file outside the assigned scope** — this is a contract violation.
- **Never commit, push, or open PRs** unless the orchestrator's prompt explicitly authorizes it.
- **If a test that was passing before the edit now fails: revert** — log the failure and move to the next target.

Last Updated: 2026.05.04 @ 04:15:00
