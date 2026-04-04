#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
ENV_FILE="$TMPDIR/.env.octopus"

# Test 1: preview works with OAuth 2 user token and does not hit the network
cat > "$ENV_FILE" << 'EOF'
X_USER_ACCESS_TOKEN=dummy-user-token
X_EXPECTED_USERNAME=leoccosta
EOF

output=$(python3 "$SCRIPT_DIR/scripts/x_post.py" --env-file "$ENV_FILE" --text "Preview only")
echo "$output" | grep -q '"mode": "preview"' || { echo "FAIL: preview mode missing"; exit 1; }
echo "$output" | grep -q '"auth_mode": "oauth2-user-token"' || { echo "FAIL: oauth2 auth mode missing"; exit 1; }
echo "PASS: preview works with OAuth 2 token"

# Test 2: missing credentials fail fast
EMPTY_ENV="$TMPDIR/empty.env"
touch "$EMPTY_ENV"

if python3 "$SCRIPT_DIR/scripts/x_post.py" --env-file "$EMPTY_ENV" --text "Should fail" > /dev/null 2>&1; then
  echo "FAIL: script should fail without credentials"
  exit 1
fi
echo "PASS: missing credentials fail fast"

rm -rf "$TMPDIR"
echo "PASS: x_post helper tests passed"
