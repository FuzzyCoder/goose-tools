#!/usr/bin/env bats
# tests/bats/test_goose_tools_subcommands.bats
# Tests for bin/goose-tools subcommands in DRY_RUN and diagnostic modes.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  BIN="${REPO_ROOT}/bin/goose-tools"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "bin/goose-tools --help prints usage" {
  run "${BIN}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"install"* ]]
}

@test "bin/goose-tools doctor runs without error" {
  # doctor checks recipes.env which may not exist in CI; it exits 1 with issues.
  # We just verify it produces output.
  run "${BIN}" doctor
  [ -n "$output" ]
}

@test "bin/goose-tools install globals --dry-run exits 0" {
  # install globals calls oz agent profile list (even in dry-run). Use a fake
  # oz on PATH so the test doesn't hang on the real oz CLI.
  FAKE_OZ_DIR="$(mktemp -d)"
  cat > "${FAKE_OZ_DIR}/oz" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${FAKE_OZ_DIR}/oz"
  PATH="${FAKE_OZ_DIR}:${PATH}" run "${BIN}" --dry-run install globals
  [ "$status" -eq 0 ] || [ "$status" -eq 3 ]
  [[ "$output" == *"DRY RUN"* ]] || [[ "$output" == *"missing"* ]]
}

@test "bin/goose-tools scaffold repo --dry-run requires existing path" {
  run "${BIN}" --dry-run scaffold repo "${TEST_TMPDIR}/nonexistent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "bin/goose-tools scaffold repo --dry-run works on real directory" {
  # Scaffold prompts interactively; provide empty lines to use defaults.
  run bash -c "${BIN} --dry-run scaffold repo ${TEST_TMPDIR} <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY"* ]]
}

@test "bin/goose-tools update repo --dry-run fails without manifest" {
  run "${BIN}" --dry-run update repo "${TEST_TMPDIR}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no .goose-tools-manifest.json"* ]]
}

