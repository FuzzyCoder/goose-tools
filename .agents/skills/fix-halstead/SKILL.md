---
name: fix-halstead
description: >-
  Remediate quality `halstead.volume` (V > 1500) and `halstead.difficulty` (D > 30)
  by extracting named sub-functions from monolithic builders, hoisting repeated
  operator patterns to helpers, and pulling shared mock data into pytest fixtures
  or module-level constants. Triggers: quality-remediate routing, "halstead volume",
  "halstead difficulty", "function vocabulary too large", "test difficulty too high".
---
# fix-halstead
## When to Use
- Quality reports `halstead.volume` failure for a function (V > 1500)
- Quality reports `halstead.difficulty` failure for a function (D > 30)
- An agent has been routed by `quality-remediate` to fix one of those rules

## Routing
Quality rules handled:
- `halstead.volume` (V > 1500)
- `halstead.difficulty` (D > 30)

For function CCX/CogC see `fix-complexity`. For class WMC see
`fix-class-complexity`.

## Playbook — Volume
1. Read the full function. Identify cohesive sub-sections (CLI argument groups, NiceGUI
   tab regions, Word doc style/header/footer blocks, pipeline phases, report sections).
2. Extract each section as a private named helper in the same module: `_build_<section>`,
   `_add_<group>_args(parser)`, `_phase_<n>_<name>(...)`. Pass the parent's mutable state
   (e.g. `parser`, `ui_state`, `wb`) explicitly.
3. Each extracted helper should have a single clear purpose and reduce the operator/operand
   vocabulary of the parent. Aim for parent V ≤ 1500 after the split.
4. For test fixtures: hoist repeated `Mock(...)` chains and dict literals into a
   module-level `_MOCK_<NAME>` constant or a `pytest.fixture`. Tests should call the
   fixture, not inline the dict structure.

## Playbook — Difficulty
1. Difficulty rises with repeated operator patterns. Spot dict-key access chains, repeated
   assertion shapes, and string-building loops.
2. Replace repeated dict-key sequences with a typed dataclass or a helper that takes named
   keyword args.
3. For tests: extract assertion shapes into a helper like `_assert_charge_row(row, ...)`.
   Each repetition then collapses to a single call.
4. Re-run `quality check halstead.difficulty --root .` for the affected file.

## Anti-Patterns
- Splitting purely by line count without semantic grouping (e.g. "first 50 lines, second
  50 lines"); the metric improves but readability collapses.
- Inlining the same dict literal 10 times in a test, then suppressing the metric.
- Replacing one helper with five micro-helpers that pass the metric but require the reader
  to chase five hops.
- Moving complexity behind a `kwargs` dict that hides the operand count.

## Validation
- Re-run `quality check halstead.volume --root . --output json` (or `halstead.difficulty`)
  for the affected file.
- Run targeted pytest for the module that owns the function.
- Run the `run-quality-checks` skill.
- For test refactors: confirm the same number of test cases run before and after the
  fixture extraction.

## Gotchas
- **Splitting by line count without semantic grouping** collapses readability while gaming the metric.
- **Replacing one helper with five micro-helpers** forces the reader to chase five hops.
- **Hiding operand count behind `kwargs` dicts** passes the metric but obfuscates intent.
