#!/usr/bin/env bash
# TODO subcommand for goose-tools.
#
# Usage: bin/goose-tools todo [--scan-only]
# Regenerates TODO.md with quality analysis and prioritized recommendations.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

_todo_collect_quality() {
  local repo_root="$1"
  local out=""

  # Python quality checks
  if [ -f "${repo_root}/pyproject.toml" ]; then
    if command -v ruff >/dev/null 2>&1; then
      local ruff_out
      ruff_out="$(cd "$repo_root" && ruff check . 2>/dev/null | head -50 || printf '')"
      [ -n "$ruff_out" ] && out="${out}## Ruff\n${ruff_out}\n\n"
    fi
    if command -v ty >/dev/null 2>&1; then
      local ty_out
      ty_out="$(cd "$repo_root" && ty check . 2>/dev/null | head -50 || printf '')"
      [ -n "$ty_out" ] && out="${out}## ty\n${ty_out}\n\n"
    fi
  fi

  # Shellcheck
  local shellcheck_out=""
  local shell_files=()
  while IFS= read -r -d '' f; do
    shell_files+=("$f")
  done < <(find "$repo_root" -type f \
    \( -name '*.sh' -o -name 'goose-tools' \) \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -print0)
  if command -v shellcheck >/dev/null 2>&1 && [ ${#shell_files[@]} -gt 0 ]; then
    shellcheck_out="$(shellcheck -x --severity=warning \
      -e SC1090,SC1091,SC2034,SC2015 \
      "${shell_files[@]}" 2>/dev/null | head -40 || printf '')"
    [ -n "$shellcheck_out" ] && out="${out}## Shellcheck\n${shellcheck_out}\n\n"
  fi

  # Slop lint (try uv run if available)
  if [ -f "${repo_root}/.slop.toml" ]; then
    local slop_out=""
    if command -v uv >/dev/null 2>&1; then
      slop_out="$(cd "$repo_root" && uv run slop lint 2>/dev/null | head -40 || printf '')"
    elif command -v slop >/dev/null 2>&1; then
      slop_out="$(cd "$repo_root" && slop lint 2>/dev/null | head -40 || printf '')"
    fi
    [ -n "$slop_out" ] && out="${out}## Slop Lint\n${slop_out}\n\n"
  fi

  printf '%s' "$out"
}

_todo_find_long_functions() {
  local repo_root="$1"
  local out=""

  # Find shell functions >100 lines
  local sh_out=""
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    # Simple heuristic: count lines between function start and next empty line or function start
    local func_lines
    func_lines="$(awk '
      /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/ { in_func=1; count=0; next }
      in_func { count++; if (/^\}/) { if (count>100) print count; in_func=0 } }
    ' "$f" | head -5 || true)"
    if [ -n "$func_lines" ]; then
      sh_out="${sh_out}  - $(basename "$f"): functions exceeding 100 lines\n"
    fi
  done < <(find "$repo_root" -type f -name '*.sh' -not -path '*/.git/*' -print0)
  [ -n "$sh_out" ] && out="${out}### Shell Functions >100 Lines\n${sh_out}\n"

  # Find Python functions >100 lines
  local py_out=""
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    local py_funcs
    py_funcs="$(awk '
      /^[[:space:]]*def[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\s*\(/ { in_func=1; count=0; next }
      in_func { count++; if (/^[[:space:]]*def / || /^class /) { if (count>100) print count; in_func=0; if (/^[[:space:]]*def /) { count=0; next } } }
      END { if (in_func && count>100) print count }
    ' "$f" | head -5 || true)"
    if [ -n "$py_funcs" ]; then
      py_out="${py_out}  - $(basename "$f"): functions exceeding 100 lines\n"
    fi
  done < <(find "$repo_root" -type f -name '*.py' -not -path '*/.git/*' -print0)
  [ -n "$py_out" ] && out="${out}### Python Functions >100 Lines\n${py_out}\n"

  printf '%s' "$out"
}

_todo_extract_items() {
  local file="$1"
  [ -f "$file" ] || return 0
  # Extract checklist items: lines starting with '- [ ]'
  grep -E '^\s*- \[ \]' "$file" | sed 's/^\s*- \[ \] //' | sort
}

_todo_validate_snapshot() {
  local old_file="$1" new_file="$2" repo_root="$3"

  [ ! -f "$old_file" ] && return 0

  local old_items new_items removed_items
  old_items="$(_todo_extract_items "$old_file")"
  new_items="$(_todo_extract_items "$new_file")"

  removed_items="$(printf '%s\n' "$old_items" | while IFS= read -r item; do
    printf '%s\n' "$new_items" | grep -Fxq "$item" || printf '%s\n' "$item"
  done)"

  if [ -z "$removed_items" ]; then
    return 0
  fi

  local suspicious=""
  printf '%s\n' "$removed_items" | while IFS= read -r item; do
    # Try to find a commit in the last 24 hours referencing the item or a related file
    local found=0
    local keyword=""
    keyword="$(printf '%s' "$item" | awk '{print $1 $2}' | sed 's/[^A-Za-z0-9_-]//g' | head -c 40)"
    if [ -n "$keyword" ]; then
      git -C "$repo_root" log --oneline --since='24 hours ago' --grep="$keyword" >/dev/null 2>&1 && found=1
    fi
    if [ "$found" = "0" ]; then
      printf '  [SNAPSHOT] Removed item without matching commit: %s\n' "$item" >&2
      suspicious="yes"
    fi
  done

  # If any suspicious removals, we still allow it but warn
  return 0
}

cmd_todo() {
  local scan_only=0
  # shellcheck disable=SC2153
  if [ "${SCAN_ONLY}" = "1" ] || [ "${DRY_RUN}" = "1" ]; then
    scan_only=1
  fi

  local repo_root
  repo_root="$(git -C "${GOOSE_TOOLS_ROOT}" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'error: not a git repository\n' >&2
    exit 1
  }

  local quality_findings
  quality_findings="$(_todo_collect_quality "$repo_root")"

  local length_findings
  length_findings="$(_todo_find_long_functions "$repo_root")"

  local now
  now="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

  local tmp_todo
  tmp_todo="$(mktemp)"

  {
    printf '# goose-tools — TODO & Recommendations\n\n'
    printf 'Last Updated: %s\n\n' "$now"
    printf -- '---\n\n'

    printf '## Quality Summary\n\n'
    if [ -z "$quality_findings" ] && [ -z "$length_findings" ]; then
      printf 'All quality checks passed.\n\n'
    else
      if [ -n "$quality_findings" ]; then
        printf '### Tool Findings\n\n%s\n' "$quality_findings"
      fi
      if [ -n "$length_findings" ]; then
        printf '### Length / Complexity\n\n%s\n' "$length_findings"
      fi
    fi

    printf '## Active Tasks\n\n'

    # Generate prioritized recommendations based on findings
    local p0_found=0 p1_found=0

    if printf '%s' "$quality_findings" | grep -q 'Shellcheck\\|Ruff\\|ty\\|Slop'; then
      printf '### P0 — Critical Quality Violations\n\n'
      printf '%s' "$quality_findings" | while IFS= read -r line; do
        case "$line" in
          \#\#*) ;; # skip headers
          *) [ -n "$line" ] && printf '  - [ ] %s\n' "$line" ;;
        esac
      done
      p0_found=1
    fi

    if [ -n "$length_findings" ]; then
      printf '### P1 — Function Length / Complexity\n\n'
      printf '%s' "$length_findings" | while IFS= read -r line; do
        case "$line" in
          \#\#*) ;;
          *) [ -n "$line" ] && printf '  - [ ] %s\n' "$line" ;;
        esac
      done
      p1_found=1
    fi

    if [ "$p0_found" = "0" ] && [ "$p1_found" = "0" ]; then
      printf '  - [ ] No active quality violations.\n'
    fi

    printf '\n### P2 — Maintenance & Hygiene\n\n'
    printf '  - [ ] Review INVENTORY.md accuracy (<5%% divergence)\n'
    printf '  - [ ] Review TODO.md snapshot-diff for unexpected removals\n'
    printf '  - [ ] Run shell compat tests before releases\n'
    printf '  - [ ] Verify bats test coverage for new subcommands\n'

    printf '\n---\n\n'
    printf '## Recommendations\n\n'
    printf '### Process\n'
    # shellcheck disable=SC2016
    printf '  - [ ] Run `bin/goose-tools doctor` after install or update\n'
    # shellcheck disable=SC2016
    printf '  - [ ] Keep `bats` and `shellcheck` prerequisites up to date\n'

    printf '\n### Performance\n'
    # shellcheck disable=SC2016
    printf '  - [ ] Monitor `inventory` generation time (<5s target)\n'

  } > "$tmp_todo"

  # Snapshot-diff validation
  local old_todo="${repo_root}/TODO.md"
  _todo_validate_snapshot "$old_todo" "$tmp_todo" "$repo_root"

  if [ "$scan_only" = "1" ]; then
    printf '=== TODO Scan Only (would write to %s) ===\n' "$old_todo"
    cat "$tmp_todo"
    rm -f "$tmp_todo"
    return 0
  fi

  mv "$tmp_todo" "$old_todo"
  printf 'TODO.md regenerated: %s\n' "$old_todo"
}
