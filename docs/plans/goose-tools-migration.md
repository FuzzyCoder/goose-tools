# Plan: goose-tools — Goose-Native Analog of warp-tools

**Created:** 2026-05-05  
**Revised:** 2026-05-05 (R1–R10 applied; R1–R6 rev2 applied)  
**Status:** Draft  
**Scope:** Create a new GitHub repo `goose-tools` that migrates the warp-tools
toolchain to the Goose platform, replacing Warp/Oz-specific primitives with their
Goose-native equivalents.

---

## 0. Background & Motivation

`warp-tools` is a portable agent toolchain built for Warp's Oz platform. It provides:

1. A structured **Plan→Review→Edit→Approve→Finalize→Execute** workflow
2. A reusable **code-quality kit** (13-rule slop linter + remediation skills)
3. A **portable skill library** (`write-tests`, `fix-*`, `review-pr`, etc.)
4. A **CLI** (`bin/warp-tools`) for install, scaffold, slot management, inventory

All of this is hard-wired to Oz primitives: `oz agent run`, `oz agent profile`,
`create_plan()`, Warp Drive notebooks, Warp Command Palette YAMLs, and
`~/.warp/` state paths.

Goose has analogous but distinct primitives:

| Warp/Oz concept | Goose equivalent |
|---|---|
| Agent profile | Recipe (`title`, `instructions`, `extensions`, `settings`) |
| `oz agent run --profile X` | `goose run --recipe recipe.yaml` |
| Warp Drive notebook | Recipe (discovered via `GOOSE_RECIPE_PATH` pointing at the local clone) |
| Command Palette YAML | Recipe `activities` field (Desktop) |
| `create_plan()` | No direct equivalent; implement via `uuidgen` + markdown registry (see §3.5); Goose's native `/plan` command is a potential complement |
| `~/.warp/state/plan_workflow/` | `~/.goose/state/plan_workflow/` (new convention) |
| `oz_pw_*.sh` launcher scripts | Shell launchers calling `goose run --recipe` |
| `AGENTS.md` | `AGENTS.md` (identical — Goose reads these too) |
| Skills (`.agents/skills/`) | Skills (`.agents/skills/`) + Goose `skills` extension |
| `bin/warp-tools` CLI | `bin/goose-tools` CLI (adapted) |
| Warp `global-warp-rule.md` | Goose `config.yaml` `instructions` / system prompt |

---

## 1. Goals

1. **Create** a new public GitHub repo `goose-tools` under the `FuzzyCoder` account
2. **Migrate** all platform-agnostic assets verbatim (skills, quality kit, shell utils,
   tests, docs structure)
3. **Adapt** all Warp/Oz-specific assets to Goose-native equivalents
4. **Replace** warp-specific references throughout (`warp` → `goose`, `oz` → `goose`,
   `~/.warp/` → `~/.goose/`, etc.)
5. **Establish** the repo as a standalone, installable toolchain — not a fork of
   warp-tools

---

## 2. What Stays the Same

The following assets are platform-agnostic and migrate verbatim (or near-verbatim):

| Asset | Notes |
|---|---|
| `.agents/skills/` — all skills | Keep all except those listed in §3 (major adaptation) and §3.18 (minor text replacement). See those sections for the full enumerated list. |
| `scaffold-analysis-pipeline` skill | Verbatim — 100% platform-agnostic |
| `quality-fix-notes` skill | Verbatim — 100% platform-agnostic |
| `utils/shell/` — `common.sh`, `flags.sh`, `logging.sh`, `paths.sh`, `github.sh` | Rename path constants only |
| `tests/` — bats tests, shellcheck | Adapt test targets for renamed scripts |
| `docs/` — most content | Rename platform references |
| `.gitignore`, `.shellcheckrc`, `.pre-commit-config.yaml`, CI | Carry over; update script paths |
| `pyproject.toml`, `uv.lock` | Carry over unchanged |
| `AGENTS.md` (all levels) | Update Warp-specific rule text |
| Code-quality kit (`quality-lint-report`, `fix-*` skills, `slop`) | Verbatim — 100% platform-agnostic |

