# Agent Profile Security Guide

Recommended Warp agent profile configurations corresponding to Trail of Bits' mechanical
enforcement layer. Each profile pattern maps to Warp's documented permission system and
autonomy levels.

## Autonomy Levels

Warp has four per-action autonomy levels. Understand them before configuring profiles:

| Level | Meaning |
|---|---|
| `Agent decides` | The agent chooses whether to act or ask, based on confidence and risk |
| `Always ask` | Warp prompts the user before every action of this type |
| `Always allow` | The agent performs the action without confirmation |
| `Never` | The action is blocked entirely, regardless of agent intent |

**`Run until completion`** is distinct from these autonomy levels. It is a per-task mode
(not a per-profile setting) that instructs Warp to execute all pending actions without
stopping to prompt. Critically: **`Run until completion` does not bypass the command
denylist.** The denylist takes precedence over all autonomy levels and over `Run until
completion`. To bypass the denylist for a specific command, the user must modify the
denylist before launching the task.

**Denylist precedence rule (Warp documentation):** "The command denylist takes precedence
over the allowlist and over `Always allow` autonomy."

---

## Profile Patterns

### Read-only

Use for code review, plan creation, analysis, and any task that must not modify files or
execute state-changing commands.

| Permission | Setting |
|---|---|
| Apply code diffs | `Never` |
| Read files | `Always allow` |
| Create plans | `Agent decides` |
| Execute commands | `Always ask` |
| Interact with running commands | `Always ask` |
| MCP permissions | `Always ask` |

**Command allowlist** (read-only patterns only):
```
ls
cat
grep
find
git status
git --no-pager log
git --no-pager diff
git --no-pager show
gh pr view
gh issue view
uv run ruff check
uv run ty check
```

**Command denylist** — use Warp's default denylist plus any project-specific destructive
commands (e.g. `rm -rf`, `DROP TABLE`, `git push --force`).

**Directory allowlist** — limit to the project root and its subdirectories. Exclude
`~/.ssh`, `~/.gnupg`, and other credential directories.

---

### Safe

Use for normal development tasks: implementing features, running tests, refactoring.
The agent can apply diffs and run dev commands, but must ask before anything potentially
destructive.

| Permission | Setting |
|---|---|
| Apply code diffs | `Always ask` |
| Read files | `Always allow` |
| Create plans | `Agent decides` |
| Execute commands | `Agent decides` |
| Interact with running commands | `Agent decides` |
| MCP permissions | `Agent decides` |

**Command allowlist** (trusted dev commands):
```
uv run
uv lock
uv sync
pytest
ruff
ty
git --no-pager status
git --no-pager diff
git --no-pager log
git --no-pager fetch
git --no-pager add
git commit
git --no-pager push origin HEAD
gh pr create
gh pr view
gh issue view
```

**Command denylist** — enforce Warp defaults. Add project-specific destructive patterns:
```
git push --force
git push --force-with-lease
git reset --hard
rm -rf
DROP TABLE
DROP DATABASE
```

**Directory allowlist** — project root and subdirectories. Read-only access to
`~/.goose/state/plan_workflow/` is acceptable for plan-workflow integration.

---

### YOLO

Use for high-trust, high-autonomy tasks where you want the agent to proceed end-to-end
without confirmation prompts. Appropriate for fully-scripted pipeline runs or known-safe
batch operations.

| Permission | Setting |
|---|---|
| Apply code diffs | `Always allow` |
| Read files | `Always allow` |
| Create plans | `Always allow` |
| Execute commands | `Always allow` |
| Interact with running commands | `Always allow` |
| MCP permissions | `Always allow` |

**Important:** Even with all permissions set to `Always allow`, **the command denylist
still applies.** Warp enforces denylist precedence regardless of the autonomy level.

To bypass the denylist for a specific task (e.g., running `git push --force` for a
known-safe rebase squash), the user must:
1. Temporarily remove the specific pattern from the profile's denylist, OR
2. Invoke `Run until completion` from the Warp input — but note this is per-task and the
   denylist still applies unless explicitly modified.

**Command allowlist** — can be broadened relative to Safe profile:
```
# All Safe profile entries, plus:
git push --force-with-lease
git rebase
git cherry-pick
uv tool run
uv tool install
```

**Recommendation:** Even in YOLO mode, keep `rm -rf` and `DROP TABLE` in the denylist.
The productivity gain from removing those guards is near zero; the blast radius is not.

---

## Command Allowlist and Denylist Examples

### Allowlist patterns (Safe baseline)
```
uv run *
pytest *
ruff *
ty *
git --no-pager *
git commit *
git push origin HEAD
gh pr *
gh issue view *
```

### Denylist patterns (recommended for all profiles)
```
git push --force
git reset --hard HEAD~*
rm -rf /
rm -rf ~
DROP TABLE
DROP DATABASE
TRUNCATE TABLE
curl * | sh
wget * | sh
eval *
```

---

## MCP Permission Guidance

MCP tools can have broad access (filesystem reads, web requests, code execution). Apply
the same autonomy-level logic:

- **Read-only profile** — `Always ask`: the agent must confirm before each MCP tool call.
- **Safe profile** — `Agent decides`: the agent invokes read-only MCP tools freely but
  asks before any MCP tool that writes, posts, or triggers external side effects.
- **YOLO profile** — `Always allow`: all MCP tools execute without confirmation. Only use
  with trusted, locally-running MCP servers whose side effects you understand.

When in doubt, start at `Always ask` and loosen only when the friction is measurably
slowing down legitimate work.

---

## Directory Allowlist and Denylist Guidance

**Allowlist** — be explicit rather than permissive. A tight allowlist prevents an agent
from accidentally reading or writing outside its intended scope:

```
/path/to/your/project/        # project root
~/.goose/state/plan_workflow/  # plan-workflow slot state (read-only is sufficient)
~/.agents/skills/             # skill files (read-only for most profiles)
```

**Denylist** — always exclude credential and secret directories:
```
~/.ssh/
~/.gnupg/
~/.aws/
~/.config/gh/               # GitHub CLI tokens
~/.netrc
```

---

## Profiles and the Plan → Execute Workflow

The Plan → Execute Workflow uses four named profiles: **Planner**, **Reviewer**,
**Approver**, and **Coder**. Recommended baseline settings:

| Profile | Suggested pattern | Suggested model | Rationale |
|---|---|---|---|
| Planner | Safe | Qwen 3.6 Plus | Creates plans and reads repo context; no code changes |
| Reviewer | Read-only | GLM 5 (`glm-5-fireworks`) | Analysis only; must not edit files |
| Approver | Read-only | Kimi K2.5 (`kimi-k25-fireworks`) | Second-pass review; must not edit files |
| Coder | Safe or YOLO | Kimi K2.6 | Implements the approved plan |
| Coder (Fast) | Safe or YOLO | MiniMax 2.7 | Optional; for small tasks where responsiveness matters |

See `docs/plan-execute-workflow.md` for the full workflow reference.

---

Last Updated: 2026.05.02 @ 23:29:08
