---
name: write-skill
description: >-
  Author a new SKILL.md from scratch or improve an existing one: structure
  frontmatter, write a description that triggers reliably, add When to Use,
  Playbook, Anti-Patterns, Validation, and Gotchas sections. Triggers: "write
  a skill", "create a skill", "improve this skill", "add a skill", "skill
  description is weak", "skill not triggering", "update skill", "fix skill".
  Do NOT use for auditing compliance across many skills (use
  refactor-agent-instructions instead).
---
# write-skill

## When to Use
- Authoring a brand-new SKILL.md from scratch
- Improving an existing skill's description, structure, or content
- A skill is failing to trigger when it should
- A skill's instructions are unclear, incomplete, or missing key sections

## New Skill Checklist

Create `.agents/skills/<skill-name>/SKILL.md`. Required structure:

```markdown
---
name: <skill-name>          # must match directory name, kebab-case
description: >-
  <verb-first description>  # see Description Design below
---
# <skill-name>

## When to Use
- <bullet 1>
- <bullet 2>

## Playbook / Workflow
1. Step
2. Step

## Anti-Patterns
- Don't do X because Y

## Validation
- How to confirm the skill's work is correct

## Gotchas
- **Bold title** — explanation

Last Updated: YYYY.MM.DD @ HH:MM:SS
```

Optional sections (add when relevant):
- `## Autonomy Gates` — for skills that edit files, commit, push, or comment on PRs; place immediately after `## When to Use`; use canonical patterns from `fix-issue`, `update-deps`, or `review-and-fix-pr`
- `## Routing` — for fix-* type skills that are dispatched by a router skill; list which rules this skill handles and which sibling skills handle adjacent rules
- `## Quick Start` — for operational skills invoked via a single command
- `## References Structure` — when companion `references/` files exist

## Description Design

The frontmatter `description` is the **only** thing that determines whether the skill loads. A weak description means the skill never fires.

**Verb-first**: Start with an action verb.
> ✅ `"Remediate quality 'npath' violations by decomposing..."`
> ❌ `"This skill handles npath violations"`

**Pushy — enumerate triggers explicitly**:
> `"Triggers: quality-remediate routing, \"npath too high\", \"path explosion\""`

**Bounded — add negative boundaries**:
> `"Do NOT use for raw cyclomatic complexity (use fix-complexity instead)"`

**Keyword-rich**: Include synonyms and natural-language phrasings users might say:
> `"fix issue", "fix-issue", "implement issue #N"` (all three in fix-issue)

**One skill, one workflow**: If a description needs two unrelated `Do NOT use for` exclusions, the skill covers two workflows — split it.

## Playbook Content

### Routing sections (fix-* dispatch skills)
- State which rules/metrics this skill handles and their thresholds
- Cross-reference sibling skills for adjacent rules
- Example: `For function-level CCX see fix-complexity. For class WMC see fix-class-complexity.`

### Anti-Patterns
Write as actionable negatives, not vague warnings:
> ✅ `"- Adding # noqa: C901 suppresses without fixing — violates zero-warnings policy"`
> ❌ `"- Don't suppress warnings"`

### Gotchas
One Gotcha per failure mode. Format: `**Bold trigger** — consequence + correct action`.
> `"- **Splitting by line count** collapses readability — group by semantic responsibility instead"`

## Progressive Disclosure

- SKILL.md ≤ 200 lines: keep everything inline
- SKILL.md > 200 lines **or** contains dense lookup tables / extended examples: extract to `references/<topic>.md` and link from the skill body
- Never exceed 500 lines in a single SKILL.md

## Portability Rules

Skills in this repo are used across projects. Never embed:
- Absolute machine paths (`/Volumes/secure/`, `~/.goose/`)
- Repo-local script references not shipped with the skill
- Project-domain nouns (product names, service names)

Use `{{PLACEHOLDER}}` for values that differ per project.

## Validation

After writing or updating a skill:
1. Read the description aloud as a user query — does it trigger naturally?
2. Check: does every `## When to Use` bullet map to a trigger phrase in the description?
3. Run `wc -l .agents/skills/<skill-name>/SKILL.md` — must be ≤ 200 lines (or extract refs)
4. Run `refactor-agent-instructions` audit commands to check compliance
5. Check for drift against `~/.agents/skills/<skill-name>/SKILL.md` if a global copy exists

## Gotchas

- **The description is the sole routing signal** — `## When to Use` is only seen after the skill loads; if the description doesn't match, the skill never fires.
- **Pushy descriptions are not arrogant** — listing trigger phrases explicitly ("even if they say X or Y") is correct practice, not over-engineering.
- **Splitting a skill increases recall** — one large skill with many workflows is harder to trigger precisely than two focused skills with sharp descriptions.
- **`edit_files` batch limit is 8 diffs per call** — when updating many skills simultaneously, batch ≤ 8 edits per call or some are silently dropped.
- **Use `create_file` for full rewrites** — `rm` on a SKILL.md causes agent blocking; `create_file` overwrites safely.
- **Anti-triggers belong in the description, not just `## When to Use`** — the model sees the description at routing time; `## When to Use` is too late to prevent misloads.

Last Updated: 2026.05.04 @ 13:25:07
