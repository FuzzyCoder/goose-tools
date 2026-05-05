---
name: fix-deps-cycle
description: >-
  Remediate quality `deps` import-cycle violations by extracting shared symbols
  (types, exceptions, dataclasses, protocols) into a neutral `_types.py` or
  `_common.py` module that both ends import. Removes the cycle at module-import
  time, not via deferred imports. Triggers: quality-remediate routing, "import
  cycle", "circular import", "deps cycle", "PLC0415 noqa".
---
# fix-deps-cycle
## When to Use
- Quality reports a `deps` failure: 2-node or N-node import cycle
- A module uses `# noqa: PLC0415` deferred imports to dodge a cycle
- An agent has been routed by `quality-remediate` to fix a deps cycle

## Routing
Quality rule handled:
- `deps` (any import cycle)

For other dependency-graph metrics (Zone of Pain `packages`), see `fix-packages`.

## Playbook
1. Read both ends of the cycle. List exactly which symbols cross the boundary in each
   direction (types, dataclasses, exceptions, `Protocol`s, sentinel constants).
2. Pick the side that conceptually owns the type. Create a new neutral module in the same
   package (e.g. `pipeline_types.py`, `_common.py`, or `_protocols.py`) and move the
   shared symbols there.
3. Update both ends to import from the neutral module. Neither end imports from the other
   for those symbols.
4. Remove ONLY the deferred local imports tied to the resolved cycle (lines marked
   `# noqa: PLC0415` for that exact pair). Leave deferred imports for OTHER cycles intact.
5. Verify with `quality check deps --root . --output json`. The cycle should be gone.

## Anti-Patterns
- Adding `if TYPE_CHECKING:` blocks to keep the cycle but pass type checks — the runtime
  cycle remains.
- Adding `# noqa: PLC0415` to suppress the cycle warning without resolving it.
- Putting both ends behind a single `import_module` runtime call.
- Moving the import inside every function that uses the symbol — this scales poorly.

## Validation
- Re-run `quality check deps --root . --output json`; confirm 0 cycles for the touched
  package.
- Run pytest for both modules and any caller that imports the moved symbols.
- Run the `run-quality-checks` skill (ruff + ty).
- Grep for `# noqa: PLC0415` in the touched modules to confirm only unrelated entries
  remain.

## Gotchas
- **`if TYPE_CHECKING:` blocks keep the runtime cycle** — the cycle persists at execution time.
- **Moving imports inside functions does not scale** — extract to a neutral `_types.py` or `_common.py` module.
- **`import_module` runtime calls mask the cycle** — resolve at module-import time instead.
