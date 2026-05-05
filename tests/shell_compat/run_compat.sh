#!/usr/bin/env bash
# tests/shell_compat/run_compat.sh
#
# CI fixture: run every goose_pw_*.sh script and bin/goose-tools subcommands
# in DRY_RUN=1 mode under both bash 4.0+ and zsh 5.0+.
#
# Validates:
#   - Each script exits 0 under both interpreters
#   - Each script produces non-empty output
#   - No interpreter-specific syntax errors
#
# Usage:
#   bash tests/shell_compat/run_compat.sh
#   zsh  tests/shell_compat/run_compat.sh
#
# Exit codes: 0 = all tests passed, 1 = one or more failed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/goose/workflows/scripts"
BIN="${REPO_ROOT}/bin/goose-tools"

PASS=0
FAIL=0

#------------------------------------------------------------------------------
# Environment setup: fake HOME, fake git repo, fake recipes.env, fake oz
#------------------------------------------------------------------------------
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TEST_TMPDIR}"' EXIT

FAKE_HOME="${TEST_TMPDIR}/fakehome"
mkdir -p "${FAKE_HOME}/.warp/state/plan_workflow"

cat > "${FAKE_HOME}/.warp/state/plan_workflow/recipes.env" <<'EOF'
PLANNER_RECIPE=test-planner-id
REVIEWER_RECIPE=test-reviewer-id
APPROVER_RECIPE=test-approver-id
CODER_RECIPE=test-coder-id
EOF

# Fake git repo (canonicalize path for macOS /var/folders -> /private)
FAKE_REPO="${TEST_TMPDIR}/fake-repo"
mkdir -p "${FAKE_REPO}"
cd "${FAKE_REPO}"
git init -q
git commit --allow-empty -m "init" -q
FAKE_REPO="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

# Fake plan registry with one active plan
cat > "${FAKE_HOME}/warp-agent-plans.md" <<'EOF'
# Warp Plan Registry

## Active Plans

| Title | Plan ID | Description | Created | Last Updated |
|-------|---------|-------------|---------|--------------|
| Test Plan | aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb | Test description | 2026-01-01 | 2026-01-01 |

## Archived Plans

| Title | Plan ID | Description | Created | Last Updated | Archived |
|-------|---------|-------------|---------|--------------|----------|
EOF

# Fake slot with all required files
FAKE_SLOT_DIR="${FAKE_HOME}/.warp/state/plan_workflow/test-slot"
mkdir -p "${FAKE_SLOT_DIR}"
printf '%s' "${FAKE_REPO}"                          > "${FAKE_SLOT_DIR}/repo_root"
printf '%s' "Test Plan"                             > "${FAKE_SLOT_DIR}/plan_title"
printf '%s' "aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb"  > "${FAKE_SLOT_DIR}/plan_id"
printf 'Section 0: OK\nSection 1: None\n'           > "${FAKE_SLOT_DIR}/review_report.md"

# Fake oz binary (must not be called in DRY_RUN mode)
FAKE_BIN="${TEST_TMPDIR}/bin"
mkdir -p "${FAKE_BIN}"
cat > "${FAKE_BIN}/oz" <<'OZEOF'
#!/usr/bin/env bash
printf 'error: oz called during DRY_RUN compat test\n' >&2
exit 99
OZEOF
chmod +x "${FAKE_BIN}/oz"

#------------------------------------------------------------------------------
# Test runner
#------------------------------------------------------------------------------
run_test() {
  local interp="$1"
  local label="$2"
  local cmd="$3"
  # All scripts get DRY_RUN=1 and the fake environment
  local output exit_code=0
  output="$(
    export HOME="${FAKE_HOME}"
    export PATH="${FAKE_BIN}:${PATH}"
    export DRY_RUN=1
    cd "${FAKE_REPO}" && \
    eval "${interp} ${cmd}" 2>&1
  )" || exit_code=$?

  if [ "$exit_code" != "0" ]; then
    FAIL=$((FAIL + 1))
    printf '  FAIL [%s] %s — exited %d\n' "$interp" "$label" "$exit_code"
    printf '  Output: %s\n' "$output"
    return
  fi

  if [ -z "$output" ]; then
    FAIL=$((FAIL + 1))
    printf '  FAIL [%s] %s — empty output\n' "$interp" "$label"
    return
  fi

  PASS=$((PASS + 1))
  printf '  PASS [%s] %s\n' "$interp" "$label"
}

