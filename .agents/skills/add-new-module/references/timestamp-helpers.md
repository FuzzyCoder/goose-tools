# Timestamp Display Helpers

## Table of Contents
1. [The Three-Helper Pattern](#1-the-three-helper-pattern)
2. [Key Principles](#2-key-principles)

---

## 1. The Three-Helper Pattern

When a module produces user-facing timestamp strings, use dedicated helpers that separate
display semantics from storage semantics. **Store UTC, display local time.**

```python
from datetime import datetime


def format_ts_display(dt: datetime | None) -> str:
    """Local-time display for tables and headers: YYYY-MM-DD @ HH:MM:SS ZZZ.

    Converts aware datetimes to local timezone via astimezone().
    Naive datetimes are formatted as-is (no conversion).
    Returns em-dash for None.
    """
    if dt is None:
        return "\u2014"  # em dash
    if dt.tzinfo is not None:
        dt = dt.astimezone()
    return dt.strftime("%Y-%m-%d @ %H:%M:%S %Z")


def format_ts_name(dt: datetime | None) -> str:
    """Local-time for labels: YYYY-MM-DD @ HH:MM ZZZ (no seconds).

    Use for auto-generated names, selector labels, and legacy display.
    """
    if dt is None:
        return "\u2014"
    if dt.tzinfo is not None:
        dt = dt.astimezone()
    return dt.strftime("%Y-%m-%d @ %H:%M %Z")


def format_ts_path(dt: datetime) -> str:
    """UTC compact timestamp for filenames: YYYYMMDD_HHMMSS.

    Always UTC. Used for file/directory names so artifact paths
    are stable regardless of the operator's local timezone.
    """
    return dt.strftime("%Y%m%d_%H%M%S")
```

---

## 2. Key Principles

- `astimezone()` only when `dt.tzinfo is not None` — never call it on naive datetimes
- **Persist in UTC**: DB timestamps, canonical run-start times, and path resolution all use UTC
- **`%Z` returns `''` for naive datetimes on macOS** — account for trailing space in assertions

Last Updated: 2026.05.04 @ 03:16:40
