#!/usr/bin/env bash
# Shared installation and manifest helpers for warp-tools.

# ---------------------------------------------------------------------------
# SHA256 helper
# ---------------------------------------------------------------------------
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    log_err 'no sha256sum or shasum found'
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Skill profile helpers
# ---------------------------------------------------------------------------

# skill_in_profile <skill_name> <profile>
# Returns 0 if the skill belongs to the given profile, 1 otherwise.
# python: every skill; core: shell/workflow skills only (no uv/ruff/pytest deps).
skill_in_profile() {
  local skill_name="$1" profile="$2"
  if [ "$profile" = "python" ]; then
    return 0
  fi
  # core allowlist: shell and workflow skills that need no Python tooling
  case "$skill_name" in
    agent-launcher|deploy-warp-tools|improve-shell-quality|list-warp-models|\
    manage-capabilities|manage-inventory|manage-plans|manage-todo|manage-worktrees|\
    plan-workflow|refactor-agent-instructions|review-plan|review-pr|sync-worktrees|\
    tune-agent-assets|write-skill)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# skill_has_drift <src_dir> <dst_dir>
# Returns 0 (true = drift detected) if any file in src_dir differs from
# the corresponding file in dst_dir (recursive, per-file SHA-256).
# Returns 1 (false = clean) if all files match.
skill_has_drift() {
  local src_dir="$1" dst_dir="$2"
  local f rel dst_file src_sha dst_sha
  while IFS= read -r f; do
    rel="${f#${src_dir}/}"
    dst_file="${dst_dir}/${rel}"
    if [ ! -f "$dst_file" ]; then
      return 0  # file present in source but missing in dest = drift
    fi
    src_sha="$(sha256_file "$f")"
    dst_sha="$(sha256_file "$dst_file")"
    if [ "$src_sha" != "$dst_sha" ]; then
      return 0  # hash mismatch = drift
    fi
  done < <(find "$src_dir" -type f | LC_ALL=C sort)
  return 1  # no drift
}

# ---------------------------------------------------------------------------
# Profile ID resolution
# ---------------------------------------------------------------------------
resolve_profile_id() {
  local name="$1"
  oz agent profile list 2>/dev/null \
    | python3 -c '
import sys
name = sys.argv[1]
for line in sys.stdin:
    if "\u2506" in line:
        parts = line.split("\u2506")
        if len(parts) >= 2:
            n = parts[1].strip().rstrip("\u2502").strip()
            if n == name:
                print(parts[0].strip().lstrip("\u2502").strip())
                break
' "$name" 2>/dev/null
}

# ---------------------------------------------------------------------------
# File installation with drift detection
# ---------------------------------------------------------------------------
install_file() {
  local src="$1" dst="$2" canonical="$3"
  local dst_dir
  dst_dir="$(dirname "$dst")"

  if [ "${DRY_RUN}" = "1" ]; then
    printf '  [DRY] install %s -> %s\n' "$canonical" "$dst"
    return 0
  fi

  if [ -f "$dst" ] && [ -f "${GLOBAL_MANIFEST}" ] && [ "${FORCE}" != "1" ]; then
    local recorded_hash
    recorded_hash=$(grep -A2 "\"path\": \"${dst}\"" "${GLOBAL_MANIFEST}" \
      | grep '"sha256"' | awk -F'"' '{print $4}' | head -1)
    if [ -n "$recorded_hash" ]; then
      local current_hash
      current_hash="$(sha256_file "$dst")"
      if [ "$current_hash" != "$recorded_hash" ]; then
        printf 'error: locally modified file: %s\n  Run with --force to overwrite\n' "$dst" >&2
        return 2
      fi
    fi
  fi

  mkdir -p "$dst_dir"
  cp "$src" "$dst"
}

# ---------------------------------------------------------------------------
# Manifest builder
# ---------------------------------------------------------------------------
MANIFEST_ENTRIES=""

manifest_add() {
  local entry
  entry="$(printf '    {"path": "%s", "canonical": "%s", "sha256": "%s"}' "$1" "$2" "$3")"
  if [ -z "${MANIFEST_ENTRIES}" ]; then
    MANIFEST_ENTRIES="${entry}"
  else
    MANIFEST_ENTRIES="${MANIFEST_ENTRIES}
,${entry}"
  fi
}

manifest_write() {
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
  printf '{\n  "warp_tools_version": "1.0",\n  "installed_at": "%s",\n  "repo": "%s",\n  "managed_files": [\n%s\n  ]\n}\n' \
    "${now}" "${WARP_TOOLS_ROOT}" "${MANIFEST_ENTRIES}" > "${GLOBAL_MANIFEST}"
}
