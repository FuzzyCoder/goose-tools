---
name: fix-class-complexity
description: >-
  Remediate quality `complexity.weighted` (WMC > 40) and `class.coupling` (CBO > 8)
  by splitting classes along field-write ownership, extracting collaborators
  behind protocols, and avoiding inheritance-based splits. Triggers: quality-remediate
  routing, "WMC too high", "CBO too high", "class is doing too much".
---
# fix-class-complexity
## When to Use
- Quality reports `complexity.weighted` (WMC) failure for a class
- Quality reports `class.coupling` (CBO) failure for a class
- An agent has been routed by `quality-remediate` to fix one of those rules

## Routing
Quality rules handled:
- `complexity.weighted` (WMC > 40)
- `class.coupling` (CBO > 8)

For function-level CCX/CogC see `fix-complexity`. For DIT/NOC inheritance issues
see `fix-class-inheritance`.

## Playbook — WMC
1. List every method, group by which instance fields it WRITES (not reads). Each write-set
   is a candidate collaborator class or private helper module.
2. Preserve invariants the original class enforced: public API surface, constructor
   validation, transaction boundaries, exception types, state ownership.
3. Move methods together with the fields they own. Do not scatter related state.
4. If the original class becomes empty, delete it. Do NOT leave a
   `class OldName(NewName): pass` shim. Update all callers in one pass.
5. Re-run `quality check complexity.weighted --root .`; expected per-class WMC ≤ 40.

## Playbook — CBO
1. Identify outgoing call sites by import; group by collaborator package.
2. Extract a thin protocol or facade in a `_protocols.py` module inside the most-coupled
   package. Both sides import from `_protocols.py`, not from each other.
3. Confirm CBO drop does not raise fan-in for any helper above the same threshold (8).
4. Re-run `quality check class.coupling --root .`.

## Anti-Patterns
- Wrapping the class with a `Manager` or `Coordinator` parent — that increases CBO and
  produces god-class drift.
- Splitting via inheritance (`class FooReader(Foo): ...`) — raises DIT and shifts metric
  to a different rule.
- Moving methods to a free function that re-imports the class instance — reduces WMC but
  increases CBO.
- Hiding write semantics behind a property to dodge the metric.

## Validation
- Re-run `quality check complexity.weighted --root . --output json` and
  `quality check class.coupling --root . --output json` for the touched modules.
- Run targeted pytest for tests covering the class.
- Run the `run-quality-checks` skill.
- Confirm no public API change for downstream callers; if a public method moved, update
  its old call sites in one pass and rerun the test suite for those callers.

## Gotchas
- **Splitting by method count is wrong** — group by field-write ownership instead.
- **Adding a Manager wrapper increases CBO** — extract protocols, don't wrap.
- **Inheritance splits raise DIT** — use composition over inheritance.
