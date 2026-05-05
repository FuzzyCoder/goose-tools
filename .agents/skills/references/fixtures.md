# Test Fixtures and Data Guide

## Table of Contents
1. [Fixtures](#1-fixtures)
2. [Test Data](#2-test-data)

---

## 1. Fixtures

- **Shared fixtures**: define in `conftest.py` at the appropriate level
- **Cleanup**: use `yield` for setup/teardown
- **Temp files**: always use `tmp_path` — never hardcode paths
- **Scope**: choose the narrowest scope that works (`function` default, `session` for expensive setup)

```python
# tests/conftest.py
import pytest
import polars as pl

@pytest.fixture
def sample_records_df() -> pl.DataFrame:
    """Minimal records DataFrame covering key edge cases."""
    return pl.DataFrame({
        "record_id": ["r1", "r2", "r3"],
        "category": ["A", "B", "A"],
        "value": [10, 20, 30],
        "active": [True, False, True],
    })

@pytest.fixture
def temp_db(tmp_path):
    """Temporary DuckDB database; auto-cleaned via tmp_path."""
    db_path = tmp_path / "test.duckdb"
    yield db_path
    # tmp_path handles cleanup automatically
```

---

## 2. Test Data

- **Always use `polars.DataFrame`** — never pandas
- Create minimal data that covers the edge cases being tested
- Never use production data

```python
import polars as pl

# ✅ Minimal Polars DataFrame with typed schema
records_df = pl.DataFrame({
    "record_id": ["r1", "r2"],
    "category": ["A", "B"],
    "value": [10, 0],
    "count": [3, 0],
}).with_columns([
    pl.col("value").cast(pl.Int32),
    pl.col("count").cast(pl.Int32),
])

# ❌ Never use pandas
import pandas as pd  # WRONG
df = pd.DataFrame(...)  # WRONG
```

Last Updated: 2026.05.04 @ 03:16:40
