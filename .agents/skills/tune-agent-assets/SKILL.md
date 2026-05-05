---
name: tune-agent-assets
description: >-
  Tune goose-tools agent assets across Progressive Disclosure (PD), Agent Harnessing (AH),
  and Token Reduction (TR). Triggers: "tune agent assets", "tune-agent-assets", "tune skills",
  "tune PD", "improve PD compliance", "reduce skill tokens", "tune token reduction",
  "tune agent harnessing". Do NOT use for authoring a brand-new skill (use write-skill),
  structural compliance audits across many files (use refactor-agent-instructions), or
  shell-script refactors (use improve-shell-quality).
---
# tune-agent-assets

Content-level PD/AH/TR tuning for Markdown instruction files. Scope: AGENTS.md files,
SKILL.md files, their `references/` companions, and `docs/*.md` files that overlap
PD/AH/TR concerns. Shell scripts are out of scope — route to `improve-shell-quality`.

## When to Use
- Reducing a SKILL.md or AGENTS.md token footprint without losing information
- Extracting dense inline content to `references/` to stay within PD thresholds
- Adding or improving `## Autonomy Gates` in an operational skill
- Tightening a skill's routing description for conciseness
- Auditing a single skill or AGENTS.md file for PD/AH/TR compliance

## Autonomy Gates

Authorized edits:
- `.agents/skills/<skill>/SKILL.md`
- `.agents/skills/<skill>/references/*.md`
- `AGENTS.md` files at any level
- `docs/*.md` files where they overlap PD/AH/TR concerns

NOT authorized:
- `CAPABILITIES.md`, `TODO.md`, or `INVENTORY.md` (user-read-only; hand-edits do not persist)
- Anything in `bin/`, `utils/`, `goose/workflows/scripts/`, or `tests/`
- Commit, push, or post PR comments

## Playbook

For full thresholds, extraction decision criteria, and TR priority rankings, see
[references/tuning-rubric.md](./references/tuning-rubric.md).

### 1. Scope and Measure

```bash
wc -l .agents/skills/<skill>/SKILL.md
uv run python -c "
import tiktoken; enc = tiktoken.get_encoding('cl100k_base')
print(len(enc.encode(open('.agents/skills/<skill>/SKILL.md').read())))
"
```

### 2. Progressive Disclosure (PD)
- SKILL.md ≤200 lines: keep everything inline.
- SKILL.md >200 lines or dense lookup tables/extended examples: extract to `references/<topic>.md`.
- Never exceed 500 lines in a single SKILL.md.
- AGENTS.md size targets: see [references/tuning-rubric.md](./references/tuning-rubric.md).
- Link all extracted files from the skill body under `## References Structure`.

### 3. Agent Harnessing (AH)
- Add `## Autonomy Gates` to skills that edit files, commit, push, or comment on PRs.
- Place it immediately after `## When to Use` — never later in the file.
- Use the table or narrative format from `fix-issue`, `update-deps`, or `review-and-fix-pr`.
- Do not add autonomy gates to review-only or report-only skills.

### 4. Token Reduction (TR)

Apply reductions in priority order (see rubric for ratio/risk details):
1. Remove section preamble sentences that restate the heading
2. Collapse redundant prose to tight bullet lists
3. Extract large examples or tables to `references/`
4. Replace repeated command blocks with a single canonical reference
5. Remove padding phrases and empty hedges

### 5. Route Structural Issues

If structural issues (metadata, frontmatter, validation-matrix) surface during a tuning
pass, note them and route to `refactor-agent-instructions` rather than fixing inline.

## Anti-Patterns
- Extracting to `references/` when the skill is already ≤200 lines — unnecessary indirection
- Adding `## Autonomy Gates` to review-only or report-only skills
- Reducing tokens by deleting meaningful content instead of restructuring
- Editing `CAPABILITIES.md`, `TODO.md`, or `INVENTORY.md` during a skill invocation
- Fixing structural or metadata issues instead of routing to `refactor-agent-instructions`
- Editing anything in `bin/`, `utils/`, `tests/`, or `goose/workflows/scripts/`

## Validation
1. `wc -l .agents/skills/<skill>/SKILL.md` — ≤200 lines (or refs extracted; never >500)
2. Token count ≤5,000 body tokens per skill
3. AGENTS.md size targets — see [references/tuning-rubric.md](./references/tuning-rubric.md)
4. If `references/` files were added, each is linked from the skill body
5. `## Autonomy Gates` (if added) appears immediately after `## When to Use`
6. No structural issues introduced (missing frontmatter, missing `Last Updated:`)

## Routing
- **write-skill** — authoring or improving a single SKILL.md from scratch
- **refactor-agent-instructions** — structural compliance, metadata normalization, validation-matrix
- **improve-shell-quality** — shell script refactors, bats tests, shellcheck CI
- **agent-launcher** — `oz agent run` launcher mechanics and Bash wrapper patterns

When structural issues surface during a PD/AH/TR pass, route them to
`refactor-agent-instructions` rather than fixing them inline.

## Gotchas
- **Extraction increases recall cost** — only extract when threshold is genuinely exceeded
  or the content is clearly optional at runtime
- **Autonomy Gates must exclude the NOT authorized list above** — never authorize edits to
  `CAPABILITIES.md`, `TODO.md`, or `INVENTORY.md` in any gated skill
- **`edit_files` batch limit: 8 diffs per call** — larger batches silently drop some diffs
- **Use `create_file` for full SKILL.md replacements** — `rm` causes agent blocking
- **Structural issues belong in `refactor-agent-instructions`** — do not scope-creep into
  metadata normalization

## References Structure
- `references/tuning-rubric.md` — detailed PD/AH/TR thresholds, extraction decision tree,
  and token reduction priority list with ratio/risk rankings

Last Updated: 2026.05.04 @ 18:25:34
