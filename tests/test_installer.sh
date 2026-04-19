#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
TMP_HOME="$(mktemp -d)"
TMP_RELEASES="$TMP_HOME/releases"
TMP_BUILD="$TMP_HOME/build"
TMP_BIN="$TMP_HOME/bin"
VERSION="v0.14.0"
cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

export HOME="$TMP_HOME"

mkdir -p "$TMP_BIN" "$TMP_RELEASES" "$TMP_BUILD" "$TMP_RELEASES/$VERSION"

mkdir -p "$TMP_BUILD/octopus-$VERSION"
rsync -a --exclude '.git' "$SCRIPT_DIR"/ "$TMP_BUILD/octopus-$VERSION"/
tar -czf "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz" -C "$TMP_BUILD" "octopus-$VERSION"
(cd "$TMP_RELEASES/$VERSION" && sha256sum "octopus-$VERSION.tar.gz" > "octopus-$VERSION.sha256")

export OCTOPUS_INSTALL_ENDPOINT="file://$TMP_RELEASES"

echo "Test: installer populates cache and shim"
bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli"
[[ -f "$TMP_BIN/octopus" ]]
$TMP_BIN/octopus doctor >/dev/null
[[ -f "$HOME/.octopus-cli/metadata.json" ]]

echo "Test: checksum in metadata matches the downloaded tarball"
expected_checksum="$(awk '{print $1}' "$TMP_RELEASES/$VERSION/octopus-$VERSION.sha256")"
actual_checksum="$(grep -o '"checksum"[[:space:]]*:[[:space:]]*"[^"]*"' "$HOME/.octopus-cli/metadata.json" | sed -E 's/.*"([^"]+)"$/\1/')"
[[ "$expected_checksum" == "$actual_checksum" ]] || {
  echo "FAIL: checksum mismatch — metadata has '$actual_checksum', expected '$expected_checksum'" >&2
  exit 1
}

echo "PASS: installer works"

echo "Test: cache dir gets a .cache-sha256 marker"
CACHE_DIR="$HOME/.octopus-cli/cache/$VERSION"
[[ -f "$CACHE_DIR/.cache-sha256" ]] \
  || { echo "FAIL: .cache-sha256 marker not written"; exit 1; }
marker_value="$(cat "$CACHE_DIR/.cache-sha256")"
[[ "$marker_value" == "$expected_checksum" ]] \
  || { echo "FAIL: marker '$marker_value' != expected '$expected_checksum'"; exit 1; }
echo "PASS: marker file written with correct checksum"

echo "Test: corrupted cache is purged and re-extracted"
# Corrupt the cache: keep the dir but change the marker to a wrong value
echo "0000000000000000000000000000000000000000000000000000000000000000" > "$CACHE_DIR/.cache-sha256"
# Touch a canary file that wouldn't exist in a fresh extraction
touch "$CACHE_DIR/.corrupted-canary"

bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli"

[[ ! -f "$CACHE_DIR/.corrupted-canary" ]] \
  || { echo "FAIL: corrupted cache was NOT purged (canary still present)"; exit 1; }
marker_after="$(cat "$CACHE_DIR/.cache-sha256")"
[[ "$marker_after" == "$expected_checksum" ]] \
  || { echo "FAIL: marker after re-install '$marker_after' != expected '$expected_checksum'"; exit 1; }
echo "PASS: corrupted cache auto-recovered via integrity check"

echo "Test: healthy cache is reused (no redundant download)"
# Second run with valid marker should reuse the cache.
# We detect reuse by checking that the 'Downloading' message is absent.
second_run="$(bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli" 2>&1)"
if echo "$second_run" | grep -q "Downloading Octopus"; then
  echo "FAIL: healthy cache triggered a redundant download" >&2
  exit 1
fi
echo "PASS: healthy cache reused"

echo "Test: --force always re-downloads even when cache is healthy"
forced_run="$(bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli" --force 2>&1)"
echo "$forced_run" | grep -q "Downloading Octopus" \
  || { echo "FAIL: --force did not trigger a fresh download"; exit 1; }
echo "PASS: --force bypasses cache"
