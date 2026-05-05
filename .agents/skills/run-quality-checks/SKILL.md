---
name: run-quality-checks
description: Run code quality checks using ruff for linting and ty for type checking. Use when running quality checks, debugging lint/type errors, or preparing code for commit. Not for writing new tests (use write-tests skill instead).
---

# Run Quality Checks

## When to Use
- Running ruff linting, ty type checking, or pytest for project code
- Debugging lint errors, type errors, or test failures
- Not for writing new tests (use `write-tests` skill instead)

## Quick Start

This library uses **ruff** for linting and **ty** for type checking to maintain code quality.

```bash
# Run all quality checks
uv run ruff check .
uv run ty check
```

> **UV_LOCKED workaround**: If `UV_LOCKED=1` is set in the environment (CI or shell
> integration), `uv run` fails after any change to `pyproject.toml` until the lock file is
> regenerated. Prefix with `UV_LOCKED=0` for dev checks:
> ```bash
> UV_LOCKED=0 uv run ruff check .
> UV_LOCKED=0 uv run pytest tests/ -m unit
> ```
> To update the lock file properly: `UV_LOCKED=0 uv lock`

## Ruff

Run linting and formatting with `uv run ruff check .` and `uv run ruff format .`.
See `references/ruff-guide.md` for full commands, configuration, and common fixes.

## Ty

Run type checking with `uv run ty check`.
See `references/ty-guide.md` for full commands, configuration, and type error fixes.

## Best Practices

1. **Run Before Committing**: Always run quality checks before git commit
2. **Fix Auto-Fixable**: Use `ruff check --fix` to auto-fix issues
3. **Address Type Errors**: Don't ignore ty warnings — fix the types
4. **Format Consistently**: Use `ruff format` for consistent code style
5. **Check Incrementally**: Run checks on changed files during development
6. **Never Suppress**: Don't add `# noqa` or `# type: ignore` without justification
7. **Follow Line Length**: Keep lines under 100 characters (ruff: `line-length = 100`)
8. **ty is for source only**: `ty` checks `{{PACKAGE_NAME}}/` by default (see `[tool.ty.src]`);
   run `ty check <path>` explicitly for test files

## Quick Reference

```bash
# Lint and fix
uv run ruff check --fix .

# Format
uv run ruff format .

# Type check
uv run ty check

# All checks
uv run ruff check . && uv run ty check && uv run pytest tests/
```

## Gotchas

- **`UV_LOCKED=1` causes `uv run` to fail** after `pyproject.toml` changes — prefix with `UV_LOCKED=0` for dev checks.
- **`ty` checks `{{PACKAGE_NAME}}/` by default** — run `ty check <path>` explicitly for test files.
- **Never add `# noqa` or `# type: ignore` without justification** — fix the underlying issue first.

## References Structure

- `references/ruff-guide.md` — Ruff commands, configuration, and common issues (line too long, imports, unused)
- `references/ty-guide.md` — Ty commands, configuration, and type error fixes
- `references/ci-workflow.md` — Pre-commit workflow, CI integration, and Marimo notebooks

Last Updated: 2026.05.04 @ 04:15:00
