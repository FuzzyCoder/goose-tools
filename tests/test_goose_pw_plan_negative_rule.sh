#!/usr/bin/env bash
# tests/test_goose_pw_plan_negative_rule.sh
#
# Validates the new-plan pinning negative rule for goose_pw_plan.sh.
# Must pass under BOTH bash 4.0+ and zsh 5.0+.
#
# Assertions:
#   (a) Composed Planner prompt contains the phrase "plan_id" in context of writing
#       to the slot path (i.e., the agent is instructed to write the plan_id file).
#   (b) Script source does NOT contain tail or awk access to ~/warp-agent-plans.md
#       (the script must not scrape the registry to get plan_id after agent exits).
#   (c) Composed Planner prompt does NOT instruct the agent to write repo_root or plan_title
#       (those are written by the script directly, not delegated to the agent).
#   (d) Script source contains explicit direct-write commands for repo_root and plan_title.
#
# Usage:
#   bash tests/test_goose_pw_plan_negative_rule.sh
#   zsh  tests/test_goose_pw_plan_negative_rule.sh
#
# Exit codes: 0 = all assertions passed, 1 = one or more assertions failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLAN_SCRIPT="${SCRIPT_DIR}/goose/workflows/scripts/goose_pw_plan.sh"

PASS=0
FAIL=0

assert_pass() {
  PASS=$((PASS + 1))
  printf '  PASS: %s\n' "$1"
}

assert_fail() {
  FAIL=$((FAIL + 1))
  printf '  FAIL: %s\n' "$1"
}

printf 'Running negative rule assertions for goose_pw_plan.sh...\n\n'

#------------------------------------------------------------------------------
# Set up a minimal fake slot/profiles environment so DRY_RUN=1 can run
#------------------------------------------------------------------------------
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TEST_TMPDIR}"' EXIT

# Create a fake git repo for the test
FAKE_REPO="${TEST_TMPDIR}/fake-repo"
mkdir -p "${FAKE_REPO}"
git -C "${FAKE_REPO}" init -q
git -C "${FAKE_REPO}" commit --allow-empty -m "init" -q

# Create fake recipes.env
FAKE_STATE="${TEST_TMPDIR}/state"
mkdir -p "${FAKE_STATE}"
cat > "${FAKE_STATE}/recipes.env" <<'EOF'
PLANNER_RECIPE=test-planner-id
REVIEWER_RECIPE=test-reviewer-id
APPROVER_RECIPE=test-approver-id
CODER_RECIPE=test-coder-id
EOF

TEST_SLOT="test-slot"
TEST_PLAN_TITLE="Test Plan Title"
TEST_PLAN_SPEC="Test plan specification content"

#------------------------------------------------------------------------------
# Run script in DRY_RUN=1 mode and capture output
# Override STATE_DIR by temporarily patching the environment
#------------------------------------------------------------------------------

# We need to override STATE_DIR inside the script. Since we can't easily do that
# without modifying the script, we create a wrapper that substitutes HOME.
FAKE_HOME="${TEST_TMPDIR}/fakehome"
mkdir -p "${FAKE_HOME}/.warp/state/plan_workflow"
cp "${FAKE_STATE}/recipes.env" "${FAKE_HOME}/.warp/state/plan_workflow/recipes.env"

# oz command mock (must not be called in DRY_RUN=1)
FAKE_BIN="${TEST_TMPDIR}/bin"
mkdir -p "${FAKE_BIN}"
cat > "${FAKE_BIN}/oz" <<'EOF'
#!/usr/bin/env bash
printf 'error: oz was called in DRY_RUN mode (should not happen)\n' >&2
exit 99
EOF
chmod +x "${FAKE_BIN}/oz"

CAPTURED_OUTPUT="$(
  cd "${FAKE_REPO}" && \
  HOME="${FAKE_HOME}" \
  PATH="${FAKE_BIN}:${PATH}" \
  DRY_RUN=1 \
  bash "${PLAN_SCRIPT}" "${TEST_SLOT}" "${TEST_PLAN_TITLE}" "${TEST_PLAN_SPEC}" 2>&1
)" || true

