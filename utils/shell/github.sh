#!/usr/bin/env bash
# Shared GitHub API helpers for warp-tools.
#
# Provides authenticated GitHub API access with automatic canonical repo name
# resolution. All functions are pure (no global state mutation) and fail fast
# on invalid or missing inputs.
#
# Dependencies:
#   - curl       (HTTP client)
#   - gh         (GitHub CLI, for token resolution)
#   - python3    (JSON parsing)
#
# Usage:
#   source utils/shell/github.sh
#   token="$(gh_token)"
#   canonical="$(gh_canonical_repo "block/goose" "$token")"
#   gh_api "/repos/aaif-goose/goose" "$token"
#   gh_search_issues "theme in:title" "block/goose" "$token"

# ---------------------------------------------------------------------------
# gh_token
# ---------------------------------------------------------------------------
# Resolve a GitHub API token via the gh CLI.
#
# Does not accept a hardcoded token — always delegates to the gh credential
# store so secrets never appear in source code or shell history.
#
# Args:
#   None
#
# Returns:
#   Prints the token string to stdout.
#
# Exits:
#   1  if gh is not installed
#   1  if gh auth token returns an empty string (not logged in)
#
# Example:
#   token="$(gh_token)" || exit 1
gh_token() {
  if ! command -v gh >/dev/null 2>&1; then
    log_err "gh_token: gh CLI not found — install from https://cli.github.com"
    return 1
  fi

  local token
  token="$(gh auth token 2>/dev/null)"

  if [ -z "$token" ]; then
    log_err "gh_token: no active gh session — run: gh auth login"
    return 1
  fi

  printf '%s' "$token"
}

# ---------------------------------------------------------------------------
# gh_canonical_repo
# ---------------------------------------------------------------------------
# Resolve the canonical «owner/repo» name for a GitHub repository.
#
# The GitHub Search API rejects aliases (e.g. «block/goose» redirects to
# «aaif-goose/goose» on the web but causes a 422 in the API). This function
# calls /repos/{owner}/{repo} and extracts the «full_name» field, which is
# always canonical.
#
# Args:
#   $1  repo   — «owner/repo» slug to resolve (required)
#   $2  token  — GitHub API token (required; obtain via gh_token)
#
# Returns:
#   Prints «canonical_owner/canonical_repo» to stdout.
#
# Exits:
#   1  if repo or token argument is missing
#   1  if the API request fails or returns no full_name
#
# Example:
#   canonical="$(gh_canonical_repo "block/goose" "$token")"
#   # → aaif-goose/goose
gh_canonical_repo() {
  local repo="${1:-}"
  local token="${2:-}"

  if [ -z "$repo" ]; then
    log_err "gh_canonical_repo: missing required argument: repo"
    return 1
  fi
  if [ -z "$token" ]; then
    log_err "gh_canonical_repo: missing required argument: token"
    return 1
  fi

  # Use -L to follow HTTP 301 redirects — the GitHub API redirects aliased
  # repo slugs (e.g. block/goose → aaif-goose/goose) rather than resolving
  # them in-place. Without -L, curl returns an empty body and no full_name.
  local response canonical
  response="$(curl -sfL \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    "${GITHUB_API_BASE}/repos/${repo}" 2>/dev/null)"

  if [ -z "$response" ]; then
    log_err "gh_canonical_repo: API request failed for repo: ${repo}"
    return 1
  fi

  canonical="$(printf '%s' "$response" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('full_name',''))" 2>/dev/null)"

  if [ -z "$canonical" ]; then
    log_err "gh_canonical_repo: could not resolve canonical name for: ${repo}"
    return 1
  fi

  printf '%s' "$canonical"
}

