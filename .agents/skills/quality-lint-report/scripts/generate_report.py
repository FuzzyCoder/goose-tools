#!/usr/bin/env python3
"""Legacy thin wrapper — delegates to the slop_report package.

Run via:
    uv run python generate_report.py
    uv run python generate_report.py --root /path/to/project
    uv run python generate_report.py --root /path/to/project --orphans
"""

from slop_report.runner import main

if __name__ == "__main__":
    main()
