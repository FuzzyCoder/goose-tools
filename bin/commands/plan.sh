#!/usr/bin/env bash
# Plan subcommand for goose-tools.
#
# Usage: bin/goose-tools plan [--with-inventory] [--with-todo] <SLOT> <PLAN_TITLE> [PLAN_SPEC]
# Thin wrapper around goose_pw_plan.sh that injects INVENTORY.md / TODO.md context
# into the plan spec before delegating. No workflow scripts are modified.
#
# Parses its own --with-* flags; global flags (--dry-run, --force, --json)
# are already consumed by the dispatcher before cmd_plan is called.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

_plan_read_file_or_warn() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    printf '\n---\n\n## %s\n\n' "$label"
    cat "$path"
  else
    printf 'warning: %s not found at %s — skipping\n' "$label" "$path" >&2
  fi
}

cmd_plan() {
  # Use global flags set by parse_flags in the dispatcher:
  # WITH_INVENTORY, WITH_TODO, DRY_RUN.
  local slot title spec

  if [ $# -lt 2 ]; then
    printf 'error: plan requires at least <SLOT> and <PLAN_TITLE>\n'
    printf '  Usage: bin/goose-tools plan [--with-inventory] [--with-todo] <SLOT> <PLAN_TITLE> [PLAN_SPEC]\n' >&2
    exit 1
  fi

  slot="${1:-}"; shift
  title="${1:-}"; shift

  # PLAN_SPEC can be provided as a literal string or read from a file
  spec="${1:-}"; shift || true

  local repo_root
  repo_root="$(git -C "${GOOSE_TOOLS_ROOT}" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'error: not a git repository\n' >&2
    exit 1
  }

  # Inject context into the plan spec
  local injected=""
  if [ "${WITH_INVENTORY:-0}" = "1" ]; then
    injected="$(_plan_read_file_or_warn "${repo_root}/INVENTORY.md" "Repository Inventory")"
  fi
  if [ "${WITH_TODO:-0}" = "1" ]; then
    injected="${injected}$(_plan_read_file_or_warn "${repo_root}/TODO.md" "Current TODO")"
  fi

  if [ -n "$injected" ]; then
    if [ -n "$spec" ]; then
      spec="${spec}${injected}"
    else
      spec="${injected}"
    fi
  fi

  # Build the final plan spec as a heredoc to avoid quoting issues
  local spec_path
  spec_path="$(mktemp)"
  if [ -n "$spec" ]; then
    printf '%s' "$spec" > "$spec_path"
  else
    printf '(No plan spec provided; agent will rely on inventory/todo context only.)\n' > "$spec_path"
  fi

  # Export DRY_RUN so goose_pw_plan.sh sees it
  export DRY_RUN

  local script
  script="${GOOSE_TOOLS_ROOT}/goose/workflows/scripts/goose_pw_plan.sh"
  if [ ! -f "$script" ]; then
    printf 'error: goose_pw_plan.sh not found at %s\n' "$script" >&2
    rm -f "$spec_path"
    exit 1
  fi

  bash "$script" "$slot" "$title" "$(cat "$spec_path")"
  local rc=$?
  rm -f "$spec_path"
  return $rc
}
