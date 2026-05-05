# Library Structure Standards

This document defines the canonical structure, size targets, and layout rules for the
agents starter library at `~/Documents/agents/`.

## Canonical Directory Layout

```
~/Documents/agents/
├── README.md                          # Human index, placeholder inventory, adoption guide
├── AGENTS.md                          # Root template (≤ 80 lines)
├── tests/
│   └── AGENTS.md                      # Tests template (≤ 60 lines)
├── utils/
│   └── AGENTS.md                      # Utils template (≤ 60 lines)
└── .agents/
    └── skills/
        ├── review-plan/
        │   └── SKILL.md
        ├── run-quality-checks/
        │   └── SKILL.md
        ├── write-tests/
        │   └── SKILL.md
        ├── add-new-module/
        │   └── SKILL.md
        ├── refactor-agent-instructions/
        │   ├── SKILL.md
        │   └── references/
        │       ├── structure-standards.md    ← this file
        │       └── validation-criteria.md
        ├── manage-worktrees/
        │   └── SKILL.md
        ├── sync-worktrees/
        │   ├── SKILL.md
        │   └── references/
        │       ├── conflict-resolution.md
        │       └── report-template.md
        └── sync-agents-library/
            └── SKILL.md
```

## Size Targets

| File type | Target | Hard limit |
|---|---|---|
| Root `AGENTS.md` | ≤ 80 lines | 100 lines |
| Subdirectory `AGENTS.md` | ≤ 60 lines | 80 lines |
| `SKILL.md` body | < 500 lines | — |
| `SKILL.md` body tokens | < 5,000 tokens | — |
| `references/*.md` | Unconstrained | — |

When a SKILL.md body would exceed 500 lines, move lookup/reference tables, extended examples,
or protocol details into a `references/` companion file and link from the main skill body.

## Source-of-Truth Model

`~/Documents/agents/` is the **canonical authoring library** — the single source of truth.

- **Never edit installed copies directly.** All changes happen in the canonical library and
  are propagated via the `sync-agents-library` skill.
- **Installed copies** live in `~/.agents/skills/` (global) or `<project>/.agents/skills/`
  (project-local). They are consumer-facing outputs, not authoritative sources.
- **AGENTS.md templates** are distributed via `sync-agents-library`'s scaffold mode, which
  copies templates into a consumer project's directory tree with placeholder substitution.

## Skill Classification

### Operational skills (require `## Quick Start`)
These skills are invoked to execute workflows, not just provide reference information:
- `manage-worktrees`
- `run-quality-checks`
- `sync-worktrees`
- `sync-agents-library`

### Reference-only skills (`## Quick Start` optional)
These skills provide knowledge, patterns, or structured workflows that do not need a
one-liner command to start:
- `add-new-module`
- `refactor-agent-instructions`
- `review-plan`
- `write-tests`

## Naming Conventions

- Skill directories: `kebab-case` (e.g., `run-quality-checks`)
- RULE identifiers: `UPPER_SNAKE_CASE` prefixed with scope (e.g., `RULE: ERROR_FAIL_FAST`)
- Placeholders in templates: `{{UPPER_SNAKE_CASE}}` (e.g., `{{PACKAGE_NAME}}`)
- Companion reference files: `kebab-case.md` (e.g., `conflict-resolution.md`)

## Starter Stack Contract

The library encodes opinions about the following defaults. Consumer projects can adapt or
remove them, but the defaults are intentional and applied consistently:

| Layer | Default |
|---|---|
| Package manager | `uv` |
| Python version | 3.13 |
| Linter | `ruff` (100-char line length) |
| Type checker | `ty` |
| DataFrame library | `polars` |
| Database | `duckdb` |
| Document store | `pymongo` |
| Notebook runtime | `marimo` |
| Logger | `loguru` |
