#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks in printf strings are markdown, not subshells
# Inventory subcommand for goose-tools.
#
# Usage: bin/goose-tools inventory [--json]
# Generates INVENTORY.md with file listings, sizes, line counts, and timestamps.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

_inventory_category() {
  local rel="$1"
  case "$rel" in
    .agents/skills/*/SKILL.md)           printf 'Skills (Primary)\n' ;;
    .agents/skills/*/references/*)       printf 'Skill References\n' ;;
    .agents/skills/*/scripts/*)          printf 'Skill Scripts\n' ;;
    .agents/skills/*/tests/fixtures/*)   printf 'Skill Test Fixtures\n' ;;
    .agents/skills/*/tests/*)            printf 'Skill Tests\n' ;;
    .agents/skills/*/*)                  printf 'Skills (Other)\n' ;;
    bin/commands/*)                      printf 'CLI Commands\n' ;;
    bin/*)                               printf 'CLI & Scripts\n' ;;
    utils/shell/*)                       printf 'Shell Utilities\n' ;;
    utils/*)                             printf 'Utilities\n' ;;
    goose/workflows/scripts/*)            printf 'Workflow Scripts\n' ;;
    goose/workflows/*.yaml)               printf 'Workflow YAMLs\n' ;;
    goose/recipes/*)                    printf 'Notebooks\n' ;;
    warp/*)                              printf 'Warp Assets\n' ;;
    docs/*)                              printf 'Documentation\n' ;;
    tests/bats/*)                        printf 'Bash Tests\n' ;;
    tests/shell_compat/*)                printf 'Shell Compat Tests\n' ;;
    tests/*)                             printf 'Tests\n' ;;
    scripts/*)                           printf 'Scripts\n' ;;
    .github/workflows/*)                 printf 'CI/CD\n' ;;
    .pre-commit-config.yaml)             printf 'CI/CD\n' ;;
    .shellcheckrc)                       printf 'CI/CD\n' ;;
    AGENTS.md|README.md|LICENSE|pyproject.toml|uv.lock|.gitignore|.slop.toml)
      printf 'Project Root\n' ;;
    *)                                   printf 'Other\n' ;;
  esac
}

_inventory_section_key() {
  local cat="$1"
  case "$cat" in
    'Project Root')    printf 'project_root\n' ;;
    'Documentation')   printf 'documentation\n' ;;
    'CLI Commands'|'CLI & Scripts')        printf 'cli_scripts\n' ;;
    'Notebooks'|'Workflow YAMLs'|'Workflow Scripts'|'Warp Assets') printf 'warp_drive_assets\n' ;;
    'Skills (Primary)'|'Skill References'|'Skill Scripts'|'Skill Test Fixtures'|'Skill Tests'|'Skills (Other)')
      printf 'skills\n' ;;
    'Bash Tests'|'Shell Compat Tests'|'Tests') printf 'tests\n' ;;
    'Utilities'|'Shell Utilities') printf 'utilities\n' ;;
    'Scripts')  printf 'setup_scripts\n' ;;
    'CI/CD')    printf 'cicd\n' ;;
    *)          printf 'other\n' ;;
  esac
}

_inventory_skill_subgroup() {
  # Given the relative path AFTER ".agents/skills/<skill-name>/", return the subgroup key.
  local rest="$1"
  case "$rest" in
    SKILL.md)          printf 'skill_md\n' ;;
    references/*)      printf 'references\n' ;;
    scripts/*)         printf 'scripts\n' ;;
    tests/fixtures/*)  printf 'tests\n' ;;
    tests/*)           printf 'tests\n' ;;
    *)                 printf 'other\n' ;;
  esac
}

_inventory_skill_description() {
  # Parse description from SKILL.md YAML frontmatter. Exits non-zero if missing/empty.
  # Handles: single-line, folded (>/>-/>+), literal (|/|-/|+), double-quoted, single-quoted.
  local skill_md="$1" skill_rel="$2"
  [ -f "$skill_md" ] || { printf ''; return 0; }
  local desc
  desc="$(awk '
    BEGIN { sq=sprintf("%c",39); found_fm=0; in_fm=0; in_desc=0; desc="" }
    /^---$/ { if (!found_fm) { found_fm=1; in_fm=1; next } if (in_fm) exit }
    !in_fm { next }
    in_desc {
      if (/^[[:space:]]/) {
        line=$0; sub(/^[[:space:]]+/,"",line)
        if (line!="") { desc=(desc==""?line:desc" "line) }
        next
      }
      in_desc=0
    }
    /^description:/ {
      rest=substr($0,13); sub(/^[[:space:]]*/,"",rest); gsub(/[[:space:]]+$/,"",rest)
      if (rest==">"||rest==">-"||rest==">+"||rest=="|"||rest=="|-"||rest=="|+") {
        in_desc=1; desc=""
      } else if (substr(rest,1,1)=="\"") {
        sub(/^"/,"",rest); sub(/"$/,"",rest); desc=rest
      } else if (substr(rest,1,1)==sq) {
        sub(/^./,"",rest); sub(/.$/,"",rest); desc=rest
      } else {
        desc=rest
      }
    }
    END { print desc }
  ' "$skill_md")"
  if [ -z "$desc" ]; then
    printf 'error: inventory: %s has no description in frontmatter\n' "$skill_rel" >&2
    return 1
  fi
  printf '%s\n' "$desc"
}

