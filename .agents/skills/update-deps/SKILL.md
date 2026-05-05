---
name: update-deps
description: Update Python dependencies for uv-managed projects. Runs uv lock --upgrade, uv sync, pip-audit vulnerability scan, run-quality-checks (inline), and the full test suite. Commits and pushes only when invoked via "update dependencies", "update-deps", or "upgrade lockfile". Applies only to repos with both pyproject.toml and uv.lock at the repo root.
---

# update-deps

uv-only Python dependency update workflow. Upgrades the lockfile, installs new versions,
scans for known vulnerabilities, validates code quality, and runs all tests before
committing. Commits and pushes are gated on explicit trigger phrases.

## When to Use

- User says "update dependencies", "update-deps", or "upgrade lockfile"
- Periodic maintenance runs to pull in patch releases and security fixes
- After a security advisory to upgrade a specific package

**This skill applies only to uv-managed repositories** — those with both `pyproject.toml`
and `uv.lock` at the repository root. In any other repository, report:

> "This repository does not appear to be a uv project (missing pyproject.toml or uv.lock
> at the repo root). update-deps applies only to uv-managed projects. Stopping."

Then stop without changing any files.

---

## Autonomy Gates

Commit and push are **only authorized** when the user invokes this skill via one of its
explicit trigger phrases.

All commits must include `Co-Authored-By: Oz <oz-agent@warp.dev>` in a new line at the
end of the commit message.

---

## Step 1 — Verify uv Project

```bash
# Check that both required files exist at the repo root
ls pyproject.toml uv.lock
```

If either file is missing, report the unsupported-repo error (above) and stop.

---

## Step 2 — Upgrade the Lockfile

```bash
uv lock --upgrade
```

This upgrades all dependencies to the latest versions allowed by the version constraints
in `pyproject.toml`. The `uv.lock` file is updated in place.

---

## Step 3 — Install Upgraded Versions

```bash
uv sync
```

This installs the upgraded packages into the `.venv` managed by uv. Required before
running type checks, which read stubs from the installed packages.

---

## Step 4 — Run pip-audit Vulnerability Scan

Detect pip-audit using this priority order:

**Detection (in order):**

1. Check if pip-audit is available as a uv tool:
   ```bash
   uv tool list 2>/dev/null | grep -q "pip-audit"
   ```
   If matched → use `uv tool run pip-audit`.

2. Otherwise, check if pip-audit is in project dev dependencies:
   ```bash
   uv pip list 2>/dev/null | awk '{print $1}' | grep -qi "pip-audit"
   ```
   If matched → use `uv run pip-audit`.

3. If neither is available, halt with:
   > "pip-audit not available. Install with: `uv tool install pip-audit`
   > Stopping — vulnerability scan is required before committing upgraded dependencies."
   Do not commit or push.

**Run pip-audit:**
```bash
# uv tool variant (preferred):
uv tool run pip-audit

# uv run variant (fallback):
uv run pip-audit
```

**Severity threshold:** pip-audit's default — any advisory at any severity level fails.
Do not pass `--vulnerability-service` or any database override; use the default OSV / PyPI
advisory source.

If pip-audit reports any advisories:
1. Identify which upgraded package introduced the advisory.
2. Check if a patched version is available (pip-audit output includes this).
3. If a patched version exists, update the version constraint in `pyproject.toml` to
   require the patched version, then re-run Steps 2–4.
4. If no patched version is available, halt and report the advisory details to the user.
   Do not commit with a known vulnerability.

---

## Step 5 — Run Quality Checks (inline)

Invoke the `run-quality-checks` skill inline — do not re-list ruff or ty commands here:

1. Read `.agents/skills/run-quality-checks/SKILL.md`.
2. Follow its commands in the current context.

Fix any ruff or ty issues introduced by the dependency upgrade before proceeding.

---

## Step 6 — Run the Test Suite

```bash
uv run pytest tests/
```

If any tests fail:
1. Determine whether the failure is caused by an API change in the upgraded dependency.
2. If yes: note the affected package and version, then halt. Report the failure and the
   affected package to the user — do not commit broken code.
3. If the failure appears pre-existing and unrelated to the upgrade, note it in the commit
   message but do not let it block the commit (use judgment; document the decision).

---

## Step 7 — Commit and Push

After all checks pass, commit the lockfile and any `pyproject.toml` changes:

```bash
git --no-pager add uv.lock pyproject.toml
git commit -m "chore: upgrade dependencies

Updated via uv lock --upgrade. pip-audit: clean. Tests: passing.

Notable changes:
<list key version bumps if visible from uv.lock diff>

Co-Authored-By: Oz <oz-agent@warp.dev>"
```

Push to the current branch:

```bash
git --no-pager push origin HEAD
```

Do not force-push. If the push is rejected (diverged branch), report the conflict to the
user rather than rebasing automatically.

---

## Report

After completing (or halting), report:

- Whether the lockfile was upgraded successfully
- pip-audit result (clean or advisory details)
- Quality check result (pass or issues found)
- Test result (pass or failures)
- What was committed and pushed (or why the commit was skipped)

---

## Gotchas

- **pip-audit is required before committing** — if unavailable, halt and tell the user to install it via `uv tool install pip-audit`.
- **`UV_LOCKED=1` breaks `uv run`** after `pyproject.toml` changes — use `UV_LOCKED=0` prefix for dev checks.
- **Do not commit with known vulnerabilities** — if a patched version exists, update the constraint; if not, halt and report.

Last Updated: 2026.05.04 @ 04:15:00
