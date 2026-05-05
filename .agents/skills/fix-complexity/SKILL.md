---
name: fix-complexity
description: >-
  Remediate quality `complexity.cyclomatic` (CCX > 10) and `complexity.cognitive`
  (CogC > 15) violations. Extract helpers, prefer guard clauses, remove dead
  defensive try/except. Triggers: quality-remediate routing, manual fix request,
  "complexity violation", "CCX too high", "CogC too high".
---
# fix-complexity
## When to Use
- Quality reports a `complexity.cyclomatic` or `complexity.cognitive` failure for any function
- An agent has been routed by `quality-remediate` to fix CCX or CogC for a specific symbol
- A user asks to lower complexity for a named function

## Routing
Quality rule prefixes handled:
- `complexity.cyclomatic` (CCX > 10)
- `complexity.cognitive` (CogC > 15)

For class-level WMC (`complexity.weighted`), see `fix-class-complexity`. For inheritance
(DIT/NOC), see `fix-class-inheritance`.

## Playbook
1. Read the function in full before touching it. Identify nested loops, if/elif chains,
   and try/except blocks that drive complexity.
2. Apply guard clauses and early returns at the top of production code where they preserve
   fail-fast behavior. Do NOT use `return None` or `return ()` to swallow setup failures
   in tests — extract setup helpers and assert/raise instead so failures remain visible.
3. Extract inner loop bodies and nested for/if chains into private `_helper(...)` functions
   in the same module. This reduces CogC, not just CCX.
4. Remove defensive `try/except` around code that provably cannot raise the caught
   exception in this call site (e.g. exception types from libraries that the call does not
   invoke). Surface real exceptions; do not catch and re-log.
5. Cap each function at 50 lines after the refactor. Move parameter validation to the top.

## Anti-Patterns
- Adding a `# noqa: PLR0911` or `# noqa: C901` to suppress the violation.
- Splitting one large function into many tiny one-liners that pass the metric but obscure
  the algorithm.
- Adding `try: ... except Exception: pass` or `except Exception: logger.warning(...)` to
  hide real failures.
- Early-returning from a test on a setup error (e.g. `if not df: return`) — this masks the
  failure and produces a falsely-passing test.

## Validation
- Re-run `quality check complexity.cyclomatic --root . --output json` (or
  `complexity.cognitive`) for the affected file.
- Run targeted pytest for the module that owns the refactored function.
- Run the `run-quality-checks` skill (`uv run ruff check .` and
  `uv run ty check`).
- If any test that was passing before the refactor now fails, revert and re-plan.

## Gotchas
- **`# noqa: PLR0911` or `# noqa: C901` suppresses without fixing** — violates zero-warnings policy.
- **Early-returning from tests on setup errors masks failures** — extract setup helpers instead.
- **Catching `Exception: pass` hides real failures** — surface real exceptions or re-raise with context.
