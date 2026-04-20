#!/usr/bin/env bash
# Regression test for the install_release version-mismatch bug.
# When `octopus install --version X` is requested and RELEASE_ROOT is a
# different version, the shim must NOT symlink X → RELEASE_ROOT. It must
# either download X or fail cleanly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="$SCRIPT_DIR/bin/octopus"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fake RELEASE_ROOT that looks like v1.0.0 (has cli/octopus.sh but no matching git tag).
mkdir -p "$tmp/release/cli"
printf '#!/usr/bin/env bash\necho "cli stub"\n' > "$tmp/release/cli/octopus.sh"
chmod +x "$tmp/release/cli/octopus.sh"

# Fake bin dir so the shim's SCRIPT_DIR/../cli/octopus.sh probe in _resolve_release_root resolves to our stub tree.
mkdir -p "$tmp/release/bin"
cp "$SHIM" "$tmp/release/bin/octopus"
chmod +x "$tmp/release/bin/octopus"

export OCTOPUS_CLI_CACHE_ROOT="$tmp/cli-cache"
# Point installer download at an endpoint that will fail — we're asserting the
# shim doesn't create a bogus symlink when it can't actually fetch the release.
export OCTOPUS_RELEASE_OWNER="nonexistent-owner-for-testing"
export OCTOPUS_RELEASE_NAME="no-such-repo"

echo "Test 1: install_release for version not matching RELEASE_ROOT must not create a bad symlink"
# Run the shim's `install --version v2.0.0`. Expect failure (installer can't fetch).
if "$tmp/release/bin/octopus" install --version v2.0.0 > "$tmp/out.log" 2>&1; then
  echo "FAIL: install succeeded against a nonexistent endpoint"
  cat "$tmp/out.log"
  exit 1
fi
# The target path must NOT exist as a symlink to the wrong tree.
target="$tmp/cli-cache/cache/v2.0.0"
if [[ -L "$target" ]]; then
  link_dest="$(readlink "$target")"
  if [[ "$link_dest" == "$tmp/release" ]]; then
    echo "FAIL: shim created a stale symlink $target -> $link_dest"
    exit 1
  fi
fi
echo "PASS: no bogus symlink created on failed download"

echo "Test 2: install_release when RELEASE_ROOT == target (self-install) succeeds"
unset OCTOPUS_RELEASE_OWNER OCTOPUS_RELEASE_NAME
# When RELEASE_ROOT IS already the target path, install must still work (mkdir + metadata).
bootstrap_cache="$tmp/bootstrap-cache"
bootstrap_target="$bootstrap_cache/cache/v9.9.9"
mkdir -p "$bootstrap_target/cli"
printf '#!/usr/bin/env bash\n' > "$bootstrap_target/cli/octopus.sh"
mkdir -p "$bootstrap_target/bin"
cp "$SHIM" "$bootstrap_target/bin/octopus"
chmod +x "$bootstrap_target/bin/octopus"

OCTOPUS_CLI_CACHE_ROOT="$bootstrap_cache" \
  "$bootstrap_target/bin/octopus" install --version v9.9.9 > "$tmp/out2.log" 2>&1 \
  || { echo "FAIL: self-install didn't succeed"; cat "$tmp/out2.log"; exit 1; }

[[ -d "$bootstrap_target" ]] || { echo "FAIL: bootstrap target missing"; exit 1; }
[[ -f "$bootstrap_cache/metadata.json" ]] || { echo "FAIL: metadata.json missing"; exit 1; }
echo "PASS: self-install bootstrap works"

echo ""
echo "All install_release tests passed."
