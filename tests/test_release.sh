#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create a real git repo for testing
git -C "$TMPDIR" init -q
git -C "$TMPDIR" config user.email "test@test.com"
git -C "$TMPDIR" config user.name "Test"

# --- Test 1: suggest-version with no tags defaults to 0.0.0 ---
echo "Test 1: suggest-version with no tags"

git -C "$TMPDIR" commit --allow-empty -m "feat: initial feature" -q
cd "$TMPDIR"
output=$("$SCRIPT_DIR/cli/octopus.sh" release suggest-version 2>&1)
echo "$output" | grep -q "current=0.0.0" || { echo "FAIL: should show current=0.0.0"; echo "Got: $output"; exit 1; }
echo "$output" | grep -q "suggested=0.1.0" || { echo "FAIL: feat should bump minor to 0.1.0"; echo "Got: $output"; exit 1; }
echo "PASS: suggest-version with no tags"

# --- Test 2: suggest-version with existing tag and feat commit ---
echo "Test 2: suggest-version with existing tag"

git -C "$TMPDIR" tag v1.0.0
git -C "$TMPDIR" commit --allow-empty -m "feat: add new feature" -q
cd "$TMPDIR"
output=$("$SCRIPT_DIR/cli/octopus.sh" release suggest-version 2>&1)
echo "$output" | grep -q "current=1.0.0" || { echo "FAIL: should show current=1.0.0"; echo "Got: $output"; exit 1; }
echo "$output" | grep -q "suggested=1.1.0" || { echo "FAIL: feat should bump to 1.1.0"; echo "Got: $output"; exit 1; }
echo "PASS: suggest-version with existing tag"

# --- Test 3: suggest-version fix only → patch ---
echo "Test 3: suggest-version fix bump"

git -C "$TMPDIR" tag v1.1.0
git -C "$TMPDIR" commit --allow-empty -m "fix: correct a bug" -q
cd "$TMPDIR"
output=$("$SCRIPT_DIR/cli/octopus.sh" release suggest-version 2>&1)
echo "$output" | grep -q "suggested=1.1.1" || { echo "FAIL: fix should bump patch to 1.1.1"; echo "Got: $output"; exit 1; }
echo "PASS: suggest-version fix bump"

# --- Test 4: suggest-version BREAKING CHANGE → major ---
echo "Test 4: suggest-version breaking change"

git -C "$TMPDIR" tag v1.1.1
git -C "$TMPDIR" commit --allow-empty -m "feat!: redesign API" -q
cd "$TMPDIR"
output=$("$SCRIPT_DIR/cli/octopus.sh" release suggest-version 2>&1)
echo "$output" | grep -q "suggested=2.0.0" || { echo "FAIL: breaking should bump to 2.0.0"; echo "Got: $output"; exit 1; }
echo "PASS: suggest-version breaking change"

# --- Test 5: suggest-version no commits since tag ---
echo "Test 5: suggest-version no commits"

git -C "$TMPDIR" tag v2.0.0
cd "$TMPDIR"
output=$("$SCRIPT_DIR/cli/octopus.sh" release suggest-version 2>&1)
echo "$output" | grep -q "No unreleased commits found" || { echo "FAIL: should report no commits"; echo "Got: $output"; exit 1; }
echo "PASS: suggest-version no commits"

# --- Test 6: list-commits shows commits since last tag ---
echo "Test 6: list-commits"

git -C "$TMPDIR" commit --allow-empty -m "feat: feature A" -q
git -C "$TMPDIR" commit --allow-empty -m "fix: bug B" -q
cd "$TMPDIR"
output=$("$SCRIPT_DIR/cli/octopus.sh" release list-commits 2>&1)
echo "$output" | grep -q "feat: feature A" || { echo "FAIL: should list feat commit"; echo "Got: $output"; exit 1; }
echo "$output" | grep -q "fix: bug B" || { echo "FAIL: should list fix commit"; echo "Got: $output"; exit 1; }
echo "PASS: list-commits"

# --- Test 7: create-tag creates annotated tag ---
echo "Test 7: create-tag"

MSG_FILE="$TMPDIR/tag-msg.txt"
echo "Release notes for v2.1.0" > "$MSG_FILE"
cd "$TMPDIR"
"$SCRIPT_DIR/cli/octopus.sh" release create-tag 2.1.0 "$MSG_FILE" 2>&1
tag_exists=$(git tag -l "v2.1.0")
[[ -n "$tag_exists" ]] || { echo "FAIL: tag v2.1.0 should exist"; exit 1; }
tag_msg=$(git tag -l --format='%(contents)' v2.1.0)
echo "$tag_msg" | grep -q "Release notes for v2.1.0" || { echo "FAIL: tag message wrong"; echo "Got: $tag_msg"; exit 1; }
echo "PASS: create-tag"

# --- Test 8: commit-changelog works without README.md ---
echo "Test 8: commit-changelog without README.md"

