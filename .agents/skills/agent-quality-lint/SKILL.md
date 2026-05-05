---
name: agent-quality-lint
license: Apache-2.0
description: >
  Agentic code quality linter. Runs 13 structural analysis rules against a
  codebase and reports violations. Operates in passive mode (after changes,
  surface only if violations found) or active mode (on user request, report
  summary). Backed by tree-sitter, ripgrep, fd, and git.
metadata:
  author: Jordan Godau
  version: 0.1.0
  references:
    - references/01_SUMMARY.md
    - references/02_INTENT.md
    - references/03_POLICIES.md
    - references/04_PROCEDURE.md
  scripts:
    - scripts/skill.sh
    - scripts/skill.ps1
  keywords:
    - slop
    - linter
    - complexity
    - coupling
    - hotspots
    - code-quality
    - agentic
    - ci
---

# agent-quality-lint

Agentic code quality linter backed by tree-sitter, ripgrep, fd, and git. Runs 13 structural
analysis rules and reports violations. Use for post-change validation or on-demand quality audits.

## When to Use

- After making code changes — run in passive mode to surface violations
- User asks to "run quality lint", "check code quality", or "analyze complexity"
- Pre-commit validation before merging branches
- Not for fixing violations (use `quality-remediate` or `fix-*` skills instead)

## Quick Start

> **Do not read reference files directly.**
> Run `./scripts/skill.sh init` to load all references in a single call.

1. Run `./scripts/skill.sh init` and follow the instructions.

## Gotchas

- **Passive vs active mode**: Passive mode surfaces violations only if found; active mode always reports a summary.
- **Do not fix violations inline** — route to the appropriate `fix-*` skill for each rule.
- **The skill reads the full codebase** — expect longer run times on large repos.

## References Structure

- `references/01_SUMMARY.md` — Rule overview and metrics definitions
- `references/02_INTENT.md` — Design goals and philosophy
- `references/03_POLICIES.md` — Rule configurations and thresholds
- `references/04_PROCEDURE.md` — Execution workflow and output format
