---
name: manage-todo
description: >-
  Regenerate or create TODO.md for this repo. Delegates to `bin/goose-tools todo`
  when available; agent-native fallback with P0/P1/P2 layout and snapshot-diff
  semantics otherwise. Shows diff and confirms before overwriting.
  Triggers: "update TODO.md", "update TODO", "regenerate TODO.md",
  "regenerate TODO", "refresh TODO list", "refresh quality snapshot",
  "create TODO.md". Do NOT use for file inventory (use manage-inventory)
  or capabilities maps (use manage-capabilities).
---
# manage-todo

## When to Use
- Create or refresh TODO.md in the current repo
- Triggers: "update TODO.md", "regenerate TODO", "refresh TODO list",
  "refresh quality snapshot", "create TODO.md"
- NOT for file inventory, quality lint reports, or capabilities maps

## Autonomy Gates
Before writing TODO.md:
1. Generate content into an in-memory buffer
2. Show diff: `+N lines / -N lines` vs existing file, or `(new file)` if absent
3. Check snapshot-diff guard (step 4) and surface any `[SNAPSHOT]` warnings
4. Ask: "Overwrite TODO.md? (yes / no)"
5. Proceed only on explicit "yes" — abort on anything else

## Playbook

### 1 — Detect layout
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
```
Check ALL three: `$REPO_ROOT/bin/goose-tools`, `$REPO_ROOT/bin/commands/inventory.sh`,
`$REPO_ROOT/bin/commands/todo.sh`.

**CLI path (all three present):** run `bin/goose-tools todo` — it writes TODO.md directly;
follow Autonomy Gates separately then stop.

**Fallback path (any file missing):** proceed with steps 2–5.

### 2 — Run quality tools (fallback)
Run each tool only when its prerequisite is met. Capture `quality_findings` as a block.

**Ruff** (if `pyproject.toml` exists and `command -v ruff`):
```bash
ruff check . 2>/dev/null | head -50
```
Prefix block with `## Ruff\n` when non-empty.

**ty** (if `pyproject.toml` exists and `command -v ty`):
```bash
ty check . 2>/dev/null | head -50
```
Prefix block with `## ty\n` when non-empty.

**Shellcheck** (if `command -v shellcheck`):
Find all `*.sh` files plus bare `goose-tools` entry script (when present), excluding `.git/`
and `__pycache__/`. Run:
```bash
shellcheck -x --severity=warning -e SC1090,SC1091,SC2034,SC2015 <files> 2>/dev/null | head -40
```
Prefix block with `## Shellcheck\n` when non-empty.

**Slop lint** (if `.slop.toml` exists):
Prefer `uv run slop lint` (if `command -v uv`), fallback to `slop lint` (if `command -v slop`).
```bash
cd "$REPO_ROOT" && uv run slop lint 2>/dev/null | head -40
```
Prefix block with `## Slop Lint\n` when non-empty. Do NOT route through `agent-quality-lint`.

### 3 — Long-function heuristic (fallback)
Find functions >100 lines. Capture `length_findings`.

**Shell files** — awk pattern: match lines like `funcname() {`; count lines until `}` at
column 0; emit filename when count > 100. Prefix with `### Shell Functions >100 Lines\n`.

**Python files** — awk pattern: match `def <name>(` lines; count until next `def` or `class`;
emit filename when count > 100. Prefix with `### Python Functions >100 Lines\n`.

### 4 — Snapshot-diff guard (fallback)
Compare checklist items (`^  - \[ \]`) in existing `TODO.md` vs newly generated buffer.
For each item removed:
1. Extract keyword: first two words, strip non-alphanumeric chars, cap at 40 chars
2. Search: `git -C "$REPO_ROOT" log --oneline --since='24 hours ago' --grep="$keyword"`
3. If no matching commit found, surface in skill response:
   `  [SNAPSHOT] Removed item without matching commit: <item>` (two leading spaces)
Do NOT insert these warnings into TODO.md.

### 5 — Render TODO.md (fallback)
Construct output with NO trailing `Last Updated:` line — the header is the only timestamp.

**Header:**
```
# <repo-name> — TODO & Recommendations

Last Updated: YYYY-MM-DD HH:MM:SS UTC

---
```

**`## Quality Summary` section:**
- If both `quality_findings` and `length_findings` are empty: emit `All quality checks passed.`
- Otherwise: emit `### Tool Findings\n<quality_findings>` (when non-empty) and/or
  `### Length / Complexity\n<length_findings>` (when non-empty)

**`## Active Tasks` section:**
- `### P0 — Critical Quality Violations` when `quality_findings` contains any of
  `Shellcheck`, `Ruff`, `ty`, `Slop` — each non-header line as `  - [ ] <line>`
- `### P1 — Function Length / Complexity` when `length_findings` non-empty —
  same `  - [ ] <line>` format
- When neither P0 nor P1 fired: emit `  - [ ] No active quality violations.`
- Always emit P2 block (see below)

**P2 — Maintenance & Hygiene (fallback — fixed generic block):**
```
### P2 — Maintenance & Hygiene

  - [ ] Review INVENTORY.md accuracy (<5% divergence)
  - [ ] Review TODO.md snapshot-diff for unexpected removals
  - [ ] Run repo test suite before releases
  - [ ] Verify CI coverage for new modules
```

**`## Recommendations` section (fallback — fixed generic block):**
```
---

## Recommendations

### Process
  - [ ] Run quality checks after install or update
  - [ ] Keep lint and test prerequisites up to date

### Performance
  - [ ] Monitor inventory generation time (<5s target)
```
File ends after the last bullet. No trailing `Last Updated:` line.

## Anti-Patterns
- Adding a `Last Updated:` footer — it belongs only in the header for TODO.md
- Routing slop lint through `agent-quality-lint` in the fallback path
- Inserting `[SNAPSHOT]` warnings into TODO.md content
- Running CLI shortcut when any of the three required files is absent

## Validation
- Header has `Last Updated:` after the `# <title>` line, then `---`; no footer timestamp
- `## Quality Summary` present; clean repos show `All quality checks passed.`
- `### P2 — Maintenance & Hygiene` always present with the four generic bullets
- `## Recommendations` with `### Process` and `### Performance` subsections present

## Gotchas
- **No footer timestamp** — unlike INVENTORY.md and CAPABILITIES.md, TODO.md has NO
  `Last Updated:` footer; the header-pattern timestamp is the only one
- **P0 grep match** — check `quality_findings` for the literal strings `Shellcheck`,
  `Ruff`, `ty`, `Slop`; the `Slop` match covers `## Slop Lint` headers
- **Snapshot guard is warn-only** — suspicious removals surface in the skill response;
  they never block the write or appear in the file

Last Updated: 2026.05.04 @ 19:02:31
