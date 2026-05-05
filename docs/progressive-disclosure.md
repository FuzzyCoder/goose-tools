# Progressive Disclosure in goose-tools

This document explains how `goose-tools` applies Progressive Disclosure (PD) to its
agent instruction files. It covers the loading model, the budget policy, the
decision rubric for placing content, and governance. It is structural narrative only
— all numeric thresholds live in the canonical PD rubric, and all measured status
lives in the compliance report.

→ **Thresholds:** [`tune-agent-assets/references/tuning-rubric.md`](../.agents/skills/tune-agent-assets/references/tuning-rubric.md)
→ **Measured status:** [`docs/progressive-disclosure-compliance.md`](./progressive-disclosure-compliance.md)

---

## Three-Tier Loading Model

the Goose platform loads agent context in three tiers, each with a different cost
and scope:

**Tier 1 — Always loaded (global rules and AGENTS.md).**
Root and subdirectory `AGENTS.md` files are injected into every conversation that
touches the repo. They must be short enough not to crowd out task-specific context.
Size targets are defined in the canonical PD rubric.

**Tier 2 — Loaded on demand (skill frontmatter descriptions).**
When Warp decides which skills to offer, it reads every installed skill's frontmatter
`description` field. All descriptions are loaded simultaneously as a flat listing.
The total listing size must fit within the listing-cap budget (see rubric). Individual
descriptions must stay within the per-description character ceiling (see rubric).

**Tier 3 — Loaded when a skill is invoked (full SKILL.md body).**
The full skill body — `## When to Use`, `## Playbook`, `## Gotchas`, etc. — is loaded
only when the agent actually invokes the skill. Dense reference material that is not
needed to decide whether to invoke the skill belongs in `references/` companion files,
not inline in the SKILL.md body.

---

## Listing-Cap Math and Budget Policy

The **listing total** is the sum of `len(name) + len(description)` across all tracked
`SKILL.md` files. This is the amount of text Warp processes when selecting skills.

The listing-cap budget and the per-description character ceiling are specified in the
canonical PD rubric:
→ [`tune-agent-assets/references/tuning-rubric.md`](../.agents/skills/tune-agent-assets/references/tuning-rubric.md)

When any individual `description` exceeds the per-description ceiling, it must be
trimmed using the trim-preservation rules:
- Every quoted trigger phrase in the existing description must appear verbatim.
- Every `Not for ...`, `Do NOT use for ...`, or `NOT for ...` clause must appear verbatim.
- No trigger phrase or boundary may be removed, reworded, or paraphrased.
- Descriptive prose (non-trigger, non-boundary text) may be shortened.

---

## Rules vs Skills vs MCP vs Hooks: Decision Rubric

Use this rubric to decide where content belongs:

**Put in `AGENTS.md`** when the content is:
- A project convention that must be enforced on every single conversation turn.
- A code-style rule, import constraint, or naming convention.
- A critical constraint that agents must never violate.

Do not put in `AGENTS.md`: architecture overviews, documentation indexes, skill
inventories, or anything that can be deferred to when it is actually needed.

**Put in a skill `description` (Tier 2)** when the content is:
- A concise trigger phrase that helps Warp route the right skill.
- A negative boundary that prevents the wrong skill from being selected.
- A short purpose statement (one sentence or a tight clause).

Do not put in a description: step-by-step instructions, examples, or any content
that is only needed after the skill is already loaded.

**Put in a skill body (Tier 3)** when the content is:
- Step-by-step playbook instructions.
- Decision criteria and autonomy gates.
- Validation checklists.
- Short examples (≤20 lines).

**Extract to `references/`** when the body content is:
- A lookup table or reference chart rarely consulted at runtime.
- Extended examples that exceed ~20 lines.
- Dense procedural detail not needed to decide whether to invoke the skill.
- Content whose removal would bring the SKILL.md under the extraction threshold.

**Use MCP** for live external data that cannot be captured in static files (e.g.,
fetching PR details from GitHub, querying a live API).

**Use hooks** for side-effect actions that must happen automatically at specific
lifecycle events (e.g., running a linter on every file save).

---

## Governance and Monitoring

**Single source of truth for thresholds:**
All PD/AGENTS size targets and budget values are defined in one place:
[`tune-agent-assets/references/tuning-rubric.md`](../.agents/skills/tune-agent-assets/references/tuning-rubric.md)

Threshold values must never be restated inline in other files. Files that reference
thresholds must link to the rubric rather than duplicate the numbers.

**Single source of truth for measured status:**
All measured compliance values (listing totals, per-skill description lengths,
AGENTS.md line counts) are published in one place:
[`docs/progressive-disclosure-compliance.md`](./progressive-disclosure-compliance.md)

**When to re-audit:**
- After adding a new skill (check listing total and per-description ceiling).
- After editing an existing description (re-check description length).
- After modifying an `AGENTS.md` file (check line count against rubric).
- After changing the listing-cap budget or description ceiling in the rubric.

**Regenerating INVENTORY.md:**
Run `bin/goose-tools inventory` after any change to tracked `SKILL.md` files.
The tool re-reads frontmatter and updates the embedded descriptions automatically.

Last Updated: 2026.05.05 @ 00:55:00
