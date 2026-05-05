#!/usr/bin/env bash
# generate_report.sh — thin wrapper for generate_report.py
#
# Usage:
#   ./.agents/skills/quality-lint-report/scripts/generate_report.sh [--root <path>] [--orphans]
#
# Resolves its own directory so it can be invoked from any working directory.
# Delegates to uv run python and propagates the script's exit code via exec.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec uv run python "${SCRIPT_DIR}/generate_report.py" "$@"
