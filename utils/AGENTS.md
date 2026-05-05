# Utils Directory Agent Rules

## Purpose

This directory contains utility functions, helpers, and common operations used across warp-tools.

RULE: UTILS_PURE_FUNCTIONS
- ALWAYS make utility functions pure (no side effects) when possible
- NEVER modify global state in utility functions
- ALWAYS return new values rather than mutating inputs
- NEVER rely on external state unless explicitly passed as parameters
- ALWAYS design utilities to be stateless and reusable

RULE: UTILS_NO_HARDCODED_CONFIG
- NEVER hardcode paths or configuration in utility functions
- ALWAYS accept configuration as parameters
- ALWAYS import paths from the package's `core.paths` module
- ALWAYS import constants from the package's `core.const` module
- NEVER embed environment-specific values in utility code

RULE: UTILS_COMPREHENSIVE_DOCSTRINGS
- ALWAYS include comprehensive docstrings with examples
- ALWAYS use Google format for docstrings
- ALWAYS provide usage examples in docstrings
- ALWAYS document all parameters, return values, and exceptions
- NEVER write utility functions without complete documentation

RULE: UTILS_INPUT_VALIDATION
- ALWAYS validate input parameters at function entry
- ALWAYS check types, ranges, and constraints early
- ALWAYS raise `ValueError` or `TypeError` with descriptive messages for invalid inputs
- NEVER assume inputs are valid without checking
- ALWAYS fail fast on invalid parameters

RULE: UTILS_NO_SILENT_FAILURES
- NEVER silently fail or return None without logging
- ALWAYS log errors before returning error indicators
- ALWAYS raise exceptions for exceptional conditions
- NEVER catch and suppress exceptions without explicit justification
- ALWAYS make failures visible and debuggable

RULE: UTILS_ERROR_PROPAGATION
- ALWAYS propagate errors with context
- ALWAYS use exception chaining (`raise ... from e`)
- ALWAYS add context to errors before re-raising
- NEVER strip error information when propagating
- ALWAYS preserve stack traces for debugging

## Customization

The following rules encode **starter-stack defaults**. Adapt or remove them for a different stack:
- **UTILS_NO_HARDCODED_CONFIG** — `<package>.core.paths` and `<package>.core.const` are conventions; adapt if project layout differs or does not use a `core/` module

Last Updated: 2026.05.02 @ 22:32:45
