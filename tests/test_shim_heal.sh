#!/usr/bin/env bash
# Regression test for install.sh healing a stale shim under --no-shim-setup.
# `octopus update` (even from an old CLI that predates sync_shim) re-fetches
# install.sh fresh from main and runs it with --no-shim-setup. The installer
# must refresh an existing stale shim on a FORWARD version move, but must NOT
# downgrade the shim when a pinned-older version is backfilled.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

endpoint="$tmp/releases"
bin="$tmp/bin"
cache="$tmp/.octopus-cli"
mkdir -p "$bin"
export OCTOPUS_INSTALL_ENDPOINT="file://$endpoint"

# Build a minimal release tarball whose bin/octopus carries a unique marker.
make_release() {
  local version="$1" marker="$2"
  local build="$tmp/build-$version/octopus-$version"
  mkdir -p "$build/bin" "$build/cli"
  printf '#!/usr/bin/env bash\n# %s\necho %s\n' "$marker" "$marker" > "$build/bin/octopus"
  chmod +x "$build/bin/octopus"
  printf '#!/usr/bin/env bash\necho cli\n' > "$build/cli/octopus.sh"
  chmod +x "$build/cli/octopus.sh"
  mkdir -p "$endpoint/$version"
  tar -czf "$endpoint/$version/octopus-$version.tar.gz" -C "$tmp/build-$version" "octopus-$version"
  ( cd "$endpoint/$version" && sha256sum "octopus-$version.tar.gz" > "octopus-$version.sha256" )
}

run_install() { # version, extra args...
  local version="$1"; shift
  bash "$INSTALL_SCRIPT" --version "$version" \
    --bin-dir "$bin" --cache-root "$cache" --force "$@"
}

make_release v9.9.8 "OLD-9.9.8"
make_release v9.9.9 "NEW-9.9.9"

echo "Test 1: a normal install plants the v9.9.9 shim"
run_install v9.9.9 > "$tmp/out1.log" 2>&1 || { echo "FAIL: install"; cat "$tmp/out1.log"; exit 1; }
grep -q "NEW-9.9.9" "$bin/octopus" || { echo "FAIL: shim is not the v9.9.9 release"; exit 1; }
echo "PASS"

echo "Test 2: --no-shim-setup heals a stale shim on a same/forward version"
printf '#!/usr/bin/env bash\n# STALE\n' > "$bin/octopus"   # simulate a pre-fix shim
run_install v9.9.9 --no-shim-setup > "$tmp/out2.log" 2>&1 || { echo "FAIL: heal install"; cat "$tmp/out2.log"; exit 1; }
grep -q "NEW-9.9.9" "$bin/octopus" || { echo "FAIL: stale shim was not healed"; cat "$tmp/out2.log"; exit 1; }
grep -q "Refreshed stale shim" "$tmp/out2.log" || { echo "FAIL: no 'Refreshed stale shim' message"; cat "$tmp/out2.log"; exit 1; }
echo "PASS"

echo "Test 3: --no-shim-setup does NOT downgrade the shim on a pinned-older backfill"
# metadata now records v9.9.9; backfilling the older v9.9.8 must leave the shim alone.
run_install v9.9.8 --no-shim-setup > "$tmp/out3.log" 2>&1 || { echo "FAIL: backfill install"; cat "$tmp/out3.log"; exit 1; }
grep -q "NEW-9.9.9" "$bin/octopus" || { echo "FAIL: shim was downgraded to v9.9.8 on a backfill"; cat "$tmp/out3.log"; exit 1; }
grep -q "Refreshed stale shim" "$tmp/out3.log" && { echo "FAIL: shim was refreshed during a downgrade backfill"; exit 1; }
echo "PASS"

echo "Test 4: --no-shim-setup never creates a stray shim where none exists"
empty_bin="$tmp/empty-bin"
mkdir -p "$empty_bin"
bash "$INSTALL_SCRIPT" --version v9.9.9 --bin-dir "$empty_bin" --cache-root "$cache" --force --no-shim-setup \
  > "$tmp/out4.log" 2>&1 || { echo "FAIL: install"; cat "$tmp/out4.log"; exit 1; }
[[ ! -e "$empty_bin/octopus" ]] || { echo "FAIL: stray shim created in a bin dir that had none"; exit 1; }
echo "PASS"

# No temp shim files left behind in the bin dir.
if ls "$bin"/.octopus-shim.* >/dev/null 2>&1; then
  echo "FAIL: temp shim file left behind"
  exit 1
fi

echo ""
echo "All shim_heal tests passed."