_inventory_entry_markdown() {
  local file="$1" repo_root="$2"
  local rel size lines mtime ts
  rel="${file#"$repo_root"/}"
  size="$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || printf '0')"
  lines="$(wc -l < "$file" | tr -d ' ')"
  mtime="$(git -C "$repo_root" log -1 --format='%ct' -- "$rel" 2>/dev/null || stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || printf '0')"
  ts="$(date -r "$mtime" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@${mtime}" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '?')"
  local tracked=""
  git -C "$repo_root" ls-files --error-unmatch "$rel" >/dev/null 2>&1 || tracked=" [untracked]"
  printf '  - `%s` (%s bytes, %s lines, %s)%s\n' "$rel" "$size" "$lines" "$ts" "$tracked"
}

_inventory_entry_json() {
  local file="$1" repo_root="$2"
  local rel size lines mtime ts category
  rel="${file#"$repo_root"/}"
  size="$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || printf '0')"
  lines="$(wc -l < "$file" | tr -d ' ')"
  mtime="$(git -C "$repo_root" log -1 --format='%ct' -- "$rel" 2>/dev/null || stat -f%m "$file" 2>/dev/null || stat -c%Y "$file" 2>/dev/null || printf '0')"
  ts="$(date -r "$mtime" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -d "@${mtime}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf '')"
  category="$(_inventory_category "$rel")"
  local tracked="true"
  git -C "$repo_root" ls-files --error-unmatch "$rel" >/dev/null 2>&1 || tracked="false"
  printf '    {"path": "%s", "category": "%s", "size": %s, "lines": %s, "last_modified": "%s", "tracked": %s}' \
    "$rel" "$category" "$size" "$lines" "$ts" "$tracked"
}

_inventory_divergence() {
  local reported="$1" tracked="$2"
  if [ "$tracked" = "0" ]; then
    printf '100\n'
    return
  fi
  local diff
  diff=$(( reported - tracked ))
  [ "$diff" -lt 0 ] && diff=$(( -diff ))
  printf '%s\n' "$(( (diff * 100) / tracked ))"
}

_inventory_bucket_file() {
  # Phase 1: route one file into the appropriate scratch bucket.
  local scratch="$1" repo_root="$2" f="$3"
  local rel cat section_key skill_rest skill_name rest subgroup skill_dir
  rel="${f#"$repo_root"/}"
  cat="$(_inventory_category "$rel")"
  section_key="$(_inventory_section_key "$cat")"
  if [ "$section_key" = 'skills' ]; then
    skill_rest="${rel#.agents/skills/}"
    skill_name="${skill_rest%%/*}"
    rest="${skill_rest#*/}"
    subgroup="$(_inventory_skill_subgroup "$rest")"
    skill_dir="$scratch/skills/$skill_name"
    mkdir -p "$skill_dir"
    printf '%s\n' "$rel" >> "$skill_dir/${subgroup}.list"
  else
    printf '%s\n' "$rel" >> "$scratch/${section_key}.list"
  fi
}

_inventory_render_section() {
  # Render a single non-skills markdown section from its bucket list.
  local scratch="$1" repo_root="$2" key="$3" title="$4" desc="$5"
  local list_file="$scratch/${key}.list"
  [ -f "$list_file" ] || return 0
  printf '## %s\n%s\n\n' "$title" "$desc"
  sort "$list_file" | while IFS= read -r rel; do
    _inventory_entry_markdown "${repo_root}/${rel}" "$repo_root"
  done
  printf '\n'
}

_inventory_render_skills() {
  # Render the Skills section: per-skill description + files in canonical subgroup order.
  local scratch="$1" repo_root="$2"
  local skills_dir="$scratch/skills"
  [ -d "$skills_dir" ] || return 0
  printf '## Skills\n'
  printf 'Portable agent skills under .agents/skills/.

'
  local skill_dir skill_name desc subgroup sg_file rel skill_md_path
  while IFS= read -r skill_dir; do
    skill_name="${skill_dir##*/}"
    skill_md_path="$repo_root/.agents/skills/$skill_name/SKILL.md"
    printf '### %s\n' "$skill_name"
    if [ -f "$skill_md_path" ]; then
      desc="$(_inventory_skill_description "$skill_md_path" \
        ".agents/skills/$skill_name/SKILL.md")" || return 1
      printf '%s\n\n' "$desc"
    else
      printf '\n'
    fi
    for subgroup in skill_md references scripts tests other; do
      sg_file="$skill_dir/${subgroup}.list"
      [ -f "$sg_file" ] || continue
      sort "$sg_file" | while IFS= read -r rel; do
        _inventory_entry_markdown "${repo_root}/${rel}" "$repo_root"
      done
    done
    printf '\n'
  done < <(find "$skills_dir" -maxdepth 1 -mindepth 1 -type d | sort)
}