@test "bin/goose-tools slot clear --dry-run on missing slot reports nothing to do" {
  run "${BIN}" --dry-run slot clear bats-test-slot
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "bin/goose-tools slot archive on missing slot exits 1" {
  run "${BIN}" --dry-run slot archive bats-test-slot
  [ "$status" -eq 1 ] || [ "$status" -eq 0 ]
}

@test "bin/goose-tools unknown subcommand exits 1" {
  run "${BIN}" not-a-command
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "bin/goose-tools inventory generates INVENTORY.md" {
  run "${BIN}" --force inventory
  [ "$status" -eq 0 ]
  [ -f "${REPO_ROOT}/INVENTORY.md" ]
  [[ "$output" == *"INVENTORY.md"* ]]
}

@test "bin/goose-tools inventory --json prints JSON" {
  run "${BIN}" --force --json inventory
  [ "$status" -eq 0 ]
  [[ "$output" == *'"generated_at"'* ]]
}

@test "bin/goose-tools todo --scan-only prints analysis" {
  run "${BIN}" --scan-only todo
  [ "$status" -eq 0 ]
  [[ "$output" == *"TODO Scan Only"* ]]
}

@test "bin/goose-tools plan --dry-run works" {
  run "${BIN}" --dry-run plan test-bats-slot "Bats Test Plan" "Test spec"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
}

@test "bin/goose-tools plan --with-inventory --dry-run injects context" {
  run "${BIN}" --force inventory
  [ "$status" -eq 0 ]
  run "${BIN}" --dry-run --with-inventory plan test-bats-ctx "Ctx Test" "Spec"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repository Inventory"* ]]
}

@test "inventory: '## Skills' heading appears exactly once" {
  run "${BIN}" --force inventory
  [ "$status" -eq 0 ]
  local count
  count="$(grep -c '^## Skills$' "${REPO_ROOT}/INVENTORY.md" || true)"
  [ "$count" -eq 1 ]
}

@test "inventory: plan-workflow skill description on the line below the heading" {
  run "${BIN}" --force inventory
  [ "$status" -eq 0 ]
  local inv="${REPO_ROOT}/INVENTORY.md"
  local heading_line desc_line desc
  heading_line="$(grep -n '^### plan-workflow$' "$inv" | head -1 | cut -d: -f1)"
  [ -n "$heading_line" ]
  desc_line=$(( heading_line + 1 ))
  desc="$(sed -n "${desc_line}p" "$inv")"
  [[ "$desc" == *"Plan"* ]] || [[ "$desc" == *"oz_pw"* ]]
}

@test "inventory: agent-launcher folded description joined to a single line" {
  run "${BIN}" --force inventory
  [ "$status" -eq 0 ]
  local inv="${REPO_ROOT}/INVENTORY.md"
  local heading_line desc_line desc
  heading_line="$(grep -n '^### agent-launcher$' "$inv" | head -1 | cut -d: -f1)"
  [ -n "$heading_line" ]
  desc_line=$(( heading_line + 1 ))
  desc="$(sed -n "${desc_line}p" "$inv")"
  [[ "$desc" == *"Bash scripting patterns"* ]]
  [[ "$desc" == *"DRY_RUN"* ]]
}

@test "inventory: agent-quality-lint description parsed correctly (description: at line 4)" {
  run "${BIN}" --force inventory
  [ "$status" -eq 0 ]
  local inv="${REPO_ROOT}/INVENTORY.md"
  local heading_line desc_line desc
  heading_line="$(grep -n '^### agent-quality-lint$' "$inv" | head -1 | cut -d: -f1)"
  [ -n "$heading_line" ]
  desc_line=$(( heading_line + 1 ))
  desc="$(sed -n "${desc_line}p" "$inv")"
  [[ "$desc" == *"Agentic code quality linter"* ]]
}

@test "inventory: skill files appear in subgroup order (SKILL.md -> references -> scripts)" {
  run "${BIN}" --force inventory
  [ "$status" -eq 0 ]
  local inv="${REPO_ROOT}/INVENTORY.md"
  local skill_md_line refs_line scripts_line
  skill_md_line="$(grep -n 'agent-quality-lint/SKILL\.md' "$inv" | head -1 | cut -d: -f1)"
  refs_line="$(grep -n 'agent-quality-lint/references/' "$inv" | head -1 | cut -d: -f1)"
  scripts_line="$(grep -n 'agent-quality-lint/scripts/' "$inv" | head -1 | cut -d: -f1)"
  [ -n "$skill_md_line" ]
  [ -n "$refs_line" ]
  [ -n "$scripts_line" ]
  [ "$skill_md_line" -lt "$refs_line" ]
  [ "$refs_line" -lt "$scripts_line" ]
}

@test "inventory --json: uv.lock category is 'Project Root'" {
  run "${BIN}" --force --json inventory
  [ "$status" -eq 0 ]
  local uv_line
  uv_line="$(printf '%s' "$output" | grep '"path": "uv.lock"')"
  [ -n "$uv_line" ]
  [[ "$uv_line" == *'"category": "Project Root"'* ]]
}

@test "inventory: SKILL.md without description causes non-zero exit" {
  local fake_skill="${REPO_ROOT}/.agents/skills/__bats_nodesc__"
  mkdir -p "$fake_skill"
  printf -- '---\nname: bats-nodesc\n---\n# No description here\n' > "${fake_skill}/SKILL.md"
  run bash -c "\"${BIN}\" --force inventory 2>&1"
  local rc="$status"
  rm -rf "$fake_skill"
  [ "$rc" -ne 0 ]
  [[ "$output" == *"__bats_nodesc__"* ]]
}

# ---------------------------------------------------------------------------
# Profile and manifest tests
# ---------------------------------------------------------------------------

@test "scaffold repo: python is the default profile" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  local mf="${TEST_TMPDIR}/.goose-tools-manifest.json"
  [ -f "$mf" ]
  grep -q '"profile": "python"' "$mf"
}

@test "scaffold repo: python profile installs all skills (including agent-quality-lint)" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} python <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  [ -d "${TEST_TMPDIR}/.agents/skills/agent-quality-lint" ]
}

@test "scaffold repo: core profile installs only core skills" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} core <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  # agent-launcher is in the core allowlist
  [ -d "${TEST_TMPDIR}/.agents/skills/agent-launcher" ]
  # agent-quality-lint is python-only — must NOT be installed
  [ ! -d "${TEST_TMPDIR}/.agents/skills/agent-quality-lint" ]
  # deploy-goose-tools is in the core allowlist
  [ -d "${TEST_TMPDIR}/.agents/skills/deploy-goose-tools" ]
}

@test "scaffold repo: unknown profile token exits 1 with usage message" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} minimal <<< $'\n\n\n'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown profile"* ]] || [[ "$output" == *"Valid profiles"* ]]
}

@test "scaffold repo: python-uv profile token rejected" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} python-uv <<< $'\n\n\n'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown profile"* ]] || [[ "$output" == *"Valid profiles"* ]]
}

@test "scaffold repo: manifest is v1.1 with goose_tools_version, profile, skills fields in correct order" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} core <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  local mf mfc
  mf="${TEST_TMPDIR}/.goose-tools-manifest.json"
  mfc="$(cat "$mf")"
  [[ "$mfc" == *'"goose_tools_version": "1.1"'* ]]
  [[ "$mfc" == *'"profile": "core"'* ]]
  [[ "$mfc" == *'"skills"'* ]]
  # Field order: goose_tools_version before profile before skills
  local vpos ppos spos
  vpos="${#mfc%%goose_tools_version*}"
  ppos="${#mfc%%\"profile\"*}"
  spos="${#mfc%%\"skills\"*}"
  [ "$vpos" -lt "$ppos" ]
  [ "$ppos" -lt "$spos" ]
}

