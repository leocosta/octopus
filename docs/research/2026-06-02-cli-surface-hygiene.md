# Research — CLI surface hygiene (registry, help, conventional commands, doctor)

- **Date:** 2026-06-02
- **Author:** Leonardo (Tech Manager II, ex-Staff SWE)
- **Roadmap:** seeds **Cluster 22** (RM-113 … RM-116)
- **Trigger:** A question — "the octopus CLI accepts parameters that aren't all
  listed in the help; which ones, and why?" Investigating it surfaced not a
  documentation gap but a **structural** one: the CLI infers commands from file
  existence and splits its help across two disconnected layers.

---

## The two root causes

### 1. Commands are inferred from file existence (no allowlist)

`cli/octopus.sh` dispatches dynamically:

```sh
LIB_SCRIPT="$CLI_DIR/lib/${COMMAND}.sh"
[[ -f "$LIB_SCRIPT" ]] || { echo "Unknown command: $COMMAND"; exit 1; }
source "$LIB_SCRIPT"
```

So **any** `cli/lib/<name>.sh` is an accepted command. There are 25 `.sh` files
but the usage lists 17 → 8 are accepted-but-unlisted. They split in two:

- **Implementation libs behind a documented short alias** — `knowledge-hygiene`
  (← `hygiene`), `knowledge-synthesize` (← `synthesize`), `knowledge-briefing`
  (← `briefing`), `knowledge-root` (← `kr`), `consigliere-lens` (← `lens`). The
  short entrypoint sources the long lib and calls the `main` (e.g. `hygiene.sh`
  ends with `kh_run`); the long lib ends on a bare function definition. Invoking
  `octopus knowledge-hygiene` sources it, defines functions, and **silently
  no-ops**.
- **Pure helper libraries never meant as commands** — `audit-map` (file→audit
  map, sourced by `pr-review`/`codereview`), `ui` (terminal helpers),
  `setup-picker` (the fzf/bash picker, sourced by `setup`). Same silent no-op.

The dispatcher cannot tell a *command* from a *library* — both are `.sh` files in
the same directory. There is no ADR governing this design; it emerged from the
original CLI (RM-007).

### 2. Help is split across two disconnected layers

- `bin/octopus` (the bootstrap shim) `print_help` lists only **5**: `install`,
  `update`, `setup`, `uninstall`, `doctor`, plus a generic `<other>`.
- Every workflow command reaches `cli/octopus.sh` via the `*)` catch-all and is
  shown only as `<other>`. A user who runs `octopus --help` never discovers
  `run`, `ask`, `dev-flow`, `kr`, `release`, … — those appear only when you run
  `octopus` with **no** arguments (the second-layer usage).

The two usage strings are hand-maintained and drift from the real command set.

### 3. Conventional affordances are missing

- `octopus version` / `octopus --version` is **unhandled** — it falls to the
  catch-all, tries to source `lib/--version.sh`, and prints *"Unknown command"*.
  (The `--version` tokens in `bin/octopus` are the `install`/`update` `--version
  <tag>` flag, not a version command.)
- No subcommand exposes `--help` / `-h`. `octopus release` (no args) prints its
  own usage, but `octopus release --help` does not; `setup`, `ask`, `run`, etc.
  have no per-command help at all.
- `setup` accepts more than the shim shows (`--scope`/`--reconfigure`/
  `--dry-run`): also `--no-hooks`, `--no-workflow`, `--bundle`, `--stack`,
  `--reviewers` — used non-interactively (CI / `octopus run`) but undocumented.
- Configuration env vars (`OCTOPUS_CLI_CACHE_ROOT`, `OCTOPUS_RELEASE_OWNER`,
  `OCTOPUS_RELEASE_NAME`, `OCTOPUS_API_ENDPOINT`, `OCTOPUS_DRY_RUN`,
  `OCTOPUS_DISABLED_HOOKS`) are nowhere in `--help`.

### 4. `doctor` is anemic

