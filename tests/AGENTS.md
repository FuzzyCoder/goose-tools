# Tests Directory Agent Rules
## Purpose
Test suites for warp-tools. All tests must follow pytest conventions and project-wide testing standards.

→ See .agents/skills/write-tests skill for examples and workflows

RULE: TEST_MARKERS_COMBINABLE
- ALWAYS use pytest markers for all tests: `@pytest.mark.unit`, `@pytest.mark.integration`, `@pytest.mark.slow`
- NEVER write tests without appropriate markers
- Markers are combinable: `slow` can stack with `unit` or `integration`
- This rule is authoritative and overrides any conflicting skill guidance

RULE: TEST_ASSERTIONS
- ALWAYS include descriptive messages with all assertions
- NEVER use bare assert statements without messages
- ALWAYS format assertion messages to show expected vs actual values
- ALWAYS use f-strings for dynamic assertion messages

RULE: TEST_ERROR_HANDLING
- ALWAYS test error conditions explicitly with `pytest.raises()`
- NEVER ignore error handling paths in tests
- ALWAYS verify exception types and messages
- ALWAYS test both success and failure paths

RULE: TEST_FIXTURES
- ALWAYS use pytest fixtures for reusable test data
- NEVER hardcode test data directly in individual tests
- ALWAYS define fixtures at appropriate scope (function, class, module, session)
- ALWAYS use `conftest.py` for shared fixtures across multiple test files
- ALWAYS clean up resources using yield pattern
- ALWAYS use `tmp_path` fixture for temporary file operations

RULE: TEST_ISOLATION
- ALWAYS mock external dependencies in unit tests
- NEVER use real database connections in `@pytest.mark.unit` tests
- NEVER make actual API calls in unit tests
- ALWAYS ensure tests can run in any order without dependencies

RULE: TEST_DATA_MANAGEMENT
- ALWAYS use `polars.DataFrame` for test dataframes (not pandas)
- ALWAYS create minimal test data covering edge cases
- NEVER use production data in tests
- ALWAYS validate data types match expectations in assertions

RULE: TEST_CLASS_ORGANIZATION
- ALWAYS organize related tests into test classes with `Test` prefix
- ALWAYS include docstrings for test classes and test functions (Google format)
- ALWAYS group class-specific fixtures within the test class

RULE: TEST_NAMING
- ALWAYS name test files with `test_` prefix
- ALWAYS name test functions with `test_` prefix
- ALWAYS follow pattern: `test_<function>_<scenario>_<expected_result>`

RULE: TEST_PARAMETRIZE
- ALWAYS use `@pytest.mark.parametrize` for multiple input scenarios
- NEVER duplicate test logic for different inputs
- ALWAYS provide descriptive IDs for parametrized tests

RULE: TEST_COMMIT_POLICY
- NEVER commit failing tests
- NEVER skip tests without documented reason

RULE: TEST_PHILOSOPHY
- Tests verify observable behavior — what code does, not how it does it
- If a refactor breaks tests but not behavior, the tests were wrong; fix them
- ALWAYS cover edge cases and error paths, not just the happy path
- Mock external, slow, or non-deterministic dependencies (network, time, filesystem I/O)
- NEVER mock pure functions or in-process business logic
- DELETE commented-out tests; do not leave them in place

## Customization

The following rules encode **starter-stack defaults**. Adapt or remove them for a different stack:
- **TEST_DATA_MANAGEMENT** — default DataFrame library for test data is `polars`; replace with `pandas` if the project is pandas-first

Last Updated: 2026.05.02 @ 22:32:45
