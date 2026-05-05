---
name: manage-inventory
description: >-
  Regenerate or create INVENTORY.md for this repo. Uses `bin/goose-tools inventory`
  in goose-tools repos; agent-native fallback with tracked/untracked labels and
  divergence semantics in others. Shows diff and confirms before overwriting.
  Triggers: "update INVENTORY.md", "regenerate inventory", "regenerate
  INVENTORY.md", "refresh file inventory", "refresh inventory",
  "create INVENTORY.md". Do NOT use for TODO generation (use manage-todo)
  or capabilities maps (use manage-capabilities).
---
# manage-inventory

## When to Use
- Create or refresh INVENTORY.md in the current repo
- Triggers: "update INVENTORY.md", "regenerate inventory", "refresh file inventory",
  "refresh inventory", "create INVENTORY.md"
- NOT for quality reports, TODO files, or capabilities maps

## Autonomy Gates
Before writing INVENTORY.md:
1. Generate content into an in-memory buffer
2. Show diff: `+N lines / -N lines` vs existing file, or `(new file)` if absent
3. Ask: "Overwrite INVENTORY.md? (yes / no)"
4. Proceed only on explicit "yes" — abort on anything else

## Playbook

### 1 — Detect layout
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
```
Check ALL three files exist: `$REPO_ROOT/bin/goose-tools`, `$REPO_ROOT/bin/commands/inventory.sh`,
`$REPO_ROOT/bin/commands/todo.sh`.

**CLI path (all three present):** run `bin/goose-tools inventory` — it writes INVENTORY.md directly
using the canonical format; follow Autonomy Gates separately then stop.

**Fallback path (any file missing):** proceed with steps 2–6.

### 2 — Collect files (fallback)
Walk with `find "$REPO_ROOT" -type f` excluding: `.git`, `__pycache__`, `.venv`,
`.ruff_cache`, `.pytest_cache`, `.tox`, `node_modules`, `.mypy_cache`, `*.pyc`, `.DS_Store`.
Sort results.

- `total_count` = file count from walk
- `tracked_count` = `git -C "$REPO_ROOT" ls-files | wc -l | tr -d ' '`
- `div_pct` = `abs(total_count − tracked_count) / tracked_count × 100` (integer, guard ÷0)

### 3 — Per-file metadata (fallback)
For each file `$f`, relative path `$rel = ${f#$REPO_ROOT/}`:
- **size:** `stat -f%z "$f"` (macOS) or `stat -c%s "$f"` (Linux)
- **lines:** `wc -l < "$f" | tr -d ' '`
- **mtime epoch:** `git log -1 --format=%ct -- "$rel"` (fallback: `stat -f%m`/`-c%Y`)
- **ts:** `date -r $epoch '+%Y-%m-%d %H:%M'` (macOS) or `date -d "@$epoch" '+%Y-%m-%d %H:%M'`
- **tracked_tag:** `""` if `git ls-files --error-unmatch "$rel"` exits 0, else `" [untracked]"`
- **entry line:** `  - \`$rel\` ($size bytes, $lines lines, $ts)$tracked_tag`

### 4 — Bucket into sections (fallback)
Map each `$rel` to a section — first matching pattern wins:

| Pattern | Section |
|---|---|
| `AGENTS.md`, `README.md`, `LICENSE`, `pyproject.toml`, `uv.lock`, `.gitignore`, `.slop.toml` | Project Root |
| `docs/*` | Documentation |
| `bin/*` | CLI & Scripts |
| `.github/workflows/*`, `.pre-commit-config.yaml`, `.shellcheckrc` | CI/CD |
| `tests/*` | Tests |
| `utils/*` | Utilities |
| `scripts/*` | Setup Scripts |
| `.agents/skills/*` | Skills (special — see step 5) |
| `warp/*` | Warp Drive Assets |
| `*` | Other |

Canonical section order: Project Root → Documentation → CLI & Scripts → Warp Drive Assets →
Skills → Tests → Utilities → Setup Scripts → CI/CD → Other.

**Generic section descriptions (fallback only):**

| Section | Description |
|---|---|
| Project Root | Root-level configuration, licensing, and dependency management files. |
| Documentation | Operator guides, reference docs, and workflow documentation under `docs/`. |
| CLI & Scripts | Shell entry points and command modules under `bin/`. |
| Warp Drive Assets | Warp notebooks, workflows, and runtime scripts (when present). |
| Skills | Portable agent skills under `.agents/skills/`. |
| Tests | Test suites under `tests/`. |
| Utilities | Shared utility code under `utils/`. |
| Setup Scripts | Standalone setup/helper scripts under `scripts/`. |
| CI/CD | GitHub Actions workflows and linter configuration. |
| Other | Everything that does not fit another section, including generated artifacts (`INVENTORY.md`, `TODO.md`). |

### 5 — Skills section (fallback)
Emit `## Skills\nPortable agent skills under \`.agents/skills/\`.\n`.
For each skill directory (sorted by name):
1. `### <skill-name>`
2. Parse description from `SKILL.md` YAML frontmatter (`description:` key; handle `>-` folded blocks
   by stripping leading whitespace and joining continuation lines with a space)
3. List files in order: `SKILL.md` first, then `references/*` (sorted), `scripts/*` (sorted),
   `tests/*` (sorted), all other files (sorted)

### 6 — Render header and footer (fallback)
**File header:**
```
# <repo-name> Repository Inventory

Last Updated: YYYY-MM-DD HH:MM:SS UTC

---

Generated: YYYY-MM-DD HH:MM:SS UTC
Source: git-tracked + untracked files (excluding .git, __pycache__, .pyc, .DS_Store)

## Summary

- **Total files:** <total_count>
- **Git-tracked:** <tracked_count>
- **Divergence:** <div_pct>% (threshold: 5%)
```
Where `<repo-name>` = `basename "$(git rev-parse --show-toplevel)"`.

**Section block format:**
```
## <Title>
<description>

  - `rel/path` (N bytes, N lines, YYYY-MM-DD HH:MM)

```

**File footer:**
```
---

Last Updated: YYYY.MM.DD @ HH:MM:SS
```

### 7 — Divergence warning
If `div_pct > 5`: surface in the skill response only: `⚠ Divergence is N% (>5% threshold).`
Do NOT alter INVENTORY.md content based on the threshold.

## Anti-Patterns
- Skipping the diff + confirm gate — always show before overwriting
- Running CLI shortcut when any of the three required files is absent
- Using goose-tools-specific section descriptions in fallback mode
- Using `__pycache__` paths or absolute machine paths in entries

## Validation
- Header contains `Generated:` line and `Source:` line
- `## Summary` has all three bullets including `Divergence:`
- Sections appear in canonical order; no section appears twice
- Skills section has one `###` subsection per directory in `.agents/skills/`

## Gotchas
- **macOS vs Linux `stat`** — chain `-f%z`/`-f%m` (macOS) before `-c%s`/`-c%Y` (Linux)
- **Untracked files** — `git log` returns empty epoch (0); always fall back to filesystem mtime
- **CLI header predates header-pattern rule** — the goose-tools shortcut path will have a
  different header format than the fallback; this divergence is expected and out of scope
- **Empty skills directory** — if `.agents/skills/` has no subdirectories, omit the Skills section

Last Updated: 2026.05.04 @ 19:02:31
