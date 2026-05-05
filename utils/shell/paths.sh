#!/usr/bin/env bash
# Path resolution constants for goose-tools.

# Resolve goose-tools repo root (script lives in bin/)
resolve_goose_tools_root() {
  git -C "$(dirname "$0")/.." rev-parse --show-toplevel 2>/dev/null || {
    printf 'error: must be run from within the goose-tools git repo\n' >&2
    exit 1
  }
}

# Global state directories (~/.goose/ is goose-tools runtime state)
STATE_DIR="${HOME}/.goose/state/plan_workflow"
# shellcheck disable=SC2034
RECIPES_ENV="${STATE_DIR}/recipes.env"
# shellcheck disable=SC2034
GLOBAL_MANIFEST="${HOME}/.goose/state/goose-tools-manifest.json"
# shellcheck disable=SC2034
GLOBAL_SCRIPTS_DIR="${HOME}/.goose/workflows/scripts"
# shellcheck disable=SC2034
GLOBAL_WORKFLOWS_DIR="${HOME}/.goose/workflows"
# shellcheck disable=SC2034
GLOBAL_SKILLS_DIR="${HOME}/.agents/skills"
# shellcheck disable=SC2034
PLANS_REGISTRY="${HOME}/goose-agent-plans.md"

# GitHub API base (overridable for testing)
# shellcheck disable=SC2034
GITHUB_API_BASE="${GITHUB_API_BASE:-https://api.github.com}"
