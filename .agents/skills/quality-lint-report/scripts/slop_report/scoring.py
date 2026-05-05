"""Human-readable scope strings for each slop rule."""

from typing import Any


def get_rule_scope(rule_key: str, rule_summary: dict[str, Any]) -> str:
    """Return the human-readable scope string for a rule's per-rule summary.

    Used in the Rule Summary table (full report) and Passes section.

    Args:
        rule_key: The slop rule identifier (e.g. ``"complexity.cyclomatic"``).
        rule_summary: The per-rule ``summary`` object from the JSON.

    Returns:
        Scope string, or empty string for unrecognised rule keys.

    Examples:
        >>> get_rule_scope("complexity.cyclomatic", {"functions_checked": 1000})
        '1,000 functions'
        >>> get_rule_scope("hotspots", {"files_analyzed": 69, "window_since": "14 days ago"})
        '69 files (14 days window)'
        >>> get_rule_scope("packages", {"packages_analyzed": 56})
        '56 packages'
    """
    if rule_key in ("complexity.cyclomatic", "complexity.cognitive"):
        fc = int(rule_summary.get("functions_checked", 0))
        return f"{fc:,} functions"
    if rule_key == "complexity.weighted":
        cc = int(rule_summary.get("classes_checked", 0))
        return f"{cc:,} classes"
    if rule_key in ("halstead.volume", "halstead.difficulty", "npath"):
        fc = int(rule_summary.get("functions_checked", 0))
        return f"{fc:,} functions"
    if rule_key == "hotspots":
        fa = int(rule_summary.get("files_analyzed", 0))
        ws = str(rule_summary.get("window_since", ""))
        return f"{fa} files ({ws.replace(' ago', '')} window)"
    if rule_key == "packages":
        pa = int(rule_summary.get("packages_analyzed", 0))
        return f"{pa} packages"
    if rule_key == "deps":
        fa = int(rule_summary.get("files_analyzed", 0))
        return f"{fa:,} files (import cycles)"
    if rule_key in ("class.coupling", "class.inheritance.depth", "class.inheritance.children"):
        cc = int(rule_summary.get("classes_checked", 0))
        return f"{cc:,} classes"
    if rule_key == "orphans":
        sa = int(rule_summary.get("symbols_analyzed", 0))
        return f"{sa:,} symbols"
    return ""
