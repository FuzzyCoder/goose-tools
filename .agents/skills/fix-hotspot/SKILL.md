---
name: fix-hotspot
description: >-
  Remediate quality `hotspots` (high churn × high complexity) by reviewing recent
  commit history, splitting decomposable files, and quarantining files with
  noisy history that need a clean spec before further edits. Triggers:
  quality-remediate routing, "hotspot violation", "high churn", "split this file".
---
# fix-hotspot
## When to Use
- Quality reports a `hotspots` failure for a file
- An agent has been routed by `quality-remediate` to address a hotspot
- A user asks to refactor a file flagged as a hotspot

## Routing
Quality rule handled:
- `hotspots` (high churn × high complexity)

For raw complexity see `fix-complexity` (function) or `fix-class-complexity`
(class). For volume issues see `fix-halstead`.

## Playbook
1. **History review (mandatory first step):**
   ```bash
   git --no-pager log --oneline --since='14 days ago' -- <file>
   ```
2. **Clean-history gate:** "clean" requires ALL of:
   - ≤ 5 commits in the 14-day window AND
   - a single primary author OR a single feature/PR theme
3. **If clean and decomposable:** split into sub-modules. Prefer a `<name>/` subdirectory
   with files named by responsibility (e.g. `_core.py`, `_io.py`, `_handlers.py`, or
   equivalent). A thin orchestrator module stays at the original path and imports the new
   sub-modules.
4. **If not clean — QUARANTINE:** stop remediation for the file in this pass, record the
   reason in the plan slot's `quarantine.txt` (one line per file:
   `<filepath>: <reason>`), and require a clean spec/fresh branch before edits.
5. **No third-pass edits:** never let any agent attempt a third speculative "fix" on the
   same hotspot file. Two prior speculative attempts force quarantine.

## Quarantine semantics
- Quarantine does NOT change `.slop.toml`.
- Quarantine does NOT add the file to any `exclude` list.
- Quarantine does NOT disable the `hotspots` rule.
- The violation persists in the quality report until a clean fix lands.

## Anti-Patterns
- Adding the file to `.slop.toml` `exclude` to silence the metric.
- Renaming the file to escape the churn measurement.
- Making cosmetic edits (whitespace, import order) just to refresh the timestamp.
- "Fixing" a hotspot by moving its complexity into one new helper and shrinking the
  parent — quality will flag the helper next pass.

## Validation
- After a clean-history split: re-run `quality lint --root . --output json` and confirm the
  file no longer appears in the `hotspots` list.
- Run pytest for tests covering the split modules.
- Run the `run-quality-checks` skill.
- For quarantined files: confirm `quarantine.txt` has the file and reason, and the file
  is unchanged in this pass.

## Gotchas
- **Adding the file to `.slop.toml` exclude silences the metric** but doesn't fix it — forbidden.
- **Renaming a file escapes churn measurement** without resolving the underlying problem.
- **Cosmetic edits (whitespace, import order)** refresh timestamps but don't count as fixes.
- **Moving complexity into one new helper** just shifts the hotspot flag to the helper next pass.
