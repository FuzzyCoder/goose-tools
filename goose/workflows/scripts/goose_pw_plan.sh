#!/usr/bin/env bash
# goose-tools managed — source: goose/workflows/scripts/goose_pw_plan.sh — do not edit locally
# goose_pw_plan.sh <SLOT> <PLAN_TITLE> <PLAN_SPEC>
#
# Launch the Planner agent to create a new plan and pin it to a slot.
# The script writes repo_root and plan_title directly; the agent writes plan_id.
#
# DRY_RUN=1  Print resolved prompt/profile/name/cwd and exit 0 without launching.
# Exit codes: 0 success, 1 validation/config failure.

set -euo pipefail

SLOT="${1:?usage: goose_pw_plan.sh <SLOT> <PLAN_TITLE> <PLAN_SPEC>}"
PLAN_TITLE="${2:?usage: goose_pw_plan.sh <SLOT> <PLAN_TITLE> <PLAN_SPEC>}"
PLAN_SPEC="${3:?usage: goose_pw_plan.sh <SLOT> <PLAN_TITLE> <PLAN_SPEC>}"

#------------------------------------------------------------------------------
# Validate slot name: ^[a-z0-9][a-z0-9-]{0,31}$
#------------------------------------------------------------------------------
case "$SLOT" in
  [a-z0-9]*)
    if ! printf '%s' "$SLOT" | grep -qE '^[a-z0-9][a-z0-9-]{0,31}$'; then
      printf 'error: invalid slot name "%s"\n  Must match ^[a-z0-9][a-z0-9-]{0,31}$ (lowercase alnum+hyphens, 1-32 chars)\n' "$SLOT" >&2
      exit 1
    fi
    ;;
  *)
    printf 'error: invalid slot name "%s"\n  Must start with a lowercase letter or digit\n' "$SLOT" >&2
    exit 1
    ;;
esac

#------------------------------------------------------------------------------
# Resolve current git repo root
#------------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not inside a git repository (goose_pw_plan.sh requires a git repo)\n' >&2
  exit 1
}

#------------------------------------------------------------------------------
# Slot state paths
#------------------------------------------------------------------------------
STATE_DIR="${HOME}/.goose/state/plan_workflow"
SLOT_DIR="${STATE_DIR}/${SLOT}"

#------------------------------------------------------------------------------
# Slot conflict detection
#------------------------------------------------------------------------------
if [ -d "${SLOT_DIR}" ]; then
  if [ -f "${SLOT_DIR}/plan_id" ]; then
    EXISTING_PLAN_ID="$(cat "${SLOT_DIR}/plan_id")"
    printf 'error: slot "%s" already has plan_id "%s"\n  To reuse this slot: bin/goose-tools slot clear %s\n  To pin an existing plan: goose_pw_select.sh %s <PLAN_ID>\n' \
      "$SLOT" "$EXISTING_PLAN_ID" "$SLOT" "$SLOT" >&2
    exit 1
  fi
  if [ -f "${SLOT_DIR}/repo_root" ]; then
    EXISTING_REPO="$(cat "${SLOT_DIR}/repo_root")"
    if [ "$EXISTING_REPO" != "$REPO_ROOT" ]; then
      printf 'error: slot "%s" is pinned to a different repo\n  Pinned:  %s\n  Current: %s\n  To reuse: bin/goose-tools slot clear %s\n' \
        "$SLOT" "$EXISTING_REPO" "$REPO_ROOT" "$SLOT" >&2
      exit 1
    fi
  fi
fi

#------------------------------------------------------------------------------
# Source profile IDs (set by: bin/goose-tools install globals)
#------------------------------------------------------------------------------
RECIPES_ENV="${STATE_DIR}/recipes.env"
if [ ! -f "${RECIPES_ENV}" ]; then
  printf 'error: recipes.env not found at "%s"\n  Run: bin/goose-tools install globals\n' "${RECIPES_ENV}" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "${RECIPES_ENV}"

if [ -z "${PLANNER_RECIPE:-}" ]; then
  printf 'error: PLANNER_RECIPE not set in recipes.env — re-run: bin/goose-tools install globals\n' >&2
  exit 1
