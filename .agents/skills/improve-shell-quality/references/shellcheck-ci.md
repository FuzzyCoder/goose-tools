# Shellcheck and CI Reference

## Table of Contents
- [Configure Shellcheck](#configure-shellcheck)
- [Run Shellcheck Locally](#run-shellcheck-locally)
- [CI Gate](#ci-gate)
- [Pre-commit Hooks](#pre-commit-hooks)
- [Install Hooks](#install-hooks)

---

## Configure Shellcheck

### Create `.shellcheckrc`

```
# Shellcheck configuration
external-sources=true
shell=bash
severity=warning

# SC1090/SC1091: dynamic sourcing via WARP_TOOLS_ROOT
disable=SC1090
disable=SC1091

# SC2015: intentional A && B || C fallback patterns
disable=SC2015

# SC2034: variables defined in shared helpers consumed by sourced scripts
disable=SC2034
```

## Run Shellcheck Locally

```bash
# All shell scripts
shellcheck -x $(find . -name '*.sh' -not -path './.git/*' -not -path './.venv/*')

# Specific file
shellcheck -x bin/mytool commands/*.sh utils/shell/*.sh
```

## CI Gate

In `.github/workflows/ci.yml`:

```yaml
jobs:
  shell-quality:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Install shellcheck
        run: |
          if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y shellcheck
          elif command -v brew >/dev/null 2>&1; then
            brew install shellcheck
          fi
      - name: Shellcheck all scripts
        run: |
          for f in bin/mytool utils/shell/*.sh commands/*.sh; do
            shellcheck -x "$f"
          done
      - name: Run bats tests
        run: bats tests/bats/
```

## Pre-commit Hooks

### `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck
        args: ["-x"]
        files: \.(sh|bash)$

  - repo: local
    hooks:
      - id: bats-tests
        name: Run bats tests
        entry: bash -c "bats tests/bats/"
        language: system
        files: \.(sh|bash)$
        pass_filenames: false
```

## Install Hooks

```bash
pre-commit install
pre-commit run --all-files
```

Last Updated: 2026.05.04 @ 03:17:04
