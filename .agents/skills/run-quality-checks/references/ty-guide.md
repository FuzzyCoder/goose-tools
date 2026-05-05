# Ty Guide

## Table of Contents
- [Check Types](#check-types)
- [Common Type Issues](#common-type-issues)
- [Ty Configuration](#ty-configuration)
- [Type Errors](#type-errors)

---

## Check Types

```bash
# Check entire project
uv run ty check

# Check specific file
uv run ty check src/mypackage/module.py

# Check with verbose output
uv run ty check --verbose
```

## Common Type Issues

**Missing type hints**:
```python
# ❌ Missing types
def process_data(data):
    return data

# ✅ With types
def process_data(data: dict) -> dict:
    return data
```

**Import type hints**:
```python
from pathlib import Path

def load_file(path: Path | None = None) -> str | None:
    if path is None:
        return None
    return path.read_text()
```

## Ty Configuration

Located in `pyproject.toml`:

```toml
[tool.ty]

# Python environment configuration
[tool.ty.environment]
python-version = "3.13"

# Source paths to check
[tool.ty.src]
include = ["{{PACKAGE_NAME}}"]
```

## Type Errors

```bash
# Ty flags type mismatches
uv run ty check

# Fix by adding/correcting type hints
def process_records_df(records_df: pl.DataFrame) -> pl.DataFrame:
    return records_df.filter(...)
```

Last Updated: 2026.05.04 @ 03:17:04