fi

#------------------------------------------------------------------------------
# Write repo_root and plan_title directly (NOT delegated to agent)
#------------------------------------------------------------------------------
mkdir -p "${SLOT_DIR}"
printf '%s' "${REPO_ROOT}" > "${SLOT_DIR}/repo_root"
printf '%s' "${PLAN_TITLE}" > "${SLOT_DIR}/plan_title"

#------------------------------------------------------------------------------
# Build Planner instructions + plan spec into a file (read by agent via read_files).
# Rationale: oz CLI hangs in goose session retry loop when --prompt exceeds
# ~1000 chars, so we externalize all instructions and pass only a short pointer prompt.
#------------------------------------------------------------------------------
INPUT_PATH="${SLOT_DIR}/planner_input.md"
cat > "${INPUT_PATH}" <<EOF
# Planner Instructions
You are the Planner for goose-tools. Create a new implementation plan and register it.
Follow ALL steps below in order without skipping any.

STEP 1 — Generate a plan_id:
  Run the shell command: uuidgen
  Capture the UUID output — this is your plan_id.

STEP 2 — Register the plan in the registry:
  Append a new row to ~/goose-agent-plans.md (Active Plans table) with:
    - Title: exactly as specified in this prompt
    - Plan ID: the UUID from Step 1
    - Created: today's UTC date
    - Repo: the repo_root path

STEP 3 — Write plan_id to slot file:
  ONLY after the registry row in Step 2 is successfully written, write the plan_id UUID
  (and nothing else) to:
    /plan_id

  If Step 2 fails, do NOT write plan_id.

STEP 4 — Confirm:
  Confirm both the registry row and the slot file were written. Include the plan_id in your report.

# Plan quality guidance
- Before writing the plan body, use read_files or grep to look up any files,
  schemas, or modules referenced in the PLAN SPEC below. Do not rely on memory alone.
- Document architectural decisions, trade-offs, and rejected alternatives directly
  in the plan body (e.g. in a "Decisions" or "Alternatives" section). Do NOT expose
  private chain-of-thought; write only what belongs in the plan document.

# Plan Title
${PLAN_TITLE}

# Plan Spec
${PLAN_SPEC}
EOF

PROMPT="Read ${INPUT_PATH} via read_files and execute the Planner workflow it describes."

#------------------------------------------------------------------------------
# DRY_RUN guard — print resolved values and exit 0 without launching agent
#------------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-0}"
if [ "${DRY_RUN}" = "1" ]; then
  printf '=== DRY RUN: goose_pw_plan.sh ===\n'
  printf 'profile:   %s\n' "${PLANNER_RECIPE}"
  printf 'name:      P01 Plan \xe2\x80\x94 %s\n' "${PLAN_TITLE}"
  printf 'cwd:       %s\n' "${REPO_ROOT}"
  printf 'slot_dir:  %s\n' "${SLOT_DIR}"
  printf 'input:     %s\n' "${INPUT_PATH}"
  printf '\n--- prompt ---\n%s\n' "${PROMPT}"
  printf '\n--- input file ---\n'
  cat "${INPUT_PATH}"
  exit 0
fi

#------------------------------------------------------------------------------
# Launch Planner — runs interactively in the current terminal; goose run --recipe
# streams the agent's output to your shell and returns control when the agent
# ends its turn.
#------------------------------------------------------------------------------
printf 'Launching Planner agent...\n'
goose run --recipe \
  "${PLANNER_RECIPE}" \
   \
   \
  --text "$(cat "${PROMPT_FILE}")" --no-session \
   || {
  printf 'error: goose run --recipe exited %s\n' "$?" >&2
  exit 1
}

if [ ! -f "${SLOT_DIR}/plan_id" ]; then
  printf 'error: agent ended its turn but plan_id was not written\n  Expected at: %s\n' "${SLOT_DIR}/plan_id" >&2
  exit 1
fi
printf 'plan_id: %s\n' "$(cat "${SLOT_DIR}/plan_id")"
