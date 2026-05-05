"""Full per-rule report formatting for slop_report."""

from typing import Any

from slop_report.helpers import oxford_join
from slop_report.models import ParsedSlopReport
from slop_report.scoring import get_rule_scope


def _render_deps_section(violations: list[Any], n: int) -> list[str]:
    """Render the Import Cycles section for the ``deps`` rule.

    Args:
        violations: List of ``deps`` violation objects.
        n: Total error count.

    Returns:
        Lines for the section (heading + one bullet per violation).
    """
    from pathlib import Path

    lines = [f"**Import Cycles (`deps` \u2014 {n} errors)**"]
    for v in violations:
        cycle: list[str] = v.get("metadata", {}).get("cycle", [])
        basenames = [Path(p).name for p in cycle]
        cycle_len = len(basenames)
        if cycle_len == 2:
            lines.append(f"- `{basenames[0]}` \u2194 `{basenames[1]}` (2-node cycle)")
        elif cycle_len >= 3:
            arrow_join = " \u2192 ".join(f"`{b}`" for b in basenames)
            lines.append(f"- {arrow_join} ({cycle_len}-node cycle)")
    return lines


def _render_hotspots_section(
    violations: list[Any], rule_summary: dict[str, Any], n: int
) -> list[str]:
    """Render the Hotspots section.

    The entry with the maximum ``value`` across all violations is marked with
    ``\u26a0 worst``. In the case of ties the first occurrence is marked.

    Args:
        violations: List of ``hotspots`` violation objects.
        rule_summary: Per-rule summary object (supplies ``window_since``).
        n: Total error count for the heading.

    Returns:
        Lines for the section.
    """
    window_since = str(rule_summary.get("window_since", ""))
    lines = [
        f"**Hotspots \u2014 high churn \u00d7 high complexity ({n} errors, {window_since})**"
    ]
    max_value: float | None = max(
        (float(v.get("value", 0)) for v in violations), default=None
    )
    marked = False
    for v in violations:
        f_val = v.get("file", "")
        meta = v.get("metadata", {})
        sum_ccx = meta.get("sum_ccx", 0)
        loc_delta = meta.get("loc_delta", 0)
        value = float(v.get("value", 0))
        bullet = (
            f"- `{f_val}` \u2014 CCX={sum_ccx}, +{loc_delta} LOC, score={value:,.0f}"
        )
        if value == max_value and not marked:
            bullet += " \u26a0 worst"
            marked = True
        lines.append(bullet)
    return lines


def _render_wmc_section(violations: list[Any], n: int) -> list[str]:
    """Render the Weighted Method Complexity section.

    Args:
        violations: List of ``complexity.weighted`` violation objects.
        n: Total error count.

    Returns:
        Lines for the section.
    """
    lines = [f"**Weighted Method Complexity \u2014 WMC ({n} errors)**"]
    for v in violations:
        symbol = v.get("symbol", "")
        value = float(v.get("value", 0))
        threshold = v.get("threshold", 0)
        meta = v.get("metadata", {})
        method_count = meta.get("method_count", 0)
        lines.append(
            f"- `{symbol}` \u2014 WMC={value:.0f}"
            f" ({method_count} methods, threshold {threshold})"
        )
    return lines


def _render_halstead_volume_section(violations: list[Any], n: int) -> list[str]:
    """Render the Halstead Volume section.

    The entry with the maximum ``value`` is marked with ``\u2014 highest in codebase``.
    In the case of ties the first occurrence is marked.

    Args:
        violations: List of ``halstead.volume`` violation objects.
        n: Total error count.

    Returns:
        Lines for the section.
    """
    lines = [f"**Halstead Volume ({n} errors)**"]
    max_value: float | None = max(
        (float(v.get("value", 0)) for v in violations), default=None
    )
    marked = False
    for v in violations:
        symbol = v.get("symbol", "")
        value = float(v.get("value", 0))
        threshold = v.get("threshold", 0)
        bullet = f"- `{symbol}` \u2014 vol={value:,.0f} (threshold {threshold:,})"
        if value == max_value and not marked:
            bullet += " \u2014 highest in codebase"
            marked = True
        lines.append(bullet)
    return lines


