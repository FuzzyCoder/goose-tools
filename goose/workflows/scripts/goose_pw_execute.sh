#!/usr/bin/env bash
# goose-tools managed — source: goose/workflows/scripts/goose_pw_execute.sh — do not edit locally
# goose_pw_execute.sh <SLOT> [fast]
#
# Launch the Coder agent to execute the finalized, approved plan (Step 06).
# Validates the slot's repo_root matches the current git repository.
# Optional second argument: "fast" selects ${CODER_FAST_RECIPE} profile instead of ${CODER_RECIPE}.
#
# DRY_RUN=1  Print resolved values and exit 0 without launching agent.
# Exit codes: 0 success, 1 validation failure.

set -euo pipefail

SLOT="${1:?usage: goose_pw_execute.sh <SLOT> [fast]}"
FLAVOR="${2:-}"

STATE_DIR="${HOME}/.goose/state/plan_workflow"
SLOT_DIR="${STATE_DIR}/${SLOT}"

#------------------------------------------------------------------------------
# Validate slot has required files
#------------------------------------------------------------------------------
for f in plan_id plan_title repo_root; do
  if [ ! -f "${SLOT_DIR}/${f}" ]; then
    printf 'error: slot "%s" is missing "%s"\n  Complete Steps 01-05 before executing.\n' \
      "${SLOT}" "${f}" >&2
    exit 1
  fi
done

PLAN_ID="$(cat "${SLOT_DIR}/plan_id")"
PLAN_TITLE="$(cat "${SLOT_DIR}/plan_title")"
PINNED_REPO="$(cat "${SLOT_DIR}/repo_root")"

#------------------------------------------------------------------------------
# Validate current repo matches pinned repo_root
#------------------------------------------------------------------------------
CURRENT_REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not inside a git repository\n' >&2
  exit 1
}
if [ "${CURRENT_REPO}" != "${PINNED_REPO}" ]; then
  printf 'error: current repo does not match slot "%s" pinned repo\n  Pinned:  %s\n  Current: %s\n' \
    "${SLOT}" "${PINNED_REPO}" "${CURRENT_REPO}" >&2
  exit 1
fi

#------------------------------------------------------------------------------
# Source profile IDs
#------------------------------------------------------------------------------
RECIPES_ENV="${STATE_DIR}/recipes.env"
if [ ! -f "${RECIPES_ENV}" ]; then
  printf 'error: recipes.env not found\n  Run: bin/goose-tools install globals\n' >&2
  exit 1
fi
# shellcheck source=/dev/null
. "${RECIPES_ENV}"

if [ -z "${CODER_RECIPE:-}" ]; then
  printf 'error: CODER_RECIPE not set in recipes.env\n' >&2; exit 1
fi

#------------------------------------------------------------------------------
# Select profile based on optional flavor argument
#------------------------------------------------------------------------------
if [ "${FLAVOR}" = "fast" ]; then
  if [ -z "${CODER_FAST_RECIPE:-}" ]; then
    printf 'error: CODER_FAST_RECIPE not set in recipes.env — re-run: bin/goose-tools install globals\n' >&2
    exit 1
  fi
  PROFILE_RECIPE="${CODER_FAST_RECIPE}"
else
  PROFILE_RECIPE="${CODER_RECIPE}"
fi

#------------------------------------------------------------------------------
# Externalize coder instructions to a file (avoids oz CLI hang when --prompt
# exceeds ~1000 chars in the goose session retry loop).
#------------------------------------------------------------------------------
INPUT_PATH="${SLOT_DIR}/coder_input.md"

cat > "${INPUT_PATH}" <<EOF
# Coder Instructions

Execute plan ${PLAN_ID}. The plan has been reviewed and approved — implement it fully.

STEP 1 — Segment the plan:
  Read the plan using read_plans. Before starting any implementation, identify all
  phases or major sections and list them briefly. This segmentation anchors your
  progress tracking for all subsequent steps.

STEP 2 — Implement each phase in order:
  Work through each phase systematically. Preserve established context between tool
  calls — do not re-derive information already confirmed in earlier steps.

  Proceed on minor implementation details without stopping. Stop and report a blocker
  when ambiguity touches any of:
    - Architecture or system design
    - Public behavior or interface contract
    - Data model or schema
    - Security posture
    - Validation scope

STEP 3 — Quality checks:
  Run any relevant tests or quality checks specified in the plan.

STEP 4 — Report:
  Report what was implemented and any deviations from the plan. If a blocker was
  encountered and stopped execution, report it clearly with the affected plan section.
EOF

PROMPT="Read ${INPUT_PATH} via read_files and execute the Coder workflow it describes."

#------------------------------------------------------------------------------
# DRY_RUN guard
#------------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-0}"
if [ "${DRY_RUN}" = "1" ]; then
  printf '=== DRY RUN: goose_pw_execute.sh ===\n'
  printf 'flavor:    %s\n' "${FLAVOR:-default}"
  printf 'profile:   %s\n' "${PROFILE_RECIPE}"
  printf 'name:      P06 Execute \xe2\x80\x94 %s\n' "${PLAN_TITLE}"
  printf 'cwd:       %s\n' "${PINNED_REPO}"
  printf 'input:     %s\n' "${INPUT_PATH}"
  printf '\n--- prompt ---\n%s\n' "${PROMPT}"
  printf '\n--- input file ---\n'
  cat "${INPUT_PATH}"
  exit 0
fi

#------------------------------------------------------------------------------
# Launch Coder — runs interactively in the current terminal; goose run --recipe
# streams the agent's output to your shell and returns control when the agent
# ends its turn.
#------------------------------------------------------------------------------
printf 'Launching Coder agent...\n'
goose run --recipe \
  "${REVIEWER_RECIPE}" \
   \
   \
  --cwd "${PINNED_REPO}" \
   || {
  printf 'error: goose run --recipe exited %s\n' "$?" >&2
  exit 1
}
