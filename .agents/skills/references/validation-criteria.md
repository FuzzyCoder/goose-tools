# Validation Criteria

Per-file compliance checklist and portability rubric for the agents starter library.

## Per-File Compliance Checklist

### AGENTS.md files (all levels)

- [ ] Every `RULE:` block has a unique `SCOPE_NAME` identifier
- [ ] No unnamed `RULE:` blocks (bare `RULE:` with no ID)
- [ ] No architecture overviews or manual skill inventories embedded in rules
- [ ] Cross-references use `→ See .agents/skills/ directory` for available workflows
      OR name a skill that is included in the library (not a repo-local skill)
- [ ] Ends with exactly one `Last Updated: YYYY.MM.DD @ HH:MM:SS` line
- [ ] File is within size targets (see [tune-agent-assets/references/tuning-rubric.md](../../tune-agent-assets/references/tuning-rubric.md))
- [ ] Any file exceeding the size target is registered in `REFACTORING_LOG.md`

### Root AGENTS.md template specifically

- [ ] Contains all required rules from the rule-selection matrix (see README.md)
- [ ] Starter-stack defaults are present (TYPE_CHECKER_TY_ONLY, CODE_STYLE_LINTING, etc.)
- [ ] All import-path examples use `{{PACKAGE_NAME}}` (not hardcoded package names)
- [ ] Ends with `## Customization` section before `Last Updated` line
- [ ] `## Customization` lists all starter-stack default rules

### SKILL.md files (all skills)

- [ ] Frontmatter block present and valid YAML (`---` delimiters)
- [ ] `name` field present and matches directory name
- [ ] `description` field: verb-first, trigger phrases, negative boundaries, no repo-specific names
- [ ] `## When to Use` section present
- [ ] Operational skills have `## Quick Start` section
- [ ] Exactly one terminal `Last Updated:` line
- [ ] No references to duckhouse, Philter, or other repo-specific project nouns
- [ ] No hardcoded machine-local paths (e.g., `/Volumes/secure/`, `~/.warp/`, etc.)
- [ ] No references to repo-local scripts, docs, or helper programs not shipped with the skill
- [ ] Skills with companion `references/` have all linked files present and paths correct
- [ ] Cross-skill references removed or replaced with capability-based negative boundaries

### review-plan skill specifically

- [ ] Step 2 documents multi-dimension analysis covering correctness, completeness, clarity, consistency, and synthesis
- [ ] Step 2 does not prescribe a specific thought count, step count, or MCP tool dependency
- [ ] Common pitfall patterns table contains only technology-agnostic rows

### sync-worktrees skill specifically

- [ ] No references to machine-specific scripts (e.g., `wt_sync_plan.zsh`)
- [ ] Optional accelerator scripts documented with detection mechanism (`-f` file check)
- [ ] `references/conflict-resolution.md` present and linked
- [ ] `references/report-template.md` present and linked
- [ ] `references/shell-env.md` NOT present (machine-specific; excluded from library)

### sync-agents-library skill specifically

- [ ] Both operating modes documented: skill-sync and template-scaffold
- [ ] Discovery targets listed: `~/.agents/skills/` and project-local `.agents/skills/`
- [ ] Placeholder substitution workflow described
- [ ] Drift-detection approach described

## Portability Rubric

A rule or skill is **portable** only if it satisfies all of the following:

1. **No repo-local paths**: Does not reference absolute paths from a specific machine or repo
2. **No repo-local scripts**: Does not depend on scripts that are not shipped as companion files
3. **No repo-local docs**: Does not link to documentation files outside the library
4. **No domain nouns**: Does not mention duckhouse, Philter, anonymous, link_errors, suppressed_codes,
   DocumentDB, philter_annotations, HIPAA Safe Harbor, GLiNER, or other project/product names
5. **No machine-local assumptions**: Does not assume specific shell helpers, Makefile targets,
   or directory conventions not defined in the library itself
6. **Placeholders for customizable values**: All project-specific identifiers replaced with
   `{{UPPER_SNAKE_CASE}}` placeholders defined in README.md

## Placeholder Inventory

All placeholders used in any library file must be defined in `README.md`.

### Required placeholders
| Placeholder | Meaning |
|---|---|
| `{{PROJECT_NAME}}` | Human-readable project name (e.g., "MyApp") |
| `{{PACKAGE_NAME}}` | Python import-path root (e.g., "myapp") |
| `{{DOMAIN_DESCRIPTION}}` | One-sentence description of the project's domain and purpose |
| `{{REPO_ROOT}}` | Absolute path to the repository root |

### Optional placeholders
| Placeholder | Meaning | When to use |
|---|---|---|
| `{{INTEGRATION_BRANCH}}` | Primary integration branch name | If not `main` |
| `{{LINT_COMMAND}}` | Override linting command | If not `uv run ruff check .` |
| `{{TYPECHECK_COMMAND}}` | Override type check command | If not `uv run ty check` |
| `{{TEST_COMMAND}}` | Override test command | If not `uv run pytest tests/` |
| `{{SKILLS_INSTALL_TARGET}}` | Project-local skills path | If not `.agents/skills/` |

## Consumer-Context Validation

After running `sync-agents-library`, verify the following for each install target:

### For skill installs (`~/.agents/skills/` or `<project>/.agents/skills/`)
- [ ] Skill directories are present and contain `SKILL.md`
- [ ] Skills are discoverable (Warp finds them in the install target directory)
- [ ] Companion `references/` files are present alongside their skill directories
- [ ] No broken internal links within skill bodies (referenced files exist)

### For template scaffolds (`<project>/` and subdirectories)
- [ ] Root `AGENTS.md` present in project root
- [ ] `tests/AGENTS.md` present if project has a `tests/` directory
- [ ] `utils/AGENTS.md` present if project has a `utils/` directory
- [ ] All `{{PLACEHOLDER}}` values substituted or flagged for manual substitution
- [ ] `Last Updated` line reflects the scaffold timestamp

Last Updated: 2026.04.28 @ 19:45:31
