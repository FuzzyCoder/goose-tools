# Parallel Agent Strategy

## Table of Contents
1. [Parallel Agent Workflow](#1-parallel-agent-workflow)
2. [Coordinator Pattern](#2-coordinator-pattern)

---

## 1. Parallel Agent Workflow

When implementing both Python and R simultaneously:
1. Treat the spec (plan) as fixed before starting agents
2. Start one agent per language with the **full Stata source + shared spec** as context
3. Each agent owns its complete language project — no cross-agent file edits
4. Shared decisions (equivalence, thresholds, deviations) stay in the plan — not in agent messages
5. Run quality checks (`ruff` + `ty`) on the Python project after both agents are idle

---

## 2. Coordinator Pattern

```
Coordinator → start_agent("python-<study>", full_spec)
Coordinator → start_agent("r-<study>", full_spec)
# await both idle, then verify:
uv run ruff check . && uv run ty check <study>/
Rscript -e "testthat::test_dir('tests/testthat')"
```

Last Updated: 2026.05.04 @ 03:16:40
