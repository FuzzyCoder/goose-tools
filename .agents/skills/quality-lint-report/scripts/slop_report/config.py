"""Configuration loading, deep merge, orphan config, and symlink management."""

from __future__ import annotations

import fnmatch
import os
import tempfile
import tomllib
from pathlib import Path
from typing import Any

import tomli_w

from slop_report.core.const import _ORPHAN_PATTERNS


def load_project_slop_config(root: Path) -> dict[str, Any]:
    """Load the project's slop configuration as a raw dict.

    Checks for ``<root>/.slop.toml`` first; falls back to the ``[tool.slop]``
    subtree of ``<root>/pyproject.toml``; returns ``{}`` if neither is found.

    Args:
        root: Project root directory.

    Returns:
        Parsed TOML content as a plain dict.

    Raises:
        ValueError: If a config file is found but fails to parse.
    """
    slop_toml = root / ".slop.toml"
    if slop_toml.is_file():
        try:
            with open(slop_toml, "rb") as fh:
                return tomllib.load(fh)
        except tomllib.TOMLDecodeError as e:
            raise ValueError(f"{slop_toml}: failed to parse TOML: {e}") from e

    pyproject = root / "pyproject.toml"
    if pyproject.is_file():
        try:
            with open(pyproject, "rb") as fh:
                data = tomllib.load(fh)
        except tomllib.TOMLDecodeError as e:
            raise ValueError(f"{pyproject}: failed to parse TOML: {e}") from e
        tool_slop = data.get("tool", {}).get("slop", {})
        if isinstance(tool_slop, dict):
            return tool_slop
    return {}


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge *override* into *base*, returning a new dict.

    Override values take precedence. Non-dict values are replaced wholesale.
    Dict values are recursively merged. Original dicts are not modified.

    Args:
        base: Base dictionary.
        override: Override dictionary whose values take precedence.

    Returns:
        New merged dictionary.

    Examples:
        >>> deep_merge({"a": {"x": 1}}, {"a": {"y": 2}})
        {'a': {'x': 1, 'y': 2}}
        >>> deep_merge({"a": 1}, {"a": 2})
        {'a': 2}
    """
    result: dict[str, Any] = dict(base)
    for key, value in override.items():
        if (
            key in result
            and isinstance(result[key], dict)
            and isinstance(value, dict)
        ):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def write_orphans_config(root: Path) -> Path:
    """Create a temp TOML config with orphans enabled, merged from the project config.

    Reads the project's existing ``.slop.toml`` (or ``pyproject.toml [tool.slop]``),
    deep-merges an ``[rules.orphans] enabled = true`` override over it (preserving
    the project's ``exclude`` list, custom thresholds, and all other rule settings),
    writes the merged result to a temporary ``.toml`` file, and returns the path.

    The caller is responsible for deleting the temp file when done.

    Args:
        root: Project root directory.

    Returns:
        Path to the written temporary TOML file.

    Raises:
        ValueError: If the project config fails to parse.
    """
    base = load_project_slop_config(root)
    merged = deep_merge(
        base,
        {
            "rules": {
                "orphans": {
                    "enabled": True,
                    "min_confidence": "high",
                    "severity": "warning",
                }
            }
        },
    )
    fd, tmp_path_str = tempfile.mkstemp(suffix=".toml")
    os.close(fd)
    tmp_path = Path(tmp_path_str)
    tmp_path.write_text(tomli_w.dumps(merged), encoding="utf-8")
    return tmp_path


def update_symlink(link_path: Path, target_name: str) -> None:
    """Create or update a symlink at *link_path* pointing to *target_name*.

    Handles all pre-existing states at *link_path*: regular file, valid
    symlink, or broken symlink. Uses a relative target path so the
    ``.slop/`` directory remains self-contained.

    Args:
        link_path: Absolute path where the symlink should be created.
        target_name: Relative path to the symlink target (may include a
            subdirectory component, e.g.
            ``"slop_lint_{ts}/slop_lint_{ts}.json"``).

    Raises:
        ValueError: If the symlink cannot be created.
    """
    if link_path.exists() or link_path.is_symlink():
        link_path.unlink()
    link_path.symlink_to(target_name)


def clean_orphan_artifacts(slop_dir: Path) -> None:
    """Delete stale flat-layout artifacts at the ``.slop/`` root.

    Regular files (not symlinks, not subdirectories) matching the legacy naming
    patterns are removed.

    Args:
        slop_dir: Path to the ``.slop/`` directory.
    """
    for entry in slop_dir.iterdir():
        if not entry.is_symlink() and entry.is_file():
            if any(fnmatch.fnmatch(entry.name, pat) for pat in _ORPHAN_PATTERNS):
                entry.unlink()
