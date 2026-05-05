# bin/goose-tools — Operations Reference

Full reference for every `bin/goose-tools` subcommand.

## Prerequisites

### Shell Test Dependencies

The shell test suite requires **bats** and **shellcheck**.

Install them via the provided script:
```bash
./scripts/install_shell_dev.sh
```

Or manually:
- **macOS**: `brew install bats-core shellcheck`
- **Debian/Ubuntu**: `sudo apt-get install -y bats shellcheck`

Verify:
```bash
bats --version
shellcheck --version
```

## Global Flags

All subcommands support these flags (specified before the subcommand name):

- `--dry-run` — Print intended actions and exit 0. No files are written, no agents launched, no directories moved.
- `--force` — Overwrite locally-modified managed files without prompting. Drift is detected via per-file SHA-256 over the entire skill directory tree (not just `SKILL.md`). Applies to `install globals`, `scaffold repo`, `update repo`, and `--profile-only scaffold repo`.
- `--json` — Emit structured JSON output in addition to human-readable output (where supported).
- `--profile-only` — (`scaffold repo` only) Switch a consumer repo's scaffold profile without re-prompting for placeholder values or rewriting `AGENTS.md`. Requires an explicit profile token.

Exit codes: `0` success; `1` partial failure; `2` conflict without `--force`; `3` missing prerequisite.

---

## install globals

Install all runtime assets from the `goose-tools` repo to global locations.

**Usage:**
```bash
bin/goose-tools install globals
bin/goose-tools --dry-run install globals
bin/goose-tools --force install globals
```

**Inputs:** The `goose-tools` repo itself (resolved via `git rev-parse --show-toplevel` from `bin/`).

**Outputs:**
- `~/.goose/workflows/scripts/goose_pw_*.sh` — 6 runtime scripts (chmod +x)
- `~/.goose/workflows/goose_pw_*.yaml` — 6 Command Palette workflow manifests
- `~/.agents/skills/<skill>/` — all portable skills from `.agents/skills/`, including
  `review-pr`, `review-and-fix-pr`, `fix-issue`, and `update-deps`
- `~/.goose/state/plan_workflow/recipes.env` — resolved agent profile IDs
- `~/.warp/state/goose-tools-manifest.json` — ownership manifest with SHA-256 hashes

**Profile resolution:** Queries `goose recipe list` at install time for profiles named
`Planner`, `Reviewer`, `Approver`, and `Coder`. Fails loudly if any are missing (exit 3).

**Conflict behavior:** If a managed file has been locally modified (current hash ≠ recorded hash),
fails with the path list. Use `--force` to overwrite.

**Dry-run behavior:** Resolves and prints profile IDs, prints intended file copy operations,
then exits 0 without writing anything.

---

## scaffold repo

Scaffold `AGENTS.md` files and portable skills into a consumer repository.

**Usage:**
```bash
bin/goose-tools scaffold repo /path/to/repo
bin/goose-tools scaffold repo /path/to/repo core
bin/goose-tools --force scaffold repo /path/to/repo
bin/goose-tools --profile-only scaffold repo /path/to/repo core
```

**Inputs:**
- `<path>` — absolute or relative path to the target repository
- `[profile]` — skill set to install: `python` (default) or `core`
  - `python` — every skill; use for Python/uv-based projects
  - `core` — shell and workflow skills only; no `uv`, `ruff`, `ty`, or `pytest` required
  - Any other value exits non-zero with a usage message naming the two valid profiles

**Interactive placeholders:** Prompts for:
- `PROJECT_NAME` — e.g. `MyApp`
- `PACKAGE_NAME` — e.g. `myapp`
- `DOMAIN_DESCRIPTION` — e.g. `Data warehouse for analysis`

Press Enter to keep `{{PLACEHOLDER}}` for manual editing later.
**`--profile-only` skips these prompts entirely** and does not rewrite `AGENTS.md`.

**`--profile-only` flag:**
- Requires an explicit profile token (does not default to `python`)
- Adds any new-profile skills not yet present in the consumer repo
- Leaves skills outside the new profile in place (non-destructive)
- Preserves the original `scaffolded_at` value from the existing manifest
- Rewrites `.goose-tools-manifest.json` with the new `profile` value and refreshed `skills` array

