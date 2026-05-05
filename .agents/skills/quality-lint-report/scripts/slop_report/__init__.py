"""slop_report — slop lint report generation package.

Public APIs:
    parse_and_validate(json_path) \u2192 ParsedSlopReport
    render_compact(parsed, json_filename) \u2192 str
    render_full(parsed, json_filename) \u2192 str
    main() \u2192 None
"""

from slop_report.config import clean_orphan_artifacts, deep_merge, load_project_slop_config
from slop_report.models import ParsedSlopReport
from slop_report.parser import parse_and_validate
from slop_report.render_compact import render_compact
from slop_report.render_full import render_full
from slop_report.runner import main, run_slop_lint

__all__ = [
    "ParsedSlopReport",
    "clean_orphan_artifacts",
    "deep_merge",
    "load_project_slop_config",
    "main",
    "parse_and_validate",
    "render_compact",
    "render_full",
    "run_slop_lint",
]
