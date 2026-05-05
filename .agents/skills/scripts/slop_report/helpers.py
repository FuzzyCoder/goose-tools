"""Shared text formatting helpers for slop_report."""

from slop_report.core.const import _EM_DASH


def oxford_join(items: list[str]) -> str:
    """Join backtick-quoted names with Oxford comma rules.

    Each item is wrapped in backtick code spans before joining.

    Args:
        items: Names to join (unquoted).

    Returns:
        Oxford-comma-joined string with each name in backtick code spans.

    Examples:
        >>> oxford_join([])
        ''
        >>> oxford_join(["foo"])
        '`foo`'
        >>> oxford_join(["foo", "bar"])
        '`foo` and `bar`'
        >>> oxford_join(["foo", "bar", "baz"])
        '`foo`, `bar`, and `baz`'
    """
    quoted = [f"`{item}`" for item in items]
    if not quoted:
        return ""
    if len(quoted) == 1:
        return quoted[0]
    if len(quoted) == 2:
        return f"{quoted[0]} and {quoted[1]}"
    return ", ".join(quoted[:-1]) + ", and " + quoted[-1]


def render_int(value: int) -> str:
    """Render a count for the table: integer if non-zero, em-dash if zero.

    Args:
        value: Non-negative integer count.

    Returns:
        Plain integer string for non-zero values, U+2014 em-dash for zero.

    Examples:
        >>> render_int(0)
        '\u2014'
        >>> render_int(42)
        '42'
    """
    return str(value) if value != 0 else _EM_DASH
