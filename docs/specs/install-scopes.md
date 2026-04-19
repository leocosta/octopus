# Spec: Install Scopes — `repo` vs `user`

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **Roadmap** | RM-018 |
| **RFC** | N/A |

## Problem

Every Octopus install wrote relative to `$PROJECT_ROOT` — the consuming repository. Teams wanting a **shared base configuration** (common rules, standard skills, company-wide hooks) had to duplicate `.octopus.yml` across every repo and keep the copies in sync manually. Claude Code, Codex, Gemini and OpenCode already merge `~/.claude/`-style user config with `<repo>/.claude/`-style project config at read time, but Octopus didn't expose that layering.

## Goals

1. Two install scopes selectable at setup time: `repo` (default, unchanged behavior) and `user`.
2. Selection precedence: `--scope` CLI flag → `OCTOPUS_SCOPE` env var → wizard prompt → `repo` default.
3. User scope writes everything to `$HOME` so the config lives in the same locations agents already read as user-level defaults (`~/.claude/`, `~/.claude/settings.json`, etc.).
4. User-scope manifest lives at `${XDG_CONFIG_HOME:-$HOME/.config}/octopus/.octopus.yml`.
5. Layering is automatic — users run `octopus setup --scope=user` once (company defaults), then `octopus setup` in each repo (project-specific overrides). CC handles the merge at session start.
6. Backward-compatible: existing repo-scope installs need no changes.

## Non-goals

- **One-shot `--scope=both`.** Users who want both scopes run `octopus setup` twice. Keeps the code path simple.
- **Uninstall command.** Managing what Octopus "owns" in `~/.claude/` needs careful tracking; deferred to RM-019+.
- **Cross-machine sync.** Dotfiles problem, not an Octopus problem.
- **Site-wide / admin install (`/etc/octopus/`).** Could be a future scope; not today.
- **Conflict resolution between scopes.** CC already resolves (repo > user at merge time).
- **MCP / workflow / reviewers / githubAction / knowledge in user scope.** These are project-scoped concepts and would leak secrets or confuse agents. Warned and ignored when user-scope manifest declares them.

## Design

### Scope → INSTALL_ROOT

```bash
OCTOPUS_SCOPE="${OCTOPUS_SCOPE:-repo}"
case "$OCTOPUS_SCOPE" in
  repo) INSTALL_ROOT="$PROJECT_ROOT" ;;
  user) INSTALL_ROOT="$HOME" ;;
esac
```

All delivery handlers in `setup.sh` that previously wrote to `$PROJECT_ROOT/$MANIFEST_DELIVERY_*_TARGET` now write to `$INSTALL_ROOT/...`. Because user scope sets `INSTALL_ROOT=$HOME` and targets are already of the form `.claude/rules/`, the files naturally land in `~/.claude/rules/` — exactly where CC looks for user-level config.

### File locations by scope

