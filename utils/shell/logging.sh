#!/usr/bin/env bash
# Common shell logging helpers for warp-tools.

# Shared log helpers
log_info() { printf '%s\n' "$1"; }
log_warn() { printf 'warning: %s\n' "$1" >&2; }
log_err()  { printf 'error: %s\n' "$1" >&2; }
