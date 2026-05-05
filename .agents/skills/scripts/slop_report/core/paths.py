"""Path resolution helpers for the slop_report package."""

from pathlib import Path


def resolve_skill_sh() -> Path:
    """Return the canonical path to the slop runner skill.sh script.

    Ascends ``parents[4]`` from this file — five directory levels up to the
    ``.agents/skills/`` root — then descends into
    ``agent-quality-lint/scripts/skill.sh``.

    Returns:
        Absolute path to ``skill.sh``.
    """
    return (
        Path(__file__).resolve().parents[4]
        / "agent-quality-lint"
        / "scripts"
        / "skill.sh"
    )
