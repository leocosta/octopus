# Spec: GPG-Signed Release Verification

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **Roadmap** | RM-009 |
| **RFC** | N/A |

## Problem Statement

RM-007 shipped the global Octopus CLI with a shell installer that downloads release tarballs, verifies a companion `SHA256` checksum when `OCTOPUS_INSTALL_ENDPOINT` is set, and caches the extracted tree. A SHA256 alongside the artifact only protects against transport corruption and storage bit-rot — an attacker with write access to the release CDN can replace both the tarball and the checksum file with matching malicious content.

A detached GPG signature over the tarball, produced with a key held only by the release maintainer, closes that gap: even if the CDN is compromised, the attacker cannot forge a valid signature without stealing the private key.

## Goals

1. `install.sh` verifies a detached GPG signature (`<artifact>.asc`) when the release endpoint publishes one.
2. Verification is on by default whenever a signature is available; the installer refuses to proceed on a failed or mismatched signature.
3. Provide env-var overrides for keyring configuration so the installer works in CI/containers without mutating the user's default GnuPG keyring.
4. Provide an explicit opt-out for emergency situations, and an explicit opt-in "strict" mode that refuses any install without a published signature.
5. Cover the behavior with an automated test that exercises valid, tampered, bypass, and strict-missing cases using an ephemeral GPG key.

## Non-Goals

- Do not publish release signatures from within `install.sh` — that belongs to the release pipeline.
- Do not embed a release public key inside the installer script. The key is distributed out-of-band (published on the project website / via the release page) and trust is established by the user explicitly importing it. Baking a key into the installer gives attackers a target on the install server.
- Do not require `gpg` to be installed when the endpoint does not publish signatures (e.g., direct GitHub archive URL). Signature verification only activates when `OCTOPUS_INSTALL_ENDPOINT` is set and a `.asc` is served.

## Design

### Verification flow

Inside `download_release()` in `install.sh`, after the SHA256 check:

1. Resolve signature URL: `${OCTOPUS_INSTALL_ENDPOINT}/<version>/octopus-<version>.tar.gz.asc`. Only computed when `OCTOPUS_INSTALL_ENDPOINT` is set.
2. Probe the signature URL with `curl --fail`. 404 is treated as "signature not published yet" and is tolerated unless strict mode is enabled.
3. If the signature is fetched, call `verify_signature <tarball> <sig>`, which invokes `gpg --verify --batch --no-auto-key-locate` against the appropriate keyring (see below). A non-zero exit aborts the install; the cache is not written.

### Keyring resolution

In precedence order:

1. `OCTOPUS_GPG_KEYRING=/path/to/pubring.kbx` — verify against this keyring only (`gpg --no-default-keyring --keyring ...`). Recommended for CI.
2. `OCTOPUS_GPG_IMPORT_KEY=/path/to/pubkey.asc` — import the supplied public key into the user's default keyring before verifying. Idempotent.
3. Default: use whatever the user's default keyring already trusts.

### Opt-out / strict flags

- `OCTOPUS_SKIP_SIGNATURE=1` — bypass verification entirely with a warning. Intended for emergency fallback, not routine use.
- `OCTOPUS_REQUIRE_SIGNATURE=1` — refuse to install if the endpoint does not publish a signature. Intended for locked-down CI pipelines.

### Help surface

`install.sh --help` documents all four env vars: `OCTOPUS_INSTALL_ENDPOINT`, `OCTOPUS_GPG_KEYRING`, `OCTOPUS_GPG_IMPORT_KEY`, `OCTOPUS_REQUIRE_SIGNATURE`, `OCTOPUS_SKIP_SIGNATURE`.

## Release pipeline expectations

The release job that publishes `octopus-<version>.tar.gz` must also publish, side-by-side:

- `octopus-<version>.sha256` — one-line `<hash>  <filename>` output of `sha256sum`
- `octopus-<version>.tar.gz.asc` — detached ASCII-armored signature produced by `gpg --detach-sign --armor`

The signing key is held by the release maintainer (out of tree). Consumers trust the key by downloading the project's public key and pointing `OCTOPUS_GPG_IMPORT_KEY` or `OCTOPUS_GPG_KEYRING` at it during their first install.

## Backward Compatibility

- Endpoints that do not yet publish `.asc` files are unaffected: the installer fetches the tarball, verifies SHA256 (if present), and proceeds exactly as before.
- Once signatures start being published, existing users who installed without a key will see a failing `gpg --verify` on their next upgrade. The error message directs them to set `OCTOPUS_GPG_IMPORT_KEY` or `OCTOPUS_SKIP_SIGNATURE=1`.

## Testing Strategy

`tests/test_signature.sh` (SKIPs gracefully when `gpg` is not installed):

1. Generates an ephemeral RSA key in an isolated `GNUPGHOME`, exports the public half to a keyring file.
2. Builds a minimal release tarball, writes SHA256, and produces a detached signature.
3. **Valid path** — install with `OCTOPUS_GPG_KEYRING` pointing at the trusted keyring → success.
4. **Tampered tarball** — modifies the tarball (regenerates SHA256 so that check still passes) → install aborts on signature mismatch.
5. **Skip flag** — restores valid tarball, keeps stale `.asc`, runs with `OCTOPUS_SKIP_SIGNATURE=1` → install succeeds with a warning.
6. **Strict mode** — removes the `.asc`, runs with `OCTOPUS_REQUIRE_SIGNATURE=1` → install aborts on missing signature.

## Risks

- **Key management is out of scope.** If the release maintainer loses the private key or has it compromised, consumers must be notified out-of-band to rotate. This spec does not define a rotation protocol.
- **GnuPG TOFU / trust model nuances.** The installer uses `gpg --verify` which returns 0 for "good signature" even when the key is not ultimately trusted. For a small project this is acceptable; organizations that need full trust validation should point `OCTOPUS_GPG_KEYRING` at a keyring containing only their signed copy of the release key.
- **Endpoint availability.** `.asc` download failures are treated as "not yet published" rather than "mirror broken" unless `OCTOPUS_REQUIRE_SIGNATURE=1`. A compromised mirror could exploit this by serving a 404 for the `.asc` while serving a malicious tarball — mitigation is to set `OCTOPUS_REQUIRE_SIGNATURE=1` in high-assurance environments.

## Changelog

- **2026-04-18** — Initial implementation (RM-009). `install.sh` verifies detached signatures; `tests/test_signature.sh` covers valid/tampered/bypass/strict paths with an ephemeral key.
