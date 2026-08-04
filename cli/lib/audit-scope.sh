# audit-scope.sh — Resolve what an audit-* skill should review, before any LLM call.
#
# Usage:
#   octopus.sh audit-scope <skill> [--base <ref>] [--ref <ref>]
#   octopus.sh audit-scope <skill> --write <key> --from <body-file> [--base <ref>] [--ref <ref>]
#
# Implements the three-path contract (RM-172). Every path prints a marker line so
# the caller — orchestrator or skill — can branch without parsing prose:
#
#   OCTOPUS_AUDIT_SCOPE=skip     no candidate files; do not dispatch, do not spend
#   OCTOPUS_AUDIT_SCOPE=cached   a prior report for this exact diff + skill; reuse it
#   OCTOPUS_AUDIT_SCOPE=scoped   dispatch, with the scoped diff that follows
#
# On the `scoped` path the caller must run the audit and then persist the result:
#   octopus audit-scope <skill> --write <key> --from <report-file>
#
# Exit status is 0 for all three resolved paths; non-zero means the resolution
# itself failed (unknown skill, not a git repo, no sha256 tool).

# `cli/octopus.sh` runs with `set -euo pipefail` and *sources* this file, so -e is
# inherited. This command reports outcomes through exit codes and markers — a
# non-zero return is data here, not a failure — and under -e the most common path
# (`skip`, when no files matched) would kill the shell before printing anything.
# Disable it explicitly; every status that matters is checked by hand below.
set +e
set -uo pipefail

AUDIT_SCOPE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./audit-prepass.sh
source "$AUDIT_SCOPE_LIB_DIR/audit-prepass.sh"
# shellcheck source=./audit-cache.sh
source "$AUDIT_SCOPE_LIB_DIR/audit-cache.sh"

_audit_scope_usage() {
  echo "Usage: octopus.sh audit-scope <skill> [--base <ref>] [--ref <ref>]"
  echo "       octopus.sh audit-scope <skill> --write <key> --from <body-file>"
}

SKILL="${1:-}"
shift 2>/dev/null || true

if [[ -z "$SKILL" || "$SKILL" == "-h" || "$SKILL" == "--help" ]]; then
  _audit_scope_usage
  exit 1
fi

BASE="main"
REF="HEAD"
WRITE_KEY=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --ref)  REF="${2:-}"; shift 2 ;;
    --write) WRITE_KEY="${2:-}"; shift 2 ;;
    --from) BODY_FILE="${2:-}"; shift 2 ;;
    *)
      echo "audit-scope: unknown argument '$1'" >&2
      _audit_scope_usage >&2
      exit 1
      ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "audit-scope: not a git repository" >&2
  exit 1
fi

# --- write path ------------------------------------------------------------

if [[ -n "$WRITE_KEY" ]]; then
  if [[ -z "$BODY_FILE" || ! -f "$BODY_FILE" ]]; then
    echo "audit-scope: --write requires --from <existing-file>" >&2
    exit 1
  fi
  audit_cache_write "$SKILL" "$WRITE_KEY" "$BODY_FILE" "$BASE" "$REF" || {
    echo "audit-scope: cache write failed" >&2
    exit 1
  }
  echo "OCTOPUS_AUDIT_SCOPE=written"
  echo "OCTOPUS_AUDIT_CACHE_KEY=$WRITE_KEY"
  exit 0
fi

# --- resolve path ----------------------------------------------------------

scoped_diff_file="$(mktemp)"
trap 'rm -f "$scoped_diff_file"' EXIT

# Capture the status directly — inside `if ! cmd`, $? is the negated test result,
# not the command's exit code, which would mask the "unresolvable skill" case.
audit_prepass_diff "$SKILL" "$BASE" "$REF" > "$scoped_diff_file" 2>/dev/null
rc=$?
if [[ $rc -ne 0 ]]; then
  if [[ $rc -eq 2 ]]; then
    echo "audit-scope: cannot resolve pre_pass patterns for '$SKILL'" >&2
    exit 2
  fi
  echo "OCTOPUS_AUDIT_SCOPE=skip"
  echo "reason: no ${SKILL#audit-} changes detected in ${BASE}..${REF}"
  exit 0
fi

CACHE_KEY="$(audit_cache_key "$SKILL" "$scoped_diff_file")" || {
  echo "audit-scope: cache key derivation failed" >&2
  exit 1
}

if cached="$(audit_cache_lookup "$SKILL" "$CACHE_KEY")"; then
  echo "OCTOPUS_AUDIT_SCOPE=cached"
  echo "OCTOPUS_AUDIT_CACHE_KEY=$CACHE_KEY"
  echo ""
  printf '%s\n' "$cached"
  exit 0
fi

echo "OCTOPUS_AUDIT_SCOPE=scoped"
echo "OCTOPUS_AUDIT_CACHE_KEY=$CACHE_KEY"
echo ""
cat "$scoped_diff_file"