---

## 3. What Changes

### 3.1 Repo Creation

- Create public repo `goose-tools` on GitHub (`FuzzyCoder/goose-tools`)
- Initialize with MIT license, `.gitignore`, and `README.md` stub
- Clone locally to `/Volumes/secure/code/goose-tools`
- Add `origin` remote, initial commit, push

### 3.2 CLI: `bin/warp-tools` → `bin/goose-tools`

| Change | Detail |
|---|---|
| Rename binary | `bin/warp-tools` → `bin/goose-tools` |
| State path | `~/.warp/state/plan_workflow/` → `~/.goose/state/plan_workflow/` |
| Install path | `~/.warp/workflows/` → `~/.goose/workflows/` |
| Skills path | `~/.agents/skills/` → unchanged (already platform-agnostic) |
| Profile resolution | Remove `oz agent profile list` / `resolve_profile_id()`; replace with recipe file lookup |
| Subcommands to adapt | `install`, `scaffold`, `update`, `doctor`, `slot`, `plan`, `inventory`, `todo` |
| Remove | `warp/` directory entirely (Warp Drive notebooks, Command Palette YAMLs) |

### 3.3 Workflow Scripts: `oz_pw_*.sh` → `goose_pw_*.sh`

The 6 Plan→Execute scripts call `oz agent run --profile <id>`. Replace with:

```bash
# Before (Warp/Oz)
oz agent run --profile "$PLANNER_PROFILE_ID" --prompt "$prompt"

# After (Goose) — interactive (streams to terminal, stays in session)
goose run --recipe planner

# After (Goose) — headless (runs and exits, no session stored)
goose run --recipe planner --no-session
# Goose resolves 'planner' via GOOSE_RECIPE_PATH → goose/recipes/planner/recipe.yaml
```

Note: `goose run` (not `goose session`) is the correct subcommand for recipe execution.
Use `--interactive` to keep the session open after the recipe completes.

Scripts to adapt:

| Old | New | Role |
|---|---|---|
| `oz_pw_plan.sh` | `goose_pw_plan.sh` | Launch Planner recipe |
| `oz_pw_review.sh` | `goose_pw_review.sh` | Launch Reviewer recipe |
| `oz_pw_edit.sh` | `goose_pw_edit.sh` | Launch Coder recipe (edits) |
| `oz_pw_finalize.sh` | `goose_pw_finalize.sh` | Launch Coder recipe (finalize) |
| `oz_pw_execute.sh` | `goose_pw_execute.sh` | Launch Coder recipe (execute) |
| `oz_pw_select.sh` | `goose_pw_select.sh` | Pin existing plan to slot |

### 3.4 Warp Drive Notebooks → Goose Recipes

Warp Drive notebooks (`.md` operator guides displayed in the Warp UI) have no direct
Goose equivalent. Replace with:

- **Recipes** (`.yaml`) stored in `goose/recipes/` — one per agent role
- **Operator guide** (`docs/plan-execute-workflow.md`) — updated for Goose CLI commands

Recipe files to create:

| Recipe | Role | Key fields |
|---|---|---|
| `planner.yaml` | Creates and registers plans | `instructions`, `extensions: [developer, todo]` |
| `reviewer.yaml` | Reviews plans (read-only) | `instructions`, `extensions: [developer]`; set `GOOSE_MODE=chat` per-session for read-only enforcement |
| `approver.yaml` | Second-pass approval | Same as reviewer with distinct instructions |
| `coder.yaml` | Implements approved plans | `instructions`, `extensions: [developer, knowledgegraphmemory]` |

### 3.5 Plan State: `create_plan()` Replacement

Oz's `create_plan()` built-in has no direct Goose equivalent. Replace with:

- **Plan registry**: Markdown file at `~/goose-agent-plans.md` (same schema as
  `~/warp-agent-plans.md`)
