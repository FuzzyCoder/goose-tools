---
name: fix-orphans
description: >-
  Remediate quality `orphans` (unreferenced symbols) by confirming the symbol is
  truly dead with import-aware search, then deleting code + tests + docs together.
  Keep dynamic-reference shims only when a public API contract demands it.
  Triggers: quality-remediate routing, "orphan symbol", "dead code", "unreferenced".
---
# fix-orphans
## When to Use
- Quality reports an `orphans` advisory for a symbol (function, class, constant)
- An agent has been routed by `quality-remediate` to address an orphan
- A user asks to delete dead code surfaced by `quality --orphans`

## Routing
Quality rule handled:
- `orphans` (unreferenced symbols)

For other dependency-graph concerns see `fix-deps-cycle` (cycles) or
`fix-packages` (Zone of Pain).

## Playbook
1. Confirm the symbol is truly unreferenced before deletion. Search exhaustively:
   - Exact grep across the repo: `grep -rn "<symbol>" --include="*.py" --include="*.md" .`
   - Import-aware search: look for `from <module> import <symbol>` and `<module>.<symbol>`
   - Dynamic references: search for the symbol as a string literal in `getattr`,
     `importlib.import_module`, registry dicts, entry points, or config files.
2. If the symbol IS used dynamically (registered in a plugin map, referenced as a string,
   resolved via `entry_points`), document the dynamic reference path in a comment near
   the definition AND add a targeted test that exercises that path.
3. If the symbol is truly dead, delete:
   - The definition.
   - All tests that reference the symbol.
   - All docs that reference the symbol (README, ARCHITECTURE, skill docs).
   - Any imports that pull in the now-empty module.
4. Do NOT keep `compatibility shims` (`from .new_module import symbol as old_name`)
   unless an external public API contract requires it. Internal callers can be updated
   in one pass.
5. Re-run quality with orphans enabled and confirm the symbol is gone:
   `./.agents/skills/quality-lint-report/scripts/generate_report.sh --orphans`

## Anti-Patterns
- Deleting a symbol without first confirming dynamic reference paths (string literals,
  registries, entry points).
- Keeping a `def old_name(*args, **kwargs): return new_name(*args, **kwargs)` shim that
  no one calls.
- Removing the test along with the symbol but leaving the docs reference.
- Adding `__all__ = ["symbol"]` to suppress the orphans warning without resolving it.

## Validation
- Re-run quality with `--orphans`; confirm the symbol no longer appears.
- Run the full pytest suite (or at minimum the modules that imported the deleted symbol).
- Run the `run-quality-checks` skill (ruff exits 0; ty has no new diagnostics).
- Grep one more time post-deletion for any leftover references in markdown, comments,
  or skill docs.

## Gotchas
- **Deleting a symbol without checking dynamic references** breaks plugin maps and entry points.
- **Keeping `def old_name(*args, **kwargs): return new_name(*args, **kwargs)` shims** that no one calls adds dead code.
- **Removing tests but leaving docs references** causes confusion for future maintainers.
