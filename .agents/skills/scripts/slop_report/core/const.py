"""Shared constants for the slop_report package."""

_SUPPORTED_STATUSES: frozenset[str] = frozenset({"pass", "fail", "skip"})
_SUPPORTED_SEVERITIES: frozenset[str] = frozenset({"error", "warning"})
_EM_DASH = "\u2014"
_ORPHAN_PATTERNS: tuple[str, ...] = (
    "slop_lint_*.json",
    "slop_lint_*.md",
    "slop_lint_full_*.md",
)
