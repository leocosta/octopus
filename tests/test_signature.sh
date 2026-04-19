#!/usr/bin/env bash
set -euo pipefail

# Exercises the GPG signature verification path in install.sh.
# - Generates an ephemeral GPG keyring + key
# - Signs a minimal release tarball + sha256
# - Installs with OCTOPUS_GPG_KEYRING pointing at the ephemeral keyring
# - Flips the signature byte and asserts the installer refuses to proceed

if ! command -v gpg &>/dev/null; then
  echo "SKIP: gpg not installed on this host"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
TMP_HOME="$(mktemp -d)"
cleanup() {
  # Best-effort: gpg-agent may still hold the GNUPGHOME open briefly.
  gpgconf --homedir "$TMP_HOME/gnupg" --kill gpg-agent 2>/dev/null || true
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

export HOME="$TMP_HOME"
export GNUPGHOME="$TMP_HOME/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

VERSION="v0.14.0"
TMP_RELEASES="$TMP_HOME/releases"
TMP_BUILD="$TMP_HOME/build"
TMP_BIN="$TMP_HOME/bin"
mkdir -p "$TMP_BIN" "$TMP_RELEASES" "$TMP_BUILD" "$TMP_RELEASES/$VERSION"

echo "Setup: generate ephemeral release signing key"
cat > "$GNUPGHOME/keygen.batch" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: Octopus Test Signing
Name-Email: test-signing@octopus.local
Expire-Date: 0
%commit
EOF
gpg --batch --quiet --gen-key "$GNUPGHOME/keygen.batch" 2>/dev/null

KEYRING="$TMP_HOME/trusted-keyring.gpg"
gpg --batch --quiet --export > "$KEYRING"

echo "Setup: build and sign a minimal release tarball"
mkdir -p "$TMP_BUILD/octopus-$VERSION"
rsync -a --exclude '.git' --exclude 'tests' "$SCRIPT_DIR"/ "$TMP_BUILD/octopus-$VERSION"/
tar -czf "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz" -C "$TMP_BUILD" "octopus-$VERSION"
(cd "$TMP_RELEASES/$VERSION" && sha256sum "octopus-$VERSION.tar.gz" > "octopus-$VERSION.sha256")
gpg --batch --quiet --detach-sign --armor \
    --output "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz.asc" \
    "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz"

export OCTOPUS_INSTALL_ENDPOINT="file://$TMP_RELEASES"
export OCTOPUS_GPG_KEYRING="$KEYRING"

echo "Test 1: install succeeds with a valid signature and a trusted keyring"
bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli" >/dev/null
[[ -f "$TMP_HOME/.octopus-cli/metadata.json" ]] || { echo "FAIL: metadata missing after install"; exit 1; }
echo "PASS: valid signature accepted"

echo "Test 2: install fails when the tarball does not match the signature"
# Tamper with the tarball (and regenerate its sha256 so SHA256 check still passes
# and we isolate the signature check failure).
printf 'tampered' >> "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz"
(cd "$TMP_RELEASES/$VERSION" && sha256sum "octopus-$VERSION.tar.gz" > "octopus-$VERSION.sha256")
rm -rf "$TMP_HOME/.octopus-cli"
if bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli" >/dev/null 2>&1; then
  echo "FAIL: installer accepted a tampered tarball whose signature no longer matches"; exit 1
fi
echo "PASS: tampered tarball rejected"

echo "Test 3: OCTOPUS_SKIP_SIGNATURE=1 bypasses verification"
# Rebuild a valid tarball but leave the old .asc behind — gpg --verify would
# reject it. With SKIP=1 the installer must proceed regardless.
rm -f "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz" "$TMP_RELEASES/$VERSION/octopus-$VERSION.sha256"
tar -czf "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz" -C "$TMP_BUILD" "octopus-$VERSION"
(cd "$TMP_RELEASES/$VERSION" && sha256sum "octopus-$VERSION.tar.gz" > "octopus-$VERSION.sha256")
rm -rf "$TMP_HOME/.octopus-cli"
OCTOPUS_SKIP_SIGNATURE=1 bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli" >/dev/null
[[ -f "$TMP_HOME/.octopus-cli/metadata.json" ]] || { echo "FAIL: metadata missing after bypass install"; exit 1; }
echo "PASS: skip flag honored"

echo "Test 4: OCTOPUS_REQUIRE_SIGNATURE=1 fails when no .asc is published"
rm "$TMP_RELEASES/$VERSION/octopus-$VERSION.tar.gz.asc"
rm -rf "$TMP_HOME/.octopus-cli"
if OCTOPUS_REQUIRE_SIGNATURE=1 bash "$INSTALL_SCRIPT" --version "$VERSION" --bin-dir "$TMP_BIN" --cache-root "$TMP_HOME/.octopus-cli" >/dev/null 2>&1; then
  echo "FAIL: REQUIRE_SIGNATURE did not enforce presence"; exit 1
fi
echo "PASS: missing signature rejected when required"

echo "PASS: signature verification end-to-end"
