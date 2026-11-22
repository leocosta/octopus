#!/usr/bin/env bash
# Regression test for #246: `octopus update --version vX --pin` must record the
# checksum of the release it just INSTALLED (cache/vX), not of the release that
# is running the update. It used to hash $RELEASE_ROOT — here this source
# checkout, whose checksum is its git HEAD — so the lockfile paired vX's version
# with another tree's checksum. Offline: the release comes from a file:// mirror.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$SCRIPT_DIR/bin/octopus"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export OCTOPUS_CLI_CACHE_ROOT="$tmp/.octopus-cli"
export OCTOPUS_INSTALL_ENDPOINT="file://$tmp/releases"
mkdir -p "$HOME"

# Minimal release tarball for the mirror.
version="v9.9.7"
build="$tmp/build/octopus-$version"
mkdir -p "$build/bin" "$build/cli"
printf '#!/usr/bin/env bash\necho octopus %s\n' "$version" > "$build/bin/octopus"
printf '#!/usr/bin/env bash\necho cli\n' > "$build/cli/octopus.sh"
chmod +x "$build/bin/octopus" "$build/cli/octopus.sh"
mkdir -p "$tmp/releases/$version"
tar -czf "$tmp/releases/$version/octopus-$version.tar.gz" -C "$tmp/build" "octopus-$version"
( cd "$tmp/releases/$version" && sha256sum "octopus-$version.tar.gz" > "octopus-$version.sha256" )

# A throwaway project (no .octopus.yml, so update does not re-run setup).
proj="$tmp/project"
mkdir -p "$proj"
git -C "$proj" init -q
cd "$proj"

echo "Test 1: update --version $version --pin installs and writes the lockfile"
"$CLI" update --version "$version" --pin > "$tmp/update.log" 2>&1 \
  || { echo "FAIL: update"; cat "$tmp/update.log"; exit 1; }
lock="$proj/.octopus/cli-lock.yaml"
grep -q "^version: $version\$" "$lock" || { echo "FAIL: lockfile version"; cat "$lock"; exit 1; }
echo "PASS"

echo "Test 2: the pinned checksum is the installed release's, not the running one's"
installed="$OCTOPUS_CLI_CACHE_ROOT/cache/$version"
expected="$(cd "$installed" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')"
pinned="$(awk '/^checksum:/ {print $2}' "$lock")"
running="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
[[ "$pinned" != "$running" ]] || { echo "FAIL: pinned the RUNNING checkout's checksum ($running)"; exit 1; }
[[ "$pinned" == "$expected" ]] || { echo "FAIL: pinned '$pinned', installed tree hashes to '$expected'"; exit 1; }
echo "PASS"

echo "Test 3: the lockfile agrees with metadata.json for the installed release"
meta="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["checksum"])' "$OCTOPUS_CLI_CACHE_ROOT/metadata.json")"
[[ "$pinned" == "$meta" ]] || { echo "FAIL: lockfile '$pinned' vs metadata '$meta'"; exit 1; }
echo "PASS"

echo ""
echo "All update --pin checksum tests passed."
