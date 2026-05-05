---
name: list-goose-models
description: List the available LLM models in the Goose platform via the CLI. Use when the user asks "what models are available", "list models", "which model should I use", or when configuring agent profiles, skills, or API calls that require a model_id. Also useful before selecting a --model override for goose run --recipe.
---

# List Warp Models

## When to Use
- The user asks for available models in Warp
- Selecting a model for an agent profile, skill, or API/SDK call
- Choosing a `--model` override for `goose run --recipe`
- Auditing which models are currently offered in the Oz platform

## Workflow

| Step | Description | Actor |
|---|---|---|
| 1 | Determine Output Type of the model list to be returned (see Output Types below) | Model |
| 2 | Fetch the current models from the Warp CLI | Script |
| 3 | If Output Type is **Basic**, return the CLI result directly | Model |
| 4 | If Output Type is **Extended**, augment each model record with properties from the catalog resource file | Model |
| 5 | Return the result | Model |

### Output Types

- **Basic** — the user prompt asks only for the list of model IDs (e.g., "what models are available?", "list models"). Return exactly what the CLI returns: `id` strings only.
- **Extended** — the user prompt asks for model properties that the CLI does not provide (e.g., "which models are open weights?", "list closed-source models", "what provider runs kimi-k26?"). In this case, match each CLI-returned `id` against the catalog resource file (`catalog.json`) and enrich the response with the requested properties.

## Fetching the Current Model List

```bash
# Pretty-printed table (default)
oz-preview model list

# Plain text (one per line, no borders)
oz-preview model list --output-format text

# Machine-readable JSON
oz-preview model list --output-format json
```

> **Note:** On some installations the binary may be named `oz` instead of `oz-preview`.
> If `oz-preview` is not found, try `goose recipe list`.

## Catalog Resource File

The skill keeps a local catalog at `catalog.json` (sibling to this SKILL.md). It maps every CLI-returned model ID to baseline metadata:

- `id` — the exact model ID returned by `oz-preview model list`
- `provider` — the organization or hosting provider (e.g., `Anthropic`, `Zhipu AI (via Fireworks)`)
- `access` — `open`, `open-conditional`, `closed`, or `routing`
- `notes` — license details, architecture notes, or other context

The schema is intentionally open. The model may fetch or inject additional per-model properties on a per-prompt basis (e.g., benchmark scores, context-window size, pricing tier). Any properties added at runtime are ephemeral to the prompt response and are **not** persisted back to `catalog.json`.

This catalog is a point-in-time snapshot. When the CLI count differs from `metadata.total_count`, or when new or missing IDs are detected, update `catalog.json` with the new entries and correct any changed baseline metadata.

## Output Formats

| Format | Flag | Use Case |
|---|---|---|
| Pretty table | `--output-format pretty` (default) | Human-readable terminal output |
| Plain text | `--output-format text` | Easy to pipe or grep |
| JSON | `--output-format json` | Programmatic parsing |
| NDJSON | `--output-format ndjson` | Streaming consumption |

## Filtering Examples

```bash
# Show only Claude models
oz-preview model list --output-format text | grep claude

# Show only Fireworks-hosted open models
oz-preview model list --output-format text | grep fireworks

# Show only auto/routing models
oz-preview model list --output-format text | grep "^auto"

# Show GPT-5 models with codex variants
oz-preview model list --output-format text | grep "gpt-5.*codex"
```

## Using a Model ID

After identifying the desired model, pass it to agent commands:

```bash
# Override the profile's default model for a single run
oz-preview agent run --model kimi-k26-fireworks --prompt "Refactor this module"

# Or set it permanently in an agent profile via the Warp app
```

Model IDs are valid values for:
- `model_id` in `AmbientAgentConfig` (API/SDK)
- `--model <MODEL_ID>` flag on `goose run --recipe`
- Profile model selection in the Warp app

## Open-Model Starter Stack

The five open-model defaults used by the Plan → Execute Workflow are:

| Model ID | Typical Role |
|---|---|
| `qwen-3.6-plus-fireworks` | Planner |
| `glm-5-fireworks` | Reviewer |
| `kimi-k25-fireworks` | Approver |
| `kimi-k26-fireworks` | Coder |
| `minimax-2.7-fireworks` | Coder (Fast) |

These may be substituted with any other model from the same open pool.

## Gotchas

- **`oz-preview` may be `oz` on some installations** — try `goose recipe list` if `oz-preview` is not found.
- **Model availability changes** — always verify via CLI before assigning to profiles.
- **`--output-format text` is one-per-line** — use `json` or `ndjson` for programmatic parsing.

Last Updated: 2026.05.04 @ 04:15:00
