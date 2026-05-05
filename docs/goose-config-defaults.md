# Goose Config Defaults

Recommended `~/.config/goose/config.yaml` settings for goose-tools users.

## Minimal Config

```yaml
GOOSE_PROVIDER: anthropic
GOOSE_MODEL: claude-sonnet-4-6
GOOSE_MODE: smart_approve
GOOSE_RECIPE_PATH: /path/to/goose-tools/goose/recipes
```

## Full Recommended Config

```yaml
# Provider
GOOSE_PROVIDER: anthropic
GOOSE_MODEL: claude-sonnet-4-6

# Permission mode
# auto          — no approval required (fastest)
# smart_approve — AI decides what needs review (recommended)
# approve       — review every action
# chat          — disable all tools
GOOSE_MODE: smart_approve

# Recipe discovery — set this to your goose-tools clone path
# bin/goose-tools install globals writes this to ~/.zshenv automatically
# GOOSE_RECIPE_PATH: /Volumes/secure/code/goose-tools/goose/recipes

# Shell used by the developer extension
GOOSE_SHELL: /bin/zsh

# Telemetry
GOOSE_TELEMETRY_ENABLED: true
```

## Permission Modes for Plan→Execute Workflow

| Role | Recommended Mode | Rationale |
|---|---|---|
| Planner | `smart_approve` | Needs file reads; plan creation is low risk |
| Reviewer | `chat` | Read-only — no tool execution needed |
| Approver | `chat` | Read-only — no tool execution needed |
| Coder | `smart_approve` | Needs full file edit + shell access |

Override per-session: `GOOSE_MODE=chat goose run --recipe reviewer`

## Extensions

Enable/disable extensions in `config.yaml`:

```yaml
extensions:
  developer:
    enabled: true
    type: platform
  todo:
    enabled: true
    type: platform
  knowledgegraphmemory:
    enabled: true
    type: stdio
    cmd: npx
    args: [-y, "@modelcontextprotocol/server-memory"]
    timeout: 300
```
