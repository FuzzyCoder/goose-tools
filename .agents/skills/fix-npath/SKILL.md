---
name: fix-npath
description: >-
  Remediate quality `npath` (combinatorial path explosion, threshold 400) by
  decomposing nested if/elif chains into a dispatch dict, `match` statement,
  or named case handlers. Triggers: quality-remediate routing, "npath too high",
  "path explosion".
---
# fix-npath
## When to Use
- Quality reports an `npath` failure for a function (NPATH > 400)
- An agent has been routed by `quality-remediate` to address an npath violation
- A user asks to flatten a deeply branching function before quality flags it

## Routing
Quality rule handled:
- `npath` (combinatorial path explosion)

For raw cyclomatic see `fix-complexity`. For function vocabulary see `fix-halstead`.

## Playbook
1. Read the function and tally each branching decision: every `if/elif`, ternary,
   `and`/`or` short-circuit, and `try/except` arm contributes to NPATH multiplicatively.
2. Identify the dispatch axis. Most violations are one large axis (e.g. file kind, event
   type, tab name) that drives the branching.
3. Decompose into:
   - A main dispatch function that resolves the axis to a key.
   - Named case handlers per key: `_handle_<case>(...)`.
   - A dispatch dict or `match` statement that maps key → handler.
4. For functions with multiple orthogonal branching axes, split first by the outer axis
   (yielding several focused inner functions), then apply the dispatch pattern within
   each.
5. Re-run `quality check npath --root . --output json`; aim for parent NPATH ≤ 400.

## Anti-Patterns
- Replacing `if/elif` with chained `or` operators that count the same in NPATH.
- Hiding branches inside a default-arg lambda.
- Splitting purely into many tiny one-liners (each branch becomes its own micro-function)
  without a coherent dispatch axis — readability collapses.
- Catching all exceptions in one big `try/except` to hide branching.

## Validation
- Re-run `quality check npath --root . --output json` for the affected file.
- Run pytest for the module that owns the function.
- Run the `run-quality-checks` skill.
- Confirm test coverage exercises each new dispatch branch (no dead handlers).

## Gotchas
- **Replacing `if/elif` with chained `or` operators** counts the same in NPATH.
- **Hiding branches inside default-arg lambdas** doesn't reduce complexity — it obscures it.
- **Splitting into many tiny one-liners** without a coherent dispatch axis collapses readability.
