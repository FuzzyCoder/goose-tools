"""Tests for the quality-lint-report generate_report script.

Covers:
- Doctest helpers (_oxford_join, _render_int, _get_rule_scope)
- parse_and_validate structural errors
- render_compact round-trips against checked-in expected outputs
- render_full round-trips against checked-in expected outputs
- _update_symlink behaviour
- run_slop_lint subprocess error simulation
- orphans rule: scope string, round-trips, config passthrough, cleanup, deep-merge regression
"""

from __future__ import annotations

import json
import subprocess
import tomllib
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest  # noqa: I001
from slop_report.config import (
    deep_merge,
    load_project_slop_config,
    update_symlink,
    write_orphans_config,
)
from slop_report.core.paths import resolve_skill_sh
from slop_report.helpers import oxford_join, render_int
from slop_report.models import ParsedSlopReport
from slop_report.parser import parse_and_validate
from slop_report.render_compact import render_compact
from slop_report.render_full import render_full
from slop_report.runner import main, run_slop_lint
from slop_report.scoring import get_rule_scope

_FIXTURES = Path(__file__).resolve().parent / "fixtures"


# ---------------------------------------------------------------------------
# Helper doctests via unit tests
# ---------------------------------------------------------------------------


class TestOxfordJoin:
    """Tests for oxford_join()."""

    @pytest.mark.unit
    def test_empty_list_returns_empty_string(self) -> None:
        result = oxford_join([])
        assert result == "", f"Expected '', got {result!r}"

    @pytest.mark.unit
    def test_single_item_is_backtick_quoted(self) -> None:
        result = oxford_join(["foo"])
        assert result == "`foo`", f"Expected '`foo`', got {result!r}"

    @pytest.mark.unit
    def test_two_items_joined_with_and(self) -> None:
        result = oxford_join(["foo", "bar"])
        assert result == "`foo` and `bar`", f"Expected '`foo` and `bar`', got {result!r}"

    @pytest.mark.unit
    def test_three_items_oxford_comma(self) -> None:
        result = oxford_join(["foo", "bar", "baz"])
        assert result == "`foo`, `bar`, and `baz`", (
            f"Expected '`foo`, `bar`, and `baz`', got {result!r}"
        )

    @pytest.mark.unit
    def test_four_items_oxford_comma(self) -> None:
        result = oxford_join(["a", "b", "c", "d"])
        assert result == "`a`, `b`, `c`, and `d`", (
            f"Expected '`a`, `b`, `c`, and `d`', got {result!r}"
        )


class TestRenderInt:
    """Tests for render_int()."""

    @pytest.mark.unit
    def test_zero_returns_em_dash(self) -> None:
        result = render_int(0)
        assert result == "\u2014", f"Expected em-dash, got {result!r}"

    @pytest.mark.unit
    def test_nonzero_returns_integer_string(self) -> None:
        result = render_int(42)
        assert result == "42", f"Expected '42', got {result!r}"

    @pytest.mark.unit
    def test_one_returns_string_one(self) -> None:
        result = render_int(1)
        assert result == "1", f"Expected '1', got {result!r}"


class TestGetRuleScope:
    """Tests for get_rule_scope()."""

    @pytest.mark.unit
    def test_cyclomatic_uses_functions_checked(self) -> None:
        scope = get_rule_scope("complexity.cyclomatic", {"functions_checked": 1000})
        assert scope == "1,000 functions", f"Got {scope!r}"

    @pytest.mark.unit
    def test_cognitive_uses_functions_checked(self) -> None:
        scope = get_rule_scope("complexity.cognitive", {"functions_checked": 500})
        assert scope == "500 functions", f"Got {scope!r}"

    @pytest.mark.unit
    def test_weighted_uses_classes_checked(self) -> None:
        scope = get_rule_scope("complexity.weighted", {"classes_checked": 200})
        assert scope == "200 classes", f"Got {scope!r}"

    @pytest.mark.unit
    def test_halstead_volume_uses_functions_checked(self) -> None:
        scope = get_rule_scope("halstead.volume", {"functions_checked": 800})
        assert scope == "800 functions", f"Got {scope!r}"

    @pytest.mark.unit
    def test_halstead_difficulty_uses_functions_checked(self) -> None:
        scope = get_rule_scope("halstead.difficulty", {"functions_checked": 750})
        assert scope == "750 functions", f"Got {scope!r}"

    @pytest.mark.unit
    def test_npath_uses_functions_checked(self) -> None:
        scope = get_rule_scope("npath", {"functions_checked": 600})
        assert scope == "600 functions", f"Got {scope!r}"

    @pytest.mark.unit
    def test_hotspots_uses_files_analyzed_and_window_since(self) -> None:
        scope = get_rule_scope(
            "hotspots", {"files_analyzed": 69, "window_since": "14 days ago"}
        )
        assert scope == "69 files (14 days window)", f"Got {scope!r}"

    @pytest.mark.unit
    def test_hotspots_window_since_without_ago(self) -> None:
        scope = get_rule_scope(
            "hotspots", {"files_analyzed": 10, "window_since": "7 days"}
        )
        assert scope == "10 files (7 days window)", f"Got {scope!r}"

    @pytest.mark.unit
    def test_packages_uses_packages_analyzed(self) -> None:
        scope = get_rule_scope("packages", {"packages_analyzed": 56})
        assert scope == "56 packages", f"Got {scope!r}"

    @pytest.mark.unit
    def test_deps_uses_files_analyzed(self) -> None:
        scope = get_rule_scope("deps", {"files_analyzed": 995})
        assert scope == "995 files (import cycles)", f"Got {scope!r}"

    @pytest.mark.unit
    def test_class_coupling_uses_classes_checked(self) -> None:
        scope = get_rule_scope("class.coupling", {"classes_checked": 1184})
        assert scope == "1,184 classes", f"Got {scope!r}"

    @pytest.mark.unit
    def test_class_inheritance_depth_uses_classes_checked(self) -> None:
        scope = get_rule_scope("class.inheritance.depth", {"classes_checked": 1184})
        assert scope == "1,184 classes", f"Got {scope!r}"

    @pytest.mark.unit
    def test_class_inheritance_children_uses_classes_checked(self) -> None:
        scope = get_rule_scope("class.inheritance.children", {"classes_checked": 1184})
        assert scope == "1,184 classes", f"Got {scope!r}"

    @pytest.mark.unit
    def test_unknown_rule_returns_empty_string(self) -> None:
        scope = get_rule_scope("unknown.rule", {"functions_checked": 100})
        assert scope == "", f"Expected empty string for unknown rule, got {scope!r}"

    @pytest.mark.unit
    def test_orphans_uses_symbols_analyzed(self) -> None:
        """get_rule_scope returns '{symbols_analyzed:,} symbols' for the orphans rule."""
        scope = get_rule_scope("orphans", {"symbols_analyzed": 250})
        assert scope == "250 symbols", f"Got {scope!r}"

    @pytest.mark.unit
    def test_orphans_formats_large_count_with_comma(self) -> None:
        """get_rule_scope formats counts >=1000 with comma separator."""
        scope = get_rule_scope("orphans", {"symbols_analyzed": 2500})
        assert scope == "2,500 symbols", f"Got {scope!r}"


