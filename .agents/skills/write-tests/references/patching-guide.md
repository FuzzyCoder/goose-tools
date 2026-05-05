# Patching, Async, and pytest.raises Guide

## Table of Contents
1. [Patching Deferred (In-Function) Imports](#1-patching-deferred-in-function-imports)
2. [ty + asyncio.to_thread + TypedDict](#2-ty--asyncioto_thread--typeddic)
3. [pytest.raises match= — Raw Strings for Regex Metacharacters](#3-pytestraises-match--raw-strings-for-regex-metacharacters)

---

## 1. Patching Deferred (In-Function) Imports

Many service modules defer imports inside function bodies to avoid circular imports
(commonly annotated `# noqa: PLC0415` in Python linters):

```python
def process(params):
    from mypackage.core.paths import DATA_PATH  # noqa: PLC0415
    ...
```

These names are **never bound at the consuming module's level**, so patching the
consuming module raises `AttributeError`:

```python
# ❌ Fails — AttributeError: <module> does not have attribute 'DATA_PATH'
with patch("mypackage.services.backup.DATA_PATH", ...):
    ...

# ✅ Correct — patch the *definition* site where the name is resolved at call time
with patch("mypackage.core.paths.DATA_PATH", ...):
    ...
```

**Rule: patch the module that *defines* the name**, not the module that imports it.
This applies to path constants, class references, and utility functions imported with
`from X import Y` inside a function body.

---

## 2. ty + asyncio.to_thread + TypedDict

`ty` raises `invalid-argument-type` when a plain dict literal is passed directly as a
`TypedDict` argument to `asyncio.to_thread()`, because `ty` cannot infer the TypedDict
type from an untyped literal:

```python
# ❌ ty error: found `dict[Unknown, Unknown]`, expected `CreateParams`
result = await asyncio.to_thread(create_something, {})

# ✅ Correct — declare an explicitly typed variable first
_params: CreateParams = {}
result = await asyncio.to_thread(create_something, _params)
```

Same applies for TypedDicts with required fields:

```python
# ❌ ty error: found `dict[..., ...]`, expected `RestoreParams`
result = await asyncio.to_thread(restore, {"name": name})

# ✅ Correct
_p: RestoreParams = {"name": name}
result = await asyncio.to_thread(restore, _p)
```

The typed variable also documents the expected call contract at the call site.

---

## 3. pytest.raises match= — Raw Strings for Regex Metacharacters

The `match=` argument to `pytest.raises()` is a regex pattern. Always use **raw strings**
when the pattern contains regex metacharacters:

```python
# ❌ May over-match or error — '.' matches any char, '*' is a quantifier
with pytest.raises(ValueError, match="path .* not found"):
    ...

# ✅ Correct — raw string prevents accidental string-escape interpretation
with pytest.raises(ValueError, match=r"path .* not found"):
    ...
```

Rules:
- Use `r"..."` whenever the pattern contains `.`, `*`, `+`, `?`, `(`, `)`, `[`, `]`, `{`, `}`
- Escape literal dots as `\.` when you want exact period matching
- For simple substring matching with no metacharacters, plain strings are fine

Last Updated: 2026.05.04 @ 03:16:40
