"""Compact report formatting for slop_report."""

from slop_report.helpers import oxford_join, render_int
from slop_report.models import ParsedSlopReport


def render_compact(parsed: ParsedSlopReport, json_filename: str) -> str:
    """Render the canonical 3-column compact violations table.

    Output is byte-identical for unchanged inputs: the compact format is the
    same as the legacy ``generate_report()`` output when ``json_filename`` equals
    the original ``json_path.name``.

    Args:
        parsed: A validated ``ParsedSlopReport``.
        json_filename: The filename to use in the H1 header (e.g.
            ``"slop_lint_00.json"``). Should be ``f"{stub}.json"`` — always
            the synthesised stub-based name.

    Returns:
        The complete Markdown content as a string ending with exactly one ``\\n``.

    Examples:
        >>> from pathlib import Path
        >>> p = parse_and_validate(Path(".slop/slop_lint_00.json"))  # doctest: +SKIP
        >>> md = render_compact(p, "slop_lint_00.json")  # doctest: +SKIP
    """
    vc = parsed.summary_violation_count
    ac = parsed.summary_advisory_count

    rows: list[str] = []
    for rule_key in (*parsed.error_rules, *parsed.advisory_only_rules):
        e = parsed.rule_error_counts[rule_key]
        a = parsed.rule_advisory_counts[rule_key]
        rows.append(f"| {rule_key} | {render_int(e)} | {render_int(a)} |")

    sentences: list[str] = []
    if parsed.zero_rules:
        zero_join = oxford_join(parsed.zero_rules)
        sentences.append(f"{zero_join} have 0 violations.")
    if ac > 0:
        adv_join = oxford_join(parsed.advisory_only_rules)
        sentences.append(
            f"The summary `violation_count` ({vc}) counts only "
            f'`severity: "error"` entries; {adv_join} violations are '
            f'`severity: "warning"` and tracked separately as advisories.'
        )

    out_lines: list[str] = [
        f"# {json_filename} \u2014 Violations by Rule",
        "",
        "| Rule | Errors | Advisories |",
        "|---|---|---|",
        *rows,
        f"| **Total** | **{vc}** | **{ac}** |",
    ]

    if sentences:
        out_lines.append("")
        body = "\n".join(sentences)
        note_block = f"(Note: {body})"
        out_lines.extend(note_block.split("\n"))

    return "\n".join(out_lines) + "\n"