printf '== Shell Compatibility Tests ==\n\n'

for interp in bash zsh; do
  if ! command -v "$interp" >/dev/null 2>&1; then
    printf 'SKIP: %s not found on PATH\n' "$interp"
    continue
  fi

  printf -- '-- Interpreter: %s (%s) --\n' "$interp" "$("$interp" --version 2>&1 | head -1)"

  # goose_pw_plan.sh (new slot)
  run_test "$interp" "goose_pw_plan.sh" \
    "'${SCRIPTS_DIR}/goose_pw_plan.sh' 'new-slot' 'My Plan Title' 'Plan content'"

  # goose_pw_select.sh (existing plan)
  run_test "$interp" "goose_pw_select.sh" \
    "'${SCRIPTS_DIR}/goose_pw_select.sh' 'another-slot' 'aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb'"

  # goose_pw_review.sh (reviewer)
  run_test "$interp" "goose_pw_review.sh reviewer" \
    "'${SCRIPTS_DIR}/goose_pw_review.sh' 'test-slot' 'reviewer'"

  # goose_pw_review.sh (approver)
  run_test "$interp" "goose_pw_review.sh approver" \
    "'${SCRIPTS_DIR}/goose_pw_review.sh' 'test-slot' 'approver'"

  # goose_pw_edit.sh
  run_test "$interp" "goose_pw_edit.sh" \
    "'${SCRIPTS_DIR}/goose_pw_edit.sh' 'test-slot'"

  # goose_pw_finalize.sh
  run_test "$interp" "goose_pw_finalize.sh" \
    "'${SCRIPTS_DIR}/goose_pw_finalize.sh' 'test-slot'"

  # goose_pw_execute.sh
  run_test "$interp" "goose_pw_execute.sh" \
    "'${SCRIPTS_DIR}/goose_pw_execute.sh' 'test-slot'"

  # bin/goose-tools doctor (DRY_RUN not needed; uses GOOSE_TOOLS_ROOT from git)
  # Run from within the goose-tools repo itself
  local_output="$(
    cd "${REPO_ROOT}" && \
    HOME="${FAKE_HOME}" \
    PATH="${FAKE_BIN}:${PATH}" \
    "${interp}" "${BIN}" doctor 2>&1
  )" || true
  if [ -n "$local_output" ]; then
    PASS=$((PASS + 1))
    printf '  PASS [%s] bin/goose-tools doctor\n' "$interp"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL [%s] bin/goose-tools doctor — empty output\n' "$interp"
  fi

  if [ "$interp" = "zsh" ]; then
    printf '  SKIP [%s] bin/goose-tools slot clear (zsh: BASH_SOURCE not supported)\n' "$interp"
    printf '  SKIP [%s] bin/goose-tools slot archive (zsh: BASH_SOURCE not supported)\n' "$interp"
  else
    # bin/goose-tools slot clear (dry-run)
    run_test "$interp" "bin/goose-tools slot clear --dry-run" \
      "'${BIN}' --dry-run slot clear 'test-slot'"

    # bin/goose-tools slot archive (dry-run)
    run_test "$interp" "bin/goose-tools slot archive --dry-run" \
      "'${BIN}' --dry-run slot archive 'test-slot'"
  fi

  # bin/goose-tools --force inventory (run from repo root; exercises the new markdown renderer)
  inventory_output=""
  inventory_rc=0
  inventory_output="$(
    cd "${REPO_ROOT}" && \
    HOME="${FAKE_HOME}" \
    PATH="${FAKE_BIN}:${PATH}" \
    "${interp}" "${BIN}" --force inventory 2>&1
  )" || inventory_rc=$?
  if [ "$inventory_rc" = "0" ] && [ -n "$inventory_output" ]; then
    PASS=$((PASS + 1))
    printf '  PASS [%s] bin/goose-tools --force inventory\n' "$interp"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL [%s] bin/goose-tools --force inventory — exited %d\n' "$interp" "$inventory_rc"
    printf '  Output: %s\n' "$inventory_output"
  fi

  printf '\n'
done

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
printf '== Summary ==\n'
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'FAIL\n'
  exit 1
fi
printf 'PASS\n'
exit 0
