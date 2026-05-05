# Recipe Authoring Guide

goose-tools ships four built-in recipes for the Plan→Execute workflow. This guide
covers the recipe format, extension configuration, and how to add new recipes.

## Recipe Format

Recipes are YAML files at `goose/recipes/<name>/recipe.yaml`:

```yaml
version: 1.0.0
title: My Recipe
description: What this recipe does
instructions: |
  Detailed agent instructions here.
extensions:
  - name: developer
    type: platform
  - name: todo
    type: platform
settings:
  goose_provider: anthropic
  goose_model: claude-sonnet-4-6
activities:
  - "Example prompt 1"
  - "Example prompt 2"
```

## Extension Types

| Type | Description | Example |
|---|---|---|
| `platform` | Runs in the agent process | `developer`, `todo`, `extensionmanager` |
| `builtin` | Part of the bundled goose MCP server | `computercontroller`, `memory` |
| `stdio` | External MCP server via stdin/stdout | `knowledgegraphmemory` |
| `streamable_http` | Remote MCP server via HTTP | `excalidraw` |

## Settings Schema

The `settings` block supports:

| Field | Description |
|---|---|
| `goose_provider` | Provider name (e.g. `anthropic`, `openai`) |
| `goose_model` | Model name (e.g. `claude-sonnet-4-6`) |
| `temperature` | Model temperature (0.0–1.0) |
| `max_turns` | Maximum agent turns before stopping |

`GOOSE_MODE` (permission mode) is **not** a recipe setting. Set it in
`~/.config/goose/config.yaml` or pass as an env var: `GOOSE_MODE=chat goose run --recipe reviewer`.

## Running Recipes

```bash
# Interactive (stays in session after completing)
goose run --recipe planner --interactive

# Headless (runs and exits)
goose run --recipe planner --no-session

# With parameters
goose run --recipe planner --params slot=my-slot --params title="My Plan"

# Preview recipe details
goose run --recipe planner --explain
```

## Adding a New Recipe

1. Create `goose/recipes/<name>/recipe.yaml`
2. The name (directory name) is how you reference it in `goose run --recipe <name>`
3. No install step needed — `GOOSE_RECIPE_PATH` picks it up automatically

## Discovery

`bin/goose-tools install globals` writes to `~/.zshenv`:
```bash
export GOOSE_RECIPE_PATH="/path/to/goose-tools/goose/recipes"
```

Goose discovers all recipes in this directory automatically. Run `goose recipe list`
to verify.
