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

# --- the `current` link (RM-188) -------------------------------------------
# Hook commands now resolve through <cache root>/current, so the link is a
# single point of failure for every hook in every project. It sits outside
# cache/, where _doctor_broken_symlinks walks, and needs its own check.

# No link at all.
OUT_NOLINK="$(run_doctor "$GOODPROJ")"
check "doctor flags a missing 'current' link" grep -q "current is missing" <<<"$OUT_NOLINK"

# Link naming a release other than the installed one — the silent
# wrong-version execution the shim fix prevents going forward. Uses a real
# directory: a link to the fixture's rotten entry is reported as dangling
# (correctly) and never reaches the version comparison.
mkdir -p "$CACHE/cache/v1.1.1"
ln -s "$CACHE/cache/v1.1.1" "$CACHE/current"
OUT_WRONG="$(run_doctor "$GOODPROJ")"
check "doctor flags 'current' pointing at another release" \
  grep -q "but the installed version is v9.9.9" <<<"$OUT_WRONG"

# Link naming the installed release — healthy.
rm -f "$CACHE/current"; ln -s "$CACHE/cache/v9.9.9" "$CACHE/current"
OUT_OK="$(run_doctor "$GOODPROJ")"
check "healthy 'current' link is not flagged" \
  bash -c "! grep -q 'current' <<<\"\$1\"" _ "$OUT_OK"

# Dev-checkout layout: cache/<version> is itself a symlink to a working tree,
# so the resolved path is the tree and a basename comparison would flag every
# developer. Must stay quiet.
DEVTREE="$TMP/devtree"; mkdir -p "$DEVTREE/hooks"
rm -rf "$CACHE/cache/v9.9.9" "$CACHE/current"
ln -s "$DEVTREE" "$CACHE/cache/v9.9.9"
ln -s "$CACHE/cache/v9.9.9" "$CACHE/current"
OUT_DEV="$(run_doctor "$GOODPROJ")"
check "dev-checkout layout does not trip the 'current' check" \
  bash -c "! grep -q 'but the installed version is' <<<\"\$1\"" _ "$OUT_DEV"

# --- the stale-hook check must survive the move to `current` (RM-188) -------
# It matches on `.octopus-cli/`, not `.octopus-cli/cache/`: a pattern scoped to
# the versioned layout would have gone blind the moment hooks started being
# delivered through the link, silently retiring the check that diagnoses this
# exact failure.
CURPROJ="$TMP/curproj"; mkdir -p "$CURPROJ/.claude"
cat > "$CURPROJ/.claude/settings.json" <<JSON
{ "hooks": { "PostToolUse": [ { "matcher": "Write",
  "hooks": [ { "type": "command", "command": "$CACHE/current/hooks/post-tool-use/gone.sh", "id": "auto-format" } ] } ] } }
JSON
OUT_CUR="$(run_doctor "$CURPROJ")"
check "doctor flags a stale hook delivered through 'current'" \
  grep -qi "stale hook" <<<"$OUT_CUR"

# A hook under 'current' that DOES resolve stays quiet.
mkdir -p "$DEVTREE/hooks/post-tool-use"; touch "$DEVTREE/hooks/post-tool-use/gone.sh"
OUT_CUR_OK="$(run_doctor "$CURPROJ")"
check "a resolving hook under 'current' is not flagged" \
  bash -c "! grep -qi 'stale hook' <<<\"\$1\"" _ "$OUT_CUR_OK"

# --- a pinned repo must not make the global link look wrong ----------------
# resolve_version() is lockfile-first and therefore project-scoped, while
# `current` is global; comparing the two would report a correct link as broken
# in every repo pinned to another release.
mkdir -p "$CURPROJ/.octopus"
# The pinned version needs a real cache entry, otherwise the check returns
# early on "release dir missing" and the test would pass without discriminating.
mkdir -p "$CACHE/cache/v1.2.3"
printf 'version: v1.2.3\nchecksum: x\n' > "$CURPROJ/.octopus/cli-lock.yaml"
OUT_PINNED="$(run_doctor "$CURPROJ")"
check "a repo pinned to another version does not trip the 'current' check" \
  bash -c "! grep -q 'but the installed version is' <<<\"\$1\"" _ "$OUT_PINNED"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