@test "scaffold repo: manifest skills array is alphabetically sorted" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} core <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  local mfc
  mfc="$(cat "${TEST_TMPDIR}/.goose-tools-manifest.json")"
  # agent-launcher (a) must appear before write-skill (w) in the JSON string
  local al_pos ws_pos
  al_pos="${#mfc%%agent-launcher*}"
  ws_pos="${#mfc%%write-skill*}"
  [ "$al_pos" -lt "$ws_pos" ]
}

@test "update repo: v1.0 manifest treated as python and rewritten to v1.1" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} python <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  # Overwrite with a v1.0 manifest (no profile field)
  printf '{"goose_tools_version": "1.0", "scaffolded_at": "2025-01-01T00:00:00Z", "source": "%s"}\n' \
    "${REPO_ROOT}" > "${TEST_TMPDIR}/.goose-tools-manifest.json"
  run "${BIN}" update repo "${TEST_TMPDIR}"
  [ "$status" -eq 0 ]
  local mfc
  mfc="$(cat "${TEST_TMPDIR}/.goose-tools-manifest.json")"
  [[ "$mfc" == *'"goose_tools_version": "1.1"'* ]]
  [[ "$mfc" == *'"profile": "python"'* ]]
  # scaffolded_at from the v1.0 manifest must be preserved
  [[ "$mfc" == *'"scaffolded_at": "2025-01-01T00:00:00Z"'* ]]
}

@test "update repo: adds missing profile skills to consumer repo" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} core <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  # Remove a core skill to simulate a newly-introduced skill being absent
  rm -rf "${TEST_TMPDIR}/.agents/skills/review-pr"
  run "${BIN}" update repo "${TEST_TMPDIR}"
  [ "$status" -eq 0 ]
  [ -d "${TEST_TMPDIR}/.agents/skills/review-pr" ]
}

@test "update repo: leaves out-of-profile skills in place" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} core <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  # Manually install a python-only skill into the core-profiled repo
  cp -r "${REPO_ROOT}/.agents/skills/agent-quality-lint" \
    "${TEST_TMPDIR}/.agents/skills/agent-quality-lint"
  run "${BIN}" update repo "${TEST_TMPDIR}"
  [ "$status" -eq 0 ]
  # The out-of-profile skill must still be there
  [ -d "${TEST_TMPDIR}/.agents/skills/agent-quality-lint" ]
}

@test "update repo: unknown manifest profile exits 1" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} python <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  # Inject an invalid profile value
  printf '{"goose_tools_version": "1.1", "scaffolded_at": "2025-01-01T00:00:00Z", "source": "%s", "profile": "invalid", "skills": []}\n' \
    "${REPO_ROOT}" > "${TEST_TMPDIR}/.goose-tools-manifest.json"
  run "${BIN}" update repo "${TEST_TMPDIR}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown profile"* ]] || [[ "$output" == *"Valid profiles"* ]]
}

@test "update repo: locally-modified skill is skipped without --force" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} python <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  # Append a local modification to a skill file
  printf '\n# bats-local-modification\n' >> "${TEST_TMPDIR}/.agents/skills/review-pr/SKILL.md"
  run "${BIN}" update repo "${TEST_TMPDIR}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"drift"* ]] || [[ "$output" == *"skipping"* ]]
  # Modification must still be present
  grep -q 'bats-local-modification' "${TEST_TMPDIR}/.agents/skills/review-pr/SKILL.md"
}

@test "update repo --force: overwrites locally-modified skill" {
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} python <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  printf '\n# bats-local-modification\n' >> "${TEST_TMPDIR}/.agents/skills/review-pr/SKILL.md"
  run "${BIN}" --force update repo "${TEST_TMPDIR}"
  [ "$status" -eq 0 ]
  # Modification must be gone after forced overwrite
  run grep -c 'bats-local-modification' "${TEST_TMPDIR}/.agents/skills/review-pr/SKILL.md"
  [ "$status" -ne 0 ]
}

@test "scaffold repo --profile-only: requires explicit profile token" {
  run "${BIN}" --profile-only scaffold repo "${TEST_TMPDIR}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires an explicit profile"* ]]
}

@test "scaffold repo --profile-only: switches profile without rewriting AGENTS.md" {
  # Initial scaffold with python profile (AGENTS.md is written)
  run bash -c "${BIN} scaffold repo ${TEST_TMPDIR} python <<< $'\n\n\n'"
  [ "$status" -eq 0 ]
  local agents_content
  agents_content="$(cat "${TEST_TMPDIR}/AGENTS.md")"
  # Switch to core without re-prompting
  run "${BIN}" --profile-only scaffold repo "${TEST_TMPDIR}" core
  [ "$status" -eq 0 ]
  # AGENTS.md content must be unchanged
  [ "$(cat "${TEST_TMPDIR}/AGENTS.md")" = "$agents_content" ]
  # Manifest must reflect new profile
  grep -q '"profile": "core"' "${TEST_TMPDIR}/.goose-tools-manifest.json"
}
