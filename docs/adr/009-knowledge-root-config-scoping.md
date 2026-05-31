# ADR-009: Knowledge-root config scoping (per-repo vs per-user)

## Status

Accepted — 2026-05-31

## Context

RM-106 introduces a registry of **knowledge roots** (markdown trees the Cluster 19 engines operate over). The four built-in roots split cleanly by ownership: `docs/` and the standards set are **per-repo** (every clone has them, the team shares them), while the auto-memory and the consigliere workspace are **per-user** and **private** (a single developer's machine, paths that must not be published). A single config location cannot serve both without either losing the shared/versioned roots or leaking a private workspace path into a team repo — the latter would violate the spirit of the ADR-007 write-guard. See [spec](../specs/knowledge-root-registry.md) decision D2.

## Sources

- `docs/specs/knowledge-root-registry.md` — D2
- `docs/research/2026-05-31-knowledge-root-operations.md` — root taxonomy
- ADR-007 (consigliere artifact location / write-guard) — the `consigliere.workspace` user-config key precedent
- ADR-005 (workspace/config/template precedence) — existing precedence model

## Decision

Knowledge-root config is **hybrid**: per-repo roots are declared in `.octopus.yml` (versioned, team-shared); per-user roots are declared in user-scoped config, reusing the existing `consigliere.workspace` pattern. The schema **forbids a per-user/private path from appearing in `.octopus.yml`** by construction — `.octopus.yml` may reference a per-user root by `id` but never carries its absolute path. The loader merges roots with precedence **built-in < project (`.octopus.yml`) < user config**.

## Alternatives Considered

### All in `.octopus.yml`

- **Pros:** one source of truth; simplest loader; everything versioned and reviewable.
- **Cons:** leaks the private consigliere/memory path into the team repo, violating the ADR-007 write-guard spirit; forces a per-user concept into a per-repo file.

### All in user config

- **Pros:** nothing private is ever versioned; uniform loader.
- **Cons:** `docs/` and the standards set stop being declared per-repo — every developer would hand-configure shared roots on every machine, defeating the "ship sensible defaults, zero extra config" goal.

## Consequences

### Positive

- Private paths cannot reach a versioned file by construction — the guard is structural, not a convention.
- Reuses the established `consigliere.workspace` user-config mechanism; no new config subsystem.
- Built-in defaults mean `docs/`, standards, memory, and the consigliere workspace resolve with zero user config in the common case.

### Negative

- The loader must read two layers and apply precedence — more complex than a single file.
- A per-user root referenced by `id` in `.octopus.yml` but undefined in user config must resolve to a no-op, not an error (graceful absence).

### Risks

- **Precedence confusion.** built-in < project < user must be documented and tested, or overrides surprise users. Mitigation: explicit precedence tests (mirrors ADR-005).
- **Schema enforcement gap.** "forbid private path in `.octopus.yml`" must be validated at load time, not just documented, or the guard is theater. Mitigation: loader rejects an absolute/`~`-rooted path under a per-user root id declared in `.octopus.yml`.