`doctor` prints the installed version and path. It does not catch the failure
classes that actually bite: **stale hook paths in `settings.json`** (the
version-pinned `cache/vX.Y.Z/...` entries that break Claude at session start —
the bug fixed in `setup.sh`'s `deliver_hooks`), **rotten cache symlinks**
(`v0.15.0 → ~/.local`, `v0.16.1 → dev checkout`), **version drift** across a
manager's repos, and **stale translations**.

## The design position

The fix is not "document more" — it is to stop inferring commands from files and
to generate help from a single source. A **declarative command registry** is the
keystone: the dispatch validates against it (helper libs error instead of
no-op'ing), and the help text is generated from it (one unified surface, no
drift). On top of the registry, the conventional affordances (`version`, per-
command `--help`, `list`, `completions`) become cheap, and the doctor grows into
the real health command. The implementation libraries stay internal — the
registry simply omits them, which also turns their silent no-op into a clean
error.

This satisfies the DRY rule in `coding-style.md` from the structural side: the
usage string and the lib directory are two sources of truth for "what commands
exist"; the registry collapses them into one.

---

## Items

### RM-113 — Command registry + generated help + lib guard (keystone)

**Need:** replace "command = a `cli/lib/*.sh` exists" with a declarative registry
(a central array, or a `# @command: <name> — <description>` marker on each
command lib). `cli/octopus.sh` validates the dispatched name against the registry
— a name not registered (a helper lib, a typo) errors clearly instead of
sourcing and no-op'ing. The help text is **generated** from the registry and
**unified**: `octopus help` / `octopus --help` lists every command, ending the
two-layer split between `bin/octopus` and `cli/octopus.sh`.

**Problem it solves:** the hand-maintained usage strings drift from the real
command set, and helper libraries are silently invocable. One registry is the
single source of truth for both the dispatch guard and the help. Foundation for
RM-114 and RM-115.

### RM-114 — Conventional CLI affordances (version, per-command help, list, completions)

**Need:** the standard affordances a CLI is expected to have, enabled by RM-113's
registry: `octopus version` / `--version` (today prints "Unknown command");
`octopus help <command>` plus `--help` / `-h` on each subcommand; `octopus list`
(the real command set, generated); and `octopus completions [bash|zsh|fish]`.

**Problem it solves:** discoverability and convention. `--version` is broken,
no command self-documents, and there is no way to enumerate the surface.
Depends on RM-113. (`version` is trivial; `completions` is the heaviest, lowest-
priority piece.)

### RM-115 — Document the hidden-but-real surface

**Need:** surface the accepted-but-undocumented surface that is not auto-covered
by RM-113's generated help: a "Configuration / Environment" section for the
`OCTOPUS_*` env vars, the full `setup` flag set (`--no-hooks`, `--no-workflow`,
`--bundle`, `--stack`, `--reviewers`), and the `release` subcommands. Bilingual
docs-site pages (EN + pt-br) where they belong.

**Problem it solves:** the non-interactive / CI knobs and the release machinery
are real and used, but invisible to a reader. Mostly docs; small surface.

### RM-116 — `octopus doctor` as the health command

**Need:** grow `doctor` from "print version + path" into read-only health
detection: stale hook paths in `settings.json` (version-pinned `cache/vX.Y.Z`
entries pointing at a deleted release — the class fixed in `deliver_hooks`),
rotten cache symlinks, version drift across repos, and stale translations.
Reuses `audit-config`.

**Problem it solves:** the failure classes that actually bite (stale hooks
erroring at session start, cache rot) are invisible until they break. A health
command surfaces them proactively. Independent of the registry.

## Discarded Items

| Item | Reason |
|---|---|
| Rename/flatten the two CLI layers (merge `bin/octopus` into `cli/octopus.sh`) | The shim/workflow split is intentional (bootstrap vs. workflow, version management lives in the shim). RM-113 unifies the *help*, not the *binaries* — no need to merge. |
| Auto-register every `cli/lib/*.sh` (opt-out marker instead of opt-in) | Opt-out keeps the "file = command" coupling that caused the problem; an explicit opt-in registry is the point. |
| Expose the implementation libs (`knowledge-*`, `consigliere-lens`) as documented commands | They are libraries behind documented aliases; exposing them would duplicate the aliases and confuse. Keep internal. |
| `install --no-shim-setup` documentation | Internal installer flag, not user-facing. Intentionally omitted. |
