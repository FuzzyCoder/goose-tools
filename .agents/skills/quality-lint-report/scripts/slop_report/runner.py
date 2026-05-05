"""Slop subprocess invocation and main CLI entry point for slop_report."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from slop_report.config import (
    clean_orphan_artifacts,
    update_symlink,
    write_orphans_config,
)
from slop_report.core.paths import resolve_skill_sh
from slop_report.parser import parse_and_validate
from slop_report.render_compact import render_compact
from slop_report.render_full import render_full


def run_slop_lint(root: Path, timestamp: str, orphans: bool = False) -> Path:
    """Invoke the slop runner and write the JSON to a per-run subdirectory.

    Locates ``skill.sh`` relative to this script, runs
    ``bash skill.sh run --root <abs_root>`` (optionally with ``--config``
    pointing to a deep-merged temp TOML enabling the orphans rule), captures
    stdout, and writes the result to
    ``root/.slop/slop_lint_{timestamp}/slop_lint_{timestamp}.json``.

    When *orphans=True*, a temporary TOML is created by deep-merging the
    project's existing ``.slop.toml`` with ``[rules.orphans] enabled = true``.
    The temp file is deleted unconditionally in a ``finally`` block.

    Args:
        root: Project root directory passed to the slop runner.
        timestamp: Timestamp string (``YYYYMMDD_HHMMSS``) used as the
            subdirectory name and filename suffix.
        orphans: If ``True``, pass a deep-merged config with orphans enabled.

    Returns:
        Path to the written
        ``.slop/slop_lint_{timestamp}/slop_lint_{timestamp}.json`` file.

    Raises:
        ValueError: If ``skill.sh`` is not found; the runner exits non-zero;
            stdout is not valid JSON; the orphans rule is missing from slop
            output when *orphans=True*; or ``.slop/`` cannot be created
            or written.
    """
    skill_sh = resolve_skill_sh()
    if not skill_sh.exists():
        raise ValueError(f"slop runner script not found: {skill_sh}")

    slop_dir = root / ".slop"
    try:
        slop_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise ValueError(f"cannot write to .slop/: {e}") from e

    run_dir = slop_dir / f"slop_lint_{timestamp}"
    try:
        run_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise ValueError(f"cannot write to .slop/: {e}") from e

    json_path = run_dir / f"slop_lint_{timestamp}.json"
    abs_root = root.resolve()

    cmd = ["bash", str(skill_sh), "run", "--root", str(abs_root)]
    tmp_config: Path | None = None
    if orphans:
        tmp_config = write_orphans_config(root)
        cmd.extend(["--config", str(tmp_config)])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)

        # slop exits non-zero when violations are found (normal case); try to
        # parse stdout as JSON first — if it succeeds, the run was valid
        # regardless of exit code.
        stdout = result.stdout
        try:
            json_data = json.loads(stdout)
        except json.JSONDecodeError as e:
            if result.returncode != 0:
                stderr_tail = (result.stderr or "").strip()[-500:]
                raise ValueError(
                    f"slop runner failed (exit {result.returncode}): {stderr_tail}"
                ) from e
            raise ValueError("slop runner produced non-JSON output") from e

        # When orphans=True, verify the rule is present with a usable status.
        # A missing or unrecognised status indicates a slop version mismatch.
        if orphans:
            orphans_rule = json_data.get("rules", {}).get("orphans")
            if orphans_rule is None or orphans_rule.get("status") not in {"pass", "fail"}:
                raise ValueError(
                    "orphans rule missing or has unexpected status in slop output; "
                    f"installed slop v{json_data.get('version', '?')} may not support --orphans"
                )

        try:
            json_path.write_text(
                json.dumps(json_data, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
        except OSError as e:
            raise ValueError(f"cannot write to .slop/: {e}") from e

        return json_path
    finally:
        if tmp_config is not None:
            try:
                tmp_config.unlink()
            except FileNotFoundError:
                pass


def main() -> None:
    """Command-line entry point.

    Runs slop lint fresh, writes three timestamped files, and updates three
    stable symlinks to point to the latest results.

    Per-run outputs (ts = YYYYMMDD_HHMMSS):
    - ``.slop/slop_lint_{ts}/slop_lint_{ts}.json``       raw slop JSON
    - ``.slop/slop_lint_{ts}/slop_lint_{ts}.md``         compact 3-column violations table
    - ``.slop/slop_lint_{ts}/slop_lint_full_{ts}.md``    full per-rule actionable report

    Symlinks updated:
    - ``.slop/slop_lint.json``      \u2192 ``slop_lint_{ts}/slop_lint_{ts}.json``
    - ``.slop/slop_lint.md``        \u2192 ``slop_lint_{ts}/slop_lint_{ts}.md``
    - ``.slop/slop_lint_full.md``   \u2192 ``slop_lint_{ts}/slop_lint_full_{ts}.md``

    Raises:
        SystemExit: With code 1 on any failure.
    """
    parser = argparse.ArgumentParser(
        description="Run slop lint and write timestamped compact + full Markdown reports."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Project root directory for slop runner invocation (default: .).",
    )
    parser.add_argument(
        "--orphans",
        action="store_true",
        help=(
            "Enable the orphans (unreferenced symbols) rule by deep-merging a runtime config "
            "override. Runs may be slow on large codebases."
        ),
    )
    args = parser.parse_args()

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    root = Path(args.root).resolve()
    slop_dir = root / ".slop"

    try:
        json_path = run_slop_lint(root, ts, orphans=args.orphans)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    # Auto-delete orphaned flat-layout artifacts at the .slop/ root.
    clean_orphan_artifacts(slop_dir)

    try:
        parsed = parse_and_validate(json_path)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    run_dir = json_path.parent
    json_filename = f"slop_lint_{ts}.json"

    compact_path = run_dir / f"slop_lint_{ts}.md"
    compact_path.write_text(render_compact(parsed, json_filename), encoding="utf-8")
    print(f"Written: {compact_path}")

    full_path = run_dir / f"slop_lint_full_{ts}.md"
    full_path.write_text(render_full(parsed, json_filename), encoding="utf-8")
    print(f"Written: {full_path}")

    update_symlink(
        slop_dir / "slop_lint.json", f"slop_lint_{ts}/slop_lint_{ts}.json"
    )
    update_symlink(
        slop_dir / "slop_lint.md", f"slop_lint_{ts}/slop_lint_{ts}.md"
    )
    update_symlink(
        slop_dir / "slop_lint_full.md",
        f"slop_lint_{ts}/slop_lint_full_{ts}.md",
    )
    print(f"Symlinks updated: slop_lint.json, slop_lint.md, slop_lint_full.md \u2192 {ts}")
