# Testing Datetime Formatters

## Table of Contents
1. [The Timezone-Abbreviation Pitfall](#1-the-timezone-abbreviation-pitfall)
2. [Check Format Structure, Not Content](#2-check-format-structure-not-content)
3. [`%Z` is Empty for Naive Datetimes on macOS](#3-z-is-empty-for-naive-datetimes-on-macos)
4. [Use `datetime.UTC` (Not `timezone.utc`)](#4-use-datetimeutc-not-timezoneutc)

---

## 1. The Timezone-Abbreviation Pitfall

Timezone abbreviations like `CDT`, `CST`, `PST`, `CET`, `MST` contain the letters T, C, P, etc.
Do **not** assert `"T" not in result` or `result.endswith("T")` on a full timestamp string:

```python
# ❌ Wrong — fails when local timezone abbreviation contains 'T' (e.g. CDT, CST)
result = format_ts_display(dt)  # → '2026-03-24 @ 07:00:00 CDT'
assert "T" not in result  # AssertionError: CDT contains T

# ✅ Correct — isolate the date portion and check only that
date_part = result.split(" @ ")[0]  # → '2026-03-24'
assert "T" not in date_part, f"Expected no ISO 'T' in date, got {result!r}"
```

---

## 2. Check Format Structure, Not Content

For display format assertions, check the structure separator, not character absence:

```python
# Test that local-time '@' format is used (not ISO 'T' format)
assert " @ " in result, f"Expected '@' separator, got {result!r}"

# Test that seconds are absent (name format: HH:MM only)
time_and_zone = result.split(" @ ")[1]  # e.g. '07:00 CDT'
time_part = time_and_zone.split(" ")[0]   # e.g. '07:00'
assert time_part.count(":") == 1, f"Expected HH:MM (no seconds), got {time_part!r}"
```

---

## 3. `%Z` is Empty for Naive Datetimes on macOS

`strftime("%Z")` returns an empty string for naive datetimes (no tzinfo). Do not assert that
`%Z` produces a non-empty abbreviation unless the datetime is tz-aware:

```python
from datetime import UTC, datetime

# tz-aware: %Z produces the local abbreviation (e.g. 'PST', 'CDT')
aware_dt = datetime(2026, 3, 24, 12, 0, 0, tzinfo=UTC)
result = aware_dt.astimezone().strftime("%Y-%m-%d @ %H:%M %Z")
# → '2026-03-24 @ 07:00 CDT'

# naive: %Z produces '' (empty string) on macOS
naive_dt = datetime(2026, 3, 24, 12, 0, 0)
result = naive_dt.strftime("%Y-%m-%d @ %H:%M %Z")
# → '2026-03-24 @ 12:00 '  (trailing space)
```

---

## 4. Use `datetime.UTC` (Not `timezone.utc`)

```python
from datetime import UTC, datetime  # ✅ Python 3.11+ alias

# ❌ Old form (still valid but triggers UP017 ruff warning)
from datetime import datetime, timezone
dt = datetime(2026, 1, 1, tzinfo=timezone.utc)

# ✅ Modern form
dt = datetime(2026, 1, 1, tzinfo=UTC)
```

Last Updated: 2026.05.04 @ 03:16:40
