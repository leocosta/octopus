#!/usr/bin/env bash
# Regression (RM-155): install.sh must resolve the checksum + signature URLs on
# the DEFAULT (GitHub) path, not only when OCTOPUS_INSTALL_ENDPOINT is set.
# Before the fix the default `install.sh --version vX` resolved empty URLs, so
# SHA-256 + GPG verification (and OCTOPUS_REQUIRE_SIGNATURE) were silently inert.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$DIR/install.sh"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

# The signing pipeline publishes octopus-<v>.tar.gz.asc + .sha256 as GitHub
# release assets; the resolvers must point at them on the default path.
sig_body() { awk '/^resolve_signature_url\(\)/,/^}/' "$INSTALL"; }
sum_body() { awk '/^resolve_checksum_url\(\)/,/^}/'  "$INSTALL"; }

t_sig_github_fallback() { sig_body | grep -q 'releases/download' && sig_body | grep -q 'tar.gz.asc'; }
check "resolve_signature_url falls back to the GitHub asset on the default path" t_sig_github_fallback

t_sum_github_fallback() { sum_body | grep -q 'releases/download' && sum_body | grep -q '\.sha256'; }
check "resolve_checksum_url falls back to the GitHub asset on the default path" t_sum_github_fallback

# Fail-closed: OCTOPUS_REQUIRE_SIGNATURE must error when no signature URL resolves.
t_require_failclosed() { grep -q 'OCTOPUS_REQUIRE_SIGNATURE=1 but no signature URL could be resolved' "$INSTALL"; }
check "OCTOPUS_REQUIRE_SIGNATURE fails closed when no signature URL resolves" t_require_failclosed

# And it errors when the signature 404s under REQUIRE.
t_require_404() { grep -q 'OCTOPUS_REQUIRE_SIGNATURE=1' "$INSTALL" && grep -q 'No signature published' "$INSTALL"; }
check "OCTOPUS_REQUIRE_SIGNATURE fails closed when the signature is missing (404)" t_require_404

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
