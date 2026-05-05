#!/usr/bin/env bash
# Scaffold repo subcommand for goose-tools.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

cmd_scaffold_repo() {
  local target_path="${1:?usage: bin/goose-tools scaffold repo <path> [python|core]}"
  local profile="${2:-}"

  # --profile-only: require explicit profile token; no default
  if [ "${PROFILE_ONLY}" = "1" ] && [ -z "$profile" ]; then
    printf 'error: --profile-only requires an explicit profile (python|core)\n' >&2
    exit 1
  fi
  [ -z "$profile" ] && profile="python"

  # Validate profile token
  case "$profile" in
    python|core) ;;
    *)
      printf 'error: unknown profile: %s\n  Valid profiles: python, core\n' "$profile" >&2
      exit 1
      ;;
  esac

  case "$target_path" in
    /*) ;;
    *) target_path="$(pwd)/${target_path}" ;;
  esac

  if [ ! -d "$target_path" ]; then
    printf 'error: target path does not exist: %s\n' "$target_path" >&2
    exit 1
  fi

  local repo_root="$target_path"
  local manifest_path="${target_path}/.goose-tools-manifest.json"

  if [ "${PROFILE_ONLY}" = "1" ]; then
    printf "Switching profile to '%s' (--profile-only): %s\n" "$profile" "$target_path"
  else
    printf 'Scaffolding into: %s (profile: %s)\n' "$target_path" "$profile"
    printf 'Enter placeholder values (press Enter to keep {{PLACEHOLDER}} for manual editing):\n'
    local PROJECT_NAME PACKAGE_NAME DOMAIN_DESCRIPTION
    printf 'PROJECT_NAME: '
    read -r PROJECT_NAME || PROJECT_NAME=""
    printf 'PACKAGE_NAME: '
    read -r PACKAGE_NAME || PACKAGE_NAME=""
    printf 'DOMAIN_DESCRIPTION: '
    read -r DOMAIN_DESCRIPTION || DOMAIN_DESCRIPTION=""

    [ -z "$PROJECT_NAME"       ] && PROJECT_NAME="{{PROJECT_NAME}}"
    [ -z "$PACKAGE_NAME"       ] && PACKAGE_NAME="{{PACKAGE_NAME}}"
    [ -z "$DOMAIN_DESCRIPTION" ] && DOMAIN_DESCRIPTION="{{DOMAIN_DESCRIPTION}}"

    scaffold_write() {
      local src="$1" dst="$2"
      if [ -f "$dst" ] && [ "${FORCE}" != "1" ]; then
        printf '  skip (exists): %s\n' "$dst"
        return 0
      fi
      if [ "${DRY_RUN}" = "1" ]; then
        printf '  [DRY] write: %s\n' "$dst"
        return 0
      fi
      mkdir -p "$(dirname "$dst")"
      sed \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{PACKAGE_NAME}}|${PACKAGE_NAME}|g" \
        -e "s|{{DOMAIN_DESCRIPTION}}|${DOMAIN_DESCRIPTION}|g" \
        -e "s|{{REPO_ROOT}}|${repo_root}|g" \
        "$src" > "$dst"
      printf '  wrote: %s\n' "$dst"
    }

    scaffold_write "${GOOSE_TOOLS_ROOT}/AGENTS.md" "${target_path}/AGENTS.md"
    [ -d "${target_path}/tests" ] && \
      scaffold_write "${GOOSE_TOOLS_ROOT}/tests/AGENTS.md" "${target_path}/tests/AGENTS.md"
    [ -d "${target_path}/utils" ] && \
      scaffold_write "${GOOSE_TOOLS_ROOT}/utils/AGENTS.md" "${target_path}/utils/AGENTS.md"
  fi

  # Install skills for the selected profile
  local dst_skills="${target_path}/.agents/skills"
  local skill_dir skill_name dst_skill_dir
  for skill_dir in "${GOOSE_TOOLS_ROOT}/.agents/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    dst_skill_dir="${dst_skills}/${skill_name}"
    skill_in_profile "$skill_name" "$profile" || continue
    if [ -d "$dst_skill_dir" ] && [ "${FORCE}" != "1" ]; then
      printf '  skip (exists): .agents/skills/%s/\n' "$skill_name"
      continue
    fi
    if [ "${DRY_RUN}" = "1" ]; then
      printf '  [DRY] install skill: %s\n' "$skill_name"
      continue
    fi
    cp -r "${skill_dir%/}" "$dst_skill_dir"
    printf '  wrote skill: .agents/skills/%s/\n' "$skill_name"
  done

  # Write v1.1 manifest
  if [ "${DRY_RUN}" != "1" ]; then
    local now scaffolded_at
    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
    # Preserve original scaffolded_at when switching profiles
    if [ "${PROFILE_ONLY}" = "1" ] && [ -f "$manifest_path" ]; then
      scaffolded_at="$(grep -oE '"scaffolded_at"[[:space:]]*:[[:space:]]*"[^"]+"' \
        "$manifest_path" | awk -F'"' '{print $4}')"
    fi
    [ -z "${scaffolded_at:-}" ] && scaffolded_at="$now"
    # Build sorted skills list from what is actually present after the run
    local skills_json="" sname
    while IFS= read -r sname; do
      [ -n "$skills_json" ] && skills_json="${skills_json},"
      skills_json="${skills_json}\"${sname}\""
    done < <(
      for sd in "${dst_skills}"/*/; do
        [ -d "$sd" ] && basename "$sd"
      done | LC_ALL=C sort
    )
    printf '{"goose_tools_version": "1.1", "scaffolded_at": "%s", "source": "%s", "profile": "%s", "skills": [%s]}\n' \
      "$scaffolded_at" "${GOOSE_TOOLS_ROOT}" "$profile" "$skills_json" > "$manifest_path"
    printf '  wrote manifest: %s\n' "$manifest_path"
  fi

  printf 'Scaffold complete.\n'
}
