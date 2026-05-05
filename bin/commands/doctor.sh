#!/usr/bin/env bash
# Doctor subcommand for goose-tools.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

cmd_doctor() {
  local self_test=0
  [ "${1:-}" = "--self-test" ] && self_test=1

  local issues=""
  local issue_count=0

  flag_issue() {
    issue_count=$((issue_count + 1))
    issues="${issues}  [${issue_count}] $1\n"
    printf '  ISSUE [%d]: %s\n' "$issue_count" "$1"
  }

  printf '%s\n\n' '== goose-tools doctor =='

  printf '%s\n' '-- Profiles --'
  if [ ! -f "${RECIPES_ENV}" ]; then
    flag_issue "recipes.env missing at ${RECIPES_ENV} — run: bin/goose-tools install globals"
  else
    # shellcheck source=/dev/null
    . "${RECIPES_ENV}"
    for var in PLANNER_RECIPE REVIEWER_RECIPE APPROVER_RECIPE CODER_RECIPE; do
      eval "val=\${${var}:-}"
      if [ -z "$val" ]; then
        flag_issue "${var} not set in recipes.env"
      else
        printf '  %s = %s\n' "$var" "$val"
      fi
    done
  fi

  printf '\n%s\n' '-- Global Scripts --'
  for script in goose_pw_plan goose_pw_select goose_pw_review goose_pw_edit goose_pw_finalize goose_pw_execute; do
    local dst="${GLOBAL_SCRIPTS_DIR}/${script}.sh"
    if [ ! -f "$dst" ]; then
      flag_issue "Missing global script: ${dst}"
    else
      local src="${GOOSE_TOOLS_ROOT}/goose/workflows/scripts/${script}.sh"
      if [ -f "$src" ]; then
        local src_sha dst_sha
        src_sha="$(sha256_file "$src")"
        dst_sha="$(sha256_file "$dst")"
        if [ "$src_sha" != "$dst_sha" ]; then
          flag_issue "Drift: ${dst} differs from canonical source"
        else
          printf '  OK: %s.sh\n' "$script"
        fi
      fi
    fi
  done

  printf '\n%s\n' '-- Global Workflow YAMLs --'
  for yaml in goose_pw_plan goose_pw_select goose_pw_review goose_pw_edit goose_pw_finalize goose_pw_execute; do
    local dst="${GLOBAL_WORKFLOWS_DIR}/${yaml}.yaml"
    if [ ! -f "$dst" ]; then
      flag_issue "Missing YAML workflow: ${dst}"
    else
      printf '  OK: %s.yaml\n' "$yaml"
    fi
  done

  printf '\n%s\n' '-- Installed Skills --'
  for skill_dir in "${GOOSE_TOOLS_ROOT}/.agents/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    local skill_name
    skill_name="$(basename "$skill_dir")"
    local dst_skill="${GLOBAL_SKILLS_DIR}/${skill_name}/SKILL.md"
    local src_skill="${skill_dir}SKILL.md"
    if [ ! -f "$dst_skill" ]; then
      flag_issue "Missing global skill: ${skill_name}"
    elif [ -f "$src_skill" ]; then
      local src_sha dst_sha
      src_sha="$(sha256_file "$src_skill")"
      dst_sha="$(sha256_file "$dst_skill")"
      if [ "$src_sha" != "$dst_sha" ]; then
        flag_issue "Drift: ~/.agents/skills/${skill_name}/SKILL.md differs from canonical"
      else
        printf '  OK: %s\n' "$skill_name"
      fi
    fi
  done

  printf '\n%s\n' '-- Slot State --'
  if [ -d "${STATE_DIR}" ]; then
    local found_slots=0
    for slot_dir in "${STATE_DIR}"/*/; do
      [ -d "$slot_dir" ] || continue
      local slot_name
      slot_name="$(basename "$slot_dir")"
      [ "$slot_name" = "archive" ] && continue
      found_slots=$((found_slots + 1))
      local has_repo_root=0 has_plan_title=0 has_plan_id=0
      [ -f "${slot_dir}/repo_root" ]  && has_repo_root=1
      [ -f "${slot_dir}/plan_title" ] && has_plan_title=1
      [ -f "${slot_dir}/plan_id" ]    && has_plan_id=1
      if [ "$has_repo_root" = "1" ] && [ "$has_plan_title" = "1" ] && [ "$has_plan_id" = "0" ]; then
        flag_issue "Slot '${slot_name}': Scenario A — plan_id missing. Recovery: bin/goose-tools slot clear ${slot_name}"
      elif [ "$has_plan_id" = "0" ]; then
        flag_issue "Slot '${slot_name}': incomplete (no plan_id). Recovery: bin/goose-tools slot clear ${slot_name}"
      else
        local pinned_repo
        pinned_repo="$(cat "${slot_dir}/repo_root" 2>/dev/null || printf '')"
        if [ -n "$pinned_repo" ] && [ ! -d "$pinned_repo" ]; then
          flag_issue "Slot '${slot_name}': repo_root no longer exists: ${pinned_repo}"
        fi
        if [ -f "${slot_dir}/decisions.txt" ] && [ ! -f "${slot_dir}/review_report.md" ]; then
          flag_issue "Slot '${slot_name}': stale handoff — decisions.txt present but review_report.md missing"
        fi
        printf '  OK: slot %s\n' "$slot_name"
      fi
    done
    [ "$found_slots" = "0" ] && printf '  (no active slots)\n'
  else
    printf '  (state dir not yet created)\n'
  fi

  if [ "$self_test" = "1" ]; then
    printf '\n%s\n' '-- Self-Test (Negative Rule) --'
    local test_script="${GOOSE_TOOLS_ROOT}/tests/test_goose_pw_plan_negative_rule.sh"
    if [ ! -f "$test_script" ]; then
      flag_issue "Self-test script not found: ${test_script}"
    else
      if bash "$test_script" && zsh "$test_script"; then
        printf '  OK: negative rule test passed under bash and zsh\n'
      else
        flag_issue "Negative rule test FAILED — see output above"
      fi
    fi
  fi

  printf '\n%s\n' '== Summary =='
  if [ "$issue_count" = "0" ]; then
    printf 'All checks passed. goose-tools is healthy.\n'
    [ "${OUTPUT_JSON}" = "1" ] && printf '{"status": "ok", "issues": []}\n'
    return 0
  else
    printf '%d issue(s) found:\n' "$issue_count"
    printf '%b' "$issues"
    [ "${OUTPUT_JSON}" = "1" ] && printf '{"status": "issues", "issue_count": %d}\n' "$issue_count"
    return 1
  fi
}
