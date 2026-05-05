"""Data models for slop_report."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class ParsedSlopReport:
    """Parsed and validated slop JSON with pre-computed partitions.

    Attributes:
        data: Raw top-level JSON object.
        version: Top-level ``version`` string.
        rules: Top-level ``rules`` mapping.
        summary: Top-level ``summary`` object.
        summary_violation_count: Errors-only count from ``summary.violation_count``.
        summary_advisory_count: Warnings-only count from ``summary.advisory_count``.
        rule_error_counts: Per-rule count of ``severity: "error"`` violations.
        rule_advisory_counts: Per-rule count of ``severity: "warning"`` violations.
        error_rules: Rule keys with \u22651 error violation (JSON file order).
        advisory_only_rules: Rule keys with \u22651 warning and 0 errors (JSON file order).
        zero_rules: Rule keys with empty violations[] regardless of status (JSON file order).
        pass_rules: Rule keys with ``status: "pass"`` (JSON file order).
        skip_rules: Rule keys with ``status: "skip"`` (JSON file order).
    """

    data: dict[str, Any]
    version: str
    rules: dict[str, Any]
    summary: dict[str, Any]
    summary_violation_count: int
    summary_advisory_count: int
    rule_error_counts: dict[str, int] = field(default_factory=dict)
    rule_advisory_counts: dict[str, int] = field(default_factory=dict)
    error_rules: list[str] = field(default_factory=list)
    advisory_only_rules: list[str] = field(default_factory=list)
    zero_rules: list[str] = field(default_factory=list)
    pass_rules: list[str] = field(default_factory=list)
    skip_rules: list[str] = field(default_factory=list)
