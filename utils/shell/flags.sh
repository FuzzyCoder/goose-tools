#!/usr/bin/env bash
# Shared flag parsing helpers for warp-tools.

# Global flag defaults
# shellcheck disable=SC2034
DRY_RUN=0
# shellcheck disable=SC2034
FORCE=0
# shellcheck disable=SC2034
OUTPUT_JSON=0
# shellcheck disable=SC2034
SCAN_ONLY=0
# shellcheck disable=SC2034
WITH_INVENTORY=0
# shellcheck disable=SC2034
WITH_TODO=0
# shellcheck disable=SC2034
PROFILE_ONLY=0

# Parse global flags from "$@", leaving remaining args in a new array.
# Usage: parse_flags "$@"; set -- "${REMAINING[@]}"
parse_flags() {
  REMAINING=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)        DRY_RUN=1;         shift ;;
      --force)          FORCE=1;           shift ;;
      --json)           OUTPUT_JSON=1;     shift ;;
      --scan-only)      SCAN_ONLY=1;       shift ;;
      --with-inventory) WITH_INVENTORY=1;  shift ;;
      --with-todo)      WITH_TODO=1;       shift ;;
      --profile-only)   PROFILE_ONLY=1;    shift ;;
      --help|-h) shift ;;
      --) shift; REMAINING+=("$@"); break ;;
      -*) printf 'error: unknown flag: %s\n' "$1" >&2; exit 1 ;;
      *)  REMAINING+=("$1"); shift ;;
    esac
  done
}
