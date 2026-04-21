#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMPDIR=$(mktemp -d)
TEST_BIN="$TMPDIR/bin"
mkdir -p "$TEST_BIN"

# Create git mock
cat > "$TEST_BIN/git" << 'MOCK'
#!/bin/bash
echo "mock-git: $@"
# Simulate branch listing for pr-open
if [[ "${1:-}" == "branch" && "${2:-}" == "-r" ]]; then
  echo "  origin/release/1.0.0"
  echo "  origin/main"
fi
# Simulate current branch
if [[ "${1:-}" == "rev-parse" ]]; then
  echo "feat/test-feature"
fi
MOCK
chmod +x "$TEST_BIN/git"

# Create gh mock
cat > "$TEST_BIN/gh" << 'MOCK'
#!/bin/bash
# Simulate PR creation
if [[ "${1:-}" == "pr" && "${2:-}" == "create" ]]; then
  echo "https://github.com/org/repo/pull/42"
  exit 0
fi
# Simulate PR view --json number (used by pr-open to get PR number)
if [[ "${1:-}" == "pr" && "${2:-}" == "view" && "${3:-}" == "--json" && "${4:-}" == "number" ]]; then
  echo "42"
  exit 0
fi
# Simulate PR diff
if [[ "${1:-}" == "pr" && "${2:-}" == "diff" ]]; then
  echo "+++ added line"
  echo "--- removed line"
  exit 0
fi
# Simulate PR merge check
if [[ "${1:-}" == "pr" && "${2:-}" == "view" ]]; then
  echo '{"reviewDecision":"APPROVED"}'
  exit 0
fi
if [[ "${1:-}" == "pr" && "${2:-}" == "checks" ]]; then
  echo "All checks passed"
  exit 0
fi
echo "mock-gh: $@"
MOCK
chmod +x "$TEST_BIN/gh"

export PATH="$TEST_BIN:$PATH"

# --- Test 1: CLI entry point routes commands ---
echo "Test 1: CLI routing"

output=$("$SCRIPT_DIR/cli/octopus.sh" branch-create feat/test 2>&1) || true
echo "$output" | grep -q "mock-git" || { echo "FAIL: branch-create should call git"; exit 1; }
echo "PASS: branch-create routed"

# --- Test 2: dev-flow start routes to branch-create ---
echo "Test 2: dev-flow start"

output=$("$SCRIPT_DIR/cli/octopus.sh" dev-flow start feat/test-flow 2>&1) || true
echo "$output" | grep -q "mock-git" || { echo "FAIL: dev-flow start should call git"; exit 1; }
echo "$output" | grep -q "Branch created" || { echo "FAIL: dev-flow start should print next-step guidance"; exit 1; }
echo "PASS: dev-flow start routed"

# --- Test 3: pr-open outputs OCTOPUS_PR ---
echo "Test 3: pr-open output"

BODY_FIXTURE="$(mktemp)"
printf '## What\nfixture\n' > "$BODY_FIXTURE"
output=$("$SCRIPT_DIR/cli/octopus.sh" pr-open --target main --body-file "$BODY_FIXTURE" 2>&1) || true
echo "$output" | grep -q "OCTOPUS_PR=" || { echo "FAIL: pr-open should output OCTOPUS_PR"; exit 1; }
rm -f "$BODY_FIXTURE"
echo "PASS: pr-open outputs PR number"

# --- Test 4: pr-review outputs diff ---
echo "Test 4: pr-review"

output=$("$SCRIPT_DIR/cli/octopus.sh" pr-review 42 2>&1) || true
echo "$output" | grep -q "Self-Review Complete" || { echo "FAIL: pr-review should show review output"; exit 1; }
echo "PASS: pr-review shows review output"

# --- Test 5: Unknown command fails ---
echo "Test 5: Unknown command"

output=$("$SCRIPT_DIR/cli/octopus.sh" nonexistent 2>&1) || true
echo "$output" | grep -qi "unknown\|not found\|usage" || { echo "FAIL: should error on unknown command"; exit 1; }
echo "PASS: unknown command handled"

rm -rf "$TMPDIR"
echo "PASS: all CLI tests passed"