_inventory_render_markdown() {
  # Phase 2: emit all sections from the scratch buckets in canonical order.
  local scratch="$1" repo_root="$2" reported="$3" tracked="$4" div="$5" now="$6"
  printf '# goose-tools Repository Inventory\n\n'
  printf 'Generated: %s\n' "$now"
  printf 'Source: git-tracked + untracked files (excluding .git, __pycache__, .pyc, .DS_Store)\n\n'
  printf '## Summary\n\n'
  printf -- '- **Total files:** %s\n' "$reported"
  printf -- '- **Git-tracked:** %s\n' "$tracked"
  printf -- '- **Divergence:** %s%% (threshold: 5%%)\n\n' "$div"
  _inventory_render_section "$scratch" "$repo_root" 'project_root' 'Project Root' \
    'Root-level configuration, licensing, and dependency management.'
  _inventory_render_section "$scratch" "$repo_root" 'documentation' 'Documentation' \
    'Operator guides, reference docs, and workflow documentation in docs/.'
  _inventory_render_section "$scratch" "$repo_root" 'cli_scripts' 'CLI & Scripts' \
    'The `bin/goose-tools` CLI entry point and its `bin/commands/` subcommand modules.'
  _inventory_render_section "$scratch" "$repo_root" 'warp_drive_assets' 'Warp Drive Assets' \
    'Notebooks, workflow YAML manifests, and the paired runtime shell scripts under `warp/`.'
  _inventory_render_skills "$scratch" "$repo_root"
  _inventory_render_section "$scratch" "$repo_root" 'tests' 'Tests' \
    'Shell, bats, and other test suites in `tests/`.'
  _inventory_render_section "$scratch" "$repo_root" 'utilities' 'Utilities' \
    'Shared utility code under `utils/`.'
  _inventory_render_section "$scratch" "$repo_root" 'setup_scripts' 'Setup Scripts' \
    'Standalone setup/helper scripts in `scripts/`.'
  _inventory_render_section "$scratch" "$repo_root" 'cicd' 'CI/CD' \
    'GitHub Actions workflow, pre-commit configuration, and `.shellcheckrc`.'
  _inventory_render_section "$scratch" "$repo_root" 'other' 'Other' \
    'Everything that does not fit another section, including generated artifacts (`INVENTORY.md`, `TODO.md`).'
  printf -- '---\n\nLast Updated: %s @ %s\n' \
    "$(date '+%Y.%m.%d')" "$(date '+%H:%M:%S')"
}

cmd_inventory() {
  local json_mode=0
  [ "${OUTPUT_JSON}" = "1" ] && json_mode=1

  local repo_root
  repo_root="$(git -C "${GOOSE_TOOLS_ROOT}" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'error: not a git repository\n' >&2
    exit 1
  }

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$repo_root" -type f \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/.ruff_cache/*' \
    -not -path '*/.pytest_cache/*' \
    -not -path '*/.tox/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.mypy_cache/*' \
    -not -name '*.pyc' \
    -not -name '.DS_Store' \
    -print0 | sort -z)

  local tracked_count
  tracked_count="$(git -C "$repo_root" ls-files | wc -l | tr -d ' ')"
  local reported_count="${#files[@]}"
  local divergence
  divergence="$(_inventory_divergence "$reported_count" "$tracked_count")"

  if [ "$json_mode" = "1" ]; then
    printf '{\n  "generated_at": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '  "repo_root": "%s",\n' "$repo_root"
    printf '  "summary": {"total_files": %s, "tracked_files": %s, "divergence_percent": %s},\n' \
      "$reported_count" "$tracked_count" "$divergence"
    printf '  "files": [\n'
    local first=1
    for f in "${files[@]}"; do
      [ "$first" = "1" ] || printf ',\n'
      first=0
      _inventory_entry_json "$f" "$repo_root"
    done
    printf '\n  ]\n}\n'
  else
    local scratch now
    scratch="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${scratch}'" EXIT
    now="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    local f
    for f in "${files[@]}"; do
      _inventory_bucket_file "$scratch" "$repo_root" "$f"
    done
    _inventory_render_markdown "$scratch" "$repo_root" \
      "$reported_count" "$tracked_count" "$divergence" "$now" \
      > "${repo_root}/INVENTORY.md"
    rm -rf "$scratch"
  fi

  if [ "${FORCE}" != "1" ] && [ "$divergence" -gt 5 ]; then
    printf 'warning: inventory divergence is %s%% (>5%%). Run with --force to suppress.\n' "$divergence" >&2
    [ "$json_mode" = "1" ] || exit 1
  fi

  if [ "$json_mode" = "0" ]; then
    printf 'Inventory written to: %s/INVENTORY.md (%d files, %d tracked, %s%% divergence)\n' \
      "$repo_root" "$reported_count" "$tracked_count" "$divergence"
  fi
}