def _render_packages_section(violations: list[Any], n: int) -> list[str]:
    """Render the Zone of Pain packages section.

    Unlike other sections, this renders a single summary sub-line rather than
    one bullet per violation.

    Args:
        violations: List of ``packages`` violation objects (all advisory warnings).
        n: Total advisory count.

    Returns:
        Lines for the section (heading + one combined sub-line).
    """
    lines = [f"**Zone of Pain packages ({n} advisory warnings)**"]
    files_join = ", ".join(f"`{v.get('file', '')}`" for v in violations)
    lines.append(f"Low instability + low abstractness: {files_join}")
    return lines


def _render_cyclomatic_section(violations: list[Any], n: int) -> list[str]:
    """Render the Cyclomatic Complexity section.

    Args:
        violations: List of ``complexity.cyclomatic`` violation objects.
        n: Total error count.

    Returns:
        Lines for the section.
    """
    lines = [f"**Cyclomatic Complexity ({n} errors)**"]
    for v in violations:
        symbol = v.get("symbol", "")
        file_ = v.get("file", "")
        line = v.get("line", 0)
        value = v.get("value", 0)
        threshold = v.get("threshold", 0)
        lines.append(
            f"- `{symbol}` (`{file_}`:{line}) \u2014 CCX={value} (threshold {threshold})"
        )
    return lines


def _render_cognitive_section(violations: list[Any], n: int) -> list[str]:
    """Render the Cognitive Complexity section.

    Args:
        violations: List of ``complexity.cognitive`` violation objects.
        n: Total error count.

    Returns:
        Lines for the section.
    """
    lines = [f"**Cognitive Complexity ({n} errors)**"]
    for v in violations:
        symbol = v.get("symbol", "")
        file_ = v.get("file", "")
        line = v.get("line", 0)
        value = v.get("value", 0)
        threshold = v.get("threshold", 0)
        lines.append(
            f"- `{symbol}` (`{file_}`:{line})"
            f" \u2014 cognitive={value} (threshold {threshold})"
        )
    return lines


def _render_halstead_difficulty_section(violations: list[Any], n: int) -> list[str]:
    """Render the Halstead Difficulty section.

    Args:
        violations: List of ``halstead.difficulty`` violation objects.
        n: Total error count.

    Returns:
        Lines for the section.
    """
    lines = [f"**Halstead Difficulty ({n} errors)**"]
    for v in violations:
        symbol = v.get("symbol", "")
        file_ = v.get("file", "")
        line = v.get("line", 0)
        value = float(v.get("value", 0))
        threshold = v.get("threshold", 0)
        lines.append(
            f"- `{symbol}` (`{file_}`:{line})"
            f" \u2014 difficulty={value:.2f} (threshold {threshold})"
        )
    return lines


def _render_npath_section(violations: list[Any], n: int) -> list[str]:
    """Render the NPATH section.

    Args:
        violations: List of ``npath`` violation objects.
        n: Total error count.

    Returns:
        Lines for the section.
    """
    lines = [f"**NPATH ({n} errors)**"]
    for v in violations:
        symbol = v.get("symbol", "")
        file_ = v.get("file", "")
        line = v.get("line", 0)
        value = int(v.get("value", 0))
        threshold = int(v.get("threshold", 0))
        lines.append(
            f"- `{symbol}` (`{file_}`:{line})"
            f" \u2014 NPATH={value:,} (threshold {threshold:,})"
        )
    return lines