# ---------------------------------------------------------------------------
# gh_api
# ---------------------------------------------------------------------------
# Make an authenticated GitHub API request.
#
# Wraps curl with the Authorization header and GitHub API content-type.
# Returns the raw JSON response body on stdout. Callers are responsible for
# parsing with python3 or jq.
#
# Args:
#   $1  path   — API path, e.g. /repos/owner/repo/issues (required)
#   $2  token  — GitHub API token (required; obtain via gh_token)
#   $3  query  — optional query string, e.g. "per_page=10&state=open"
#
# Returns:
#   Prints the raw JSON response to stdout.
#
# Exits:
#   1  if path or token argument is missing
#   1  if the curl request fails (non-2xx or network error)
#
# Example:
#   gh_api "/repos/aaif-goose/goose" "$token"
#   gh_api "/repos/aaif-goose/goose/issues" "$token" "state=open&per_page=5"
gh_api() {
  local path="${1:-}"
  local token="${2:-}"
  local query="${3:-}"

  if [ -z "$path" ]; then
    log_err "gh_api: missing required argument: path"
    return 1
  fi
  if [ -z "$token" ]; then
    log_err "gh_api: missing required argument: token"
    return 1
  fi

  local url="${GITHUB_API_BASE}${path}"
  if [ -n "$query" ]; then
    url="${url}?${query}"
  fi

  # Use -L to follow HTTP 301 redirects for aliased repo slugs.
  local response
  response="$(curl -sfL \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    "${url}" 2>/dev/null)"

  if [ -z "$response" ]; then
    log_err "gh_api: request failed: ${url}"
    return 1
  fi

  printf '%s' "$response"
}

# ---------------------------------------------------------------------------
# gh_search_issues
# ---------------------------------------------------------------------------
# Search GitHub issues with automatic canonical repo name resolution.
#
# Resolves the canonical repo name before constructing the search query,
# preventing the 422 Validation Failed error that occurs when the Search API
# receives a redirected/aliased repo slug.
#
# Args:
#   $1  query   — search qualifiers excluding repo: e.g. "theme in:title" (required)
#   $2  repo    — «owner/repo» slug; may be an alias (required)
#   $3  token   — GitHub API token (required; obtain via gh_token)
#   $4  limit   — max results per page, 1–100, default 10 (optional)
#
# Returns:
#   Prints the raw JSON search response to stdout.
#
# Exits:
#   1  if query, repo, or token is missing
#   1  if canonical resolution or the search request fails
#
# Example:
#   gh_search_issues "theme in:title" "block/goose" "$token" 5
#   gh_search_issues "custom theme is:open" "aaif-goose/goose" "$token"
gh_search_issues() {
  local query="${1:-}"
  local repo="${2:-}"
  local token="${3:-}"
  local limit="${4:-10}"

  if [ -z "$query" ]; then
    log_err "gh_search_issues: missing required argument: query"
    return 1
  fi
  if [ -z "$repo" ]; then
    log_err "gh_search_issues: missing required argument: repo"
    return 1
  fi
  if [ -z "$token" ]; then
    log_err "gh_search_issues: missing required argument: token"
    return 1
  fi

  # Validate limit is numeric and in range
  if ! printf '%s' "$limit" | grep -qE '^[0-9]+$' || [ "$limit" -lt 1 ] || [ "$limit" -gt 100 ]; then
    log_err "gh_search_issues: limit must be an integer between 1 and 100, got: ${limit}"
    return 1
  fi

  local canonical
  canonical="$(gh_canonical_repo "$repo" "$token")" || return 1

  local encoded_query
  encoded_query="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]+' repo:'+sys.argv[2]))" \
    "$query" "$canonical" 2>/dev/null)"

  if [ -z "$encoded_query" ]; then
    log_err "gh_search_issues: failed to encode query"
    return 1
  fi

  local response
  response="$(curl -sf \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    "${GITHUB_API_BASE}/search/issues?q=${encoded_query}&per_page=${limit}" 2>/dev/null)"

  if [ -z "$response" ]; then
    log_err "gh_search_issues: search request failed for query: ${query} repo: ${canonical}"
    return 1
  fi

  printf '%s' "$response"
}
