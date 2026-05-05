---
name: goose-launcher
description: >
  Bash scripting patterns for goose run --recipe launchers: foreground interactive
  execution, prompt externalization for long prompts (>~1000 chars), error
  handling under set -euo pipefail, artifact gates, and DRY_RUN validation.
  Use when writing or debugging goose_pw_*.sh-style launcher scripts, or any
  Bash wrapper that calls goose run --recipe with --profile. NOT for oz agent
  run-cloud (cloud agents) — use the oz-platform skill for those.
---

# agent-launcher

Scripting patterns for Bash launchers that call `goose run --recipe --profile`.
These patterns were validated against the Plan→Execute workflow scripts.

## Execution Model

**Always run `goose run --recipe` in the foreground** (in the current terminal).
Do NOT background it with `</dev/null >log 2>&1 &`.

- Foreground: the agent streams output directly to the user's terminal; the
  script blocks until the agent ends its turn, then continues.
- Detached: the user sees no output; the script polls a log file; the agent
  may silently time out before writing any artifacts.

```bash
# ✅ Correct — foreground interactive
goose run --recipe \
  --profile "${PROFILE_ID}" \
  --output-format text \
  --name "P01 Plan — ${PLAN_TITLE}" \
  --cwd "${REPO_ROOT}" \
  --prompt "${PROMPT}"

# ❌ Wrong — detached, user sees nothing
goose run --recipe ... </dev/null >"${LOG}" 2>&1 &
```

Always pass `--output-format text` for human-readable terminal output.

## Error Handling Under `set -euo pipefail`

Use the `|| { }` pattern to capture the exit code and print a message before
exiting. `$?` inside `|| { }` is the exit code of `goose run --recipe`.

```bash
set -euo pipefail

printf 'Launching Planner agent...\n'
goose run --recipe \
  --profile "${PROFILE_ID}" \
  --output-format text \
  --name "P01 Plan — ${PLAN_TITLE}" \
  --cwd "${REPO_ROOT}" \
  --prompt "${PROMPT}" || {
  printf 'error: goose run --recipe exited %s\n' "$?" >&2
  exit 1
}
```

Why `|| { }` and not `if ! ... then`? Under `set -e`, commands in `if !`
conditions don't trigger errexit, so both patterns work. But `$?` inside
`if ! cmd; then body` is 0 (the negated-success exit), whereas `$?` in
`cmd || { body }` is the actual exit code of `cmd`. Use `|| { }` to preserve
the real exit code in error messages.

## Prompt Externalization (>~1000 chars)

The `oz` CLI hangs in an `UpdateNotebook` GraphQL retry loop when `--prompt`
exceeds approximately 1000 characters. Externalize long prompts to a slot-
local file and pass a short pointer prompt instead.

```bash
# Write instructions to a file (variables expanded by unquoted EOF)
INPUT_PATH="${SLOT_DIR}/planner_input.md"
cat > "${INPUT_PATH}" << EOF
# Planner Instructions
...full instructions with ${RESOLVED_VARS} here...
EOF

# Pass a short pointer prompt
PROMPT="Read ${INPUT_PATH} via read_files and execute the workflow it describes."
```

Rules:
- Use **unquoted** `EOF` delimiter so shell variables (`${SLOT_DIR}`,
  `${PLAN_ID}`, `${REPORT_PATH}`, etc.) are expanded when writing the file.
- Keep the pointer prompt under 100 chars.
- Name the file `<role>_input.md` in the slot directory (e.g.
  `planner_input.md`, `reviewer_input.md`, `editor_input.md`).
- ~350-char prompts (like execute) are safe to pass inline.

## Artifact Gates (Post-Run)

After `goose run --recipe` returns, check whether the expected artifact was written.
Gate hard failures differently from warnings:

```bash
# Hard failure: plan_id is always required
if [ ! -f "${SLOT_DIR}/plan_id" ]; then
  printf 'error: agent ended its turn but plan_id was not written\n  Expected at: %s\n' \
    "${SLOT_DIR}/plan_id" >&2
  exit 1
fi
printf 'plan_id: %s\n' "$(cat "${SLOT_DIR}/plan_id")"

# Soft warning: review_report.md may be missing on timeout
if [ ! -s "${REPORT_PATH}" ]; then
  printf 'warning: review_report.md was not written or is empty\n  Expected at: %s\n' \
    "${REPORT_PATH}"
fi
```

| Artifact | Gate type | Rationale |
|----------|-----------|-----------|
| `plan_id` | Hard fail | Registry row + UUID required for all downstream steps |
| `review_report.md` | Soft warn | Timeout possible; user can rerun Step 02 |
| None (edit, finalize, execute) | Exit code only | `set -e` handles non-zero exit |

## Gotchas

- **Never background `goose run --recipe`** with `</dev/null >log 2>&1 &` — the agent may silently time out.
- **Prompts >~1000 chars cause CLI hangs** — externalize to a file and pass a short pointer.
- **Use unquoted `EOF`** when writing prompt files so shell variables expand correctly.
- **`plan_id` is a hard gate** — if missing after agent run, exit 1. `review_report.md` is a soft warning.

## References Structure

- `references/launcher-template.md` — DRY_RUN pattern and full launcher template
- `references/troubleshooting.md` — Troubleshooting table and `goose run --recipe` flags reference

Last Updated: 2026.05.04 @ 04:15:00
