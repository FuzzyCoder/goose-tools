#!/usr/bin/env bash
# Path resolution constants for warp-tools.

# GitHub API base URL — used by utils/shell/github.sh helpers.
# Override in tests by setting GITHUB_API_BASE before sourcing.
GITHUB_API_BASE="${GITHUB_API_BASE:-https://api.github.com}"

# Resolve warp-tools repo root (script lives in bin/)
resolve_warp_tools_root() {
  git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null || {
    printf 'error: must be run from within the warp-tools git repo\n' >&2
    exit 1
  }
}

# Global state directories
STATE_DIR="${HOME}/.warp/state/plan_workflow"
# shellcheck disable=SC2034
PROFILES_ENV="${STATE_DIR}/profiles.env"
# shellcheck disable=SC2034
GLOBAL_MANIFEST="${HOME}/.warp/state/warp-tools-manifest.json"
# shellcheck disable=SC2034
GLOBAL_SCRIPTS_DIR="${HOME}/.warp/workflows/scripts"
# shellcheck disable=SC2034
GLOBAL_WORKFLOWS_DIR="${HOME}/.warp/workflows"
# shellcheck disable=SC2034
GLOBAL_SKILLS_DIR="${HOME}/.agents/skills"
# shellcheck disable=SC2034
PLANS_REGISTRY="${HOME}/warp-agent-plans.md"