| Artifact | Repo scope | User scope |
|---|---|---|
| Manifest | `<repo>/.octopus.yml` | `~/.config/octopus/.octopus.yml` |
| Secrets | `<repo>/.env.octopus` | `~/.config/octopus/.env.octopus` (chmod 600) |
| CLAUDE.md / AGENTS.md | `<repo>/.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| rules/skills/roles | `<repo>/.claude/<subdir>/` | `~/.claude/<subdir>/` |
| settings.json | `<repo>/.claude/settings.json` | `~/.claude/settings.json` |
| slash commands | `<repo>/.claude/commands/` | `~/.claude/commands/` |
| `.gitignore` update | ✓ | — (skipped) |
| GitHub Actions scaffold | ✓ | — (skipped) |
| MCP servers | ✓ | — (warned + ignored) |
| Workflow + reviewers | ✓ | — (warned + ignored) |
| Knowledge modules | ✓ | — (warned + ignored) |

### Resolution flow

Inside `cli/lib/setup.sh`:

1. Parse `--scope=<value>` from CLI args, strip it from the passthrough list.
2. If `--scope` is set → export `OCTOPUS_SCOPE`; set `OCTOPUS_SCOPE_PINNED=1`.
3. Else if `OCTOPUS_SCOPE` already set in env → `OCTOPUS_SCOPE_PINNED=1`.
4. Else → default to `repo`; leave unpinned.
5. Compute `MANIFEST_DIR = $HOME/.config/octopus` (user) or `$PWD` (repo).
6. If manifest missing → wizard launches. `_wizard_scope_prompt` runs only when `OCTOPUS_SCOPE_PINNED` is unset.
7. After the wizard's scope prompt (if any), the wizard re-resolves its write target to the user-config dir when the user picked `user`.
8. When the wizard runs with a manifest already present AND the manifest declares `scope: <value>`, the parser sets `OCTOPUS_SCOPE_PINNED=1`. Prompt is skipped.

### `.octopus.yml` schema

One new optional top-level key:

```yaml
scope: user   # default: repo (omitted)
```

The wizard only emits this key when the selected scope is `user`. Absence means repo-scope.

### Scope mismatch warning

When a manifest declares `scope: X` but invocation overrode to `Y`:

```
⚠  Manifest declares 'scope: user' but active scope is 'repo' (flag/env override). Continuing with 'repo'.
```

Continues with the runtime scope (precedence rule). Surfaces the mismatch so the user notices.

### User-scope field validation

After parsing, `setup.sh` in user scope disables fields that don't make sense at user level:

- `mcp:` — secrets belong in repo scope (workflow tokens, DB URLs differ per project)
- `workflow:` — dev-flow commands need a repo context
- `reviewers:` — reviewers are per-repo team configuration
- `githubAction:` — GitHub Actions live inside `.github/` of a repo
- `knowledge:` — domain context is per-project

Each triggers a `⚠  Ignoring '<field>' in user scope — ...` warning. The field is reset to its empty value so downstream delivery handlers short-circuit cleanly without throwing.

### Restart nudge

End-of-setup in user scope prints:

> `ℹ  Restart any active Claude Code / Codex / Gemini sessions for changes to take effect.`

Because active agent sessions cache settings.json at load time. Not fatal, just informational.

## Backward compatibility

- Repos with an existing `.octopus.yml` (no `scope:` key) keep working unchanged — `OCTOPUS_SCOPE` defaults to `repo`.
- Existing tests (`test_full_setup.sh`, etc.) continue to pass without modification — they don't set `OCTOPUS_SCOPE`, inheriting the `repo` default.
- The wizard's scope prompt only appears when the caller didn't pin the scope, so CI invocations (`OCTOPUS_SCOPE=repo` or `--scope=repo` explicit) skip it.

## Testing strategy

- Syntax: `bash -n setup.sh cli/lib/setup.sh cli/lib/setup-wizard.sh`.
- Roundtrip: generate YAML with `OCTOPUS_SCOPE=user`, verify `scope: user` present; reset state; re-parse; assert `OCTOPUS_SCOPE=user` restored.
- End-to-end repo scope (backward-compat): existing `tests/test_full_setup.sh` continues to pass.
- End-to-end user scope: write manifest to `~/.config/octopus/.octopus.yml`, run setup with `--scope=user`, verify `~/.claude/CLAUDE.md`, `~/.claude/rules/…`, `~/.claude/settings.json` exist; verify `~/.gitignore` was not touched.
- User-scope warnings: manifest with `mcp: [notion]`, `workflow: true`, `knowledge: true` and `scope: user` emits 3 warnings; downstream delivery does not fail.
- Precedence: manifest `scope: user` + `--scope=repo` flag → warning + runtime scope `repo`.

## Risks

- **Stale settings.json in running sessions** — mitigated by end-of-setup nudge. Out of our control otherwise.
- **Secrets under `~/.config/octopus/.env.octopus`** — `chmod 600` is applied best-effort; mode may not stick on FAT/NTFS mounts.
- **Field leakage under user scope** — mitigated by explicit warnings + field reset after parse.
- **User deletes their manifest and re-runs** — wizard re-runs from scratch; no data loss in `.claude/` since Octopus-written files remain and are overwritten idempotently.

## Changelog

- **2026-04-18** — Initial implementation. `OCTOPUS_SCOPE={repo,user}` flow from CLI → env → manifest → wizard. User-scope manifest at `~/.config/octopus/.octopus.yml`. Delivery targets switched to `$INSTALL_ROOT`. User-scope-invalid fields warn-and-ignore. Restart nudge on user-scope setup.