**Outputs:**
- `<path>/AGENTS.md` — root AGENTS.md with placeholders substituted (skipped with `--profile-only`)
- `<path>/tests/AGENTS.md` — if `tests/` directory exists (skipped with `--profile-only`)
- `<path>/utils/AGENTS.md` — if `utils/` directory exists (skipped with `--profile-only`)
- `<path>/.agents/skills/<skill>/` — skills matching the selected profile
- `<path>/.goose-tools-manifest.json` — v1.1 manifest: `goose_tools_version`, `scaffolded_at`,
  `source`, `profile`, `skills` (alphabetically sorted array of installed skill names)

**Non-destructive by default:** Will not overwrite existing files. Use `--force` to overwrite.

**Dry-run behavior:** Prints all intended writes; makes no changes.

---

## update repo

Refresh goose-tools-managed files in a consumer repository that was previously scaffolded.

**Usage:**
```bash
bin/goose-tools update repo /path/to/repo
bin/goose-tools --dry-run update repo /path/to/repo
bin/goose-tools --force update repo /path/to/repo
```

**Inputs:** `<path>` must contain `.goose-tools-manifest.json` (written by `scaffold repo`).

**Outputs:**
- Refreshes already-installed skills (per-file SHA-256 drift check; locally-modified skills
  are skipped unless `--force`)
- Adds any canonical skill that belongs to the recorded profile but is not yet present
- Leaves skills outside the recorded profile in place (non-destructive)
- Rewrites `.goose-tools-manifest.json` to v1.1 with the refreshed `skills` array

**Manifest parsing:**
- `goose_tools_version: "1.0"` (or missing `profile` field) — treated as `python` profile;
  manifest is rewritten to v1.1. Note: this resurrects every `python`-profile skill that was
  previously deleted. Run `--profile-only scaffold repo <path> core` before the first
  `update repo` if you want `core` semantics.
- Unknown `profile` value — exits non-zero with an error naming the manifest path and the two
  valid profile values. Does not silently default.

**Conflict handling:** Drift detected via per-file SHA-256 over the entire skill directory;
locally-modified skills are skipped without `--force`.

---

## doctor

Check the health of the global goose-tools installation and slot state.

**Usage:**
```bash
bin/goose-tools doctor
bin/goose-tools doctor --self-test
bin/goose-tools --json doctor
```

**Checks performed:**
1. `recipes.env` — present, all 4 IDs set
2. Global scripts — each `goose_pw_*.sh` present and SHA matches canonical source
3. Global YAML manifests — each `goose_pw_*.yaml` present
4. Skills — each `.agents/skills/<skill>/SKILL.md` SHA matches canonical
5. Slot state — each slot under `~/.goose/state/plan_workflow/`:
   - Scenario A: `repo_root` + `plan_title` present, `plan_id` missing → Planner failed mid-run
   - Scenario B: Stale handoff — `decisions.txt` present but `review_report.md` missing
   - `repo_root` path no longer exists on disk
6. Self-test (with `--self-test`): runs `tests/test_goose_pw_plan_negative_rule.sh` under both `bash` and `zsh`

**Exit codes:** `0` if clean; `1` if any issues found.

**JSON output (`--json`):**
```json
{"status": "ok", "issues": []}
{"status": "issues", "issue_count": 2}
```

---

## slot clear

Remove a slot directory after interactive confirmation.

**Usage:**
```bash
bin/goose-tools slot clear <slot>
bin/goose-tools --dry-run slot clear <slot>
```

**Behavior:**
- Lists files inside the slot directory
- Prompts `Confirm? [y/N]`
- On confirmation: `rm -rf ~/.goose/state/plan_workflow/<slot>/`
- Dry-run: prints what would be removed; exits 0 without removing

**Recovery scenarios where slot clear is needed:**
- Scenario A: `repo_root` and `plan_title` written but Planner failed before writing `plan_id`
- Slot conflict: slot is pinned to wrong repo or plan

---

## slot archive

Archive a slot directory to `~/.goose/state/plan_workflow/archive/<YYYY-MM-DD>-<slot>/`.

**Usage:**
```bash
bin/goose-tools slot archive <slot>
bin/goose-tools --dry-run slot archive <slot>
```

**Behavior:**
- Moves `~/.goose/state/plan_workflow/<slot>/` to `~/.goose/state/plan_workflow/archive/<date>-<slot>/`
- Preserves all slot files with their original mtime (for auditing)
- Creates the `archive/` parent directory if needed
- Dry-run: prints intended move; exits 0 without moving

**After archiving:** Also move the plan's registry row from Active to Archived in
`~/goose-agent-plans.md` (use the `manage-plans` skill or edit manually).

Last Updated: 2026.05.04 @ 18:34:27