- **Plan ID**: Use `uuidgen` at slot creation time (shell-native, no API call)
- **Todo extension**: Use `Todo.todoWrite()` for in-session task tracking
- **`manage-plans` skill**: Adapt to write/read `~/goose-agent-plans.md` directly (see §3.13)

> **Note:** Goose provides a native `/plan` CLI prompt command and `GOOSE_PLANNER_MODEL`/
> `GOOSE_PLANNER_PROVIDER` config settings. This is not a drop-in replacement for
> `create_plan()`, but may complement the registry approach — evaluate during Phase 5.

### 3.6 Agent Profiles → Recipes

Replace Warp agent profiles with Goose recipes. Recipes live in the repo at
`goose/recipes/<name>/recipe.yaml` and are discovered at runtime via
`GOOSE_RECIPE_PATH` pointing at the local clone (see §3.16, D6).

```yaml
# goose/recipes/planner/recipe.yaml
# Discovered via GOOSE_RECIPE_PATH — no install step needed
version: 1.0.0
title: Planner
description: Creates structured implementation plans
instructions: |
  You are a Planner agent. Your job is to create a detailed, structured
  implementation plan based on the user's specification. Write the plan
  to the slot directory and register it in ~/goose-agent-plans.md.
extensions:
  - name: developer
    type: platform
  - name: todo
    type: platform
settings:
  goose_model: claude-sonnet-4-6
  goose_provider: anthropic
```

> **Note:** The `settings` block in recipes supports only `goose_provider`,
> `goose_model`, `temperature`, and `max_turns`. `GOOSE_MODE` (permission mode)
> is not a recipe setting — set it in `~/.config/goose/config.yaml` or pass it
> as an environment variable to `goose run`.

### 3.7 `deploy-warp-tools` Skill → `deploy-goose-tools`

Adapt the deployment skill:
- Replace `warp-tools` references with `goose-tools`
- Replace `~/.warp/` paths with `~/.goose/`
- Replace profile installation with recipe installation
- Remove Warp Drive notebook import steps

### 3.8 `agent-launcher` Skill → `goose-launcher`

Replace Oz-specific launcher patterns (`oz agent run`, `--profile`, prompt externalization
via tmpfiles) with Goose equivalents:

```bash
# Goose launcher pattern — interactive
goose run --recipe "$RECIPE_FILE"

# Goose launcher pattern — headless (run and exit, no session stored)
goose run --recipe "$RECIPE_FILE" --no-session
```

Document: `--no-session` vs `--interactive`, recipe parameter substitution,
`GOOSE_RECIPE_PATH` configuration.

### 3.9 `list-warp-models` Skill → `list-goose-models`

Replace `oz model list` with Goose provider/model configuration:
- Read from `~/.config/goose/config.yaml`
- Document supported providers (Anthropic, OpenAI, Ollama, etc.)
- Update model catalog (`catalog.json`)

### 3.10 `plan-workflow` Skill

Adapt to drive `goose_pw_*.sh` scripts instead of `oz_pw_*.sh`. Update all slot
references from `~/.warp/state/plan_workflow/` → `~/.goose/state/plan_workflow/`.

### 3.11 AGENTS.md Updates

Remove or replace all Warp-specific rules:
- `AGENT_PROFILE_MODELS` → Goose `config.yaml` model configuration
- Remove Warp Drive / Command Palette references
- Keep all platform-agnostic rules (code style, imports, error handling, etc.)

### 3.12 Path Convention: `~/.config/goose/` (Config) vs `~/.goose/` (State)

Goose uses `~/.config/goose/` for user configuration (`config.yaml`, manually saved
recipes). `goose-tools` introduces `~/.goose/` for **runtime state** — slot directories,
`recipes.env`, and workflow scripts — that is managed by the toolchain, not by the user
or Goose Desktop.

| Root | Managed by | Contents |
|---|---|---|
| `~/.config/goose/` | Goose + user | `config.yaml`, Desktop-saved recipes |
| `~/.goose/state/plan_workflow/` | `goose-tools` | Slot dirs, `recipes.env` |
| `~/.goose/workflows/scripts/` | `goose-tools` | Installed `goose_pw_*.sh` scripts |

