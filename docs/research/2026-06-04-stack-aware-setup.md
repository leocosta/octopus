# Research — Stack-aware, granular setup

- **Date:** 2026-06-04
- **Author:** Leonardo (Tech Manager II, ex-Staff SWE)
- **Roadmap:** seeds **Cluster 24** (RM-138 … RM-145)
- **Trigger:** After Cluster 23 cut the per-session token cost, the question became
  *what gets installed in the first place*. A C#-only shop shouldn't carry Python rules
  or three databases it doesn't use — but today `octopus setup` installs coarsely and
  never detects the stack.

---

## The three gaps

### 1. `.octopus.yml` is not populated with `rules:` automatically
`cli/lib/setup.sh::_setup_generate_manifest` (L85–125) only writes `rules:` when the user
passes `--stack` (`dotnet`→csharp, `node`→typescript — hardcoded). There is **no repo scan**,
and the picker (`cli/lib/setup-picker.sh`) has **no stack selection**. So in practice the
manifest ships without `rules:`, and the generator is faithful to the manifest → the
`## Language Rules` pointers in `.claude/CLAUDE.md` carry only `common`. No language rules load.

### 2. Intent bundles pull stack/DB-specific skills atomically
`bundles/backend.yml` and `fullstack.yml` include **all four** `dba-*` (mssql + postgres +
mongodb + redis) regardless of the DB in use; `dotnet` (424 lines) only enters via
`--stack dotnet`. There is no way to affirm "C# + MSSQL only" without hand-editing the manifest —
bundles are all-or-nothing.

### 3. Situational defaults weigh on the registry
Every delivered skill loads its `description` into every session (the Cluster 23 lever).
`starter` ships `map-system` (manual-only by its own description) and `delegate` (situational,
305 lines); `quality` bundles 18 skills (blocking audits + signal-only + `knowledge-*` +
`fleet-*`) as one atomic unit.

## Reusable foundation
`fleet-bootstrap` already defines **stack-profile auto-detection** for the multi-repo flow
(`skills/fleet-bootstrap/SKILL.md:81-84`): `*.csproj`→dotnet, `package.json`+framework→node,
`pyproject.toml`→python, plus tiers T0/T1/T2. And the `dba-*` skills already carry DB detection
signals in their `triggers.keywords` (e.g. redis → `StackExchange.Redis`/`ioredis`/`redis-py`).
The fix is to **bring that detection down into single-repo `octopus setup`** and split the axes:
*intent bundle* (stack-agnostic) vs *stack/db profile* (language/DB).

## How "stack" flows today (for reference)
`.octopus.yml` (`rules:`/`skills:`/`bundles:`) → `setup.sh` parses it (`parse_octopus_yml`,
`expand_bundles`) → `generate_from_template` writes `.claude/CLAUDE.md` substituting `{{RULES}}`
with one pointer line per `OCTOPUS_RULES` entry (+`common` always) and `{{SKILLS}}` per skill;
`deliver_rules` symlinks `rules/<rule>/*.md` → `.claude/rules/<rule>/` (loaded natively). So the
CLAUDE.md pointers are generated **from the yml** — which is exactly why an empty `rules:` yields
no language rules. `active_stacks` (= the rule names) only filters hooks with a `stacks:` field.

## Decisions
- **Detection:** detect + **confirm in the picker** (pre-select, user adjusts) before writing.
- **Architecture:** **stack/db profiles** as a new axis (reuses the fleet concept); intent
  bundles become stack-agnostic.
- **Rebalance:** `dba-*` only for the affirmed DB; **split the `quality` bundle**; drop
  `map-system` and `delegate` from `starter`.
- **Scope:** roadmap capture → phased, verified implementation (same cadence as Cluster 23).

---

## Items

### RM-138 — Single-repo stack/DB auto-detection
`_detect_stack()` in `cli/lib/setup.sh` scans `$PROJECT_ROOT` reusing the fleet detect signals
(`*.csproj`/`*.sln`→csharp, `package.json`+tsconfig/`*.ts(x)`→typescript, `pyproject.toml`/
`requirements.txt`→python) and DB signals from the `dba-*` `triggers.keywords` (Npgsql/psycopg→
postgres, Microsoft.Data.SqlClient→mssql, MongoDB.Driver/mongoose/pymongo→mongodb,
StackExchange.Redis/ioredis/redis-py→redis). Emits detected stacks + DBs. Read-only.

### RM-139 — Picker confirmation + manifest population
The picker gets a **Stack/Database** section with detected items pre-checked and toggleable
(`PICKER_STACK`/`PICKER_DBS`); `_setup_generate_manifest` writes the resolved `rules:` +
`profiles:` into `.octopus.yml`, replacing the hardcoded `--stack` `case`.

### RM-140 — Stack/DB profiles as a setup axis
Profiles modeled as bundles with a `category:` (reusing `expand_bundles`, which already merges
skills/roles/rules): `stack-csharp` (`skills:[dotnet]`, `rules:[csharp]`), `stack-typescript`,
`stack-python`; `db-mssql`/`db-postgres`/`db-mongodb`/`db-redis` (each its `dba-*`). Picker
groups by category (Stack / Database / Intent).

### RM-141 — Intent bundles go stack-agnostic
Remove the four `dba-*` from `backend`/`fullstack` (now sourced from `db-*` profiles); remove
`dotnet` from the `--stack` hardcode (now from `stack-csharp`). `backend` keeps `backend-patterns`
+ roles.

### RM-142 — Split the `quality` bundle
Break `quality` into focused sub-bundles: `quality-audits` (blocking — audit-money/tenant/
security/contracts/audit-all), `quality-signals` (audit-grounding/verification/style + audit-config
+ refactor-deepen), `knowledge-ops` (knowledge-*), and move `fleet-*` to `tech-lead`/a `fleet`
bundle. `quality` may remain a composer of the sub-bundles for compatibility.

### RM-143 — Trim `starter` defaults
Move `map-system` (manual-only) and `delegate` (situational, 305L) out of `starter` into an
opt-in `workflow-extras` bundle (or explicit skills). `starter` keeps the core loop.

### RM-144 — Manifest `exclude:` for granular opt-out
Support `exclude:` in `.octopus.yml`: after `expand_bundles`, remove listed members from the
delivered skills/roles/rules (covers cases profiles don't, e.g. `exclude: [dba-mongodb]`). Picker
member-deselect is a stretch.

### RM-145 — Detection/profile tests + per-profile budget
`tests/test_stack_detection.sh` (a C# repo → `rules:[csharp]`+dotnet, no foreign language/DB);
update `test_bundles.sh` (backend/fullstack no longer carry `dba-*`); extend `context-budget` with
a per-bundle/profile budget and lock it in the ratchet.

## Discarded Items

| Item | Reason |
|---|---|
| Auto-write detected stack without confirming | Detection can be wrong (monorepo, ambiguous, legacy) — the picker confirm step is cheap and prevents surprise installs. |
| Keep bundles atomic + only add `exclude:` | Solves subtraction but not the positive axis (detected DB → just that `dba-*`); profiles model the language/DB dimension cleanly and reuse the fleet concept. |
| Per-language backend skills (node-patterns/python-patterns) | `backend-patterns` is already multi-stack; splitting it is a separate concern, not part of granular install. |
| Detect output language (pt-br/en) here | Already handled by the existing language auto-detection (`OCTOPUS_LANGUAGE_*`); out of scope. |
