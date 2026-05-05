---
name: fix-packages
description: >-
  Remediate quality `packages` advisories by introducing minimal abstract interface
  modules for Zone of Pain packages (high stability + low abstractness) and by
  deleting unused interfaces in the Uselessness zone. Python only. Triggers:
  quality-remediate routing, "packages advisory", "zone of pain", "low abstractness".
---
# fix-packages
## When to Use
- Quality reports a `packages` advisory for a Python package
- An agent has been routed by `quality-remediate` to address a packages advisory
- A user asks to lower a package's distance from the main sequence

## Routing
Quality rule handled:
- `packages` (advisory: Zone of Pain or Uselessness zone)

For function or class metrics see the dedicated `fix-complexity`,
`fix-class-complexity`, `fix-class-inheritance`, or `fix-halstead` skills.

## Playbook — Zone of Pain (high stability + low abstractness)
1. Identify the public concrete classes the package exposes that other packages depend on.
2. Introduce a minimal abstract interface module in the package:
   - File: `_protocols.py`
   - Define only the public contract (`Protocol`, `ABC`, or typed dataclass) that
     downstream callers actually use.
3. Update the concrete implementation to register against / inherit from / implement that
   interface. Update downstream callers to import from `_protocols.py` instead of the
   concrete module.
4. Re-run `quality check packages --root .`; the package should move toward the main sequence.

## Playbook — Uselessness zone (high abstractness, low instability)
1. Identify abstract classes / `Protocol`s with no concrete implementations actively used.
2. Delete the speculative interface and any orphaned ABC/Protocol modules.
3. If a single concrete class remains, drop the abstract layer entirely and let callers
   depend on the concrete class.

## Constraints
- `packages` runs Python only. For other languages use `dependency-cruiser` manually.
- Do NOT introduce a new abstract layer just to satisfy the metric — only when it
  reflects a real public contract.
- Do NOT promote private helpers to abstract interfaces solely to lower the score.

## Anti-Patterns
- Adding an empty `_protocols.py` with no methods to game the metric.
- Wrapping every package in an abstract base class — this raises CBO elsewhere and adds
  ceremony without value.
- Moving the concrete class into the abstract module rather than alongside it.

## Validation
- Re-run `quality check packages --root . --output json` for the touched package.
- Run pytest for the touched package and any caller that imports the changed contract.
- Run the `run-quality-checks` skill.
- Confirm no caller still imports the concrete class from the old path if you've split
  it; update imports in one pass.

## Gotchas
- **Adding an empty `_protocols.py` with no methods** games the metric without adding value.
- **Wrapping every package in an abstract base class** raises CBO elsewhere and adds ceremony.
- **Moving the concrete class into the abstract module** rather than alongside it confuses ownership.