# ---------------------------------------------------------------------------
# parse_and_validate structural errors
# ---------------------------------------------------------------------------


class TestParseAndValidate:
    """Structural validation tests for parse_and_validate()."""

    @pytest.mark.unit
    def test_missing_file_raises(self, tmp_path: Path) -> None:
        with pytest.raises(ValueError, match="does not exist"):
            parse_and_validate(tmp_path / "missing.json")

    @pytest.mark.unit
    def test_wrong_suffix_raises(self, tmp_path: Path) -> None:
        p = tmp_path / "report.txt"
        p.write_text("{}", encoding="utf-8")
        with pytest.raises(ValueError, match=r"\.txt"):
            parse_and_validate(p)

    @pytest.mark.unit
    def test_invalid_json_raises(self, tmp_path: Path) -> None:
        p = tmp_path / "bad.json"
        p.write_text("not json{{{", encoding="utf-8")
        with pytest.raises(ValueError, match="failed to parse JSON"):
            parse_and_validate(p)

    @pytest.mark.unit
    def test_missing_rules_raises(self, tmp_path: Path) -> None:
        p = tmp_path / "no_rules.json"
        p.write_text(
            json.dumps({"summary": {"violation_count": 0, "advisory_count": 0}}),
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="'rules' object"):
            parse_and_validate(p)

    @pytest.mark.unit
    def test_missing_advisory_count_raises(self, tmp_path: Path) -> None:
        p = tmp_path / "no_advisory.json"
        p.write_text(
            json.dumps(
                {
                    "rules": {},
                    "summary": {"violation_count": 0},
                }
            ),
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="advisory_count"):
            parse_and_validate(p)

    @pytest.mark.unit
    def test_unsupported_status_raises(self, tmp_path: Path) -> None:
        p = tmp_path / "bad_status.json"
        p.write_text(
            json.dumps(
                {
                    "rules": {
                        "myrule": {
                            "status": "broken",
                            "violations": [],
                            "summary": {},
                        }
                    },
                    "summary": {"violation_count": 0, "advisory_count": 0},
                }
            ),
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="unsupported status"):
            parse_and_validate(p)

    @pytest.mark.unit
    def test_count_mismatch_raises(self, tmp_path: Path) -> None:
        p = tmp_path / "mismatch.json"
        p.write_text(
            json.dumps(
                {
                    "rules": {
                        "myrule": {
                            "status": "fail",
                            "violations": [],
                            "summary": {},
                        }
                    },
                    "summary": {"violation_count": 5, "advisory_count": 0},
                }
            ),
            encoding="utf-8",
        )
        with pytest.raises(ValueError, match="does not match summary.violation_count"):
            parse_and_validate(p)


# ---------------------------------------------------------------------------
# Compact renderer round-trip tests
# ---------------------------------------------------------------------------


