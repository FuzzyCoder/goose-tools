# Starter-Stack Customization Defaults

The following rules encode **starter-stack defaults**. Adapt or remove them for a different stack:

- **TYPE_CHECKER_TY_ONLY** — default is `ty`; replace with `pyright` or `basedpyright` if preferred
- **CODE_STYLE_LINTING** — default linter is `ruff` at 100-char line length; adjust `pyproject.toml` as needed
- **CODE_STYLE_DATAFRAMES** — default DataFrame library is `polars`; remove or replace if project is pandas-first
- **ERROR_LOGGING** — default logger is `loguru`; replace with `structlog` or stdlib `logging` if preferred
- **DOCS_UV_RUN_COMMANDS** — assumes `uv`-managed environments; adapt for `poetry`, `pip`, or `conda`
- **MODULE_IMPORTS** — assumes `<package>.core.const` and `<package>.core.paths` conventions; adapt if layout differs or the repo has no Python package yet
- **DATA_*** rules — assume Polars; remove if project does not use DataFrame operations

Last Updated: 2026.05.04 @ 03:17:55
