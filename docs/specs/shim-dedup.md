# Spec: Dedup the CLI shim

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **Roadmap** | RM-019 |
| **RFC** | N/A |

## Problem

`install.sh` writes the global `octopus` shim to `$OCTOPUS_BIN_DIR/octopus` via a HEREDOC that duplicates the entire contents of `bin/octopus` (~240 lines including version resolution, lockfile handling, sub-command dispatch). Every time `bin/octopus` changes in the repo, the HEREDOC must be kept in sync manually. Silent drift is a realistic failure mode: the repo's shim implements feature X, users who installed via `install.sh` get the old HEREDOC version.

Earlier specs (RM-007, RM-008) flagged this as a known non-goal. This spec resolves it.

## Goals

1. Eliminate the HEREDOC copy of the shim in `install.sh`.
2. After downloading and extracting a release, have `install.sh` copy `bin/octopus` from the extracted tree directly into `$OCTOPUS_BIN_DIR/octopus`.
3. Preserve every existing installer behavior: shim executable bit, PATH check, uninstall flow, cache structure.

## Non-goals

- Changing the shim's behavior or interface.
- Changing the installer's CLI surface.
- Packaging the shim as a separate download (the tarball already contains it).

## Design

### Before

```bash
install_shim() {
  mkdir -p "$OCTOPUS_BIN_DIR"
  cat > "$OCTOPUS_BIN_DIR/octopus" << 'OCTOPUS_SHIM_EOF'
  #!/usr/bin/env bash
  ... ~240 lines of duplicated shim code ...
  OCTOPUS_SHIM_EOF
  chmod +x "$OCTOPUS_BIN_DIR/octopus"
  success "Installed shim to $OCTOPUS_BIN_DIR/octopus"
}
```

### After

```bash
install_shim() {
  local version="$1"
  local source_shim="$OCTOPUS_CACHE_DIR/cache/$version/bin/octopus"

  if [[ ! -f "$source_shim" ]]; then
    error "Shim not found in extracted release at $source_shim"
    exit 1
  fi

  mkdir -p "$OCTOPUS_BIN_DIR"
  cp "$source_shim" "$OCTOPUS_BIN_DIR/octopus"
  chmod +x "$OCTOPUS_BIN_DIR/octopus"
  success "Installed shim to $OCTOPUS_BIN_DIR/octopus"
}
```

The shim now comes from the same release the user is installing — no manual sync required, no drift window.

### Call site

`install_shim` is called once in `main()` of `install.sh`. Currently takes no arguments. Will be updated to receive the version:

```bash
# before
install_shim

# after
install_shim "$VERSION"
```

### Edge cases

- **Tarball missing `bin/octopus`** — `install.sh` aborts with a clear error. This would indicate a broken release and needs manual investigation (should never happen in practice).
- **Reinstall with `--force`** — existing shim is overwritten; same behavior as today.
- **`--uninstall`** — `rm -f "$OCTOPUS_BIN_DIR/octopus"` continues to work (shim is a plain file, not a symlink).

## Backward compatibility

- Fresh installs produce identical results (same shim bytes, different origin path).
- Users who upgrade via `octopus update --latest` aren't affected; the global CLI shim resolves via `bin/octopus` regardless. This change only affects `install.sh`.

## Testing

- `tests/test_installer.sh` continues to exercise the full flow (download → extract → shim → metadata) against a mocked release endpoint. No assertion changes needed — the test already verifies `$TMP_BIN/octopus` exists and runs `doctor`.
- Manual verification: diff between `bin/octopus` in the repo and the installed shim at `$OCTOPUS_BIN_DIR/octopus` after a fresh install — expect identical files (modulo trailing newlines).

## Risks

- **Changes to `bin/octopus` that break backward compat** — the installer still serves the shim shipped with the targeted version, so the compatibility window matches the release version the user chose. Not a new risk introduced by this change.

## Changelog

- **2026-04-18** — Replaced the HEREDOC with a direct `cp` from the extracted release tree. Deleted ~240 lines from `install.sh`.
