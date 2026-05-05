#!/usr/bin/env bash
# Slot management subcommands for goose-tools.

# shellcheck source=utils/shell/logging.sh
# shellcheck source=utils/shell/paths.sh
# shellcheck source=utils/shell/common.sh

cmd_slot_clear() {
  local slot="${1:?usage: bin/goose-tools slot clear <slot>}"
  local slot_dir="${STATE_DIR}/${slot}"

  if [ ! -d "$slot_dir" ]; then
    printf 'Slot "%s" does not exist (nothing to clear).\n' "$slot"
    return 0
  fi

  if [ "${DRY_RUN}" = "1" ]; then
    printf '[DRY] Would remove: %s\n' "$slot_dir"
    return 0
  fi

  printf 'About to REMOVE slot directory:\n  %s\n' "$slot_dir"
  printf 'Files inside:\n'
  find "$slot_dir" -maxdepth 1 -not -path "$slot_dir" | sed 's|^  ||' | sed 's/^/  /'
  printf 'Confirm? [y/N] '
  read -r confirm || confirm="n"
  case "$confirm" in
    [yY]|[yY][eE][sS])
      rm -rf "$slot_dir"
      printf 'Slot "%s" cleared.\n' "$slot"
      ;;
    *)
      printf 'Aborted.\n'
      ;;
  esac
}

cmd_slot_archive() {
  local slot="${1:?usage: bin/goose-tools slot archive <slot>}"
  local slot_dir="${STATE_DIR}/${slot}"
  local today archive_dir
  today="$(date '+%Y-%m-%d')"
  archive_dir="${STATE_DIR}/archive/${today}-${slot}"

  if [ ! -d "$slot_dir" ]; then
    printf 'error: slot "%s" does not exist\n' "$slot" >&2
    exit 1
  fi

  if [ "${DRY_RUN}" = "1" ]; then
    printf '[DRY] Would move: %s -> %s\n' "$slot_dir" "$archive_dir"
    return 0
  fi

  mkdir -p "${STATE_DIR}/archive"
  mv "$slot_dir" "$archive_dir"
  printf 'Slot "%s" archived to:\n  %s\n' "$slot" "$archive_dir"
}
