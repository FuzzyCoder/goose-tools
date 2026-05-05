"""JSON parsing and structural validation for slop reports."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from slop_report.core.const import _SUPPORTED_SEVERITIES, _SUPPORTED_STATUSES
from slop_report.models import ParsedSlopReport


def _validate_path(json_path: Path) -> None:
    """Validate that *json_path* is a regular file with a ``.json`` suffix.

    Args:
        json_path: Candidate path.

    Raises:
        ValueError: If the path does not exist, is not a regular file, or
            lacks a ``.json`` suffix.
    """
    if not json_path.exists():
        raise ValueError(f"{json_path}: file does not exist")
    if not json_path.is_file():
        raise ValueError(f"{json_path}: not a regular file")
    if json_path.suffix != ".json":
        raise ValueError(f"{json_path}: expected .json suffix, got {json_path.suffix!r}")


def _parse_json_structure(json_path: Path) -> dict[str, Any]:
    """Load and validate top-level structure from the slop JSON file.

    Args:
        json_path: Path to a valid JSON file.

    Returns:
        The parsed JSON dict.

    Raises:
        ValueError: If JSON parsing fails or top-level ``rules`` / ``summary``
            objects are missing.
    """
    try:
        data: Any = json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ValueError(f"{json_path}: failed to parse JSON: {e}") from e

    if not isinstance(data, dict):
        raise ValueError(
            f"{json_path}: expected a JSON object at top level, got {type(data).__name__}"
        )
    if not isinstance(data.get("rules"), dict):
        raise ValueError(f"{json_path}: missing or invalid top-level 'rules' object")
    if not isinstance(data.get("summary"), dict):
        raise ValueError(f"{json_path}: missing or invalid top-level 'summary' object")
    return data


def _validate_summary(summary: dict[str, Any], json_path: Path) -> tuple[int, int]:
    """Validate that *summary* contains required count fields.

    Args:
        summary: The top-level ``summary`` dict.
        json_path: Source path (used only in error messages).

    Returns:
        ``(violation_count, advisory_count)`` as ints.

    Raises:
        ValueError: If ``violation_count`` or ``advisory_count`` are missing.
    """
    if "violation_count" not in summary:
        raise ValueError(f"{json_path}: summary missing 'violation_count'")
    if "advisory_count" not in summary:
        raise ValueError(f"{json_path}: summary missing 'advisory_count'")
    return int(summary["violation_count"]), int(summary["advisory_count"])


def _validate_rule_status(
    rule_key: str, rule_data: dict[str, Any], json_path: Path
) -> None:
    """Validate a single rule's ``status`` field.

    Args:
        rule_key: Rule identifier.
        rule_data: The rule's dict.
        json_path: Source path (used in error messages).

    Raises:
        ValueError: If ``status`` is not a supported value.
    """
    status = rule_data.get("status")
    if status not in _SUPPORTED_STATUSES:
        raise ValueError(
            f"{json_path}: rule {rule_key!r} has unsupported status {status!r}; "
            f"supported: {sorted(_SUPPORTED_STATUSES)}"
        )


def _validate_violation(
    rule_key: str, idx: int, violation: Any, json_path: Path
) -> str:
    """Validate a single violation entry and return its severity.

    Args:
        rule_key: Rule identifier.
        idx: Index within the ``violations`` list.
        violation: The violation object.
        json_path: Source path (used in error messages).

    Returns:
        The violation severity string (``"error"`` or ``"warning"``).

    Raises:
        ValueError: If the violation is not a dict or has an unsupported
            ``severity`` value.
    """
    if not isinstance(violation, dict):
        raise ValueError(
            f"{json_path}: rule {rule_key!r} violations[{idx}] is not an object"
        )
    severity = violation.get("severity")
    if severity not in _SUPPORTED_SEVERITIES:
        raise ValueError(
            f"{json_path}: rule {rule_key!r} violations[{idx}] has unsupported "
            f"severity {severity!r}; supported: {sorted(_SUPPORTED_SEVERITIES)}"
        )
    return severity


def _partition_rules(
    rules: dict[str, Any],
    rule_error_counts: dict[str, int],
    rule_advisory_counts: dict[str, int],
) -> tuple[list[str], list[str], list[str], list[str], list[str]]:
    """Partition rules into error / advisory-only / zero / pass / skip lists.

    Args:
        rules: Mapping of rule key to rule data dict.
        rule_error_counts: Per-rule error counts.
        rule_advisory_counts: Per-rule advisory counts.

    Returns:
        ``(error_rules, advisory_only_rules, zero_rules, pass_rules, skip_rules)``
        in JSON file order.
    """
    error_rules: list[str] = []
    advisory_only_rules: list[str] = []
    zero_rules: list[str] = []
    pass_rules: list[str] = []
    skip_rules: list[str] = []

    for rule_key, rule_data in rules.items():
        status = rule_data.get("status")
        e = rule_error_counts[rule_key]
        a = rule_advisory_counts[rule_key]

        if e > 0:
            error_rules.append(rule_key)
        elif a > 0:
            advisory_only_rules.append(rule_key)
        else:
            zero_rules.append(rule_key)

        if status == "pass":
            pass_rules.append(rule_key)
        elif status == "skip":
            skip_rules.append(rule_key)

    return error_rules, advisory_only_rules, zero_rules, pass_rules, skip_rules


def parse_and_validate(json_path: Path) -> ParsedSlopReport:
    """Parse and validate a slop lint JSON file, returning a ``ParsedSlopReport``.

    Performs structural validation, per-rule severity counting, and cross-checks
    that computed counts match the top-level summary totals.

    Args:
        json_path: Path to the slop lint JSON file. Must exist, be a regular
            file, and have a ``.json`` suffix.

    Returns:
        A ``ParsedSlopReport`` with all partitions pre-computed.

    Raises:
        ValueError: If the path is invalid; the JSON fails to parse; the
            top-level ``rules`` or ``summary`` objects are missing or malformed;
            any rule has an unsupported ``status`` or a violation entry has an
            unsupported ``severity``; or per-rule computed counts do not match
            the top-level summary totals.

    Examples:
        >>> from pathlib import Path
        >>> parse_and_validate(Path(".slop/slop_lint.json"))  # doctest: +SKIP
        ParsedSlopReport(...)
    """
    _validate_path(json_path)
    data = _parse_json_structure(json_path)
    rules: dict[str, Any] = data["rules"]
    summary: dict[str, Any] = data["summary"]
    version = str(data.get("version", ""))

    summary_violation_count, summary_advisory_count = _validate_summary(summary, json_path)

    rule_error_counts: dict[str, int] = {}
    rule_advisory_counts: dict[str, int] = {}
    pass_rules: list[str] = []
    skip_rules: list[str] = []

    for rule_key, rule_data in rules.items():
        if not isinstance(rule_data, dict):
            raise ValueError(f"{json_path}: rule {rule_key!r} is not an object")

        _validate_rule_status(rule_key, rule_data, json_path)

        violations = rule_data.get("violations", [])
        if not isinstance(violations, list):
            raise ValueError(
                f"{json_path}: rule {rule_key!r} has malformed 'violations' (not a list)"
            )

        err_count = 0
        adv_count = 0
        for i, v in enumerate(violations):
            severity = _validate_violation(rule_key, i, v, json_path)
            if severity == "error":
                err_count += 1
            else:
                adv_count += 1

        rule_error_counts[rule_key] = err_count
        rule_advisory_counts[rule_key] = adv_count

        status = rule_data.get("status")
        if status == "pass":
            pass_rules.append(rule_key)
        elif status == "skip":
            skip_rules.append(rule_key)

    computed_errors = sum(rule_error_counts.values())
    computed_advisories = sum(rule_advisory_counts.values())

    if computed_errors != summary_violation_count:
        raise ValueError(
            f"{json_path}: computed error count {computed_errors} does not match "
            f"summary.violation_count {summary_violation_count}"
        )
    if computed_advisories != summary_advisory_count:
        raise ValueError(
            f"{json_path}: computed advisory count {computed_advisories} does not match "
            f"summary.advisory_count {summary_advisory_count}"
        )

    error_rules, advisory_only_rules, zero_rules, pass_rules_out, skip_rules_out = (
        _partition_rules(rules, rule_error_counts, rule_advisory_counts)
    )

    return ParsedSlopReport(
        data=data,
        version=version,
        rules=rules,
        summary=summary,
        summary_violation_count=summary_violation_count,
        summary_advisory_count=summary_advisory_count,
        rule_error_counts=rule_error_counts,
        rule_advisory_counts=rule_advisory_counts,
        error_rules=error_rules,
        advisory_only_rules=advisory_only_rules,
        zero_rules=zero_rules,
        pass_rules=pass_rules_out,
        skip_rules=skip_rules_out,
    )