This mirrors how Goose itself separates config from session data.

### 3.13 `manage-plans` Skill

Adapt to remove all Warp/Oz-specific dependencies:
- Replace `create_plan()` tool call with `uuidgen` + direct registry write
- Replace `edit_plans` / `read_plans` tool calls with direct file read/write
- Replace `~/warp-agent-plans.md` with `~/goose-agent-plans.md`
- Remove `Warp Drive notebook` references
- Replace `oz_pw_review.sh` / `oz_pw_select.sh` step references with `goose_pw_*` equivalents
- Replace `~/.warp/state/plan_workflow/` paths with `~/.goose/state/plan_workflow/`

### 3.14 `fix-issue` Skill

Adapt to remove Warp/Oz-specific dependencies:
- Replace "create a Warp plan" with "create a goose-tools plan" (via `manage-plans`)
- Replace `Co-Authored-By: Oz <oz-agent@warp.dev>` with a neutral co-author tag
- Replace `~/warp-agent-plans.md` references with `~/goose-agent-plans.md`
- Replace `create_plan` tool call reference with the `uuidgen` registry approach

### 3.15 `review-and-fix-pr` Skill

Adapt to remove Warp/Oz-specific dependencies:
- Replace `Co-Authored-By: Oz <oz-agent@warp.dev>` with a neutral co-author tag
  (e.g., `Co-Authored-By: Goose <goose-agent@block.xyz>`)

### 3.16 Recipe Discovery via `GOOSE_RECIPE_PATH`

Recipes live in the repo at `goose/recipes/<name>/recipe.yaml`. Goose discovers them
at runtime via the `GOOSE_RECIPE_PATH` environment variable, which points at the
local clone. No recipe files are copied to `~/.config/goose/recipes/` — the repo
is the single source of truth.

**Setup** — `bin/goose-tools install globals` adds this to `~/.zshenv`:
```bash
export GOOSE_RECIPE_PATH="/Volumes/secure/code/goose-tools/goose/recipes"
```

After this, `goose run --recipe planner` resolves to
`/Volumes/secure/code/goose-tools/goose/recipes/planner/recipe.yaml` automatically.

