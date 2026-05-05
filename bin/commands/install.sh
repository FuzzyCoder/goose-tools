#!/usr/bin/env bash
# Install globals subcommand for goose-tools.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

cmd_install_globals() {
  printf 'Installing goose-tools globals from: %s\n' "${GOOSE_TOOLS_ROOT}"

  # -------------------------------------------------------------------------
  # Verify prerequisites
  # -------------------------------------------------------------------------
  if ! command -v uuidgen >/dev/null 2>&1; then
    printf 'error: uuidgen not found — required for plan ID generation\n' >&2
    exit 3
  fi

  if [ "${DRY_RUN}" = "1" ]; then
    printf '[DRY RUN] Would write recipes.env, install scripts, set GOOSE_RECIPE_PATH. No changes made.\n'
    return 0
  fi

  mkdir -p "${STATE_DIR}"
  mkdir -p "${GLOBAL_SCRIPTS_DIR}"
  mkdir -p "${GLOBAL_SKILLS_DIR}"

  # -------------------------------------------------------------------------
  # Write recipes.env
  # Records resolved recipe paths sourced by goose_pw_*.sh scripts.
  # GOOSE_RECIPE_PATH points Goose at goose/recipes/ for `goose run --recipe`.
  # -------------------------------------------------------------------------
  {
    printf '# goose-tools managed — do not edit locally\n'
    printf 'GOOSE_TOOLS_ROOT=%s\n' "${GOOSE_TOOLS_ROOT}"
    printf 'PLANNER_RECIPE=%s/goose/recipes/planner/recipe.yaml\n'  "${GOOSE_TOOLS_ROOT}"
    printf 'REVIEWER_RECIPE=%s/goose/recipes/reviewer/recipe.yaml\n' "${GOOSE_TOOLS_ROOT}"
    printf 'APPROVER_RECIPE=%s/goose/recipes/approver/recipe.yaml\n' "${GOOSE_TOOLS_ROOT}"
    printf 'CODER_RECIPE=%s/goose/recipes/coder/recipe.yaml\n'       "${GOOSE_TOOLS_ROOT}"
  } > "${RECIPES_ENV}"
  printf 'Wrote: %s\n' "${RECIPES_ENV}"

  # -------------------------------------------------------------------------
  # Write GOOSE_RECIPE_PATH to ~/.zshenv
  # Enables `goose run --recipe planner` to resolve without a local install.
  # -------------------------------------------------------------------------
  local zshenv="${HOME}/.zshenv"
  local recipe_path_line="export GOOSE_RECIPE_PATH=\"${GOOSE_TOOLS_ROOT}/goose/recipes\""
  if grep -qF "GOOSE_RECIPE_PATH" "$zshenv" 2>/dev/null; then
    printf 'GOOSE_RECIPE_PATH already set in %s — skipping\n' "$zshenv"
  else
    printf '\n# goose-tools: recipe discovery\n%s\n' "$recipe_path_line" >> "$zshenv"
    printf 'Added GOOSE_RECIPE_PATH to %s\n' "$zshenv"
  fi

  # -------------------------------------------------------------------------
  # Install runtime workflow scripts
  # -------------------------------------------------------------------------
  for src_file in "${GOOSE_TOOLS_ROOT}/goose/workflows/scripts"/goose_pw_*.sh; do
    [ -f "$src_file" ] || continue
    local fname canonical dst sha
    fname="$(basename "$src_file")"
    canonical="goose/workflows/scripts/${fname}"
    dst="${GLOBAL_SCRIPTS_DIR}/${fname}"
    install_file "$src_file" "$dst" "$canonical"
    chmod +x "$dst"
    sha="$(sha256_file "$dst")"
    manifest_add "$dst" "$canonical" "$sha"
    printf 'Installed script: %s\n' "$fname"
  done

  # -------------------------------------------------------------------------
  # Install portable skills
  # -------------------------------------------------------------------------
  for skill_dir in "${GOOSE_TOOLS_ROOT}/.agents/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    local skill_name dst_dir
    skill_name="$(basename "$skill_dir")"
    dst_dir="${GLOBAL_SKILLS_DIR}/${skill_name}"
    if [ "${FORCE}" = "1" ] || [ ! -d "$dst_dir" ]; then
      rm -rf "$dst_dir"
      cp -r "${skill_dir%/}" "$dst_dir"
      printf 'Installed skill: %s\n' "$skill_name"
    else
      if skill_has_drift "${skill_dir%/}" "$dst_dir"; then
        printf 'warning: skill "%s" has local drift — skipping (use --force to overwrite)\n' "$skill_name"
        continue
      fi
      cp -r "${skill_dir%/}" "$dst_dir"
      printf 'Refreshed skill: %s\n' "$skill_name"
    fi
    local canonical sha
    canonical=".agents/skills/${skill_name}/SKILL.md"
    sha="$(sha256_file "${dst_dir}/SKILL.md" 2>/dev/null || printf 'n/a')"
    manifest_add "${dst_dir}/SKILL.md" "$canonical" "$sha"
  done

  manifest_write
  printf 'Wrote manifest: %s\n' "${GLOBAL_MANIFEST}"
  printf '\nInstall complete.\n'
  printf 'Reload your shell (or run: source ~/.zshenv) to activate GOOSE_RECIPE_PATH.\n'
  printf 'Then verify: goose run --recipe planner --explain\n'
}