cd "$TMPDIR"
echo "## [2.2.0] - 2026-03-22" > CHANGELOG.md
echo "Some release notes" >> CHANGELOG.md
"$SCRIPT_DIR/cli/octopus.sh" release commit-changelog 2.2.0 2>&1
last_msg=$(git log -1 --format="%s")
[[ "$last_msg" == "chore(release): v2.2.0" ]] || { echo "FAIL: commit message should be 'chore(release): v2.2.0'"; echo "Got: $last_msg"; exit 1; }
echo "PASS: commit-changelog without README.md"

# --- Test 9: commit-changelog syncs README version references ---
echo "Test 9: commit-changelog syncs README.md"

SYNC_REPO="$TMPDIR/sync-repo"
mkdir -p "$SYNC_REPO"
git -C "$SYNC_REPO" init -q
git -C "$SYNC_REPO" config user.email "test@test.com"
git -C "$SYNC_REPO" config user.name "Test"
cat > "$SYNC_REPO/README.md" << 'EOF'
![Version](https://img.shields.io/badge/version-v2.1.0-blue)

```bash
cd octopus && git fetch --tags && git checkout v2.1.0 && cd ..
./octopus/setup.sh
git add octopus && git commit -m "chore: update octopus to v2.1.0"
curl -fsSL https://example.com/install.sh | bash -s -- --version v2.1.0
```
EOF
cat > "$SYNC_REPO/CHANGELOG.md" << 'EOF'
## [Unreleased]
Pending notes
EOF
git -C "$SYNC_REPO" add README.md CHANGELOG.md
git -C "$SYNC_REPO" commit -m "docs: seed release files" -q
cat > "$SYNC_REPO/CHANGELOG.md" << 'EOF'
## [2.2.0] - 2026-03-22
Some release notes
EOF
cd "$SYNC_REPO"
"$SCRIPT_DIR/cli/octopus.sh" release commit-changelog 2.2.0 2>&1
grep -q 'version-v2.2.0-blue' README.md || { echo "FAIL: README badge should be updated"; cat README.md; exit 1; }
grep -q 'git checkout v2.2.0' README.md || { echo "FAIL: README checkout example should be updated"; cat README.md; exit 1; }
grep -q 'chore: update octopus to v2.2.0' README.md || { echo "FAIL: README commit example should be updated"; cat README.md; exit 1; }
grep -q -- '--version v2.2.0' README.md || { echo "FAIL: README install --version example should be updated"; cat README.md; exit 1; }
last_files=$(git show --name-only --format= HEAD)
echo "$last_files" | grep -q '^CHANGELOG.md$' || { echo "FAIL: release commit should include CHANGELOG.md"; echo "$last_files"; exit 1; }
echo "$last_files" | grep -q '^README.md$' || { echo "FAIL: release commit should include README.md"; echo "$last_files"; exit 1; }
echo "PASS: commit-changelog syncs README.md"

# --- Test 10: commit-changelog fails on malformed README sync anchor ---
echo "Test 10: commit-changelog fails on malformed README.md"

BROKEN_REPO="$TMPDIR/broken-repo"
mkdir -p "$BROKEN_REPO"
git -C "$BROKEN_REPO" init -q
git -C "$BROKEN_REPO" config user.email "test@test.com"
git -C "$BROKEN_REPO" config user.name "Test"
cat > "$BROKEN_REPO/README.md" << 'EOF'
![Version](https://img.shields.io/badge/version-latest-blue)
EOF
cat > "$BROKEN_REPO/CHANGELOG.md" << 'EOF'
## [2.2.0] - 2026-03-22
Some release notes
EOF
git -C "$BROKEN_REPO" add README.md CHANGELOG.md
git -C "$BROKEN_REPO" commit -m "docs: seed broken readme" -q
cd "$BROKEN_REPO"
if "$SCRIPT_DIR/cli/octopus.sh" release commit-changelog 2.2.0 > "$TMPDIR/broken-output.txt" 2>&1; then
  echo "FAIL: commit-changelog should fail when README sync pattern is malformed"
  exit 1
fi
grep -q "README version sync failed" "$TMPDIR/broken-output.txt" || { echo "FAIL: should explain README sync failure"; cat "$TMPDIR/broken-output.txt"; exit 1; }
echo "PASS: commit-changelog fails on malformed README.md"

# --- Test 11: create-gh-release calls gh (mocked) ---
echo "Test 11: create-gh-release"

MOCK_BIN="$TMPDIR/mock_bin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/gh" << 'MOCK'
#!/bin/bash
if [[ "${1:-}" == "release" && "${2:-}" == "create" ]]; then
  echo "mock-release-created: $@"
  exit 0
fi
echo "mock-gh: $@"
MOCK
chmod +x "$MOCK_BIN/gh"

cd "$TMPDIR"
NOTES_FILE="$TMPDIR/release-notes.txt"
echo "Short release summary" > "$NOTES_FILE"
export PATH="$MOCK_BIN:$PATH"
output=$("$SCRIPT_DIR/cli/octopus.sh" release create-gh-release 2.2.0 "$NOTES_FILE" 2>&1)
echo "$output" | grep -q "mock-release-created" || { echo "FAIL: should call gh release create"; echo "Got: $output"; exit 1; }
echo "PASS: create-gh-release"

echo ""
echo "PASS: all release tests passed"
