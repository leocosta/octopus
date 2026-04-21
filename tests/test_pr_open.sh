#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$SCRIPT_DIR/cli/octopus.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Minimal git repo with a feature branch, so early validations in pr-open.sh
# ("not on main") pass and we reach the --body-file contract.
REPO="$TMPDIR/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t"
git -C "$REPO" config user.name "t"
git -C "$REPO" commit --allow-empty -m "init" -q
git -C "$REPO" checkout -q -b feat/x

# Stub gh and git push so the test does not hit the network.
STUB_BIN="$TMPDIR/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "create" ]]; then
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body-file) echo "BODY_FILE_RECEIVED=$2" >> "$STUB_LOG"; shift 2 ;;
      *) shift ;;
    esac
  done
  echo "https://example.test/stub/pr/1"
  exit 0
fi
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  echo '1'
  exit 0
fi
exit 0
EOF
chmod +x "$STUB_BIN/gh"

cat > "$STUB_BIN/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "push" ]]; then
  exit 0
fi
exec /usr/bin/git "$@"
EOF
chmod +x "$STUB_BIN/git"

export STUB_LOG="$TMPDIR/stub.log"
: > "$STUB_LOG"

echo "Test 1: pr-open without --body-file aborts"
cd "$REPO"
set +e
PATH="$STUB_BIN:$PATH" "$CLI" pr-open --target main > "$TMPDIR/out1.txt" 2>&1
code=$?
set -e
[[ $code -ne 0 ]] || { echo "FAIL: expected non-zero exit"; cat "$TMPDIR/out1.txt"; exit 1; }
grep -q "body-file" "$TMPDIR/out1.txt" || { echo "FAIL: error message should mention --body-file"; cat "$TMPDIR/out1.txt"; exit 1; }
echo "PASS: pr-open requires --body-file"

echo "Test 2: pr-open with nonexistent --body-file aborts"
set +e
PATH="$STUB_BIN:$PATH" "$CLI" pr-open --target main --body-file "$TMPDIR/missing.md" > "$TMPDIR/out2.txt" 2>&1
code=$?
set -e
[[ $code -ne 0 ]] || { echo "FAIL: expected non-zero exit"; cat "$TMPDIR/out2.txt"; exit 1; }
grep -q "Body file not found" "$TMPDIR/out2.txt" || { echo "FAIL: error should mention 'Body file not found'"; cat "$TMPDIR/out2.txt"; exit 1; }
echo "PASS: pr-open rejects missing body file"
