#!/usr/bin/env bash
# goose-tools managed — source: goose/workflows/scripts/goose_pw_review.sh — do not edit locally
# goose_pw_review.sh <SLOT> <reviewer|approver>
#
# Validate the slot's repo_root matches current repo, then launch Reviewer
# (Step 02) or Approver (Step 04) with the standardized review prompt.
# The review agent is required to write its full report to the slot's
# review_report.md before ending its turn.
#
# DRY_RUN=1  Print resolved values and exit 0 without launching agent.
# Exit codes: 0 success, 1 validation failure.

set -euo pipefail

SLOT="${1:?usage: goose_pw_review.sh <SLOT> <reviewer|approver>}"
ROLE="${2:?usage: goose_pw_review.sh <SLOT> <reviewer|approver>}"

STATE_DIR="${HOME}/.goose/state/plan_workflow"
SLOT_DIR="${STATE_DIR}/${SLOT}"

#------------------------------------------------------------------------------
# Validate role
#------------------------------------------------------------------------------
case "${ROLE}" in
  reviewer|approver) ;;
  *)
    printf 'error: invalid role "%s" — must be "reviewer" or "approver"\n' "${ROLE}" >&2
    exit 1
    ;;
esac

#------------------------------------------------------------------------------
# Validate slot has required files
#------------------------------------------------------------------------------
for f in plan_id plan_title repo_root; do
  if [ ! -f "${SLOT_DIR}/${f}" ]; then
    printf 'error: slot "%s" is missing "%s"\n  Run Step 01 (goose_pw_plan.sh) or Step 01b (goose_pw_select.sh) first.\n' \
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
  printf 'error: recipes.env not found at "%s"\n  Run: bin/goose-tools install globals\n' "${RECIPES_ENV}" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "${RECIPES_ENV}"

#------------------------------------------------------------------------------
# Select profile and step number
#------------------------------------------------------------------------------
if [ "${ROLE}" = "reviewer" ]; then
  if [ -z "${REVIEWER_RECIPE:-}" ]; then
    printf 'error: REVIEWER_RECIPE not set in recipes.env\n' >&2; exit 1
  fi
  PROFILE_RECIPE="${REVIEWER_RECIPE}"
  STEP="P02"
else
  if [ -z "${APPROVER_RECIPE:-}" ]; then
    printf 'error: APPROVER_RECIPE not set in recipes.env\n' >&2; exit 1
  fi
  PROFILE_RECIPE="${APPROVER_RECIPE}"
  STEP="P04"
fi

#------------------------------------------------------------------------------
# Externalize review instructions to a file (avoids oz CLI hang when --prompt
# exceeds ~1000 chars in the goose session retry loop).
#------------------------------------------------------------------------------
REPORT_PATH="${SLOT_DIR}/review_report.md"
INPUT_PATH="${SLOT_DIR}/${ROLE}_input.md"

if [ "${ROLE}" = "reviewer" ]; then
cat > "${INPUT_PATH}" <<EOF
# Review Instructions (Reviewer)

Review plan ${PLAN_ID} for correctness, completeness, clarity, and consistency.
DO NOT modify the plan. DO NOT execute.

Step 1: read_plans to load the current plan content. Then use grep/read_files to
  cross-reference any claims against actual files in the repo (cwd: ${PINNED_REPO}).

Step 2: Analyze the plan. Consider correctness of the
  approach, completeness of coverage, clarity of specifications, and consistency
  across all sections.

Role emphasis: fresh analytical critique with interleaved codebase lookups.
  Apply first-principles correctness — challenge every technical claim independently.
  The frame is: "is the plan logically sound?"

Step 3: Write the full review report in sections 0-6:
  Section 0: Executive Summary (overall assessment, ship/hold recommendation)
  Section 1: Correctness Issues
  Section 2: Completeness Issues
  Section 3: Clarity Issues
  Section 4: Consistency Issues
  Section 5: Recommendations [R1], [R2], ... (each cites its source issue)
  Section 6: Decisions Required [D1], [D2], ... (each cites its issue and related [Rx])
  Cross-reference format in Sections 5 and 6:
    [R3] -> Issue 1a          (recommendation cites its source issue)
    [D1] -> Issue 2a, [R5]   (decision cites its issue and related recommendation)

