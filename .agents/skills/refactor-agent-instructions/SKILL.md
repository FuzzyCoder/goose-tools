---
name: refactor-agent-instructions
description: >-
  Audit and normalize instruction files (AGENTS.md, SKILL.md). Invoke this skill
  whenever the user says "refactor agent instructions", "run the validation matrix",
  "check instruction file compliance", "normalize skills", "audit AGENTS.md", or
  "check skill structure" — even if they phrase it casually. Do NOT use for
  pipeline execution, notebook management, or code quality checks. Do NOT use for
  PD/AH/TR content-level tuning (use tune-agent-assets instead).
---
# Refactor Agent Instructions

## When to Use
- Running a refactor pass on AGENTS.md or SKILL.md files
- Running the validation matrix after changes to instruction files
- Normalizing skill metadata (frontmatter, `## When to Use`, `## Quick Start`, `Last Updated`)
- Auditing for unnamed `RULE:` blocks, orphaned cross-references, or size violations

## Quick Start

```bash
# Audit AGENTS.md files: line counts
find . -name "AGENTS.md" -not -path "*/.venv/*" | sort | xargs wc -l

# Audit SKILL.md files: line counts
wc -l .agents/skills/*/SKILL.md | sort -rn

# Audit SKILL.md metadata gaps
for f in .agents/skills/*/SKILL.md; do
  skill=$(echo $f | sed 's|.*/\([^/]*\)/SKILL.md|\1|')
  fm=$(head -1 "$f" | grep -c "^---" || true)
  when=$(grep -c "^## When to Use" "$f" || true)
  qs=$(grep -c "^## Quick Start" "$f" || true)
  lu=$(grep -c "^Last Updated:" "$f" || true)
  echo "$skill | fm=$fm when=$when qs=$qs lu=$lu"
done

# Check for unnamed RULE: blocks
grep -rn "^RULE:$" --include="AGENTS.md" .

# Measure skill body token count (requires tiktoken)
uv run python -c "
import tiktoken; enc = tiktoken.get_encoding('cl100k_base')
print(len(enc.encode(open('.agents/skills/<skill>/SKILL.md').read())))
"
```

## Workflow

### 1. Inventory Pass
- Read [references/structure-standards.md](<./references/structure-standards.md>) as the baseline
- Re-run audit commands above to compare live state to baseline
- Note any new files, deletions, or size changes since last pass

### 2. Standards Reference
- Read [references/validation-criteria.md](<./references/validation-criteria.md>) for compliance rules
- Size targets: see [tune-agent-assets/references/tuning-rubric.md](../tune-agent-assets/references/tuning-rubric.md)
- Targets: SKILL.md < 500 lines and < 5,000 body tokens

### 3. AGENTS.md Compliance
- Every `RULE:` block must have a unique ID (`RULE: SCOPE_NAME`)
- No architecture overviews, documentation indexes, or manual skill inventories
- Root AGENTS.md: project identity + critical constraints + pointers to `.agents/skills/` only
- Every file must end with `Last Updated: YYYY.MM.DD @ HH:MM:SS`

### 4. SKILL.md Compliance
- Required frontmatter: `name`, `description` (verb-first, trigger keywords, negative boundaries)
- Optional frontmatter: `metadata.version` — never top-level `version:`
- Every skill needs `## When to Use`
- Operational skills also need `## Quick Start`
- Exactly one terminal `Last Updated:` line per file
- Move lookup/support material to `references/`; split on independent trigger conditions

For content-level PD/AH/TR tuning (token reduction, extraction decisions, gate patterns),
route to the `tune-agent-assets` skill rather than handling it inline.

### 5. Exception Registration
Any file remaining over-target after refactoring must be recorded in a `REFACTORING_LOG.md`
in the project's agent instruction directory with: measured size, rationale, and why further
splitting would reduce usability.

### 6. Cross-Reference Validation
```bash
# Find orphaned → See ... skill references
grep -rn "→ See" --include="AGENTS.md" . | grep -v ".venv"

# Verify each referenced skill directory exists
ls .agents/skills/
```

### 7. Portable Skill Drift Check
Portable skills appear in both the project's `.agents/skills/` and the global `~/.agents/skills/`.
Divergence can cause subtle bugs (truncated paragraphs, missing sections) that are hard to spot
in a normal review. Flag any differences:

```bash
for skill in .agents/skills/*/; do
  name=$(basename "$skill")
  global="$HOME/.agents/skills/$name/SKILL.md"
  [ -f "$global" ] && ! diff -q "$skill/SKILL.md" "$global" > /dev/null 2>&1 && echo "DRIFT: $name"
done
```

Intentional divergence (project-specific pitfall tables, domain rules) is acceptable — document it.
Unintentional divergence (truncations, missing sections) must be repaired atomically across all
copies using `edit_files` multi-diff and back-propagated to `~/Documents/agents/`.

## Execution Notes

### edit_files batch limits
When adding sections (e.g., `## When to Use`) to many skill files simultaneously, batch no more
than **8 diffs per `edit_files` call**. Larger batches silently drop some diffs and produce a
partial result without error messages. Apply remaining edits in subsequent calls.

### File replacement: use create_file, not rm
To replace a full SKILL.md (e.g., when slimming an oversized skill): use `create_file` with
the full new content. `create_file` overwrites existing files. Avoid `rm` on instruction files
— it causes agent blocking and loses the file permanently before a replacement is ready.

### Sub-agent coordination for decomposition
When delegating decomposition work to sub-agents:
- Give explicit tool guidance: prefer `create_file` over `rm` + create
- Sub-agents can be blocked when trying `rm`; tell them upfront to use `create_file` instead
- Have sub-agents send status messages at start and completion so you can track progress
- Monitor via `wc -l .agents/skills/<skill>/SKILL.md` and `ls .agents/skills/<skill>/references/`

### Skill description quality
Skill descriptions are the **primary triggering mechanism**. A skill with a weak description
will not be invoked even when perfect for the task. Write descriptions that are:
- **Verb-first**: starts with an action word
- **Pushy**: enumerate trigger phrases explicitly ("even if they say X or Y")
- **Bounded**: include negative boundaries ("Do NOT use for...")
- **Keyword-rich**: include synonyms and related terms for better semantic matching

The `## When to Use` body section is for agents that have already loaded the skill; the
frontmatter description determines whether the skill is loaded at all.

## Operational vs Reference-Only Skills

**Operational — edit-capable** (define `## Autonomy Gates`; edit files as authorized):
`fix-issue`, `review-and-fix-pr`, `tune-agent-assets`, `update-deps`

**Operational — single-command** (also include `## Quick Start`):
`manage-worktrees`, `run-quality-checks`, `sync-worktrees`, `sync-agents-library`

**Reference-only** (produce reports or guidance; no file edits):
`add-new-module`, `refactor-agent-instructions`, `review-plan`, `write-tests`

## Gotchas

- **edit_files batch limit: 8 diffs per call** — larger batches silently drop some diffs.
- **Use `create_file` for full SKILL.md replacements** — `rm` causes agent blocking and loses files before replacements are ready.
- **Sub-agents must be told to use `create_file` over `rm`** — they can get blocked on delete operations.
- **Skill descriptions are the primary trigger mechanism** — weak descriptions mean the skill won't load even when perfect for the task.

## References Structure

- `references/structure-standards.md` — library structure, size targets, and layout rules
- `references/validation-criteria.md` — per-file compliance checklist and portability rubric

Last Updated: 2026.05.04 @ 04:15:00
