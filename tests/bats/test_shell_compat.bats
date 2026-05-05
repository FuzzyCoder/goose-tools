#!/usr/bin/env bats
# tests/bats/test_shell_compat.bats
# Shell compatibility smoke tests: verify scripts run under bash and zsh.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  SCRIPTS_DIR="${REPO_ROOT}/goose/workflows/scripts"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  # Fake git repo (canonicalize path)
  mkdir -p "${TEST_TMPDIR}/fake-repo"
  cd "${TEST_TMPDIR}/fake-repo"
  git init -q
  git commit --allow-empty -m "init" -q
  FAKE_REPO="$(git rev-parse --show-toplevel)"
  cd "${REPO_ROOT}"

  # Fake HOME with recipes.env
  FAKE_HOME="${TEST_TMPDIR}/fakehome"
  mkdir -p "${FAKE_HOME}/.warp/state/plan_workflow"
  cat > "${FAKE_HOME}/.warp/state/plan_workflow/recipes.env" <<'EOF'
PLANNER_RECIPE=test-planner-id
REVIEWER_RECIPE=test-reviewer-id
APPROVER_RECIPE=test-approver-id
CODER_RECIPE=test-coder-id
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

  # Fake slot
  FAKE_SLOT_DIR="${FAKE_HOME}/.warp/state/plan_workflow/compat-slot"
  mkdir -p "${FAKE_SLOT_DIR}"
  printf '%s' "${FAKE_REPO}"  > "${FAKE_SLOT_DIR}/repo_root"
  printf '%s' "Test Plan"               > "${FAKE_SLOT_DIR}/plan_title"
  printf '%s' "aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb" > "${FAKE_SLOT_DIR}/plan_id"
  printf 'Section 0: OK\n'              > "${FAKE_SLOT_DIR}/review_report.md"

  # Fake oz
  mkdir -p "${TEST_TMPDIR}/bin"
  cat > "${TEST_TMPDIR}/bin/oz" <<'OZEOF'
#!/usr/bin/env bash
printf 'error: oz called during compat test\n' >&2
exit 99
OZEOF
  chmod +x "${TEST_TMPDIR}/bin/oz"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "negative rule test passes under bash" {
  run bash "${REPO_ROOT}/tests/test_goose_pw_plan_negative_rule.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "negative rule test passes under zsh (if available)" {
  if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
  run zsh "${REPO_ROOT}/tests/test_goose_pw_plan_negative_rule.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "goose_pw_plan.sh DRY_RUN under zsh (if available)" {
  if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run zsh "${SCRIPTS_DIR}/goose_pw_plan.sh" "zsh-slot" "Title" "Spec"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "goose_pw_execute.sh DRY_RUN under zsh (if available)" {
  if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
  cd "${TEST_TMPDIR}/fake-repo"
  HOME="${FAKE_HOME}" PATH="${TEST_TMPDIR}/bin:${PATH}" DRY_RUN=1 \
    run zsh "${SCRIPTS_DIR}/goose_pw_execute.sh" "compat-slot"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "shell_compat/run_compat.sh passes under bash" {
  run bash "${REPO_ROOT}/tests/shell_compat/run_compat.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "shell_compat/run_compat.sh passes under zsh (if available)" {
  if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
  run zsh "${REPO_ROOT}/tests/shell_compat/run_compat.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}