Wait for user direction before any Step 4 actions.

REVIEW REPORT PERSISTENCE CONTRACT (required before ending your turn):
  Write the complete Section 0-6 report verbatim to:
    ${REPORT_PATH}
  Overwrite any prior contents. This file is the handoff medium that lets the
  Step 03/05 edit agent apply your exact recommendations without re-deriving them.
  Use create_file or run_shell_command to write the file.
EOF
else
cat > "${INPUT_PATH}" <<EOF
# Review Instructions (Approver)

Review plan ${PLAN_ID} for correctness, completeness, clarity, and consistency.
DO NOT modify the plan. DO NOT execute.

Step 1: read_plans to load the current plan content. Then use grep/read_files to
  cross-reference any claims against actual files in the repo (cwd: ${PINNED_REPO}).

Step 2: Analyze the plan. Consider correctness of the
  approach, completeness of coverage, clarity of specifications, and consistency
  across all sections.

Role emphasis: Coder-executability gate. Reframe Section 0 as:
  "can a coding agent implement this plan without stalling on missing
  specifications or ambiguous instructions?"
  Treat every ambiguity that would force the Coder to make an undocumented
  architectural decision as a blocker, regardless of whether it was flagged
  in the first review.

Step 3: Write the full review report in sections 0-6:
  Section 0: Executive Summary (overall assessment, ship/hold recommendation)
  Section 1: Correctness Issues
  Section 2: Completeness Issues
  Section 3: Clarity Issues
  Section 4: Consistency Issues
  Section 5: Recommendations [R1], [R2], ... (each cites its source issue)
  Section 6: Decisions Required [D1], [D2], ... (each cites its issue and related [Rx])
  Cross-reference format in Sections 5 and 6:
    [R3] -> Issue 1a          (recommendation cites its source issue)
    [D1] -> Issue 2a, [R5]   (decision cites its issue and related recommendation)

Wait for user direction before any Step 4 actions.

REVIEW REPORT PERSISTENCE CONTRACT (required before ending your turn):
  Write the complete Section 0-6 report verbatim to:
    ${REPORT_PATH}
  Overwrite any prior contents. This file is the handoff medium that lets the
  Step 03/05 edit agent apply your exact recommendations without re-deriving them.
  Use create_file or run_shell_command to write the file.
EOF
fi

PROMPT="Read ${INPUT_PATH} via read_files and execute the workflow it describes."

#------------------------------------------------------------------------------
# DRY_RUN guard
#------------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-0}"
if [ "${DRY_RUN}" = "1" ]; then
  printf '=== DRY RUN: goose_pw_review.sh ===\n'
  printf 'role:       %s\n' "${ROLE}"
  printf 'profile:    %s\n' "${PROFILE_RECIPE}"
  printf 'name:       %s Review \xe2\x80\x94 %s\n' "${STEP}" "${PLAN_TITLE}"
  printf 'cwd:        %s\n' "${PINNED_REPO}"
  printf 'report_to:  %s\n' "${REPORT_PATH}"
  printf 'input:      %s\n' "${INPUT_PATH}"
  printf '\n--- prompt ---\n%s\n' "${PROMPT}"
  printf '\n--- input file ---\n'
  cat "${INPUT_PATH}"
  exit 0
fi

#------------------------------------------------------------------------------
# Launch agent — runs interactively in the current terminal; goose run --recipe
# streams the agent's output to your shell and returns control when the agent
# ends its turn.
#------------------------------------------------------------------------------
printf 'Launching %s agent...\n' "${ROLE}"
goose run --recipe \
  "${REVIEWER_RECIPE}" \
   \
   \
  --cwd "${PINNED_REPO}" \
   || {
  printf 'error: goose run --recipe exited %s\n' "$?" >&2
  exit 1
}

if [ ! -s "${REPORT_PATH}" ]; then
  printf 'warning: review_report.md was not written or is empty\n  Expected at: %s\n' "${REPORT_PATH}"
fi
