---
name: quality-remediate
description: >-
  Iteratively remediate slop violations by routing each rule to its dedicated
  fix-* skill and delegating to local sub-agents (`quality-remediator` skill) when
  the violation set is large or spans multiple package roots. Stops when quality-lint
  exits clean or after 5 rounds. Triggers: "remediate quality", "fix quality
  violations", "run quality remediation", "clear the quality report".
---
# quality-remediate
## When to Use
- After `quality-lint-report` produces a fresh report with errors and the user wants
  remediation applied
- When iterating until slop exits clean for `severity=error` rules
- For coordinating multiple fix-* skills across rule families

## Routing
Slop rule → fix-* skill mapping (canonical):
- `complexity.cyclomatic`, `complexity.cognitive` → `fix-complexity`
- `complexity.weighted`, `class.coupling` → `fix-class-complexity`
- `class.inheritance.depth`, `class.inheritance.children` → `fix-class-inheritance`
- `halstead.volume`, `halstead.difficulty` → `fix-halstead`
- `npath` → `fix-npath`
- `hotspots` → `fix-hotspot`
- `packages` → `fix-packages`
- `deps` → `fix-deps-cycle`
- `orphans` → `fix-orphans`

If a future slop rule appears without a routing entry: STOP and report the unmapped rule
to the user. Do not guess.

## Round protocol
A "round" is exactly: one `slop lint --root . --output json` invocation, followed by all
fixes applied for the highest-severity rule before re-running slop.
1. Run `slop lint --root . --output json`. If exit 0 → report clean and stop.
2. Parse JSON; group violations by rule in (severity=error first, then advisory) then by
   count descending.
3. Pick the top group. Route through the canonical map above.
4. Apply fixes per the routed skill.
5. Re-run `slop lint --root . --output json`. End of round.
6. Loop terminates when (a) slop reports 0 errors, or (b) round counter hits 5.
7. After 5 rounds, stop and report remaining violations and why.

## Sub-agent delegation
Delegate to a local `quality-remediator` sub-agent when EITHER:
- violation count for a single rule exceeds 10, OR
- violations span >3 modules across distinct first-level package directories

Sub-agents run in isolated worktrees with explicit file ownership; coordinate so no two
agents touch the same file. See `quality-remediator/SKILL.md` for the sub-agent contract.

## Gotchas

- **If a future slop rule appears without a routing entry: STOP and report** — do not guess.
- **Never disable a slop rule** — violations must be fixed, not silenced.
- **Never add `# noqa` to mask structural violations** — use inline comments with one-line justification only if truly unfixable.
- **Violation count must strictly decrease per round** — if it doesn't, the fix was ineffective.

Last Updated: 2026.05.04 @ 04:15:00

