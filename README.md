# goose-tools

Canonical portable agent toolchain for the [Goose](https://github.com/block/goose) platform.

`goose-tools` provides a structured **Plan → Review → Edit → Approve → Finalize → Execute**
workflow, a reusable code-quality kit (13-rule slop linter + remediation skills), and a
portable skill library — all built natively for Goose.

## What is this?

`goose-tools` orchestrates multiple specialized Goose agents (Planner, Reviewer, Approver,
Coder) through an isolated per-slot state directory using Goose recipes:

1. **Create** a plan with the Planner recipe
2. **Review** it with the Reviewer recipe (7-dimension report)
3. **Edit** the plan based on review recommendations
4. **Approve** with the Approver recipe (second-pass review)
5. **Finalize** the plan based on approval recommendations
6. **Execute** with the Coder recipe

All slot state lives in `~/.goose/state/plan_workflow/<slot>/` — isolated per slot,
allowing concurrent plans in separate terminals.

## Prerequisites

- [Goose](https://github.com/block/goose) installed (`goose` on PATH or via Goose Desktop)
- A local clone of this repo at a stable path (e.g. `/Volumes/secure/code/goose-tools`)
- A configured Goose provider in `~/.config/goose/config.yaml`
- `uuidgen` available (standard on macOS; `uuid-runtime` on Linux)

## Quick Start

```bash
# 1. Clone
git clone https://github.com/FuzzyCoder/goose-tools.git ~/code/goose-tools

# 2. Install globals (writes GOOSE_RECIPE_PATH to ~/.zshenv, installs scripts + skills)
cd ~/code/goose-tools
./bin/goose-tools install globals

# 3. Reload your shell
source ~/.zshenv

# 4. Verify recipe discovery
goose run --recipe planner --explain
```

## Recipe Discovery

Recipes live in `goose/recipes/<name>/recipe.yaml` and are discovered at runtime via
`GOOSE_RECIPE_PATH`. No files are copied — the repo is the single source of truth.

`bin/goose-tools install globals` writes this to `~/.zshenv`:
```bash
export GOOSE_RECIPE_PATH="/path/to/goose-tools/goose/recipes"
```

After that, `goose run --recipe planner` resolves automatically.

## Shell Tests and Quality Checks

```bash
# Install test dependencies
./scripts/install_shell_dev.sh

# Run bats tests
bats tests/bats/

# Run shellcheck
for f in bin/goose-tools utils/shell/*.sh bin/commands/*.sh goose/workflows/scripts/*.sh; do
  shellcheck -x "$f"
done
```

## Slop Code Quality

```bash
# Run a fresh quality report
uv run ./.agents/skills/quality-lint-report/scripts/generate_report.sh

# Run with orphan detection
uv run ./.agents/skills/quality-lint-report/scripts/generate_report.sh --orphans

# Run tests
UV_LOCKED=0 uv run pytest
```

## The 6-Stage Loop

```
(00 List) → 01 Create+Pin | 01b Pin Existing → 02 Review → 03 Edit →
           04 Approve → 05 Finalize → 06 Execute → (07 Archive)
```

## Documentation

- `docs/plan-execute-workflow.md` — full operator guide
- `docs/operations.md` — `bin/goose-tools` subcommand reference
- `docs/goose-config-defaults.md` — recommended `~/.config/goose/config.yaml` settings
- `docs/troubleshooting.md` — common failure modes and recovery
- `docs/shell-compatibility.md` — supported shells and forbidden constructs
- `docs/agent-profile-security.md` — Goose permission mode patterns
- `CAPABILITIES.md` — skill catalog with example prompts

## Repository Layout

```
goose-tools/
├── bin/goose-tools             # CLI: install, scaffold, update, doctor, slot
├── goose/
│   ├── recipes/                # Agent recipes (discovered via GOOSE_RECIPE_PATH)
│   │   ├── planner/recipe.yaml
│   │   ├── reviewer/recipe.yaml
│   │   ├── approver/recipe.yaml
│   │   └── coder/recipe.yaml
│   └── workflows/
│       └── scripts/            # Runtime goose_pw_*.sh scripts
├── .agents/skills/             # Portable skills (installed globally + per-repo)
├── AGENTS.md                   # Root AGENTS.md template for consumer repos
├── tests/                      # bats tests, shellcheck, compat
├── utils/shell/                # Shared shell utilities
└── docs/                       # Operator guides and reference docs
```

Last Updated: 2026-05-05
