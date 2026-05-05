# Domain Map for `manage-capabilities`

Config artifact — authoritative registry for skill-to-domain assignments, bundled flags,
example prompts, and gap-text entries. Not bound by the SKILL.md 200-line limit.

**Format rules for renderers:**
- Domain display order = order of `## <Domain>` headings in this file
- Bundled skills: marked with `(bundled)` in the Skills list
- Example tags: `[skill-name]` at end of each example; filter out examples whose tagged
  skill is not currently installed
- Gap text: `**Gap:**` line under a domain; shown when that domain has no installed skills
- Unconditional gaps: `**Gap:**` entries under `## Unconditional Gaps` always show

---

## Deploy & Adopt

**Skills:**
- `deploy-warp-tools` — scaffold warp-tools into a new repo, update an existing one, install globals, switch scaffold profiles, run doctor

**Examples:**
- "Scaffold warp-tools into my repo." [deploy-warp-tools]
- "Update warp-tools in `/path/to/myproject`." [deploy-warp-tools]
- "Install warp-tools globals on this machine." [deploy-warp-tools]
- "Switch my repo to the `core` scaffold profile." [deploy-warp-tools]

**Gap:** No deploy/adoption skill installed — scaffold one with `deploy-warp-tools` from warp-tools.

---

## Plan & Review Workflow

**Skills:**
- `plan-workflow` — drive Plan→Review→Edit→Review→Finalize→Execute via slot scripts (`oz_pw_*.sh`)
- `manage-plans` — create/register/retrieve Warp plans with persistent `plan_id` tracking
- `review-plan` — multi-dimension review (Correctness/Completeness/Clarity/Consistency)
- `review-pr` — read-only dimensional PR review (correctness+tests, security+design)
- `review-and-fix-pr` — autonomously review and fix the current branch's PR (applies fixes, commits, pushes)

**Examples:**
- "Start the plan workflow with slot `cleanup`." [plan-workflow]
- "Review this plan." [review-plan]
- "Review-pr." [review-pr]
- "Review and fix this PR." [review-and-fix-pr]

**Gap:** No plan/review workflow skill installed.

---

## Authoring Code, Tests & Modules

**Skills:**
- `add-new-module` — create a new module following project conventions
- `write-tests` — write pytest tests for uv-managed Python projects
- `run-quality-checks` — run ruff lint and ty type checking

**Examples:**
- "Add a new module under `utils/` for CSV ingest." [add-new-module]
- "Write tests for `parser.py`." [write-tests]
- "Run quality checks." [run-quality-checks]

**Gap:** No code authoring skill installed.

---

## Skill Authoring & Maintenance

**Skills:**
- `write-skill` — author or improve a single SKILL.md
- `create-skill` (bundled) — create/edit skills, run evals, benchmark, optimize descriptions
- `refactor-agent-instructions` — audit/normalize across many AGENTS.md and SKILL.md files
- `tune-agent-assets` — PD/AH/TR content-level tuning of SKILL.md, AGENTS.md, and docs

**Examples:**
- "Write a skill for running database migrations safely." [write-skill]
- "Improve the description for the `fix-complexity` skill so it triggers more reliably." [write-skill]
- "Run the validation matrix and audit AGENTS.md compliance." [refactor-agent-instructions]
- "Benchmark the `quality-remediate` skill and report variance." [create-skill]
- "Tune PD compliance for the `sync-worktrees` skill." [tune-agent-assets]
- "Reduce skill tokens in `quality-remediate`." [tune-agent-assets]

**Gap:** No skill authoring skill installed.

---

## Code Quality Lint & Remediation

**Skills:**
- `agent-quality-lint` — run the 13-rule structural linter (passive/active mode)
- `quality-lint-report` — generate timestamped compact and full Markdown reports
- `quality-remediate` — orchestrate iterative remediation (routes to `fix-*` skills, up to 5 rounds)
- `quality-remediator` — sub-agent for single-rule, scoped fixes (invoked by `quality-remediate`)
- `quality-fix-notes` — maintain Obsidian fix notes per lint rule
- `fix-orphans` — remediate unreferenced symbols
- `fix-hotspot` — remediate high-churn × high-complexity files
- `fix-packages` — remediate Zone of Pain packages (high stability, low abstractness)
- `fix-halstead` — remediate Halstead volume and difficulty violations
- `fix-class-complexity` — remediate WMC and CBO class violations
- `fix-complexity` — remediate cyclomatic (CCX) and cognitive (CogC) complexity violations
- `fix-class-inheritance` — remediate deep inheritance (DIT) and too-many-children (NOC) violations
- `fix-deps-cycle` — remediate import cycles by extracting shared types
- `fix-npath` — remediate combinatorial path explosion (NPATH > 400)
- `fix-issue` — given a GitHub issue, branch + plan + implement + self-review + open PR

