---
name: manage-capabilities
description: >-
  Regenerate or create CAPABILITIES.md — the skill capability map. Reads
  `references/domain-map.md` for skill-to-domain assignments and prompts;
  produces a deterministic map of installed and bundled skills. Shows diff
  and confirms before overwriting. Triggers: "update CAPABILITIES.md",
  "update capabilities", "sync capabilities with skills",
  "create CAPABILITIES.md", "add new skill to capabilities". Do NOT use
  for file inventory (use manage-inventory) or TODO generation
  (use manage-todo).
---
# manage-capabilities

## When to Use
- Create or refresh CAPABILITIES.md in the current repo
- After adding, removing, or renaming skills
- Triggers: "update CAPABILITIES.md", "update capabilities",
  "sync capabilities with skills", "create CAPABILITIES.md",
  "add new skill to capabilities"
- NOT for file inventory or TODO generation

## Autonomy Gates
Before writing CAPABILITIES.md:
1. Generate content into an in-memory buffer
2. Show diff: `+N lines / -N lines` vs existing file, or `(new file)` if absent
3. Ask: "Overwrite CAPABILITIES.md? (yes / no)"
4. Proceed only on explicit "yes" — abort on anything else. No manual sections are preserved.

## References Structure
- `references/domain-map.md` — config/lookup table mapping skills to domains, example
  prompts, bundled flags, and gap-text entries. This is a config artifact and is not
  bound by the SKILL.md 200-line limit.

## Playbook

### 1 — Read domain-map
Read `<skill-dir>/manage-capabilities/references/domain-map.md` where
`<skill-dir>` = `.agents/skills` relative to repo root (or the path you are reading
this SKILL.md from).

Parse the map for:
- Display-ordered domain list (headings under `## Domains`)
- Per-domain skill entries (bullets under `**Skills:**`, with `(bundled)` flag)
- Per-domain example prompts (bullets under `**Examples:**`, each tagged `[skill-name]`)
- Per-domain gap-text line (`**Gap:**` entry, shown when domain has no installed skills)

### 2 — Enumerate installed skills
- **Repo-local:** collect all subdirectory names under `.agents/skills/` that contain
  a `SKILL.md` file (`ls .agents/skills/*/SKILL.md`); these are the installed local skills
- **Bundled:** use the explicit list in `references/domain-map.md`; filesystem detection
  of bundled skills is not feasible — the domain map is the authoritative registry

### 3 — Generate CAPABILITIES.md
**File header:**
```
# <repo-name> Capabilities

Last Updated: YYYY-MM-DD HH:MM:SS UTC

---

```
Where `<repo-name>` = `basename "$(git rev-parse --show-toplevel)"`.

**Intro paragraph (verbatim):**
```
This document maps common activities to the skills available in this repo and provides
example prompts for triggering them. Skills marked **(bundled)** are provided by Warp
itself rather than the goose-tools repository.
```

**Per-domain blocks (in domain-map display order):**
For each domain with at least one installed skill:
1. Emit `## <Domain Name>`
2. Emit `**Skills:**` bullet list — include only skills that are actually installed;
   append ` (bundled)` to bundled skills (e.g., `- \`oz-platform\` (bundled) — ...`)
3. Emit `**Examples:**` bullet list — include only examples whose `[primary-skill]` tag
   refers to an installed skill; omit examples for uninstalled skills

**Unmapped local skills:**
Any repo-local skill installed but absent from the domain map → grouped under
`## Other` at the end (before Gaps), with a `**Skills:**` bullet but no examples:
```
**Examples:**
_(none — add seeds to references/domain-map.md to populate)_
```

**Gaps section:**
```
## Gaps (No Skill Coverage Yet)

- <domain-name>: <gap-text from domain map>
```
Include: (a) every mapped domain that has NO installed skills (local or bundled), and
(b) any free-form `**Gap:**` entries from the domain map that are unconditional.

**File footer:**
```
---

Last Updated: YYYY.MM.DD @ HH:MM:SS
```

### 4 — Diff + confirm (per Autonomy Gates)
Then write.

## Anti-Patterns
- Preserving user-authored sections from a previous CAPABILITIES.md — always full overwrite
- Emitting examples for skills not installed in the current repo
- Filesystem-detecting bundled skills — use the domain map as the sole bundled-skill registry
- Hardcoding domain order in the skill — always read from domain-map display order

## Validation
- Intro paragraph matches verbatim spec from step 3
- Every installed local skill appears exactly once (mapped domain or `## Other`)
- Bundled skills show ` (bundled)` suffix in their bullet
- `## Gaps` section present (may be empty body if no gaps)
- File ends with `Last Updated: YYYY.MM.DD @ HH:MM:SS` footer

## Gotchas
- **domain-map.md is the sole truth** — if a bundled skill is removed from the map,
  it disappears from CAPABILITIES.md; update the map when bundled skills change
- **`## Other` has no examples** — this is intentional to expose unmapped skills
- **Warp-tools repo**: all skills are installed; consumer repos may have fewer skills,
  producing more Gaps entries automatically

Last Updated: 2026.05.04 @ 19:02:31