def _render_orphans_section(violations: list[Any], n_advisories: int) -> list[str]:
    """Render the Unreferenced Symbols section for the ``orphans`` rule.

    Args:
        violations: List of ``orphans`` violation objects.
        n_advisories: Total advisory (warning) count.

    Returns:
        Lines for the section (heading + one bullet per violation).
    """
    lines = [
        f"**Unreferenced Symbols \u2014 `orphans` ({n_advisories} advisory warnings)**"
    ]
    for v in violations:
        symbol = v.get("symbol")
        file_ = v.get("file", "")
        line = v.get("line")
        value = int(v.get("value", 0))
        confidence = v.get("metadata", {}).get("confidence")

        line_suffix = f":{line}" if line is not None else ""
        confidence_part = f" ({confidence} confidence)" if confidence else ""

        if symbol:
            location = f"(`{file_}`{line_suffix})"
            bullet = f"- `{symbol}` {location} \u2014 {value} references{confidence_part}"
        else:
            bullet = f"- `{file_}`{line_suffix} \u2014 {value} references{confidence_part}"

        lines.append(bullet)
    return lines


def _render_unknown_section(
    rule_key: str,
    violations: list[Any],
    n_errors: int,
    n_advisories: int,
) -> list[str]:
    """Fallback section renderer for unrecognised rule keys.

    Args:
        rule_key: Rule identifier string.
        violations: Violation objects for the rule.
        n_errors: Count of error-severity violations.
        n_advisories: Count of warning-severity violations.

    Returns:
        Lines for the section.
    """
    n = n_errors + n_advisories
    kind = "errors" if n_errors > 0 else "advisory warnings"
    lines = [f"**{rule_key} ({n} {kind})**"]
    for v in violations:
        file_ = v.get("file", "")
        line = v.get("line", "")
        symbol = v.get("symbol", "")
        msg = v.get("message", "")
        if symbol:
            lines.append(f"- `{symbol}` (`{file_}`:{line}) \u2014 {msg}")
        else:
            lines.append(f"- `{file_}` \u2014 {msg}")
    return lines


def _render_rule_section(
    rule_key: str,
    violations: list[Any],
    rule_summary: dict[str, Any],
    n_errors: int,
    n_advisories: int,
) -> list[str]:
    """Dispatch to the appropriate per-rule section renderer.

    Args:
        rule_key: The slop rule identifier.
        violations: Violation objects for the rule.
        rule_summary: Per-rule summary object.
        n_errors: Count of error violations for the rule.
        n_advisories: Count of advisory violations for the rule.

    Returns:
        Lines for the section (heading + bullets/content).
    """
    if rule_key == "deps":
        return _render_deps_section(violations, n_errors)
    if rule_key == "hotspots":
        return _render_hotspots_section(violations, rule_summary, n_errors)
    if rule_key == "complexity.weighted":
        return _render_wmc_section(violations, n_errors)
    if rule_key == "halstead.volume":
        return _render_halstead_volume_section(violations, n_errors)
    if rule_key == "packages":
        return _render_packages_section(violations, n_advisories)
    if rule_key == "complexity.cyclomatic":
        return _render_cyclomatic_section(violations, n_errors)
    if rule_key == "complexity.cognitive":
        return _render_cognitive_section(violations, n_errors)
    if rule_key == "halstead.difficulty":
        return _render_halstead_difficulty_section(violations, n_errors)
    if rule_key == "npath":
        return _render_npath_section(violations, n_errors)
    if rule_key == "orphans":
        return _render_orphans_section(violations, n_advisories)
    return _render_unknown_section(rule_key, violations, n_errors, n_advisories)


def _render_header_block(parsed: ParsedSlopReport, json_filename: str) -> list[str]:
    """Render the report header block.

    Args:
        parsed: Validated report data.
        json_filename: JSON filename for the subtitle.

    Returns:
        Header lines.
    """
    vc = parsed.summary_violation_count
    ac = parsed.summary_advisory_count
    total = vc + ac
    result = str(parsed.summary.get("result", "unknown")).upper()
    rc = int(parsed.summary.get("rules_checked", 0))
    rs = int(parsed.summary.get("rules_skipped", 0))

    lines: list[str] = [
        f"## Slop Lint Report \u2014 `{json_filename}` (v{parsed.version})",
        "",
        f"**Overall: {result} \u2014 {vc} errors, {ac} advisories** ({total} total)",
    ]
    if rs > 0:
        skip_join = ", ".join(f"`{r}`" for r in parsed.skip_rules)
        lines.append(f"{rc} rules checked, {rs} skipped ({skip_join})")
    else:
        lines.append(f"{rc} rules checked")
    lines.append("")
    return lines