**Examples:**
- "Run slop and generate the report." [quality-lint-report]
- "Remediate quality violations." [quality-remediate]
- "Fix the orphan symbols in `src/cli/`." [fix-orphans]
- "CCX is too high in `parser.py` — fix complexity violations." [fix-complexity]
- "Update slop notes after the rule-set bump." [quality-fix-notes]
- "Fix issue #482." [fix-issue]

**Gap:** No code quality skill installed.

---

## Git Worktrees

**Skills:**
- `manage-worktrees` — create, list, remove, and prune git worktrees
- `sync-worktrees` — commit, push, integrate, and rebase across all worktrees

**Examples:**
- "Create a worktree for branch `feat/foo`." [manage-worktrees]
- "Sync all worktrees." [sync-worktrees]

**Gap:** No git worktree skill installed.

---

## Dependencies & Maintenance

**Skills:**
- `update-deps` — run `uv lock --upgrade`, sync, pip-audit, quality checks, and tests

**Examples:**
- "Update dependencies." [update-deps]

**Gap:** No dependency management skill installed.

---

## Shell & Launcher Work

**Skills:**
- `agent-launcher` — Bash patterns for `oz agent run` launchers (foreground, prompt externalization, DRY_RUN)
- `improve-shell-quality` — modularize monolithic shell scripts with bats tests and shellcheck CI

**Examples:**
- "Write a launcher script for the Reviewer profile." [agent-launcher]
- "Refactor `bin/foo.sh` into modules with bats tests." [improve-shell-quality]

**Gap:** No shell/launcher skill installed.

---

## Repo Documentation

**Skills:**
- `manage-inventory` — regenerate or create INVENTORY.md (file inventory)
- `manage-todo` — regenerate or create TODO.md (quality-snapshot task list)
- `manage-capabilities` — regenerate or create CAPABILITIES.md (skill capability map)

**Examples:**
- "Update INVENTORY.md." [manage-inventory]
- "Regenerate the inventory." [manage-inventory]
- "Update TODO.md." [manage-todo]
- "Refresh the quality snapshot." [manage-todo]
- "Sync capabilities with the installed skills." [manage-capabilities]
- "Update CAPABILITIES.md." [manage-capabilities]

**Gap:** No repo documentation skill installed.

---

## Analysis Pipelines

**Skills:**
- `scaffold-analysis-pipeline` — scaffold a dual-language (Python + R) standalone analysis pipeline sub-project

**Examples:**
- "Create a new analysis pipeline for this dataset." [scaffold-analysis-pipeline]
- "Port this Stata workflow to Python." [scaffold-analysis-pipeline]
- "Scaffold a numbered-step pipeline with parquet intermediates." [scaffold-analysis-pipeline]

**Gap:** No analysis pipeline skill installed.

---

## Oz Cloud Agents

**Skills:**
- `oz-platform` (bundled) — run, configure, and inspect Oz cloud agents via REST API and CLI

**Examples:**
- "Launch a cloud agent for the planner profile." [oz-platform]
- "List recent cloud agent runs." [oz-platform]

**Gap:** No Oz cloud agent skill installed.

---

## Model Selection

**Skills:**
- `list-warp-models` — list available LLM models in Warp's Oz platform via the CLI

**Examples:**
- "List the available Warp models." [list-warp-models]
- "Show me only open models I can use for the Planner profile." [list-warp-models]
- "Which model should I use for planning?" [list-warp-models]
- "What's the best model_id for a Coder profile that prioritizes speed?" [list-warp-models]

**Gap:** No model-selection skill installed.

---

## Claude / Anthropic SDK

**Skills:**
- `claude-api` (bundled) — build, debug, and optimize Claude API apps (caching, thinking, tool use, batch, citations); migrate between Claude versions

**Examples:**
- "Add prompt caching to this Anthropic SDK call." [claude-api]
- "Migrate this code from Claude 4.6 to 4.7." [claude-api]

**Gap:** No Claude/Anthropic SDK skill installed.

---

## Warp App Configuration

**Skills:**
- `modify-settings` (bundled) — view or modify Warp settings via JSON schema
- `create-tab-config` (bundled) — create new Warp tab config TOML files
- `update-tab-config` (bundled) — update existing Warp tab config TOML files
- `tab-configs` (bundled) — reference the Warp tab config schema and examples
- `add-mcp-server` (bundled) — add an MCP server to Warp configuration
- `pr-comments` (bundled) — fetch and display GitHub PR review comments for the current branch
- `feedback` (bundled) — turn rough Warp feedback into a filed GitHub issue for `warpdotdev/warp`

**Examples:**
- "Add a Postgres MCP server." [add-mcp-server]
- "Create a tab config with three panes for backend dev." [create-tab-config]
- "Show PR comments for this branch." [pr-comments]
- "File a Warp bug for this regression." [feedback]

**Gap:** No Warp app configuration skill installed.

---

## Unconditional Gaps

<!-- Add free-form gap entries here that should ALWAYS appear in CAPABILITIES.md
     regardless of which skills are installed. Example:
     - Database migrations: no skill covers safe migration authoring yet.
-->
