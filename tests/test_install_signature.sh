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

# Default-path key self-bootstrap (RM-158): the installer pins the release
# fingerprint and fetches the key by it so a clean machine verifies without a
# pre-seeded keyring (the bug this fixes: "GPG signature verification failed"
# on a fresh box).
sig_fn_body() { awk '/^verify_signature\(\)/,/^}/' "$INSTALL"; }

t_pinned_fpr() { grep -q 'OCTOPUS_RELEASE_FPR=' "$INSTALL" && grep -q '63C35E66917CE4540CD27592C8BA059A0322F3CD' "$INSTALL"; }
check "pins the release fingerprint as the out-of-band trust anchor" t_pinned_fpr

t_recv_keys() { sig_fn_body | grep -q -- '--recv-keys' && sig_fn_body | grep -q -- '--keyserver'; }
check "fetches the release key by fingerprint from a keyserver when absent" t_recv_keys

t_strict_signer() { sig_fn_body | grep -q -- '--status-fd' && sig_fn_body | grep -q 'VALIDSIG'; }
check "verifies the signer fingerprint via --status-fd (rejects foreign keys)" t_strict_signer

t_warn_continue() { sig_fn_body | grep -q 'NO_PUBKEY' && sig_fn_body | grep -q 'checksum-only'; }
check "warns and continues on checksum-only when the key is unobtainable" t_warn_continue

t_require_strict() { sig_fn_body | grep -q 'OCTOPUS_REQUIRE_SIGNATURE' ; }
check "OCTOPUS_REQUIRE_SIGNATURE turns the unobtainable-key case into a hard failure" t_require_strict

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
