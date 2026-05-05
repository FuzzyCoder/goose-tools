# Bats Testing Reference

## Table of Contents
- [Install Bats](#install-bats)
- [Test Patterns](#test-patterns)
- [Test Command Modules in Isolation](#test-command-modules-in-isolation)
- [Mocks for External Tools](#mocks-for-external-tools)

---

## Install Bats

```bash
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get install bats

# Or vendored submodule
git submodule add https://github.com/bats-core/bats-core.git tests/bats/vendor/bats-core
```

## Test Patterns

Test one behavior per `@test`:

```bats
#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  BIN="${REPO_ROOT}/bin/mytool"
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "doctor runs without error" {
  run "${BIN}" doctor
  [ -n "$output" ]
}

@test "install --dry-run exits 0" {
  run "${BIN}" --dry-run install globals
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY"* ]]
}

@test "unknown subcommand exits 1" {
  run "${BIN}" not-a-command
  [ "$status" -eq 1 ]
}
```

## Test Command Modules in Isolation

Source the module directly in a bats test and call the function:

```bats
@test "cmd_doctor detects missing profiles.env" {
  source "${REPO_ROOT}/commands/doctor.sh"
  # Set up environment
  run cmd_doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"profiles.env missing"* ]]
}
```

## Mocks for External Tools

```bats
@test "install globals --dry-run with fake oz" {
  FAKE_OZ_DIR="$(mktemp -d)"
  cat > "${FAKE_OZ_DIR}/oz" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${FAKE_OZ_DIR}/oz"
  PATH="${FAKE_OZ_DIR}:${PATH}" run "${BIN}" --dry-run install globals
  [ "$status" -eq 0 ] || [ "$status" -eq 3 ]
}
```

Last Updated: 2026.05.04 @ 03:17:04