class TestRenderCompact:
    """Byte-identical round-trip tests for render_compact()."""

    @pytest.mark.unit
    def test_rich_compact_matches_expected(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        expected = (_FIXTURES / "rich" / "expected_compact.md").read_text(encoding="utf-8")
        parsed = parse_and_validate(json_path)
        result = render_compact(parsed, "rich.json")
        if len(result) == len(expected):
            first_diff = next(
                (i for i, (a, b) in enumerate(zip(result, expected, strict=True)) if a != b),
                -1,
            )
            assert result == expected, (
                f"compact render for 'rich' does not match expected output\n"
                f"first diff at char {first_diff}"
            )
        else:
            assert result == expected, (
                f"length mismatch: got {len(result)}, expected {len(expected)}"
            )

    @pytest.mark.unit
    def test_minimal_pass_compact_matches_expected(self) -> None:
        json_path = _FIXTURES / "minimal_pass" / "input.json"
        expected = (_FIXTURES / "minimal_pass" / "expected_compact.md").read_text(
            encoding="utf-8"
        )
        parsed = parse_and_validate(json_path)
        result = render_compact(parsed, "minimal_pass.json")
        assert result == expected, (
            f"compact render for 'minimal_pass' does not match expected output\n"
            f"got:\n{result!r}\nexpected:\n{expected!r}"
        )

    @pytest.mark.unit
    def test_with_skips_compact_matches_expected(self) -> None:
        json_path = _FIXTURES / "with_skips" / "input.json"
        expected = (_FIXTURES / "with_skips" / "expected_compact.md").read_text(
            encoding="utf-8"
        )
        parsed = parse_and_validate(json_path)
        result = render_compact(parsed, "with_skips.json")
        assert result == expected, (
            f"compact render for 'with_skips' does not match expected output\n"
            f"got:\n{result!r}\nexpected:\n{expected!r}"
        )

    @pytest.mark.unit
    def test_compact_ends_with_single_newline(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_compact(parsed, "rich.json")
        assert result.endswith("\n"), f"Expected trailing newline, got {result[-5:]!r}"
        assert not result.endswith("\n\n"), "Expected exactly one trailing newline"

    @pytest.mark.unit
    def test_orphans_enabled_compact_matches_expected(self) -> None:
        """Compact round-trip for orphans_enabled fixture."""
        json_path = _FIXTURES / "orphans_enabled" / "input.json"
        expected = (_FIXTURES / "orphans_enabled" / "expected_compact.md").read_text(
            encoding="utf-8"
        )
        parsed = parse_and_validate(json_path)
        result = render_compact(parsed, "orphans_enabled.json")
        assert result == expected, (
            f"compact render for 'orphans_enabled' does not match expected output\n"
            f"got:\n{result!r}\nexpected:\n{expected!r}"
        )


# ---------------------------------------------------------------------------
# Full renderer round-trip tests
# ---------------------------------------------------------------------------


class TestRenderFull:
    """Byte-identical round-trip tests for render_full()."""

    @pytest.mark.unit
    def test_rich_full_matches_expected(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        expected = (_FIXTURES / "rich" / "expected_full.md").read_text(encoding="utf-8")
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert result == expected, (
            f"full render for 'rich' does not match expected output\n"
            f"got length={len(result)}, expected length={len(expected)}"
        )

    @pytest.mark.unit
    def test_minimal_pass_full_matches_expected(self) -> None:
        json_path = _FIXTURES / "minimal_pass" / "input.json"
        expected = (_FIXTURES / "minimal_pass" / "expected_full.md").read_text(
            encoding="utf-8"
        )
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "minimal_pass.json")
        assert result == expected, (
            f"full render for 'minimal_pass' does not match expected output\n"
            f"got:\n{result!r}\nexpected:\n{expected!r}"
        )

    @pytest.mark.unit
    def test_with_skips_full_matches_expected(self) -> None:
        json_path = _FIXTURES / "with_skips" / "input.json"
        expected = (_FIXTURES / "with_skips" / "expected_full.md").read_text(
            encoding="utf-8"
        )
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "with_skips.json")
        assert result == expected, (
            f"full render for 'with_skips' does not match expected output\n"
            f"got:\n{result!r}\nexpected:\n{expected!r}"
        )

    @pytest.mark.unit
    def test_full_ends_with_single_newline(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert result.endswith("\n"), f"Expected trailing newline, got {result[-5:]!r}"
        assert not result.endswith("\n\n"), "Expected exactly one trailing newline"

    @pytest.mark.unit
    def test_orphans_enabled_full_matches_expected(self) -> None:
        """Full round-trip for orphans_enabled fixture."""
        json_path = _FIXTURES / "orphans_enabled" / "input.json"
        expected = (_FIXTURES / "orphans_enabled" / "expected_full.md").read_text(
            encoding="utf-8"
        )
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "orphans_enabled.json")
        assert result == expected, (
            f"full render for 'orphans_enabled' does not match expected output\n"
            f"got length={len(result)}, expected length={len(expected)}\n"
            f"got:\n{result!r}\nexpected:\n{expected!r}"
        )

    @pytest.mark.unit
    def test_render_full_orphans_pass_does_not_perturb_top_actionable_issues(
        self,
    ) -> None:
        """Adding orphans:pass with 0 violations does not change Top Actionable Issues."""
        cyclomatic_violation = {
            "rule": "complexity.cyclomatic",
            "file": "src/x.py",
            "line": 10,
            "symbol": "do_work",
            "message": "CCX 12",
            "severity": "error",
            "value": 12,
            "threshold": 10,
            "metadata": {},
        }
        base_rules: dict = {
            "complexity.cyclomatic": {
                "status": "fail",
                "violations": [cyclomatic_violation],
                "summary": {"functions_checked": 50, "violation_count": 1},
                "errors": [],
            }
        }
        base_summary: dict = {
            "rules_checked": 1,
            "rules_skipped": 0,
            "violation_count": 1,
            "advisory_count": 0,
            "result": "fail",
        }

        parsed_a = ParsedSlopReport(
            data={},
            version="0.6.1",
            rules=dict(base_rules),
            summary=dict(base_summary),
            summary_violation_count=1,
            summary_advisory_count=0,
            rule_error_counts={"complexity.cyclomatic": 1},
            rule_advisory_counts={"complexity.cyclomatic": 0},
            error_rules=["complexity.cyclomatic"],
            advisory_only_rules=[],
            zero_rules=[],
            pass_rules=[],
            skip_rules=[],
        )

        rules_with_orphans = {
            **base_rules,
            "orphans": {
                "status": "pass",
                "violations": [],
                "summary": {"symbols_analyzed": 100},
                "errors": [],
            },
        }
        parsed_b = ParsedSlopReport(
            data={},
            version="0.6.1",
            rules=rules_with_orphans,
            summary={**base_summary, "rules_checked": 2},
            summary_violation_count=1,
            summary_advisory_count=0,
            rule_error_counts={"complexity.cyclomatic": 1, "orphans": 0},
            rule_advisory_counts={"complexity.cyclomatic": 0, "orphans": 0},
            error_rules=["complexity.cyclomatic"],
            advisory_only_rules=[],
            zero_rules=["orphans"],
            pass_rules=["orphans"],
            skip_rules=[],
        )

        result_a = render_full(parsed_a, "test_a.json")
        result_b = render_full(parsed_b, "test_b.json")

        # Extract Top Actionable Issues sections (between the heading and ### Passes)
        tai_a = result_a.split("### Top Actionable Issues")[1].split("### Passes")[0]
        tai_b = result_b.split("### Top Actionable Issues")[1].split("### Passes")[0]
        assert tai_a == tai_b, (
            f"Top Actionable Issues must be unchanged when orphans has no violations.\n"
            f"Without orphans:\n{tai_a!r}\nWith orphans pass:\n{tai_b!r}"
        )

    @pytest.mark.unit
    def test_full_report_skip_rules_excluded_from_table(self) -> None:
        json_path = _FIXTURES / "with_skips" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "with_skips.json")
        assert "`orphans`" not in result.split("### Rule Summary")[1].split("### Top")[0], (
            "Skip rule 'orphans' must not appear in the Rule Summary table"
        )

    @pytest.mark.unit
    def test_full_report_packages_shows_warn_in_table(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert "2 (warn)" in result, (
            "packages advisory-only violations must show '2 (warn)' in Rule Summary"
        )

    @pytest.mark.unit
    def test_full_report_hotspots_worst_marker(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert "\u26a0 worst" in result, (
            "Hotspot with maximum score must be marked with ⚠ worst"
        )

    @pytest.mark.unit
    def test_full_report_halstead_volume_highest_marker(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert "highest in codebase" in result, (
            "Halstead volume entry with maximum value must be marked 'highest in codebase'"
        )

    @pytest.mark.unit
    def test_full_report_deps_two_node_uses_bidirectional_arrow(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert "\u2194" in result, (
            "2-node deps cycle must use ↔ arrow"
        )

    @pytest.mark.unit
    def test_full_report_deps_three_node_uses_right_arrow(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert "3-node cycle" in result, (
            "3-node deps cycle must show '3-node cycle' in label"
        )

    @pytest.mark.unit
    def test_full_report_passes_shared_scope_suffix(self) -> None:
        json_path = _FIXTURES / "rich" / "input.json"
        parsed = parse_and_validate(json_path)
        result = render_full(parsed, "rich.json")
        assert "all clean across 50 classes." in result, (
            "Passes section must use 'all clean across {scope}' when all pass rules share scope"
        )

    @pytest.mark.unit
    def test_full_report_no_passing_rules_shows_none_message(self) -> None:
        """A report with no passing rules shows '(no passing rules)'."""
        minimal_data = {
            "version": "0.1.0",
            "rules": {
                "complexity.cyclomatic": {
                    "status": "fail",
                    "violations": [
                        {
                            "rule": "complexity.cyclomatic",
                            "file": "x.py",
                            "line": 1,
                            "symbol": "f",
                            "message": "CCX 11",
                            "severity": "error",
                            "value": 11,
                            "threshold": 10,
                            "metadata": {},
                        }
                    ],
                    "summary": {"functions_checked": 10, "violation_count": 1},
                    "errors": [],
                }
            },
            "summary": {
                "rules_checked": 1,
                "rules_skipped": 0,
                "violation_count": 1,
                "advisory_count": 0,
                "result": "fail",
            },
        }
        # Build ParsedSlopReport directly without needing a file
        parsed = ParsedSlopReport(
            data=minimal_data,
            version="0.1.0",
            rules=minimal_data["rules"],
            summary=minimal_data["summary"],
            summary_violation_count=1,
            summary_advisory_count=0,
            rule_error_counts={"complexity.cyclomatic": 1},
            rule_advisory_counts={"complexity.cyclomatic": 0},
            error_rules=["complexity.cyclomatic"],
            advisory_only_rules=[],
            zero_rules=[],
            pass_rules=[],
            skip_rules=[],
        )
        result = render_full(parsed, "no_pass.json")
        assert "(no passing rules)" in result, (
            f"Expected '(no passing rules)' when pass_rules is empty, got:\n{result}"
        )


# ---------------------------------------------------------------------------
# _update_symlink
# ---------------------------------------------------------------------------


class TestUpdateSymlink:
    """Tests for update_symlink()."""

    @pytest.mark.unit
    def test_creates_symlink_when_target_absent(self, tmp_path: Path) -> None:
        """Creates a relative symlink when link_path does not yet exist."""
        target_file = tmp_path / "slop_lint_20260430_120000.json"
        target_file.write_text("{}", encoding="utf-8")
        link_path = tmp_path / "slop_lint.json"

        update_symlink(link_path, "slop_lint_20260430_120000.json")

        assert link_path.is_symlink(), f"Expected symlink at {link_path}"
        assert link_path.resolve() == target_file.resolve(), (
            f"Symlink target mismatch: {link_path.resolve()} != {target_file.resolve()}"
        )

    @pytest.mark.unit
    def test_replaces_existing_symlink(self, tmp_path: Path) -> None:
        """Updates an existing symlink to point to a new target."""
        old_target = tmp_path / "slop_lint_20260430_110000.json"
        old_target.write_text("{}", encoding="utf-8")
        new_target = tmp_path / "slop_lint_20260430_120000.json"
        new_target.write_text("{}", encoding="utf-8")
        link_path = tmp_path / "slop_lint.json"
        link_path.symlink_to("slop_lint_20260430_110000.json")

        update_symlink(link_path, "slop_lint_20260430_120000.json")

        assert link_path.is_symlink(), f"Expected symlink at {link_path}"
        assert link_path.resolve() == new_target.resolve(), (
            f"Expected symlink to point to new target, got {link_path.resolve()}"
        )

    @pytest.mark.unit
    def test_replaces_existing_regular_file(self, tmp_path: Path) -> None:
        """Replaces a regular file (e.g. pre-symlink legacy file) with a symlink."""
        target_file = tmp_path / "slop_lint_20260430_120000.json"
        target_file.write_text("{}", encoding="utf-8")
        # Pre-existing regular file at the link path (simulates first run after migration)
        link_path = tmp_path / "slop_lint.json"
        link_path.write_text("old content", encoding="utf-8")
        assert not link_path.is_symlink(), "Pre-condition: should be a regular file"

        update_symlink(link_path, "slop_lint_20260430_120000.json")

        assert link_path.is_symlink(), f"Expected symlink at {link_path}, got regular file"
        assert link_path.resolve() == target_file.resolve(), (
            f"Symlink target mismatch: {link_path.resolve()} != {target_file.resolve()}"
        )

    @pytest.mark.unit
    def test_replaces_broken_symlink(self, tmp_path: Path) -> None:
        """Replaces a broken (dangling) symlink with a valid one."""
        target_file = tmp_path / "slop_lint_20260430_120000.json"
        target_file.write_text("{}", encoding="utf-8")
        link_path = tmp_path / "slop_lint.json"
        # Create a broken symlink pointing to a non-existent file
        link_path.symlink_to("slop_lint_19990101_000000.json")
        assert link_path.is_symlink(), "Pre-condition: is a symlink"
        assert not link_path.exists(), "Pre-condition: symlink target does not exist (broken)"

        update_symlink(link_path, "slop_lint_20260430_120000.json")

        assert link_path.is_symlink(), f"Expected symlink at {link_path}"
        assert link_path.exists(), "New symlink should not be broken"
        assert link_path.resolve() == target_file.resolve(), (
            f"Symlink target mismatch: {link_path.resolve()} != {target_file.resolve()}"
        )


# ---------------------------------------------------------------------------
# run_slop_lint subprocess error simulation
# ---------------------------------------------------------------------------


class TestRunSlopLint:
    """Tests for run_slop_lint() failure modes via subprocess mocking."""

    _TS = "20260430_000000"

    # Helper: returns a fake Path.exists that makes skill.sh appear absent.
    @staticmethod
    def _exists_no_skill(path_self: Path) -> bool:
        """Fake Path.exists — returns False for paths ending with 'skill.sh'."""
        if "skill.sh" in path_self.name:
            return False
        import os
        return os.path.exists(path_self)

    # Helper: returns a fake Path.exists that makes skill.sh appear present.
    @staticmethod
    def _exists_with_skill(path_self: Path) -> bool:
        """Fake Path.exists — returns True for skill.sh, real check otherwise."""
        if "skill.sh" in path_self.name:
            return True
        import os
        return os.path.exists(path_self)

    @pytest.mark.unit
    def test_missing_skill_sh_raises(self, tmp_path: Path) -> None:
        """ValueError raised when skill.sh is not found."""
        with patch.object(Path, "exists", TestRunSlopLint._exists_no_skill):
            with pytest.raises(ValueError, match="slop runner script not found"):
                run_slop_lint(tmp_path, self._TS)

    @pytest.mark.unit
    def test_nonzero_exit_raises_with_exit_code(self, tmp_path: Path) -> None:
        """ValueError with exit code when skill.sh exits non-zero."""
        mock_result = MagicMock(spec=subprocess.CompletedProcess)
        mock_result.returncode = 1
        mock_result.stderr = "slop configuration error"
        mock_result.stdout = ""

        with (
            patch.object(Path, "exists", TestRunSlopLint._exists_with_skill),
            patch("slop_report.runner.subprocess.run", return_value=mock_result),
        ):
            with pytest.raises(ValueError, match=r"slop runner failed \(exit 1\)"):
                run_slop_lint(tmp_path, self._TS)

    @pytest.mark.unit
    def test_non_json_stdout_raises(self, tmp_path: Path) -> None:
        """ValueError when runner stdout is not valid JSON."""
        mock_result = MagicMock(spec=subprocess.CompletedProcess)
        mock_result.returncode = 0
        mock_result.stderr = ""
        mock_result.stdout = "this is not json {{{"

        with (
            patch.object(Path, "exists", TestRunSlopLint._exists_with_skill),
            patch("slop_report.runner.subprocess.run", return_value=mock_result),
        ):
            with pytest.raises(ValueError, match="non-JSON output"):
                run_slop_lint(tmp_path, self._TS)

    @pytest.mark.unit
    def test_slop_dir_created_and_json_named_correctly(self, tmp_path: Path) -> None:
        """run_slop_lint creates .slop/ and writes slop_lint_{timestamp}.json."""
        root = tmp_path / "project"
        root.mkdir()
        slop_dir = root / ".slop"

        valid_json = json.dumps(
            {
                "version": "0.7.0",
                "rules": {},
                "summary": {
                    "rules_checked": 0,
                    "rules_skipped": 0,
                    "violation_count": 0,
                    "advisory_count": 0,
                    "result": "pass",
                },
            }
        )
        mock_result = MagicMock(spec=subprocess.CompletedProcess)
        mock_result.returncode = 0
        mock_result.stderr = ""
        mock_result.stdout = valid_json

        with (
            patch.object(Path, "exists", TestRunSlopLint._exists_with_skill),
            patch("slop_report.runner.subprocess.run", return_value=mock_result),
        ):
            returned_path = run_slop_lint(root, self._TS)

        expected = slop_dir / f"slop_lint_{self._TS}" / f"slop_lint_{self._TS}.json"
        assert slop_dir.exists(), f"Expected .slop/ to be created at {slop_dir}"
        assert returned_path == expected, (
            f"Expected returned path {expected}, got {returned_path}"
        )
        assert returned_path.exists(), "Expected JSON file to be written"


# ---------------------------------------------------------------------------
# main() — per-run subdirectory layout and orphan cleanup
# ---------------------------------------------------------------------------


_VALID_SLOP_JSON = json.dumps(
    {
        "version": "0.7.0",
        "rules": {},
        "summary": {
            "rules_checked": 0,
            "rules_skipped": 0,
            "violation_count": 0,
            "advisory_count": 0,
            "result": "pass",
        },
    }
)


class TestMain:
    """Tests for main() — per-run subdirectory layout and orphaned flat-file cleanup."""

    _TS = "20260430_000000"

    @staticmethod
    def _exists_with_skill(path_self: Path) -> bool:
        """Fake Path.exists — returns True for skill.sh, real check otherwise."""
        if "skill.sh" in path_self.name:
            return True
        import os

        return os.path.exists(path_self)

    @pytest.mark.unit
    def test_main_writes_subdirectory_and_resolves_symlinks(self, tmp_path: Path) -> None:
        """main() creates slop_lint_{ts}/ subdirectory with all three artifacts and updates root
        symlinks.
        """
        root = tmp_path / "project"
        root.mkdir()
        slop_dir = root / ".slop"

        mock_result = MagicMock(spec=subprocess.CompletedProcess)
        mock_result.returncode = 0
        mock_result.stderr = ""
        mock_result.stdout = _VALID_SLOP_JSON

        with (
            patch.object(Path, "exists", TestMain._exists_with_skill),
            patch("slop_report.runner.subprocess.run", return_value=mock_result),
            patch("slop_report.runner.datetime") as mock_dt,
            patch("sys.argv", ["generate_report", "--root", str(root)]),
        ):
            mock_dt.now.return_value.strftime.return_value = self._TS
            main()

        run_dir = slop_dir / f"slop_lint_{self._TS}"
        assert run_dir.is_dir(), f"Expected run subdirectory to exist at {run_dir}"

        json_file = run_dir / f"slop_lint_{self._TS}.json"
        assert json_file.exists(), f"Expected JSON artifact at {json_file}"

        compact_file = run_dir / f"slop_lint_{self._TS}.md"
        assert compact_file.exists(), f"Expected compact MD artifact at {compact_file}"

        full_file = run_dir / f"slop_lint_full_{self._TS}.md"
        assert full_file.exists(), f"Expected full MD artifact at {full_file}"

        json_link = slop_dir / "slop_lint.json"
        md_link = slop_dir / "slop_lint.md"
        full_link = slop_dir / "slop_lint_full.md"

        assert json_link.is_symlink(), f"Expected {json_link} to be a symlink"
        assert json_link.resolve() == json_file.resolve(), (
            f"Expected slop_lint.json → {json_file}, got {json_link.resolve()}"
        )
        assert md_link.is_symlink(), f"Expected {md_link} to be a symlink"
        assert md_link.resolve() == compact_file.resolve(), (
            f"Expected slop_lint.md → {compact_file}, got {md_link.resolve()}"
        )
        assert full_link.is_symlink(), f"Expected {full_link} to be a symlink"
        assert full_link.resolve() == full_file.resolve(), (
            f"Expected slop_lint_full.md → {full_file}, got {full_link.resolve()}"
        )

    @pytest.mark.unit
    def test_main_removes_orphaned_flat_layout_files(self, tmp_path: Path) -> None:
        """main() deletes stale flat-layout files but preserves symlinks and unrelated files."""
        root = tmp_path / "project"
        root.mkdir()
        slop_dir = root / ".slop"
        slop_dir.mkdir()

        # Pre-populate orphaned flat-layout artifacts from a previous run.
        old_ts = "20260429_120000"
        old_json = slop_dir / f"slop_lint_{old_ts}.json"
        old_md = slop_dir / f"slop_lint_{old_ts}.md"
        old_full = slop_dir / f"slop_lint_full_{old_ts}.md"
        old_json.write_text("{}", encoding="utf-8")
        old_md.write_text("# old compact", encoding="utf-8")
        old_full.write_text("# old full", encoding="utf-8")

        # Stable symlinks pointing at the now-orphaned flat files.
        (slop_dir / "slop_lint.json").symlink_to(f"slop_lint_{old_ts}.json")
        (slop_dir / "slop_lint.md").symlink_to(f"slop_lint_{old_ts}.md")
        (slop_dir / "slop_lint_full.md").symlink_to(f"slop_lint_full_{old_ts}.md")

        # An unrelated file that must survive the cleanup.
        sentinel = slop_dir / "keep.txt"
        sentinel.write_text("preserved", encoding="utf-8")

        mock_result = MagicMock(spec=subprocess.CompletedProcess)
        mock_result.returncode = 0
        mock_result.stderr = ""
        mock_result.stdout = _VALID_SLOP_JSON

        with (
            patch.object(Path, "exists", TestMain._exists_with_skill),
            patch("slop_report.runner.subprocess.run", return_value=mock_result),
            patch("slop_report.runner.datetime") as mock_dt,
            patch("sys.argv", ["generate_report", "--root", str(root)]),
        ):
            mock_dt.now.return_value.strftime.return_value = self._TS
            main()

        # Orphaned flat regular files must be deleted.
        assert not old_json.exists(), f"Expected orphaned {old_json.name} to be deleted"
        assert not old_md.exists(), f"Expected orphaned {old_md.name} to be deleted"
        assert not old_full.exists(), f"Expected orphaned {old_full.name} to be deleted"

        # Stable symlinks survive and now resolve into the new run subdirectory.
        json_link = slop_dir / "slop_lint.json"
        md_link = slop_dir / "slop_lint.md"
        full_link = slop_dir / "slop_lint_full.md"
        assert json_link.is_symlink(), f"Expected {json_link.name} to remain a symlink"
        assert md_link.is_symlink(), f"Expected {md_link.name} to remain a symlink"
        assert full_link.is_symlink(), f"Expected {full_link.name} to remain a symlink"

        run_dir = slop_dir / f"slop_lint_{self._TS}"
        assert json_link.resolve() == (run_dir / f"slop_lint_{self._TS}.json").resolve(), (
            f"Expected slop_lint.json to resolve into new run_dir, got {json_link.resolve()}"
        )
        assert md_link.resolve() == (run_dir / f"slop_lint_{self._TS}.md").resolve(), (
            f"Expected slop_lint.md to resolve into new run_dir, got {md_link.resolve()}"
        )
        assert full_link.resolve() == (run_dir / f"slop_lint_full_{self._TS}.md").resolve(), (
            f"Expected slop_lint_full.md to resolve into new run_dir, got {full_link.resolve()}"
        )

        # Unrelated file must be untouched.
        assert sentinel.exists(), f"Expected sentinel {sentinel.name} to be preserved"
        assert sentinel.read_text(encoding="utf-8") == "preserved", (
            f"Expected sentinel content 'preserved', got {sentinel.read_text(encoding='utf-8')!r}"
        )

    @pytest.mark.unit
    def test_main_orphans_flag_forwarded_to_run_slop_lint(self, tmp_path: Path) -> None:
        """main() passes orphans=True to run_slop_lint when --orphans is set."""
        root = tmp_path / "project"
        root.mkdir()

        with (
            patch("slop_report.runner.run_slop_lint") as mock_rsl,
            patch("slop_report.runner.parse_and_validate") as mock_pav,
            patch("slop_report.runner.render_compact", return_value="compact\n"),
            patch("slop_report.runner.render_full", return_value="full\n"),
            patch("slop_report.runner.datetime") as mock_dt,
            patch("sys.argv", ["generate_report", "--root", str(root), "--orphans"]),
        ):
            mock_dt.now.return_value.strftime.return_value = self._TS
            # mock run_slop_lint to return a valid path in .slop/
            slop_dir = root / ".slop"
            slop_dir.mkdir()
            run_dir = slop_dir / f"slop_lint_{self._TS}"
            run_dir.mkdir()
            fake_json = run_dir / f"slop_lint_{self._TS}.json"
            fake_json.write_text("{}", encoding="utf-8")
            mock_rsl.return_value = fake_json
            mock_pav.return_value = MagicMock()
            main()

        mock_rsl.assert_called_once()
        _, kwargs = mock_rsl.call_args
        assert kwargs.get("orphans") is True, (
            f"Expected orphans=True forwarded to run_slop_lint, got kwargs={kwargs!r}"
        )


# ---------------------------------------------------------------------------
# run_slop_lint orphans=True — config passthrough and cleanup
# ---------------------------------------------------------------------------


_VALID_ORPHANS_JSON = json.dumps(
    {
        "version": "0.6.1",
        "rules": {
            "orphans": {
                "status": "pass",
                "violations": [],
                "summary": {"symbols_analyzed": 10, "violation_count": 0},
                "errors": [],
            }
        },
        "summary": {
            "rules_checked": 1,
            "rules_skipped": 0,
            "violation_count": 0,
            "advisory_count": 0,
            "result": "pass",
        },
    }
)


class TestRunSlopLintOrphans:
    """Tests for run_slop_lint(orphans=True) config passthrough, cleanup, and error paths."""

    _TS = "20260430_000000"

    @staticmethod
    def _exists_with_skill(path_self: Path) -> bool:
        """Fake Path.exists — returns True for skill.sh, real check otherwise."""
        if "skill.sh" in path_self.name:
            return True
        import os

        return os.path.exists(path_self)

    @pytest.mark.unit
    def test_orphans_true_passes_config_flag_and_cleans_up(
        self, tmp_path: Path
    ) -> None:
        """run_slop_lint passes --config to subprocess and deletes temp file after."""
        root = tmp_path / "project"
        root.mkdir()

        captured: dict = {}

        def mock_subprocess(cmd: list, **kwargs):  # type: ignore[override]
            if "--config" in cmd:
                idx = cmd.index("--config") + 1
                config_path = cmd[idx]
                with open(config_path, "rb") as fh:
                    captured["config"] = tomllib.load(fh)
                captured["path"] = config_path
            return MagicMock(returncode=0, stdout=_VALID_ORPHANS_JSON, stderr="")

        with (
            patch.object(Path, "exists", TestRunSlopLintOrphans._exists_with_skill),
            patch("slop_report.runner.subprocess.run", side_effect=mock_subprocess),
        ):
            run_slop_lint(root, self._TS, orphans=True)

        assert "path" in captured, (
            "Expected --config to be passed to subprocess when orphans=True"
        )
        assert captured["path"].endswith(".toml"), (
            f"Expected config path to end with .toml, got {captured['path']!r}"
        )
        assert not Path(captured["path"]).exists(), (
            f"Expected temp config {captured['path']!r} to be deleted after run_slop_lint"
        )
        assert captured["config"]["rules"]["orphans"]["enabled"] is True, (
            "Expected orphans.enabled=True in the generated temp config"
        )

    @pytest.mark.unit
    def test_orphans_cleanup_on_subprocess_exception(self, tmp_path: Path) -> None:
        """Temp config file is deleted even when subprocess raises an exception."""
        root = tmp_path / "project"
        root.mkdir()

        captured_path: dict = {}

        def raise_subprocess(cmd: list, **kwargs):  # type: ignore[override]
            if "--config" in cmd:
                captured_path["path"] = cmd[cmd.index("--config") + 1]
            raise RuntimeError("subprocess exploded")

        with (
            patch.object(Path, "exists", TestRunSlopLintOrphans._exists_with_skill),
            patch("slop_report.runner.subprocess.run", side_effect=raise_subprocess),
        ):
            with pytest.raises(RuntimeError, match="subprocess exploded"):
                run_slop_lint(root, self._TS, orphans=True)

        if "path" in captured_path:
            assert not Path(captured_path["path"]).exists(), (
                f"Expected temp config {captured_path['path']!r} to be cleaned up after exception"
            )

    @pytest.mark.unit
    def test_orphans_missing_from_output_raises_value_error(
        self, tmp_path: Path
    ) -> None:
        """ValueError raised when orphans rule is absent from slop output with orphans=True."""
        root = tmp_path / "project"
        root.mkdir()

        no_orphans_json = json.dumps(
            {
                "version": "0.6.1",
                "rules": {},
                "summary": {
                    "rules_checked": 0,
                    "rules_skipped": 0,
                    "violation_count": 0,
                    "advisory_count": 0,
                    "result": "pass",
                },
            }
        )

        with (
            patch.object(Path, "exists", TestRunSlopLintOrphans._exists_with_skill),
                patch(
                "slop_report.runner.subprocess.run",
                return_value=MagicMock(returncode=0, stdout=no_orphans_json, stderr=""),
            ),
        ):
            with pytest.raises(ValueError, match="orphans rule missing"):
                run_slop_lint(root, self._TS, orphans=True)


# ---------------------------------------------------------------------------
# _deep_merge and _write_orphans_config — deep-merge regression
# ---------------------------------------------------------------------------


class TestDeepMergeAndOrphansConfig:
    """Tests for deep_merge() and write_orphans_config() deep-merge correctness."""

    @pytest.mark.unit
    def test_deep_merge_nested_dicts_merged(self) -> None:
        """Nested dict values are recursively merged, not wholesale replaced."""
        base = {"a": {"x": 1, "y": 2}, "b": 3}
        override = {"a": {"y": 99, "z": 100}}
        result = deep_merge(base, override)
        assert result == {"a": {"x": 1, "y": 99, "z": 100}, "b": 3}, (
            f"Deep merge result mismatch: {result!r}"
        )

    @pytest.mark.unit
    def test_deep_merge_scalar_override_wins(self) -> None:
        """Scalar override value replaces base value."""
        result = deep_merge({"a": 1}, {"a": 2})
        assert result["a"] == 2, f"Expected override value 2, got {result['a']!r}"

    @pytest.mark.unit
    def test_deep_merge_does_not_mutate_originals(self) -> None:
        """Original base and override dicts are not modified."""
        base = {"rules": {"orphans": {"enabled": False}}}
        override = {"rules": {"orphans": {"enabled": True}}}
        _ = deep_merge(base, override)
        assert base["rules"]["orphans"]["enabled"] is False, (
            "deep_merge must not mutate the base dict"
        )

    @pytest.mark.unit
    def test_write_orphans_config_preserves_project_settings(
        self, tmp_path: Path
    ) -> None:
        """write_orphans_config preserves exclude and custom thresholds from .slop.toml."""
        project_root = tmp_path / "project"
        project_root.mkdir()
        slop_toml = project_root / ".slop.toml"
        slop_toml.write_text(
            'exclude = ["foo/**"]\n'
            "[rules.complexity]\n"
            "cyclomatic_threshold = 7\n\n"
            "[rules.orphans]\n"
            "enabled = false\n",
            encoding="utf-8",
        )

        tmp_config = write_orphans_config(project_root)
        try:
            with open(tmp_config, "rb") as fh:
                config = tomllib.load(fh)
        finally:
            try:
                tmp_config.unlink()
            except FileNotFoundError:
                pass

        assert config.get("exclude") == ["foo/**"], (
            f"Expected exclude=['foo/**'] preserved, got {config.get('exclude')!r}"
        )
        assert config.get("rules", {}).get("complexity", {}).get("cyclomatic_threshold") == 7, (
            "Expected cyclomatic_threshold=7 preserved from project .slop.toml"
        )
        assert config["rules"]["orphans"]["enabled"] is True, (
            "Expected orphans.enabled to be True after deep-merge override"
        )

    @pytest.mark.unit
    def test_load_project_slop_config_returns_empty_for_no_config(
        self, tmp_path: Path
    ) -> None:
        """load_project_slop_config returns {} when no config file is present."""
        result = load_project_slop_config(tmp_path)
        assert result == {}, (
            f"Expected empty dict for project with no config, got {result!r}"
        )

    @pytest.mark.unit
    def test_load_project_slop_config_reads_slop_toml(self, tmp_path: Path) -> None:
        """load_project_slop_config reads .slop.toml when present."""
        (tmp_path / ".slop.toml").write_text(
            'exclude = ["docs/**"]\n', encoding="utf-8"
        )
        result = load_project_slop_config(tmp_path)
        assert result.get("exclude") == ["docs/**"], (
            f"Expected exclude from .slop.toml, got {result!r}"
        )

    @pytest.mark.unit
    def test_load_project_slop_config_reads_pyproject_toml_tool_slop(
        self, tmp_path: Path
    ) -> None:
        """load_project_slop_config falls back to pyproject.toml [tool.slop]."""
        (tmp_path / "pyproject.toml").write_text(
            '[tool.slop]\nexclude = ["build/**"]\n', encoding="utf-8"
        )
        result = load_project_slop_config(tmp_path)
        assert result.get("exclude") == ["build/**"], (
            f"Expected exclude from pyproject.toml [tool.slop], got {result!r}"
        )


# ---------------------------------------------------------------------------
# Integration tests — real slop lint with deep-merged orphans config
# ---------------------------------------------------------------------------


class TestOrphansIntegration:
    """Integration tests: write_orphans_config() + real slop lint."""

    @pytest.mark.integration
    def test_write_orphans_config_runs_real_slop_with_orphans_rule(
        self, tmp_path: Path
    ) -> None:
        """End-to-end: _write_orphans_config produces a valid deep-merged TOML.

        Verifies:
        (a) orphans rule present in slop output with status in {pass, fail}
        (b) project exclude is honored (no violations from archive/ dir)
        (c) project custom thresholds are preserved in the generated config
        """
        import shutil
        import subprocess as sp

        # Skip if slop is not installed.
        if not shutil.which("slop"):
            pytest.skip("slop CLI not found in PATH")

        # Setup: minimal project with .slop.toml containing exclude + custom threshold.
        project_root = tmp_path / "test_project"
        project_root.mkdir()

        slop_cfg = project_root / ".slop.toml"
        slop_cfg.write_text(
            'exclude = ["archive/**"]\n'
            "[rules.complexity]\n"
            "enabled = true\n"
            "cyclomatic_threshold = 3\n"
            "severity = \"error\"\n\n"
            "[rules.orphans]\n"
            "enabled = false\n"
            "min_confidence = \"high\"\n"
            "severity = \"warning\"\n",
            encoding="utf-8",
        )

        # A simple Python file (clean — no complexity violations at threshold 3).
        (project_root / "main.py").write_text(
            'def simple(x: int) -> int:\n    """Simple fn."""\n    return x + 1\n',
            encoding="utf-8",
        )

        # A file inside archive/ — should be excluded.
        archive_dir = project_root / "archive"
        archive_dir.mkdir()
        (archive_dir / "legacy.py").write_text(
            'def legacy_fn():\n    """Excluded."""\n    return 1\n',
            encoding="utf-8",
        )

        tmp_config = write_orphans_config(project_root)
        try:
            # (c) Custom threshold preserved in generated config.
            with open(tmp_config, "rb") as fh:
                config_data = tomllib.load(fh)
            assert config_data.get("rules", {}).get("complexity", {}).get(
                "cyclomatic_threshold"
            ) == 3, (
                "Expected cyclomatic_threshold=3 preserved in generated config"
            )

            # Run real slop lint with generated config.
            result = sp.run(
                [
                    "slop",
                    "lint",
                    "--root",
                    str(project_root),
                    "--config",
                    str(tmp_config),
                    "--output",
                    "json",
                ],
                capture_output=True,
                text=True,
            )
            json_data = json.loads(result.stdout)

            # (a) orphans rule present with valid status.
            rules = json_data.get("rules", {})
            assert "orphans" in rules, (
                f"Expected 'orphans' key in slop output rules, got keys: {list(rules.keys())}"
            )
            orphans_status = rules["orphans"].get("status")
            assert orphans_status in {"pass", "fail"}, (
                f"Expected orphans status in {{pass, fail}}, got {orphans_status!r}"
            )

            # (b) exclude honored — no violations from archive/.
            orphans_violations = rules["orphans"].get("violations", [])
            for v in orphans_violations:
                file_path = v.get("file", "")
                assert "archive" not in file_path.replace("\\", "/"), (
                    f"Expected no orphan violations from archive/ (excluded), got: {file_path!r}"
                )
        finally:
            try:
                tmp_config.unlink()
            except FileNotFoundError:
                pass


# ---------------------------------------------------------------------------
# Repo-layout path resolution regression test
# ---------------------------------------------------------------------------

_REPO_ROOT = Path(__file__).resolve().parents[4]


class TestResolveSkillSh:
    """Regression tests for resolve_skill_sh() path computation.

    Catches the parents[2] bug (resolves into quality-lint-report/scripts/)
    and any future layout drift in agent-quality-lint/scripts/.
    """

    @pytest.mark.unit
    def test_resolve_skill_sh_points_to_existing_file(self) -> None:
        """resolve_skill_sh() must resolve to a file that actually exists.

        Example:
            >>> from slop_report.core.paths import resolve_skill_sh
            >>> resolve_skill_sh().exists()
            True
        """
        assert resolve_skill_sh().exists(), (
            f"skill.sh not found at {resolve_skill_sh()!r} — check parents[] index in paths.py"
        )

    @pytest.mark.unit
    def test_resolve_skill_sh_equals_expected_path(self) -> None:
        """resolve_skill_sh() must equal the canonical sibling skill path.

        Strict equality catches parent-index drift even when the file happens
        to exist at a different location.

        Example:
            >>> from slop_report.core.paths import resolve_skill_sh
            >>> resolve_skill_sh().name
            'skill.sh'
        """
        expected = _REPO_ROOT / ".agents" / "skills" / "agent-quality-lint" / "scripts" / "skill.sh"
        assert resolve_skill_sh() == expected, (
            f"Expected {expected!r}, got {resolve_skill_sh()!r}"
        )
