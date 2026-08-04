#!/usr/bin/env bash
# cli/lib/audit-cache.sh — Deterministic output cache for audit-* skills.
#
# Compiles the protocol previously described in skills/_shared/audit-cache.md
# (RM-172). The key derivation is byte-compatible with the prose version, so
# entries written before this change still hit.
#
# Public API:
#   audit_cache_key <skill> <scoped-diff-file>        → prints the 64-char key
#   audit_cache_lookup <skill> <key>                  → prints the cached body
#                                                       exit 1 = miss
#   audit_cache_write <skill> <key> <body-file> [base] [ref]
#                                                     → writes the cache entry
#   audit_cache_path <skill> <key>                    → prints the entry path
#
# Sourced by the review orchestrator, by audit-* skills invoked standalone, and
# from tests. Sourcing has no side effects.

AUDIT_CACHE_OCTOPUS_DIR="${AUDIT_CACHE_OCTOPUS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# Cache lives in the repo under review (cwd), not in the Octopus install.
AUDIT_CACHE_ROOT="${AUDIT_CACHE_ROOT:-.octopus/cache}"

# ---------------------------------------------------------------------------
# _audit_cache_sha256
# Reads stdin, prints the hex digest.
#
# The prose protocol hardcoded `sha256sum`, which is absent on stock macOS and on
# some Windows git-bash installs — a latent break, since install.ps1 is a
# supported path. Resolve whatever is available instead.
# ---------------------------------------------------------------------------
#
# AUDIT_CACHE_HASH_TOOL pins the implementation (sha256sum|shasum|openssl); all
# three must yield the same digest, which is what keeps a cache written on Linux
# readable on macOS. Tests assert that equality.
_audit_cache_hash_tool() {
  local tool="${AUDIT_CACHE_HASH_TOOL:-}"

  if [[ -n "$tool" ]]; then
    command -v "$tool" >/dev/null 2>&1 || {
      echo "audit-cache: AUDIT_CACHE_HASH_TOOL=$tool not found" >&2
      return 1
    }
    printf '%s' "$tool"
    return 0
  fi

  local candidate
  for candidate in sha256sum shasum openssl; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  echo "audit-cache: no sha256 implementation found (tried sha256sum, shasum, openssl)" >&2
  return 1
}

_audit_cache_sha256() {
  local tool
  tool="$(_audit_cache_hash_tool)" || return 1

  case "$tool" in
    sha256sum) sha256sum | cut -c1-64 ;;
    shasum)    shasum -a 256 | cut -c1-64 ;;
    openssl)   openssl dgst -sha256 | awk '{print $NF}' | cut -c1-64 ;;
  esac
}

_audit_cache_skill_file() {
  echo "$AUDIT_CACHE_OCTOPUS_DIR/skills/${1}/SKILL.md"
}

# ---------------------------------------------------------------------------
# audit_cache_key <skill> <scoped-diff-file>
# key = sha256( scoped_diff || sha256(SKILL.md) )
# Trailing newlines are stripped from the diff to match the prose version, which
# interpolated a shell variable (command substitution drops them).
# ---------------------------------------------------------------------------
audit_cache_key() {
  local skill="$1" diff_file="$2"
  local skill_file skill_hash scoped_diff

  skill_file="$(_audit_cache_skill_file "$skill")"
  [[ -f "$skill_file" ]] || return 2
  [[ -f "$diff_file" ]] || return 2

  skill_hash="$(_audit_cache_sha256 < "$skill_file")" || return 1
  scoped_diff="$(cat "$diff_file")"

  printf '%s%s' "$scoped_diff" "$skill_hash" | _audit_cache_sha256
}

audit_cache_path() {
  printf '%s/%s/%s.md' "$AUDIT_CACHE_ROOT" "$1" "$2"
}

# ---------------------------------------------------------------------------
# audit_cache_lookup <skill> <key>
# Prints the cached body with the YAML frontmatter stripped. Exit 1 on miss.
# ---------------------------------------------------------------------------
audit_cache_lookup() {
  local file
  file="$(audit_cache_path "$1" "$2")"
  [[ -f "$file" ]] || return 1

  # Strip the frontmatter and the blank line that separates it from the body, so
  # the output is byte-identical to what the audit originally printed.
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    NR == 1 { body = 1 }
    infm && /^---[[:space:]]*$/ { infm = 0; body = 1; skipblank = 1; next }
    infm { next }
    body {
      if (skipblank && $0 ~ /^[[:space:]]*$/) next
      skipblank = 0
      print
    }
  ' "$file"
}

# ---------------------------------------------------------------------------
# audit_cache_write <skill> <key> <body-file> [base] [ref]
# ---------------------------------------------------------------------------
audit_cache_write() {
  local skill="$1" key="$2" body_file="$3" base="${4:-}" ref="${5:-}"
  local file dir

  [[ -f "$body_file" ]] || return 2

  file="$(audit_cache_path "$skill" "$key")"
  dir="$(dirname "$file")"
  mkdir -p "$dir" || return 1

  {
    printf -- '---\n'
    printf 'skill: %s\n' "$skill"
    printf 'ref: %s\n' "$ref"
    printf 'base: %s\n' "$base"
    printf 'created_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '---\n\n'
    cat "$body_file"
  } > "$file" || return 1

  _audit_cache_gitignore_guard
}

# ---------------------------------------------------------------------------
# _audit_cache_gitignore_guard
# Ensures .octopus/cache/ is ignored. Warns but never aborts.
# ---------------------------------------------------------------------------
_audit_cache_gitignore_guard() {
  local ignore=".gitignore" entry=".octopus/cache/"

  if [[ -f "$ignore" ]] && grep -qF "$entry" "$ignore"; then
    return 0
  fi

  if ! printf '%s\n' "$entry" >> "$ignore" 2>/dev/null; then
    echo "audit-cache: could not write $ignore — add '$entry' manually" >&2
  fi
  return 0
}
