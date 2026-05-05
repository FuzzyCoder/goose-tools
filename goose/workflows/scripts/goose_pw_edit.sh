#!/usr/bin/env bash
# goose-tools managed — source: goose/workflows/scripts/goose_pw_edit.sh — do not edit locally
# goose_pw_edit.sh <SLOT>
#
# Apply REVIEWER-raised edits to the plan (Step 03 in the Plan→Execute workflow).
# Requires review_report.md in the slot (written by goose_pw_review.sh Step 02).
# Reads decisions.txt from the slot if present; absent is valid (no user decisions).
# Launches the Reviewer agent with an edit-plan-only prompt using file-path injection.
#
# DRY_RUN=1  Print resolved values and exit 0 without launching agent.
# Exit codes: 0 success, 1 validation failure.

set -euo pipefail

SLOT="${1:?usage: goose_pw_edit.sh <SLOT>}"

STATE_DIR="${HOME}/.goose/state/plan_workflow"
SLOT_DIR="${STATE_DIR}/${SLOT}"

#------------------------------------------------------------------------------
# Validate slot has required files
#------------------------------------------------------------------------------
for f in plan_id plan_title repo_root; do
  if [ ! -f "${SLOT_DIR}/${f}" ]; then
    printf 'error: slot "%s" is missing "%s"\n  Run Step 01 or 01b first, then Step 02.\n' \
      "${SLOT}" "${f}" >&2
    exit 1
  fi
done

PLAN_ID="$(cat "${SLOT_DIR}/plan_id")"
PLAN_TITLE="$(cat "${SLOT_DIR}/plan_title")"
PINNED_REPO="$(cat "${SLOT_DIR}/repo_root")"
REPORT_PATH="${SLOT_DIR}/review_report.md"
DECISIONS_PATH="${SLOT_DIR}/decisions.txt"

#------------------------------------------------------------------------------
# review_report.md is REQUIRED — fail loudly if missing
#------------------------------------------------------------------------------
if [ ! -f "${REPORT_PATH}" ] || [ ! -s "${REPORT_PATH}" ]; then
  printf 'error: review_report.md missing or empty — re-run Step 02 before editing\n  Expected at: %s\n  Run: goose_pw_review.sh %s reviewer\n' \
    "${REPORT_PATH}" "${SLOT}" >&2
  exit 1
fi

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

if [ -z "${REVIEWER_RECIPE:-}" ]; then
  printf 'error: REVIEWER_RECIPE not set in recipes.env\n' >&2; exit 1
fi

#------------------------------------------------------------------------------
# Determine decisions context
#------------------------------------------------------------------------------
if [ -f "${DECISIONS_PATH}" ] && [ -s "${DECISIONS_PATH}" ]; then
  DECISIONS_CONTEXT="User decisions are in: ${DECISIONS_PATH}
  Use read_files to load this file. Each line has format 'D1: <decision text>'.
  Blank lines and lines starting with '#' are comments — ignore them."
else
  DECISIONS_CONTEXT="No user decisions file found (${DECISIONS_PATH} is absent or empty).
  Apply all Reviewer recommendations without user overrides."
fi

#------------------------------------------------------------------------------
# Externalize edit instructions to a file (avoids oz CLI hang when --prompt
# exceeds ~1000 chars in the goose session retry loop).
#------------------------------------------------------------------------------
INPUT_PATH="${SLOT_DIR}/editor_input.md"

cat > "${INPUT_PATH}" << EOF
# Editor Instructions

You are the Reviewer continuing your own analytical review from Step 02 into a
targeted edit pass. Apply your previously written feedback — do not re-derive
it from scratch.
DO NOT implement any code. ONLY edit the plan document.

Role emphasis:
- Apply fresh analysis only when a [Dx] user decision changes the surrounding
  rationale. Do not re-examine conclusions already drawn in Step 02.
- Maintain analytical-critique framing throughout. Do NOT shift to
  Coder-executability framing — that is the Approver's role in Steps 04/05.

STEP 1 — Load the review report:
  Use read_files to load the full review report from:
    ${REPORT_PATH}
  This file contains the complete Section 0-6 review you wrote in Step 02.

STEP 2 — Load user decisions (if any):
  ${DECISIONS_CONTEXT}

STEP 3 — Load the current plan:
  Call read_plans with plan_id: ${PLAN_ID}

STEP 4 — Apply edits:
  Make ALL edits in a SINGLE edit_plans call. Do not make multiple smaller edits.
  Apply every [Rx] recommendation from the review report, incorporating any [Dx]
  user decisions that override or modify a recommendation.
  If a [Dx] decision rejects a recommendation, skip that [Rx] change.

STEP 5 — Report:
  Summarize which [Rx] items were applied and which [Dx] decisions were incorporated.
  State explicitly if any recommendation was skipped due to a user decision.
EOF

PROMPT="Read ${INPUT_PATH} via read_files and execute the workflow it describes."

#------------------------------------------------------------------------------
# DRY_RUN guard
#------------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-0}"
if [ "${DRY_RUN}" = "1" ]; then
  printf '=== DRY RUN: goose_pw_edit.sh ===\n'
  printf 'profile:    %s\n' "${REVIEWER_RECIPE}"
  printf 'name:       P03 Edit \xe2\x80\x94 %s\n' "${PLAN_TITLE}"
  printf 'cwd:        %s\n' "${PINNED_REPO}"
  printf 'report:     %s\n' "${REPORT_PATH}"
  printf 'decisions:  %s\n' "${DECISIONS_PATH}"
  printf 'input:      %s\n' "${INPUT_PATH}"
  printf '\n--- prompt ---\n%s\n' "${PROMPT}"
  printf '\n--- input file ---\n'
  cat "${INPUT_PATH}"
  exit 0
fi

#------------------------------------------------------------------------------
# Launch Reviewer for edit-only pass — runs interactively in the current
# terminal; goose run --recipe streams the agent's output to your shell and returns
# control when the agent ends its turn.
#------------------------------------------------------------------------------
printf 'Launching Reviewer (edit pass)...\n'
goose run --recipe \
  --profile "${REVIEWER_RECIPE}" \
   \
   \
  --cwd "${PINNED_REPO}" \
   || {
  printf 'error: goose run --recipe exited %s\n' "$?" >&2
  exit 1
}
