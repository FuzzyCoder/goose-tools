#!/usr/bin/env bash
# Update repo subcommand for goose-tools.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

cmd_update_repo() {
  local target_path="${1:?usage: bin/goose-tools update repo <path>}"
  case "$target_path" in
    /*) ;;
    *) target_path="$(pwd)/${target_path}" ;;
  esac

  local manifest_path="${target_path}/.goose-tools-manifest.json"
  if [ ! -f "$manifest_path" ]; then
    printf 'error: no .goose-tools-manifest.json found in %s\n  Run: bin/goose-tools scaffold repo %s\n' \
      "$target_path" "$target_path" >&2
    exit 1
  fi

  # Parse manifest fields
  local version profile scaffolded_at
  version="$(grep -oE '"goose_tools_version"[[:space:]]*:[[:space:]]*"[^"]+"' \
    "$manifest_path" | awk -F'"' '{print $4}')"
  profile="$(grep -oE '"profile"[[:space:]]*:[[:space:]]*"[^"]+"' \
    "$manifest_path" | awk -F'"' '{print $4}')"
  scaffolded_at="$(grep -oE '"scaffolded_at"[[:space:]]*:[[:space:]]*"[^"]+"' \
    "$manifest_path" | awk -F'"' '{print $4}')"

  # v1.0 migration: no profile field → treat as python (broad-install semantics)
  if [ "$version" = "1.0" ] || [ -z "$profile" ]; then
    printf 'note: v1.0 manifest — treating as python profile; manifest will be rewritten to v1.1\n'
    profile="python"
  fi

  # Reject unknown profile values
  case "$profile" in
    python|core) ;;
    *)
      printf 'error: unknown profile in %s: %s\n  Valid profiles: python, core\n' \
        "$manifest_path" "$profile" >&2
      exit 1
      ;;
  esac

  printf 'Updating repo: %s (profile: %s)\n' "$target_path" "$profile"

  local dst_skills="${target_path}/.agents/skills"
  local skill_dir skill_name dst_skill_dir

  printf 'Refreshing installed skills and adding missing profile skills...\n'
  for skill_dir in "${GOOSE_TOOLS_ROOT}/.agents/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    dst_skill_dir="${dst_skills}/${skill_name}"

    if [ -d "$dst_skill_dir" ]; then
      # Already installed: refresh if clean, skip if locally modified
      if [ "${FORCE}" != "1" ] && skill_has_drift "${skill_dir%/}" "$dst_skill_dir"; then
        printf '  warning: skill "%s" has local drift — skipping (use --force to overwrite)\n' \
          "$skill_name"
        continue
      fi
      if [ "${DRY_RUN}" = "1" ]; then
        printf '  [DRY] refresh skill: %s\n' "$skill_name"
        continue
      fi
      rm -rf "$dst_skill_dir"
      cp -r "${skill_dir%/}" "$dst_skill_dir"
      printf '  refreshed skill: %s\n' "$skill_name"
    elif skill_in_profile "$skill_name" "$profile"; then
      # New canonical skill in the recorded profile: add it
      if [ "${DRY_RUN}" = "1" ]; then
        printf '  [DRY] add skill: %s\n' "$skill_name"
        continue
      fi
      cp -r "${skill_dir%/}" "$dst_skill_dir"
      printf '  added skill: %s\n' "$skill_name"
    fi
    # Skills installed but outside the profile are left in place (non-destructive)
  done

  # Rewrite manifest to v1.1 (preserve scaffolded_at verbatim)
  if [ "${DRY_RUN}" != "1" ]; then
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
      "${scaffolded_at}" "${GOOSE_TOOLS_ROOT}" "$profile" "$skills_json" > "$manifest_path"
    printf '  wrote manifest (v1.1): %s\n' "$manifest_path"
  fi

  printf 'Update complete. Run bin/goose-tools doctor to verify.\n'
}
