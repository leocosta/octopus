#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$SCRIPT_DIR/cli/octopus.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Stub gh so the test never hits the network. STUB_IS_DRAFT drives what
# `gh pr view --json isDraft` reports; STUB_NO_PR makes the branch lookup
# fail the way gh does when no PR exists for the current branch.
STUB_BIN="$TMPDIR/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "ready" ]]; then
  echo "READY_CALLED=$3" >> "$STUB_LOG"
  exit 0
fi
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "$*" == *isDraft* ]]; then
    echo "${STUB_IS_DRAFT:-true}"
    exit 0
  fi
  if [[ -n "${STUB_NO_PR:-}" ]]; then
    echo "no pull requests found for branch" >&2
    exit 1
  fi
  echo "7"
  exit 0
fi
exit 0
EOF
chmod +x "$STUB_BIN/gh"

export STUB_LOG="$TMPDIR/stub.log"
: > "$STUB_LOG"

echo "Test 1: no argument and no PR for the branch prints usage and fails"
: > "$STUB_LOG"
set +e
STUB_NO_PR=1 PATH="$STUB_BIN:$PATH" "$CLI" pr-ready > "$TMPDIR/out1.txt" 2>&1
code=$?
set -e
[[ $code -ne 0 ]] || { echo "FAIL: expected non-zero exit"; cat "$TMPDIR/out1.txt"; exit 1; }
grep -q "Usage: octopus.sh pr-ready" "$TMPDIR/out1.txt" \
  || { echo "FAIL: usage line missing"; cat "$TMPDIR/out1.txt"; exit 1; }
! grep -q "READY_CALLED" "$STUB_LOG" \
  || { echo "FAIL: gh pr ready called with no resolvable PR"; cat "$STUB_LOG"; exit 1; }
echo "PASS: pr-ready needs a resolvable PR number"

echo "Test 2: an already-ready PR exits 0 without calling gh pr ready"
: > "$STUB_LOG"
STUB_IS_DRAFT=false PATH="$STUB_BIN:$PATH" "$CLI" pr-ready 5 > "$TMPDIR/out2.txt" 2>&1
! grep -q "READY_CALLED" "$STUB_LOG" \
  || { echo "FAIL: gh pr ready called on a non-draft PR"; cat "$STUB_LOG"; exit 1; }
grep -q "already ready" "$TMPDIR/out2.txt" \
  || { echo "FAIL: no notice for an already-ready PR"; cat "$TMPDIR/out2.txt"; exit 1; }
echo "PASS: promotion is idempotent"

echo "Test 3: a draft PR is promoted"
: > "$STUB_LOG"
STUB_IS_DRAFT=true PATH="$STUB_BIN:$PATH" "$CLI" pr-ready 5 > "$TMPDIR/out3.txt" 2>&1
grep -q "READY_CALLED=5" "$STUB_LOG" \
  || { echo "FAIL: gh pr ready was not called for the draft"; cat "$STUB_LOG"; exit 1; }
echo "PASS: draft PR is promoted"

echo "Test 4: the PR number falls back to the current branch"
: > "$STUB_LOG"
STUB_IS_DRAFT=true PATH="$STUB_BIN:$PATH" "$CLI" pr-ready > "$TMPDIR/out4.txt" 2>&1
grep -q "READY_CALLED=7" "$STUB_LOG" \
  || { echo "FAIL: branch fallback did not resolve the PR number"; cat "$STUB_LOG"; exit 1; }
echo "PASS: PR number falls back to the current branch"
