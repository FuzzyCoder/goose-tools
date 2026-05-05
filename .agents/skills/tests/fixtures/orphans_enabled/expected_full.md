## Slop Lint Report — `orphans_enabled.json` (v0.6.1)

**Overall: FAIL — 0 errors, 2 advisories** (2 total)
2 rules checked

### Rule Summary

| Rule | Status | Violations | Scope |
|---|---|---|---|
| `complexity.cyclomatic` | PASS | 0 | 50 functions |
| `orphans` | FAIL | 2 (warn) | 250 symbols |

### Top Actionable Issues

**Unreferenced Symbols — `orphans` (2 advisory warnings)**
- `extract_pii_features` (`anonymous/extract.py`:42) — 0 references (high confidence)
- `format_note_id` (`anonymous/utils.py`:17) — 0 references (high confidence)

### Passes
`complexity.cyclomatic` — all clean across 50 functions.
