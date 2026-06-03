#!/usr/bin/env bash
# tests/test_doctor.sh
# RM-116 — `octopus doctor` as the health command. Read-only detection of the
# failure classes that actually bite: stale hook paths in settings.json
# (version-pinned cache paths that no longer exist) and broken cache symlinks.
# Hermetic: a fixture HOME + cache, network disabled via a dead API endpoint.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="$SCRIPT_DIR/bin/octopus"
PASS=0; FAIL=0
check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CACHE="$TMP/.octopus-cli"
mkdir -p "$CACHE/cache/v9.9.9"
cat > "$CACHE/metadata.json" <<JSON
{ "version": "v9.9.9", "checksum": "x", "installed_at": "now", "release_path": "$CACHE/cache/v9.9.9" }
JSON
# A broken symlink in the cache (rotten): target does not exist.
ln -s "$TMP/gone" "$CACHE/cache/v0.0.1"

run_doctor() {  # $1 = project dir
  ( cd "$1" && HOME="$TMP" OCTOPUS_CLI_CACHE_ROOT="$CACHE" \
      OCTOPUS_API_ENDPOINT="http://127.0.0.1:9/none" bash "$SHIM" doctor 2>&1 )
}

# --- project with a STALE hook (cache path that no longer exists) -----------
BADPROJ="$TMP/bad"; mkdir -p "$BADPROJ/.claude"
cat > "$BADPROJ/.claude/settings.json" <<JSON
{ "hooks": { "PostToolUse": [ { "matcher": "Write",
  "hooks": [ { "type": "command", "command": "$CACHE/cache/v0.0.0-gone/hooks/auto-format.sh", "id": "auto-format" } ] } ] } }
JSON
OUT_BAD="$(run_doctor "$BADPROJ")"
check "doctor still reports the installed version" grep -q "v9.9.9" <<<"$OUT_BAD"
check "doctor flags the stale hook path"           grep -qi "stale hook" <<<"$OUT_BAD"
check "doctor flags the broken cache symlink"      grep -qi "broken.*symlink\|stale.*cache" <<<"$OUT_BAD"

# --- project whose hook points at an EXISTING file (healthy) ---------------
GOODPROJ="$TMP/good"; mkdir -p "$GOODPROJ/.claude"
mkdir -p "$CACHE/cache/v9.9.9/hooks"
touch "$CACHE/cache/v9.9.9/hooks/auto-format.sh"
cat > "$GOODPROJ/.claude/settings.json" <<JSON
{ "hooks": { "PostToolUse": [ { "matcher": "Write",
  "hooks": [ { "type": "command", "command": "$CACHE/cache/v9.9.9/hooks/auto-format.sh", "id": "auto-format" } ] } ] } }
JSON
OUT_GOOD="$(run_doctor "$GOODPROJ")"
check "healthy hook is not flagged as stale" bash -c "! grep -qi 'stale hook.*v9.9.9/hooks/auto-format' <<<\"\$1\"" _ "$OUT_GOOD"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
