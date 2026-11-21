# ADR-013: portable hook paths and the Windows `current` junction

## Status

Accepted — 2026-11-20

## Context

Since RM-188, every hook Octopus delivers resolves through the version-independent
link `~/.octopus-cli/current`. That covers the Claude Code commands written into
`.claude/settings.json` and the wrappers written into `.git/hooks/`. Two
assumptions under that link failed on Windows, and both were reproduced on a clean
Windows 11 VM (PR #244):

1. **The link was spelled as an absolute path for one shell.** A setup run from
   WSL wrote `/home/<u>/.octopus-cli/current/…`. Native Claude Code on the same
   project runs hooks through Git Bash, where that path does not exist, so all 18
   hooks exited 127. The reverse direction broke the same way. `settings.json`
   and `.git/hooks` are shared by every client of a working tree, so any absolute
   path is correct for at most one environment.
2. **`ln -s` is not a link under Git Bash.** Without Developer Mode, MSYS
   silently *copies* the target tree and returns 0. The first `octopus update`
   turned the junction that `install.ps1` creates into a 1,000-file copy. Every
   later update then failed with `rm: cannot remove 'current': Is a directory`,
   leaving the install stuck on the old release.

## Sources

- `setup.sh` `deliver_hooks` — the Claude Code hook path rewrite.
- `cli/lib/hooks.sh` `_hooks_wrapper` / `_hooks_portable_root` — git hook wrappers.
- `bin/octopus` `update_current`, `install.sh` `update_symlink` — the link writers.
- `tests/test_hooks_injection.sh`, `tests/test_hooks_install.sh`,
  `tests/test_current_junction.sh` — the contracts below.
- `docs/adr/011-capability-gated-delivery.md` — delivery is per agent
  capability, which is why the portable form is gated per agent here.

## Decision

1. **Hook commands name the link relative to `$HOME`.** The text written is
   literally `"$HOME/.octopus-cli/current/hooks/…"` (quoted), and the shell that
   runs the hook expands it, so each environment resolves *its own* install.
   This applies only when all three hold:
   - the default cache is in use: neither `OCTOPUS_CLI_CACHE_ROOT` nor
     `OCTOPUS_CACHE_ROOT` is set;
   - the delivery goes through the `current` link;
   - the consumer runs commands through a shell. That is always true for git
     hooks. An agent declares it with the `hooks_via_shell` manifest capability
     (ADR-011: delivery is gated on capabilities, never on agent names); today
     only Claude Code does.

   Everything else keeps the literal path: pinned lockfiles, vendored checkouts,
   custom cache roots, and other `settings_json` agents such as OpenCode.
   `setup.sh` and `cli/lib/hooks.sh` apply the same rule.
2. **On NTFS, `current` is a junction, never `ln -s`.** NTFS here means Git Bash,
   MSYS or Cygwin, or WSL reaching a cache under `/mnt/<drive>`. The link is
   replaced through PowerShell:
   - the paths are passed in environment variables, not interpolated into
     the command text;
   - an existing link is removed with `Directory.Delete($l)`, which never
     touches the tree behind it;
   - a real directory left by an earlier `ln -s` is healed with
     `Directory.Delete($l, $true)`.

   The helper exists in two copies, in `bin/octopus` and `install.sh`
   (`install.sh` runs standalone), and a test keeps them byte-identical.

## Alternatives Considered

### Absolute path plus a drift warning (status quo since #239)

- **Pros:** no runtime dependency on `$HOME`; one literal path to reason about.
- **Cons:** only detects the breakage, never prevents it; mixed Git Bash + WSL
  teams must re-run setup every time they switch shells, and each run breaks
  the other side.

### A per-environment `settings.json` / hook directory

- **Pros:** each environment gets exact absolute paths.
- **Cons:** Claude Code and git read exactly one location per working tree;
  there is nowhere to put the second copy.

### Developer Mode / `MSYS=winsymlinks:nativestrict` for real symlinks

- **Pros:** one code path (`ln -s`) everywhere.
- **Cons:** requires a machine-level setting most users do not have; without
  it MSYS still falls back to copying silently, which is the failure itself.

## Consequences

### Positive

- One committed `settings.json` and one set of git hooks work from Git Bash,
  WSL, Linux and macOS at once.
- `octopus update` works repeatedly on Windows; a broken copy left by older
  versions heals on the next update.
- No hook file contains a user name or a machine-specific path.

### Negative

- A hook command now depends on `$HOME` when it runs. An agent started under
  another home (`sudo`, a container, CI) must have Octopus installed there, or
  the hook exits 127, which Claude Code treats as non-blocking. `octopus doctor`
  expands `$HOME` to flag paths that do not resolve.
- On Windows the link writer depends on `powershell.exe`, which is always
  present on Windows but is one more moving part than `ln`.

### Risks

- An agent must declare `hooks_via_shell` only if its runner really goes
  through a shell. One that execs argv would get an unexpanded `"$HOME/…"`
  path. Agents without the capability keep literal paths.
- The two copies of the junction helper could drift. Mitigated by
  `tests/test_current_junction.sh`.
