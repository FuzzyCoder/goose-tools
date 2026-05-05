---
name: quality-lint-report
description: >-
  Run the code-quality linter and write timestamped compact and full Markdown
  reports. Use when asked to "run slop", "generate report", or "actionable
  issues". Not for fixing violations (use quality-remediate) or ad-hoc lint
  without reports.
---

# quality-lint-report

## When to Use

- To run slop lint and produce compact + full Markdown reports in one shot
- Produces three timestamped files and updates three stable symlinks per run
- `--check` scoped lint is **deferred** — not available in this version

## CLI

```bash
.agents/skills/quality-lint-report/scripts/generate_report.sh
```

**Standard run (project root = `.`):**
```bash
.agents/skills/quality-lint-report/scripts/generate_report.sh
```

**Specify a different project root:**
```bash
.agents/skills/quality-lint-report/scripts/generate_report.sh --root /path/to/project
```

**Specify a different project root and enable orphans detection:**
```bash
.agents/skills/quality-lint-report/scripts/generate_report.sh --root /path/to/project --orphans
```

**Flags:**
- `--root <path>` — project root for the slop runner. Defaults to `.`.
- `--orphans` — enable the `orphans` (unreferenced symbols) rule via deep-merged runtime config. Runs may be slow on large codebases (see "How `--orphans` works internally" below).

The shell wrapper resolves its own directory and delegates to `generate_report.py`
via `uv run python`, propagating the script's exit code.

## Outputs per run

`ts = YYYYMMDD_HHMMSS` is generated once at the start of each invocation.

Three timestamped files are written inside a per-run subdirectory:
- `.slop/slop_lint_{ts}/slop_lint_{ts}.json` — raw slop JSON
- `.slop/slop_lint_{ts}/slop_lint_{ts}.md` — compact 3-column violations table
- `.slop/slop_lint_{ts}/slop_lint_full_{ts}.md` — full per-rule actionable report

Three symlinks are created/updated at the `.slop/` root after each run:
- `.slop/slop_lint.json` → `slop_lint_{ts}/slop_lint_{ts}.json`
- `.slop/slop_lint.md` → `slop_lint_{ts}/slop_lint_{ts}.md`
- `.slop/slop_lint_full.md` → `slop_lint_{ts}/slop_lint_full_{ts}.md`

On each run, two migration steps are applied automatically:
1. Any existing regular files at the three stable symlink paths (e.g. a legacy
   `slop_lint.json` from before symlinks were introduced) are removed and replaced
   with symlinks pointing into the new run subdirectory.
2. Orphaned flat-layout timestamped artifacts at the `.slop/` root — regular files
   (not symlinks) matching `slop_lint_*.json`, `slop_lint_*.md`, or
   `slop_lint_full_*.md` — are auto-deleted before the new run's Markdown files are
   written. Existing run subdirectories (`slop_lint_*/`) are left untouched.

## Compact Report Format

Output: `.slop/slop_lint_{ts}.md`

```
# slop_lint_{ts}.json — Violations by Rule

| Rule | Errors | Advisories |
|---|---|---|
| {rule} | {errors} | {advisories} |
...
| **Total** | **{violation_count}** | **{advisory_count}** |

(Note: …)
```

Format rules:
- Error partition rendered first; advisory-only partition last; both in JSON file order.
- Zero values → `—` (U+2014); non-zero → plain integer.
- Footer note includes Sentence A (rules with 0 violations) and Sentence B (advisory counts) when applicable.
- Output ends with exactly one `\n`.

## Full Report Format

Output: `.slop/slop_lint_full_{ts}.md`

Four sections rendered in order:

### 1. Header Block

```
## Slop Lint Report — `slop_lint_{ts}.json` (v{version})

**Overall: {RESULT} — {violation_count} errors, {advisory_count} advisories** ({total} total)
{rules_checked} rules checked[, {rules_skipped} skipped (`{skip_names}`)]
```

The parenthetical skip clause is omitted when `rules_skipped == 0`.

### 2. Rule Summary (`### Rule Summary`)

4-column table `| Rule | Status | Violations | Scope |`.
- All non-skip rules included (pass rules show `0`; skip rules excluded).
- Advisory-only rules show `{n} (warn)` in Violations.
- Rules appear in JSON file order.

**Per-rule scope strings:**
- `complexity.cyclomatic`, `complexity.cognitive`: `{functions_checked:,} functions`
- `complexity.weighted`: `{classes_checked:,} classes`
- `halstead.volume`, `halstead.difficulty`, `npath`: `{functions_checked:,} functions`
- `hotspots`: `{files_analyzed} files ({window_since.replace(" ago", "")} window)`
- `packages`: `{packages_analyzed} packages`
- `deps`: `{files_analyzed:,} files (import cycles)`
- `class.coupling`, `class.inheritance.depth`, `class.inheritance.children`: `{classes_checked:,} classes`
- `orphans`: `{symbols_analyzed:,} symbols`

