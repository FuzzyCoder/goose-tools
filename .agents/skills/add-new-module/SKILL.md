---
name: add-new-module
description: Create new modules following project conventions for structure, imports, documentation, and naming. Use when creating a new module, utility function, or data transformer. Not for new project scaffolding — use a project-specific scaffolding skill instead. Not for editing existing modules (use fix-* skills or refactor-agent-instructions instead).
---

# Add New Module

## When to Use
- Creating a new module, utility function, or data transformer in the project package
- Naming, documenting, or organizing code within an existing package
- Not for new project scaffolding (use a project-specific scaffolding skill instead)

## Module Creation Workflow

1. Choose location by purpose (`core/`, `data/`, `utils/`)
2. Create file and add header with Google docstring, imports, and example usage
3. See `references/module-template.md` for full template and integration steps

## Import Conventions

### Always Import Specific Symbols

```python
# ✅ Correct: Import specific symbols
from {{PACKAGE_NAME}}.core.const import VERSION, PROJECT_NAME
from {{PACKAGE_NAME}}.core.paths import DATA_DIR, MODELS_PATH

# ❌ Wrong: Import entire modules
import {{PACKAGE_NAME}}.core.const as const
from {{PACKAGE_NAME}}.core import paths
```

### Import Order

```python
# 1. Standard library
from typing import Optional
from pathlib import Path
from datetime import datetime

# 2. Third-party
import polars as pl
import duckdb
from loguru import logger

# 3. Local imports (specific symbols only)
from {{PACKAGE_NAME}}.core.const import CONSTANT_NAME
from {{PACKAGE_NAME}}.core.paths import DATA_PATH
```

## Function Documentation

### Use Google Docstring Format

```python
def process_data(
    records_df: pl.DataFrame,
    threshold: float,
    exclude_nulls: bool = True
) -> pl.DataFrame:
    """Process dataframe with filtering and transformations.

    Applies threshold filtering and optionally removes null values.
    Returns transformed dataframe with new derived columns.

    Args:
        records_df: Input dataframe with required columns: id, value, category
        threshold: Minimum value for filtering (inclusive)
        exclude_nulls: If True, remove rows with any null values

    Returns:
        Transformed dataframe with filtered rows and derived columns

    Raises:
        ValueError: If required columns are missing
        TypeError: If records_df is not a polars DataFrame

    Example:
        >>> import polars as pl
        >>> records_df = pl.DataFrame({"id": [1, 2], "value": [10, 20]})
        >>> result = process_data(records_df, threshold=15.0)
        >>> len(result)
        1
    """
    # Implementation
    pass
```

## Error Handling

Fail fast with context. Validate inputs at function entry, chain exceptions, and never
return empty DataFrames on errors. See the `references/module-template.md` for full
examples including `__init__.py`, tests, and quality-check commands.

## Gotchas

- **Do not hardcode paths** in module code — use `core/paths.py` and `core/const.py` instead.
- **Do not use `_key` or `_id` suffixes** in data models — use semantic names like `note_id`, `user_id`.
- **DataFrame variables must end with `_df`** — never use `df_` prefix.
- **Never return empty `pl.DataFrame()` on errors** — let exceptions propagate with context.
- **Use `uv run python -m` in all doc examples** — never bare `python -m`.

## References Structure

- `references/module-template.md` — full module template, `__init__.py`, tests, and quality-check commands
- `references/timestamp-helpers.md` — `format_ts_display`, `format_ts_name`, `format_ts_path` helpers

Last Updated: 2026.05.04 @ 04:15:00
