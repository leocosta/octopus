# RFC: Global Octopus CLI

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-04 |
| **Author** | codex assistant |
| **Status** | Draft |
| **Spec** | [docs/specs/octopus-cli-tool.md](docs/specs/octopus-cli-tool.md) |

## Background

The roadmap entry RM-007 calls for “Octopus CLI Tool” so that teams do not need to add the repository as a git submodule in every project. Today Octopus is always a submodule: README installation instructions, `setup.sh`, `cli/octopus.sh`, the `update` workflow, and every commands document expect `./octopus/...`.

## Decision

1. _Distribution:_ Ship a shell installer (downloaded via `curl | bash`) that fetches the tagged release archive from GitHub, verifies SHA256 + signature, caches it under `~/.octopus-cli/cache/<tag>`, and exposes a shim at `/usr/local/bin/octopus` (or the equivalent user `bin` dir on Windows). The shim boots the cached release and forwards arguments to the release’s `bin/octopus.sh`.
2. _Version pinning:_ Introduce a per-repository lockfile (`.octopus/cli-lock.yaml` or `.octopus-version`) that records `{version: vX.Y.Z, checksum: <sha256>}`. The global CLI reads it when located (walking parent directories for `.octopus.yml`) and installs the requested tag to keep the reproducibility submodules provided.
3. _Compatibility:_ Retain `./octopus/setup.sh` and `./octopus/cli/octopus.sh` as migration shims. They continue to exist so legacy automation still works during rollout but delegate to the global CLI whenever possible.
4. _Command contract:_ All generated instructions now tell users/agents to run `octopus <command>`. Existing automation that still runs the shim works because the shim executes the cached release and prints a deprecation notice.
5. _Integrity:_ Every install uses both the published SHA256 checksum and the GitHub release signature (GPG) before the archive is accepted into cache.
6. _Platforms:_ The installer is POSIX/Bash based and also installs a trivial PowerShell shim so Windows users (Git Bash, WSL, PowerShell Core) have the same entrypoint.

## Alternatives Considered

- **Homebrew formula** – narrower platform reach and more maintenance; we still need a shell installer for Linux/macOS and something for Windows.
- **NPM distribution** – too heavy dependency on Node toolchain and uninterpretable for existing scripts.
- **Keep submodule-only** – unacceptable due to onboarding friction RM-007 aims to solve.

## Implementation Notes

- Implement `octopus install`, `setup`, `update`, `doctor`, and retain workflow commands (`branch-create`, `dev-flow`, `release`, etc.).
- Update `setup.sh` and generated command docs to mention `octopus <command>` while keeping the legacy string as a migration note.
- Add new tests `test_cli_global_install`, `test_cli_lockfile_respected`, and `test_update_checksums` (see spec) once the CLI runtime exists.

## Testing

- Manual verification of `octopus install` with mocked release metadata (package + signature).
- Automated checks in `tests/` once new CLI code exists, covering installer, lockfile, and shim fallback.

## Unresolved Questions

- Should the lockfile live under `.octopus/cli-lock.yaml` or a single `.octopus-version` file?
- Do we need to enforce signed releases on day one or can it ship in two phases?

