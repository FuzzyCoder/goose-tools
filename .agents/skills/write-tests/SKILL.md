---
name: write-tests
description: Write tests following pytest conventions and markers for uv-managed Python projects. Use when writing new tests, structuring test classes, fixtures, or parametrize calls. Not for running quality checks (use run-quality-checks skill instead).
metadata:
  version: 1.0.0
---

# Write Tests

## When to Use
- Writing new pytest tests for any project module
- Structuring test classes, fixtures, or parametrize calls following project conventions
- Not for running quality checks (use `run-quality-checks` skill instead)

Tests live in `tests/` and follow strict pytest conventions. Every test must have
a marker, use descriptive assertions, and remain isolated from external dependencies.

## 1. Markers

Every test **must** have exactly one marker. Never write an unmarked test.

| Marker | Use when |
|--------|----------|
| `@pytest.mark.unit` | Fast, isolated — no DB, no API, no filesystem |
| `@pytest.mark.integration` | Multiple components interact; real internal state |
| `@pytest.mark.slow` | Test takes > 1 second |

```python
@pytest.mark.unit
def test_compute_score_basic():
    ...

@pytest.mark.integration
def test_full_pipeline_creates_database():
    ...

@pytest.mark.slow
@pytest.mark.integration
def test_generate_report_end_to_end():
    ...
```

Run subsets by marker:

```bash
uv run pytest tests/ -m unit
uv run pytest tests/ -m "not integration"
uv run pytest tests/ -m "not slow"
```

## 2. Assertions

**NEVER** use bare `assert` without a message. Always include an f-string showing expected vs actual.

```python
# ❌ Wrong
assert len(result) == 3
assert result["status"] == "active"

# ✅ Correct
assert len(result) == 3, f"Expected 3 results, got {len(result)}"
assert result["status"] == "active", f"Expected status='active', got {result['status']!r}"
```

Always test exception messages too:

```python
with pytest.raises(ValueError, match="Missing required columns"):
    process_data(empty_df)
```

## 5. Mocking

In `@pytest.mark.unit` tests: **mock all external dependencies** — no real DB connections, no real
API calls, no filesystem writes.

```python
from unittest.mock import MagicMock, patch

@pytest.mark.unit
def test_generate_report_calls_external_api(sample_facts):
    mock_client = MagicMock()
    mock_client.post.return_value = MagicMock(status_code=200, json=lambda: {"result": "ok"})
    with patch("{{PACKAGE_NAME}}.services.api_client.ApiClient", return_value=mock_client):
        result = generate_report(sample_facts)
    assert result is not None, "Report should be generated"
```

Use `pytest-mock` (`mocker` fixture) as an alternative.

## Commands

```bash
uv run pytest tests/
uv run pytest tests/ -m unit
uv run pytest tests/ -m "not integration"
uv run pytest tests/test_analysis.py
uv run pytest --cov={{PACKAGE_NAME}} tests/
uv run pytest tests/ -v
```

> Always use `uv run pytest` — never bare `pytest`.

## Gotchas

- **Every test MUST have exactly one marker** — `@pytest.mark.unit`, `@pytest.mark.integration`, or `@pytest.mark.slow`.
- **Never use bare `assert`** — always include an f-string showing expected vs actual.
- **Unit tests must mock all external dependencies** — no real DB, API, or filesystem access.
- **Always use `uv run pytest`** — never bare `pytest`.

## References Structure

- `references/fixtures.md` — shared fixtures, scopes, temp files, and test data patterns
- `references/parametrize-guide.md` — parametrization patterns and test organization
- `references/datetime-testing.md` — testing timezone-aware datetime formatters
- `references/patching-guide.md` — patching deferred imports, ty/asyncio, and pytest.raises

Last Updated: 2026.05.04 @ 04:15:00