def _render_rule_summary(parsed: ParsedSlopReport) -> list[str]:
    """Render the 4-column Rule Summary table.

    Args:
        parsed: Validated report data.

    Returns:
        Table lines.
    """
    lines: list[str] = [
        "### Rule Summary",
        "",
        "| Rule | Status | Violations | Scope |",
        "|---|---|---|---|",
    ]

    for rule_key, rule_data in parsed.rules.items():
        status = str(rule_data.get("status", ""))
        if status == "skip":
            continue
        status_display = status.upper()
        rule_summary = rule_data.get("summary", {})
        scope = get_rule_scope(rule_key, rule_summary)
        err_count = parsed.rule_error_counts[rule_key]
        adv_count = parsed.rule_advisory_counts[rule_key]

        if status == "pass":
            violations_str = "0"
        elif err_count == 0 and adv_count > 0:
            violations_str = f"{adv_count} (warn)"
        else:
            violations_str = str(err_count + adv_count)

        lines.append(
            f"| `{rule_key}` | {status_display} | {violations_str} | {scope} |"
        )

    lines.append("")
    return lines


def _render_actionable_issues(parsed: ParsedSlopReport) -> list[str]:
    """Render the Top Actionable Issues section.

    Args:
        parsed: Validated report data.

    Returns:
        Section lines.
    """
    lines: list[str] = [
        "### Top Actionable Issues",
        "",
    ]

    for rule_key, rule_data in parsed.rules.items():
        err_count = parsed.rule_error_counts[rule_key]
        adv_count = parsed.rule_advisory_counts[rule_key]
        if err_count == 0 and adv_count == 0:
            continue
        violations = rule_data.get("violations", [])
        rule_summary_d: dict[str, Any] = rule_data.get("summary", {})
        section_lines = _render_rule_section(
            rule_key, violations, rule_summary_d, err_count, adv_count
        )
        lines.extend(section_lines)
        lines.append("")

    return lines


def _render_passes(parsed: ParsedSlopReport) -> list[str]:
    """Render the Passes section.

    Args:
        parsed: Validated report data.

    Returns:
        Section lines.
    """
    lines: list[str] = ["### Passes"]
    if parsed.pass_rules:
        pass_scopes = [
            get_rule_scope(rk, parsed.rules[rk].get("summary", {}))
            for rk in parsed.pass_rules
        ]
        rules_joined = oxford_join(parsed.pass_rules)
        unique_scopes = set(pass_scopes)
        if len(unique_scopes) == 1 and next(iter(unique_scopes)):
            scope_str = next(iter(unique_scopes))
            lines.append(f"{rules_joined} \u2014 all clean across {scope_str}.")
        else:
            for rk, sc in zip(parsed.pass_rules, pass_scopes, strict=True):
                if sc:
                    lines.append(f"- `{rk}` \u2014 {sc}")
                else:
                    lines.append(f"- `{rk}`")
    else:
        lines.append("(no passing rules)")

    return lines


def render_full(parsed: ParsedSlopReport, json_filename: str) -> str:
    """Render the full actionable slop lint report.

    Sections emitted:
    - Header block (H2 title, overall result line, scope line)
    - Rule Summary (4-column table, all non-skip rules)
    - Top Actionable Issues (per-rule sections for every rule with \u22651 violation)
    - Passes (Oxford-comma join of passing rules with scope suffix)

    Args:
        parsed: A validated ``ParsedSlopReport``.
        json_filename: The filename to use in the H2 header (e.g.
            ``"slop_lint_00.json"``). Should be ``f"{stub}.json"``.

    Returns:
        The complete Markdown content as a string ending with exactly one ``\\n``.
    """
    lines: list[str] = []
    lines.extend(_render_header_block(parsed, json_filename))
    lines.extend(_render_rule_summary(parsed))
    lines.extend(_render_actionable_issues(parsed))
    lines.extend(_render_passes(parsed))
    return "\n".join(lines) + "\n"
