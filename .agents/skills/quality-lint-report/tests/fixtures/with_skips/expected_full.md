## Slop Lint Report — `with_skips.json` (v0.7.0)

**Overall: FAIL — 1 errors, 0 advisories** (1 total)
2 rules checked, 2 skipped (`orphans`, `future_rule`)

### Rule Summary

| Rule | Status | Violations | Scope |
|---|---|---|---|
| `complexity.cyclomatic` | FAIL | 1 | 50 functions |
| `class.coupling` | PASS | 0 | 20 classes |

### Top Actionable Issues

**Cyclomatic Complexity (1 errors)**
- `do_work` (`src/main.py`:20) — CCX=11 (threshold 10)

### Passes
`class.coupling` — all clean across 20 classes.
