#!/usr/bin/env bats
# tests/bats/test_workflow_scripts.bats
# Tests for oz_pw_*.sh workflow scripts in DRY_RUN=1 mode.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  SCRIPTS_DIR="${REPO_ROOT}/warp/workflows/scripts"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  # Fake git repo (resolve canonical path for macOS /var/folders -> /private)
  mkdir -p "${TEST_TMPDIR}/fake-repo"
  cd "${TEST_TMPDIR}/fake-repo"
  git init -q
  git commit --allow-empty -m "init" -q
  FAKE_REPO="$(git rev-parse --show-toplevel)"
  cd "${REPO_ROOT}"

  # Fake HOME with profiles.env
  FAKE_HOME="${TEST_TMPDIR}/fakehome"
  mkdir -p "${FAKE_HOME}/.warp/state/plan_workflow"
  cat > "${FAKE_HOME}/.warp/state/plan_workflow/profiles.env" <<'EOF'
PLANNER_ID=test-planner-id
REVIEWER_ID=test-reviewer-id
APPROVER_ID=test-approver-id
CODER_ID=test-coder-id
EOF

  # Fake plan registry
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

  # Fake slot with required files
  FAKE_SLOT_DIR="${FAKE_HOME}/.warp/state/plan_workflow/bats-test-slot"
  mkdir -p "${FAKE_SLOT_DIR}"
  printf '%s' "${FAKE_REPO}"  > "${FAKE_SLOT_DIR}/repo_root"
  printf '%s' "Test Plan"               > "${FAKE_SLOT_DIR}/plan_title"
  printf '%s' "aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb" > "${FAKE_SLOT_DIR}/plan_id"
  printf 'Section 0: OK\n'              > "${FAKE_SLOT_DIR}/review_report.md"

  # Fake oz binary (must not be called in DRY_RUN mode)
  mkdir -p "${TEST_TMPDIR}/bin"
  cat > "${TEST_TMPDIR}/bin/oz" <<'OZEOF'
#!/usr/bin/env bash
printf 'error: oz called during DRY_RUN compat test\n' >&2
exit 99
OZEOF
  chmod +x "${TEST_TMPDIR}/bin/oz"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "oz_pw_plan.sh DRY_RUN=1 works under bash" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_plan.sh" \
    "bats-new-slot" "My Plan" "Plan spec"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "oz_pw_select.sh DRY_RUN=1 works under bash" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_select.sh" \
    "bats-select-slot" "aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pinned"* ]] || [[ "$output" == *"DRY"* ]]
}

@test "oz_pw_review.sh reviewer DRY_RUN=1 works under bash" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_review.sh" "bats-test-slot" "reviewer"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "oz_pw_review.sh approver DRY_RUN=1 works under bash" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_review.sh" "bats-test-slot" "approver"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "oz_pw_edit.sh DRY_RUN=1 works under bash" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_edit.sh" "bats-test-slot"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "oz_pw_finalize.sh DRY_RUN=1 works under bash" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_finalize.sh" "bats-test-slot"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "oz_pw_execute.sh DRY_RUN=1 works under bash" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_execute.sh" "bats-test-slot"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "oz_pw_plan.sh rejects invalid slot names" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_plan.sh" "UPPER" "Plan" "Spec"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid slot name"* ]]
}

@test "oz_pw_select.sh rejects invalid UUID" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_select.sh" "slot" "not-a-uuid"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid UUID"* ]]
}

@test "oz_pw_review.sh rejects invalid role" {
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run bash "${SCRIPTS_DIR}/oz_pw_review.sh" "bats-test-slot" "not-a-role"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid role"* ]]
}
