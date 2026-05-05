# Parametrization and Test Organization Guide

## Table of Contents
1. [Parametrization](#1-parametrization)
2. [Test Organization](#2-test-organization)

---

## 1. Parametrization

Use `@pytest.mark.parametrize` with **descriptive ids** whenever testing multiple inputs. Never
duplicate test logic.

```python
@pytest.mark.parametrize(
    "input_value,expected_output",
    [
        (0, "zero"),
        (1, "positive"),
        (-1, "negative"),
    ],
    ids=["zero", "positive", "negative"],
)
@pytest.mark.unit
def test_classify_value(input_value, expected_output):
    result = classify_value(input_value)
    assert result == expected_output, (
        f"Expected {expected_output!r} for input={input_value}, got {result!r}"
    )
```

---

## 2. Test Organization

- Group related tests in `Test*` classes with docstrings
- Name: `test_<function>_<scenario>_<expected_result>`

```python
class TestComputeScore:
    """Tests for compute_score() in analysis.py."""

    @pytest.mark.unit
    def test_compute_score_returns_zero_on_empty_input(self, empty_df):
        """Returns 0.0 when input DataFrame has no rows."""
        result = compute_score(empty_df)
        assert result == 0.0, f"Expected 0.0, got {result!r}"

    @pytest.mark.unit
    def test_compute_score_sorts_output_descending(self, sample_records_df):
        """Results are ordered by score, highest first."""
        results = compute_score(sample_records_df)
        scores = [r["score"] for r in results]
        assert scores == sorted(scores, reverse=True), (
            f"Expected descending scores, got {scores}"
        )
```

File naming: `test_<module_name>.py` → `test_analysis.py`

Last Updated: 2026.05.04 @ 03:16:40
