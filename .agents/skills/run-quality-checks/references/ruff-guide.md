# Ruff Guide

## Table of Contents
- [Check for Issues](#check-for-issues)
- [Auto-Fix Issues](#auto-fix-issues)
- [Format Code](#format-code)
- [Ruff Configuration](#ruff-configuration)
- [Common Issues](#common-issues)

---

## Check for Issues

```bash
# Check all files
uv run ruff check .

# Check specific directory
uv run ruff check src/

# Check specific file
uv run ruff check src/mypackage/module.py
```

## Auto-Fix Issues

```bash
# Fix auto-fixable issues
uv run ruff check --fix .

# Preview fixes without applying
uv run ruff check --diff .
```

## Format Code

```bash
# Format all files
uv run ruff format .

# Check formatting without changes
uv run ruff format --check .
```

## Ruff Configuration

Located in `pyproject.toml`:

```toml
[tool.ruff]
line-length = 100
target-version = "py313"

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # Pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
]
```

## Common Issues

### Line Too Long

```bash
# Ruff will flag lines > 100 characters
uv run ruff check .

# Fix by breaking lines
data = some_function(
    param1="value1",
    param2="value2",
    param3="value3"
)
```

### Import Sorting

```bash
# Ruff auto-sorts imports
uv run ruff check --fix .

# Organizes as:
# 1. Standard library
# 2. Third-party
# 3. Local imports
```

### Unused Imports

```bash
# Ruff detects and removes unused imports
uv run ruff check --fix .
```

Last Updated: 2026.05.04 @ 03:17:04