### 3. Top Actionable Issues (`### Top Actionable Issues`)

One sub-section per rule with ≥1 violation, in JSON file order. ALL violations included.

**Per-rule rendering templates:**
- `deps` — `**Import Cycles (\`deps\` — {n} errors)**`; 2-node: `\`f1\` ↔ \`f2\` (2-node cycle)`; ≥3-node: `\`f1\` → … → \`fN\` (N-node cycle)` (basenames from `metadata.cycle`)
- `hotspots` — `**Hotspots — high churn × high complexity ({n} errors, {window_since})**`; `- \`{file}\` — CCX={sum_ccx}, +{loc_delta} LOC, score={value:,.0f}`; max-value entry gets ` ⚠ worst`
- `complexity.weighted` — `**Weighted Method Complexity — WMC ({n} errors)**`; `- \`{symbol}\` — WMC={value:.0f} ({method_count} methods, threshold {threshold})`
- `halstead.volume` — `**Halstead Volume ({n} errors)**`; `- \`{symbol}\` — vol={value:,.0f} (threshold {threshold:,})`; max-value entry gets ` — highest in codebase`
- `packages` — `**Zone of Pain packages ({n} advisory warnings)**`; single sub-line: `Low instability + low abstractness: \`pkg1\`, \`pkg2\`, …`
- `complexity.cyclomatic` — `**Cyclomatic Complexity ({n} errors)**`; `- \`{symbol}\` (\`{file}\`:{line}) — CCX={value} (threshold {threshold})`
- `complexity.cognitive` — `**Cognitive Complexity ({n} errors)**`; `- \`{symbol}\` (\`{file}\`:{line}) — cognitive={value} (threshold {threshold})`
- `halstead.difficulty` — `**Halstead Difficulty ({n} errors)**`; `- \`{symbol}\` (\`{file}\`:{line}) — difficulty={value:.2f} (threshold {threshold})`
- `npath` — `**NPATH ({n} errors)**`; `- \`{symbol}\` (\`{file}\`:{line}) — NPATH={value:,} (threshold {threshold:,})`
- `orphans` — `**Unreferenced Symbols — \`orphans\` (N advisory warnings)**`; one bullet per violation: `` - `{symbol}` (`{file}`:{line}) — {value} references ({confidence} confidence) `` reading `symbol`, `file`, `line`, `value` from top-level fields and `confidence` from `metadata.confidence`. Fallbacks: if `line` is missing/null, omit `:{line}`; if `symbol` is missing, render `` `{file}`:{line} `` as the primary identifier; if `confidence` is missing, omit the `({confidence} confidence)` parenthetical.

### 4. Passes (`### Passes`)

Pass rules in JSON file order, Oxford-comma-joined with backtick quoting.
If all pass rules share the same scope value: `{rules} — all clean across {scope}.`
Otherwise: one line per rule with its individual scope.
If no pass rules: `(no passing rules)`

## How `--orphans` works internally

When `--orphans` is passed:
1. At runtime the script reads the project's `.slop.toml` (or `pyproject.toml [tool.slop]` if no `.slop.toml` is present). If neither exists, an empty base is used.
2. It deep-merges `[rules.orphans] enabled = true` (plus `min_confidence = "high"` and `severity = "warning"`) over the base config. This preserves the project's `exclude` list, custom thresholds, and all other rule settings.
3. The merged result is written to a temporary `.toml` file.
4. `slop lint --config <tempfile>` is invoked via `skill.sh run`.
5. The tempfile is deleted unconditionally in a `finally` block after the subprocess exits or raises.
6. No subprocess timeout is enforced — runs on codebases with many symbol definitions may hang. This is the same rationale recorded in the project's existing `.slop.toml` (`O(N) rg subprocess per symbol`). Users invoking `--orphans` accept this risk explicitly.

## Validation Rules

The generator raises `ValueError` immediately (fail-fast) for:

- JSON parse failure (chained with `raise … from e`)
- Missing `rules` object or `summary.violation_count` / `summary.advisory_count`
- Any rule `status` outside `{pass, fail, skip}`
- Any `violations[].severity` outside `{error, warning}`
- Per-rule computed counts that do not match the top-level summary totals

## Gotchas

- **`--orphans` runs may hang on large codebases** — the subprocess has no timeout (`O(N) rg subprocess per symbol`).
- **Stable symlinks are created/updated after each run** — legacy flat files at symlink paths are auto-migrated.
- **Orphaned flat-layout timestamped artifacts are auto-deleted** — run subdirectories are left untouched.

Last Updated: 2026.05.04 @ 04:15:00