**Why not `GOOSE_RECIPE_GITHUB_REPO`?** That feature requires recipes at the
repo root (`<name>/recipe.yaml`), which conflicts with the plan's nested
`goose/recipes/` layout. Since goose-tools users always have a local clone
(it's a toolchain with a CLI, scripts, and skills), `GOOSE_RECIPE_PATH` is
simpler, always current, and avoids the copy-drift problem entirely.

**`profiles.env` replacement** — replace with `recipes.env`, written by
`bin/goose-tools install globals`, recording the resolved recipe paths:

```bash
# ~/.goose/state/plan_workflow/recipes.env
GOOSE_TOOLS_ROOT=/Volumes/secure/code/goose-tools
PLANNER_RECIPE=${GOOSE_TOOLS_ROOT}/goose/recipes/planner/recipe.yaml
REVIEWER_RECIPE=${GOOSE_TOOLS_ROOT}/goose/recipes/reviewer/recipe.yaml
APPROVER_RECIPE=${GOOSE_TOOLS_ROOT}/goose/recipes/approver/recipe.yaml
CODER_RECIPE=${GOOSE_TOOLS_ROOT}/goose/recipes/coder/recipe.yaml
```

The `goose_pw_*.sh` scripts source this file instead of `profiles.env`.

### 3.17 Additional Skills — Minor Warp/Oz Text Replacement

The following 10 skills are not structurally Warp-dependent but contain Warp/Oz
text references (paths, co-author tags, tool names) that must be updated. These
are covered by Phase 5 step 8 but are enumerated here for completeness:

| Skill | # Refs | What to change |
|---|---|---|
| `improve-shell-quality` | 9 | `bin/warp-tools` → `bin/goose-tools`, `~/.warp/state/` → `~/.goose/state/` |
| `manage-capabilities` | 3 | "provided by Warp" → "provided by Goose", `warp-tools repository` → `goose-tools repository` |
| `manage-inventory` | 9 | `bin/warp-tools inventory` → `bin/goose-tools inventory`, detection logic paths |
| `manage-todo` | 4 | `bin/warp-tools todo` → `bin/goose-tools todo`, detection logic paths |
| `review-plan` | 5 | `oz_pw_review.sh` → `goose_pw_review.sh`, `oz_pw_edit.sh` → `goose_pw_edit.sh`, `oz_pw_finalize.sh` → `goose_pw_finalize.sh` |
| `review-pr` | 3 | `oz-agent@warp.dev` → neutral co-author tag, disclosure boilerplate |
| `sync-worktrees` | 2 | `Co-Authored-By: Oz <oz-agent@warp.dev>` → neutral co-author tag |
| `tune-agent-assets` | 4 | `warp-tools agent assets` → `goose-tools agent assets`, `warp/workflows/scripts/` → `goose/workflows/scripts/` |
| `update-deps` | 2 | `Co-Authored-By: Oz <oz-agent@warp.dev>` → neutral co-author tag |
| `write-skill` | 1 | `~/.warp/` anti-pattern example → `~/.goose/` |

### 3.18 Docs Updates

| Doc | Change |
|---|---|
| `README.md` | Full rewrite for Goose platform |
| `docs/plan-execute-workflow.md` | Replace `oz_pw_*.sh` commands with `goose_pw_*.sh` |
| `docs/operations.md` | Replace `bin/warp-tools` reference with `bin/goose-tools` |
| `docs/agent-profile-security.md` | Adapt for Goose permission modes (`GOOSE_MODE`) |
| `docs/global-warp-rule.md` | Replace with `docs/goose-config-defaults.md` |
| `docs/troubleshooting.md` | Update failure modes for Goose CLI |
| `docs/shell-compatibility.md` | Keep verbatim |

---

## 4. New Assets (Goose-Specific)

| Asset | Purpose |
|---|---|
| `goose/recipes/planner/recipe.yaml` | Planner agent recipe (discovered via `GOOSE_RECIPE_PATH`) |
| `goose/recipes/reviewer/recipe.yaml` | Reviewer agent recipe (discovered via `GOOSE_RECIPE_PATH`) |
| `goose/recipes/approver/recipe.yaml` | Approver agent recipe (discovered via `GOOSE_RECIPE_PATH`) |
| `goose/recipes/coder/recipe.yaml` | Coder agent recipe (discovered via `GOOSE_RECIPE_PATH`) |
| `docs/goose-config-defaults.md` | Recommended `~/.config/goose/config.yaml` settings |
| `docs/recipes.md` | Recipe authoring guide for goose-tools |
| `deploy-goose-tools` skill | Goose-native equivalent of `deploy-warp-tools` |
| `goose-launcher` skill | Goose-native equivalent of `agent-launcher` |
| `list-goose-models` skill | Goose-native equivalent of `list-warp-models` |

---

## 5. Execution Phases

### Phase 1 — Repo Bootstrap (Day 1)
1. Create `FuzzyCoder/goose-tools` repo on GitHub via `gh repo create`
2. Initialize locally: `git init`, license, `.gitignore`, stub `README.md`
3. Copy platform-agnostic assets verbatim: `utils/`, `tests/`, quality kit skills,
   `pyproject.toml`, CI, pre-commit config, shellcheck config
4. Initial commit and push

### Phase 2 — State & Path Layer (Day 1–2)
1. Update `utils/shell/paths.sh` — replace `~/.warp/` with `~/.goose/`
2. Create `bin/goose-tools` — rename and adapt from `bin/warp-tools`
3. Adapt all subcommands: `install`, `scaffold`, `update`, `doctor`, `slot`, `plan`
4. Update bats tests for renamed paths and scripts

### Phase 3 — Workflow Scripts (Day 2–3)
1. Create `goose/workflows/scripts/goose_pw_*.sh` (6 scripts)
2. Replace `oz agent run` calls with `goose run --recipe`
3. Replace `resolve_profile_id()` + `profiles.env` with `recipes.env` recipe path lookup (see §3.16)
4. Replace `create_plan()` with `uuidgen` + direct markdown registry writes
5. Adapt slot artifact verification logic

### Phase 4 — Recipes (Day 3)
1. Create `goose/recipes/<name>/recipe.yaml` directory structure (one subdir per recipe)
2. Author `planner`, `reviewer`, `approver`, `coder` recipes
3. Update `bin/goose-tools install globals` to write `GOOSE_RECIPE_PATH` to `~/.zshenv` and `recipes.env` to `~/.goose/state/plan_workflow/`
4. Verify `goose run --recipe planner` resolves correctly via `GOOSE_RECIPE_PATH`

### Phase 5 — Skills Adaptation (Day 4–5)
1. Adapt `deploy-warp-tools` → `deploy-goose-tools`
2. Adapt `agent-launcher` → `goose-launcher`
3. Adapt `list-warp-models` → `list-goose-models`
4. Adapt `plan-workflow` → update paths and script names
5. Adapt `manage-plans` → remove `create_plan()` / `read_plans` / `edit_plans` dependency (see §3.13)
6. Adapt `fix-issue` → remove Warp-specific co-author tag and plan primitives (see §3.14)
7. Adapt `review-and-fix-pr` → replace co-author tag (see §3.15)
8. Update the 10 additional skills with minor Warp/Oz text references (see §3.17 for the enumerated checklist)

### Phase 6 — Docs & AGENTS.md (Day 5–6)
1. Rewrite `README.md`
2. Update all `docs/` files
3. Update `AGENTS.md` (root, `tests/`, `utils/`)
4. Write `docs/goose-config-defaults.md`
5. Write `docs/recipes.md`
6. Regenerate `INVENTORY.md` and `CAPABILITIES.md`

### Phase 7 — Validation (Day 6–7)
1. Run full bats test suite
2. Run shellcheck on all scripts
3. Run `bin/goose-tools doctor`
4. Run quality lint (`slop`) — resolve any violations
5. End-to-end smoke test: run one full Plan→Execute cycle with Goose recipes

---

## 6. Key Decisions & Open Questions

| # | Decision | Resolution |
|---|---|---|
| D1 | Where does `goose-tools` live locally? | `/Volumes/secure/code/goose-tools` |
| D2 | GitHub visibility? | Public (mirrors warp-tools policy) |
| D3 | Plan ID generation without `create_plan()`? | `uuidgen` in shell |
| D4 | Recipe discovery for end users? | `GOOSE_RECIPE_PATH` pointing at the local clone's `goose/recipes/` directory — see §3.16 |
| D5 | Keep warp-tools alive in parallel? | Yes — separate repos, no cross-dependency |
| D6 | `GOOSE_RECIPE_GITHUB_REPO` for recipe distribution? | **Resolved: not used.** `GOOSE_RECIPE_GITHUB_REPO` requires root-level recipe directories, incompatible with the plan's nested `goose/recipes/` layout. Not needed — goose-tools users always have a local clone. Use `GOOSE_RECIPE_PATH` instead (see §3.16). `bin/goose-tools install globals` writes this to `~/.zshenv` automatically. |

---

## 7. Success Criteria

- [ ] `FuzzyCoder/goose-tools` repo exists and is public
- [ ] `bin/goose-tools install globals` runs without error on a clean machine
- [ ] Full Plan→Execute cycle completes with Goose recipes (planner → reviewer → coder)
- [ ] All bats tests pass
- [ ] shellcheck passes on all scripts with zero warnings
- [ ] Quality lint (`slop`) exits clean
- [ ] No `warp`, `oz`, or `~/.warp/` references remain outside of migration notes
- [ ] `CAPABILITIES.md` and `INVENTORY.md` are current and accurate
