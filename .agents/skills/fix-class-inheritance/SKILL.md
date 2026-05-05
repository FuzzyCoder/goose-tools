---
name: fix-class-inheritance
description: >-
  Remediate quality `class.inheritance.depth` (DIT > 4) and
  `class.inheritance.children` (NOC > 10) by flattening hierarchies, extracting
  composition helpers, and splitting overly broad bases into narrower protocols.
  Triggers: quality-remediate routing, "DIT too high", "NOC too high",
  "inheritance too deep", "too many subclasses".
---
# fix-class-inheritance
## When to Use
- Quality reports `class.inheritance.depth` (DIT > 4) for a class
- Quality reports `class.inheritance.children` (NOC > 10) for a base class
- An agent has been routed by `quality-remediate` to fix one of those rules

## Routing
Quality rules handled:
- `class.inheritance.depth` (DIT > 4)
- `class.inheritance.children` (NOC > 10)

For class-level WMC/CBO see `fix-class-complexity`. For function complexity
see `fix-complexity`.

## Playbook — DIT (depth)
1. Map the inheritance chain top-down. Identify the deepest leaf and the shared
   behavior that motivated each intermediate base.
2. Extract shared behavior into composition helpers, mixins-by-protocol, or stand-alone
   strategy functions. Prefer module-level helpers over a new base class.
3. Flatten by removing intermediate bases that exist only to share a method or two.
   Inline the shared method into a `_helper` or attach it via composition.
4. Never introduce inheritance solely to share implementation — prefer explicit
   composition and typed `Protocol`s.

## Playbook — NOC (children)
1. List every direct subclass of the offending base and group by the responsibility each
   subclass actually overrides.
2. Split the base into 2+ narrower protocols/strategy classes, each owned by a single
   responsibility group.
3. Re-anchor existing subclasses on whichever new base they actually need; delete bases
   they don't.
4. Confirm no subclass now multiply-inherits across the split protocols unless the
   intersection is intentional.

## Anti-Patterns
- Adding an empty intermediate base just to satisfy the metric.
- Renaming the parent class to hide it from the quality scan.
- Replacing inheritance with a generic abstract base that re-introduces the same depth
  one tier lower.
- Moving children into a sibling module to avoid the count without resolving the
  underlying responsibility split.

## Validation
- Re-run `quality check class.inheritance.depth --root . --output json` and
  `quality check class.inheritance.children --root . --output json`.
- Run targeted pytest for the touched modules.
- Run the `run-quality-checks` skill.
- Confirm no caller relies on a removed intermediate base via `isinstance` checks; if it
  does, replace with a `Protocol` or explicit type guard.

## Gotchas
- **Never introduce inheritance solely for code sharing** — use composition or protocols.
- **Renaming parent classes hides the metric** without resolving the problem.
- **`isinstance` checks on removed bases** will silently break at runtime — replace with
  Protocol or explicit type guards before deleting intermediate bases.
