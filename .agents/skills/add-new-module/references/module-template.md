# Module Structure Template and Integration Steps

## Table of Contents
1. [Module Structure Template](#1-module-structure-template)
2. [Integration Steps](#2-integration-steps)

---

## 1. Module Structure Template

```python
"""Module description.

Extended explanation of purpose and usage.
"""

from pathlib import Path

import polars as pl
from loguru import logger

from {{PACKAGE_NAME}}.core.const import CONSTANT_NAME
from {{PACKAGE_NAME}}.core.paths import DATA_PATH


def public_function(
    records_df: pl.DataFrame,
    param: str
) -> pl.DataFrame:
    """Public function with Google docstring.

    Args:
        records_df: Input dataframe
        param: Configuration parameter

    Returns:
        Transformed dataframe

    Example:
        >>> result = public_function(records_df, "value")
    """
    # Input validation
    if records_df.is_empty():
        raise ValueError("DataFrame cannot be empty")

    # Implementation
    try:
        result = _internal_helper(records_df, param)
    except Exception as e:
        logger.error(f"Function failed: {e}")
        raise RuntimeError(f"Processing error: {e}") from e

    return result


def _internal_helper(records_df: pl.DataFrame, param: str) -> pl.DataFrame:
    """Private helper function (prefixed with _).

    Internal functions don't need extensive docs but should
    still have basic description of purpose.
    """
    return records_df.filter(pl.col("field") == param)
```

---

## 2. Integration Steps

### 2.1. Add to `__init__.py`

```python
# In {{PACKAGE_NAME}}/data/__init__.py
from {{PACKAGE_NAME}}.data.transformers.new_transformer import transform_data

__all__ = ["transform_data"]
```

### 2.2. Add Tests

```python
# In tests/test_new_transformer.py
import pytest
import polars as pl

from {{PACKAGE_NAME}}.data.transformers.new_transformer import transform_data


@pytest.mark.unit
def test_transform_data_basic():
    """Test basic transformation functionality."""
    records_df = pl.DataFrame({"id": [1, 2], "value": [10, 20]})
    result = transform_data(records_df, threshold=15.0)

    assert len(result) == 1, f"Expected 1 row, got {len(result)}"
    assert result["id"][0] == 2, "Expected id=2 after filtering"
```

### 2.3. Update Documentation

Add to relevant documentation files:
- API reference
- Module-specific AGENTS.md if adding a new subdirectory
- Architecture docs if the change is significant

### 2.4. Run Quality Checks

```bash
# Format and lint
uv run ruff format .
uv run ruff check --fix .

# Type check
uv run ty check

# Run tests
uv run pytest tests/test_new_transformer.py
```

Last Updated: 2026.05.04 @ 03:16:40
