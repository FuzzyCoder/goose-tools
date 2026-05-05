# Global Warp Rule — Oz Agent Philosophy

This document is the **canonical source text** for a Warp Rule the user can paste into
**Settings → AI → Rules** (the global Rules surface, not a Warp Drive notebook or project
`AGENTS.md`). The Rules surface applies to every Oz conversation regardless of which repo
is active; use it for principles that should hold universally.

## How to Use

1. Open Warp → Settings → AI → Rules.
2. Create a new rule and paste the rule text below (starting at "## Core Principles").
3. Save. The rule will be active for all future Oz conversations.

Do not copy this entire document — copy only the rule text under "## Core Principles".
Project-specific overrides belong in the repo's `AGENTS.md`, not here.

---

## Principle Selection Rationale

Trail of Bits' `claude-code-config` defines a layered philosophy covering design, quality,
safety, testing, and workflow. Not every principle translates directly to Warp's `oz agent run`
workflow. The following were **considered and excluded**:

- *Claude-specific slash commands* (`/compact`, `/cost`, `/init`) — no Warp equivalent.
- *MCP-specific tool rules* (Claude MCP session management) — Warp manages MCP permissions
  via profile settings, not inline instructions.
- *`CLAUDE.md` hierarchy rules* — Warp uses `AGENTS.md` with its own precedence model,
  already documented in the project template.
- *Checkpoint/snapshot workflow* — Warp does not have a native snapshot primitive; the
  Plan→Execute workflow serves the same purpose.

The following were **selected** because they map cleanly to Warp's tooling, the
`oz agent run` workflow, and the `warp-tools` skill ecosystem:

| Selected principle | Rationale |
|---|---|
| No speculative features | Prevents scope creep in plan execution |
| No premature abstraction | Encourages minimal, reversible implementations |
| Clarity over cleverness | Code must be reviewable by the next Oz agent |
| Justify dependencies | `uv`-managed projects; every dep has a lockfile cost |
| No phantom features | Oz agents should not implement beyond the plan |
| Replace rather than deprecate | Avoids dead-code accumulation across sessions |
| Verify with ruff/ty/tests | Matches the `run-quality-checks` skill contract |
| Bias toward reversible action | Critical given autonomous commit/push gates |
| Finish without scope creep | Agents must not extend scope mid-execution |
| Agent-native design | Code must work with Oz's tool-call execution model |
| Proactive skill use | Matches the `warp-tools` skill ecosystem |
| Deliberate context management | Oz context windows are finite; plan before reading |

---

## Core Principles

*(Paste this section into Settings → AI → Rules)*

```
## Oz Agent Philosophy

### Design
- NEVER add features not explicitly requested in the plan or user message.
- NEVER introduce premature abstractions — prefer flat, obvious code over clever structure.
- Write code that the next agent (or human) can read and modify without re-reading your reasoning.
- Every new dependency must be justified: state what it does and why a lighter alternative is insufficient.
- Replace deprecated or superseded code rather than leaving both versions in place.

### Quality
- ALWAYS verify your implementation with ruff (linting), ty (type checking), and the test suite before reporting done.
- Fix every warning from ruff, ty, and pytest. If a warning truly cannot be fixed, add an inline ignore with a one-line justification comment.
- Keep functions ≤ 100 lines, cyclomatic complexity ≤ 8, and ≤ 5 positional parameters.
- Use absolute imports only — no relative `..` paths.

### Safety and Reversibility
- Prefer reversible actions: create before delete, branch before commit, draft before push.
- Before any destructive operation (rm, force-push, drop table), state what will be destroyed and ask for confirmation — even in YOLO profiles.
- NEVER commit secrets, credentials, or tokens. Use environment variables or secret managers.
- Do not push to the default branch directly; open a PR.

### Workflow
- When a skill exists for the task, use it. Do not reinvent workflows documented in `.agents/skills/`.
- Finish the assigned task completely before reporting done. Do not leave TODOs in the implementation unless the plan explicitly deferred them.
- Do not expand scope mid-execution. If new work is discovered, report it and wait for direction.
- Manage context deliberately: read only the files needed for the current step. Avoid bulk-reading entire directories speculatively.
- When launching sub-agents, assign each agent a single, clearly bounded task and document the boundary in the prompt.
```

---

Last Updated: 2026.05.01 @ 00:04:37
