# Spec: Octopus CLI Tool

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-04 |
| **Author** | codex assistant |
| **Status** | Proposed |
| **Roadmap** | RM-007 |
| **RFC** | TBD |

## Problem Statement

Octopus today installs itself as a git submodule. Every repository has to add `octopus` as a submodule, run `./octopus/setup.sh`, and subsequently invoke commands via `./octopus/cli/octopus.sh`. This tight coupling creates friction for new adopters, duplicates per-repo bootstrap instructions, and makes homegrown automation rely on repository-relative paths. RM-007 proposes a global CLI so teams can adopt Octopus as a centralized standard library without wiring every repository as a submodule.

## Goals

1. Ship a single global `octopus` command (shell installer) that downloads a release artifact, verifies integrity, caches it, and exposes commands such as `install`, `setup`, `update`, `doctor`, and the existing workflow helpers.
2. Preserve per-repo reproducibility by pinning each repository to a specific Octopus version via a lockfile (`.octopus/cli-lock.yaml`) or equivalent metadata that records the git tag and checksum used during installation.
3. Keep the existing `./octopus/setup.sh` + `./octopus/cli/octopus.sh` path alive as a migration shim that delegates to the global CLI when possible.
4. Make the installer and CLI work on every supported OS (Linux, macOS, Windows via Git Bash/PowerShell shim) and surface the same commands agents already expect.
5. Document the new model, update generated instructions, and cover the new surface with automated tests.

## Non-Goals

- Remove the existing workflow/update commands before compatibility mode is stable.
- Force all repositories to reconfigure immediately; existing submodule workflows remain valid during migration.
- Ship compiled binaries; the global CLI is a POSIX/Bash shell installer and runner.

## Design

**CLI distribution model**
- A shell installer (`curl https://.../install.sh | bash`) downloads the tagged release archive from GitHub and extracts it into `~/.octopus-cli/cache/<tag>` (per-host cache). It records the tag, checksum, and a release signature in `~/.octopus-cli/metadata.json`.
- The installer creates a lightweight shim (`/usr/local/bin/octopus` or `%USERPROFILE%\\bin\\octopus` on Windows) that bootstraps the selected release from the cache and forwards commands to `bin/octopus.sh` inside the cached release.

**Repository discovery and root resolution**
- When `octopus` runs, it walks parent directories to locate `.octopus.yml`. Repos can override the installed version via `.octopus/cli-lock.yaml`, which lists `version:` (git tag/ref) and `checksum:` (SHA256 of the release archive). If absent, the CLI uses the global `~/.octopus-cli/metadata.json` default version.
- Repo-local scripts such as `./octopus/setup.sh` now execute via the shim (`octopus setup`) but still operate on the nested repository by setting `PROJECT_ROOT` appropriately.

**Version pinning and update model**
- `octopus install` respects `.octopus/cli-lock.yaml` and download the declared version. If the file is missing, it defaults to the newest release recorded in the global metadata.
- `octopus update` without args fetches the latest version, verifies checksum/signature, and optionally updates `.octopus/cli-lock.yaml` when invoked with `--pin`. The submodule workflow no longer commits a git SHA but instead lets the lockfile capture the intended tag.

**Install/bootstrap flow**
- After downloading, the installer verifies the archive against both the published SHA256 checksum file and the GitHub release signature (GPG key). Only after both checks pass is the cache considered valid.
- The installer writes `~/.octopus-cli/metadata.json` with `{ "version": "vX.Y.Z", "checksum": "...", "signature": "...", "installed_at": "..." }` so the global CLI can expose `octopus doctor` diagnostics.

**Setup execution contract**
- All generated instructions (README, commands docs, workflow messages, `setup.sh` output) now say `octopus <command>` instead of `./octopus/cli/octopus.sh`. Setup still symlinks/renders agent commands, so `OCTOPUS_CLI_REL` in `setup.sh` becomes the canonical reference.

**Generated command invocation contract**
- The CLI accepts the same commands as today (`branch-create`, `dev-flow`, `pr-open`, `pr-review`, `pr-comments`, `pr-merge`, `release`, `update`) plus new global ones (`install`, `setup`, `doctor`). Agents will continue to see `octopus.sh` commands during the transition because compatibility fixtures keep the old script around for sample outputs; the actual executions happen through the global shim.

**Compatibility modes: submodule and global**
- Repositories that already override `PROJECT_ROOT` with `.octopus/` remain operational: `setup.sh` still exists and can be invoked directly for now, but it simply proxies to `octopus setup` internally. This ensures current tests, docs, and automations still work while migration progresses.
- New repositories default to the global CLI workflow. The lockfile allows older repos to pin themselves to a specific release without submodules.

**Migration path**
- Provide a `octopus migrate` helper that:
  1. Installs the global CLI.
  2. Generates `.octopus/cli-lock.yaml` with the current submodule tag.
  3. Updates README/commands to mention the new flow and leave a note explaining `./octopus/` is legacy.

## Backward Compatibility

- `setup.sh` remains in the tree; running `./octopus/setup.sh` prints a notice pointing to `octopus setup` but still serves as a shim for scripts that hardcode the legacy path.
- Tests such as `tests/test_cli.sh` and `tests/test_update.sh` continue to source `cli/octopus.sh`, but the script now delegates to the cached release: `source ./cli/octopus.sh` becomes a backwards-compatible entrypoint that lazily downloads/uses the global CLI.
- Agent instructions generated by `setup.sh` now reference `octopus <command>` while keeping the legacy lines for existing conversations to avoid breaking ongoing workflows during the transition window.

## Context for Agents

- Configured machine now has a global `octopus` command; update agent prompts to run `octopus setup`, `octopus update`, etc.
- Knowledge modules: `documentation` domain (no promoted rules yet). Hypothesis HYP-001 still under investigation; continue marking evidence when editing `roles/tech-writer.md` or knowledge files.

## Testing Strategy

1. `test_cli_global_install`: simulate `octopus install --version vX.Y.Z`, ensure the archive downloads to `~/.octopus-cli/cache/vX.Y.Z`, and verify the checksum/signature files are recorded.
2. `test_cli_lockfile_respected`: create `.octopus/cli-lock.yaml` with a pinned version and run `octopus setup`; assert the global CLI honors the requested tag rather than default metadata.
3. `test_cli_shim_legacy`: run `./octopus/cli/octopus.sh branch-create ...` and confirm it sources the cached release so existing tests still pass.
4. `test_update_checksums`: run `octopus update --latest` with mocked release metadata and ensure both checksum and signature verifications occur.
5. `test_agent_instructions`: run `setup.sh` and verify generated docs/reference commands cite `octopus <cmd>`; confirm legacy instructions remain in comments for migration.

## Risks

- Platform parity: the shell installer must work on Linux, macOS, and Windows shimmed environments; build and test matrix must cover each.
- Cache corruption: if a cached release fails verification, the CLI must re-download instead of silently reusing corrupted data.
- Lockfile drift: users may forget to update `.octopus/cli-lock.yaml`, leading to mismatched releases. Provide `octopus doctor` and `octopus update --pin` to surface and fix drift.

## Changelog

- 2026-04-04: Introduce RM-007 global Octopus CLI, shell installer, lockfile pinning, and migration shims.
