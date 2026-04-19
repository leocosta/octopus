# Spec: Release signing pipeline

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **Roadmap** | RM-020 |
| **RFC** | N/A |
| **Depends on** | [RM-009](signed-releases.md) |

## Problem

RM-009 shipped the consumer side of GPG verification: `install.sh` downloads and verifies `<artifact>.sha256` and `<artifact>.tar.gz.asc` when `OCTOPUS_INSTALL_ENDPOINT` exposes them. But no release pipeline actually produces those companions today — releases cut via `octopus release` only publish the source archive that GitHub auto-generates from the git tag. The GPG verification code path is therefore dormant: it short-circuits silently because no `.asc` is ever found.

This spec adds the producer side: a GitHub Action that signs the release tarball on every published release and uploads the companions as release assets.

## Goals

1. When a GitHub Release is published (manual or via `octopus release create-gh-release`), automatically:
   - Download the tagged source tarball produced by GitHub.
   - Compute its SHA256 and write `octopus-<tag>.sha256`.
   - Sign the tarball with the maintainer's GPG key and write `octopus-<tag>.tar.gz.asc`.
   - Upload both as release assets.
2. Keys and passphrases live in GitHub repository secrets, never in the repo.
3. The Action runs unconditionally and fails loudly if the secrets are missing, so a partial release (source only, no signatures) is impossible to ship accidentally.

## Non-goals

- Key rotation protocol (tracked separately).
- Publishing the public key from the repo (maintainer hosts it out-of-band; consumers fetch and trust explicitly via `OCTOPUS_GPG_IMPORT_KEY`).
- Signing release notes, commits, or tags themselves (only the release artifact).
- Mirror strategies, CDN signing, or multi-key voting.

## Design

### Workflow file

`.github/workflows/release-sign.yml`:

```yaml
name: Sign release
on:
  release:
    types: [published]

permissions:
  contents: write  # required to upload release assets

jobs:
  sign:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout at the release tag
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.release.tag_name }}

      - name: Import GPG private key
        run: |
          if [[ -z "${{ secrets.OCTOPUS_RELEASE_GPG_KEY }}" ]]; then
            echo "::error::OCTOPUS_RELEASE_GPG_KEY secret not set"
            exit 1
          fi
          echo "${{ secrets.OCTOPUS_RELEASE_GPG_KEY }}" | gpg --batch --import
          echo "GPG_KEY_ID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')" >> "$GITHUB_ENV"

      - name: Download source tarball
        env:
          TAG: ${{ github.event.release.tag_name }}
        run: |
          gh release download "$TAG" --pattern '*.tar.gz' --dir /tmp/release || true
          # If no .tar.gz asset exists, fall back to the source archive GitHub auto-generates
          if ! ls /tmp/release/*.tar.gz >/dev/null 2>&1; then
            curl -fsSL \
              "https://github.com/${GITHUB_REPOSITORY}/archive/refs/tags/${TAG}.tar.gz" \
              -o "/tmp/release/octopus-${TAG}.tar.gz"
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Produce SHA256 and GPG signature
        env:
          TAG: ${{ github.event.release.tag_name }}
          GPG_PASSPHRASE: ${{ secrets.OCTOPUS_RELEASE_GPG_PASSPHRASE }}
        run: |
          cd /tmp/release
          TARBALL="octopus-${TAG}.tar.gz"
          sha256sum "$TARBALL" > "octopus-${TAG}.sha256"
          echo "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
            --passphrase-fd 0 --local-user "$GPG_KEY_ID" \
            --detach-sign --armor --output "${TARBALL}.asc" "$TARBALL"

      - name: Upload companions as release assets
        env:
          TAG: ${{ github.event.release.tag_name }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          cd /tmp/release
          gh release upload "$TAG" \
            "octopus-${TAG}.sha256" \
            "octopus-${TAG}.tar.gz.asc" \
            --clobber
```

### Required repository secrets

| Secret | Contents | How to generate |
|---|---|---|
| `OCTOPUS_RELEASE_GPG_KEY` | ASCII-armored private key exported via `gpg --export-secret-keys --armor <key-id>` | One-time setup by maintainer |
| `OCTOPUS_RELEASE_GPG_PASSPHRASE` | Passphrase that unlocks the private key | Set when key is generated |

### Public key distribution

The public key is NOT shipped in this repository. Maintainers publish it via:

- Personal Keybase / GitHub profile
- Project website (when one exists)
- `gpg --keyserver keys.openpgp.org --send-keys <key-id>`

Consumers fetch the public key and trust it explicitly:

```bash
curl -fsSL https://<maintainer-url>/octopus-releases.asc > /tmp/octopus-releases.asc
OCTOPUS_GPG_IMPORT_KEY=/tmp/octopus-releases.asc octopus install
# or set permanently:
export OCTOPUS_GPG_IMPORT_KEY=/tmp/octopus-releases.asc
```

### Fallback / resilience

- **Missing secrets** — Action fails with `::error::` and the release remains without signatures. Maintainer notices in the Actions tab and re-runs after provisioning. No silent "partial release".
- **Tarball asset doesn't exist** — Action falls back to the GitHub-generated source archive URL. Both paths sign the exact bytes consumers would download.
- **Subsequent re-run** — `--clobber` on `gh release upload` idempotently replaces existing `.sha256` / `.asc` if a previous run failed partway.

## Testing

Workflow validation is done via real release cuts:

1. Create a test tag (`v1.1.0-rc1`) and draft release.
2. Publish → Action runs → companions appear in release assets within ~30s.
3. Locally: `curl .../octopus-v1.1.0-rc1.tar.gz.asc` and `gpg --verify` against the known public key.

No unit test is practical for the workflow itself; relying on observability of the Actions run log.

## Backward compatibility

- **Existing releases (v0.1 through v1.1.0)** remain unsigned. `install.sh` skips verification silently for them because the `.asc` 404s — same behavior as today.
- **Future releases from v1.1.1 onward** carry signatures. Users who have imported the public key get automatic verification; users who haven't see `gpg: Can't check signature: No public key` and can opt out with `OCTOPUS_SKIP_SIGNATURE=1`.

## Risks

- **Leaked secret** — maintainer revokes the key, generates a new one, re-uploads secrets. Publishes revocation cert + new public key. Consumers update `OCTOPUS_GPG_IMPORT_KEY`.
- **Passphrase lock-in** — if the passphrase secret is lost, no release can be signed. Mitigation: document passphrase storage in a password manager outside GitHub.
- **Action failure during release** — release already published (source tarball exists), companions missing. Maintainer re-runs the workflow manually (`gh workflow run release-sign.yml -F tag=v1.1.0`).

## Changelog

- **2026-04-18** — Initial workflow. `.github/workflows/release-sign.yml` added. Requires `OCTOPUS_RELEASE_GPG_KEY` and `OCTOPUS_RELEASE_GPG_PASSPHRASE` secrets to be provisioned before the next release cut.
