#!/usr/bin/env bash
# Regression test for the shim self-update bug.
# `octopus update` invokes the installer with --no-shim-setup, so the running
# shim (bin/octopus) was never refreshed — a new global command added to the
# shim could only reach users via a full reinstall. command_update must now
# copy the target release's shim over the running one (atomic rename).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="$SCRIPT_DIR/bin/octopus"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A fake RELEASE_ROOT (resolved from <bindir>/.. ) so the running shim treats
# $tmp/release as the current release tree. Not a git repo → install_release
# takes the download branch rather than the dev-checkout symlink branch.
root="$tmp/release"
mkdir -p "$root/cli" "$root/bin"
printf '#!/usr/bin/env bash\necho "cli stub"\n' > "$root/cli/octopus.sh"
chmod +x "$root/cli/octopus.sh"

# The running shim IS the real (new) shim under test — it must contain sync_shim.
cp "$SHIM" "$root/bin/octopus"
chmod +x "$root/bin/octopus"

# The NEW shim that the release ships: the real shim + a unique marker line, so
# it is byte-different from the running one and we can assert the swap happened.
new_shim="$tmp/new-shim"
cp "$SHIM" "$new_shim"
marker="# shim-sync-marker-$$"
printf '%s\n' "$marker" >> "$new_shim"

# Stub installer: curl from the bogus owner/repo fails, so the shim falls back
# to $RELEASE_ROOT/install.sh. This stub populates the cache for the requested
# version with a cli stub and the NEW shim.
cat > "$root/install.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
version=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --version) version="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
target="\$OCTOPUS_CACHE_DIR/cache/\$version"
mkdir -p "\$target/cli" "\$target/bin"
printf '#!/usr/bin/env bash\necho cli\n' > "\$target/cli/octopus.sh"
chmod +x "\$target/cli/octopus.sh"
cp "$new_shim" "\$target/bin/octopus"
chmod +x "\$target/bin/octopus"
EOF
chmod +x "$root/install.sh"

export OCTOPUS_CLI_CACHE_ROOT="$tmp/cli-cache"
export OCTOPUS_RELEASE_OWNER="nonexistent-owner-for-testing"
export OCTOPUS_RELEASE_NAME="no-such-repo"

echo "Test 1: octopus update refreshes a stale shim with the release's version"
# Run from $tmp (no .octopus.yml) so the post-update setup step is skipped.
( cd "$tmp" && "$root/bin/octopus" update --version v2.0.0 ) > "$tmp/out.log" 2>&1 \
  || { echo "FAIL: update exited non-zero"; cat "$tmp/out.log"; exit 1; }

if ! cmp -s "$root/bin/octopus" "$new_shim"; then
  echo "FAIL: running shim was not refreshed to the release shim"
  cat "$tmp/out.log"
  exit 1
fi
if ! grep -qF "$marker" "$root/bin/octopus"; then
  echo "FAIL: marker from the new shim is absent after update"
  exit 1
fi
grep -q "Refreshed shim" "$tmp/out.log" || { echo "FAIL: no 'Refreshed shim' message"; cat "$tmp/out.log"; exit 1; }
echo "PASS: stale shim refreshed on update"

echo "Test 2: a second update is a no-op (shim already identical)"
( cd "$tmp" && "$root/bin/octopus" update --version v2.0.0 ) > "$tmp/out2.log" 2>&1 \
  || { echo "FAIL: second update exited non-zero"; cat "$tmp/out2.log"; exit 1; }
if grep -q "Refreshed shim" "$tmp/out2.log"; then
  echo "FAIL: shim was rewritten even though it was already identical"
  cat "$tmp/out2.log"
  exit 1
fi
echo "PASS: identical shim is a no-op"

echo ""
echo "All shim_sync tests passed."
