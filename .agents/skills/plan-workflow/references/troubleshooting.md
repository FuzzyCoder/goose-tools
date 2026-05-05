# Troubleshooting and Health Check Reference

## Table of Contents
- [DRY_RUN Pattern](<#dry_run-pattern>)
- [Health Check](<#health-check>)
- [Troubleshooting Quick Reference](<#troubleshooting-quick-reference>)

---

## DRY_RUN Pattern

Every `goose_pw_*.sh` script supports `DRY_RUN=1`:

```bash
DRY_RUN=1 ~/.goose/workflows/scripts/goose_pw_plan.sh <slot> "<title>" "<spec>"
```

Prints the resolved `--profile`, `--name`, `--cwd`, `--prompt`, and `--input` that WOULD be
used, then exits 0 without touching any slot files or launching any agent. Use for validation.

**Scripting internals:** For patterns behind the launchers (foreground execution, prompt
externalization, artifact gates, `$?` capture under `set -euo pipefail`), see the
`agent-launcher` skill.

---

## Health Check

```bash
bin/goose-tools doctor           # check scripts, YAMLs, skills, profiles, slot state
bin/goose-tools doctor --self-test  # also run negative rule test under bash+zsh
```

Exit 0 = healthy. Exit 1 = issues found with recovery hints.

---

## Troubleshooting Quick Reference

| Symptom | Recovery |
|---------|---------|
| `recipes.env not found` | `bin/goose-tools install globals` |
| `slot conflict` | `bin/goose-tools slot clear <slot>` then re-pin |
| `review_report.md missing` | Re-run Step 02 (`goose_pw_review.sh <slot> reviewer`) |
| `repo_root does not match` | `slot clear`, `cd` to repo, `goose_pw_select.sh` |
| `plan is archived` | Create new plan (Step 01) |
| `plan not found` | Check UUID in `~/goose-agent-plans.md` |

Full details: `docs/troubleshooting.md` in the goose-tools repo.

Last Updated: 2026.05.04 @ 03:17:04
