---
name: improve-shell-quality
description: Refactor monolithic shell scripts into modular command modules with bats tests, shellcheck CI, and pre-commit hooks. Use when a shell script exceeds ~100 lines, lacks tests, or needs shellcheck integration.
---

# Improve Shell Quality

## When to Use

- A shell script exceeds ~100 lines or violates the single-responsibility principle.
- `bin/goose-tools` or any workflow script is monolithic and untestable.
- No bats tests exist for shell subcommands or workflow scripts.
- No shellcheck CI gate or pre-commit hook is configured.
- A script mixes flag parsing, business logic, and side-effects in one file.

## Goals

- Decompose monolithic scripts into a thin dispatcher + per-command modules.
- Add bats test coverage for every subcommand and workflow script.
- Run shellcheck on every `.sh` file with zero warnings (tuned via `.shellcheckrc`).
- Block bad commits with a pre-commit hook and CI gate.

## Project Layout (Target)

```
project/
├── bin/
│   └── mytool              # thin dispatcher (~50 lines)
├── commands/
│   ├── install.sh          # cmd_install()
│   ├── doctor.sh           # cmd_doctor()
│   └── slot.sh             # cmd_slot_clear(), cmd_slot_archive()
├── utils/shell/
│   ├── flags.sh            # parse_flags(), DRY_RUN, FORCE, OUTPUT_JSON
│   ├── paths.sh            # STATE_DIR, GLOBAL_* constants
│   ├── logging.sh          # log_info(), log_warn(), log_err()
│   └── common.sh           # sha256_file(), install_file(), manifest_add()
├── tests/bats/
│   ├── test_subcommands.bats
│   └── test_workflows.bats
├── .shellcheckrc           # external-sources, severity, common disables
├── .pre-commit-config.yaml # shellcheck + bats hooks
└── .github/workflows/ci.yml # shellcheck + bats job (ubuntu + macos matrix)
```

## Phase 1 — Decompose the Monolith

### 1.1 Identify logical subcommands

Read the script and list every `case` branch or `if` block that handles a distinct user-facing operation. Each operation becomes one file under `commands/`.

### 1.2 Extract shared helpers

Move these into `utils/shell/`:

- **Flag parsing** → `flags.sh`
  ```bash
  parse_flags() { ... }   # consumes --dry-run, --force, --json, etc.
  ```
- **Path constants** → `paths.sh`
  ```bash
  STATE_DIR="${HOME}/.warp/state/..."
  ```
- **Logging** → `logging.sh`
  ```bash
  log_info() { printf '%s\n' "$1"; }
  ```
- **File I/O / manifest** → `common.sh`
  ```bash
  sha256_file() { ... }
  install_file() { ... }
  ```

### 1.3 Write the thin dispatcher

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARP_TOOLS_ROOT="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel)"

# Source shared helpers
source "${WARP_TOOLS_ROOT}/utils/shell/flags.sh"
source "${WARP_TOOLS_ROOT}/utils/shell/paths.sh"
source "${WARP_TOOLS_ROOT}/utils/shell/logging.sh"
source "${WARP_TOOLS_ROOT}/utils/shell/common.sh"

# Source command modules
source "${WARP_TOOLS_ROOT}/commands/install.sh"
source "${WARP_TOOLS_ROOT}/commands/doctor.sh"
# ... etc.

# Parse global flags and shift them out
parse_flags "$@"
set -- "${REMAINING[@]}"

SUBCOMMAND="${1:-}"
shift || true

case "${SUBCOMMAND}" in
  install) cmd_install "$@" ;;
  doctor)  cmd_doctor "$@" ;;
  *)       printf 'error: unknown subcommand\n' >&2; exit 1 ;;
esac
```

Constraints:
- Dispatcher ≤ 50 lines of non-comment logic.
- No business logic in the dispatcher — only routing and flag parsing.

### 1.4 Convert each subcommand to a module

Example: `commands/doctor.sh`

```bash
#!/usr/bin/env bash
# Doctor subcommand for mytool.
# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

cmd_doctor() {
  local self_test=0
  [ "${1:-}" = "--self-test" ] && self_test=1
  # ... checks ...
}
```

## Phase 5 — Update Install / Doctor Commands

- `install globals` must copy `commands/` and `utils/shell/` to the consumer.
- `doctor --self-test` should verify `commands/` and `utils/shell/` exist in the install target.

## Exit Criteria

- Dispatcher ≤ 50 lines.
- Each command module ≤ 100 lines (or split further).
- `bats tests/bats/` passes with 0 failures.
- `shellcheck -x` on all `.sh` files returns 0.
- Pre-commit hook blocks commits that fail shellcheck or bats.
- CI passes on both ubuntu-latest and macos-latest.

## Gotchas

- **Mixing flag parsing, business logic, and side-effects** in one file creates untestable monoliths.
- **`shellcheck source=` directives must point to actual paths** — missing sources cause false negatives.
- **Bats tests need isolated temp directories** — shared state between tests causes flaky failures.

## References Structure

- `references/bats-testing.md` — Install bats, test patterns, isolation tests, mocks
- `references/shellcheck-ci.md` — Shellcheck configuration, local runs, CI gate, pre-commit hooks

Last Updated: 2026.05.04 @ 04:15:00
