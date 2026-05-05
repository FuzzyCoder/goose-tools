---
name: deploy-goose-tools
description: Adopt or maintain the goose-tools toolchain in a consumer repository. Use when scaffolding goose-tools into a new project, updating an existing consumer repo, installing globals on a new machine, switching scaffold profiles, or checking installation health. Triggers: "scaffold goose-tools into my repo", "install goose-tools", "deploy goose-tools", "update goose-tools", "switch scaffold profile", "run doctor", "install globals", "profile-only".
---

# Deploy goose-tools

Manage the goose-tools toolchain lifecycle in consumer repos: install global prerequisites,
scaffold a repo for the first time, keep it current, or switch between the `python` and `core`
scaffold profiles.

## When to Use

- Scaffolding goose-tools (`AGENTS.md`, skills) into a new consumer repo for the first time
- Updating a previously-scaffolded repo (refresh skills, add newly-introduced ones)
- Installing or refreshing global prerequisites (`goose_pw_*.sh`, `recipes.env`) on a new machine
- Switching a consumer repo from `python` to `core` profile (or vice versa)
- Running the doctor check after a machine change, account change, or suspected drift
- NOT for creating or managing goose-tools plans (use `manage-plans`)
- NOT for running quality checks (use `run-quality-checks` or `agent-quality-lint`)

## Find Your GOOSE_TOOLS_ROOT

Every command below uses `{{GOOSE_TOOLS_ROOT}}` — the absolute path to your local goose-tools
checkout. Run this to find it:

```bash
git -C /path/to/goose-tools rev-parse --show-toplevel
```

Replace `{{GOOSE_TOOLS_ROOT}}` with that output before running any command.
Replace `{{TARGET_REPO}}` with the absolute or relative path to the consumer repo.

**These are runtime placeholders — not scaffold-time substitutions.**
`bin/commands/scaffold.sh` only substitutes `{{PROJECT_NAME}}`, `{{PACKAGE_NAME}}`,
`{{DOMAIN_DESCRIPTION}}`, and `{{REPO_ROOT}}`. Fill in `{{GOOSE_TOOLS_ROOT}}` and
`{{TARGET_REPO}}` by hand when copying commands.

## Playbook

### Entry Point 1 — Install Globals

Run once per machine (or after a Warp account change / profile rename). Confirms `oz` is on
`PATH` and the four required profiles (`Planner`, `Reviewer`, `Approver`, `Coder`) exist.

```bash
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools install globals
```

Installs `goose_pw_*.sh` scripts, YAML manifests, and **all skills** (every profile — `install
globals` is always profile-agnostic) to global locations. Writes `recipes.env`.

Add `--dry-run` to preview; `--force` to overwrite locally-modified managed files.

### Entry Point 2 — Scaffold Repo

Run once per consumer repo. Prompts for `PROJECT_NAME`, `PACKAGE_NAME`, and
`DOMAIN_DESCRIPTION` interactively (press Enter to keep `{{PLACEHOLDER}}` for later).

**Two profiles:**
- `python` (default) — every skill; use for Python/uv-based projects
- `core` — shell and workflow skills only; no `uv`, `ruff`, `ty`, or `pytest` required

```bash
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools scaffold repo {{TARGET_REPO}}
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools scaffold repo {{TARGET_REPO}} core
```

Writes `AGENTS.md` (and `tests/AGENTS.md`, `utils/AGENTS.md` if those directories exist),
copies the profile's skills to `{{TARGET_REPO}}/.agents/skills/`, and writes
`.goose-tools-manifest.json` (v1.1: includes `profile` and `skills` fields).

Non-destructive by default — existing files are skipped. Add `--force` to overwrite.

### Entry Point 3 — Update Repo

Run after pulling new goose-tools commits. Refreshes installed skills and adds any newly-
introduced skills that belong to the recorded profile.

**Requires:** `.goose-tools-manifest.json` in `{{TARGET_REPO}}` (written by `scaffold repo`).

```bash
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools update repo {{TARGET_REPO}}
```

Behavior:
- Refreshes already-installed skills (per-file SHA-256 drift check; skips locally-modified
  skills unless `--force`)
- Adds any new canonical skill that belongs to the recorded profile but is not yet present
- Leaves skills outside the recorded profile in place (non-destructive)
- Rewrites `.goose-tools-manifest.json` to v1.1 with the refreshed `skills` array

### Entry Point 4 — Doctor

Check the health of the global installation and slot state.

```bash
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools doctor
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools doctor --self-test   # optional negative-rule validation
```

### Profile Switching

To switch a consumer repo's profile without re-prompting for placeholder values:

```bash
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools --profile-only scaffold repo {{TARGET_REPO}} <new-profile>
```

This is the safe, supported path: adds skills the new profile requires, rewrites the manifest's
`profile` field, and does **not** re-prompt for placeholders or rewrite `AGENTS.md`.

## Anti-Patterns

- DO NOT pass unknown profile tokens (`minimal`, `python-uv`, `full`) — only `python` and
  `core` are valid; any other token exits non-zero with a usage message
- DO NOT switch profiles by re-running `scaffold repo` without `--profile-only` — it re-prompts
  and can clobber a previously substituted `AGENTS.md`
- DO NOT run `update repo` on a repo without `.goose-tools-manifest.json` — scaffold first
- DO NOT hardcode `{{GOOSE_TOOLS_ROOT}}` in team docs; link to `git rev-parse --show-toplevel`

## Validation

After scaffolding:
```bash
ls {{TARGET_REPO}}/.agents/skills/           # profile's skills present
cat {{TARGET_REPO}}/.goose-tools-manifest.json  # v1.1 with profile + skills fields
```

After updating:
```bash
{{GOOSE_TOOLS_ROOT}}/bin/goose-tools doctor    # should report no issues
```

## Gotchas

- **`install globals` is profile-agnostic** — always installs every skill regardless of the
  profile used for `scaffold repo` or `update repo`.
- **`update repo` does not change the `profile` field** — use `--profile-only scaffold repo`
  to switch profiles.
- **v1.0 manifest migration** — repos scaffolded before v1.1 have no `profile` field. `update
  repo` treats them as `python` and rewrites the manifest to v1.1. Run `--profile-only scaffold
  repo {{TARGET_REPO}} core` first if you want `core` semantics.
- **Locally-modified skills are skipped by `update repo`** unless `--force` is set (per-file
  SHA-256 drift detection across the entire skill directory, not just `SKILL.md`).

Last Updated: 2026.05.04 @ 18:34:27
