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
