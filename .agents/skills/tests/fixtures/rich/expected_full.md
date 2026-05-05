## Slop Lint Report — `rich.json` (v0.7.0)

**Overall: FAIL — 13 errors, 2 advisories** (15 total)
12 rules checked, 1 skipped (`orphans`)

### Rule Summary

| Rule | Status | Violations | Scope |
|---|---|---|---|
| `complexity.cyclomatic` | FAIL | 2 | 200 functions |
| `complexity.cognitive` | FAIL | 1 | 200 functions |
| `complexity.weighted` | FAIL | 2 | 50 classes |
| `halstead.volume` | FAIL | 2 | 180 functions |
| `halstead.difficulty` | FAIL | 1 | 180 functions |
| `npath` | FAIL | 1 | 180 functions |
| `hotspots` | FAIL | 2 | 30 files (7 days window) |
| `packages` | FAIL | 2 (warn) | 15 packages |
| `deps` | FAIL | 2 | 100 files (import cycles) |
| `class.coupling` | PASS | 0 | 50 classes |
| `class.inheritance.depth` | PASS | 0 | 50 classes |
| `class.inheritance.children` | PASS | 0 | 50 classes |

### Top Actionable Issues

**Cyclomatic Complexity (2 errors)**
- `run_pipeline` (`src/pipeline.py`:10) — CCX=15 (threshold 10)
- `parse_config` (`src/utils.py`:5) — CCX=12 (threshold 10)

**Cognitive Complexity (1 errors)**
- `run_pipeline` (`src/pipeline.py`:10) — cognitive=22 (threshold 15)

**Weighted Method Complexity — WMC (2 errors)**
- `Pipeline` — WMC=55 (10 methods, threshold 40)
- `Evaluator` — WMC=42 (8 methods, threshold 40)

**Halstead Volume (2 errors)**
- `run_pipeline` — vol=3,000 (threshold 1,500) — highest in codebase
- `parse_config` — vol=1,800 (threshold 1,500)

**Halstead Difficulty (1 errors)**
- `parse_config` (`src/utils.py`:5) — difficulty=35.50 (threshold 30)

**NPATH (1 errors)**
- `run_pipeline` (`src/pipeline.py`:10) — NPATH=500 (threshold 400)

**Hotspots — high churn × high complexity (2 errors, 7 days ago)**
- `src/pipeline.py` — CCX=200, +500 LOC, score=100,000 ⚠ worst
- `src/evaluator.py` — CCX=80, +200 LOC, score=16,000

**Zone of Pain packages (2 advisory warnings)**
Low instability + low abstractness: `src/core`, `src/utils`

**Import Cycles (`deps` — 2 errors)**
- `pipeline.py` ↔ `pipeline_execution.py` (2-node cycle)
- `services.py` → `preflight.py` → `runner.py` (3-node cycle)

### Passes
`class.coupling`, `class.inheritance.depth`, and `class.inheritance.children` — all clean across 50 classes.
