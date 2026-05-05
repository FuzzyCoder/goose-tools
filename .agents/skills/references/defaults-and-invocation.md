# Confirmed Defaults and Invocation Parameters

## Table of Contents
- [Confirmed Defaults](#confirmed-defaults)
- [Invocation Summary](#invocation-summary)

## Confirmed Defaults

### 1. Protected branch rewrite (Phase 4)
- **Default**: `skip-and-report` — protected branches are excluded from rebase scope.
- **Override**: `--allow-rewrite <branch1> [<branch2> ...]`

### 2. Policy-blocked integration/push (Phases 2–3)
- **Default**: `stop-and-report`
- **Override**: `--on-policy-block=prompt`

### 3. Merge policy (Phase 2)
- **Default**: `ff-then-merge`
- **Override**: `--merge-policy=ff-only` or `--merge-policy=prompt`

## Invocation Summary

| Parameter | Values | Default |
|---|---|---|
| `--allow-rewrite` | `<branch> [...]` | (none — protected branches skipped) |
| `--on-policy-block` | `stop-and-report`, `prompt` | `stop-and-report` |
| `--merge-policy` | `ff-then-merge`, `ff-only`, `prompt` | `ff-then-merge` |
