#!/usr/bin/env bash
# goose-tools managed — source: goose/workflows/scripts/goose_pw_select.sh — do not edit locally
# goose_pw_select.sh <SLOT> <PLAN_ID>
#
# Pin an existing active plan to a slot without launching an agent.
# Validates the plan_id in ~/goose-agent-plans.md and writes slot state files.
#
# DRY_RUN=1  Print resolved values and exit 0 without writing any files.
# Exit codes: 0 success, 1 validation failure.

set -euo pipefail

SLOT="${1:?usage: goose_pw_select.sh <SLOT> <PLAN_ID>}"
PLAN_ID="${2:?usage: goose_pw_select.sh <SLOT> <PLAN_ID>}"

PLANS_REGISTRY="${HOME}/goose-agent-plans.md"
STATE_DIR="${HOME}/.goose/state/plan_workflow"
SLOT_DIR="${STATE_DIR}/${SLOT}"

#------------------------------------------------------------------------------
# Validate slot name
#------------------------------------------------------------------------------
if ! printf '%s' "$SLOT" | grep -qE '^[a-z0-9][a-z0-9-]{0,31}$'; then
  printf 'error: invalid slot name "%s"\n  Must match ^[a-z0-9][a-z0-9-]{0,31}$\n' "$SLOT" >&2
  exit 1
fi

#------------------------------------------------------------------------------
# 1. Validate UUID format
#------------------------------------------------------------------------------
if ! printf '%s' "$PLAN_ID" | grep -qiE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
  printf 'error: invalid UUID "%s"\n  Expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\n' "$PLAN_ID" >&2
  exit 1
fi

#------------------------------------------------------------------------------
# 2. Check registry presence
#------------------------------------------------------------------------------
if [ ! -f "${PLANS_REGISTRY}" ]; then
  printf 'error: plan registry not found at "%s"\n  Run the Planner first to create a plan.\n' "${PLANS_REGISTRY}" >&2
  exit 1
fi

# Check Active Plans section (between "## Active Plans" and "## Archived")
IN_ACTIVE=$(awk '/^## Active Plans/,/^## Archived/' "${PLANS_REGISTRY}" \
  | grep '|' | grep -v 'Title\|---' \
  | awk -F'|' '{gsub(/ /,"",$3); print $3}' \
  | grep -c "^${PLAN_ID}$" 2>/dev/null || printf '0')

if [ "${IN_ACTIVE}" -gt 0 ]; then
  # Extract plan title from Active Plans
  PLAN_TITLE=$(awk '/^## Active Plans/,/^## Archived/' "${PLANS_REGISTRY}" \
    | grep '|' | grep -v 'Title\|---' \
    | awk -F'|' -v id="${PLAN_ID}" \
      '{gsub(/ /,"",$3); t=$2; gsub(/^ +| +$/,"",t); if ($3 == id) print t}' \
    | head -1)
  STATUS="active"
else
  # Check Archived Plans section
  IN_ARCHIVED=$(awk '/^## Archived Plans/,0' "${PLANS_REGISTRY}" \
    | grep '|' | grep -v 'Title\|---' \
    | awk -F'|' '{gsub(/ /,"",$3); print $3}' \
    | grep -c "^${PLAN_ID}$" 2>/dev/null || printf '0')

  if [ "${IN_ARCHIVED}" -gt 0 ]; then
    printf 'error: plan is archived, not resumable\n  Plan ID: %s\n  To start fresh, use: goose_pw_plan.sh <SLOT> "<TITLE>" "<SPEC>"\n' "${PLAN_ID}" >&2
    exit 1
  else
    printf 'error: plan not found in registry\n  Plan ID: %s\n  Registry: %s\n' "${PLAN_ID}" "${PLANS_REGISTRY}" >&2
    exit 1
  fi
fi

#------------------------------------------------------------------------------
# 3. Resolve current git repo root
#------------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not inside a git repository\n' >&2
  exit 1
}

#------------------------------------------------------------------------------
# 4. Slot conflict detection
#------------------------------------------------------------------------------
if [ -d "${SLOT_DIR}" ]; then
  if [ -f "${SLOT_DIR}/plan_id" ]; then
    EXISTING_PLAN_ID="$(cat "${SLOT_DIR}/plan_id")"
    if [ "${EXISTING_PLAN_ID}" != "${PLAN_ID}" ]; then
      printf 'error: slot conflict — slot "%s" is already pinned to plan "%s"\n  To reuse: bin/goose-tools slot clear %s\n' \
        "${SLOT}" "${EXISTING_PLAN_ID}" "${SLOT}" >&2
      exit 1
    fi
  fi
  if [ -f "${SLOT_DIR}/repo_root" ]; then
    EXISTING_REPO="$(cat "${SLOT_DIR}/repo_root")"
    if [ "${EXISTING_REPO}" != "${REPO_ROOT}" ]; then
      printf 'error: slot conflict — slot "%s" is pinned to a different repo\n  Pinned:  %s\n  Current: %s\n  To reuse: bin/goose-tools slot clear %s\n' \
        "${SLOT}" "${EXISTING_REPO}" "${REPO_ROOT}" "${SLOT}" >&2
      exit 1
    fi
  fi
fi

#------------------------------------------------------------------------------
# DRY_RUN guard
#------------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-0}"
if [ "${DRY_RUN}" = "1" ]; then
  printf '=== DRY RUN: goose_pw_select.sh ===\n'
  printf 'slot:       %s -> %s\n' "${SLOT}" "${SLOT_DIR}"
  printf 'plan_id:    %s\n' "${PLAN_ID}"
  printf 'plan_title: %s\n' "${PLAN_TITLE:-<unknown>}"
  printf 'repo_root:  %s\n' "${REPO_ROOT}"
  printf 'status:     %s\n' "${STATUS}"
  exit 0
fi

#------------------------------------------------------------------------------
# 5. Write slot state files
#------------------------------------------------------------------------------
mkdir -p "${SLOT_DIR}"
printf '%s' "${PLAN_ID}"    > "${SLOT_DIR}/plan_id"
printf '%s' "${PLAN_TITLE}" > "${SLOT_DIR}/plan_title"
printf '%s' "${REPO_ROOT}"  > "${SLOT_DIR}/repo_root"

printf 'Slot "%s" pinned:\n  plan_id:    %s\n  plan_title: %s\n  repo_root:  %s\n' \
  "${SLOT}" "${PLAN_ID}" "${PLAN_TITLE}" "${REPO_ROOT}"
printf 'Next step: goose_pw_review.sh %s reviewer\n' "${SLOT}"
