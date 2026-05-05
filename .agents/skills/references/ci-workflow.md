# CI and Workflow Reference

## Table of Contents
- [Pre-Commit Workflow](#pre-commit-workflow)
- [After Adding Dependencies](#after-adding-dependencies)
- [Marimo Notebooks](#marimo-notebooks)
- [CI Integration](#ci-integration)

---

## Pre-Commit Workflow

Before committing code:

```bash
# 1. Format code
uv run ruff format .

# 2. Fix auto-fixable linting issues
uv run ruff check --fix .

# 3. Check remaining linting issues
uv run ruff check .

# 4. Run type checker
uv run ty check

# 5. Run unit tests only (fast)
uv run pytest tests/ -m unit

# 6. Run full test suite
uv run pytest tests/
```

## After Adding Dependencies

When `UV_LOCKED=1` is set, regenerate the lock file first:

```bash
UV_LOCKED=0 uv lock                    # update lock file
UV_LOCKED=0 uv sync                    # install new packages into .venv
UV_LOCKED=0 uv run ruff check ...      # then run quality checks
UV_LOCKED=0 uv run pytest tests/ -m unit
```

> **After changing a dependency group's version**, run `uv sync` to install the updated
> packages into `.venv` BEFORE running `ty check`. Without it, `ty` still reads old type
> stubs and may report false errors.

## Marimo Notebooks

Marimo notebooks have special type checking rules:

```python
# reportUnusedExpression = "none" for marimo
# Last expression is intentionally "unused" (it's the display)
df  # This is OK in marimo notebooks
```

## CI Integration

Quality checks should run in any CI system (GitLab CI, GitHub Actions, etc.) using `uv run`:

```bash
# Run in CI pipeline
uv run ruff check .
uv run ty check
uv run pytest tests/ -m unit
```

CI typically sets `UV_LOCKED=1`. If a new dependency was added and the lock file committed,
CI runs will work. If you only see `uv lock` errors locally, use `UV_LOCKED=0` prefix.

Last Updated: 2026.05.04 @ 03:17:04
