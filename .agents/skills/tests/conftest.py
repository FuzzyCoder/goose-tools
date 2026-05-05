"""pytest configuration for quality-lint-report skill tests.

Adds the scripts directory to sys.path so generate_report can be imported
without installation.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Make generate_report and slop_report importable regardless of invocation directory.
_SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))