printf 'Captured DRY_RUN output (%d chars)\n\n' "$(printf '%s' "$CAPTURED_OUTPUT" | wc -c)"

#------------------------------------------------------------------------------
# Assertion (a): prompt contains instruction to write plan_id to slot file
#------------------------------------------------------------------------------
printf '(a) Prompt instructs agent to write plan_id to slot path...\n'
if printf '%s' "$CAPTURED_OUTPUT" | grep -q 'plan_id'; then
  assert_pass "(a) prompt contains 'plan_id' reference"
else
  assert_fail "(a) prompt does NOT contain 'plan_id' — agent won't write the slot file"
fi

#------------------------------------------------------------------------------
# Assertion (b): script source does NOT contain tail/awk scraping warp-agent-plans.md
#------------------------------------------------------------------------------
printf '\n(b) Script source does not scrape warp-agent-plans.md for plan_id...\n'
SCRIPT_SOURCE="$(cat "${PLAN_SCRIPT}")"

# Check for tail | awk or awk ... | tail patterns accessing warp-agent-plans.md
SCRAPING_PATTERN=0
if printf '%s' "$SCRIPT_SOURCE" | grep -qE '(tail|awk).*(warp-agent-plans|plans\.md)'; then
  SCRAPING_PATTERN=1
fi
if printf '%s' "$SCRIPT_SOURCE" | grep -qE '(warp-agent-plans|plans\.md).*(tail|awk)'; then
  SCRAPING_PATTERN=1
fi
# Also check for any read of warp-agent-plans.md by the script itself
if printf '%s' "$SCRIPT_SOURCE" | grep -qE 'cat.*warp-agent-plans' ; then
  SCRAPING_PATTERN=1
fi

if [ "$SCRAPING_PATTERN" = "0" ]; then
  assert_pass "(b) script does not scrape warp-agent-plans.md"
else
  assert_fail "(b) script source contains scraping of warp-agent-plans.md — violates negative rule"
fi

#------------------------------------------------------------------------------
# Assertion (c): prompt does NOT instruct agent to write repo_root or plan_title
#------------------------------------------------------------------------------
printf '\n(c) Prompt does not instruct agent to write repo_root or plan_title...\n'
PROMPT_SECTION="$(printf '%s' "$CAPTURED_OUTPUT" | awk '/--- prompt ---/,0')"

DELEGATE_ROOT=0
DELEGATE_TITLE=0
if printf '%s' "$PROMPT_SECTION" | grep -qiE 'write.*repo_root|repo_root.*write'; then
  DELEGATE_ROOT=1
fi
if printf '%s' "$PROMPT_SECTION" | grep -qiE 'write.*plan_title|plan_title.*write'; then
  DELEGATE_TITLE=1
fi

if [ "$DELEGATE_ROOT" = "0" ]; then
  assert_pass "(c) prompt does not instruct agent to write repo_root"
else
  assert_fail "(c) prompt instructs agent to write repo_root — should be written by script directly"
fi

if [ "$DELEGATE_TITLE" = "0" ]; then
  assert_pass "(c) prompt does not instruct agent to write plan_title"
else
  assert_fail "(c) prompt instructs agent to write plan_title — should be written by script directly"
fi

#------------------------------------------------------------------------------
# Assertion (d): script source contains direct-write commands for repo_root and plan_title
#------------------------------------------------------------------------------
printf '\n(d) Script source contains direct printf writes for repo_root and plan_title...\n'

if printf '%s' "$SCRIPT_SOURCE" | grep -qE "printf.*repo_root|> .*repo_root"; then
  assert_pass "(d) script has direct write for repo_root"
else
  assert_fail "(d) script missing direct write for repo_root"
fi

if printf '%s' "$SCRIPT_SOURCE" | grep -qE "printf.*plan_title|> .*plan_title"; then
  assert_pass "(d) script has direct write for plan_title"
else
  assert_fail "(d) script missing direct write for plan_title"
fi

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
printf '\n============================\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'FAIL\n'
  exit 1
fi
printf 'PASS\n'
exit 0
