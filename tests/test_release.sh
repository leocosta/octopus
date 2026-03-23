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

# --- Test 8: commit-changelog stages and commits ---
echo "Test 8: commit-changelog"

cd "$TMPDIR"
echo "## [2.2.0] - 2026-03-22" > CHANGELOG.md
echo "Some release notes" >> CHANGELOG.md
"$SCRIPT_DIR/cli/octopus.sh" release commit-changelog 2.2.0 2>&1
last_msg=$(git log -1 --format="%s")
[[ "$last_msg" == "chore(release): v2.2.0" ]] || { echo "FAIL: commit message should be 'chore(release): v2.2.0'"; echo "Got: $last_msg"; exit 1; }
echo "PASS: commit-changelog"

# --- Test 9: create-gh-release calls gh (mocked) ---
echo "Test 9: create-gh-release"

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
