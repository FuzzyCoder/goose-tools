# warp-tools Agent Rules
## Purpose
`warp-tools` is the canonical portable agent toolchain for Warp's Oz platform. It
provides the Plan→Review→Edit→Review→Finalize→Execute workflow scripts, agent profile
templates, and Warp Drive assets. The repo is evolving toward a monorepo structure that
will also ship a portable slop code-quality kit (lint, report, remediation) and other
reusable tools for existing projects to adopt and new projects to deploy.

## Conventions

RULE: TYPE_CHECKER_TY_ONLY
- ALWAYS use `ty` for type checking
- NEVER use pyright or basedpyright
RULE: CODE_STYLE_LINTING
- ALWAYS use ruff for linting with 100 char line length
- ALWAYS use Google format docstrings with examples
RULE: CODE_STYLE_DATAFRAMES
- ALWAYS use Polars-first; use pandas only when required by a third-party dependency
- ALWAYS use `*_df` suffix for DataFrame variables
- NEVER use `df_*` prefix for DataFrame variables
RULE: SEMANTIC_KEYS
- ALWAYS use semantic keys in data models and schemas (e.g., `note_id`, `user_id`, `record_id`)
- NEVER use generic `_key` or `_id` suffixes when a domain-meaningful name exists
RULE: MODULE_IMPORTS
- ALWAYS add constants to the package's `core/const.py` only; never create new constant files
- ALWAYS import paths from the package's `core/paths` module
- ALWAYS import specific symbols, not entire modules
- NEVER hardcode constants or directory paths outside of the package's `core/const.py` and `core/paths.py`
RULE: CROSS_MODULE_IMPORTS
- NEVER import from sibling packages or modules at the same level
- ALWAYS route shared logic through a `common/` or `utils/` module
- Cross-module reads are permitted but must be read-only and explicitly documented
RULE: THIRD_PARTY_ERROR_HANDLING
- NEVER suppress errors or warnings from third-party packages
- ALWAYS attempt to correct the calling code that causes the error or warning
- ALWAYS raise an explicit error when the issue cannot be prevented by corrected code
- ALWAYS log third-party errors with full context before raising
RULE: ERROR_FAIL_FAST
- ALWAYS validate input parameters at function entry
- ALWAYS raise `ValueError`/`TypeError` immediately on invalid input
- NEVER return None or empty without logging
RULE: ERROR_EXCEPTION_PROPAGATION
- ALWAYS use chained exceptions (`raise ... from e`)
- ALWAYS log context before re-raising exceptions
- NEVER suppress third-party exceptions without explicit justification
RULE: ERROR_LOGGING
- ALWAYS use loguru for structured, contextual logging
- NEVER suppress errors; correct calling code first
RULE: DATA_NO_EMPTY_DATAFRAMES_ON_ERROR
- NEVER return `pl.DataFrame()` on database or I/O errors
- ALWAYS let exceptions propagate with context
- NEVER mask errors by returning empty dataframes
RULE: DATA_LAZY_EVALUATION_FOR_LARGE_DATA
- ALWAYS use `pl.scan_csv().collect()` for files >100MB
- NEVER load large datasets eagerly with `pl.read_csv()` without justification
- ALWAYS prefer lazy evaluation for large file operations
RULE: DATA_CACHE_EXPENSIVE_OPERATIONS
- ALWAYS use `@functools.lru_cache` for repeated expensive database queries or computations
- NEVER fetch the same data multiple times in a session without caching
RULE: DOCS_UV_RUN_COMMANDS
- ALWAYS use `uv run python -m` (never bare `python -m`) in all runnable command examples in docs
- NEVER write bare `python -m <module>` in *.md files — it executes outside the uv-managed environment
- Exceptions: cron entries with explicit venv path, CI/CD YAML blocks, descriptive prose (not instructions)
RULE: HARD_QUALITY_LIMITS
- NEVER write functions longer than 100 lines
- NEVER write functions with cyclomatic complexity > 8
- NEVER write functions with more than 5 positional parameters
- ALWAYS use absolute imports only — no relative `..` paths
- ALWAYS add Google-style docstrings to non-trivial public APIs
RULE: ZERO_WARNINGS_POLICY
- Fix every warning emitted by ruff, ty, and pytest
- If a warning truly cannot be fixed, add an inline `# noqa` or `# type: ignore` with a one-line justification comment
- NEVER leave unexplained suppressions in committed code
RULE: REVIEW_ORDER
- ALWAYS evaluate code in this order: architecture → code quality → tests → performance
- ALWAYS sync to the latest remote before reviewing: `git --no-pager fetch origin`
- NEVER review a stale local copy without fetching first
RULE: TEST_BEHAVIOR_NOT_IMPLEMENTATION
- Tests MUST verify what code does (its observable behavior), not how it does it
- If a refactor breaks tests but not the observable behavior, the tests were wrong
- NEVER write tests that assert internal implementation details (private methods, call counts on internals)
RULE: AGENT_PROFILE_MODELS
- Profile → Model mapping lives in `docs/agent-profile-security.md` — single source of truth; never inline.
- Open-model defaults are starter-stack defaults from the open-model pool. No Auto routing. No proprietary closed models.
## Skills and Docs

Task-specific workflows live in `.agents/skills/` — browse the directory for all available skills.
→ See .agents/skills/ directory for available workflows
→ See README.md for project documentation and architecture overview
## Rule Precedence

When rules conflict:
1. Most local AGENTS.md takes precedence (e.g., `src/core/AGENTS.md` > root)
2. Project-specific rules override personal rules
3. Explicit instructions override general conventions
## Customization

→ See [docs/customization-defaults.md](docs/customization-defaults.md) for starter-stack defaults.
Last Updated: 2026.05.02 @ 23:29:08
